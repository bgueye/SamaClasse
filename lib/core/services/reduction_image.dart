// Réduction des schémas avant leur dépôt dans l'espace `schemas` (D15) :
// l'espace refuse tout fichier de plus de 150 Ko, pour que les élèves les
// chargent vite en 3G.
//
// Logique pure (aucun widget, aucun réseau), testée seule
// (test/core/reduction_image_test.dart). Lancée dans un isolat avec
// `compute` : décoder une photo de cahier prend quelques centaines de
// millisecondes, l'écran ne doit pas se figer.

import 'dart:math' show max, min;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Taille maximale acceptée par l'espace `schemas` (150 × 1 024 octets).
const limiteOctetsSchema = 153600;

/// Plus grande largeur gardée : bien assez pour une page de cahier sur un
/// téléphone ou une tablette (le schéma s'affiche en pleine largeur).
const largeurMaxSchema = 1200;

/// Plus grande hauteur gardée (schéma très allongé).
const hauteurMaxSchema = 1600;

/// En dessous de cette largeur, un schéma devient illisible : on préfère
/// refuser l'image plutôt que de déposer une vignette floue.
const largeurMinSchema = 400;

/// Image prête à déposer.
class ImageReduite {
  const ImageReduite({required this.octets, required this.largeur, required this.hauteur});

  /// Contenu JPEG.
  final Uint8List octets;
  final int largeur;
  final int hauteur;

  /// Extension du fichier déposé (toujours du JPEG, voir [reduireImage]).
  String get extension => 'jpg';
}

/// L'image n'a pas pu être lue (format inconnu, fichier abîmé).
class ImageIllisible implements Exception {
  const ImageIllisible();
}

/// L'image ne passe pas sous [limiteOctetsSchema], même très réduite
/// (rarissime : photo extrêmement chargée).
class ImageTropLourde implements Exception {
  const ImageTropLourde();
}

/// Réduit [octets] (JPEG, PNG, WebP, GIF, BMP…) en un JPEG de moins de
/// [limite] octets, d'au plus [largeurMaxSchema] × [hauteurMaxSchema] pixels.
///
/// Pourquoi toujours du JPEG : une photo de cahier en PNG pèse plusieurs
/// mégaoctets ; le JPEG la ramène à 60–120 Ko sans perte visible pour un
/// schéma tracé à la main. Le ré-encodage efface aussi les métadonnées de
/// la photo (lieu GPS, modèle du téléphone), qui n'ont rien à faire en ligne.
///
/// Étapes :
/// 1. redresser l'image selon son orientation EXIF (photo prise en
///    portrait) ;
/// 2. poser une image transparente (PNG) sur fond blanc : en JPEG, la
///    transparence deviendrait noire ;
/// 3. réduire aux dimensions maximales ;
/// 4. encoder en qualité décroissante (85 → 45) jusqu'à passer sous la
///    limite ; sinon, réduire encore la largeur de 20 % et recommencer.
ImageReduite reduireImage(Uint8List octets, {int limite = limiteOctetsSchema}) {
  final lue = img.decodeImage(octets);
  if (lue == null || lue.width == 0 || lue.height == 0) throw const ImageIllisible();

  var image = img.bakeOrientation(lue);
  // Le paquet recopie sinon les métadonnées de la photo (lieu GPS, modèle
  // du téléphone, date) dans le JPEG produit : on les efface.
  image.exif = img.ExifData();
  if (image.hasAlpha) {
    final fond = img.Image(width: image.width, height: image.height)
      ..clear(img.ColorRgb8(255, 255, 255));
    image = img.compositeImage(fond, image);
  }

  // Plus grande largeur qui respecte les deux maximums (jamais d'agrandissement).
  final echelle = min(1.0, min(largeurMaxSchema / image.width, hauteurMaxSchema / image.height));
  var largeur = max(1, (image.width * echelle).round());

  while (true) {
    final reduite = largeur >= image.width
        ? image
        : img.copyResize(image, width: largeur, interpolation: img.Interpolation.average);
    for (final qualite in const [85, 75, 65, 55, 45]) {
      final jpeg = img.encodeJpg(reduite, quality: qualite);
      if (jpeg.length <= limite) {
        return ImageReduite(octets: jpeg, largeur: reduite.width, hauteur: reduite.height);
      }
    }
    final suivante = (largeur * 0.8).round();
    // Une image déjà petite qui ne passe pas : inutile d'insister.
    if (suivante < largeurMinSchema || suivante >= largeur) throw const ImageTropLourde();
    largeur = suivante;
  }
}

/// « 92 Ko », « 1,4 Mo » : poids lisible d'un fichier.
String libellePoids(int octets) {
  if (octets < 1024) return '$octets o';
  if (octets < 1024 * 1024) return '${(octets / 1024).round()} Ko';
  final mo = (octets / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');
  return '$mo Mo';
}
