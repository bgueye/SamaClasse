// « Envoyer cette leçon » et « Fiche à imprimer » (D35) : contenu de la
// fiche par type d'exercice, PDF fabriqué avec les vraies polices, message
// envoyé, et les deux icônes de l'écran de leçon.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/fiche/contenu_fiche.dart';
import 'package:samaclasse/features/fiche/fiche_pdf.dart';
import 'package:samaclasse/features/lecon/envoi_lecon.dart';

import '../outils/faux_depot.dart';

final _ligne = (donneesReelles['lecons'] as Map)['1'] as Map<String, dynamic>;
final _lecon = Lecon.fromJson(_ligne);

/// Exercice fictif d'un type donné, pour couvrir chaque zone de réponse.
Exercice _ex(String type, {String enonce = 'Consigne.', Object? donnees, Object? reponse, String? corrige}) =>
    Exercice.fromJson({
      'id': 900,
      'ordre': 1,
      'niveau': 'j_applique',
      'type': type,
      'enonce': enonce,
      'donnees': donnees,
      'reponse': reponse,
      'corrige': corrige,
    });

void main() {
  group('Markdown vers blocs', () {
    test('marques retirées, puces, titres, lignes vides', () {
      expect(
        blocsDepuisMarkdown('## **Je connais.**\n\n- un *mot*\n1. Complète : [lien](https://x.sn)'),
        const [TexteFiche('Je connais.'), TexteFiche('• un mot'), TexteFiche('1. Complète : lien')],
      );
      expect(blocsDepuisMarkdown(null), isEmpty);
      expect(sansMarques('3 * 4 = 12'), '3 * 4 = 12', reason: 'une multiplication reste');
    });

    test('tableau : en-tête et cases vides, sans la ligne de séparation', () {
      final blocs = blocsDepuisMarkdown('Complète.\n| État | Exemple |\n| --- | :---: |\n| solide |  |');
      expect(blocs.first, const TexteFiche('Complète.'));
      final tableau = blocs[1] as TableauFiche;
      expect(tableau.lignes, [
        ['État', 'Exemple'],
        ['solide', ''],
      ]);
    });

    test('schéma : sa description seulement', () {
      final blocs = blocsDepuisMarkdown('![Coupe de la Terre](https://x.sn/a.png)');
      expect((blocs.single as SchemaFiche).description, 'Coupe de la Terre');
    });

    test('questions numérotées', () {
      expect(questionsNumerotees('**Je sais.**\n1. Un ?\n2) Deux ?\nTexte'), 2);
    });
  });

  group('Zone de réponse et corrigé, par type', () {
    test('QCM : une case par choix ; corrigé : le bon choix', () {
      final e = _ex('qcm', donnees: {
        'questions': [
          {'q': 'Le baobab est :', 'choix': ['herbacé', 'arborescent']},
        ],
      }, reponse: [1]);
      final choix = zoneReponse(e).single as ChoixFiche;
      expect(choix.question, 'Le baobab est :');
      expect(choix.choix, ['herbacé', 'arborescent']);
      expect(corrigeFiche(e), const [TexteFiche('1. arborescent')]);
    });

    test('vrai ou faux : cases, et lignes si on demande de corriger', () {
      final e = _ex('vrai_faux',
          enonce: 'Vrai ou faux ? Si c’est faux, corrige la phrase.',
          donnees: {'affirmations': ['A', 'B']},
          reponse: [true, false]);
      final zone = zoneReponse(e);
      expect((zone.first as VraiFauxFiche).affirmations, ['A', 'B']);
      expect(zone.skip(1), const [TexteFiche('Corrections :'), LignesFiche(2)]);
      expect(corrigeFiche(e), const [TexteFiche('1. Vrai'), TexteFiche('2. Faux')]);
      expect(zoneReponse(_ex('vrai_faux', donnees: {'affirmations': ['A']}, reponse: [true])).length, 1);
    });

    test('relier : colonnes dans l’ordre des données', () {
      final e = _ex('relier', donnees: {
        'gauche': ['1492', '1500'],
        'droite': ['Cabral', 'Colomb'],
      }, reponse: {'1492': 'Colomb', '1500': 'Cabral'});
      final r = zoneReponse(e).single as RelierFiche;
      expect(r.gauche, ['1492', '1500']);
      expect(r.droite, ['Cabral', 'Colomb']);
      expect(corrigeFiche(e), const [TexteFiche('1492 → Colomb'), TexteFiche('1500 → Cabral')]);
    });

    test('tableau : rien de plus si l’énoncé a son tableau ; sinon champs ou classement', () {
      expect(zoneReponse(_ex('tableau', enonce: '| A | B |\n| --- | --- |\n| x |  |', reponse: ['y'])), isEmpty);
      expect((zoneReponse(_ex('tableau', reponse: ['a', 'b'])).single as ChampsFiche).libelles, ['1.', '2.']);
      final classement = zoneReponse(_ex('tableau', donnees: {
        'categories': {'homogene': 'Homogène'},
      }, reponse: {
        'homogene': ['air'],
        'heterogene': ['eau + sable'],
      })).single as ClassementFiche;
      expect(classement.elements, ['air', 'eau + sable']);
      expect(classement.categories, ['Heterogene', 'Homogène']);
    });

    test('calcul : un champ par valeur ; questions de cours : deux lignes par question', () {
      final calcul = _ex('calcul', reponse: {'totaux': [5, 7], 'aire_m2': 8.5});
      expect((zoneReponse(calcul).single as ChampsFiche).libelles.length, 3);
      expect(corrigeFiche(calcul).last, const TexteFiche('Aire m2 : 8,5'));
      expect(zoneReponse(_ex('question_cours', enonce: '1. A ?\n2. B ?\n3. C ?')), const [LignesFiche(6)]);
      expect(zoneReponse(_ex('question_cours', enonce: 'Définis le mot.')), const [LignesFiche(4)]);
      expect(zoneReponse(_ex('redaction')), const [LignesFiche(8)]);
    });

    test('corrigé rédigé d’abord ; sinon correction libre', () {
      expect(corrigeFiche(_ex('redaction', corrige: '*Exemple :* texte.')), const [TexteFiche('Exemple : texte.')]);
      expect(corrigeFiche(_ex('redaction')), const [TexteFiche('Correction libre : voir avec l’enseignant.')]);
    });
  });

  group('Fiche d’une leçon', () {
    test('en-tête, notions, exercices numérotés, lien', () {
      final c = contenuFiche(_lecon);
      expect(c.titre, _lecon.titre);
      expect(c.surTitre, '${_lecon.contexte!.matiere}, ${_lecon.contexte!.classe} · Leçon ${_lecon.numero}');
      expect(c.retenir.length, _lecon.aRetenir.length);
      expect([for (final e in c.exercices) e.numero], [for (var i = 1; i <= _lecon.exercices.length; i++) i]);
      expect(c.lien, 'https://samaclasse.app/lecon/${_lecon.id}');
      expect(nomFiche(_lecon), 'Fiche - ${_lecon.titre}');
    });

    testWidgets('PDF avec les vraies polices, tous les types d’exercices', (tester) async {
      final lecon = Lecon.fromJson({
        ..._ligne,
        'exercices': [
          ...(_ligne['exercices'] as List),
          {'id': 901, 'ordre': 90, 'niveau': 'je_connais', 'type': 'qcm', 'enonce': 'Choisis.', 'donnees': {'questions': [{'q': 'Q ?', 'choix': ['a', 'b']}]}, 'reponse': [0], 'corrige': null},
          {'id': 902, 'ordre': 91, 'niveau': 'je_connais', 'type': 'relier', 'enonce': 'Relie.', 'donnees': {'gauche': ['1444'], 'droite': ['Cap-Vert']}, 'reponse': {'1444': 'Cap-Vert'}, 'corrige': null},
          {'id': 903, 'ordre': 92, 'niveau': 'j_applique', 'type': 'tableau', 'enonce': 'Classe.', 'donnees': null, 'reponse': {'a': ['x'], 'b': ['y']}, 'corrige': null},
          {'id': 904, 'ordre': 93, 'niveau': 'j_applique', 'type': 'calcul', 'enonce': 'Calcule 10⁻³ × 2.', 'donnees': null, 'reponse': {'resultat': 0.002}, 'corrige': null},
          {'id': 905, 'ordre': 94, 'niveau': 'je_reflechis', 'type': 'tableau', 'enonce': '| A | B |\n| --- | --- |\n| x |  |\n![Schéma](https://x.sn/s.png)', 'donnees': null, 'reponse': ['y'], 'corrige': null},
        ],
      });
      final octets = await tester.runAsync(() async => fabriquerFichePdf(contenuFiche(lecon), await chargerPolicesFiche()));
      expect(ascii.decode(octets!.sublist(0, 5)), '%PDF-');
      expect(octets.length, greaterThan(10000));
    });
  });

  group('Envoi', () {
    test('message : titre, matière, classe et lien', () {
      expect(
        messageEnvoi(_lecon),
        'Révise « ${_lecon.titre} » (${_lecon.contexte!.matiere.toLowerCase()}, ${_lecon.contexte!.classe}) '
        'sur SamaClasse : https://samaclasse.app/lecon/${_lecon.id}',
      );
    });
  });

  group('Écran de leçon', () {
    testWidgets('« Envoyer cette leçon » : message, envoi, copie du lien', (tester) async {
      final partage = FauxPartage();
      await lancerApp(tester, depot: FauxDepot(), partage: partage, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Envoyer cette leçon'));
      await tester.pumpAndSettle();
      expect(find.text(messageEnvoi(_lecon)), findsOneWidget);

      await tester.tap(find.text('Envoyer par une application'));
      await tester.pumpAndSettle();
      expect(partage.envois, [messageEnvoi(_lecon)]);
      expect(find.text('Choisis l’application : WhatsApp, SMS…'), findsOneWidget);

      await tester.tap(find.text('Copier le lien'));
      await tester.pumpAndSettle();
      expect(partage.copies, ['https://samaclasse.app/lecon/${_lecon.id}']);
      expect(find.text('Lien copié.'), findsOneWidget);
    });

    testWidgets('« Fiche à imprimer » : un PDF nommé d’après la leçon', (tester) async {
      final impression = FausseImpression();
      await lancerApp(tester, depot: FauxDepot(), impression: impression, chemin: '/lecon/1');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Fiche à imprimer'));
        // Le PDF se fabrique pour de vrai (polices, mise en page).
        for (var i = 0; i < 100 && impression.documents.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      expect(impression.noms, ['Fiche - ${_lecon.titre}']);
      expect(ascii.decode(impression.documents.single.sublist(0, 5)), '%PDF-');
    });

    for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
      testWidgets('fenêtre d’envoi sans débordement à 200 % ($nom)', (tester) async {
        await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1', taille: taille, echelleTexte: 2);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Envoyer cette leçon'));
        await tester.pumpAndSettle();
        expect(find.text('Copier le lien'), findsOneWidget);
        expect(find.byType(BottomSheet), findsOneWidget);
      });
    }
  });
}
