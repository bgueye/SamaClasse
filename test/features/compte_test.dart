// Espace parents (phase 2) : logique pure des saisies et des erreurs, puis
// écrans sur la vraie application avec un faux compte (sans réseau).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/services/preferences.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/compte/outils_compte.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthApiException, AuthRetryableFetchException, PostgrestException;

import '../outils/faux_depot.dart';

/// Classes du jeu enregistré (test/fixtures/supabase.json).
const _quatrieme = 1;
const _secondeL = 2;

void main() {
  group('Saisies', () {
    test('e-mail : nettoyé et vérifié dans sa forme', () {
      expect(nettoyerEmail('  Awa.Diop@Mail.COM '), 'awa.diop@mail.com');
      expect(emailValide('awa@exemple.sn'), isTrue);
      expect(emailValide(' awa@exemple.sn '), isTrue);
      for (final faux in ['', 'awa', 'awa@', 'awa@exemple', '@exemple.sn', 'awa diop@exemple.sn', 'a@b@c.sn']) {
        expect(emailValide(faux), isFalse, reason: '« $faux »');
      }
    });

    test('code : chiffres seulement, de 6 à 10', () {
      expect(nettoyerCode('123 456'), '123456');
      expect(nettoyerCode(' 12-34-56 '), '123456');
      expect(codeComplet('123 456'), isTrue);
      // Cas réel du 15/11/2026 : le projet envoie des codes à 8 chiffres.
      expect(codeComplet('1234 5678'), isTrue);
      expect(codeComplet('1234567890'), isTrue);
      expect(codeComplet('12345'), isFalse);
      expect(codeComplet('12345678901'), isFalse);
    });

    test('prénom : espaces nettoyés, 1 à 40 caractères', () {
      expect(nettoyerPrenom('  Awa   Diop '), 'Awa Diop');
      expect(erreurPrenom('Awa'), isNull);
      expect(erreurPrenom('   '), isNotNull);
      expect(erreurPrenom('A' * 40), isNull);
      expect(erreurPrenom('A' * 41), isNotNull);
      // Compté en caractères, comme char_length en base, pas en octets.
      expect(erreurPrenom('é' * 40), isNull);
    });
  });

  group('Messages d’erreur', () {
    test('code faux ou expiré', () {
      final m = messageErreurCompte(const AuthApiException('Token has expired or is invalid', code: 'otp_expired'));
      expect(m, contains('code est inexact'));
    });

    test('trop de demandes', () {
      for (final code in ['over_email_send_rate_limit', 'over_request_rate_limit']) {
        expect(messageErreurCompte(AuthApiException('rate', code: code)), contains('Patientez'));
      }
    });

    test('réseau', () {
      expect(messageErreurCompte(AuthRetryableFetchException()), contains('Pas de connexion'));
      expect(messageErreurCompte(AuthRetryableFetchException(message: 'SocketException')), contains('Pas de connexion'));
      expect(messageErreurCompte(TimeoutException('lent')), contains('Pas de connexion'));
    });

    test('erreur du serveur (5xx) : pas « pas de connexion »', () {
      // Cas réel du 14/11/2026 : l'envoi de l'e-mail échoue côté serveur,
      // Supabase répond 500 et la bibliothèque lève la même exception qu'une
      // coupure réseau, mais avec un code HTTP.
      final m = messageErreurCompte(AuthRetryableFetchException(message: 'Error sending confirmation email', statusCode: '500'));
      expect(m, contains('service de connexion'));
      expect(m, isNot(contains('Pas de connexion')));
    });

    test('limite de 10 profils et prénom refusé par la base', () {
      expect(
        messageErreurCompte(const PostgrestException(message: 'Nombre maximal de profils enfants atteint (10).', code: '23514')),
        contains('10 profils'),
      );
      expect(
        messageErreurCompte(const PostgrestException(message: 'violates check constraint', code: '23514')),
        contains('prénom'),
      );
    });

    test('session expirée et profil disparu', () {
      expect(messageErreurCompte(const PostgrestException(message: 'JWT expired', code: 'PGRST301')), contains('Reconnectez-vous'));
      expect(messageErreurCompte(const PostgrestException(message: 'no rows', code: 'PGRST116')), contains('n’existe plus'));
    });

    test('jamais de détail technique', () {
      final m = messageErreurCompte(const AuthApiException('Internal Server Error xyz', code: 'unexpected_failure'));
      expect(m, isNot(contains('xyz')));
    });
  });

  group('Connexion', () {
    testWidgets('accueil → espace parents → connexion par code', (tester) async {
      final compte = FauxCompte();
      await lancerApp(tester, depot: FauxDepot(), compte: compte);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Espace parents'));
      await tester.pumpAndSettle();
      expect(find.text('Espace parents'), findsOneWidget);

      // Adresse incomplète : message, rien n'est envoyé.
      await tester.enterText(find.byType(TextField), 'awa@');
      await tester.tap(find.text('Recevoir un code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('adresse e-mail complète'), findsOneWidget);
      expect(compte.codesEnvoyes, isEmpty);

      await tester.enterText(find.byType(TextField), ' Parent@Exemple.SN ');
      await tester.tap(find.text('Recevoir un code'));
      await tester.pumpAndSettle();
      expect(compte.codesEnvoyes, ['parent@exemple.sn']);
      expect(find.textContaining('parent@exemple.sn'), findsOneWidget);

      // Code faux : message clair, on reste sur l'étape du code.
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Valider le code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('code est inexact'), findsOneWidget);
      expect(compte.estConnecte, isFalse);

      // Bon code collé avec une espace : connecté, liste des enfants (vide).
      await tester.enterText(find.byType(TextField), '123 456');
      await tester.tap(find.text('Valider le code'));
      await tester.pumpAndSettle();
      expect(compte.estConnecte, isTrue);
      expect(find.text('Aucun profil pour l’instant'), findsOneWidget);
      expect(find.textContaining('Connecté avec parent@exemple.sn'), findsOneWidget);
    });

    testWidgets('envoi du code sans réseau : message, puis nouvel essai', (tester) async {
      final compte = FauxCompte()..pannes['envoyerCode'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'parent@exemple.sn');
      await tester.tap(find.text('Recevoir un code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pas de connexion'), findsOneWidget);

      await tester.tap(find.text('Recevoir un code'));
      await tester.pumpAndSettle();
      expect(find.text('Valider le code'), findsOneWidget);
    });

    testWidgets('« Changer d’adresse » revient à l’étape de l’e-mail', (tester) async {
      await lancerApp(tester, depot: FauxDepot(), compte: FauxCompte(), chemin: '/compte');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'parent@exemple.sn');
      await tester.tap(find.text('Recevoir un code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Changer d’adresse'));
      await tester.pumpAndSettle();
      expect(find.text('Recevoir un code'), findsOneWidget);
    });
  });

  group('Mes enfants', () {
    FauxCompte connecte([List<Enfant> enfants = const []]) =>
        FauxCompte(connecte: 'parent@exemple.sn', enfants: enfants);

    testWidgets('chargement, puis profils', (tester) async {
      final compte = connecte([const Enfant(id: 1, prenom: 'Awa', classeId: _quatrieme)])..attente = Completer();
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      compte.attente!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Awa'), findsOneWidget);
      expect(find.text('4ème'), findsOneWidget);
    });

    testWidgets('erreur réseau, puis « Réessayer »', (tester) async {
      final compte = connecte([const Enfant(id: 1, prenom: 'Awa', classeId: _quatrieme)])..pannes['enfants'] = 1;
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte');
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Awa'), findsOneWidget);
    });

    testWidgets('ajouter un enfant : contrôle de la fiche, puis profil de ce téléphone', (tester) async {
      final compte = connecte();
      final prefs = FaussesPreferences();
      await lancerApp(tester, depot: FauxDepot(), compte: compte, preferences: prefs, chemin: '/compte');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter un enfant'));
      await tester.pumpAndSettle();
      // Rien de saisi : deux messages, la fiche reste ouverte.
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Indiquez le prénom de l’enfant.'), findsOneWidget);
      expect(find.text('Choisissez la classe de l’enfant.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Prénom'), '  Awa  ');
      await tester.tap(find.text('Seconde L'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(compte.profils.single.prenom, 'Awa');
      expect(compte.profils.single.classeId, _secondeL);
      // Premier profil : choisi d'office pour ce téléphone, avec sa classe.
      expect(find.text('Utilisé sur ce téléphone'), findsOneWidget);
      expect(prefs.enfant?.prenom, 'Awa');
      expect(prefs.classe, _secondeL);
    });

    testWidgets('modifier un profil met à jour celui de ce téléphone', (tester) async {
      final compte = connecte([const Enfant(id: 1, prenom: 'Awa', classeId: _quatrieme)]);
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa'));
      await lancerApp(tester, depot: FauxDepot(), compte: compte, preferences: prefs, chemin: '/compte');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Prénom'), 'Awa Marie');
      await tester.tap(find.text('Seconde L'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Awa Marie'), findsOneWidget);
      expect(prefs.enfant?.prenom, 'Awa Marie');
      expect(prefs.classe, _secondeL);
    });

    testWidgets('supprimer demande confirmation et oublie le profil de ce téléphone', (tester) async {
      final compte = connecte([const Enfant(id: 1, prenom: 'Awa', classeId: _quatrieme)]);
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa'));
      await lancerApp(tester, depot: FauxDepot(), compte: compte, preferences: prefs, chemin: '/compte');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(compte.profils, hasLength(1));

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Supprimer')));
      await tester.pumpAndSettle();
      expect(compte.profils, isEmpty);
      expect(prefs.enfant, isNull);
      expect(find.text('Aucun profil pour l’instant'), findsOneWidget);
    });

    testWidgets('« Utiliser sur ce téléphone » : accueil personnalisé et classe choisie', (tester) async {
      final compte = connecte([
        const Enfant(id: 1, prenom: 'Awa', classeId: _quatrieme),
        const Enfant(id: 2, prenom: 'Moussa', classeId: _secondeL),
      ]);
      final prefs = FaussesPreferences(classe: _quatrieme, enfant: const EnfantActif(id: 1, prenom: 'Awa'));
      await lancerApp(tester, depot: FauxDepot(), compte: compte, preferences: prefs);
      await tester.pumpAndSettle();
      expect(find.text('Bonjour Awa !'), findsOneWidget);

      await tester.tap(find.byTooltip('Espace parents'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Utiliser sur ce téléphone'));
      await tester.pumpAndSettle();
      expect(prefs.enfant?.id, 2);

      await tester.tap(find.text('Mes cours'));
      await tester.pumpAndSettle();
      expect(find.text('Bonjour Moussa !'), findsOneWidget);
      expect(find.text('Tes matières en Seconde L'), findsOneWidget);
    });

    testWidgets('déconnexion : retour à la connexion, profil du téléphone oublié', (tester) async {
      final compte = connecte([const Enfant(id: 1, prenom: 'Awa', classeId: _quatrieme)]);
      final prefs = FaussesPreferences(enfant: const EnfantActif(id: 1, prenom: 'Awa'));
      await lancerApp(tester, depot: FauxDepot(), compte: compte, preferences: prefs, chemin: '/compte');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(compte.estConnecte, isFalse);
      expect(prefs.enfant, isNull);
      expect(find.text('Recevoir un code'), findsOneWidget);
    });

    testWidgets('10 profils : plus de bouton d’ajout', (tester) async {
      final compte = connecte([
        for (var i = 1; i <= 10; i++) Enfant(id: i, prenom: 'Enfant $i', classeId: _quatrieme),
      ]);
      await lancerApp(tester, depot: FauxDepot(), compte: compte, chemin: '/compte');
      await tester.pumpAndSettle();
      expect(find.text('Ajouter un enfant'), findsNothing);
    });
  });

  group('Pas de débordement, texte système à 200 %', () {
    final avecEnfants = [
      const Enfant(id: 1, prenom: 'Aminata Fatou Bintou', classeId: _quatrieme),
      const Enfant(id: 2, prenom: 'Moussa', classeId: _secondeL),
    ];
    const actif = EnfantActif(id: 1, prenom: 'Aminata Fatou Bintou');

    for (final (nom, taille) in [('téléphone', tailleTelephone), ('web large', tailleWeb)]) {
      testWidgets('$nom : connexion, étape du code', (tester) async {
        await lancerApp(tester, depot: FauxDepot(), compte: FauxCompte(), chemin: '/compte', taille: taille, echelleTexte: 2);
        await tester.pumpAndSettle();
        // À 200 %, l'explication remplit l'écran : le champ est plus bas.
        await tester.scrollUntilVisible(find.byType(TextField), 200, scrollable: find.byType(Scrollable).first);
        await tester.enterText(find.byType(TextField), 'parent.avec.une.longue.adresse@exemple.sn');
        await _toucher(tester, find.text('Recevoir un code'));
        await tester.scrollUntilVisible(find.byType(TextField), 200, scrollable: find.byType(Scrollable).first);
        await tester.enterText(find.byType(TextField), '000000');
        await _toucher(tester, find.text('Valider le code'));
        expect(find.textContaining('code est inexact'), findsOneWidget);
      });

      testWidgets('$nom : mes enfants et fiche ouverte', (tester) async {
        await lancerApp(
          tester,
          depot: FauxDepot(),
          compte: FauxCompte(connecte: 'parent@exemple.sn', enfants: avecEnfants),
          preferences: FaussesPreferences(enfant: actif),
          chemin: '/compte',
          taille: taille,
          echelleTexte: 2,
        );
        await tester.pumpAndSettle();
        await _toucher(tester, find.text('Ajouter un enfant'));
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('$nom : accueil avec un profil choisi', (tester) async {
        await lancerApp(
          tester,
          depot: FauxDepot(),
          preferences: FaussesPreferences(enfant: actif),
          taille: taille,
          echelleTexte: 2,
        );
        await tester.pumpAndSettle();
        expect(find.text('Bonjour Aminata Fatou Bintou !'), findsOneWidget);
      });
    }
  });
}

/// À 200 %, le bouton visé est souvent sous le bas de l'écran : on fait
/// défiler jusqu'à lui avant de le toucher, comme le ferait l'utilisateur.
Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}
