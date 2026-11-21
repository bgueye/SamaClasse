// « Signaler une erreur » (D35, D38) : logique pure (motifs, messages,
// libellés), fenêtre d'envoi depuis une leçon et depuis un exercice (quatre
// états, 200 %), et section « Erreurs signalées » des rédacteurs.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/signalement/fiche_signalement.dart';
import 'package:samaclasse/features/validation/outils_validation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../outils/faux_depot.dart';

final _lecon = Lecon.fromJson((donneesReelles['lecons'] as Map)['1'] as Map<String, dynamic>);

/// Signalement tel que la requête des rédacteurs le rend.
Signalement _signalement({
  int id = 1,
  int? exerciceId,
  int? ordre,
  String motif = 'faute',
  String? precision,
  String recuLe = '2026-11-21T19:15:00+00:00',
}) =>
    Signalement.fromJson({
      'id': id,
      'lecon_id': 1,
      'exercice_id': exerciceId,
      'motif': motif,
      'precision_texte': precision,
      'recu_le': recuLe,
      'lecons': {'titre': 'Introduction aux sciences physiques'},
      'exercices': ordre == null ? null : {'ordre': ordre},
    });

/// Fait défiler l'écran jusqu'à [cible] : à 200 %, une liste ne construit
/// pas encore les éléments trop bas, et `ensureVisible` ne les trouve pas.
Future<void> montrer(WidgetTester tester, Finder cible) async {
  if (cible.evaluate().isEmpty) {
    await tester.scrollUntilVisible(cible, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
}

void main() {
  group('Logique', () {
    test('codes des motifs : ceux de la base', () {
      expect(MotifSignalement.values.map((m) => m.code), ['faute', 'corrige_faux', 'pas_comme_cahier', 'autre']);
      expect(MotifSignalement.depuisCode('corrige_faux'), MotifSignalement.corrigeFaux);
      expect(MotifSignalement.depuisCode('inconnu'), MotifSignalement.autre, reason: 'motif ajouté plus tard');
    });

    test('« Le corrigé me semble faux » seulement pour un exercice', () {
      expect(motifsProposes(pourExercice: false), isNot(contains(MotifSignalement.corrigeFaux)));
      expect(motifsProposes(pourExercice: false), hasLength(3));
      expect(motifsProposes(pourExercice: true), MotifSignalement.values);
    });

    test('précision : espaces retirés, vide devient null', () {
      expect(nettoyerPrecision('  12 et non 21 \n'), '12 et non 21');
      expect(nettoyerPrecision('   '), isNull);
    });

    test('messages d’erreur', () {
      const limite = PostgrestException(message: 'Tu as déjà envoyé plusieurs signalements. Réessaie dans une heure.', code: 'P0001');
      expect(messageErreurSignalement(limite), limite.message);
      expect(
        messageErreurSignalement(const PostgrestException(message: 'x', code: 'P0002')),
        'Cette leçon a changé depuis. Reviens à l’accueil, puis réessaie.',
      );
      expect(messageErreurSignalement(const SocketException('x')), startsWith('Pas de connexion'));
      expect(messageErreurSignalement(const PostgrestException(message: 'x', code: '500')), startsWith('L’envoi n’a pas marché'));
    });

    test('lecture d’un signalement (forme réelle de la réponse)', () {
      final s = _signalement(exerciceId: 22, ordre: 3, motif: 'pas_comme_cahier', precision: 'Dans mon cahier : 12');
      expect(s.leconId, 1);
      expect(s.exerciceId, 22);
      expect(s.ordreExercice, 3);
      expect(s.motif, MotifSignalement.pasCommeCahier);
      expect(s.precision, 'Dans mon cahier : 12');
      expect(s.recuLe, DateTime.utc(2026, 11, 21, 19, 15));
      expect(_signalement().exerciceId, isNull);
    });

    test('libellés de l’écran des rédacteurs', () {
      expect(libelleSignalement(_signalement()), 'Leçon · Introduction aux sciences physiques');
      expect(libelleSignalement(_signalement(exerciceId: 22, ordre: 3)), 'Exercice 3 · Introduction aux sciences physiques');
      expect(libelleSignalement(_signalement(exerciceId: 22)), 'Exercice · Introduction aux sciences physiques');
      expect(resumeSignalements(1), '1 erreur signalée par un lecteur attend ta vérification.');
      expect(resumeSignalements(3), '3 erreurs signalées par des lecteurs attendent ta vérification.');
      final d = DateTime.utc(2026, 11, 21, 19, 15).toLocal();
      expect(
        recuLeSignalement(_signalement()),
        'Reçu le ${d.day.toString().padLeft(2, '0')}/11/2026 à ${d.hour.toString().padLeft(2, '0')}:15',
      );
    });

    test('raison proposée pour une correction', () {
      expect(
        motifCorrectionDepuis(_signalement(exerciceId: 22, ordre: 3, motif: 'corrige_faux', precision: 'Le résultat est 12')),
        'Signalement d’un lecteur (exercice 3), le corrigé me semble faux : « Le résultat est 12 »',
      );
      expect(motifCorrectionDepuis(_signalement()), 'Signalement d’un lecteur, une faute dans le texte');
      final long = motifCorrectionDepuis(_signalement(precision: 'é' * 500));
      expect(long.runes.length, longueurMaxMotif);
      expect(long, endsWith('…'));
    });

    test('sous-titre de la fenêtre', () {
      expect(sousTitreSignalement(_lecon), 'Leçon · ${_lecon.titre}');
      expect(sousTitreSignalement(_lecon, numeroExercice: 4), 'Exercice 4 · ${_lecon.titre}');
    });
  });

  group('Fenêtre d’envoi', () {
    Future<void> ouvrir(WidgetTester tester) async {
      await montrer(tester, find.text('Signaler une erreur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Signaler une erreur'));
      await tester.pumpAndSettle();
    }

    FilledButton boutonEnvoyer(WidgetTester tester) =>
        tester.widget<FilledButton>(find.ancestor(of: find.text('Envoyer'), matching: find.byType(FilledButton)));

    testWidgets('depuis une leçon : motif obligatoire, envoi, merci', (tester) async {
      final signalement = FauxSignalement();
      await lancerApp(tester, depot: FauxDepot(), signalement: signalement, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await ouvrir(tester);

      expect(find.text('Leçon · ${_lecon.titre}'), findsOneWidget);
      expect(find.text('Le corrigé me semble faux'), findsNothing, reason: 'une leçon n’a pas de corrigé');
      expect(find.text('N’écris pas ton nom ni ton numéro.'), findsOneWidget);
      expect(boutonEnvoyer(tester).onPressed, isNull, reason: 'aucun motif choisi');
      expect(find.text('Choisis d’abord ce qui ne va pas.'), findsOneWidget);

      await tester.tap(find.text('Ce n’est pas comme dans mon cahier'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Dans mon cahier, la date est le 12/11.  ');
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(signalement.recus, hasLength(1));
      final r = signalement.recus.single;
      expect(r.leconId, 1);
      expect(r.exerciceId, isNull);
      expect(r.motif, MotifSignalement.pasCommeCahier);
      expect(r.precision, 'Dans mon cahier, la date est le 12/11.');
      expect(find.text('Merci, c’est envoyé'), findsOneWidget);

      await tester.tap(find.text('Revenir à la leçon'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('envoi en cours : bouton désactivé, sans double envoi', (tester) async {
      final signalement = FauxSignalement()..attente = Completer();
      await lancerApp(tester, depot: FauxDepot(), signalement: signalement, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await ouvrir(tester);
      await tester.tap(find.text('Une faute dans le texte'));
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      await tester.pump();

      expect(find.text('Envoi…'), findsOneWidget);
      final bouton = tester.widget<FilledButton>(find.ancestor(of: find.text('Envoi…'), matching: find.byType(FilledButton)));
      expect(bouton.onPressed, isNull);

      signalement.attente!.complete();
      await tester.pumpAndSettle();
      expect(signalement.recus, hasLength(1));
      expect(find.text('Merci, c’est envoyé'), findsOneWidget);
    });

    testWidgets('sans réseau : message, formulaire gardé, puis réessai', (tester) async {
      final signalement = FauxSignalement()..enPanne = true;
      await lancerApp(tester, depot: FauxDepot(), signalement: signalement, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await ouvrir(tester);
      await tester.tap(find.text('Autre chose'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Le titre est coupé.');
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(find.text('Pas de connexion internet. Réessaie quand tu auras du réseau.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget, reason: 'pas la couleur seule');
      expect(find.text('Le titre est coupé.'), findsOneWidget);
      expect(signalement.recus, isEmpty);

      signalement.enPanne = false;
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(signalement.recus.single.precision, 'Le titre est coupé.');
      expect(find.text('Merci, c’est envoyé'), findsOneWidget);
    });

    testWidgets('limite d’envois : la phrase de la base', (tester) async {
      final signalement = FauxSignalement()..limite = 0;
      await lancerApp(tester, depot: FauxDepot(), signalement: signalement, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await ouvrir(tester);
      await tester.tap(find.text('Une faute dans le texte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(find.text('Tu as déjà envoyé plusieurs signalements. Réessaie dans une heure.'), findsOneWidget);
    });

    testWidgets('depuis un exercice : l’exercice est envoyé, corrigé proposé', (tester) async {
      final signalement = FauxSignalement();
      await lancerApp(tester, depot: FauxDepot(), signalement: signalement, chemin: '/lecon/1/exercices');
      await tester.pumpAndSettle();
      await ouvrir(tester);

      expect(find.text('Exercice 1 · ${_lecon.titre}'), findsOneWidget);
      await tester.tap(find.text('Le corrigé me semble faux'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      final r = signalement.recus.single;
      expect(r.exerciceId, _lecon.exercices.first.id);
      expect(r.motif, MotifSignalement.corrigeFaux);
      expect(r.precision, isNull);
      expect(find.text('Revenir à l’exercice'), findsOneWidget);
    });

    for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
      testWidgets('sans débordement à 200 % ($nom) : formulaire, erreur, merci', (tester) async {
        final signalement = FauxSignalement()..enPanne = true;
        await lancerApp(
          tester,
          depot: FauxDepot(),
          signalement: signalement,
          chemin: '/lecon/1/exercices',
          taille: taille,
          echelleTexte: 2,
        );
        await tester.pumpAndSettle();
        await ouvrir(tester);
        expect(find.byType(BottomSheet), findsOneWidget);

        await tester.tap(find.text('Le corrigé me semble faux'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Envoyer'));
        await tester.tap(find.text('Envoyer'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Pas de connexion'), findsOneWidget);

        signalement.enPanne = false;
        await tester.ensureVisible(find.text('Envoyer'));
        await tester.tap(find.text('Envoyer'));
        await tester.pumpAndSettle();
        expect(find.text('Merci, c’est envoyé'), findsOneWidget);
      });
    }
  });

  group('« Erreurs signalées » (rédacteurs)', () {
    FauxCompte connecte() => FauxCompte(connecte: 'redacteur@exemple.sn');

    FausseRedaction redactionAvec(List<Signalement> signalements) => FausseRedaction(
          redacteur: true,
          signalements: signalements,
          textes: {
            1: TexteLecon(
              id: 1,
              titre: _lecon.titre,
              publiee: true,
              introduction: _lecon.introduction,
              corps: _lecon.corps,
            ),
          },
        );

    testWidgets('liste, « C’est corrigé », puis « Annuler »', (tester) async {
      final redaction = redactionAvec([
        _signalement(id: 1, precision: 'Il manque un accent.'),
        _signalement(id: 2, exerciceId: 22, ordre: 3, motif: 'corrige_faux', recuLe: '2026-11-21T20:00:00+00:00'),
      ]);
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();

      expect(find.text('Erreurs signalées'), findsOneWidget);
      expect(find.text('2 erreurs signalées par des lecteurs attendent ta vérification.'), findsOneWidget);
      expect(find.text('Leçon · Introduction aux sciences physiques'), findsOneWidget);
      expect(find.text('« Il manque un accent. »'), findsOneWidget);
      expect(find.text('Exercice 3 · Introduction aux sciences physiques'), findsOneWidget);
      expect(find.text('Le corrigé me semble faux'), findsOneWidget);

      await tester.ensureVisible(find.text('C’est corrigé').first);
      await tester.tap(find.text('C’est corrigé').first);
      await tester.pumpAndSettle();
      expect(redaction.traitements, {1: EtatSignalement.traite});
      expect(find.text('« Il manque un accent. »'), findsNothing);
      expect(find.text('1 erreur signalée par un lecteur attend ta vérification.'), findsOneWidget);
      expect(find.text('Signalement traité.'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(redaction.traitements[1], EtatSignalement.nouveau);
      expect(find.text('« Il manque un accent. »'), findsOneWidget);
    });

    testWidgets('« Pas d’erreur » écarte le signalement', (tester) async {
      final redaction = redactionAvec([_signalement()]);
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Pas d’erreur'));
      await tester.tap(find.text('Pas d’erreur'));
      await tester.pumpAndSettle();
      expect(redaction.traitements, {1: EtatSignalement.ecarte});
      expect(find.text('Erreurs signalées'), findsNothing);
      expect(find.text('Rien à vérifier'), findsOneWidget);
    });

    testWidgets('« Demander une correction » : raison préremplie, puis signalement traité', (tester) async {
      final redaction = redactionAvec([_signalement(exerciceId: 22, ordre: 3, motif: 'corrige_faux', precision: 'C’est 12')]);
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Demander une correction'));
      await tester.tap(find.text('Demander une correction'));
      await tester.pumpAndSettle();

      const raison = 'Signalement d’un lecteur (exercice 3), le corrigé me semble faux : « C’est 12 »';
      expect(find.text(raison), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Points à vérifier, un par ligne'), 'Le corrigé de l’exercice 3 est-il juste ?');
      await tester.tap(find.text('Demander'));
      await tester.pumpAndSettle();

      expect(redaction.corrections.single.motif, raison);
      expect(redaction.corrections.single.points, ['Le corrigé de l’exercice 3 est-il juste ?']);
      expect(redaction.traitements, {1: EtatSignalement.traite});
      expect(find.text('Correction demandée, signalement traité.'), findsOneWidget);
      expect(find.text('Corrections en cours'), findsOneWidget);
    });

    testWidgets('erreur réseau en traitant : message, signalement gardé', (tester) async {
      final redaction = redactionAvec([_signalement()])..pannes['traiter'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: connecte(), redaction: redaction, chemin: '/validation');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('C’est corrigé'));
      await tester.tap(find.text('C’est corrigé'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pas de connexion'), findsOneWidget);
      expect(redaction.traitements, isEmpty);
      expect(find.text('Erreurs signalées'), findsOneWidget);
    });

    for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
      testWidgets('carte sans débordement à 200 % ($nom)', (tester) async {
        final redaction = redactionAvec([
          _signalement(exerciceId: 22, ordre: 3, motif: 'pas_comme_cahier', precision: 'Dans mon cahier ' * 10),
        ]);
        await lancerApp(
          tester,
          depot: FauxDepot(),
          compte: connecte(),
          redaction: redaction,
          chemin: '/validation',
          taille: taille,
          echelleTexte: 2,
        );
        await tester.pumpAndSettle();
        await montrer(tester, find.text('Pas d’erreur'));
        expect(find.text('Pas d’erreur'), findsOneWidget);
      });
    }
  });
}
