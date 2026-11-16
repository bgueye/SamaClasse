// Téléphone d'un enfant lié à son profil par un code du parent (D32).
//
// Le parent connecté demande un code pour un de ses enfants
// (`Compte.creerCodeLiaison`) ; sur le téléphone de l'enfant, l'application
// ouvre une session Supabase anonyme et donne ce code
// (`Compte.lierCeTelephone`). Ce téléphone envoie alors les lectures et les
// résultats de cet enfant, et rien d'autre (règles de la migration
// `liaison_appareils`). L'enfant n'a jamais le compte de son parent.

import 'package:flutter/foundation.dart';

import '../core/services/preferences.dart';
import 'compte.dart';
import 'suivi.dart';

/// Code de liaison affiché au parent.
@immutable
class CodeLiaison {
  const CodeLiaison({required this.code, required this.expireLe});

  /// Six chiffres.
  final String code;
  final DateTime expireLe;
}

/// Téléphone lié à un profil enfant (ligne de `appareils`), vu par le parent.
@immutable
class AppareilLie {
  const AppareilLie({required this.id, required this.enfantId, required this.lieLe, this.appareil});

  /// Identifiant de la session anonyme du téléphone.
  final String id;
  final int enfantId;

  /// « Android », « iPhone », « Navigateur » ; `null` si inconnu.
  final String? appareil;
  final DateTime lieLe;

  factory AppareilLie.fromJson(Map<String, dynamic> json) => AppareilLie(
        id: json['id'] as String,
        enfantId: (json['enfant_id'] as num).toInt(),
        appareil: json['appareil'] as String?,
        lieLe: DateTime.parse(json['lie_le'] as String),
      );
}

/// Code refusé par la base (faux, expiré ou déjà utilisé).
class CodeLiaisonRefuse implements Exception {
  const CodeLiaisonRefuse(this.essaisRestants);

  /// Essais encore permis dans l'heure (0 : il faut attendre).
  final int essaisRestants;
}

/// Type d'appareil envoyé à la liaison, pour que le parent reconnaisse ses
/// téléphones. Volontairement vague : ni modèle, ni nom de l'appareil.
String typeAppareil({required TargetPlatform plateforme, required bool web}) {
  if (web) return 'Navigateur';
  return switch (plateforme) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iPhone',
    _ => 'Ordinateur',
  };
}

/// Ce qu'a trouvé [verifierTelephoneLie].
enum EtatLiaison {
  /// Pas un téléphone lié (parent connecté, ou rien) : rien à faire.
  sansObjet,

  /// Toujours lié ; le prénom a pu être mis à jour.
  lie,

  /// Le parent a délié ce téléphone ou supprimé le profil : le téléphone
  /// revient en mode normal (lecture sans compte).
  delie,

  /// Pas de réponse du serveur (hors connexion) : on garde l'état actuel.
  inconnu,
}

/// Vérifie, au lancement et au retour de l'application, que ce téléphone est
/// toujours lié au profil retenu.
///
/// Si le parent l'a délié (la session anonyme a été supprimée) ou a supprimé
/// le profil, le téléphone oublie le profil et ce qui attendait d'être
/// envoyé (la base le refuserait). Hors connexion, rien ne change.
Future<EtatLiaison> verifierTelephoneLie({
  required Compte compte,
  required Preferences preferences,
  required SuiviResultats suivi,
}) async {
  if (compte.estConnecte) return EtatLiaison.sansObjet;
  final actif = await preferences.enfantActif();
  if (actif == null || !actif.lie) return EtatLiaison.sansObjet;

  Future<EtatLiaison> oublier() async {
    await preferences.choisirEnfant(null);
    await suivi.viderFile();
    return EtatLiaison.delie;
  }

  // Session anonyme disparue : supprimée par « Délier » (le serveur refuse
  // alors de la prolonger, et Supabase la ferme).
  if (!compte.estAnonyme) return oublier();

  final Enfant? enfant;
  try {
    enfant = await compte.enfantDeCeTelephone();
  } catch (_) {
    return EtatLiaison.inconnu;
  }
  if (enfant == null) {
    // Profil supprimé, ou téléphone délié pendant que la session tenait
    // encore : on ferme aussi la session devenue inutile.
    try {
      await compte.deconnecter();
    } catch (_) {}
    return oublier();
  }
  if (enfant.prenom != actif.prenom) await preferences.choisirEnfant(actif.avecPrenom(enfant.prenom));
  return EtatLiaison.lie;
}
