// Corrections des leçons publiées, versions et rôle validateur (D33) :
// logique pure, puis les écrans sur la vraie application avec une fausse
// rédaction qui reproduit les règles de la base.

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/schemas/outils_schemas.dart';
import 'package:samaclasse/features/validation/outils_validation.dart';

import '../outils/faux_depot.dart';

const _corps = 'Premier paragraphe.\n\nDeuxième paragraphe.';

TexteLecon _texte({bool publiee = true, String corps = _corps}) =>
    TexteLecon(id: 1, titre: 'Introduction aux sciences physiques', publiee: publiee, introduction: 'Intro.', corps: corps);

CorrectionLecon _correction({int id = 50, bool parMoi = false, bool corrigee = true, List<String>? points}) => CorrectionLecon(
      id: id,
      leconId: 1,
      titreEnLigne: 'Introduction aux sciences physiques',
      classe: '4ème',
      ordreClasse: 9,
      matiere: 'Sciences physiques',
      matiereSlug: 'sciences-physiques',
      texte: const TexteRedige(
        titre: 'Introduction aux sciences physiques',
        objectifs: ['Distinguer physique et chimie'],
        introduction: 'Intro corrigée.',
        corps: 'Paragraphe corrigé.',
        aRetenir: [ElementARetenir(notion: 'Fusion', essentiel: 'Solide vers liquide.')],
      ),
      points: points ?? const ['La date du cours est-elle juste ?'],
      motif: 'La date du cours est fausse',
      demandeeLe: DateTime(2026, 11, 16, 10),
      modifieeLe: corrigee ? DateTime(2026, 11, 16, 12) : DateTime(2026, 11, 16, 10),
      parMoi: parMoi,
    );

VersionLecon _version(int id, int numero, String motif, {String corps = _corps}) => VersionLecon(
      id: id,
      leconId: 1,
      numero: numero,
      motif: motif,
      publieeLe: DateTime(2026, 11, numero + 10),
      texte: TexteRedige(titre: 'Introduction aux sciences physiques', objectifs: const [], introduction: 'Intro.', corps: corps, aRetenir: const []),
    );

PointLeve _leve(int id, String point, {int? correctionId, int leconId = 1}) =>
    PointLeve(id: id, leconId: leconId, point: point, leveLe: DateTime(2026, 11, 16), correctionId: correctionId);

FauxCompte _connecte() => FauxCompte(connecte: 'redacteur@exemple.sn');

/// Fait défiler jusqu'à [cible] dans la liste de l'écran, puis la touche.
Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
}

void main() {
  group('Logique pure', () {
    test('points saisis un par ligne : nettoyés, sans doublon', () {
      expect(decouperPoints('  Date ?\n\nDate ?\n Titre à revoir \n'), ['Date ?', 'Titre à revoir']);
      expect(decouperPoints('   '), isEmpty);
    });

    test('raison et points : messages d’erreur', () {
      expect(erreurMotif('ab'), isNotNull);
      expect(erreurMotif('x' * 501), isNotNull);
      expect(erreurMotif('La date est fausse'), isNull);
      expect(erreurPoints(''), isNotNull);
      expect(erreurPoints(List.generate(21, (i) => 'Point $i').join('\n')), isNotNull);
      expect(erreurPoints('x' * 501), isNotNull);
      expect(erreurPoints('Date ?'), isNull);
    });

    test('points d’une correction : seuls ceux de CETTE correction comptent', () {
      final c = _correction(points: ['A', 'B']);
      final leves = [_leve(1, 'A', correctionId: 50), _leve(2, 'B', correctionId: 49), _leve(3, 'B')];
      expect(pointLeveCorrection(leves, 50, 'A')?.id, 1);
      expect(pointsRestantsCorrection(c, leves), ['B']);
      // Et un point de correction ne lève pas le point d'une leçon à vérifier.
      expect(pointLeve([_leve(4, 'A', correctionId: 50)], 1, 'A'), isNull);
      expect(pointLeve(leves, 1, 'B')?.id, 3);
    });

    test('état du texte et résumé', () {
      expect(etatTexteCorrection(_correction()), 'Texte corrigé le 16/11/2026');
      expect(etatTexteCorrection(_correction(corrigee: false)), 'Texte pas encore corrigé');
      expect(resumeCorrections(1), startsWith('1 leçon publiée est en correction'));
      expect(resumeCorrections(3), startsWith('3 leçons publiées sont en correction'));
      expect(libelleClasseMatiereCorrection(_correction()), '4ème, Sciences physiques');
    });

    test('schémas : qui peut ajouter et retirer', () {
      final enLigne = _texte();
      const enCorrection = TexteLecon(id: 1, titre: 'T', publiee: true, corps: 'C', correctionId: 50);
      final aVerifier = _texte(publiee: false);
      SchemaLecon schema({int? correctionId}) => SchemaLecon(
            id: 1,
            leconId: 1,
            champ: ChampLecon.corps,
            chemin: 'lecons/1/a.jpg',
            description: 'D',
            ajouteLe: DateTime(2026),
            correctionId: correctionId,
          );
      expect(peutAjouterSchema(enLigne, validateur: false), isFalse);
      expect(peutAjouterSchema(enLigne, validateur: true), isTrue);
      expect(peutAjouterSchema(enCorrection, validateur: false), isTrue);
      expect(peutAjouterSchema(aVerifier, validateur: false), isTrue);
      expect(peutRetirerSchema(schema(correctionId: 50), enCorrection, validateur: false), isTrue);
      expect(peutRetirerSchema(schema(), enCorrection, validateur: true), isFalse);
      expect(peutRetirerSchema(schema(), enLigne, validateur: false), isFalse);
      expect(peutRetirerSchema(schema(), enLigne, validateur: true), isTrue);
      expect(peutRetirerSchema(schema(), aVerifier, validateur: false), isTrue);
      expect(resumeSchemas(0, publiee: true, dansCorrection: true), contains('texte corrigé'));
      expect(resumeSchemas(0, publiee: true, validateur: false), contains('demande d’abord une correction'));
    });

    test('modèles lus depuis la base', () {
      final json = {
        'id': 7,
        'lecon_id': 1,
        'titre': 'T',
        'objectifs': ['O'],
        'introduction': null,
        'corps': 'C',
        'a_retenir': [
          {'notion': 'N', 'essentiel': 'E'},
        ],
        'points_a_verifier': ['P'],
        'motif': 'M',
        'demandee_par': 'moi',
        'demandee_le': '2026-11-16T10:00:00+00:00',
        'modifiee_le': '2026-11-16T10:00:00+00:00',
        'lecons': {
          'titre': 'T en ligne',
          'chapitres': {
            'classes': {'libelle': '4ème', 'ordre': 9},
            'matieres': {'nom': 'SVT', 'slug': 'svt'},
          },
        },
      };
      final c = CorrectionLecon.fromJson(json, moi: 'moi');
      expect((c.titreEnLigne, c.parMoi, c.texteCorrige, c.texte.aRetenir.single.notion), ('T en ligne', true, false, 'N'));
      expect(CorrectionLecon.fromJson(json, moi: 'autre').parMoi, isFalse);
      final v = VersionLecon.fromJson({
        'id': 3,
        'lecon_id': 1,
        'numero': 2,
        'motif': 'M',
        'publiee_le': '2026-11-16T10:00:00+00:00',
        'titre': 'T',
        'objectifs': null,
        'introduction': 'I',
        'corps': null,
        'a_retenir': null,
      });
      expect((v.numero, v.texte.introduction), (2, 'I'));
      expect(v.texte.objectifs, isEmpty);
      expect(PointLeve.fromJson({'id': 1, 'lecon_id': 1, 'point': 'P', 'leve_le': '2026-11-16T10:00:00Z', 'correction_id': 9}).correctionId, 9);
    });
  });

  group('Demander une correction (leçon)', () {
    testWidgets('menu « Outils du rédacteur », puis la fenêtre', (tester) async {
      final redaction = FausseRedaction(redacteur: true, validateur: false, textes: {1: _texte()});
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Outils du rédacteur'));
      await tester.pumpAndSettle();
      expect(find.text('Versions de la leçon'), findsOneWidget);
      await tester.tap(find.text('Demander une correction'));
      await tester.pumpAndSettle();

      // Rien de saisi : deux messages, rien d'envoyé.
      await tester.tap(find.text('Demander'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Explique en quelques mots'), findsOneWidget);
      expect(find.textContaining('au moins un point'), findsOneWidget);
      expect(redaction.corrections, isEmpty);

      await tester.enterText(find.byType(TextField).at(0), 'La date du cours est fausse');
      await tester.enterText(find.byType(TextField).at(1), 'Date du cours ?\nTitre du II ?');
      await tester.tap(find.text('Demander'));
      await tester.pumpAndSettle();
      expect(redaction.corrections.single.points, ['Date du cours ?', 'Titre du II ?']);
      expect(redaction.corrections.single.motif, 'La date du cours est fausse');
      expect(find.textContaining('Correction demandée'), findsOneWidget);
      // La leçon reste en ligne, inchangée.
      expect(redaction.textes[1]!.corps, _corps);
    });

    testWidgets('correction déjà en cours : message de la base', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()}, corrections: [_correction()]);
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Outils du rédacteur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demander une correction'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Autre chose');
      await tester.enterText(find.byType(TextField).at(1), 'Point ?');
      await tester.tap(find.text('Demander'));
      await tester.pumpAndSettle();
      expect(find.text('Une correction de cette leçon est déjà en cours.'), findsOneWidget);
    });
  });

  group('Corrections en cours (Leçons à vérifier)', () {
    Future<void> ouvrir(WidgetTester tester, FausseRedaction redaction) async {
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      expect(find.text('Corrections en cours'), findsOneWidget);
      await _toucher(tester, find.text('Introduction aux sciences physiques'));
      await tester.pumpAndSettle();
    }

    testWidgets('validateur : lever le point, puis publier la correction', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()}, corrections: [_correction()]);
      await ouvrir(tester, redaction);
      expect(find.text('Correction : La date du cours est fausse'), findsOneWidget);
      expect(find.text('Texte corrigé le 16/11/2026'), findsOneWidget);
      expect(find.text('Coche tous les points pour publier'), findsOneWidget);

      await _toucher(tester, find.text('La date du cours est-elle juste ?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Oui : 12/11 dans le cahier.');
      await tester.tap(find.text('Lever le point'));
      await tester.pumpAndSettle();
      expect(redaction.leves.single.correctionId, 50);

      await _toucher(tester, find.text('Publier la correction'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Publier'));
      await tester.pumpAndSettle();
      expect(redaction.textes[1]!.corps, 'Paragraphe corrigé.');
      expect(redaction.versionsEnBase.single.motif, 'La date du cours est fausse');
      expect(find.textContaining('est en ligne (version 1)'), findsOneWidget);
      expect(find.text('Corrections en cours'), findsNothing);
    });

    testWidgets('rédacteur simple : ne publie pas, n’abandonne pas la correction d’un autre', (tester) async {
      final redaction = FausseRedaction(
        redacteur: true,
        validateur: false,
        textes: {1: _texte()},
        corrections: [_correction()],
        leves: [_leve(1, 'La date du cours est-elle juste ?', correctionId: 50)],
      );
      await ouvrir(tester, redaction);
      final bouton = find.widgetWithText(FilledButton, 'Un validateur publiera la correction');
      await tester.ensureVisible(bouton);
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);
      expect(find.text('Abandonner la correction'), findsNothing);
    });

    testWidgets('demandeur : abandonne, les images ajoutées sont supprimées', (tester) async {
      final redaction = FausseRedaction(
        redacteur: true,
        validateur: false,
        textes: {1: _texte()},
        corrections: [_correction(parMoi: true)],
        schemas: [
          SchemaLecon(
            id: 9,
            leconId: 1,
            champ: ChampLecon.corps,
            chemin: 'lecons/1/dans-correction.jpg',
            description: 'D',
            ajouteLe: DateTime(2026, 11, 16),
            correctionId: 50,
          ),
        ],
      );
      await ouvrir(tester, redaction);
      await _toucher(tester, find.text('Abandonner la correction'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Abandonner'));
      await tester.pumpAndSettle();
      expect(redaction.correctionsFermees[50], 'abandonnee');
      expect(redaction.supprimes, ['lecons/1/dans-correction.jpg']);
      expect(redaction.textes[1]!.corps, _corps);
      expect(find.textContaining('Correction abandonnée'), findsOneWidget);
    });

    testWidgets('« Relire le texte corrigé » ouvre l’aperçu', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()}, corrections: [_correction()]);
      await ouvrir(tester, redaction);
      await _toucher(tester, find.text('Relire le texte corrigé'));
      await tester.pumpAndSettle();
      expect(find.text('Correction en cours : La date du cours est fausse'), findsOneWidget);
      expect(find.text('Paragraphe corrigé.'), findsOneWidget);
      expect(find.text('Solide vers liquide.'), findsOneWidget);
    });

    testWidgets('nouvelle leçon : un rédacteur simple ne publie pas', (tester) async {
      final redaction = FausseRedaction(
        redacteur: true,
        validateur: false,
        lecons: [
          const LeconAVerifier(
            id: 2,
            titre: 'La digestion',
            classe: '4ème',
            ordreClasse: 9,
            matiere: 'SVT',
            matiereSlug: 'svt',
            points: ['Origine ?'],
            artefactUrl: null,
          ),
        ],
        leves: [_leve(1, 'Origine ?', leconId: 2)],
      );
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      await tester.tap(find.text('La digestion'));
      await tester.pumpAndSettle();
      final bouton = find.widgetWithText(FilledButton, 'Un validateur publiera la leçon');
      await tester.ensureVisible(bouton);
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);
    });
  });

  group('Aperçu de la correction', () {
    testWidgets('pas de correction en cours', (tester) async {
      await lancerApp(tester,
          depot: FauxDepot(), compte: _connecte(), redaction: FausseRedaction(redacteur: true), chemin: '/lecon/1/correction');
      await tester.pumpAndSettle();
      expect(find.text('Pas de correction en cours'), findsOneWidget);
    });

    testWidgets('réservé aux rédacteurs, et erreur puis « Réessayer »', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), chemin: '/lecon/1/correction');
      await tester.pumpAndSettle();
      expect(find.text('Réservé aux rédacteurs'), findsOneWidget);

      final redaction = FausseRedaction(redacteur: true, corrections: [_correction()])..pannes['correctionDe'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1/correction');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Paragraphe corrigé.'), findsOneWidget);
    });
  });

  group('Versions', () {
    final versions = [_version(1, 1, 'Version en ligne au 16/11/2026'), _version(2, 2, 'La date du cours est fausse', corps: 'Corrigé.')];

    testWidgets('validateur : relire une version, puis revenir à elle', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte(corps: 'Corrigé.')}, versions: versions);
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1/versions');
      await tester.pumpAndSettle();
      expect(find.text('Version 2 · en ligne'), findsOneWidget);
      expect(find.text('Version 1'), findsOneWidget);

      // La version en ligne : pas de retour possible vers elle-même.
      await tester.tap(find.text('Version 2 · en ligne'));
      await tester.pumpAndSettle();
      expect(find.text('Revenir à cette version'), findsNothing);
      await tester.tap(find.text('Versions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Version 1'));
      await tester.pumpAndSettle();
      expect(find.text('Premier paragraphe.'), findsOneWidget);
      await tester.tap(find.text('Revenir à cette version'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Revenir'));
      await tester.pumpAndSettle();
      expect(redaction.textes[1]!.corps, _corps);
      expect(redaction.versionsEnBase.last.motif, 'Retour à la version 1');
      expect(find.text('Version 3 · en ligne'), findsOneWidget);
      expect(find.textContaining('de nouveau en ligne (version 3)'), findsOneWidget);
    });

    testWidgets('rédacteur simple, ou correction en cours : pas de retour', (tester) async {
      final simple = FausseRedaction(redacteur: true, validateur: false, textes: {1: _texte()}, versions: versions);
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: simple, chemin: '/lecon/1/versions');
      await tester.pumpAndSettle();
      expect(find.textContaining('Seul un validateur'), findsOneWidget);
      await tester.tap(find.text('Version 1'));
      await tester.pumpAndSettle();
      expect(find.text('Revenir à cette version'), findsNothing);

      final enCorrection = FausseRedaction(redacteur: true, textes: {1: _texte()}, versions: versions, corrections: [_correction()]);
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: enCorrection, chemin: '/lecon/1/versions');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Version 1'));
      await tester.pumpAndSettle();
      expect(find.text('Revenir à cette version'), findsNothing);
      expect(find.textContaining('Une correction est en cours'), findsOneWidget);
    });

    testWidgets('aucune version, et erreur puis « Réessayer »', (tester) async {
      await lancerApp(tester,
          depot: FauxDepot(), compte: _connecte(), redaction: FausseRedaction(redacteur: true), chemin: '/lecon/1/versions');
      await tester.pumpAndSettle();
      expect(find.text('Aucune version'), findsOneWidget);

      final redaction = FausseRedaction(redacteur: true, versions: versions)..pannes['versions'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1/versions');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Version 1'), findsOneWidget);
    });
  });

  group('Schémas pendant une correction', () {
    testWidgets('rédacteur simple sans correction : ajout impossible, expliqué', (tester) async {
      final redaction = FausseRedaction(redacteur: true, validateur: false, textes: {1: _texte()});
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      expect(find.textContaining('demande d’abord une correction'), findsOneWidget);
      final bouton = find.widgetWithText(FilledButton, 'Ajouter un schéma');
      expect(tester.widget<FilledButton>(bouton).onPressed, isNull);
    });

    testWidgets('correction en cours : le schéma va dans le texte corrigé', (tester) async {
      final redaction = FausseRedaction(redacteur: true, validateur: false, textes: {1: _texte()}, corrections: [_correction()]);
      await lancerApp(tester,
          depot: FauxDepot(),
          compte: _connecte(),
          redaction: redaction,
          choixImage: FauxChoixImage(octets: Uint8List.fromList(List.filled(10, 1))),
          chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      expect(find.textContaining('va dans le texte corrigé'), findsOneWidget);
      await tester.tap(find.text('Ajouter un schéma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Les trois états');
      final ajouter = find.text('Ajouter à la leçon');
      await tester.scrollUntilVisible(ajouter, 200,
          scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
      await tester.tap(ajouter);
      await tester.pumpAndSettle();
      expect(redaction.corrections.single.texte.corps, contains('![Les trois états]'));
      expect(redaction.textes[1]!.corps, _corps);
      expect(find.textContaining('dans la correction en cours'), findsOneWidget);
    });
  });

  group('Pas de débordement à 200 %', () {
    for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
      testWidgets('$nom : correction dépliée, aperçu, versions', (tester) async {
        final redaction = FausseRedaction(
          redacteur: true,
          textes: {1: _texte()},
          corrections: [_correction(parMoi: true)],
          versions: [_version(1, 1, 'Version en ligne au 16/11/2026')],
        );
        await lancerApp(tester,
            depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/validation', taille: taille, echelleTexte: 2);
        await tester.pumpAndSettle();
        final titre = find.text('Introduction aux sciences physiques');
        await tester.scrollUntilVisible(titre, 200, scrollable: find.byType(Scrollable).first);
        await _toucher(tester, titre);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Abandonner la correction'), 200, scrollable: find.byType(Scrollable).first);

        await lancerApp(tester,
            depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1/correction', taille: taille, echelleTexte: 2);
        await tester.pumpAndSettle();
        await lancerApp(tester,
            depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1/versions', taille: taille, echelleTexte: 2);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.textContaining('Version 1'), 200, scrollable: find.byType(Scrollable).first);
        await _toucher(tester, find.textContaining('Version 1'));
        await tester.pumpAndSettle();
      });

      testWidgets('$nom : fenêtre « Demander une correction »', (tester) async {
        await lancerApp(tester,
            depot: FauxDepot(),
            compte: _connecte(),
            redaction: FausseRedaction(redacteur: true, textes: {1: _texte()}),
            chemin: '/lecon/1',
            taille: taille,
            echelleTexte: 2);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Outils du rédacteur'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Demander une correction'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Demander'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Explique en quelques mots'), findsOneWidget);
      });
    }
  });
}
