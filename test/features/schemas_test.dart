// « Schémas de la leçon » (rédacteurs, phase 5) : logique pure, puis
// l'écran sur la vraie application avec une fausse rédaction qui imite
// `ajouter_schema` et `retirer_schema`, et un faux appareil photo.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:samaclasse/core/services/choix_image.dart';
import 'package:samaclasse/core/services/reduction_image.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/schemas/outils_schemas.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException, StorageException;

import '../outils/faux_depot.dart';

/// Vraie petite image PNG (l'aperçu de la fenêtre la décode).
final Uint8List _photo = img.encodePng(img.Image(width: 8, height: 6)..clear(img.ColorRgb8(240, 240, 255)));

const _corps = 'Premier paragraphe sur la matière.\n\n'
    '## Les trois états\n\n'
    '- solide\n- liquide\n- gaz\n\n'
    'Dernier paragraphe : la fusion.';

TexteLecon _texte({String? introduction = 'Une courte introduction.', String? corps = _corps, bool publiee = true}) =>
    TexteLecon(id: 1, titre: 'Introduction aux sciences physiques', publiee: publiee, introduction: introduction, corps: corps);

SchemaLecon _schema(int id, String description) => SchemaLecon(
      id: id,
      leconId: 1,
      champ: ChampLecon.corps,
      chemin: 'lecons/1/fichier-$id.jpg',
      description: description,
      ajouteLe: DateTime(2026, 11, 16),
    );

FauxCompte _connecte() => FauxCompte(connecte: 'redacteur@exemple.sn');

/// Fait défiler jusqu'à [cible], puis la touche. Une liste ne construit
/// que ce qui est près de l'écran : si [cible] n'existe pas encore, on fait
/// défiler la liste de la page du dessus (la fenêtre d'ajout est construite
/// après l'écran, sa liste est donc la dernière).
Future<void> _toucher(WidgetTester tester, Finder cible) async {
  if (cible.evaluate().isEmpty) {
    await tester.scrollUntilVisible(cible, 200, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
  }
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
}

void main() {
  group('Paragraphes (même règle que ajouter_schema)', () {
    test('découpage sur les lignes vides, même faites d’espaces', () {
      // Exemple du test SQL de la migration : 3 paragraphes.
      expect(decouperParagraphes('P1\n\nP2\n \nP3'), ['P1', 'P2', 'P3']);
      expect(decouperParagraphes('P1\nsuite\n\nP2'), ['P1\nsuite', 'P2']);
      expect(decouperParagraphes('P1\n\t\nP2'), ['P1', 'P2']);
    });

    test('texte vide : aucun paragraphe', () {
      expect(decouperParagraphes(null), isEmpty);
      expect(decouperParagraphes('  \n '), isEmpty);
    });

    test('lignes vides en trop : paragraphes vides gardés (numérotation du serveur)', () {
      // Le serveur compte 2 séparateurs dans « A\n\n\n\nB » : 3 paragraphes.
      expect(decouperParagraphes('A\n\n\n\nB'), ['A', '', 'B']);
    });

    test('repères : au début, puis après chaque paragraphe non vide', () {
      final r = reperes('A\n\n\n\nB');
      expect([for (final x in r) x.apres], [0, 1, 3]);
      expect(r.last.apercu, 'B');
      expect(reperes(null), [(apres: 0, apercu: '')]);
    });
  });

  group('Aperçu d’un paragraphe', () {
    test('sans marques Markdown, sur une ligne', () {
      expect(apercuParagraphe('## Les trois états'), 'Les trois états');
      expect(apercuParagraphe('- solide\n- liquide\n- gaz'), 'solide liquide gaz');
      expect(apercuParagraphe('La **fusion** est le passage _solide_ → liquide.'), 'La fusion est le passage solide → liquide.');
      expect(apercuParagraphe('1. Chauffer\n2. Observer'), 'Chauffer Observer');
    });

    test('tableau : sans la ligne de séparation', () {
      expect(apercuParagraphe('| État | Forme |\n| --- | --- |\n| Solide | Propre |'), 'État Forme Solide Propre');
    });

    test('image existante : « Schéma : description »', () {
      expect(apercuParagraphe('![Le cycle de l’eau](https://x.supabase.co/a.png)'), 'Schéma : Le cycle de l’eau');
    });

    test('long paragraphe : coupé avec « … »', () {
      final a = apercuParagraphe('mot ' * 100);
      expect(a.runes.length, lessThanOrEqualTo(longueurApercu));
      expect(a, endsWith('…'));
    });
  });

  group('Description', () {
    test('obligatoire, de 3 à 300 caractères, sans crochets', () {
      expect(erreurDescription('   '), isNotNull);
      expect(erreurDescription('ab'), isNotNull);
      expect(erreurDescription('x' * 301), isNotNull);
      expect(erreurDescription('Le schéma [1]'), isNotNull);
      expect(erreurDescription('Les trois états de l’eau'), isNull);
      expect(erreurDescription('x' * 300), isNull);
    });

    test('nettoyée sur une ligne', () {
      expect(nettoyerDescription('  Les trois\n états  de l’eau '), 'Les trois états de l’eau');
    });
  });

  group('Messages', () {
    test('erreurs d’image, de dépôt et de la fonction', () {
      expect(messageErreurSchema(const ImageIllisible()), contains('illisible'));
      expect(messageErreurSchema(const ImageTropLourde()), contains('150 Ko'));
      expect(messageErreurSchema(const StorageException('trop gros', statusCode: '413')), contains('150 Ko'));
      expect(messageErreurSchema(const StorageException('interdit', statusCode: '403')), contains('droits de rédacteur'));
      const change = PostgrestException(message: 'La leçon a changé…', code: '40001');
      expect(messageErreurSchema(change), contains('Recharge-la'));
      expect(estTexteChange(change), isTrue);
      expect(estTexteChange(const PostgrestException(message: 'x', code: '42501')), isFalse);
      expect(messageErreurSchema(const PostgrestException(message: 'La description doit faire de 3 à 300 caractères.', code: '22023')),
          'La description doit faire de 3 à 300 caractères.');
      expect(messageErreurSchema(Exception('réseau')), contains('Pas de connexion'));
    });

    test('résumé : nombre accordé, et leçon publiée ou non', () {
      expect(resumeSchemas(0, publiee: true), startsWith('Aucun schéma'));
      expect(resumeSchemas(1, publiee: true), contains('1 schéma ajouté'));
      expect(resumeSchemas(2, publiee: false), contains('2 schémas ajoutés'));
      expect(resumeSchemas(1, publiee: true), contains('prochaine mise à jour'));
      expect(resumeSchemas(1, publiee: false), contains('une fois publiée'));
    });

    test('modèles lus depuis la base', () {
      final t = TexteLecon.fromJson({'id': 3, 'titre': 'T', 'statut': 'a_verifier', 'introduction': null, 'corps': 'C'});
      expect((t.publiee, t.texte(ChampLecon.corps), t.texte(ChampLecon.introduction)), (false, 'C', null));
      final s = SchemaLecon.fromJson({
        'id': 4,
        'lecon_id': 3,
        'champ': 'introduction',
        'chemin': 'lecons/3/a.jpg',
        'description': 'D',
        'ajoute_le': '2026-11-16T10:00:00+00:00',
      });
      expect((s.champ, s.chemin), (ChampLecon.introduction, 'lecons/3/a.jpg'));
    });
  });

  group('Écran', () {
    testWidgets('sans connexion, puis compte non rédacteur : réservé', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      expect(find.text('Réservé aux rédacteurs'), findsOneWidget);
      expect(find.text('Aller à l’espace parents'), findsOneWidget);

      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      expect(find.text('Réservé aux rédacteurs'), findsOneWidget);
      expect(find.text('Aller à l’espace parents'), findsNothing);
    });

    testWidgets('chargement, erreur, puis « Réessayer »', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()})..pannes['schemas'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1/schemas');
      // Premier affichage : la réponse n'est pas encore arrivée.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Introduction aux sciences physiques'), findsOneWidget);
    });

    testWidgets('leçon introuvable', (tester) async {
      await lancerApp(tester,
          depot: FauxDepot(), compte: _connecte(), redaction: FausseRedaction(redacteur: true), chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      expect(find.text('Leçon introuvable'), findsOneWidget);
    });

    testWidgets('aucun schéma : résumé et bouton d’ajout', (tester) async {
      await lancerApp(tester,
          depot: FauxDepot(),
          compte: _connecte(),
          redaction: FausseRedaction(redacteur: true, textes: {1: _texte()}),
          chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucun schéma ajouté'), findsOneWidget);
      expect(find.text('Ajouter un schéma'), findsOneWidget);
    });

    testWidgets('ajouter un schéma : galerie, description, endroit, puis la liste', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()});
      final choix = FauxChoixImage(octets: _photo);
      await lancerApp(tester,
          depot: FauxDepot(), compte: _connecte(), redaction: redaction, choixImage: choix, chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter un schéma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pumpAndSettle();
      expect(choix.sources, [SourceImage.galerie]);
      expect(find.text('1200 × 800 px · ${libellePoids(_photo.length)}'), findsOneWidget);

      // Description vide : refusée, rien n'est déposé.
      await _toucher(tester, find.text('Ajouter à la leçon'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Décris le schéma'), findsOneWidget);
      expect(redaction.fichiers, isEmpty);

      await tester.enterText(find.byType(TextField), 'Les trois états de la matière');
      // Endroit : après « Les trois états » (2e paragraphe du corps).
      final repere = find.text('Après : Les trois états');
      await _toucher(tester, repere);
      await _toucher(tester, find.text('Ajouter à la leçon'));
      await tester.pumpAndSettle();

      // Retour à la liste, avec le nouveau schéma.
      expect(find.text('Ajouter un schéma'), findsOneWidget);
      expect(find.text('Les trois états de la matière'), findsOneWidget);
      expect(find.textContaining('Les élèves le verront'), findsOneWidget);
      final corps = redaction.textes[1]!.corps!;
      expect(decouperParagraphes(corps)[2], startsWith('![Les trois états de la matière]('));
      expect(decouperParagraphes(corps)[1], '## Les trois états');
      expect(redaction.supprimes, isEmpty);
    });

    testWidgets('par défaut, à la fin du corps ; introduction au choix', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()});
      await lancerApp(tester,
          depot: FauxDepot(),
          compte: _connecte(),
          redaction: redaction,
          choixImage: FauxChoixImage(octets: _photo),
          chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un schéma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prendre une photo'));
      await tester.pumpAndSettle();
      expect(find.text('À la fin, après : Dernier paragraphe : la fusion.'), findsOneWidget);

      await tester.tap(find.text('Introduction'));
      await tester.pumpAndSettle();
      expect(find.text('À la fin, après : Une courte introduction.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Schéma d’introduction');
      await _toucher(tester, find.text('Ajouter à la leçon'));
      await tester.pumpAndSettle();
      expect(redaction.textes[1]!.introduction, startsWith('Une courte introduction.\n\n![Schéma d’introduction]('));
      expect(redaction.textes[1]!.corps, _corps);
    });

    testWidgets('leçon modifiée entre-temps : refus, image supprimée, « Recharger la leçon »', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()});
      await lancerApp(tester,
          depot: FauxDepot(),
          compte: _connecte(),
          redaction: redaction,
          choixImage: FauxChoixImage(octets: _photo),
          chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un schéma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pumpAndSettle();

      // Quelqu'un corrige la leçon pendant que la fenêtre est ouverte.
      redaction.textes[1] = _texte(corps: '$_corps\n\nParagraphe ajouté.');
      await tester.enterText(find.byType(TextField), 'Les trois états');
      await _toucher(tester, find.text('Ajouter à la leçon'));
      await tester.pumpAndSettle();
      expect(find.textContaining('La leçon a changé'), findsOneWidget);
      // L'image déposée n'est pas restée orpheline.
      expect(redaction.supprimes, hasLength(1));
      expect(redaction.fichiers, isEmpty);

      await _toucher(tester, find.text('Recharger la leçon'));
      await tester.pumpAndSettle();
      expect(find.text('À la fin, après : Paragraphe ajouté.'), findsOneWidget);
      await _toucher(tester, find.text('Ajouter à la leçon'));
      await tester.pumpAndSettle();
      expect(redaction.textes[1]!.corps, endsWith('Paragraphe ajouté.\n\n![Les trois états](https://exemple.supabase.co/storage/v1/object/public/schemas/lecons/1/fichier-2.jpg)'));
    });

    testWidgets('autre refus du serveur : message, image supprimée, fenêtre ouverte', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()})
        ..refusAjout = const PostgrestException(message: 'La description ne peut contenir ni crochets ni retour à la ligne.', code: '22023');
      await lancerApp(tester,
          depot: FauxDepot(),
          compte: _connecte(),
          redaction: redaction,
          choixImage: FauxChoixImage(octets: _photo),
          chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un schéma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Une description');
      await _toucher(tester, find.text('Ajouter à la leçon'));
      await tester.pumpAndSettle();
      expect(find.text('La description ne peut contenir ni crochets ni retour à la ligne.'), findsOneWidget);
      expect(find.text('Recharger la leçon'), findsNothing);
      expect(redaction.supprimes, hasLength(1));
      // La fenêtre reste ouverte (son titre ; celui de l'écran est caché dessous).
      expect(find.text('Ajouter un schéma'), findsOneWidget);
      expect(find.text('Où le placer ?', skipOffstage: false), findsOneWidget);
    });

    testWidgets('dépôt impossible (réseau) : message, rien d’inséré', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()})..pannes['deposer'] = 1;
      await lancerApp(tester,
          depot: FauxDepot(),
          compte: _connecte(),
          redaction: redaction,
          choixImage: FauxChoixImage(octets: _photo),
          chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un schéma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Une description');
      await _toucher(tester, find.text('Ajouter à la leçon'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pas de connexion'), findsOneWidget);
      expect(redaction.schemas, isEmpty);
      expect(redaction.textes[1]!.corps, _corps);
    });

    testWidgets('image illisible : message et « Choisir une autre image »', (tester) async {
      await lancerApp(tester,
          depot: FauxDepot(),
          compte: _connecte(),
          redaction: FausseRedaction(redacteur: true, textes: {1: _texte()}),
          choixImage: FauxChoixImage(octets: _photo, erreurReduction: const ImageIllisible()),
          chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un schéma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pumpAndSettle();
      expect(find.textContaining('illisible'), findsOneWidget);
      await tester.tap(find.text('Choisir une autre image'));
      await tester.pumpAndSettle();
      expect(find.text('Schémas de la leçon'), findsOneWidget);
    });

    testWidgets('galerie refermée sans choisir : rien ne se passe', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()});
      await lancerApp(tester,
          depot: FauxDepot(), compte: _connecte(), redaction: redaction, choixImage: FauxChoixImage(), chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un schéma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pumpAndSettle();
      expect(find.text('Ajouter à la leçon'), findsNothing);
      expect(find.text('Schémas de la leçon'), findsOneWidget);
    });

    testWidgets('retirer un schéma : confirmation, puis image supprimée', (tester) async {
      final redaction = FausseRedaction(
        redacteur: true,
        textes: {1: _texte()},
        schemas: [_schema(7, 'Le cycle de l’eau'), _schema(8, 'Les changements d’état')],
      );
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      expect(find.textContaining('2 schémas ajoutés'), findsOneWidget);
      expect(find.text('Corps de la leçon · ajouté le 16/11/2026'), findsNWidgets(2));

      final retirer = find.text('Retirer').first;
      await _toucher(tester, retirer);
      await tester.pumpAndSettle();
      expect(find.text('Retirer ce schéma ?'), findsOneWidget);
      // « Garder » : rien ne change.
      await tester.tap(find.text('Garder'));
      await tester.pumpAndSettle();
      expect(redaction.schemas, hasLength(2));

      await _toucher(tester, find.text('Retirer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Retirer'));
      await tester.pumpAndSettle();
      expect(find.text('Schéma retiré de la leçon.'), findsOneWidget);
      expect(find.text('Le cycle de l’eau'), findsNothing);
      expect(redaction.supprimes, ['lecons/1/fichier-7.jpg']);
    });

    testWidgets('retrait refusé (réseau) : message, schéma gardé', (tester) async {
      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()}, schemas: [_schema(7, 'Le cycle de l’eau')])
        ..pannes['retirer'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1/schemas');
      await tester.pumpAndSettle();
      await _toucher(tester, find.text('Retirer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Retirer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pas de connexion'), findsOneWidget);
      expect(find.text('Le cycle de l’eau'), findsOneWidget);
      expect(redaction.supprimes, isEmpty);
    });

    testWidgets('accès : bouton sur la leçon pour un rédacteur seulement', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), chemin: '/lecon/1');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Outils du rédacteur'), findsNothing);

      final redaction = FausseRedaction(redacteur: true, textes: {1: _texte()});
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Outils du rédacteur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schémas de la leçon'));
      await tester.pumpAndSettle();
      expect(find.text('Schémas de la leçon'), findsOneWidget);
      // Retour à la leçon.
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(find.text('Introduction aux sciences physiques'), findsOneWidget);
    });

    testWidgets('accès : depuis « Leçons à vérifier »', (tester) async {
      final redaction = FausseRedaction(
        redacteur: true,
        lecons: [
          const LeconAVerifier(
            id: 1,
            titre: 'Introduction aux sciences physiques',
            classe: '4ème',
            ordreClasse: 9,
            matiere: 'Sciences physiques',
            matiereSlug: 'sciences-physiques',
            points: ['Point à lever.'],
            artefactUrl: null,
          ),
        ],
        textes: {1: _texte(publiee: false)},
      );
      await lancerApp(tester, depot: FauxDepot(), compte: _connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Introduction aux sciences physiques'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter ou retirer des schémas'));
      await tester.pumpAndSettle();
      expect(find.text('Schémas de la leçon'), findsOneWidget);
      expect(find.textContaining('pas encore publiée'), findsOneWidget);
    });

    group('pas de débordement à 200 %', () {
      for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
        testWidgets(nom, (tester) async {
          final redaction = FausseRedaction(
            redacteur: true,
            textes: {1: _texte()},
            schemas: [_schema(7, 'Les trois états de la matière et les six changements d’état entre eux')],
          );
          await lancerApp(tester,
              depot: FauxDepot(),
              compte: _connecte(),
              redaction: redaction,
              choixImage: FauxChoixImage(octets: _photo),
              chemin: '/lecon/1/schemas',
              taille: taille,
              echelleTexte: 2);
          await tester.pumpAndSettle();
          await _toucher(tester, find.text('Ajouter un schéma'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Choisir dans la galerie'));
          await tester.pumpAndSettle();
          // Toute la fenêtre, jusqu'au bouton.
          await _toucher(tester, find.text('Ajouter à la leçon'));
          await tester.pumpAndSettle();
          // Description vide : rien n'est déposé, et le message (plus haut,
          // sous le champ) s'affiche sans déborder.
          expect(redaction.fichiers, hasLength(1)); // seulement le schéma existant
          await tester.scrollUntilVisible(find.textContaining('Décris le schéma'), -200,
              scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
          expect(find.textContaining('Décris le schéma'), findsOneWidget);
        });
      }
    });
  });
}
