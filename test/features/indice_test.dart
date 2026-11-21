// « Un indice avant le corrigé » (D39, maquette `Indice`) : lecture de la
// colonne `indice`, bouton « Voir un indice » seulement avant la correction,
// encadré qui reste affiché, remise à zéro par « Recommencer », 200 %.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';

import '../outils/faux_depot.dart';

const _indice = 'Relis la notion « Phénomène physique » dans **À retenir**.';

/// Le jeu enregistré, avec un indice sur certains exercices de la leçon 1
/// (exercices 20 à 24, dans l'ordre).
FauxDepot _depotAvecIndices(Map<int, String> indices) {
  final donnees = jsonDecode(jsonEncode(donneesReelles)) as Map<String, dynamic>;
  final lecon = (donnees['lecons'] as Map)['1'] as Map<String, dynamic>;
  for (final e in (lecon['exercices'] as List).cast<Map<String, dynamic>>()) {
    final indice = indices[e['id']];
    if (indice != null) e['indice'] = indice;
  }
  return FauxDepot(donnees);
}

/// Fait défiler la liste jusqu'à [cible] (à 200 %, elle n'est pas encore construite).
Future<void> _montrer(WidgetTester tester, Finder cible) async {
  if (cible.evaluate().isEmpty) {
    await tester.scrollUntilVisible(cible, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
}

/// Valide l'exercice affiché (« Valider » ou « Voir le corrigé »).
Future<void> _valider(WidgetTester tester) async {
  final valider = find.text('Valider');
  await tester.tap(valider.evaluate().isNotEmpty ? valider : find.text('Voir le corrigé'));
  await tester.pumpAndSettle();
}

void main() {
  group('Modèle', () {
    Map<String, dynamic> ligne([Object? indice]) => {
          'id': 1,
          'ordre': 1,
          'niveau': 'je_connais',
          'type': 'question_cours',
          'enonce': 'Définis.',
          'donnees': null,
          'reponse': null,
          'corrige': null,
          'indice': ?indice,
        };

    test('indice lu, absent ou blanc devient null', () {
      expect(Exercice.fromJson(ligne(_indice)).indice, _indice);
      expect(Exercice.fromJson(ligne()).indice, isNull, reason: 'copie d’avant la colonne');
      expect(Exercice.fromJson(ligne('   ')).indice, isNull);
    });
  });

  group('Écran d’exercices', () {
    testWidgets('sans indice : pas de bouton', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/exercices');
      await tester.pumpAndSettle();
      expect(find.text('Voir un indice'), findsNothing);
    });

    testWidgets('« Voir un indice » : encadré, qui reste après le corrigé', (tester) async {
      await lancerApp(tester, depot: _depotAvecIndices({20: _indice}), chemin: '/lecon/1/exercices');
      await tester.pumpAndSettle();

      await _montrer(tester, find.text('Voir un indice'));
      await tester.tap(find.text('Voir un indice'));
      await tester.pumpAndSettle();
      expect(find.text('Indice'), findsOneWidget);
      expect(find.textContaining('Phénomène physique'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget, reason: 'le bouton a disparu');

      await _valider(tester);
      expect(find.text('Indice'), findsOneWidget, reason: 'l’indice reste affiché avec le corrigé');
      expect(find.text('Compare avec le corrigé'), findsOneWidget);
    });

    testWidgets('corrigé vu sans indice : le bouton disparaît', (tester) async {
      await lancerApp(tester, depot: _depotAvecIndices({20: _indice}), chemin: '/lecon/1/exercices');
      await tester.pumpAndSettle();
      expect(find.text('Voir un indice'), findsOneWidget);
      await _valider(tester);
      expect(find.text('Voir un indice'), findsNothing);
      expect(find.text('Indice'), findsNothing);
    });

    testWidgets('chaque exercice a son indice ; « Recommencer » les referme', (tester) async {
      await lancerApp(
        tester,
        depot: _depotAvecIndices({20: _indice, 21: 'Pense aux trois états de la matière.'}),
        chemin: '/lecon/1/exercices',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir un indice'));
      await tester.pumpAndSettle();
      await _valider(tester);
      await _montrer(tester, find.text('Exercice suivant'));
      await tester.tap(find.text('Exercice suivant'));
      await tester.pumpAndSettle();

      // Exercice 2 : son propre bouton, l'indice du 1 n'est pas affiché.
      expect(find.textContaining('Phénomène physique'), findsNothing);
      await _montrer(tester, find.text('Voir un indice'));
      await tester.tap(find.text('Voir un indice'));
      await tester.pumpAndSettle();
      expect(find.text('Pense aux trois états de la matière.'), findsOneWidget);

      // Fin de la série, puis « Recommencer » : retour à l'exercice 1, indice fermé.
      for (var i = 2; i <= 5; i++) {
        await _valider(tester);
        final suite = find.text(i == 5 ? 'Voir mon résultat' : 'Exercice suivant');
        await _montrer(tester, suite);
        await tester.tap(suite);
        await tester.pumpAndSettle();
      }
      await _montrer(tester, find.text('Recommencer'));
      await tester.tap(find.text('Recommencer'));
      await tester.pumpAndSettle();
      expect(find.text('Exercice 1 sur 5'), findsOneWidget);
      expect(find.text('Indice'), findsNothing);
      expect(find.text('Voir un indice'), findsOneWidget);
    });

    for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
      testWidgets('sans débordement à 200 % ($nom)', (tester) async {
        await lancerApp(
          tester,
          depot: _depotAvecIndices({20: '$_indice Cherche ensuite si la nature du corps change : c’est la clé.'}),
          chemin: '/lecon/1/exercices',
          taille: taille,
          echelleTexte: 2,
        );
        await tester.pumpAndSettle();
        await _montrer(tester, find.text('Voir un indice'));
        await tester.tap(find.text('Voir un indice'));
        await tester.pumpAndSettle();
        expect(find.text('Indice'), findsOneWidget);
      });
    }
  });
}
