// Mode projection (D35) : découpage de la leçon en diapositives, puis
// l'écran (boutons, clavier, quitter, quatre états, téléphone et web).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/lecon/lecon_screen.dart';
import 'package:samaclasse/features/projection/outils_projection.dart';
import 'package:samaclasse/features/projection/projection_screen.dart';

import '../outils/faux_depot.dart';

final _ligne = (donneesReelles['lecons'] as Map)['1'] as Map<String, dynamic>;
final _lecon = Lecon.fromJson(_ligne);

Lecon _avec({String? corps, String? introduction, List<String> objectifs = const [], List<Object> aRetenir = const []}) =>
    Lecon.fromJson({
      ..._ligne,
      'corps': corps,
      'introduction': introduction,
      'objectifs': objectifs,
      'a_retenir': aRetenir,
    });

void main() {
  group('Diapositives', () {
    test('ouverture, une par partie « ## », puis « À retenir »', () {
      final d = diapositives(_avec(
        objectifs: ['Distinguer'],
        introduction: 'Intro.',
        corps: 'Avant.\n## I. Première\nTexte 1\n### 1) Sous-partie\nTexte 1b\n## II. Seconde\nTexte 2',
        aRetenir: [
          {'notion': 'Gaz', 'essentiel': 'Ni forme ni volume'},
        ],
      ));
      expect([for (final x in d) x.titre], [_lecon.titre, 'I. Première', 'II. Seconde', 'À retenir']);
      expect(d[0].markdown, '**Ce que tu vas apprendre**\n\n- Distinguer\n\nIntro.\n\nAvant.');
      expect(d[1].markdown, 'Texte 1\n### 1) Sous-partie\nTexte 1b', reason: 'les « ### » restent dans la partie');
      expect(d.last.markdown, '**Gaz** : Ni forme ni volume');
    });

    test('sans ouverture ni titres : une seule diapositive, jamais aucune', () {
      expect([for (final x in diapositives(_avec(corps: '## I. Seule\nTexte'))) x.titre], ['I. Seule']);
      final vide = diapositives(_avec());
      expect(vide.length, 1);
      expect(vide.single.titre, _lecon.titre);
    });

    test('vraie leçon : quatre parties', () {
      final d = diapositives(_lecon);
      expect(d.where((x) => RegExp(r'^[IV]+\.').hasMatch(x.titre)).length, 4);
      expect(d.last.titre, 'À retenir');
    });

    test('agrandissement selon la largeur, borné', () {
      expect(agrandissementProjection(390), 1.2);
      expect(agrandissementProjection(1280), closeTo(2.13, 0.01));
      expect(agrandissementProjection(4000), 2.4);
    });
  });

  group('Écran', () {
    final nombre = diapositives(_lecon).length;

    testWidgets('boutons et clavier, puis « Quitter la projection »', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1', taille: tailleWeb);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Projeter la leçon'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectionScreen), findsOneWidget);
      expect(find.text('Partie 1 sur $nombre'), findsOneWidget);

      await tester.tap(find.byTooltip('Partie suivante'));
      await tester.pumpAndSettle();
      expect(find.text('Partie 2 sur $nombre'), findsOneWidget);
      expect(find.text('I. Phénomènes physiques et phénomènes chimiques'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Partie 3 sur $nombre'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Partie 2 sur $nombre'), findsOneWidget);

      // Pas de retour avant la première ni d'avance après la dernière.
      for (var i = 0; i < nombre + 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
      }
      await tester.pumpAndSettle();
      expect(find.text('Partie $nombre sur $nombre'), findsOneWidget);
      expect(find.text('À retenir'), findsOneWidget);

      await tester.tap(find.text('Quitter la projection'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectionScreen), findsNothing);
      expect(find.byType(LeconScreen), findsOneWidget);
    });

    testWidgets('Échap quitte ; ouverte directement, elle revient à la leçon', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/projection', taille: tailleWeb);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(LeconScreen), findsOneWidget);
    });

    testWidgets('pas d’icône de projection sur un téléphone', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Projeter la leçon'), findsNothing);
    });

    testWidgets('chargement, erreur et « Réessayer », leçon absente', (tester) async {
      final depot = FauxDepot()
        ..attente = Completer<void>()
        ..pannes['lecon'] = 2; // l'écran de leçon, en dessous, la charge aussi
      await lancerApp(tester, depot: depot, chemin: '/lecon/1/projection', taille: tailleWeb);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      depot.attente!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Impossible de charger'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Partie 1 sur $nombre'), findsOneWidget);

      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/999/projection', taille: tailleWeb);
      await tester.pumpAndSettle();
      expect(find.text('Leçon pas encore disponible'), findsOneWidget);
    });

    for (final (nom, taille, echelle) in [
      ('téléphone à 200 %', tailleTelephone, 2.0),
      ('web large', tailleWeb, 1.0),
      ('web large à 200 %', tailleWeb, 2.0),
    ]) {
      testWidgets('pas de débordement ($nom)', (tester) async {
        await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/projection', taille: taille, echelleTexte: echelle);
        await tester.pumpAndSettle();
        for (var i = 0; i < nombre; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
        }
        expect(find.text('Partie $nombre sur $nombre'), findsOneWidget);
      });
    }
  });
}
