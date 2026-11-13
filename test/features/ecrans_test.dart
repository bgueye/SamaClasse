// Tests des quatre écrans avec la vraie application et un faux dépôt.
//
// Ils couvrent ce que CLAUDE.md demande pour un écran : les quatre états
// (chargement, erreur avec « Réessayer », vide, contenu), l'ouverture directe
// d'une adresse (web), le parcours complet de la phase 0, et l'absence de
// débordement sur téléphone (390 px) avec un texte système à 200 %.
//
// Ils compilent aussi `main`/`app`/`router` et tous les écrans : une erreur
// comme les imports manquants de la phase 0 fait désormais échouer `flutter test`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/services/preferences.dart';

import '../outils/faux_depot.dart';

/// Données utiles tirées des réponses enregistrées (4ème, Sciences physiques).
final _lecon = (donneesReelles['lecons'] as Map)['1'] as Map<String, dynamic>;
final String _titreLecon = _lecon['titre'] as String;
final int _nbExercices = (_lecon['exercices'] as List).length;
final String _premiereNotion = ((_lecon['a_retenir'] as List).first as Map)['notion'] as String;

/// Attend la fin des chargements et des animations.
Future<void> _attendre(WidgetTester tester) => tester.pumpAndSettle();

void main() {
  group('Accueil', () {
    testWidgets('chargement, puis matières de la première classe', (tester) async {
      final depot = FauxDepot()..attente = Completer<void>();
      await lancerApp(tester, depot: depot);
      await tester.pump();
      // Pas de pumpAndSettle ici : l'indicateur tourne sans fin.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      depot.attente!.complete();
      await _attendre(tester);
      expect(find.text('Tes matières en 4ème'), findsOneWidget);
      expect(find.text('Sciences physiques'), findsOneWidget);
      expect(find.text('1 leçon prête sur 12 chapitres'), findsOneWidget);
      expect(find.text('Pas encore de leçon, 14 chapitres au programme'), findsOneWidget);
    });

    testWidgets('erreur réseau, puis « Réessayer » au retour du réseau', (tester) async {
      final depot = FauxDepot()..pannes['classes'] = 1;
      await lancerApp(tester, depot: depot);
      await _attendre(tester);
      expect(find.text('Impossible de charger'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await _attendre(tester);
      expect(depot.appels['classes'], 2);
      expect(find.text('Tes matières en 4ème'), findsOneWidget);
    });

    testWidgets('erreur sur les matières seulement : « Réessayer » les recharge', (tester) async {
      final depot = FauxDepot()..pannes['matieres'] = 1;
      await lancerApp(tester, depot: depot);
      await _attendre(tester);
      expect(find.text('Impossible de charger'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await _attendre(tester);
      expect(find.text('Sciences physiques'), findsOneWidget);
    });

    testWidgets('aucune classe en base', (tester) async {
      await lancerApp(tester, depot: FauxDepot({'classes': <Object>[]}));
      await _attendre(tester);
      expect(find.text('Aucune classe pour l’instant'), findsOneWidget);
    });

    testWidgets('classe sans matière', (tester) async {
      await lancerApp(tester, depot: FauxDepot({'classes': donneesReelles['classes']}));
      await _attendre(tester);
      expect(find.text('Pas encore de matière'), findsOneWidget);
    });

    testWidgets('changer de classe : la liste change et le choix est retenu', (tester) async {
      final preferences = FaussesPreferences();
      await lancerApp(tester, depot: FauxDepot(), preferences: preferences);
      await _attendre(tester);

      await tester.tap(find.text('Seconde L'));
      await _attendre(tester);
      expect(find.text('Tes matières en Seconde L'), findsOneWidget);
      expect(preferences.classe, 2);
    });

    testWidgets('la classe retenue est rouverte au lancement', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), preferences: FaussesPreferences(classe: 2));
      await _attendre(tester);
      expect(find.text('Tes matières en Seconde L'), findsOneWidget);
    });

    testWidgets('« Reprendre où tu t’es arrêté » rouvre la dernière leçon', (tester) async {
      final preferences = FaussesPreferences(
        derniere: DerniereLecon(
          id: 1,
          titre: _titreLecon,
          matiere: 'Sciences physiques',
          matiereSlug: 'sciences-physiques',
          classe: '4ème',
        ),
      );
      await lancerApp(tester, depot: FauxDepot(), preferences: preferences);
      await _attendre(tester);
      expect(find.text('Reprendre où tu t’es arrêté'), findsOneWidget);

      await tester.tap(find.text('Continuer la lecture'));
      await _attendre(tester);
      expect(find.text('Faire les exercices ($_nbExercices)'), findsOneWidget);
    });
  });

  group('Matière', () {
    testWidgets('chapitres, état des leçons et filtre « Leçons prêtes »', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/classe/1/matiere/2');
      await _attendre(tester);
      expect(find.text('4ème, 1 leçon prête sur 12 chapitres'), findsOneWidget);
      // Le nombre d'exercices vient de `exercices(count)` (tâche 6 de la phase 0).
      expect(find.text('Leçon prête, $_nbExercices exercices'), findsOneWidget);
      expect(find.text('Grandeurs physiques et mesures'), findsOneWidget);

      await tester.tap(find.text('Leçons prêtes'));
      await _attendre(tester);
      expect(find.text(_titreLecon), findsOneWidget);
      expect(find.text('Grandeurs physiques et mesures'), findsNothing);
    });

    testWidgets('Seconde L : chapitres visibles, « Leçon pas encore disponible »', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/classe/2/matiere/2');
      await _attendre(tester);
      expect(find.text('Leçon pas encore disponible'), findsWidgets);
      expect(find.textContaining('Leçon prête'), findsNothing);
    });

    testWidgets('les remarques internes des chapitres ne sont jamais affichées', (tester) async {
      final chapitres = donneesReelles['chapitres'] as Map<String, dynamic>;
      final avecRemarque = <String, List<String>>{};
      chapitres.forEach((cle, lignes) {
        for (final c in (lignes as List).cast<Map<String, dynamic>>()) {
          final remarque = c['remarque'] as String?;
          if (remarque != null) (avecRemarque[cle] ??= []).add(remarque);
        }
      });
      expect(avecRemarque, isNotEmpty, reason: 'le jeu de données doit contenir des remarques');

      for (final MapEntry(key: cle, value: remarques) in avecRemarque.entries) {
        final [classe, matiere] = cle.split('-');
        // Écran très haut : tous les chapitres sont construits, pas seulement le haut de la liste.
        await lancerApp(tester, depot: FauxDepot(), chemin: '/classe/$classe/matiere/$matiere', taille: const Size(390, 6000));
        await _attendre(tester);
        for (final r in remarques) {
          expect(find.textContaining(r), findsNothing, reason: 'remarque visible dans $cle');
        }
      }
    });

    testWidgets('erreur réseau, puis « Réessayer »', (tester) async {
      final depot = FauxDepot()..pannes['chapitres'] = 1;
      await lancerApp(tester, depot: depot, chemin: '/classe/1/matiere/2');
      await _attendre(tester);
      expect(find.text('Impossible de charger'), findsOneWidget);
      expect(find.text('Mes cours'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await _attendre(tester);
      expect(find.text('Grandeurs physiques et mesures'), findsOneWidget);
    });

    testWidgets('matière sans chapitre', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/classe/1/matiere/999');
      await _attendre(tester);
      expect(find.text('Aucun chapitre'), findsOneWidget);
    });

    testWidgets('adresse invalide : page introuvable', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/classe/x/matiere/2');
      await _attendre(tester);
      expect(find.text('Page introuvable'), findsOneWidget);
    });
  });

  group('Leçon', () {
    testWidgets('adresse /lecon/1 ouverte directement (web)', (tester) async {
      final preferences = FaussesPreferences();
      await lancerApp(tester, depot: FauxDepot(), preferences: preferences, chemin: '/lecon/1');
      await _attendre(tester);
      expect(find.text(_titreLecon), findsOneWidget);
      expect(find.text('Sciences physiques, 4ème'), findsOneWidget);
      // Mémorisée pour « Reprendre où tu t’es arrêté ».
      expect(preferences.derniere?.id, 1);
    });

    testWidgets('onglet « À retenir »', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1');
      await _attendre(tester);
      await tester.tap(find.text('À retenir').first);
      await _attendre(tester);
      expect(find.text(_premiereNotion), findsOneWidget);
    });

    testWidgets('leçon non publiée : « Leçon pas encore disponible »', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/999');
      await _attendre(tester);
      expect(find.text('Leçon pas encore disponible'), findsOneWidget);
    });

    testWidgets('erreur réseau, puis « Réessayer »', (tester) async {
      final depot = FauxDepot()..pannes['lecon'] = 1;
      await lancerApp(tester, depot: depot, chemin: '/lecon/1');
      await _attendre(tester);
      expect(find.text('Impossible de charger'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await _attendre(tester);
      expect(find.text(_titreLecon), findsOneWidget);
    });
  });

  group('Exercices', () {
    testWidgets('série complète, bilan, puis « Recommencer »', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/exercices');
      await _attendre(tester);
      await _faireTouteLaSerie(tester);
      expect(find.text('Exercices terminés'), findsOneWidget);

      // Le bilan est une liste paresseuse : le bouton, en bas, n'existe qu'une fois atteint.
      await tester.scrollUntilVisible(find.text('Recommencer'), 300, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Recommencer'));
      await _attendre(tester);
      expect(find.text('Exercice 1 sur $_nbExercices'), findsOneWidget);
    });

    testWidgets('leçon sans exercice disponible', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/999/exercices');
      await _attendre(tester);
      expect(find.text('Pas d’exercices'), findsOneWidget);
    });

    testWidgets('erreur réseau, puis « Réessayer »', (tester) async {
      // Deux pannes : ouvrir /lecon/1/exercices construit aussi la page de la
      // leçon en dessous (pour le bouton retour), qui demande elle aussi la leçon.
      final depot = FauxDepot()..pannes['lecon'] = 2;
      await lancerApp(tester, depot: depot, chemin: '/lecon/1/exercices');
      await _attendre(tester);
      expect(find.text('Impossible de charger'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await _attendre(tester);
      expect(find.text('Exercice 1 sur $_nbExercices'), findsOneWidget);
    });
  });

  testWidgets('parcours de la phase 0 : accueil → matière → leçon → exercices → retour', (tester) async {
    await lancerApp(tester, depot: FauxDepot());
    await _attendre(tester);

    await tester.tap(find.text('Sciences physiques'));
    await _attendre(tester);
    await tester.tap(find.text(_titreLecon));
    await _attendre(tester);

    final bouton = find.text('Faire les exercices ($_nbExercices)');
    await tester.scrollUntilVisible(bouton, 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(bouton);
    await _attendre(tester);
    expect(find.text('Exercice 1 sur $_nbExercices'), findsOneWidget);

    await tester.tap(find.text('La leçon'));
    await _attendre(tester);
    expect(find.text(_titreLecon), findsOneWidget);
  });

  group('Pas de débordement, texte système à 200 %', () {
    // Écran haut pour construire toute la page et pas seulement son début.
    const telephoneLong = Size(390, 5000);

    for (final chemin in ['/', '/classe/1/matiere/2', '/classe/2/matiere/5', '/lecon/1', '/lecon/999']) {
      testWidgets('téléphone : $chemin', (tester) async {
        await lancerApp(tester, depot: FauxDepot(), chemin: chemin, taille: telephoneLong, echelleTexte: 2);
        await _attendre(tester);
      });
    }

    testWidgets('téléphone : onglet « À retenir »', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1', taille: telephoneLong, echelleTexte: 2);
      await _attendre(tester);
      await tester.tap(find.text('À retenir').first);
      await _attendre(tester);
    });

    testWidgets('téléphone : chaque exercice corrigé, puis le bilan', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1/exercices', taille: telephoneLong, echelleTexte: 2);
      await _attendre(tester);
      await _faireTouteLaSerie(tester);
    });

    testWidgets('états d’erreur sur petit écran de téléphone', (tester) async {
      final depot = FauxDepot()..pannes['classes'] = 1;
      await lancerApp(tester, depot: depot, echelleTexte: 2);
      await _attendre(tester);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    for (final chemin in ['/', '/classe/1/matiere/2', '/lecon/1', '/lecon/1/exercices']) {
      testWidgets('web large : $chemin', (tester) async {
        await lancerApp(tester, depot: FauxDepot(), chemin: chemin, taille: tailleWeb);
        await _attendre(tester);
      });
    }
  });
}

/// Valide chaque exercice sans répondre (une question vide compte faux),
/// passe au suivant, et s'arrête sur le bilan.
Future<void> _faireTouteLaSerie(WidgetTester tester) async {
  for (var i = 1; i <= _nbExercices; i++) {
    expect(find.text('Exercice $i sur $_nbExercices'), findsOneWidget);
    final valider = find.text('Valider');
    await tester.tap(valider.evaluate().isNotEmpty ? valider : find.text('Voir le corrigé'));
    await _attendre(tester);
    await tester.tap(find.text(i == _nbExercices ? 'Voir mon résultat' : 'Exercice suivant'));
    await _attendre(tester);
  }
}
