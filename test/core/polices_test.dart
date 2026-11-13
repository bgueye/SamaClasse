// Polices de secours (décision D17) : exposants, flèches, grec et symboles
// mathématiques absents d'Atkinson et de Playwrite.
//
// La couverture des caractères eux-mêmes se vérifie avec
// tool/polices/sous_ensembles.py (et la requête SQL de DESIGN.md) ; ici, on
// vérifie que tous les textes de l'application héritent bien des secours.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/theme/theme.dart';

/// Polices de secours réellement appliquées au texte [libelle].
List<String>? secoursDe(WidgetTester tester, String libelle) =>
    tester.renderObject<RenderParagraph>(find.text(libelle)).text.style?.fontFamilyFallback;

void main() {
  test('les fichiers des polices de secours et leurs licences sont présents', () {
    for (final fichier in [
      'assets/fonts/NotoSansSecours-Regular.ttf',
      'assets/fonts/NotoSansMathSecours-Regular.ttf',
      'assets/fonts/licences/noto-sans-OFL.txt',
      'assets/fonts/licences/noto-sans-math-OFL.txt',
    ]) {
      expect(File(fichier).existsSync(), isTrue, reason: fichier);
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final famille in policesSecours) {
      expect(pubspec, contains('family: $famille'), reason: 'police non déclarée dans pubspec.yaml');
    }
  });

  testWidgets('tous les textes héritent des polices de secours', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: themeSamaClasse(),
      home: Scaffold(
        body: Column(
          children: [
            const Text('10⁻³ texte courant'),
            // Les titres cursifs et les boutons précisent leur police :
            // ils doivent garder les secours du thème.
            Text('Titre → cursif', style: Styles.cahier()),
            FilledButton(onPressed: () {}, child: const Text('ℝ bouton')),
            const Chip(label: Text('≈ puce')),
            // Comme les filtres de l'écran matière : style de puce propre.
            ChoiceChip(
              label: const Text('Δ filtre'),
              selected: true,
              labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    ));

    expect(
      tester.renderObject<RenderParagraph>(find.text('Δ filtre')).text.style?.fontFamily,
      policeTexte,
      reason: 'le filtre doit garder Atkinson',
    );
    for (final libelle in ['10⁻³ texte courant', 'Titre → cursif', 'ℝ bouton', '≈ puce', 'Δ filtre']) {
      expect(secoursDe(tester, libelle), policesSecours, reason: '« $libelle » sans police de secours');
    }
  });
}
