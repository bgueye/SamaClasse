// Hors connexion vu de l'élève (décision D16) : la vraie application avec
// ContenuHorsLigne, un serveur simulé et une copie locale.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/widgets/bandeau_hors_connexion.dart';
import 'package:samaclasse/data/data.dart';

import '../outils/faux_depot.dart';

final _lundi = DateTime(2026, 11, 13, 20);

String _copieDuLundi([Instantane? contenu]) =>
    encoderCopie(CopieContenu(contenu: contenu ?? instantaneReel(), telechargeeLe: _lundi));

void main() {
  testWidgets('mode avion avec une copie : tout s’affiche, bandeau « Hors connexion »', (tester) async {
    final contenu = ContenuHorsLigne(
      source: FausseSource()..enPanne = true,
      stockage: FauxStockage(_copieDuLundi()),
    );
    await lancerApp(tester, depot: contenu);
    await tester.pumpAndSettle();

    expect(find.text('Tes matières en 4ème'), findsOneWidget);
    expect(find.text('Hors connexion · contenu du 13/11/2026'), findsOneWidget);

    // On peut lire une leçon et faire ses exercices sans réseau.
    // Avec le bandeau, la matière peut être juste sous le bas de l'écran.
    await tester.ensureVisible(find.text('Sciences physiques'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sciences physiques'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Introduction aux sciences physiques'));
    await tester.pumpAndSettle();
    expect(find.text('Faire les exercices (5)', skipOffstage: false), findsOneWidget);
    expect(find.text('Hors connexion · contenu du 13/11/2026'), findsOneWidget);
  });

  testWidgets('en ligne : pas de bandeau', (tester) async {
    final contenu = ContenuHorsLigne(source: FausseSource(), stockage: FauxStockage(_copieDuLundi()));
    await lancerApp(tester, depot: contenu);
    await tester.pumpAndSettle();
    expect(find.textContaining('Hors connexion'), findsNothing);
  });

  testWidgets('premier lancement en mode avion : « Réessayer » au retour du réseau', (tester) async {
    final source = FausseSource()..enPanne = true;
    await lancerApp(tester, depot: ContenuHorsLigne(source: source, stockage: FauxStockage()));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger'), findsOneWidget);

    source.enPanne = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Tes matières en 4ème'), findsOneWidget);
  });

  testWidgets('leçon publiée pendant la lecture : l’écran se met à jour tout seul', (tester) async {
    // Copie du lundi : Sciences physiques n'a qu'une leçon prête. Le serveur
    // en annonce deux : la liste doit changer sans action de l'élève.
    final serveur = instantaneReel();
    final ligne = serveur.matieresBrutes.firstWhere((m) => m['classe_id'] == 1 && m['matiere_id'] == 2);
    ligne['nb_lecons'] = 2;
    // Le serveur ne répond qu'à notre signal : on voit d'abord la copie.
    final source = FausseSource(serveur)..attente = Completer<void>();

    await lancerApp(tester, depot: ContenuHorsLigne(source: source, stockage: FauxStockage(_copieDuLundi())));
    await tester.pumpAndSettle();
    expect(find.text('1 leçon prête sur 12 chapitres'), findsOneWidget);

    source.attente!.complete();
    await tester.pumpAndSettle();
    expect(find.text('2 leçons prêtes sur 12 chapitres'), findsOneWidget);
    expect(find.text('1 leçon prête sur 12 chapitres'), findsNothing);
  });

  testWidgets('tirer pour actualiser sans réseau : la liste reste, le bandeau apparaît', (tester) async {
    final source = FausseSource();
    await lancerApp(tester, depot: ContenuHorsLigne(source: source, stockage: FauxStockage(_copieDuLundi())));
    await tester.pumpAndSettle();
    expect(find.byType(BandeauHorsConnexion), findsOneWidget);
    expect(find.textContaining('Hors connexion'), findsNothing);

    source.enPanne = true;
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Tes matières en 4ème'), findsOneWidget);
    expect(find.textContaining('Hors connexion'), findsOneWidget);
  });

  testWidgets('bandeau sans débordement à 200 % sur téléphone', (tester) async {
    final contenu = ContenuHorsLigne(
      source: FausseSource()..enPanne = true,
      stockage: FauxStockage(_copieDuLundi()),
    );
    await lancerApp(tester, depot: contenu, echelleTexte: 2);
    await tester.pumpAndSettle();
    // Un débordement ferait échouer le test de lui-même.
    expect(find.textContaining('Hors connexion'), findsOneWidget);
  });

  test('texte du bandeau', () {
    expect(texteHorsConnexion(DateTime(2026, 1, 5)), 'Hors connexion · contenu du 05/01/2026');
    expect(texteHorsConnexion(null), 'Hors connexion');
  });
}
