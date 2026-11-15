// Captures d'écran de l'application, pour vérifier l'interface à l'œil :
// alignement sur les lignes Seyès, débordements, rendu des polices.
//
// Lancer :
//   flutter test tool/captures/captures_test.dart
// Images produites dans build/captures/ (ignoré par git).
//
// Ce n'est pas un test de non-régression (rien n'est comparé) : il est rangé
// dans tool/ pour que `flutter test` ne le lance pas à chaque fois. Les
// polices réelles (Atkinson, Playwrite, icônes Material) sont chargées, alors
// que les tests ordinaires utilisent une police de test à chasse fixe.
// Données : le même jeu enregistré que les tests d'écrans.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/app.dart';
import 'package:samaclasse/core/services/preferences.dart';
import 'package:samaclasse/core/theme/theme.dart';
import 'package:samaclasse/data/data.dart';

import '../../test/outils/faux_depot.dart';
import '../../test/outils/polices.dart';

const _dossier = 'build/captures';

/// Compte avec une semaine de travail pour Awa (leçon 1, exercices 20 à 24).
FauxCompte _compteAvecSuivi() {
  final maintenant = DateTime.now();
  ResultatExercice r(int exercice, int minutes, {bool reussi = true, int? bonnes, int? total}) => ResultatExercice(
        id: 'capture-$exercice-$minutes',
        enfantId: 1,
        exerciceId: exercice,
        reussi: reussi,
        bonnes: bonnes,
        total: total,
        autoEvaluation: bonnes == null,
        faitLe: maintenant.subtract(Duration(minutes: minutes)),
      );
  return FauxCompte(
    connecte: 'parent@exemple.sn',
    enfants: _enfants,
    lectures: [LectureLecon(enfantId: 1, leconId: 1, lueLe: maintenant)],
    resultats: [
      r(20, 9),
      r(21, 8, reussi: false, bonnes: 4, total: 6),
      r(22, 6, bonnes: 6, total: 6),
      r(23, 4, reussi: false, bonnes: 3, total: 5),
      r(24, 2, reussi: false),
    ],
  );
}

/// Profils de l'espace parents pour les captures.
const _enfants = [
  Enfant(id: 1, prenom: 'Awa', classeId: 1),
  Enfant(id: 2, prenom: 'Moussa', classeId: 2),
];

/// Enregistre l'écran entier en PNG.
Future<void> _capturer(WidgetTester tester, String nom) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image = await captureImage(find.byType(SamaClasseApp).evaluate().single);
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dossier/$nom.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

/// Fait défiler la zone défilante principale (la dernière construite).
Future<void> _defiler(WidgetTester tester, double distance) async {
  await tester.drag(find.byType(Scrollable).last, Offset(0, -distance));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(chargerPolicesReelles);

  for (final (suffixe, echelle) in [('', 1.0), ('_200', 2.0)]) {
    testWidgets('téléphone$suffixe', (tester) async {
      Future<void> ouvrir(String chemin) =>
          lancerApp(tester, depot: FauxDepot(), chemin: chemin, echelleTexte: echelle);

      await ouvrir('/');
      await _capturer(tester, 'tel${suffixe}_01_accueil');

      await ouvrir('/classe/1/matiere/2');
      await _capturer(tester, 'tel${suffixe}_02_matiere');

      await ouvrir('/lecon/1');
      await _capturer(tester, 'tel${suffixe}_03_lecon_a');
      for (final lettre in ['b', 'c', 'd', 'e', 'f']) {
        await _defiler(tester, 600);
        await _capturer(tester, 'tel${suffixe}_03_lecon_$lettre');
      }

      await ouvrir('/lecon/1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('À retenir').first);
      await _capturer(tester, 'tel${suffixe}_04_a_retenir');

      await ouvrir('/lecon/1/exercices');
      await tester.pumpAndSettle();
      for (var i = 1; i <= 5; i++) {
        await _capturer(tester, 'tel${suffixe}_05_exercice${i}_a');
        final valider = find.text('Valider');
        await tester.tap(valider.evaluate().isNotEmpty ? valider : find.text('Voir le corrigé'));
        await _capturer(tester, 'tel${suffixe}_05_exercice${i}_b_corrige');
        // Bas de l'exercice corrigé : corrigé, « Avais-tu juste ? »…
        await _defiler(tester, 3000);
        await _capturer(tester, 'tel${suffixe}_05_exercice${i}_c_bas');
        await tester.tap(find.text(i == 5 ? 'Voir mon résultat' : 'Exercice suivant'));
        await tester.pumpAndSettle();
      }
      await _capturer(tester, 'tel${suffixe}_06_bilan');

      await ouvrir('/a-propos');
      await _capturer(tester, 'tel${suffixe}_07_a_propos');

      // Espace parents (phase 2) : connexion, puis profils enfants.
      await ouvrir('/compte');
      await _capturer(tester, 'tel${suffixe}_08_connexion');
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: FauxCompte(connecte: 'parent@exemple.sn', enfants: _enfants),
        preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa')),
        chemin: '/compte',
        echelleTexte: echelle,
      );
      await _capturer(tester, 'tel${suffixe}_09_mes_enfants');
      await tester.ensureVisible(find.text('Ajouter un enfant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un enfant'));
      await _capturer(tester, 'tel${suffixe}_10_fiche_enfant');
      await lancerApp(
        tester,
        depot: FauxDepot(),
        preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa')),
        echelleTexte: echelle,
      );
      await _capturer(tester, 'tel${suffixe}_11_accueil_profil');

      // Suivi de mes enfants (phase 3).
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: _compteAvecSuivi(),
        preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa')),
        chemin: '/suivi',
        echelleTexte: echelle,
      );
      await _capturer(tester, 'tel${suffixe}_12_suivi');
    });
  }

  // Polices de secours (D17) mêlées au texte : exposants, flèches, grec,
  // symboles mathématiques et phonétiques, dans le texte courant et en cursive.
  testWidgets('symboles', (tester) async {
    await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1');
    await tester.pumpAndSettle();
    final contexte = tester.element(find.byType(Scaffold).first);
    // Pas de `await` : push ne se termine qu'à la fermeture de la page.
    Navigator.of(contexte).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              for (final style in [Styles.lecon, Styles.lecon.copyWith(fontWeight: FontWeight.w700), Styles.cahier(taille: 20)])
                Text(
                  '10⁻³ m ; 10ⁿ × 10ᵐ = 10ⁿ⁺ᵐ ; x ∈ ℝ ; a ≤ b ; a ≈ 3,14 ; '
                  'liquide → gaz ; R = 12 Ω ; Δt ; π ; µg ; [ʃ] [ʒ] [ɛ] [ɑ̃]',
                  style: style,
                ),
            ],
          ),
        ),
      ),
    ));
    await _capturer(tester, 'symboles');
  });

  testWidgets('web large', (tester) async {
    for (final (chemin, nom) in [
      ('/', 'web_01_accueil'),
      ('/classe/1/matiere/2', 'web_02_matiere'),
      ('/lecon/1', 'web_03_lecon'),
      ('/lecon/1/exercices', 'web_05_exercice'),
      ('/compte', 'web_08_connexion'),
    ]) {
      await lancerApp(tester, depot: FauxDepot(), chemin: chemin, taille: tailleWeb);
      await _capturer(tester, nom);
    }
    await lancerApp(
      tester,
      depot: FauxDepot(),
      compte: FauxCompte(connecte: 'parent@exemple.sn', enfants: _enfants),
      preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa')),
      chemin: '/compte',
      taille: tailleWeb,
    );
    await _capturer(tester, 'web_09_mes_enfants');
    await lancerApp(
      tester,
      depot: FauxDepot(),
      compte: _compteAvecSuivi(),
      preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa')),
      chemin: '/suivi',
      taille: tailleWeb,
    );
    await _capturer(tester, 'web_12_suivi');
  });
}
