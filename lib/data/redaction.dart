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
// `ajouter_schema` et `retirer_schema`), et corrigent les leçons publiées
// (D33) : demande de correction, copie de travail, points, publication par
// un validateur, versions.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart' show ElementARetenir;
import 'signalement.dart';
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
    this.correctionId,
  });

  final int id;
  final int leconId;
  final String point;
  final DateTime leveLe;

  /// Correction à laquelle appartient le point (D33) ; `null` pour un point
  /// d'une leçon pas encore publiée.
  final int? correctionId;

  /// Réponse du rédacteur : ce qu'il a vérifié ou trouvé dans le cahier
  /// (obligatoire quand le point est une question).
  final String? commentaire;

  factory PointLeve.fromJson(Map<String, dynamic> json) => PointLeve(
        id: (json['id'] as num).toInt(),
        leconId: (json['lecon_id'] as num).toInt(),
        point: json['point'] as String,
        leveLe: DateTime.parse(json['leve_le'] as String),
        commentaire: json['commentaire'] as String?,
        correctionId: (json['correction_id'] as num?)?.toInt(),
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
    this.correctionId,
  });

  final int id;
  final String titre;

  /// Correction ouverte (D33) : le texte est alors celui de la copie de
  /// travail, et un schéma ajouté y va (pas en ligne).
  final int? correctionId;

  bool get dansCorrection => correctionId != null;

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
    this.correctionId,
  });

  final int id;
  final int leconId;
  final ChampLecon champ;

  /// Ajouté dans une correction (D33), sinon directement dans la leçon.
  final int? correctionId;

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
        correctionId: (json['correction_id'] as num?)?.toInt(),
      );
}

/// Texte d'une leçon (le texte seulement, sans les exercices) : en ligne,
/// copie de travail d'une correction ou version archivée (D33).
@immutable
class TexteRedige {
  const TexteRedige({
    required this.titre,
    required this.objectifs,
    required this.introduction,
    required this.corps,
    required this.aRetenir,
  });

  final String titre;
  final List<String> objectifs;
  final String? introduction;
  final String? corps;
  final List<ElementARetenir> aRetenir;

  factory TexteRedige.fromJson(Map<String, dynamic> json) => TexteRedige(
        titre: json['titre'] as String,
        objectifs: [for (final o in (json['objectifs'] as List?) ?? const []) o as String],
        introduction: json['introduction'] as String?,
        corps: json['corps'] as String?,
        aRetenir: [
          for (final e in (json['a_retenir'] as List?) ?? const []) ElementARetenir.fromJson(e as Map<String, dynamic>),
        ],
      );
}

/// Correction en cours d'une leçon publiée (ligne ouverte de
/// `corrections_lecons`, D33).
@immutable
class CorrectionLecon {
  const CorrectionLecon({
    required this.id,
    required this.leconId,
    required this.titreEnLigne,
    required this.classe,
    required this.ordreClasse,
    required this.matiere,
    required this.matiereSlug,
    required this.texte,
    required this.points,
    required this.motif,
    required this.demandeeLe,
    required this.modifieeLe,
    required this.parMoi,
  });

  final int id;
  final int leconId;

  /// Titre de la leçon telle qu'elle est en ligne.
  final String titreEnLigne;
  final String classe;
  final int ordreClasse;
  final String matiere;
  final String? matiereSlug;

  /// Texte de travail (corrigé, ou encore identique au texte en ligne).
  final TexteRedige texte;
  final List<String> points;

  /// Raison de la correction.
  final String motif;
  final DateTime demandeeLe;

  /// Dernière modification du texte de travail.
  final DateTime modifieeLe;

  /// Demandée par le compte connecté : il peut l'abandonner.
  final bool parMoi;

  /// Le texte de travail a été modifié depuis la demande.
  bool get texteCorrige => modifieeLe.difference(demandeeLe).inSeconds > 1;

  factory CorrectionLecon.fromJson(Map<String, dynamic> json, {String? moi}) {
    final lecon = json['lecons'] as Map<String, dynamic>;
    final chapitre = lecon['chapitres'] as Map<String, dynamic>;
    final classe = chapitre['classes'] as Map<String, dynamic>;
    final matiere = chapitre['matieres'] as Map<String, dynamic>;
    return CorrectionLecon(
      id: (json['id'] as num).toInt(),
      leconId: (json['lecon_id'] as num).toInt(),
      titreEnLigne: lecon['titre'] as String,
      classe: classe['libelle'] as String,
      ordreClasse: (classe['ordre'] as num?)?.toInt() ?? 0,
      matiere: matiere['nom'] as String,
      matiereSlug: matiere['slug'] as String?,
      texte: TexteRedige.fromJson(json),
      points: [for (final p in (json['points_a_verifier'] as List?) ?? const []) p as String],
      motif: json['motif'] as String,
      demandeeLe: DateTime.parse(json['demandee_le'] as String),
      modifieeLe: DateTime.parse(json['modifiee_le'] as String),
      parMoi: moi != null && json['demandee_par'] == moi,
    );
  }
}

/// Version mise en ligne d'une leçon (ligne de `versions_lecons`, D33). La
/// plus récente est le texte en ligne.
@immutable
class VersionLecon {
  const VersionLecon({
    required this.id,
    required this.leconId,
    required this.numero,
    required this.motif,
    required this.publieeLe,
    required this.texte,
  });

  final int id;
  final int leconId;
  final int numero;
  final String motif;
  final DateTime publieeLe;
  final TexteRedige texte;

  factory VersionLecon.fromJson(Map<String, dynamic> json) => VersionLecon(
        id: (json['id'] as num).toInt(),
        leconId: (json['lecon_id'] as num).toInt(),
        numero: (json['numero'] as num).toInt(),
        motif: json['motif'] as String,
        publieeLe: DateTime.parse(json['publiee_le'] as String),
        texte: TexteRedige.fromJson(json),
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

  /// Lève [point] de la leçon [leconId] (ou de sa correction [correctionId],
  /// D33), au nom du compte connecté, avec la réponse du rédacteur
  /// ([commentaire], facultatif pour un simple constat).
  Future<PointLeve> leverPoint({required int leconId, required String point, String? commentaire, int? correctionId});

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

  // --- Corrections et versions (D33) ---

  /// Vrai si le compte connecté est validateur (publie, abandonne, revient
  /// à une version).
  Future<bool> estValidateur();

  /// Corrections ouvertes, toutes leçons confondues.
  Future<List<CorrectionLecon>> correctionsEnCours();

  /// Correction ouverte de la leçon, ou `null`.
  Future<CorrectionLecon?> correctionDe(int leconId);

  /// Demande une correction d'une leçon publiée : la leçon reste en ligne,
  /// une copie de travail est créée.
  Future<int> demanderCorrection({required int leconId, required String motif, required List<String> points});

  /// Validateur : met la correction en ligne. Rend le numéro de la version.
  Future<int> publierCorrection(int correctionId);

  /// Ferme la correction sans la publier. Rend les chemins des images
  /// ajoutées dedans, à supprimer avec [supprimerImage].
  Future<List<String>> abandonnerCorrection(int correctionId);

  /// Versions publiées de la leçon, de la plus récente à la plus ancienne.
  Future<List<VersionLecon>> versions(int leconId);

  /// Validateur : remet en ligne le texte de la version. Rend le numéro de
  /// la nouvelle version.
  Future<int> revenirAVersion(int versionId);

  // --- Signalements des lecteurs (D38) ---

  /// Signalements à traiter (état `nouveau`), du plus ancien au plus récent.
  Future<List<Signalement>> signalements();

  /// Marque le signalement traité, écarté, ou le remet à traiter.
  Future<void> traiterSignalement(int id, EtatSignalement etat);
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
    final lignes = await _client
        .from('points_leves')
        .select('id, lecon_id, point, leve_le, commentaire, correction_id')
        .order('leve_le');
    return lignes.map(PointLeve.fromJson).toList();
  }

  @override
  Future<PointLeve> leverPoint({required int leconId, required String point, String? commentaire, int? correctionId}) async {
    // `leve_par` est rempli par la base avec le compte connecté.
    final ligne = await _client
        .from('points_leves')
        .insert({'lecon_id': leconId, 'point': point, 'commentaire': commentaire, 'correction_id': correctionId})
        .select('id, lecon_id, point, leve_le, commentaire, correction_id')
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
    final (ligne, correction) = await (
      _client.from('lecons').select('id, titre, statut, introduction, corps').eq('id', leconId).maybeSingle(),
      correctionDe(leconId),
    ).wait;
    if (ligne == null) return null;
    final enLigne = TexteLecon.fromJson(ligne);
    if (correction == null) return enLigne;
    // Correction ouverte : on travaille sur la copie de travail (D33).
    return TexteLecon(
      id: enLigne.id,
      titre: correction.texte.titre,
      publiee: enLigne.publiee,
      introduction: correction.texte.introduction,
      corps: correction.texte.corps,
      correctionId: correction.id,
    );
  }

  @override
  Future<List<SchemaLecon>> schemasLecon(int leconId) async {
    final lignes = await _client
        .from('schemas_lecons')
        .select('id, lecon_id, champ, chemin, description, ajoute_le, correction_id')
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

  // --- Corrections et versions (D33) ---

  (String, bool)? _validateur;

  @override
  Future<bool> estValidateur() async {
    final compte = _client.auth.currentUser?.id;
    if (compte == null) return false;
    final connu = _validateur;
    if (connu != null && connu.$1 == compte) return connu.$2;
    final reponse = await _client.rpc<bool>('est_validateur');
    _validateur = (compte, reponse);
    return reponse;
  }

  static const _colonnesCorrection = 'id, lecon_id, titre, objectifs, introduction, corps, a_retenir, '
      'points_a_verifier, motif, demandee_par, demandee_le, modifiee_le, '
      'lecons(titre, chapitres(classes(libelle, ordre), matieres(nom, slug)))';

  @override
  Future<List<CorrectionLecon>> correctionsEnCours() async {
    final lignes = await _client
        .from('corrections_lecons')
        .select(_colonnesCorrection)
        .eq('etat', 'ouverte')
        .order('demandee_le');
    final moi = _client.auth.currentUser?.id;
    return [for (final l in lignes) CorrectionLecon.fromJson(l, moi: moi)];
  }

  @override
  Future<CorrectionLecon?> correctionDe(int leconId) async {
    final ligne = await _client
        .from('corrections_lecons')
        .select(_colonnesCorrection)
        .eq('lecon_id', leconId)
        .eq('etat', 'ouverte')
        .maybeSingle();
    return ligne == null ? null : CorrectionLecon.fromJson(ligne, moi: _client.auth.currentUser?.id);
  }

  @override
  Future<int> demanderCorrection({required int leconId, required String motif, required List<String> points}) async {
    final id = await _client.rpc<num>('demander_correction', params: {
      'p_lecon_id': leconId,
      'p_motif': motif,
      'p_points': points,
    });
    return id.toInt();
  }

  @override
  Future<int> publierCorrection(int correctionId) async {
    final numero = await _client.rpc<num>('publier_correction', params: {'p_correction_id': correctionId});
    return numero.toInt();
  }

  @override
  Future<List<String>> abandonnerCorrection(int correctionId) async {
    final chemins = await _client.rpc<List<dynamic>>('abandonner_correction', params: {'p_correction_id': correctionId});
    return [for (final c in chemins) c as String];
  }

  @override
  Future<List<VersionLecon>> versions(int leconId) async {
    final lignes = await _client
        .from('versions_lecons')
        .select('id, lecon_id, numero, motif, publiee_le, titre, objectifs, introduction, corps, a_retenir')
        .eq('lecon_id', leconId)
        .order('numero', ascending: false);
    return lignes.map(VersionLecon.fromJson).toList();
  }

  @override
  Future<int> revenirAVersion(int versionId) async {
    final numero = await _client.rpc<num>('revenir_a_version', params: {'p_version_id': versionId});
    return numero.toInt();
  }

  // --- Signalements des lecteurs (D38) ---

  @override
  Future<List<Signalement>> signalements() async {
    // Règle RLS : seuls les rédacteurs lisent cette table. Le titre vient de
    // `lecons`, que les rédacteurs lisent quel que soit le statut.
    final lignes = await _client
        .from('signalements')
        .select('id, lecon_id, exercice_id, motif, precision_texte, recu_le, lecons(titre), exercices(ordre)')
        .eq('etat', EtatSignalement.nouveau.code)
        .order('recu_le');
    return lignes.map(Signalement.fromJson).toList();
  }

  @override
  Future<void> traiterSignalement(int id, EtatSignalement etat) =>
      _client.rpc<void>('traiter_signalement', params: {'p_id': id, 'p_etat': etat.code});
}
