// « Suivi de mes enfants » (phase 3) : calculs de la semaine, derniers
// exercices, leçons disponibles, puis l'écran sur la vraie application avec
// un faux compte.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/services/preferences.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/suivi/statistiques.dart';

import '../outils/faux_depot.dart';

/// Leçon 1 du jeu enregistré (4ème, sciences physiques) : exercices 20 à 24
/// (question de cours, tableau, tableau, vrai ou faux, question de cours).
final Lecon _lecon1 = Lecon.fromJson((donneesReelles['lecons'] as Map)['1'] as Map<String, dynamic>);

ResultatExercice _res(int exerciceId, DateTime quand, {int enfant = 1, bool reussi = true, int? bonnes, int? total}) =>
    ResultatExercice(
      id: '$enfant-$exerciceId-${quand.millisecondsSinceEpoch}',
      enfantId: enfant,
      exerciceId: exerciceId,
      reussi: reussi,
      bonnes: bonnes,
      total: total,
      autoEvaluation: bonnes == null,
      faitLe: quand,
    );

/// Ce qu'un lecteur d'écran annonce pour la case qui contient [texte].

void main() {
  group('Semaine', () {
    test('commence le lundi à 0 h', () {
      // Jeudi 19/11/2026 → lundi 16/11/2026.
      expect(debutSemaine(DateTime(2026, 11, 19, 15, 30)), DateTime(2026, 11, 16));
      // Le lundi même : minuit de ce jour.
      expect(debutSemaine(DateTime(2026, 11, 16, 0, 5)), DateTime(2026, 11, 16));
      // Dimanche 15/11 : semaine commencée le lundi 9/11.
      expect(debutSemaine(DateTime(2026, 11, 15, 23, 59)), DateTime(2026, 11, 9));
    });

    test('résumé en phrases : pluriels, zéros, phrase complète', () {
      const b = BilanSemaine(leconsLues: 3, exercicesFaits: 10, reussis: 8, joursTravailles: 4);
      expect(majuscule(phraseLecons(b)), 'A lu 3 leçons');
      expect(phraseExercices(b), 'a réussi 8 exercices sur 10');
      expect(phraseJours(b), 'a travaillé 4 jours sur 7');
      expect(texteResume('Awa', b),
          'Cette semaine, Awa a lu 3 leçons, a réussi 8 exercices sur 10 et a travaillé 4 jours sur 7.');
      const un = BilanSemaine(leconsLues: 1, exercicesFaits: 1, reussis: 1, joursTravailles: 1);
      expect(texteResume('Awa', un), 'Cette semaine, Awa a lu 1 leçon, a réussi 1 exercice sur 1 et a travaillé 1 jour sur 7.');
      const rien = BilanSemaine(leconsLues: 0, exercicesFaits: 0, reussis: 0);
      expect(texteResume('Awa', rien), 'Cette semaine, Awa n’a pas encore travaillé dans SamaClasse.');
      expect(majuscule(phraseExercices(rien)), 'N’a pas encore fait d’exercice');
    });

    test('jours travaillés : jours distincts, lectures et exercices mêlés', () {
      final jeudi = DateTime(2026, 11, 19, 15);
      final bilan = bilanSemaine(
        enfantId: 1,
        lectures: [LectureLecon(enfantId: 1, leconId: 1, lueLe: DateTime(2026, 11, 16, 9))],
        resultats: [
          _res(20, DateTime(2026, 11, 16, 18)),
          _res(21, DateTime(2026, 11, 18, 10)),
          _res(22, DateTime(2026, 11, 19, 8)),
        ],
        maintenant: jeudi,
      );
      expect(bilan.joursTravailles, 3);
    });

    test('bilan : seulement cet enfant et cette semaine', () {
      final jeudi = DateTime(2026, 11, 19, 15);
      final mardi = DateTime(2026, 11, 17, 10);
      final semainePassee = DateTime(2026, 11, 13, 10);
      final bilan = bilanSemaine(
        enfantId: 1,
        lectures: [
          LectureLecon(enfantId: 1, leconId: 1, lueLe: mardi),
          LectureLecon(enfantId: 1, leconId: 2, lueLe: semainePassee),
          LectureLecon(enfantId: 2, leconId: 1, lueLe: mardi),
        ],
        resultats: [
          _res(20, mardi),
          _res(21, mardi, reussi: false, bonnes: 2, total: 6),
          _res(22, mardi, bonnes: 6, total: 6),
          _res(23, semainePassee),
          _res(20, mardi, enfant: 2),
        ],
        maintenant: jeudi,
      );
      // Mardi seulement : la lecture et les trois exercices du même jour.
      expect(bilan, const BilanSemaine(leconsLues: 1, exercicesFaits: 3, reussis: 2, joursTravailles: 1));
      expect(bilan.pourcentage, 67);
    });

    test('pas d’exercice : pas de pourcentage', () {
      expect(const BilanSemaine(leconsLues: 2, exercicesFaits: 0, reussis: 0).pourcentage, isNull);
      expect(const BilanSemaine(leconsLues: 0, exercicesFaits: 4, reussis: 4).pourcentage, 100);
    });
  });

  group('Derniers exercices', () {
    test('du plus récent au plus ancien, cet enfant seulement, 5 au plus', () {
      final base = DateTime(2026, 11, 17, 10);
      final resultats = [
        for (var i = 0; i < 7; i++) _res(20 + i % 5, base.add(Duration(minutes: i))),
        _res(20, base.add(const Duration(hours: 5)), enfant: 2),
      ];
      final derniers = derniersExercices(enfantId: 1, resultats: resultats, lecons: [_lecon1]);
      expect(derniers, hasLength(5));
      expect(derniers.first.resultat.faitLe, base.add(const Duration(minutes: 6)));
      expect(derniers.every((x) => x.resultat.enfantId == 1), isTrue);
      expect(derniers.first.lecon.titre, _lecon1.titre);
    });

    test('exercice qui n’est plus publié : sauté', () {
      final derniers = derniersExercices(
        enfantId: 1,
        resultats: [_res(9999, DateTime(2026, 11, 17)), _res(21, DateTime(2026, 11, 16), bonnes: 3, total: 6, reussi: false)],
        lecons: [_lecon1],
      );
      expect(derniers.single.exercice.id, 21);
      expect(derniers.single.exercice.type, TypeExercice.tableau);
    });

    test('score en mots', () {
      expect(libelleScore(_res(21, DateTime(2026), reussi: false, bonnes: 2, total: 6)), '2 sur 6');
      expect(libelleScore(_res(20, DateTime(2026))), 'Juste, selon l’enfant');
      expect(libelleScore(_res(20, DateTime(2026), reussi: false)), 'À revoir, selon l’enfant');
    });
  });

  group('Leçons disponibles', () {
    test('filtre par classe', () {
      expect(leconsDeClasse([_lecon1], '4ème'), [_lecon1]);
      expect(leconsDeClasse([_lecon1], 'Seconde L'), isEmpty);
    });

    test('résumé accordé', () {
      expect(resumeDisponibles([]), 'Pas encore de leçon publiée.');
      expect(resumeDisponibles([_lecon1]), '1 leçon et 5 exercices pour l’instant.');
      expect(resumeDisponibles([_lecon1, _lecon1]), '2 leçons et 10 exercices pour l’instant.');
      expect(libelleExercices(1), '1 exercice');
    });
  });

  group('Écran', () {
    final enfants = [
      const Enfant(id: 1, prenom: 'Awa', classeId: 1),
      const Enfant(id: 2, prenom: 'Moussa', classeId: 2),
    ];

    FauxCompte compteAvec({List<Enfant>? profils, List<ResultatExercice>? resultats, List<LectureLecon>? lectures}) =>
        FauxCompte(
          connecte: 'parent@exemple.sn',
          enfants: profils ?? enfants,
          resultats: resultats,
          lectures: lectures,
        );

    testWidgets('sans connexion : renvoie vers l’espace parents', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/suivi');
      await tester.pumpAndSettle();
      expect(find.text('Connectez-vous pour voir le suivi'), findsOneWidget);
      await tester.tap(find.text('Aller à l’espace parents'));
      await tester.pumpAndSettle();
      expect(find.text('Recevoir un code'), findsOneWidget);
    });

    testWidgets('chargement, puis contenu de l’enfant de ce téléphone', (tester) async {
      final maintenant = DateTime.now();
      final compte = compteAvec(
        resultats: [
          _res(21, maintenant, enfant: 2, reussi: false, bonnes: 2, total: 6),
          _res(20, maintenant.subtract(const Duration(minutes: 1)), enfant: 2),
        ],
        lectures: [LectureLecon(enfantId: 2, leconId: 1, lueLe: maintenant)],
      )..attente = Completer();
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: compte,
        preferences: FaussesPreferences(enfant: const EnfantActif(id: 2, prenom: 'Moussa')),
        chemin: '/suivi',
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      compte.attente!.complete();
      await tester.pumpAndSettle();
      // Moussa (enfant de ce téléphone) est affiché d'abord, en phrases.
      expect(find.text('A lu 1 leçon'), findsOneWidget);
      expect(find.text('A réussi 1 exercice sur 2'), findsOneWidget);
      expect(find.text('A travaillé 1 jour sur 7'), findsOneWidget);
      expect(find.text('2 sur 6'), findsOneWidget);
      expect(find.text('Juste, selon l’enfant'), findsOneWidget);
      expect(find.text('Tableau à compléter'), findsOneWidget);
      // Seconde L : pas de leçon publiée dans le jeu de test.
      expect(find.text('Leçons disponibles en Seconde L'), findsOneWidget);
      expect(find.text('Pas encore de leçon publiée.'), findsOneWidget);
    });

    testWidgets('changer d’enfant change les chiffres et les leçons', (tester) async {
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: compteAvec(resultats: [_res(20, DateTime.now(), enfant: 2)]),
        chemin: '/suivi',
      );
      await tester.pumpAndSettle();
      // Sans profil sur ce téléphone : le premier enfant (Awa, 4ème).
      expect(find.text('Leçons disponibles en 4ème'), findsOneWidget);
      expect(find.text('Introduction aux sciences physiques'), findsOneWidget);
      expect(find.text('1 leçon et 5 exercices pour l’instant.'), findsOneWidget);
      expect(find.text('N’a pas encore lu de leçon'), findsOneWidget);
      expect(find.text('N’a pas encore fait d’exercice'), findsOneWidget);
      expect(find.text('N’a pas encore travaillé'), findsOneWidget);
      expect(find.textContaining('Aucun exercice pour l’instant'), findsOneWidget);

      await tester.tap(find.text('Moussa'));
      await tester.pumpAndSettle();
      expect(find.text('Leçons disponibles en Seconde L'), findsOneWidget);
      expect(find.text('A réussi 1 exercice sur 1'), findsOneWidget);
    });

    testWidgets('« Écouter le résumé » et « Envoyer ce résumé »', (tester) async {
      final moteur = FauxMoteurVocal();
      final partage = FauxPartage();
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: compteAvec(
          profils: [enfants.first],
          lectures: [LectureLecon(enfantId: 1, leconId: 1, lueLe: DateTime.now())],
        ),
        moteurVocal: moteur,
        partage: partage,
        chemin: '/suivi',
      );
      await tester.pumpAndSettle();
      const resume = 'Cette semaine, Awa a lu 1 leçon, n’a pas encore fait d’exercice et a travaillé 1 jour sur 7.';

      await tester.tap(find.byTooltip('Écouter le résumé'));
      await tester.pumpAndSettle();
      expect(moteur.vitesse, 0.45);
      expect(moteur.journal, ['langue fr-FR', 'dire $resume']);

      final envoyer = find.text('Envoyer ce résumé');
      await tester.ensureVisible(envoyer);
      await tester.pumpAndSettle();
      await tester.tap(envoyer);
      await tester.pumpAndSettle();
      expect(partage.envois, ['$resume (SamaClasse)']);
    });

    testWidgets('erreur réseau, puis « Réessayer »', (tester) async {
      final compte = compteAvec()..pannes['resultats'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/suivi');
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Cette semaine'), findsOneWidget);
    });

    testWidgets('aucun profil enfant : invitation à en ajouter un', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), compte: compteAvec(profils: []), chemin: '/suivi');
      await tester.pumpAndSettle();
      expect(find.text('Aucun profil pour l’instant'), findsOneWidget);
    });

    testWidgets('un seul enfant : pas de choix, son prénom et sa classe', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), compte: compteAvec(profils: [enfants.first]), chemin: '/suivi');
      await tester.pumpAndSettle();
      expect(find.text('Awa, 4ème'), findsOneWidget);
    });

    testWidgets('ouvert depuis l’espace parents', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), compte: compteAvec(), chemin: '/compte');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir le suivi de mes enfants'));
      await tester.pumpAndSettle();
      expect(find.text('Suivi de mes enfants'), findsOneWidget);
    });

    testWidgets('les résultats en attente sur ce téléphone partent avant l’affichage', (tester) async {
      final envoi = FauxEnvoi();
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: compteAvec(),
        preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa')),
        envoi: envoi,
        chemin: '/suivi',
      );
      await tester.pumpAndSettle();
      // File vide ici : l'envoi est tenté sans rien envoyer, puis l'écran s'affiche.
      expect(find.text('Cette semaine'), findsOneWidget);
    });

    group('pas de débordement à 200 %', () {
      for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
        testWidgets(nom, (tester) async {
          final maintenant = DateTime.now();
          await lancerApp(
            tester,
            depot: FauxDepot(),
            compte: compteAvec(
              profils: [
                const Enfant(id: 1, prenom: 'Aminata Fatou Bintou', classeId: 1),
                const Enfant(id: 2, prenom: 'Moussa', classeId: 2),
              ],
              resultats: [
                _res(21, maintenant, reussi: false, bonnes: 2, total: 6),
                _res(24, maintenant, reussi: false),
              ],
            ),
            chemin: '/suivi',
            taille: taille,
            echelleTexte: 2,
          );
          await tester.pumpAndSettle();
          expect(find.text('Cette semaine'), findsOneWidget);
        });
      }
    });
  });
}
