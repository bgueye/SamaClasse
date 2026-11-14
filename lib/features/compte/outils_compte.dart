// Logique pure des écrans du compte parent : validation des saisies et
// traduction des erreurs Supabase en phrases compréhensibles.
//
// Hors des widgets pour être testée seule (test/features/compte_test.dart).
// Les écrans du compte s'adressent aux parents : vouvoiement (le reste de
// l'application tutoie l'élève).

import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthRetryableFetchException, PostgrestException;

/// Longueur du code reçu par e-mail (réglage « Email OTP Length » de
/// Supabase, D22).
const longueurCode = 6;

/// Longueur maximale d'un prénom (contrainte de la table `enfants`).
const longueurMaxPrenom = 40;

/// Adresse débarrassée des espaces et en minuscules : « Awa.Diop@Mail.com »
/// et « awa.diop@mail.com » désignent le même compte.
String nettoyerEmail(String saisie) => saisie.trim().toLowerCase();

/// Vérification de forme seulement (un « @ », un point dans le domaine, pas
/// d'espace) : c'est l'envoi du code qui prouve que l'adresse existe.
bool emailValide(String saisie) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(nettoyerEmail(saisie));

/// Garde les chiffres seulement : un code collé depuis l'e-mail peut
/// contenir des espaces (« 123 456 »).
String nettoyerCode(String saisie) => saisie.replaceAll(RegExp(r'\D'), '');

bool codeComplet(String saisie) => nettoyerCode(saisie).length == longueurCode;

/// Prénom sans espaces superflus (« Awa  Diop » → « Awa Diop »).
String nettoyerPrenom(String saisie) => saisie.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Message d'erreur du champ prénom, ou `null` s'il est valable.
String? erreurPrenom(String saisie) {
  final p = nettoyerPrenom(saisie);
  if (p.isEmpty) return 'Indiquez le prénom de l’enfant.';
  if (p.runes.length > longueurMaxPrenom) return 'Le prénom ne doit pas dépasser $longueurMaxPrenom caractères.';
  return null;
}

/// Phrase à afficher pour une erreur venue de Supabase (connexion ou table
/// `enfants`). Le détail technique n'est jamais montré : il ne parlerait pas
/// à un parent.
String messageErreurCompte(Object erreur) {
  if (erreur is AuthRetryableFetchException) return _messageReseau;
  if (erreur is AuthException) {
    switch (erreur.code) {
      // Supabase renvoie le même code pour un code faux et un code expiré.
      case 'otp_expired':
        return 'Ce code est inexact ou n’est plus valable. Vérifiez-le, ou demandez un nouveau code.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Trop de demandes en peu de temps. Patientez quelques minutes avant de redemander un code.';
      case 'email_address_invalid':
      case 'validation_failed':
        return 'Cette adresse e-mail n’est pas valide.';
      case 'signup_disabled':
        return 'La création de compte est fermée pour le moment.';
      case 'session_expired':
      case 'session_not_found':
      case 'refresh_token_not_found':
        return _messageSession;
    }
    return 'La connexion n’a pas abouti. Réessayez dans un instant.';
  }
  if (erreur is PostgrestException) {
    switch (erreur.code) {
      // check_violation : le déclencheur `limiter_enfants` ou la contrainte
      // sur la longueur du prénom.
      case '23514':
        return erreur.message.contains('maximal')
            ? 'Un compte peut avoir 10 profils enfants au plus.'
            : 'Le prénom doit faire entre 1 et $longueurMaxPrenom caractères.';
      case 'PGRST301':
      case 'PGRST303':
        return _messageSession;
      // Ligne absente : profil déjà supprimé depuis un autre appareil.
      case 'PGRST116':
        return 'Ce profil n’existe plus. Il a peut-être été supprimé depuis un autre téléphone.';
    }
    return 'L’enregistrement n’a pas abouti. Réessayez dans un instant.';
  }
  // Le reste (pas de réseau, délai dépassé…) : très probablement la connexion.
  return _messageReseau;
}

const _messageReseau = 'Pas de connexion internet. Vérifiez le réseau, puis réessayez.';
const _messageSession = 'Votre session a expiré. Reconnectez-vous.';
