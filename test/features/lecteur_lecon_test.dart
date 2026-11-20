// « Écouter la leçon » : comportement du lecteur (IMPLEMENTATION_LECTEUR_VOCAL.md,
// section 5) avec un faux moteur vocal, puis la barre dans la vraie
// application : absente sans script, pause en ouvrant les exercices, arrêt en
// quittant la leçon, pas de débordement à 200 %.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/exercices/exercices_screen.dart';
import 'package:samaclasse/features/lecon/lecon_screen.dart';
import 'package:samaclasse/features/lecon/lecteur_lecon.dart';

import '../outils/faux_depot.dart';

const _script = [
  SegmentAudio(lang: 'fr-FR', texte: 'Leçon : le présent simple.'),
  SegmentAudio(lang: 'en-GB', texte: 'The present simple.'),
  SegmentAudio(lang: 'fr-FR', texte: 'On l’emploie pour les habitudes.'),
];

/// Journal attendu pour la lecture d'un passage dans sa langue.
List<String> _lu(SegmentAudio s, [String? langue]) => ['langue ${langue ?? s.lang}', 'dire ${s.texte}'];

void main() {
  group('Langues', () {
    test('variantes proches, jamais une autre langue', () {
      expect(languesAEssayer('en-GB'), ['en-GB', 'en-US', 'en']);
      expect(languesAEssayer('fr-FR'), ['fr-FR', 'fr-CA', 'fr']);
      expect(languesAEssayer('es-ES'), ['es-ES', 'es-US', 'es-MX', 'es']);
      expect(languesAEssayer('de-DE'), ['de-DE', 'de']);
    });

    test('avertissement lisible par un élève', () {
      expect(
        messageVoixAbsentes(['en-GB']),
        'Voix anglaise absente de ce téléphone : ces passages sont sautés. '
        'Installe-la dans les réglages de synthèse vocale.',
      );
      expect(messageVoixAbsentes(['en-GB', 'en-US', 'es-ES']), startsWith('Voix anglaise, espagnole absentes'));
      expect(messageVoixAbsentes(['en-GB', 'es-ES']), endsWith('Installe-les dans les réglages de synthèse vocale.'));
    });
  });

  group('LecteurLecon', () {
    test('lit tout dans l’ordre, change de voix, puis revient au début', () async {
      final moteur = FauxMoteurVocal();
      final lecteur = LecteurLecon(_script, moteur);
      await lecteur.lire();
      expect(moteur.vitesse, 0.45);
      expect(moteur.journal, [for (final s in _script) ..._lu(s)]);
      expect(lecteur.etat, EtatLecteur.arrete);
      expect(lecteur.index, 0);
    });

    test('pause garde la position ; la reprise relit le passage depuis son début', () async {
      final moteur = FauxMoteurVocal(automatique: false);
      final lecteur = LecteurLecon(_script, moteur);
      lecteur.lire().ignore();
      await pumpEventQueue();
      moteur.finirPassage();
      await pumpEventQueue();
      expect(lecteur.index, 1);

      await lecteur.pause();
      await pumpEventQueue();
      expect(lecteur.etat, EtatLecteur.pause);
      expect(lecteur.index, 1);
      expect(moteur.journal.last, 'arrêt');

      moteur.journal.clear();
      lecteur.lire().ignore();
      await pumpEventQueue();
      expect(moteur.journal, _lu(_script[1]));
      expect(lecteur.etat, EtatLecteur.lecture);
    });

    test('suivant et précédent : la lecture continue si elle était en cours', () async {
      final moteur = FauxMoteurVocal(automatique: false);
      final lecteur = LecteurLecon(_script, moteur);
      lecteur.lire().ignore();
      await pumpEventQueue();

      lecteur.suivant().ignore();
      await pumpEventQueue();
      expect(lecteur.index, 1);
      expect(lecteur.etat, EtatLecteur.lecture);
      expect(moteur.journal.last, 'dire ${_script[1].texte}');

      lecteur.precedent().ignore();
      await pumpEventQueue();
      expect(lecteur.index, 0);
      expect(moteur.journal.last, 'dire ${_script[0].texte}');
      // Une seule voix à la fois : l'ancienne boucle ne reprend pas.
      expect(moteur.journal.where((e) => e.startsWith('dire')).length, 3);
    });

    test('suivant à l’arrêt : se place sans lire', () async {
      final moteur = FauxMoteurVocal();
      final lecteur = LecteurLecon(_script, moteur);
      await lecteur.suivant();
      expect(lecteur.index, 1);
      expect(lecteur.etat, EtatLecteur.pause);
      expect(moteur.journal.where((e) => e.startsWith('dire')), isEmpty);
      // Pas de dépassement du dernier passage.
      await lecteur.allerA(99);
      expect(lecteur.index, 2);
    });

    test('arrêt : voix coupée et retour au premier passage', () async {
      final moteur = FauxMoteurVocal(automatique: false);
      final lecteur = LecteurLecon(_script, moteur);
      lecteur.lire().ignore();
      await pumpEventQueue();
      moteur.finirPassage();
      await pumpEventQueue();

      await lecteur.arreter();
      await pumpEventQueue();
      expect(lecteur.etat, EtatLecteur.arrete);
      expect(lecteur.index, 0);
      expect(moteur.parle, isFalse);
      expect(moteur.journal.last, 'arrêt');
    });

    test('voix exacte absente : variante proche (en-GB → en-US)', () async {
      final moteur = FauxMoteurVocal(langues: {'fr-FR', 'en-US'});
      final lecteur = LecteurLecon(_script, moteur);
      await lecteur.lire();
      expect(moteur.journal, [..._lu(_script[0]), ..._lu(_script[1], 'en-US'), ..._lu(_script[2])]);
      expect(lecteur.languesAbsentes, isEmpty);
    });

    test('langue absente : passage sauté, jamais lu par une autre voix', () async {
      final moteur = FauxMoteurVocal(langues: {'fr-FR'});
      final lecteur = LecteurLecon(_script, moteur);
      await lecteur.lire();
      expect(moteur.journal, [..._lu(_script[0]), ..._lu(_script[2])]);
      expect(lecteur.languesAbsentes, {'en-GB'});
      expect(lecteur.etat, EtatLecteur.arrete);
    });

    test('détruit en pleine lecture : voix coupée, plus aucune notification', () async {
      final moteur = FauxMoteurVocal(automatique: false);
      final lecteur = LecteurLecon(_script, moteur);
      lecteur.lire().ignore();
      await pumpEventQueue();
      lecteur.dispose();
      await pumpEventQueue();
      expect(moteur.journal.last, 'arrêt');
      expect(moteur.journal.where((e) => e.startsWith('dire')).length, 1);
    });
  });

  group('Barre dans l’écran de leçon', () {
    final ligne = (donneesReelles['lecons'] as Map)['1'] as Map<String, dynamic>;
    final avecScript = {
      ...donneesReelles,
      'lecons': {
        '1': {
          ...ligne,
          'script_audio': [
            for (final s in _script) {'lang': s.lang, 'texte': s.texte},
          ],
        },
      },
    };
    final ecouter = find.byTooltip('Écouter la leçon');

    testWidgets('leçon sans script : aucune barre', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1');
      await tester.pumpAndSettle();
      expect(find.byType(LeconScreen), findsOneWidget);
      expect(ecouter, findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('lecture, changement d’onglet, pause aux exercices, arrêt au retour', (tester) async {
      final moteur = FauxMoteurVocal(automatique: false);
      await lancerApp(tester, depot: FauxDepot(avecScript), moteurVocal: moteur, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      expect(find.text('Écouter la leçon'), findsOneWidget);

      await tester.tap(ecouter);
      await tester.pump();
      expect(find.text(_script[0].texte), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);

      // « À retenir » : la barre et la lecture restent.
      await tester.tap(find.text('À retenir'));
      await tester.pumpAndSettle();
      expect(moteur.parle, isTrue);
      moteur.finirPassage();
      await tester.pumpAndSettle();
      expect(moteur.journal.last, 'dire ${_script[1].texte}');
      expect(find.text(_script[1].texte), findsOneWidget);

      // Exercices ouverts par-dessus : la voix se tait, la position reste.
      final bouton = find.textContaining('Faire les exercices');
      await tester.ensureVisible(bouton);
      await tester.tap(bouton);
      await tester.pumpAndSettle();
      expect(find.byType(ExercicesScreen), findsOneWidget);
      expect(moteur.parle, isFalse);
      expect(moteur.journal.last, 'arrêt');

      GoRouter.of(tester.element(find.byType(ExercicesScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reprendre'), findsOneWidget);
      expect(find.text(_script[1].texte), findsOneWidget);

      // Reprise, puis départ de la leçon : la voix s'arrête.
      await tester.tap(find.byTooltip('Reprendre'));
      await tester.pump();
      expect(moteur.parle, isTrue);
      GoRouter.of(tester.element(find.byType(LeconScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(LeconScreen), findsNothing);
      expect(moteur.parle, isFalse);
    });

    testWidgets('« À retenir » avec son script : la barre lit l’essentiel (D37)', (tester) async {
      const essentiel = [
        SegmentAudio(lang: 'fr-FR', texte: 'À retenir : le présent simple.'),
        SegmentAudio(lang: 'en-GB', texte: 'He drinks.'),
      ];
      final donnees = {
        ...avecScript,
        'lecons': {
          '1': {
            ...((avecScript['lecons'] as Map)['1'] as Map<String, dynamic>),
            'script_retenir': [
              for (final s in essentiel) {'lang': s.lang, 'texte': s.texte},
            ],
          },
        },
      };
      final moteur = FauxMoteurVocal(automatique: false);
      await lancerApp(tester, depot: FauxDepot(donnees), moteurVocal: moteur, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      // « La leçon » : le cours, comme avant.
      await tester.tap(ecouter);
      await tester.pump();
      expect(moteur.journal.last, 'dire ${_script[0].texte}');

      // « À retenir » : la lecture du cours s'arrête, la barre lit l'essentiel.
      await tester.tap(find.text('À retenir'));
      await tester.pumpAndSettle();
      expect(moteur.parle, isFalse);
      expect(find.text('Écouter l’essentiel'), findsOneWidget);
      await tester.tap(find.byTooltip('Écouter l’essentiel'));
      await tester.pump();
      expect(moteur.journal.last, 'dire ${essentiel[0].texte}');
      expect(find.text(essentiel[0].texte), findsOneWidget);

      // Retour à « La leçon » : la barre redevient « Écouter la leçon ».
      await tester.tap(find.text('La leçon'));
      await tester.pumpAndSettle();
      expect(moteur.parle, isFalse);
      expect(ecouter, findsOneWidget);
    });

    testWidgets('voix absente : avertissement affiché', (tester) async {
      await lancerApp(
        tester,
        depot: FauxDepot(avecScript),
        moteurVocal: FauxMoteurVocal(langues: {'fr-FR'}),
        chemin: '/lecon/1',
      );
      await tester.pumpAndSettle();
      await tester.tap(ecouter);
      await tester.pumpAndSettle();
      expect(find.textContaining('Voix anglaise absente'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    for (final (nom, taille) in [
      ('téléphone', tailleTelephone),
      ('web large', tailleWeb),
      ('téléphone en paysage', const Size(844, 390)),
    ]) {
      testWidgets('pas de débordement à 200 % ($nom)', (tester) async {
        await lancerApp(
          tester,
          depot: FauxDepot(avecScript),
          moteurVocal: FauxMoteurVocal(langues: {'fr-FR'}, automatique: false),
          chemin: '/lecon/1',
          taille: taille,
          echelleTexte: 2,
        );
        await tester.pumpAndSettle();
        await tester.tap(ecouter);
        await tester.pumpAndSettle();
        expect(find.textContaining('Voix anglaise absente'), findsNothing);
        expect(find.text(_script[0].texte), findsOneWidget);
        // Cibles tactiles d'au moins 44 px.
        for (final b in tester.widgetList<IconButton>(find.byType(IconButton))) {
          final element = find.byWidget(b);
          if (element.evaluate().isEmpty) continue;
          expect(tester.getSize(element).shortestSide, greaterThanOrEqualTo(44));
        }
      });
    }
  });
}
