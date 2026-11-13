// Lisibilité des puces de choix (ChoiceChip) : le texte doit avoir une
// couleur et contraster avec le fond (DESIGN.md : 4,5:1 minimum).
//
// Défaut signalé le 13/11/2026 : les puces « Oui, j’avais juste » /
// « Non, je me suis trompé » des exercices à correction manuelle étaient
// blanches sur fond clair. Cause : le thème redéfinissait `chipTheme.labelStyle`
// sans couleur, ce qui écrasait celle de Material 3 ; un texte sans couleur
// est peint en blanc par le moteur de rendu.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/theme/couleurs.dart';
import 'package:samaclasse/core/theme/theme.dart';

import '../outils/faux_depot.dart';

/// Rapport de contraste WCAG entre deux couleurs opaques.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (clair, sombre) = la > lb ? (la, lb) : (lb, la);
  return (clair + 0.05) / (sombre + 0.05);
}

/// Couleur réellement donnée au texte [libelle] (null = peint en blanc).
Color? couleurTexte(WidgetTester tester, String libelle) =>
    tester.renderObject<RenderParagraph>(find.text(libelle)).text.style?.color;

void main() {
  for (final selectionnee in [false, true]) {
    testWidgets('puce du thème : texte coloré et lisible (sélectionnée : $selectionnee)', (tester) async {
      final theme = themeSamaClasse();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: ChoiceChip(label: const Text('Oui, j’avais juste'), selected: selectionnee, onSelected: (_) {}),
          ),
        ),
      ));
      final couleur = couleurTexte(tester, 'Oui, j’avais juste');
      expect(couleur, isNotNull, reason: 'sans couleur, le texte est peint en blanc');
      // Fond Material 3 d'une puce : transparent sur le fond de l'écran, ou
      // `secondaryContainer` une fois sélectionnée.
      final fond = selectionnee ? theme.colorScheme.secondaryContainer : Couleurs.fond;
      expect(contraste(couleur!, fond), greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('exercice à correction manuelle : « Avais-tu juste ? » lisible', (tester) async {
    await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/exercices');
    await tester.pumpAndSettle();
    // Exercice 1 : question de cours, donc correction manuelle.
    await tester.tap(find.text('Voir le corrigé'));
    await tester.pumpAndSettle();

    for (final libelle in ['Oui, j’avais juste', 'Non, je me suis trompé']) {
      await tester.ensureVisible(find.text(libelle));
      await tester.pumpAndSettle();
      final couleur = couleurTexte(tester, libelle);
      expect(couleur, isNotNull, reason: '« $libelle » serait blanc sur blanc');
      expect(contraste(couleur!, Couleurs.fond), greaterThanOrEqualTo(4.5));
    }

    // Une fois choisie, la puce reste lisible.
    await tester.tap(find.text('Oui, j’avais juste'));
    await tester.pumpAndSettle();
    final choisie = couleurTexte(tester, 'Oui, j’avais juste');
    expect(contraste(choisie!, themeSamaClasse().colorScheme.secondaryContainer), greaterThanOrEqualTo(4.5));
  });

  testWidgets('tableau de classement : les catégories à choisir sont lisibles', (tester) async {
    await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/exercices', taille: const Size(390, 3000));
    await tester.pumpAndSettle();
    // Exercice 3 de la leçon publiée : classement « chimique » / « physique ».
    for (final (valider, suivant) in [('Voir le corrigé', 'Exercice suivant'), ('Valider', 'Exercice suivant')]) {
      await tester.tap(find.text(valider));
      await tester.pumpAndSettle();
      await tester.tap(find.text(suivant));
      await tester.pumpAndSettle();
    }
    expect(find.text('Exercice 3 sur 5'), findsOneWidget);

    final puces = find.byType(ChoiceChip);
    expect(puces, findsWidgets);
    for (final libelle in ['Chimique', 'Physique']) {
      final textes = find.descendant(of: puces, matching: find.text(libelle));
      expect(textes, findsWidgets);
      final couleur = tester.renderObject<RenderParagraph>(textes.first).text.style?.color;
      expect(couleur, isNotNull, reason: 'catégorie « $libelle » blanche sur blanc');
      expect(contraste(couleur!, Couleurs.fond), greaterThanOrEqualTo(4.5));
    }
  });
}
