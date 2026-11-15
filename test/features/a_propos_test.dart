// Page « À propos » (décision D18).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/version.dart';

import '../outils/faux_depot.dart';

void main() {
  test('la version affichée est celle de pubspec.yaml', () {
    final ligne = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = ligne.split(':')[1].trim().split('+').first;
    expect(versionApplication, version, reason: 'changer aussi lib/core/version.dart');
  });

  testWidgets('ouverte depuis l’accueil par le bouton « À propos »', (tester) async {
    await lancerApp(tester, depot: FauxDepot());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('À propos'));
    await tester.pumpAndSettle();

    expect(find.text('Le programme scolaire du Sénégal, leçon par leçon.'), findsOneWidget);
    expect(find.text('D’où viennent les leçons ?'), findsOneWidget);
    expect(find.text('Tes données'), findsOneWidget);
    // Texte validé par Bocar le 15/11/2026 (phase 3) : la lecture reste sans
    // compte, le texte saisi n'est jamais envoyé, le suivi est décrit tel
    // qu'il est enregistré.
    expect(find.textContaining('Pas besoin de compte pour lire les leçons'), findsOneWidget);
    expect(find.textContaining('ce n’est jamais envoyé'), findsOneWidget);
    expect(find.textContaining('les leçons que tu ouvres et tes résultats aux exercices'), findsOneWidget);
    expect(find.text('Pour les parents'), findsOneWidget);
    expect(find.textContaining('Jamais ce qu’il écrit.'), findsOneWidget);
    expect(find.textContaining('Supprimer un profil efface aussi son suivi.'), findsOneWidget);
    // Ancienne promesse, devenue fausse avec le suivi (phase 3).
    expect(find.textContaining('rien n’est envoyé'), findsNothing);
    expect(find.textContaining('Pas de compte à créer'), findsNothing);
    expect(find.text('Conçue par Bocar Gueye'), findsOneWidget);
    expect(find.text('Version $versionApplication'), findsOneWidget);
    // Pas d'adresse de contact (demande de Bocar).
    expect(find.textContaining('@'), findsNothing);

    await tester.tap(find.text('Mes cours'));
    await tester.pumpAndSettle();
    expect(find.text('Tes matières en 4ème'), findsOneWidget);
  });

  testWidgets('« Licences » ouvre la page des licences', (tester) async {
    await lancerApp(tester, depot: FauxDepot(), chemin: '/a-propos');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Licences')); // en bas de la page
    await tester.pumpAndSettle();
    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('sans débordement à 200 % sur téléphone', (tester) async {
    await lancerApp(tester, depot: FauxDepot(), chemin: '/a-propos', taille: const Size(390, 3000), echelleTexte: 2);
    await tester.pumpAndSettle();
    expect(find.text('Licences'), findsOneWidget);
  });
}
