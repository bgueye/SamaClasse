// Choix d'une image sur l'appareil : photo prise sur le moment ou image de
// la galerie (rédacteurs, ajout d'un schéma à une leçon).
//
// Derrière une interface pour que les tests d'écran n'ouvrent jamais
// l'appareil photo : ils passent un faux à `AppScope`.

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'reduction_image.dart';

enum SourceImage { appareilPhoto, galerie }

/// Ouvre l'appareil photo ou la galerie, puis prépare l'image pour l'espace
/// `schemas`.
abstract class ChoixImage {
  const ChoixImage();

  /// Contenu de l'image choisie, ou `null` si l'utilisateur renonce.
  Future<Uint8List?> choisir(SourceImage source);

  /// Réduit l'image sous 150 Ko ([reduireImage]), dans un isolat pour ne pas
  /// figer l'écran (sur le web, `compute` l'exécute sur place).
  Future<ImageReduite> reduire(Uint8List octets) => compute(reduireImage, octets);
}

/// Appareil photo et galerie du système (paquet officiel `image_picker`).
///
/// Android : le sélecteur de photos du système, sans autorisation à
/// demander. iOS : les phrases d'autorisation sont dans `Info.plist`. Web :
/// la boîte « ouvrir un fichier » du navigateur (l'appareil photo sur un
/// téléphone).
class ChoixImageSysteme extends ChoixImage {
  const ChoixImageSysteme();

  @override
  Future<Uint8List?> choisir(SourceImage source) async {
    final fichier = await ImagePicker().pickImage(
      source: source == SourceImage.appareilPhoto ? ImageSource.camera : ImageSource.gallery,
      // Première réduction faite par le système (rapide, en code natif) :
      // une photo de 12 Mpx arrive à 2 400 px, ce qui ménage la mémoire.
      // La réduction finale sous 150 Ko se fait ensuite (reduction_image).
      maxWidth: 2400,
      maxHeight: 2400,
      requestFullMetadata: false,
    );
    return fichier?.readAsBytes();
  }
}
