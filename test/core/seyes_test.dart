// Alignement du texte des leçons sur les lignes Seyès (tâche 7 de la phase 0).
//
// Avec les vraies polices, chaque texte de la page de leçon — paragraphes,
// listes, titres de section, titres cursifs — doit avoir sa ligne de base sur
// une ligne forte du quadrillage, à 1 px près. Avant la correction du
// 13/11/2026, le texte flottait 10 px au-dessus des lignes et les titres
// cursifs tombaient entre deux lignes.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/theme/theme.dart';
import 'package:samaclasse/core/widgets/page_seyes.dart';

import '../outils/faux_depot.dart';
import '../outils/polices.dart';

/// Pour chaque texte de la page Seyès affichée : (texte, écart à la ligne
/// forte la plus proche, en px).
List<(String, double)> _ecarts(WidgetTester tester) {
  final page = find.byType(PageSeyes);
  final haut = tester.renderObject<RenderBox>(page).localToGlobal(Offset.zero).dy;

  // Position de la première ligne forte, calculée comme le fait PageSeyes.
  final contexte = tester.element(find.descendant(of: page, matching: find.byType(Padding)).first);
  final premiereLigne = 16 + ligneDeBase(DefaultTextStyle.of(contexte).style.merge(Styles.lecon));

  // Les boutons (« Faire les exercices ») ne sont pas posés sur les lignes.
  // (On remonte les ancêtres : FilledButton, OutlinedButton… dérivent tous de
  // ButtonStyleButton, et findAncestorWidgetOfExactType ne voit que le type exact.)
  bool dansUnBouton(Element e) {
    var trouve = false;
    e.visitAncestorElements((a) {
      trouve = a.widget is ButtonStyleButton;
      return !trouve;
    });
    return trouve;
  }

  final textes = find
      .descendant(of: page, matching: find.byType(RichText))
      .evaluate()
      .where((e) => !dansUnBouton(e));

  return [
    for (final e in textes)
      () {
        final p = e.renderObject! as RenderParagraph;
        final ligneDeBaseY = p.localToGlobal(Offset.zero).dy - haut +
            p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        var ecart = (ligneDeBaseY - premiereLigne) % interligne;
        if (ecart > interligne / 2) ecart -= interligne;
        return (p.text.toPlainText(), ecart);
      }(),
  ];
}

void main() {
  setUpAll(chargerPolicesReelles);

  Future<void> verifier(WidgetTester tester) async {
    final ecarts = _ecarts(tester);
    expect(ecarts.length, greaterThan(10), reason: 'la page doit contenir du texte');
    final horsLigne = ecarts.where((t) => t.$2.abs() > 1).toList();
    expect(horsLigne, isEmpty, reason: 'textes qui ne reposent pas sur une ligne forte');
  }

  testWidgets('onglet « La leçon » : tout le texte repose sur les lignes', (tester) async {
    // Écran très haut : toute la leçon est construite d'un coup.
    await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1', taille: const Size(390, 6000));
    await tester.pumpAndSettle();
    await verifier(tester);
  });

  testWidgets('onglet « À retenir » : tout le texte repose sur les lignes', (tester) async {
    await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1', taille: const Size(390, 6000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('À retenir').first);
    await tester.pumpAndSettle();
    await verifier(tester);
  });
}
