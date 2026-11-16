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
//
// Phase 5 : les rédacteurs ajoutent aussi les schémas des leçons depuis
// l'application (espace `schemas`, table `schemas_lecons`, fonctions
// `ajouter_schema` et `retirer_schema`).

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'suivi.dart' show genererUuid;

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

/// Partie d'une leçon où l'on peut insérer un schéma (contrainte de
/// `schemas_lecons.champ`).
enum ChampLecon {
  introduction('introduction', 'Introduction'),
  corps('corps', 'Corps de la leçon');

  const ChampLecon(this.valeur, this.libelle);

  /// Valeur en base.
  final String valeur;

  /// Libellé affiché.
  final String libelle;

  static ChampLecon depuis(String valeur) =>
      ChampLecon.values.firstWhere((c) => c.valeur == valeur, orElse: () => ChampLecon.corps);
}

/// Texte d'une leçon tel qu'il est en base, quel que soit son statut : c'est
/// ce texte exact que `ajouter_schema` compare avant d'insérer une image
/// (la copie locale des élèves ne convient pas : elle peut être en retard et
/// ne contient pas les leçons non publiées).
@immutable
class TexteLecon {
  const TexteLecon({
    required this.id,
    required this.titre,
    required this.publiee,
    this.introduction,
    this.corps,
  });

  final int id;
  final String titre;

  /// Leçon déjà visible des élèves : un schéma ajouté leur arrive à la
  /// prochaine mise à jour.
  final bool publiee;
  final String? introduction;
  final String? corps;

  String? texte(ChampLecon champ) => switch (champ) {
        ChampLecon.introduction => introduction,
        ChampLecon.corps => corps,
      };

  factory TexteLecon.fromJson(Map<String, dynamic> json) => TexteLecon(
        id: (json['id'] as num).toInt(),
        titre: json['titre'] as String,
        publiee: json['statut'] == 'publiee',
        introduction: json['introduction'] as String?,
        corps: json['corps'] as String?,
      );
}

/// Schéma ajouté à une leçon depuis l'application (ligne de
/// `schemas_lecons`).
@immutable
class SchemaLecon {
  const SchemaLecon({
    required this.id,
    required this.leconId,
    required this.champ,
    required this.chemin,
    required this.description,
    required this.ajouteLe,
  });

  final int id;
  final int leconId;
  final ChampLecon champ;

  /// Chemin du fichier dans l'espace `schemas` (`lecons/12/<uuid>.jpg`).
  final String chemin;
  final String description;
  final DateTime ajouteLe;

  factory SchemaLecon.fromJson(Map<String, dynamic> json) => SchemaLecon(
        id: (json['id'] as num).toInt(),
        leconId: (json['lecon_id'] as num).toInt(),
        champ: ChampLecon.depuis(json['champ'] as String),
        chemin: json['chemin'] as String,
        description: json['description'] as String,
        ajouteLe: DateTime.parse(json['ajoute_le'] as String),
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

  // --- Schémas des leçons (phase 5) ---

  /// Texte actuel de la leçon en base (publiée ou non), ou `null` si elle
  /// n'existe pas.
  Future<TexteLecon?> texteLecon(int leconId);

  /// Schémas ajoutés à la leçon depuis l'application, du plus ancien au plus
  /// récent.
  Future<List<SchemaLecon>> schemasLecon(int leconId);

  /// Dépose l'image (déjà réduite sous 150 Ko) dans l'espace `schemas`, sous
  /// un nom aléatoire, et renvoie son chemin.
  Future<String> deposerImage({required int leconId, required Uint8List octets, required String extension});

  /// Insère l'image déposée à [chemin] dans le texte de la leçon, après
  /// [apres] paragraphes de [champ] (0 : au début ; `null` : à la fin).
  /// [texteAttendu] est le texte affiché au rédacteur : s'il a changé en
  /// base, l'ajout est refusé (code 40001).
  Future<int> ajouterSchema({
    required int leconId,
    required ChampLecon champ,
    required int? apres,
    required String? texteAttendu,
    required String chemin,
    required String description,
  });

  /// Retire le schéma de la leçon et renvoie le chemin du fichier, à
  /// supprimer ensuite avec [supprimerImage].
  Future<String> retirerSchema(int schemaId);

  /// Supprime un fichier de l'espace `schemas` qu'aucune leçon n'utilise
  /// (image retirée, ou déposée sans que l'ajout aboutisse).
  Future<void> supprimerImage(String chemin);

  /// Adresse publique d'un fichier de l'espace `schemas`.
  String adresseImage(String chemin);
}

class RedactionSupabase implements Redaction {
  RedactionSupabase(this._client);

  final SupabaseClient _client;

  /// Dernière réponse de `est_redacteur`, par compte : l'écran de leçon la
  /// demande à chaque ouverture (bouton « Schémas »), inutile de refaire
  /// l'appel réseau à chaque fois.
  (String, bool)? _role;

  @override
  Future<bool> estRedacteur() async {
    final compte = _client.auth.currentUser?.id;
    if (compte == null) return false;
    final connu = _role;
    if (connu != null && connu.$1 == compte) return connu.$2;
    final reponse = await _client.rpc<bool>('est_redacteur');
    _role = (compte, reponse);
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

  // --- Schémas des leçons (phase 5) ---

  static const _espace = 'schemas';

  @override
  Future<TexteLecon?> texteLecon(int leconId) async {
    final ligne = await _client
        .from('lecons')
        .select('id, titre, statut, introduction, corps')
        .eq('id', leconId)
        .maybeSingle();
    return ligne == null ? null : TexteLecon.fromJson(ligne);
  }

  @override
  Future<List<SchemaLecon>> schemasLecon(int leconId) async {
    final lignes = await _client
        .from('schemas_lecons')
        .select('id, lecon_id, champ, chemin, description, ajoute_le')
        .eq('lecon_id', leconId)
        .order('ajoute_le');
    return lignes.map(SchemaLecon.fromJson).toList();
  }

  @override
  Future<String> deposerImage({required int leconId, required Uint8List octets, required String extension}) async {
    // Nom aléatoire imposé par la règle de dépôt : jamais d'écrasement.
    final chemin = 'lecons/$leconId/${genererUuid()}.$extension';
    await _client.storage.from(_espace).uploadBinary(
          chemin,
          octets,
          fileOptions: FileOptions(
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
            // Un fichier ne change jamais (nom unique) : cache long.
            cacheControl: '31536000',
          ),
        );
    return chemin;
  }

  @override
  Future<int> ajouterSchema({
    required int leconId,
    required ChampLecon champ,
    required int? apres,
    required String? texteAttendu,
    required String chemin,
    required String description,
  }) async {
    final id = await _client.rpc<num>('ajouter_schema', params: {
      'p_lecon_id': leconId,
      'p_champ': champ.valeur,
      'p_apres': apres,
      'p_texte_attendu': texteAttendu,
      'p_chemin': chemin,
      'p_description': description,
    });
    return id.toInt();
  }

  @override
  Future<String> retirerSchema(int schemaId) =>
      _client.rpc<String>('retirer_schema', params: {'p_schema_id': schemaId});

  @override
  Future<void> supprimerImage(String chemin) => _client.storage.from(_espace).remove([chemin]);

  @override
  String adresseImage(String chemin) => _client.storage.from(_espace).getPublicUrl(chemin);
}
