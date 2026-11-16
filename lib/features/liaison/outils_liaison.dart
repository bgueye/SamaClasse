// Logique pure de la liaison d'un téléphone d'enfant (D32), testée seule
// (test/features/liaison_test.dart).
//
// Deux publics : l'enfant qui tape le code (tutoiement) et le parent qui le
// donne et gère les téléphones (vouvoiement, comme l'espace parents).

import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

import '../../data/data.dart';

/// « d’Awa », « d’Ibrahima », « de Moussa » : « de » élidé devant une
/// voyelle, comme on l'écrit (« le téléphone d’Awa »).
String dePrenom(String prenom) {
  final p = prenom.trim();
  if (p.isEmpty) return 'de $p';
  return RegExp(r'^[AEIOUYÀÂÄÉÈÊËÎÏÔÖÙÛÜaeiouyàâäéèêëîïôöùûü]').hasMatch(p) ? 'd’$p' : 'de $p';
}

/// Nombre de chiffres d'un code de liaison.
const longueurCodeLiaison = 6;

/// Chiffres seulement (« 482 913 » collé ou tapé avec un espace).
String nettoyerCodeLiaison(String saisie) => saisie.replaceAll(RegExp(r'[^0-9]'), '');

bool codeLiaisonComplet(String code) => RegExp('^[0-9]{$longueurCodeLiaison}\$').hasMatch(code);

/// « 482913 » → « 482 913 » : plus facile à lire et à recopier.
String formaterCodeLiaison(String code) =>
    code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

/// Version lue aux lecteurs d'écran : chiffre par chiffre (« 4 8 2 9 1 3 »).
String codeLiaisonEpele(String code) => code.split('').join(' ');

/// Temps restant d'un code : « 9:41 », « 0:05 » ; « 0:00 » une fois expiré.
String libelleTempsRestant(Duration reste) {
  final secondes = reste.isNegative ? 0 : reste.inSeconds;
  return '${secondes ~/ 60}:${(secondes % 60).toString().padLeft(2, '0')}';
}

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

/// « Android, lié le 16/11/2026 ».
String libelleAppareil(AppareilLie a) => '${a.appareil ?? 'Téléphone'}, lié le ${_date(a.lieLe)}';

/// Téléphones liés à [enfantId], du plus ancien au plus récent.
List<AppareilLie> appareilsDe(List<AppareilLie> appareils, int enfantId) =>
    [for (final a in appareils) if (a.enfantId == enfantId) a];

/// Message pour l'enfant qui tape le code (tutoiement).
String messageErreurLiaison(Object erreur) {
  if (erreur is CodeLiaisonRefuse) {
    return switch (erreur.essaisRestants) {
      <= 0 => 'Ce code n’est pas bon. Trop d’essais : réessaie dans une heure.',
      1 => 'Ce code n’est pas bon, ou il a expiré. Encore 1 essai. Demande un nouveau code à ton parent.',
      final n => 'Ce code n’est pas bon, ou il a expiré. Encore $n essais.',
    };
  }
  if (erreur is PostgrestException) {
    // Refus expliqués en français par la base (trop d'essais, 3 téléphones).
    if (erreur.code == 'P0001') return erreur.message;
    return 'La liaison n’a pas abouti. Réessaie dans un instant.';
  }
  if (erreur is AuthException) {
    // Sessions anonymes désactivées dans le tableau de bord, ou limite de
    // création atteinte.
    if (erreur.statusCode == '429') return 'Trop d’essais depuis ce réseau. Réessaie dans une heure.';
    return 'La liaison des téléphones n’est pas disponible pour le moment. Préviens ton parent.';
  }
  return 'Pas de connexion internet. Vérifie le réseau, puis réessaie.';
}

/// Message pour le parent (vouvoiement).
String messageErreurParentLiaison(Object erreur) {
  if (erreur is PostgrestException) {
    if (erreur.code == 'P0001' || erreur.code == 'P0002') return erreur.message;
    if (erreur.code == '42501') return 'Ce profil n’appartient pas à votre compte.';
    return 'L’opération n’a pas abouti. Réessayez dans un instant.';
  }
  return 'Pas de connexion internet. Vérifiez le réseau, puis réessayez.';
}
