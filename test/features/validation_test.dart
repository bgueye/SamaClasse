// « Leçons à vérifier » (phase 4) : logique pure, puis l'écran sur la vraie
// application avec une fausse rédaction qui reproduit les règles de la base.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/validation/outils_validation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../outils/faux_depot.dart';

LeconAVerifier _lecon(int id, String titre, List<String> points,
        {String classe = '4ème', int ordre = 9, String matiere = 'SVT', String? artefact}) =>
    LeconAVerifier(
      id: id,
      titre: titre,
      classe: classe,
      ordreClasse: ordre,
      matiere: matiere,
      matiereSlug: 'svt',
      points: points,
      artefactUrl: artefact,
    );

PointLeve _leve(int id, int leconId, String point) =>
    PointLeve(id: id, leconId: leconId, point: point, leveLe: DateTime(2026, 11, 15));

final _digestion = _lecon(2, 'La digestion et l’absorption', ['Étapes gastrique et intestinale ?', 'Origine des exercices ?']);
final _ecosysteme = _lecon(10, 'La structure d’un écosystème', ['Peuplement animal à rédiger.'],
    classe: 'Seconde L', ordre: 11);

void main() {
  group('Logique pure', () {
    test('points restants : comparés au texte, leçon par leçon', () {
      final leves = [_leve(1, 2, 'Origine des exercices ?'), _leve(2, 10, 'Origine des exercices ?')];
      expect(pointsRestants(_digestion, leves), ['Étapes gastrique et intestinale ?']);
      expect(pointsRestants(_ecosysteme, leves), ['Peuplement animal à rédiger.']);
    });

    test('pastille', () {
      expect(libellePastille(0), 'Prête');
      expect(libellePastille(1), '1 point');
      expect(libellePastille(4), '4 points');
    });

    test('résumé accordé', () {
      expect(resumeValidation([], []), 'Aucune leçon n’attend ta relecture pour l’instant.');
      expect(resumeValidation([_digestion, _ecosysteme], []),
          startsWith('2 leçons attendent ta relecture, 3 points à lever avec les cahiers.'));
      expect(resumeValidation([_ecosysteme], []), startsWith('1 leçon attend ta relecture, 1 point à lever'));
      expect(resumeValidation([_ecosysteme], [_leve(1, 10, 'Peuplement animal à rédiger.')]),
          startsWith('1 leçon attend ta relecture, tous les points sont levés.'));
    });

    test('tri : classe, puis matière, puis titre', () {
      final histoire = _lecon(6, 'L’Afrique de l’Ouest', [], matiere: 'Géographie');
      expect(trierLecons([_ecosysteme, _digestion, histoire]).map((l) => l.id), [6, 2, 10]);
    });

    test('messages d’erreur', () {
      expect(messageErreurRedaction(const PostgrestException(message: 'Il reste 1 point(s) à vérifier.', code: 'P0001')),
          'Il reste 1 point(s) à vérifier.');
      expect(messageErreurRedaction(const PostgrestException(message: 'denied', code: '42501')), contains('droits de rédacteur'));
      expect(messageErreurRedaction(const SocketException('réseau')), contains('Pas de connexion'));
    });

    test('lecture d’une ligne de la base', () {
      final l = LeconAVerifier.fromJson({
        'id': 2,
        'titre': 'La digestion',
        'points_a_verifier': ['a', 'b'],
        'artefact_url': 'https://claude.ai/artifact/x',
        'chapitres': {
          'classes': {'libelle': '4ème', 'ordre': 9},
          'matieres': {'nom': 'SVT', 'slug': 'svt'},
        },
      });
      expect((l.classe, l.ordreClasse, l.matiere, l.artefactUrl), ('4ème', 9, 'SVT', 'https://claude.ai/artifact/x'));
      expect(l.points, ['a', 'b']);
      expect(libelleClasseMatiere(l), '4ème, SVT');
    });
  });

  group('Écran', () {
    FauxCompte connecte() => FauxCompte(connecte: 'redacteur@exemple.sn');

    testWidgets('sans connexion : réservé aux rédacteurs', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/validation');
      await tester.pumpAndSettle();
      expect(find.text('Réservé aux rédacteurs'), findsOneWidget);
      expect(find.text('Aller à l’espace parents'), findsOneWidget);
    });

    testWidgets('compte non rédacteur : réservé, et aucun accès visible ailleurs', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), chemin: '/validation');
      await tester.pumpAndSettle();
      expect(find.text('Réservé aux rédacteurs'), findsOneWidget);

      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), chemin: '/compte');
      await tester.pumpAndSettle();
      expect(find.text('Leçons à vérifier'), findsNothing);
    });

    testWidgets('lever les points, puis publier', (tester) async {
      final redaction = FausseRedaction(redacteur: true, lecons: [_digestion, _ecosysteme]);
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      expect(find.textContaining('2 leçons attendent ta relecture, 3 points'), findsOneWidget);
      expect(find.text('2 points'), findsOneWidget);
      expect(find.text('4ème, SVT'), findsOneWidget);

      await tester.tap(find.text('La digestion et l’absorption'));
      await tester.pumpAndSettle();
      expect(find.text('Coche tous les points pour publier'), findsOneWidget);
      // Bouton inactif tant qu'il reste des points.
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Coche tous les points pour publier')).onPressed, isNull);

      await tester.tap(find.text('Étapes gastrique et intestinale ?'));
      await tester.pumpAndSettle();
      expect(find.text('1 point'), findsNWidgets(2), reason: 'cette leçon et l’autre');
      await tester.tap(find.text('Origine des exercices ?'));
      await tester.pumpAndSettle();
      expect(redaction.leves.map((p) => p.point), ['Étapes gastrique et intestinale ?', 'Origine des exercices ?']);
      expect(find.text('Prête'), findsOneWidget);

      await tester.tap(find.text('Publier la leçon'));
      await tester.pumpAndSettle();
      expect(find.text('Publier « La digestion et l’absorption » ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Publier'));
      await tester.pumpAndSettle();

      expect(redaction.publiees, [2]);
      expect(find.text('Publiée'), findsOneWidget);
      expect(find.text('Leçon publiée'), findsOneWidget);
      expect(find.textContaining('est publiée. Les élèves la verront'), findsOneWidget);
      expect(find.textContaining('1 leçon attend ta relecture'), findsOneWidget);
    });

    testWidgets('décocher annule le point (avant publication)', (tester) async {
      final redaction = FausseRedaction(
        redacteur: true,
        lecons: [_ecosysteme],
        leves: [_leve(7, 10, 'Peuplement animal à rédiger.')],
      );
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      await tester.tap(find.text('La structure d’un écosystème'));
      await tester.pumpAndSettle();
      expect(find.text('Publier la leçon'), findsOneWidget);

      await tester.tap(find.text('Peuplement animal à rédiger.'));
      await tester.pumpAndSettle();
      expect(redaction.leves, isEmpty);
      expect(find.text('Coche tous les points pour publier'), findsOneWidget);
    });

    testWidgets('erreur en levant un point : message, case inchangée', (tester) async {
      final redaction = FausseRedaction(redacteur: true, lecons: [_ecosysteme])..pannes['lever'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      await tester.tap(find.text('La structure d’un écosystème'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peuplement animal à rédiger.'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pas de connexion'), findsOneWidget);
      expect(redaction.leves, isEmpty);
      expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);
    });

    testWidgets('chargement en erreur, puis « Réessayer »', (tester) async {
      final redaction = FausseRedaction(redacteur: true, lecons: [_ecosysteme])..pannes['lecons'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('La structure d’un écosystème'), findsOneWidget);
    });

    testWidgets('rien à vérifier', (tester) async {
      await lancerApp(tester,
          depot: FauxDepot(), compte: connecte(), redaction: FausseRedaction(redacteur: true), chemin: '/validation');
      await tester.pumpAndSettle();
      expect(find.text('Rien à vérifier'), findsOneWidget);
    });

    testWidgets('rédacteur : accès depuis l’espace parents et depuis le suivi', (tester) async {
      final redaction = FausseRedaction(redacteur: true, lecons: [_ecosysteme]);
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/compte');
      await tester.pumpAndSettle();
      // Compte rédacteur sans profil enfant : le bouton est là quand même.
      await tester.tap(find.text('Leçons à vérifier'));
      await tester.pumpAndSettle();
      expect(find.text('La structure d’un écosystème'), findsOneWidget);

      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/suivi');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Leçons à vérifier'));
      await tester.pumpAndSettle();
      expect(find.text('La structure d’un écosystème'), findsOneWidget);
    });

    group('pas de débordement à 200 %', () {
      for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
        testWidgets(nom, (tester) async {
          final redaction = FausseRedaction(redacteur: true, lecons: [
            _lecon(6, 'L’Afrique de l’Ouest : étude de situation', [
              '6 000 km d’ouest en est : chiffre qui paraît trop élevé (plutôt 3 500 à 4 000 km). Vérifier.',
              'Latitudes absentes du cahier.',
            ], matiere: 'Géographie', artefact: 'https://claude.ai/artifact/x'),
            _ecosysteme,
          ]);
          await lancerApp(tester,
              depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/validation', taille: taille, echelleTexte: 2);
          await tester.pumpAndSettle();
          // À 200 %, la liste commence sous le bas de l'écran.
          final titre = find.text('L’Afrique de l’Ouest : étude de situation');
          await tester.scrollUntilVisible(titre, 200, scrollable: find.byType(Scrollable).first);
          await tester.ensureVisible(titre);
          await tester.pumpAndSettle();
          await tester.tap(titre);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('Ouvrir la leçon pour la corriger'), 200,
              scrollable: find.byType(Scrollable).first);
          expect(find.text('Ouvrir la leçon pour la corriger'), findsOneWidget);
        });
      }
    });
  });
}
