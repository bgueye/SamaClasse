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
import 'package:image/image.dart' as img;

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

/// Trois leçons à vérifier (textes inspirés des vraies), un point levé.
FausseRedaction _redactionCapture() {
  LeconAVerifier l(int id, String titre, String classe, int ordre, String matiere, String slug, List<String> points) =>
      LeconAVerifier(
        id: id,
        titre: titre,
        classe: classe,
        ordreClasse: ordre,
        matiere: matiere,
        matiereSlug: slug,
        points: points,
        artefactUrl: 'https://claude.ai/artifact/exemple',
      );
  return FausseRedaction(
    redacteur: true,
    lecons: [
      l(2, 'La digestion et l’absorption', '4ème', 9, 'SVT', 'svt', [
        'Le III ne détaille que l’étape buccale : les étapes gastrique et intestinale figurent-elles dans le cahier ?',
        'Les exercices de la fiche viennent-ils du cahier ou ont-ils été ajoutés ?',
      ]),
      l(6, 'L’Afrique de l’Ouest : étude de situation', '4ème', 9, 'Géographie', 'geographie', [
        'Latitudes : le cahier ne donne pas les valeurs.',
        '6 000 km d’ouest en est : chiffre qui paraît trop élevé.',
        'Climat guinéen complété.',
      ]),
      l(10, 'La structure d’un écosystème', 'Seconde L', 11, 'SVT', 'svt', [
        'La partie sur le peuplement animal reste à rédiger.',
      ]),
    ],
    leves: [
      PointLeve(
        id: 1,
        leconId: 2,
        point: 'Les exercices de la fiche viennent-ils du cahier ou ont-ils été ajoutés ?',
        leveLe: DateTime(2026, 11, 15),
      ),
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

      // Leçons à vérifier (phase 4), une leçon dépliée avec un point levé.
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: FauxCompte(connecte: 'redacteur@exemple.sn'),
        redaction: _redactionCapture(),
        chemin: '/validation',
        echelleTexte: echelle,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('La digestion et l’absorption'));
      await _capturer(tester, 'tel${suffixe}_13_validation');
      // Fenêtre « Lever ce point » sur une question, réponse en cours.
      final question = find.textContaining('Le III ne détaille');
      await tester.ensureVisible(question);
      await tester.pumpAndSettle();
      await tester.tap(question);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Non : le cahier ne traite que l’étape buccale. III raccourci.');
      await _capturer(tester, 'tel${suffixe}_14_lever_point');
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

  // Schémas de la leçon (rédacteurs, phase 5) : liste, puis fenêtre d'ajout.
  testWidgets('schemas', (tester) async {
    // Faux « schéma du cahier » : fond blanc, lignes et un cercle.
    final dessin = img.Image(width: 900, height: 600)..clear(img.ColorRgb8(255, 255, 255));
    for (var y = 40; y < 600; y += 40) {
      img.drawLine(dessin, x1: 0, y1: y, x2: 899, y2: y, color: img.ColorRgb8(200, 210, 240));
    }
    img.drawCircle(dessin, x: 450, y: 300, radius: 150, color: img.ColorRgb8(30, 60, 200));
    final photo = img.encodeJpg(dessin);
    for (final (echelle, suffixe) in [(1.0, ''), (2.0, '_200')]) {
      final redaction = FausseRedaction(
        redacteur: true,
        textes: {
          1: const TexteLecon(
            id: 1,
            titre: 'Introduction aux sciences physiques',
            publiee: true,
            introduction: 'Les sciences physiques étudient la matière et ses transformations.',
            corps: 'Ce premier chapitre présente les deux grandes familles de phénomènes.\n\n'
                '## Les phénomènes physiques\n\n'
                'Un phénomène physique ne change pas la nature de la matière : la glace qui fond reste de l’eau.\n\n'
                '## Les phénomènes chimiques\n\n'
                'Un phénomène chimique crée de nouvelles substances.',
          ),
        },
        schemas: [
          SchemaLecon(
            id: 7,
            leconId: 1,
            champ: ChampLecon.corps,
            chemin: 'lecons/1/fichier-7.jpg',
            description: 'Les trois états de la matière et les changements d’état entre eux',
            ajouteLe: DateTime(2026, 11, 16),
          ),
        ],
      );
      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: FauxCompte(connecte: 'redacteur@exemple.sn'),
        redaction: redaction,
        choixImage: FauxChoixImage(octets: photo),
        chemin: '/lecon/1/schemas',
        echelleTexte: echelle,
      );
      await _capturer(tester, 'tel${suffixe}_15_schemas');
      await tester.ensureVisible(find.text('Ajouter un schéma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un schéma'));
      await _capturer(tester, 'tel${suffixe}_16_schemas_source');
      await tester.tap(find.text('Choisir dans la galerie'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await _capturer(tester, 'tel${suffixe}_17_fiche_schema_a');
      await tester.enterText(find.byType(TextField), 'Les deux familles de phénomènes');
      await tester.scrollUntilVisible(find.text('Où le placer ?'), 300,
          scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
      await _capturer(tester, 'tel${suffixe}_17_fiche_schema_b');
    }
  });

  // Liaison du téléphone d'un enfant (D32) : enfant, téléphone lié, parent.
  testWidgets('liaison', (tester) async {
    const awa = Enfant(id: 1, prenom: 'Awa', classeId: 1);
    const moussa = Enfant(id: 2, prenom: 'Moussa', classeId: 2);
    for (final (echelle, suffixe) in [(1.0, ''), (2.0, '_200')]) {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lier', echelleTexte: echelle);
      await tester.enterText(find.byType(TextField), '111 111');
      await tester.tap(find.widgetWithText(FilledButton, 'Lier ce téléphone'), warnIfMissed: false);
      await _capturer(tester, 'tel${suffixe}_18_lier');

      await lancerApp(
        tester,
        depot: FauxDepot(),
        compte: FauxCompte(lieA: awa),
        preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa', lie: true)),
        chemin: '/compte',
        echelleTexte: echelle,
      );
      await _capturer(tester, 'tel${suffixe}_19_telephone_lie');

      final compte = FauxCompte(
        connecte: 'parent@exemple.sn',
        enfants: [awa, moussa],
        appareils: [AppareilLie(id: 't', enfantId: 1, appareil: 'Android', lieLe: DateTime(2026, 11, 16))],
      );
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte', echelleTexte: echelle);
      final lier = find.bySemanticsLabel('Lier le téléphone d’Awa');
      await tester.scrollUntilVisible(lier, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await _capturer(tester, 'tel${suffixe}_20_enfants_telephones');
      await tester.tap(lier);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Pas de pumpAndSettle : le compte à rebours tourne.
      await tester.runAsync(() async {
        final image = await captureImage(find.byType(SamaClasseApp).evaluate().single);
        final octets = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_dossier/tel${suffixe}_21_code_liaison.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(octets!.buffer.asUint8List());
      });
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
    }
  });

  // Corrections et versions (D33).
  testWidgets('corrections', (tester) async {
    final correction = CorrectionLecon(
      id: 50,
      leconId: 1,
      titreEnLigne: 'Introduction aux sciences physiques',
      classe: '4ème',
      ordreClasse: 9,
      matiere: 'Sciences physiques',
      matiereSlug: 'sciences-physiques',
      texte: const TexteRedige(
        titre: 'Introduction aux sciences physiques',
        objectifs: ['Distinguer un phénomène physique d’un phénomène chimique'],
        introduction: 'Les sciences physiques étudient la matière et ses transformations.',
        corps: '## I. Les phénomènes physiques\n\nLa glace qui fond reste de l’eau.',
        aRetenir: [ElementARetenir(notion: 'Phénomène physique', essentiel: 'La matière ne change pas de nature.')],
      ),
      points: const ['La date du cours est-elle le 12/11 ?', 'Le titre du I est-il juste ?'],
      motif: 'La date du cours est fausse',
      demandeeLe: DateTime(2026, 11, 16, 10),
      modifieeLe: DateTime(2026, 11, 16, 12),
      parMoi: false,
    );
    VersionLecon version(int id, int numero, String motif) => VersionLecon(
          id: id,
          leconId: 1,
          numero: numero,
          motif: motif,
          publieeLe: DateTime(2026, 11, 14 + numero),
          texte: correction.texte,
        );
    for (final (echelle, suffixe) in [(1.0, ''), (2.0, '_200')]) {
      final redaction = FausseRedaction(
        redacteur: true,
        textes: {1: const TexteLecon(id: 1, titre: 'Introduction aux sciences physiques', publiee: true, corps: 'C')},
        corrections: [correction],
        leves: [PointLeve(id: 1, leconId: 1, point: 'La date du cours est-elle le 12/11 ?', leveLe: DateTime(2026, 11, 16), commentaire: 'Oui, page 3.', correctionId: 50)],
        versions: [version(1, 1, 'Version en ligne au 16/11/2026'), version(2, 2, 'Schéma des états ajouté')],
      );
      Future<void> ouvrir(String chemin) => lancerApp(
            tester,
            depot: FauxDepot(),
            compte: FauxCompte(connecte: 'redacteur@exemple.sn'),
            redaction: redaction,
            chemin: chemin,
            echelleTexte: echelle,
          );
      await ouvrir('/validation');
      await tester.pumpAndSettle();
      final titre = find.text('Introduction aux sciences physiques');
      await tester.scrollUntilVisible(titre, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(titre);
      await _capturer(tester, 'tel${suffixe}_22_correction_carte');
      await ouvrir('/lecon/1/correction');
      await _capturer(tester, 'tel${suffixe}_23_correction_apercu');
      await ouvrir('/lecon/1/versions');
      await _capturer(tester, 'tel${suffixe}_24_versions');
      redaction.corrections.clear();
      await ouvrir('/lecon/1/versions');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Version 1'));
      await _capturer(tester, 'tel${suffixe}_25_version');
      await ouvrir('/lecon/1');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Outils du rédacteur'));
      await _capturer(tester, 'tel${suffixe}_26_outils');
      await tester.tap(find.text('Demander une correction'));
      await _capturer(tester, 'tel${suffixe}_27_demande');
    }
  });

  // Téléphone en paysage : en-tête de la leçon sur une seule ligne.
  testWidgets('paysage', (tester) async {
    for (final (echelle, nom) in [(1.0, 'paysage_03_lecon'), (2.0, 'paysage_200_03_lecon')]) {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/lecon/1', taille: const Size(844, 390), echelleTexte: echelle);
      await _capturer(tester, nom);
    }
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
    await lancerApp(
      tester,
      depot: FauxDepot(),
      compte: FauxCompte(connecte: 'redacteur@exemple.sn'),
      redaction: _redactionCapture(),
      chemin: '/validation',
      taille: tailleWeb,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('La digestion et l’absorption'));
    await _capturer(tester, 'web_13_validation');
  });
}
