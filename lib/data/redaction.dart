// Validation et publication des leçons par les rédacteurs (phase 4, D23,
// D25).
//
// Réservé aux comptes de la table `redacteurs` : les règles RLS leur
// laissent lire les leçons non publiées, lever des points (table
// `points_leves`, historique) et appeler `publier_lecon`. Les autres comptes
// n'obtiennent rien de ces requêtes : l'écran vérifie le rôle d'abord.
//
// Les données de rédaction (`points_a_verifier`, `artefact_url`) ne servent
// qu'ici : elles ne doivent jamais apparaître dans un écran d'élève.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Leçon « à vérifier », telle que l'écran de validation l'affiche.
@immutable
class LeconAVerifier {
  const LeconAVerifier({
    required this.id,
    required this.titre,
    required this.classe,
    required this.ordreClasse,
    required this.matiere,
    required this.matiereSlug,
    required this.points,
    required this.artefactUrl,
  });

  final int id;
  final String titre;
  final String classe;

  /// Position de la classe dans le cursus, pour ranger les leçons.
  final int ordreClasse;
  final String matiere;
  final String? matiereSlug;

  /// Points à vérifier avec les cahiers avant publication.
  final List<String> points;

  /// Lien vers l'artefact où la leçon se corrige (claude.ai).
  final String? artefactUrl;

  factory LeconAVerifier.fromJson(Map<String, dynamic> json) {
    final chapitre = json['chapitres'] as Map<String, dynamic>;
    final classe = chapitre['classes'] as Map<String, dynamic>;
    final matiere = chapitre['matieres'] as Map<String, dynamic>;
    return LeconAVerifier(
      id: (json['id'] as num).toInt(),
      titre: json['titre'] as String,
      classe: classe['libelle'] as String,
      ordreClasse: (classe['ordre'] as num?)?.toInt() ?? 0,
      matiere: matiere['nom'] as String,
      matiereSlug: matiere['slug'] as String?,
      points: [for (final p in (json['points_a_verifier'] as List?) ?? const []) p as String],
      artefactUrl: json['artefact_url'] as String?,
    );
  }
}

/// Point levé par un rédacteur (ligne de `points_leves`).
@immutable
class PointLeve {
  const PointLeve({
    required this.id,
    required this.leconId,
    required this.point,
    required this.leveLe,
    this.commentaire,
  });

  final int id;
  final int leconId;
  final String point;
  final DateTime leveLe;

  /// Réponse du rédacteur : ce qu'il a vérifié ou trouvé dans le cahier
  /// (obligatoire quand le point est une question).
  final String? commentaire;

  factory PointLeve.fromJson(Map<String, dynamic> json) => PointLeve(
        id: (json['id'] as num).toInt(),
        leconId: (json['lecon_id'] as num).toInt(),
        point: json['point'] as String,
        leveLe: DateTime.parse(json['leve_le'] as String),
        commentaire: json['commentaire'] as String?,
      );
}

/// Contrat utilisé par l'écran de validation (faux dans les tests).
abstract class Redaction {
  /// Vrai si le compte connecté est rédacteur.
  Future<bool> estRedacteur();

  /// Leçons au statut « à vérifier », toutes classes confondues.
  Future<List<LeconAVerifier>> leconsAVerifier();

  /// Points déjà levés sur des leçons pas encore publiées (et l'historique
  /// des autres, inutile ici mais sans gêne).
  Future<List<PointLeve>> pointsLeves();

  /// Lève [point] de la leçon [leconId], au nom du compte connecté, avec la
  /// réponse du rédacteur ([commentaire], facultatif pour un simple constat).
  Future<PointLeve> leverPoint({required int leconId, required String point, String? commentaire});

  /// Annule un point levé par erreur (possible tant que la leçon n'est pas
  /// publiée).
  Future<void> annulerPoint(int id);

  /// Publie la leçon : la base vérifie le rôle et que tous les points sont
  /// levés, puis la passe à « publiee ».
  Future<void> publier(int leconId);
}

class RedactionSupabase implements Redaction {
  RedactionSupabase(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> estRedacteur() async {
    if (_client.auth.currentUser == null) return false;
    final reponse = await _client.rpc<bool>('est_redacteur');
    return reponse;
  }

  @override
  Future<List<LeconAVerifier>> leconsAVerifier() async {
    final lignes = await _client
        .from('lecons')
        .select('id, titre, points_a_verifier, artefact_url, '
            'chapitres(classes(libelle, ordre), matieres(nom, slug))')
        .eq('statut', 'a_verifier')
        .order('id');
    return lignes.map(LeconAVerifier.fromJson).toList();
  }

  @override
  Future<List<PointLeve>> pointsLeves() async {
    final lignes =
        await _client.from('points_leves').select('id, lecon_id, point, leve_le, commentaire').order('leve_le');
    return lignes.map(PointLeve.fromJson).toList();
  }

  @override
  Future<PointLeve> leverPoint({required int leconId, required String point, String? commentaire}) async {
    // `leve_par` est rempli par la base avec le compte connecté.
    final ligne = await _client
        .from('points_leves')
        .insert({'lecon_id': leconId, 'point': point, 'commentaire': commentaire})
        .select('id, lecon_id, point, leve_le, commentaire')
        .single();
    return PointLeve.fromJson(ligne);
  }

  @override
  Future<void> annulerPoint(int id) => _client.from('points_leves').delete().eq('id', id);

  @override
  Future<void> publier(int leconId) => _client.rpc<void>('publier_lecon', params: {'p_lecon_id': leconId});
}
