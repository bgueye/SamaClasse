// « Signaler une erreur » sur une leçon ou un exercice (D35, D38).
//
// Tout le monde peut signaler, même sans compte : l'envoi passe par la
// fonction `signaler_erreur` de la base (migration `signalements`), qui
// vérifie que la leçon est publiée et limite les envois (5 par heure par
// session ou par adresse IP). Aucune identité n'est gardée avec le
// signalement.
//
// Les rédacteurs lisent et traitent les signalements dans « Leçons à
// vérifier » (`Redaction.signalements`, `Redaction.traiterSignalement`).
//
// Sans réseau, rien n'est gardé pour plus tard (D38, simplicité) : la
// fenêtre demande de réessayer.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ce qui ne va pas, d'après le lecteur. Les codes sont ceux de la colonne
/// `signalements.motif` ; les libellés, ceux de la maquette `Signaler`.
enum MotifSignalement {
  faute('faute', 'Une faute dans le texte'),
  corrigeFaux('corrige_faux', 'Le corrigé me semble faux'),
  pasCommeCahier('pas_comme_cahier', 'Ce n’est pas comme dans mon cahier'),
  autre('autre', 'Autre chose');

  const MotifSignalement(this.code, this.libelle);

  final String code;
  final String libelle;

  /// Motif d'un code de la base ; `autre` pour un code inconnu (motif ajouté
  /// plus tard dans la base) plutôt qu'une erreur dans l'écran des rédacteurs.
  static MotifSignalement depuisCode(String code) =>
      values.firstWhere((m) => m.code == code, orElse: () => MotifSignalement.autre);
}

/// Motifs proposés : « Le corrigé me semble faux » n'a de sens que pour un
/// exercice (une leçon n'a pas de corrigé).
List<MotifSignalement> motifsProposes({required bool pourExercice}) => [
      for (final m in MotifSignalement.values)
        if (pourExercice || m != MotifSignalement.corrigeFaux) m,
    ];

/// Longueur maximale de la précision (contrainte de `precision_texte`).
const longueurMaxPrecision = 500;

/// Précision sans espaces superflus ; `null` si elle est vide (la base fait
/// de même).
String? nettoyerPrecision(String saisie) {
  final p = saisie.trim();
  return p.isEmpty ? null : p;
}

/// Message d'erreur de la fenêtre de signalement (tutoiement de l'élève).
///
/// Les refus de la limite d'envois (P0001) ont déjà une phrase claire en
/// français (« Tu as déjà envoyé plusieurs signalements… ») : on l'affiche
/// telle quelle.
String messageErreurSignalement(Object erreur) {
  if (erreur is PostgrestException) {
    return switch (erreur.code) {
      'P0001' => erreur.message,
      // Leçon dépubliée ou exercice retiré entre-temps.
      'P0002' => 'Cette leçon a changé depuis. Reviens à l’accueil, puis réessaie.',
      _ => 'L’envoi n’a pas marché. Réessaie dans un instant.',
    };
  }
  // Le reste : très probablement le réseau.
  return 'Pas de connexion internet. Réessaie quand tu auras du réseau.';
}

/// Envoi d'un signalement. Remplacé par un faux dans les tests.
abstract interface class EnvoiSignalement {
  /// Envoie le signalement. [exerciceId] vide : il porte sur la leçon.
  /// Lève une erreur si l'envoi échoue (réseau, limite d'envois).
  Future<void> signaler({
    required int leconId,
    int? exerciceId,
    required MotifSignalement motif,
    String? precision,
  });
}

class EnvoiSignalementSupabase implements EnvoiSignalement {
  const EnvoiSignalementSupabase(this._client);

  final SupabaseClient _client;

  @override
  Future<void> signaler({
    required int leconId,
    int? exerciceId,
    required MotifSignalement motif,
    String? precision,
  }) =>
      _client.rpc<void>('signaler_erreur', params: {
        'p_lecon_id': leconId,
        'p_exercice_id': exerciceId,
        'p_motif': motif.code,
        'p_precision': precision,
      });
}

/// Ce qu'un rédacteur fait d'un signalement (colonne `signalements.etat`).
enum EtatSignalement {
  /// À traiter (ou remis à traiter après une erreur de manipulation).
  nouveau('nouveau'),

  /// L'erreur est corrigée, ou une correction est demandée.
  traite('traite'),

  /// Pas d'erreur.
  ecarte('ecarte');

  const EtatSignalement(this.code);

  final String code;
}

/// Signalement à traiter, tel que l'écran des rédacteurs l'affiche.
@immutable
class Signalement {
  const Signalement({
    required this.id,
    required this.leconId,
    required this.titreLecon,
    required this.motif,
    required this.recuLe,
    this.exerciceId,
    this.ordreExercice,
    this.precision,
  });

  final int id;
  final int leconId;
  final String titreLecon;

  /// Vide : le signalement porte sur la leçon elle-même.
  final int? exerciceId;

  /// Numéro de l'exercice dans la leçon (colonne `exercices.ordre`).
  final int? ordreExercice;
  final MotifSignalement motif;
  final String? precision;
  final DateTime recuLe;

  /// Forme de la réponse de
  /// `select id, lecon_id, exercice_id, motif, precision_texte, recu_le,
  /// lecons(titre), exercices(ordre)`.
  factory Signalement.fromJson(Map<String, dynamic> json) {
    final lecon = json['lecons'] as Map<String, dynamic>?;
    final exercice = json['exercices'] as Map<String, dynamic>?;
    return Signalement(
      id: (json['id'] as num).toInt(),
      leconId: (json['lecon_id'] as num).toInt(),
      titreLecon: lecon?['titre'] as String? ?? 'Leçon ${json['lecon_id']}',
      exerciceId: (json['exercice_id'] as num?)?.toInt(),
      ordreExercice: (exercice?['ordre'] as num?)?.toInt(),
      motif: MotifSignalement.depuisCode(json['motif'] as String),
      precision: json['precision_texte'] as String?,
      recuLe: DateTime.parse(json['recu_le'] as String),
    );
  }
}
