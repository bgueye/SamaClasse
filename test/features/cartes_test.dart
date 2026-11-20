// « Interroge-moi » (D35) : la logique des cartes, puis l'écran dans la vraie
// application (élève et parent, quatre états, 200 %), et l'encart « Que lui
// demander ce soir ? » de l'écran « Suivi ».
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/revision/cartes_screen.dart';
import 'package:samaclasse/features/revision/outils_cartes.dart';
import 'package:samaclasse/features/suivi/statistiques.dart';

import '../outils/faux_depot.dart';

const _cartes = [
  ElementARetenir(notion: 'Dates', essentiel: '1444 : Cap-Vert.'),
  ElementARetenir(notion: 'Déclin', essentiel: 'Le commerce va vers la côte.'),
  ElementARetenir(notion: 'Réorientation', essentiel: 'Forts et comptoirs.'),
];

/// Fait défiler jusqu'à [cible], laisse le défilement s'appliquer, puis la touche.
Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

/// Leçon 1 du jeu enregistré (4ème, sciences physiques) et ses notions.
final _ligne = (donneesReelles['lecons'] as Map)['1'] as Map<String, dynamic>;
final _notions = Lecon.fromJson(_ligne).aRetenir;

void main() {
  group('SeanceCartes', () {
    test('une carte après l’autre : recto, verso, réponse', () {
      var s = SeanceCartes.depuis(_cartes);
      expect(s.vide, isFalse);
      expect(s.terminee, isFalse);
      expect(s.carte.notion, 'Dates');
      expect(s.retournee, isFalse);
      expect(s.libellePosition(ModeCartes.eleve), 'Carte 1 sur 3');
      expect(s.libellePosition(ModeCartes.parent), 'Question 1 sur 3');

      s = s.retourner();
      expect(s.retournee, isTrue);
      s = s.repondre(sue: true);
      expect(s.carte.notion, 'Déclin');
      expect(s.retournee, isFalse, reason: 'la carte suivante montre son recto');
      expect(s.sues, 1);

      s = s.repondre(sue: false).repondre(sue: true);
      expect(s.terminee, isTrue);
      expect(s.sues, 2);
      expect(s.aRevoir, [1]);
      // Rien ne bouge une fois le tour fini.
      expect(s.repondre(sue: true).sues, 2);
      expect(s.retourner().retournee, isFalse);
    });

    test('revoir les cartes ratées, puis recommencer', () {
      final fin = SeanceCartes.depuis(_cartes).repondre(sue: false).repondre(sue: true).repondre(sue: false);
      final revue = fin.revoirRatees();
      expect(revue.file, [0, 2]);
      expect(revue.position, 0);
      expect(revue.sues, 0);
      expect(revue.aRevoir, isEmpty);
      expect(revue.carte.notion, 'Dates');
      expect(revue.libellePosition(ModeCartes.eleve), 'Carte 1 sur 2');

      final sansRatee = SeanceCartes.depuis(_cartes).repondre(sue: true).repondre(sue: true).repondre(sue: true);
      expect(identical(sansRatee.revoirRatees(), sansRatee), isTrue);
      expect(revue.recommencer().file, [0, 1, 2]);
    });

    test('leçon sans notions : séance vide', () {
      final s = SeanceCartes.depuis(const []);
      expect(s.vide, isTrue);
      expect(s.terminee, isFalse);
      expect(identical(s.repondre(sue: true), s), isTrue);
    });

    test('question du parent et mode dans l’adresse', () {
      expect(questionParent(' Commerce transsaharien '), 'Explique-moi : « Commerce transsaharien ».');
      expect(ModeCartes.depuisAdresse('parent'), ModeCartes.parent);
      expect(ModeCartes.depuisAdresse(null), ModeCartes.eleve);
      expect(ModeCartes.depuisAdresse('autre'), ModeCartes.eleve);
    });
  });

  group('derniereLeconARetenir', () {
    final avec = Lecon.fromJson(_ligne);
    final sans = Lecon.fromJson({..._ligne, 'id': 2, 'a_retenir': <Object>[]});
    final jour = DateTime(2026, 11, 20, 18);

    test('la plus récente de cet enfant, avec des notions', () {
      expect(
        derniereLeconARetenir(
          enfantId: 1,
          lectures: [
            LectureLecon(enfantId: 1, leconId: 1, lueLe: jour.subtract(const Duration(days: 1))),
            // Plus récente, mais sans notions à réciter : sautée.
            LectureLecon(enfantId: 1, leconId: 2, lueLe: jour),
            // Plus récente encore, mais plus publiée : sautée.
            LectureLecon(enfantId: 1, leconId: 99, lueLe: jour.add(const Duration(hours: 1))),
            // Autre enfant.
            LectureLecon(enfantId: 2, leconId: 1, lueLe: jour.add(const Duration(hours: 2))),
          ],
          lecons: [avec, sans],
        )?.id,
        1,
      );
    });

    test('aucune leçon lue : rien à proposer', () {
      expect(derniereLeconARetenir(enfantId: 1, lectures: const [], lecons: [avec]), isNull);
      expect(
        derniereLeconARetenir(enfantId: 1, lectures: [LectureLecon(enfantId: 1, leconId: 2, lueLe: jour)], lecons: [sans]),
        isNull,
      );
    });
  });

  group('Écran', () {
    testWidgets('depuis « À retenir » : cartes, verso, réponses, bilan, cartes ratées', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('À retenir'));
      await tester.pumpAndSettle();
      final bouton = find.text('Interroge-moi');
      await _toucher(tester, bouton);

      expect(find.byType(CartesScreen), findsOneWidget);
      expect(find.text(_notions.first.notion), findsOneWidget);
      expect(find.text(_notions.first.essentiel), findsNothing, reason: 'le verso est caché');
      expect(find.text('Carte 1 sur ${_notions.length}'), findsOneWidget);

      await _toucher(tester, find.text('Retourner la carte'));
      expect(find.text(_notions.first.essentiel), findsOneWidget);

      // Première carte ratée, toutes les autres sues.
      await _toucher(tester, find.text('À revoir'));
      expect(find.text('Carte 2 sur ${_notions.length}'), findsOneWidget);
      for (var i = 1; i < _notions.length; i++) {
        await _toucher(tester, find.text('Retourner la carte'));
        await _toucher(tester, find.text('Je savais'));
      }

      expect(find.text('Cartes terminées'), findsOneWidget);
      expect(find.text('Tu savais ${_notions.length - 1} cartes sur ${_notions.length}.'), findsOneWidget);
      expect(find.text('1 carte à revoir : reprends-la maintenant ou plus tard.'), findsOneWidget);
      expect(find.textContaining('Faire les exercices'), findsOneWidget);
      await _toucher(tester, find.text('Revoir les cartes ratées'));
      expect(find.text('Carte 1 sur 1'), findsOneWidget);
      expect(find.text(_notions.first.notion), findsOneWidget);
    });

    testWidgets('mode parent par l’adresse : question et réponse visibles tout de suite', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/reviser?mode=parent');
      await tester.pumpAndSettle();
      expect(find.text('Faire réciter'), findsOneWidget);
      expect(find.text('Demandez-lui :'), findsOneWidget);
      expect(find.text(questionParent(_notions.first.notion)), findsOneWidget);
      expect(find.text(_notions.first.essentiel), findsOneWidget);
      expect(find.text('Retourner la carte'), findsNothing);

      await _toucher(tester, find.text('Bien répondu'));
      expect(find.text('Question 2 sur ${_notions.length}'), findsOneWidget);

      // Retour au mode élève : la séance repart du début, verso caché.
      await _toucher(tester, find.text('Je révise seul'));
      expect(find.text('Interroge-moi'), findsOneWidget);
      expect(find.text('Carte 1 sur ${_notions.length}'), findsOneWidget);
      expect(find.text(_notions.first.essentiel), findsNothing);
    });

    testWidgets('chargement, puis erreur et « Réessayer »', (tester) async {
      final depot = FauxDepot()
        ..attente = Completer<void>()
        ..pannes['lecon'] = 2; // l'écran de leçon, en dessous, la charge aussi
      await lancerApp(tester, depot: depot, chemin: '/lecon/1/reviser');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      depot.attente!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Impossible de charger'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text(_notions.first.notion), findsOneWidget);
    });

    testWidgets('leçon sans notions, ou absente : message vide', (tester) async {
      final sansNotions = {
        ...donneesReelles,
        'lecons': {
          '1': {..._ligne, 'a_retenir': <Object>[]},
        },
      };
      await lancerApp(tester, depot: FauxDepot(sansNotions), chemin: '/lecon/1/reviser');
      await tester.pumpAndSettle();
      expect(find.text('Pas encore de cartes'), findsOneWidget);
      expect(find.text('Revenir à la leçon'), findsOneWidget);

      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/999/reviser');
      await tester.pumpAndSettle();
      expect(find.text('Leçon pas encore disponible'), findsOneWidget);
    });

    testWidgets('pas de bouton « Interroge-moi » sans notions', (tester) async {
      final sansNotions = {
        ...donneesReelles,
        'lecons': {
          '1': {..._ligne, 'a_retenir': <Object>[]},
        },
      };
      await lancerApp(tester, depot: FauxDepot(sansNotions), chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('À retenir'));
      await tester.pumpAndSettle();
      expect(find.text('Interroge-moi'), findsNothing);
    });

    for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
      testWidgets('pas de débordement à 200 %, élève et parent ($nom)', (tester) async {
        await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/reviser', taille: taille, echelleTexte: 2);
        await tester.pumpAndSettle();
        final retourner = find.text('Retourner la carte');
        await _toucher(tester, retourner);
        expect(find.text(_notions.first.essentiel), findsOneWidget);

        await _toucher(tester, find.text('Je fais réciter'));
        expect(find.text('Demandez-lui :'), findsOneWidget);
      });
    }
  });

  group('Suivi : « Que lui demander ce soir ? »', () {
    testWidgets('la dernière leçon lue ouvre les cartes en mode parent', (tester) async {
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: FauxCompte(
          connecte: 'parent@exemple.sn',
          enfants: [const Enfant(id: 1, prenom: 'Awa', classeId: 1)],
          lectures: [LectureLecon(enfantId: 1, leconId: 1, lueLe: DateTime.now())],
        ),
        chemin: '/suivi',
      );
      await tester.pumpAndSettle();
      expect(find.text('Que lui demander ce soir ?'), findsOneWidget);
      final bouton = find.text('Faire réciter Awa');
      await _toucher(tester, bouton);
      expect(find.byType(CartesScreen), findsOneWidget);
      expect(find.text('Demandez-lui :'), findsOneWidget);
    });

    testWidgets('sans leçon lue : pas d’encart', (tester) async {
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: FauxCompte(connecte: 'parent@exemple.sn', enfants: [const Enfant(id: 1, prenom: 'Awa', classeId: 1)]),
        chemin: '/suivi',
      );
      await tester.pumpAndSettle();
      expect(find.text('Cette semaine'), findsOneWidget);
      expect(find.text('Que lui demander ce soir ?'), findsNothing);
    });
  });
}
