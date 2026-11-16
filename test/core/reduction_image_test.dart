// Réduction des schémas sous 150 Ko avant dépôt (lib/core/services/
// reduction_image.dart).

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:samaclasse/core/services/reduction_image.dart';

/// Image « photo » difficile à compresser : du bruit coloré (le pire cas
/// pour le JPEG, bien plus lourd qu'une vraie photo de cahier).
img.Image bruit(int largeur, int hauteur, {int graine = 1}) {
  final hasard = Random(graine);
  final image = img.Image(width: largeur, height: hauteur);
  for (final p in image) {
    p
      ..r = hasard.nextInt(256)
      ..g = hasard.nextInt(256)
      ..b = hasard.nextInt(256);
  }
  return image;
}

/// Page de cahier : fond blanc et quelques traits, comme un vrai schéma.
img.Image schemaCahier(int largeur, int hauteur) {
  final image = img.Image(width: largeur, height: hauteur)..clear(img.ColorRgb8(255, 255, 255));
  for (var y = 40; y < hauteur; y += 40) {
    img.drawLine(image, x1: 0, y1: y, x2: largeur - 1, y2: y, color: img.ColorRgb8(200, 210, 240));
  }
  img.drawCircle(image, x: largeur ~/ 2, y: hauteur ~/ 2, radius: hauteur ~/ 4, color: img.ColorRgb8(30, 60, 200));
  return image;
}

Uint8List png(img.Image i) => img.encodePng(i);

void main() {
  group('reduireImage', () {
    test('grande photo de cahier : JPEG de moins de 150 Ko, 1 200 px de large', () {
      final r = reduireImage(png(schemaCahier(4000, 3000)));
      expect(r.octets.length, lessThanOrEqualTo(limiteOctetsSchema));
      expect(r.largeur, largeurMaxSchema);
      expect(r.hauteur, 900);
      expect(r.extension, 'jpg');
      // Le résultat est bien un JPEG lisible, aux dimensions annoncées.
      final relu = img.decodeJpg(r.octets)!;
      expect((relu.width, relu.height), (r.largeur, r.hauteur));
    });

    test('image très chargée (bruit) : passe quand même sous la limite', () {
      final r = reduireImage(png(bruit(2400, 1800)));
      expect(r.octets.length, lessThanOrEqualTo(limiteOctetsSchema));
      expect(r.largeur, lessThanOrEqualTo(largeurMaxSchema));
      expect(r.largeur, greaterThanOrEqualTo(largeurMinSchema));
    });

    test('schéma très allongé : hauteur limitée à 1 600 px, proportions gardées', () {
      final r = reduireImage(png(schemaCahier(1000, 4000)));
      expect(r.hauteur, hauteurMaxSchema);
      expect(r.largeur, 400);
    });

    test('petite image : jamais agrandie', () {
      final r = reduireImage(png(schemaCahier(600, 300)));
      expect((r.largeur, r.hauteur), (600, 300));
    });

    test('PNG transparent : posé sur fond blanc (pas noir en JPEG)', () {
      final transparente = img.Image(width: 500, height: 500, numChannels: 4)..clear(img.ColorRgba8(0, 0, 0, 0));
      final r = reduireImage(png(transparente));
      final pixel = img.decodeJpg(r.octets)!.getPixel(250, 250);
      expect(pixel.r, greaterThan(245));
      expect(pixel.g, greaterThan(245));
      expect(pixel.b, greaterThan(245));
    });

    test('photo prise en portrait (orientation EXIF) : redressée', () {
      final photo = schemaCahier(800, 400);
      photo.exif.imageIfd.orientation = 6; // tourner de 90° pour l'afficher
      final r = reduireImage(img.encodeJpg(photo));
      expect((r.largeur, r.hauteur), (400, 800));
    });

    test('métadonnées de la photo effacées (lieu, appareil)', () {
      final photo = schemaCahier(800, 400);
      photo.exif.imageIfd.make = 'Telephone';
      photo.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(14, 1);
      final source = img.encodeJpg(photo);
      expect(img.decodeJpg(source)!.exif.imageIfd.hasMake, isTrue); // le test a un sens
      final relu = img.decodeJpg(reduireImage(source).octets)!;
      expect(relu.exif.imageIfd.hasMake, isFalse);
      expect(relu.exif.gpsIfd.isEmpty, isTrue);
    });

    test('fichier qui n’est pas une image : ImageIllisible', () {
      expect(() => reduireImage(Uint8List.fromList(List.filled(100, 7))), throwsA(isA<ImageIllisible>()));
    });

    test('limite impossible à tenir : ImageTropLourde', () {
      expect(() => reduireImage(png(bruit(1200, 900)), limite: 2000), throwsA(isA<ImageTropLourde>()));
    });
  });

  test('libellePoids', () {
    expect(libellePoids(800), '800 o');
    expect(libellePoids(94208), '92 Ko');
    expect(libellePoids(1468006), '1,4 Mo');
  });
}
