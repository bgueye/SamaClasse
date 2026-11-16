// Téléphone d'un enfant lié à son profil par un code du parent (D32) :
// logique pure, vérification au lancement, envoi du suivi, puis les écrans
// (enfant qui tape le code, téléphone lié, parent qui donne le code et
// délie) sur la vraie application avec un faux compte.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/services/preferences.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/liaison/outils_liaison.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException, PostgrestException;

import '../outils/faux_depot.dart';

const _awa = Enfant(id: 1, prenom: 'Awa', classeId: 1);
const _moussa = Enfant(id: 2, prenom: 'Moussa', classeId: 2);

AppareilLie _telephone(String id, int enfantId, {String? appareil = 'Android'}) =>
    AppareilLie(id: id, enfantId: enfantId, appareil: appareil, lieLe: DateTime(2026, 11, 16, 18));

SuiviResultats _suivi(Compte compte, Preferences preferences, {FauxEnvoi? envoi, FauxStockageFile? stockage}) =>
    SuiviResultats(
      compte: compte,
      preferences: preferences,
      envoi: envoi ?? FauxEnvoi(),
      stockage: stockage ?? FauxStockageFile(),
    );

/// Fait défiler jusqu'à [cible] dans la liste de l'écran, puis la touche.
Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
}

void main() {
  group('Logique pure', () {
    test('code : chiffres seulement, 6 chiffres, affiché en deux groupes', () {
      expect(nettoyerCodeLiaison(' 482 913 '), '482913');
      expect(nettoyerCodeLiaison('48-29a13'), '482913');
      expect(codeLiaisonComplet('482913'), isTrue);
      expect(codeLiaisonComplet('48291'), isFalse);
      expect(codeLiaisonComplet('4829134'), isFalse);
      expect(formaterCodeLiaison('482913'), '482 913');
      expect(codeLiaisonEpele('482913'), '4 8 2 9 1 3');
    });

    test('temps restant', () {
      expect(libelleTempsRestant(const Duration(minutes: 9, seconds: 41)), '9:41');
      expect(libelleTempsRestant(const Duration(seconds: 5)), '0:05');
      expect(libelleTempsRestant(const Duration(seconds: -3)), '0:00');
    });

    test('téléphones : libellé et tri par enfant', () {
      final a = _telephone('a', 1);
      final b = _telephone('b', 2, appareil: null);
      expect(libelleAppareil(a), 'Android, lié le 16/11/2026');
      expect(libelleAppareil(b), 'Téléphone, lié le 16/11/2026');
      expect(appareilsDe([a, b], 1), [a]);
      expect(AppareilLie.fromJson({'id': 'x', 'enfant_id': 3, 'appareil': null, 'lie_le': '2026-11-16T18:00:00+00:00'}).enfantId, 3);
    });

    test('type d’appareil : vague, sans modèle', () {
      expect(typeAppareil(plateforme: TargetPlatform.android, web: false), 'Android');
      expect(typeAppareil(plateforme: TargetPlatform.iOS, web: false), 'iPhone');
      expect(typeAppareil(plateforme: TargetPlatform.android, web: true), 'Navigateur');
      expect(typeAppareil(plateforme: TargetPlatform.windows, web: false), 'Ordinateur');
    });

    test('messages pour l’enfant (tutoiement)', () {
      expect(messageErreurLiaison(const CodeLiaisonRefuse(4)), contains('Encore 4 essais'));
      expect(messageErreurLiaison(const CodeLiaisonRefuse(1)), contains('Encore 1 essai.'));
      expect(messageErreurLiaison(const CodeLiaisonRefuse(0)), contains('réessaie dans une heure'));
      expect(messageErreurLiaison(const PostgrestException(message: 'Trop d’essais. Réessaie dans une heure.', code: 'P0001')),
          'Trop d’essais. Réessaie dans une heure.');
      expect(messageErreurLiaison(const AuthApiException('Anonymous sign-ins are disabled', statusCode: '422')),
          contains('Préviens ton parent'));
      expect(messageErreurLiaison(Exception('réseau')), contains('Pas de connexion'));
    });

    test('messages pour le parent (vouvoiement)', () {
      expect(messageErreurParentLiaison(const PostgrestException(message: 'Ce profil a déjà 3 téléphones liés.', code: 'P0001')),
          'Ce profil a déjà 3 téléphones liés.');
      expect(messageErreurParentLiaison(Exception('réseau')), contains('Vérifiez'));
    });

    test('« de » élidé devant une voyelle', () {
      expect(dePrenom('Awa'), 'd’Awa');
      expect(dePrenom('Ibrahima'), 'd’Ibrahima');
      expect(dePrenom('Élodie'), 'd’Élodie');
      expect(dePrenom('Moussa'), 'de Moussa');
      expect(dePrenom('Fatou'), 'de Fatou');
    });

    test('profil du téléphone : « lié » gardé, ancien format accepté', () {
      final lie = EnfantActif.fromJson(const EnfantActif(id: 1, prenom: 'Awa', lie: true).toJson());
      expect((lie.id, lie.prenom, lie.lie), (1, 'Awa', true));
      expect(EnfantActif.fromJson({'id': 2, 'prenom': 'Moussa'}).lie, isFalse);
      expect(const EnfantActif(id: 1, prenom: 'Awa').toJson().containsKey('lie'), isFalse);
      expect(lie.avecPrenom('Awa Fall').lie, isTrue);
    });
  });

  group('Vérification au lancement', () {
    test('parent connecté, ou profil choisi par le parent : rien à faire', () async {
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa'));
      final compte = FauxCompte(connecte: 'parent@exemple.sn');
      expect(await verifierTelephoneLie(compte: compte, preferences: prefs, suivi: _suivi(compte, prefs)), EtatLiaison.sansObjet);
      final sansCompte = FauxCompte();
      expect(await verifierTelephoneLie(compte: sansCompte, preferences: prefs, suivi: _suivi(sansCompte, prefs)),
          EtatLiaison.sansObjet);
      expect(prefs.enfant, isNotNull);
    });

    test('toujours lié : le prénom suit le profil', () async {
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa', lie: true));
      final compte = FauxCompte(lieA: const Enfant(id: 1, prenom: 'Awa Fall', classeId: 1));
      expect(await verifierTelephoneLie(compte: compte, preferences: prefs, suivi: _suivi(compte, prefs)), EtatLiaison.lie);
      expect((prefs.enfant!.prenom, prefs.enfant!.lie), ('Awa Fall', true));
    });

    test('délié par le parent : profil et file oubliés, session fermée', () async {
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa', lie: true));
      final compte = FauxCompte(lieA: _awa)..lieA = null; // session encore là, plus de profil
      final stockage = FauxStockageFile()..texte = encoderFile(FileEnvoi(lectures: [LectureLecon(enfantId: 1, leconId: 1, lueLe: DateTime(2026))]));
      final suivi = _suivi(compte, prefs, stockage: stockage);
      expect(await verifierTelephoneLie(compte: compte, preferences: prefs, suivi: suivi), EtatLiaison.delie);
      expect(prefs.enfant, isNull);
      expect(await suivi.enAttente(), 0);
      expect(compte.estAnonyme, isFalse);
      suivi.arreter();
    });

    test('session anonyme disparue (supprimée par « Délier ») : profil oublié', () async {
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa', lie: true));
      final compte = FauxCompte();
      expect(await verifierTelephoneLie(compte: compte, preferences: prefs, suivi: _suivi(compte, prefs)), EtatLiaison.delie);
      expect(prefs.enfant, isNull);
    });

    test('hors connexion : on garde tout', () async {
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa', lie: true));
      final compte = FauxCompte(lieA: _awa)..pannes['enfantDeCeTelephone'] = 1;
      expect(await verifierTelephoneLie(compte: compte, preferences: prefs, suivi: _suivi(compte, prefs)), EtatLiaison.inconnu);
      expect(prefs.enfant, isNotNull);
    });
  });

  test('téléphone lié : les lectures et les résultats partent sans compte parent', () async {
    final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa', lie: true));
    final compte = FauxCompte(lieA: _awa);
    final envoi = FauxEnvoi();
    final suivi = _suivi(compte, prefs, envoi: envoi);
    await suivi.noterLecture(7);
    await suivi.envoyer();
    expect(envoi.lecturesRecues.single.enfantId, 1);
    // Sans session du tout, rien n'est noté.
    final sansSession = FauxCompte();
    final envoi2 = FauxEnvoi();
    final suivi2 = _suivi(sansSession, prefs, envoi: envoi2);
    await suivi2.noterLecture(7);
    expect(await suivi2.enAttente(), 0);
    suivi.arreter();
    suivi2.arreter();
  });

  group('Écran de l’enfant', () {
    testWidgets('depuis l’espace parents : « J’ai un code de mon parent »', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), chemin: '/compte');
      await tester.pumpAndSettle();
      await _toucher(tester, find.text('J’ai un code de mon parent'));
      await tester.pumpAndSettle();
      expect(find.text('Lier ce téléphone'), findsWidgets);
      expect(find.text('Code de ton parent'), findsOneWidget);
    });

    testWidgets('code incomplet, puis faux, puis bon : le téléphone est celui d’Awa', (tester) async {
      final compte = FauxCompte();
      compte.codesLiaison['482913'] = _awa;
      final prefs = FaussesPreferences();
      // Le vrai chemin : accueil, Espace parents, « J'ai un code de mon parent ».
      await lancerApp(tester, depot: FauxDepot(), compte: compte, preferences: prefs);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Espace parents'));
      await tester.pumpAndSettle();
      await _toucher(tester, find.text('J’ai un code de mon parent'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '482');
      await tester.tap(find.widgetWithText(FilledButton, 'Lier ce téléphone'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tape les 6 chiffres'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '111 111');
      await tester.tap(find.widgetWithText(FilledButton, 'Lier ce téléphone'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Encore 4 essais'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '482 913');
      await tester.tap(find.widgetWithText(FilledButton, 'Lier ce téléphone'));
      await tester.pumpAndSettle();
      expect(prefs.enfant?.id, 1);
      expect(prefs.enfant?.lie, isTrue);
      expect(prefs.classe, 1);
      expect(compte.estConnecte, isFalse);
      // Retour à l'accueil, au nom d'Awa.
      expect(find.text('Bonjour Awa !'), findsOneWidget);
      expect(find.textContaining('lié à ton profil'), findsOneWidget);
    });

    testWidgets('liaison impossible (réseau) : message, rien de retenu', (tester) async {
      final compte = FauxCompte()..pannes['lier'] = 1;
      final prefs = FaussesPreferences();
      await lancerApp(tester, depot: FauxDepot(), compte: compte, preferences: prefs, chemin: '/lier');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '482913');
      await tester.tap(find.widgetWithText(FilledButton, 'Lier ce téléphone'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pas de connexion'), findsOneWidget);
      expect(prefs.enfant, isNull);
    });

    testWidgets('compte parent ouvert sur ce téléphone : il faut le déconnecter d’abord', (tester) async {
      final compte = FauxCompte(connecte: 'parent@exemple.sn');
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa'));
      await lancerApp(tester, depot: FauxDepot(), compte: compte, preferences: prefs, chemin: '/lier');
      await tester.pumpAndSettle();
      expect(find.textContaining('connecté au compte parent parent@exemple.sn'), findsOneWidget);
      expect(find.text('Code de ton parent'), findsNothing);
      await _toucher(tester, find.text('Déconnecter le compte parent'));
      await tester.pumpAndSettle();
      expect(compte.estConnecte, isFalse);
      expect(prefs.enfant, isNull);
      expect(find.text('Code de ton parent'), findsOneWidget);
    });

    testWidgets('téléphone lié : pas d’accès au compte, « Ce n’est plus mon téléphone »', (tester) async {
      final compte = FauxCompte(lieA: _awa);
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa', lie: true));
      await lancerApp(tester, depot: FauxDepot(), compte: compte, preferences: prefs, chemin: '/compte');
      await tester.pumpAndSettle();
      expect(find.text('Téléphone d’Awa'), findsOneWidget);
      expect(find.text('Mes enfants'), findsNothing);
      expect(find.text('Se déconnecter'), findsNothing);
      expect(find.text('Supprimer mon compte'), findsNothing);

      await _toucher(tester, find.text('Ce n’est plus mon téléphone'));
      await tester.pumpAndSettle();
      // « Annuler » : rien ne change.
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(compte.estAnonyme, isTrue);

      await _toucher(tester, find.text('Ce n’est plus mon téléphone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Délier ce téléphone'));
      await tester.pumpAndSettle();
      expect(compte.estAnonyme, isFalse);
      expect(prefs.enfant, isNull);
      expect(find.text('Recevoir un code'), findsOneWidget);
    });

    testWidgets('session anonyme sans liaison aboutie : connexion habituelle', (tester) async {
      final compte = FauxCompte()..anonyme = true;
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte');
      await tester.pumpAndSettle();
      expect(find.text('Recevoir un code'), findsOneWidget);
    });
  });

  group('Écran du parent', () {
    testWidgets('« Lier un téléphone » : code en grand, temps restant, puis fermer', (tester) async {
      final compte = FauxCompte(connecte: 'parent@exemple.sn', enfants: [_awa, _moussa]);
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte');
      await tester.pumpAndSettle();
      await _toucher(tester, find.bySemanticsLabel('Lier le téléphone d’Awa'));
      // La fenêtre a un compte à rebours : pas de pumpAndSettle tant qu'elle
      // est ouverte.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Lier le téléphone d’Awa'), findsOneWidget);
      expect(find.text('482 913'), findsOneWidget);
      expect(find.textContaining('Valable encore'), findsOneWidget);
      expect(compte.codesLiaison['482913'], _awa);
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('482 913'), findsNothing);
    });

    testWidgets('code refusé par la base : message et « Réessayer »', (tester) async {
      final compte = FauxCompte(connecte: 'parent@exemple.sn', enfants: [_awa])..pannes['creerCode'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte');
      await tester.pumpAndSettle();
      await _toucher(tester, find.bySemanticsLabel('Lier le téléphone d’Awa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pas de connexion'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('482 913'), findsOneWidget);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
    });

    testWidgets('téléphones liés sous chaque profil, et « Délier »', (tester) async {
      final compte = FauxCompte(
        connecte: 'parent@exemple.sn',
        enfants: [_awa, _moussa],
        appareils: [_telephone('t-awa', 1), _telephone('t-moussa', 2, appareil: 'iPhone')],
      );
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte');
      await tester.pumpAndSettle();
      expect(find.text('Android, lié le 16/11/2026'), findsOneWidget);
      expect(find.text('iPhone, lié le 16/11/2026'), findsOneWidget);

      await _toucher(tester, find.bySemanticsLabel('Délier ce téléphone d’Awa'));
      await tester.pumpAndSettle();
      expect(find.text('Délier ce téléphone ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Délier').last);
      await tester.pumpAndSettle();
      expect(compte.appareilsDelies, ['t-awa']);
      expect(find.text('Android, lié le 16/11/2026'), findsNothing);
      expect(find.text('iPhone, lié le 16/11/2026'), findsOneWidget);
      expect(find.text('Le téléphone d’Awa est délié.'), findsOneWidget);
    });

    testWidgets('téléphones indisponibles (réseau) : les profils s’affichent quand même', (tester) async {
      final compte = FauxCompte(connecte: 'parent@exemple.sn', enfants: [_awa])..pannes['appareils'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte');
      await tester.pumpAndSettle();
      expect(find.text('Awa'), findsOneWidget);
      expect(find.bySemanticsLabel('Lier le téléphone d’Awa'), findsOneWidget);
    });
  });

  group('Pas de débordement à 200 %', () {
    for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
      testWidgets('$nom : saisie du code et erreur', (tester) async {
        await lancerApp(tester, depot: FauxDepot(), chemin: '/lier', taille: taille, echelleTexte: 2);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byType(EditableText), 200, scrollable: find.byType(Scrollable).first);
        await tester.enterText(find.byType(TextField), '111111');
        final bouton = find.widgetWithText(FilledButton, 'Lier ce téléphone');
        await tester.scrollUntilVisible(bouton, 200, scrollable: find.byType(Scrollable).first);
        await _toucher(tester, bouton);
        await tester.pumpAndSettle();
        expect(find.textContaining('Encore 4 essais'), findsOneWidget);
      });

      testWidgets('$nom : téléphone lié', (tester) async {
        await lancerApp(tester,
            depot: FauxDepot(),
            compte: FauxCompte(lieA: _awa),
            preferences: FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa', lie: true)),
            chemin: '/compte',
            taille: taille,
            echelleTexte: 2);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Ce n’est plus mon téléphone'), 200, scrollable: find.byType(Scrollable).first);
      });

      testWidgets('$nom : profils avec téléphones, et fenêtre du code', (tester) async {
        final compte = FauxCompte(
          connecte: 'parent@exemple.sn',
          enfants: [_awa],
          appareils: [_telephone('t-awa', 1)],
        );
        await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte', taille: taille, echelleTexte: 2);
        await tester.pumpAndSettle();
        final lier = find.bySemanticsLabel('Lier le téléphone d’Awa');
        await tester.scrollUntilVisible(lier, 200, scrollable: find.byType(Scrollable).first);
        await _toucher(tester, lier);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('482 913'), findsOneWidget);
        await tester.tap(find.text('Fermer'));
        await tester.pumpAndSettle();
      });
    }
  });
}
