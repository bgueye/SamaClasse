// Captures d'écran de l'application, pour vérifier l'interface à l'œil :
// alignement sur les lignes Seyès, débordements, rendu des polices.
//
// Lancer :
//   flutter test tool/captures/captures_test.dart
// Images produites dans build/captures/ (ignoré par git).
//
// Ce n'est pas un test de non-régression (rien n'est comparé) : il est rangé
// dans tool/ pour que `flutter test` ne le lance pas à chaque fois. Les
// polices réelles (Atkinson, Playwrite, icônes Material) sont chargées, alors
// que les tests ordinaires utilisent une police de test à chasse fixe.
// Données : le même jeu enregistré que les tests d'écrans.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/app.dart';

import '../../test/outils/faux_depot.dart';
import '../../test/outils/polices.dart';

const _dossier = 'build/captures';

/// Enregistre l'écran entier en PNG.
Future<void> _capturer(WidgetTester tester, String nom) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image = await captureImage(find.byType(SamaClasseApp).evaluate().single);
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dossier/$nom.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

/// Fait défiler la zone défilante principale (la dernière construite).
Future<void> _defiler(WidgetTester tester, double distance) async {
  await tester.drag(find.byType(Scrollable).last, Offset(0, -distance));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(chargerPolicesReelles);

  for (final (suffixe, echelle) in [('', 1.0), ('_200', 2.0)]) {
    testWidgets('téléphone$suffixe', (tester) async {
      Future<void> ouvrir(String chemin) =>
          lancerApp(tester, depot: FauxDepot(), chemin: chemin, echelleTexte: echelle);

      await ouvrir('/');
      await _capturer(tester, 'tel${suffixe}_01_accueil');

      await ouvrir('/classe/1/matiere/2');
      await _capturer(tester, 'tel${suffixe}_02_matiere');

      await ouvrir('/lecon/1');
      await _capturer(tester, 'tel${suffixe}_03_lecon_a');
      for (final lettre in ['b', 'c', 'd', 'e', 'f']) {
        await _defiler(tester, 600);
        await _capturer(tester, 'tel${suffixe}_03_lecon_$lettre');
      }

      await ouvrir('/lecon/1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('À retenir').first);
      await _capturer(tester, 'tel${suffixe}_04_a_retenir');

      await ouvrir('/lecon/1/exercices');
      await tester.pumpAndSettle();
      for (var i = 1; i <= 5; i++) {
        await _capturer(tester, 'tel${suffixe}_05_exercice${i}_a');
        final valider = find.text('Valider');
        await tester.tap(valider.evaluate().isNotEmpty ? valider : find.text('Voir le corrigé'));
        await _capturer(tester, 'tel${suffixe}_05_exercice${i}_b_corrige');
        // Bas de l'exercice corrigé : corrigé, « Avais-tu juste ? »…
        await _defiler(tester, 3000);
        await _capturer(tester, 'tel${suffixe}_05_exercice${i}_c_bas');
        await tester.tap(find.text(i == 5 ? 'Voir mon résultat' : 'Exercice suivant'));
        await tester.pumpAndSettle();
      }
      await _capturer(tester, 'tel${suffixe}_06_bilan');
    });
  }

  testWidgets('web large', (tester) async {
    for (final (chemin, nom) in [
      ('/', 'web_01_accueil'),
      ('/classe/1/matiere/2', 'web_02_matiere'),
      ('/lecon/1', 'web_03_lecon'),
      ('/lecon/1/exercices', 'web_05_exercice'),
    ]) {
      await lancerApp(tester, depot: FauxDepot(), chemin: chemin, taille: tailleWeb);
      await _capturer(tester, nom);
    }
  });
}
