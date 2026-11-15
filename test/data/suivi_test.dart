// Suivi des enfants (phase 3, D24) : file d'attente des lectures et des
// résultats, envoi au retour du réseau, sans doublon ni texte saisi.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/services/preferences.dart';
import 'package:samaclasse/data/data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../outils/faux_depot.dart';

final _midi = DateTime.utc(2026, 11, 15, 12);

/// Service prêt à l'emploi : parent connecté, profil « Awa » (id 1) choisi.
({SuiviResultats suivi, FauxEnvoi envoi, FauxStockageFile stockage, FauxCompte compte}) _service({
  bool connecte = true,
  bool avecEnfant = true,
  FauxEnvoi? envoi,
}) {
  final compte = FauxCompte(connecte: connecte ? 'parent@exemple.sn' : null);
  final e = envoi ?? FauxEnvoi();
  final stockage = FauxStockageFile();
  final suivi = SuiviResultats(
    compte: compte,
    preferences: FaussesPreferences(enfant: avecEnfant ? const EnfantActif(id: 1, prenom: 'Awa') : null),
    envoi: e,
    stockage: stockage,
    horloge: () => _midi,
  );
  addTearDown(suivi.arreter);
  return (suivi: suivi, envoi: e, stockage: stockage, compte: compte);
}

const _juste = CorrectionAuto([true, true, true]);
const _partiel = CorrectionAuto([true, false, true]);

/// L'envoi aboutit côté serveur mais la réponse se perd (réseau coupé au
/// mauvais moment) : le téléphone croit à un échec et renverra.
class _ReponsePerdue extends FauxEnvoi {
  bool perdre = true;

  @override
  Future<void> envoyerResultats(List<ResultatEnAttente> resultats) async {
    await super.envoyerResultats(resultats);
    if (perdre) {
      perdre = false;
      throw const SocketException('Réponse perdue (test)');
    }
  }
}

void main() {
  group('Logique pure', () {
    test('UUID version 4, tous différents', () {
      final forme = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      final ids = {for (var i = 0; i < 500; i++) genererUuid()};
      expect(ids, hasLength(500));
      expect(ids.every(forme.hasMatch), isTrue);
      // Avec un hasard fixé, le résultat est reproductible.
      expect(genererUuid(Random(1)), genererUuid(Random(1)));
    });

    ResultatEnAttente? depuis(Correction c, {bool? auto}) => resultatDepuis(
          correction: c,
          autoEvaluation: auto,
          enfantId: 1,
          exerciceId: 7,
          maintenant: _midi,
          nouvelId: () => 'id',
        );

    test('exercice corrigé par l’application : score et « réussi »', () {
      final r = depuis(_juste)!;
      expect((r.reussi, r.bonnes, r.total, r.autoEvaluation), (true, 3, 3, false));
      final p = depuis(_partiel)!;
      expect((p.reussi, p.bonnes, p.total), (false, 2, 3));
    });

    test('exercice comparé au corrigé : « Avais-tu juste ? », sans score', () {
      final r = depuis(const CorrectionManuelle('corrigé'), auto: true)!;
      expect((r.reussi, r.bonnes, r.total, r.autoEvaluation), (true, null, null, true));
      expect(depuis(const CorrectionManuelle('corrigé'), auto: false)!.reussi, isFalse);
      // Pas encore de réponse à « Avais-tu juste ? » : rien à noter.
      expect(depuis(const CorrectionManuelle('corrigé')), isNull);
    });

    test('réponse incomplète : rien à noter', () {
      expect(depuis(const ReponseInvalide('incomplet')), isNull);
    });

    test('jamais de texte saisi dans ce qui part', () {
      final r = depuis(_juste)!;
      expect(r.toJson().keys.toSet(),
          {'id', 'enfant_id', 'exercice_id', 'reussi', 'bonnes', 'total', 'auto_evaluation', 'fait_le'});
    });

    test('file : aller-retour, et contenu illisible ignoré', () {
      final file = const FileEnvoi()
          .avecResultat(depuis(_juste)!)
          .avecLecture(LectureEnAttente(enfantId: 1, leconId: 3, lueLe: _midi));
      final relue = decoderFile(encoderFile(file));
      expect(relue.resultats.single.toJson(), file.resultats.single.toJson());
      expect(relue.lectures.single.toJson(), file.lectures.single.toJson());
      expect(decoderFile('pas du json').estVide, isTrue);
      expect(decoderFile('{"version": 2, "resultats": [], "lectures": []}').estVide, isTrue);
    });

    test('file : une seule lecture par enfant et par leçon, la plus récente', () {
      final plusTard = _midi.add(const Duration(hours: 1));
      final file = const FileEnvoi()
          .avecLecture(LectureEnAttente(enfantId: 1, leconId: 3, lueLe: _midi))
          .avecLecture(LectureEnAttente(enfantId: 1, leconId: 3, lueLe: plusTard))
          .avecLecture(LectureEnAttente(enfantId: 2, leconId: 3, lueLe: _midi));
      expect(file.lectures, hasLength(2));
      expect(file.lectures.firstWhere((l) => l.enfantId == 1).lueLe, plusTard);
    });

    test('refus définitifs et erreurs passagères', () {
      for (final code in ['42501', '23503', '23514']) {
        expect(estRefusDefinitif(PostgrestException(message: 'refus', code: code)), isTrue, reason: code);
      }
      expect(estRefusDefinitif(const SocketException('réseau')), isFalse);
      expect(estRefusDefinitif(const PostgrestException(message: 'JWT expired', code: 'PGRST301')), isFalse);
    });
  });

  group('Service', () {
    test('sans parent connecté : rien n’est noté ni envoyé', () async {
      final s = _service(connecte: false);
      await s.suivi.noterResultat(exerciceId: 7, correction: _juste);
      await s.suivi.noterLecture(3);
      expect(await s.suivi.enAttente(), 0);
      expect(s.envoi.appels, 0);
    });

    test('sans profil enfant sur ce téléphone : rien n’est noté', () async {
      final s = _service(avecEnfant: false);
      await s.suivi.noterResultat(exerciceId: 7, correction: _juste);
      expect(await s.suivi.enAttente(), 0);
    });

    test('avec réseau : envoyé tout de suite, file vide', () async {
      final s = _service();
      await s.suivi.noterResultat(exerciceId: 7, correction: _juste);
      await s.suivi.noterLecture(3);
      expect(s.envoi.resultatsRecus.single.exerciceId, 7);
      expect(s.envoi.resultatsRecus.single.enfantId, 1);
      expect(s.envoi.lecturesRecues.single.leconId, 3);
      expect(await s.suivi.enAttente(), 0);
    });

    test('hors connexion : gardé, puis envoyé au retour du réseau', () async {
      final s = _service();
      s.envoi.enPanne = true;
      await s.suivi.noterResultat(exerciceId: 7, correction: _juste);
      await s.suivi.noterResultat(exerciceId: 8, correction: _partiel);
      await s.suivi.noterLecture(3);
      expect(await s.suivi.enAttente(), 3);
      expect(s.envoi.resultatsRecus, isEmpty);

      s.envoi.enPanne = false;
      await s.suivi.envoyer();
      expect(s.envoi.resultatsRecus.map((r) => r.exerciceId), [7, 8]);
      expect(s.envoi.lecturesRecues, hasLength(1));
      expect(await s.suivi.enAttente(), 0);
      // L'heure gardée est celle de l'exercice, pas celle de l'envoi.
      expect(s.envoi.resultatsRecus.first.faitLe, _midi);
    });

    test('réponse perdue puis renvoi : aucun doublon', () async {
      final s = _service(envoi: _ReponsePerdue());
      await s.suivi.noterResultat(exerciceId: 7, correction: _juste);
      // Reçu par le serveur, mais le téléphone l'a gardé.
      expect(s.envoi.resultatsRecus, hasLength(1));
      expect(await s.suivi.enAttente(), 1);

      await s.suivi.envoyer();
      expect(s.envoi.resultatsRecus, hasLength(1), reason: 'même identifiant : ignoré');
      expect(await s.suivi.enAttente(), 0);
    });

    test('ligne refusée par la base : abandonnée, les autres partent', () async {
      final s = _service();
      s.envoi
        ..enPanne = true
        ..refuses.add(7);
      await s.suivi.noterResultat(exerciceId: 7, correction: _juste);
      await s.suivi.noterResultat(exerciceId: 8, correction: _juste);

      s.envoi.enPanne = false;
      await s.suivi.envoyer();
      expect(s.envoi.resultatsRecus.map((r) => r.exerciceId), [8]);
      expect(await s.suivi.enAttente(), 0, reason: 'la ligne refusée ne bloque pas la file');
    });

    test('connexion du parent : ce qui attendait part', () async {
      final s = _service();
      s.envoi.enPanne = true;
      await s.suivi.noterResultat(exerciceId: 7, correction: _juste);
      await s.compte.deconnecter();
      s.envoi.enPanne = false;

      // Déconnecté : la file attend.
      await s.suivi.envoyer();
      expect(s.envoi.resultatsRecus, isEmpty);

      await s.compte.verifierCode('parent@exemple.sn', FauxCompte.codeValable);
      await s.suivi.envoyer(); // attend la fin de l'envoi déclenché par la connexion
      expect(s.envoi.resultatsRecus.single.exerciceId, 7);
    });
  });

  group('Écrans', () {
    testWidgets('ouvrir une leçon la note comme lue', (tester) async {
      final envoi = FauxEnvoi();
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: FauxCompte(connecte: 'parent@exemple.sn'),
        preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa')),
        envoi: envoi,
        chemin: '/lecon/1',
      );
      await tester.pumpAndSettle();
      expect(envoi.lecturesRecues.map((l) => (l.enfantId, l.leconId)), contains((1, 1)));
    });

    testWidgets('série d’exercices : les auto-évaluations sont envoyées', (tester) async {
      final envoi = FauxEnvoi();
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: FauxCompte(connecte: 'parent@exemple.sn'),
        preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa')),
        envoi: envoi,
        chemin: '/lecon/1/exercices',
      );
      await tester.pumpAndSettle();

      // Leçon 1 du jeu enregistré : 5 exercices, dont 2 questions de cours
      // (comparées au corrigé). Réponses laissées vides pour les autres.
      for (var i = 1; i <= 5; i++) {
        final valider = find.text('Valider');
        await tester.tap(valider.evaluate().isNotEmpty ? valider : find.text('Voir le corrigé'));
        await tester.pumpAndSettle();
        final oui = find.text('Oui, j’avais juste');
        if (oui.evaluate().isNotEmpty) {
          await tester.ensureVisible(oui);
          await tester.pumpAndSettle();
          await tester.tap(oui);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(i == 5 ? 'Voir mon résultat' : 'Exercice suivant'));
        await tester.pumpAndSettle();
      }

      final autos = envoi.resultatsRecus.where((r) => r.autoEvaluation).toList();
      expect(autos.map((r) => r.exerciceId).toSet(), {20, 24});
      expect(autos.every((r) => r.reussi && r.enfantId == 1), isTrue);
      // Chaque exercice n'est noté qu'une fois.
      final ids = envoi.resultatsRecus.map((r) => r.exerciceId).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    testWidgets('sans compte : rien n’est envoyé', (tester) async {
      final envoi = FauxEnvoi();
      await lancerApp(tester, depot: FauxDepot(), envoi: envoi, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      expect(envoi.appels, 0);
    });
  });
}
