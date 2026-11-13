// Modèles de données SamaClasse, alignés sur le schéma Supabase « samaclasse ».
//
// Chaque modèle se construit depuis une ligne JSON renvoyée par Supabase
// (fromJson). Les noms de colonnes restent ceux de la base (snake_case),
// les champs Dart sont en camelCase.

/// Fiabilité d'un chapitre du programme (enum `statut_programme`).
enum StatutProgramme {
  officiel('officiel'),
  source('source'),
  cahier('cahier'),
  aValider('a_valider'),
  aCompleter('a_completer');

  const StatutProgramme(this.db);
  final String db;

  static StatutProgramme fromDb(String valeur) => values.firstWhere(
        (e) => e.db == valeur,
        orElse: () => throw FormatException('statut_programme inconnu : $valeur'),
      );
}

/// État de rédaction d'une leçon (enum `statut_lecon`).
/// Les élèves ne voient que les leçons `publiee` (règle RLS).
enum StatutLecon {
  brouillon('brouillon'),
  aVerifier('a_verifier'),
  publiee('publiee');

  const StatutLecon(this.db);
  final String db;

  static StatutLecon fromDb(String valeur) => values.firstWhere(
        (e) => e.db == valeur,
        orElse: () => throw FormatException('statut_lecon inconnu : $valeur'),
      );
}

/// Niveau d'un exercice (enum `niveau_exercice`).
enum NiveauExercice {
  jeConnais('je_connais', 'Je connais'),
  jApplique('j_applique', "J'applique"),
  jeReflechis('je_reflechis', 'Je réfléchis');

  const NiveauExercice(this.db, this.libelle);
  final String db;
  final String libelle;

  static NiveauExercice fromDb(String valeur) => values.firstWhere(
        (e) => e.db == valeur,
        orElse: () => throw FormatException('niveau_exercice inconnu : $valeur'),
      );
}

/// Type d'exercice (enum `type_exercice`).
enum TypeExercice {
  qcm('qcm', 'QCM'),
  vraiFaux('vrai_faux', 'Vrai ou faux'),
  relier('relier', 'Relier'),
  tableau('tableau', 'Tableau à compléter'),
  questionCours('question_cours', 'Question de cours'),
  documents('documents', 'Exploitation de documents'),
  experience('experience', 'Expérience à interpréter'),
  calcul('calcul', 'Calcul'),
  redaction('redaction', 'Rédaction'),
  epreuve('epreuve', 'Épreuve type');

  const TypeExercice(this.db, this.libelle);
  final String db;
  final String libelle;

  static TypeExercice fromDb(String valeur) => values.firstWhere(
        (e) => e.db == valeur,
        orElse: () => throw FormatException('type_exercice inconnu : $valeur'),
      );
}

int _entier(Object? v) => (v as num).toInt();
int? _entierOuNull(Object? v) => v == null ? null : (v as num).toInt();
List<String> _textes(Object? v) => v == null ? const [] : List<String>.from(v as List);

/// Une classe (4ème, Seconde L…), table `classes`.
class Classe {
  const Classe({
    required this.id,
    required this.code,
    required this.libelle,
    required this.cycle,
    required this.ordre,
  });

  final int id;
  final String code;
  final String libelle;
  final String cycle;
  final int ordre;

  factory Classe.fromJson(Map<String, dynamic> json) => Classe(
        id: _entier(json['id']),
        code: json['code'] as String,
        libelle: json['libelle'] as String,
        cycle: json['cycle'] as String,
        ordre: _entier(json['ordre']),
      );
}

/// Une matière dans une classe, avec ses compteurs (vue `matieres_par_classe`).
class MatiereDeClasse {
  const MatiereDeClasse({
    required this.classeId,
    required this.matiereId,
    required this.slug,
    required this.nom,
    required this.nbChapitres,
    required this.nbLecons,
  });

  final int classeId;
  final int matiereId;
  final String slug;
  final String nom;
  final int nbChapitres;

  /// Leçons publiées seulement.
  final int nbLecons;

  factory MatiereDeClasse.fromJson(Map<String, dynamic> json) => MatiereDeClasse(
        classeId: _entier(json['classe_id']),
        matiereId: _entier(json['matiere_id']),
        slug: json['slug'] as String,
        nom: json['nom'] as String,
        nbChapitres: _entier(json['nb_chapitres']),
        nbLecons: _entier(json['nb_lecons']),
      );
}

/// Résumé d'une leçon, tel qu'il apparaît dans la liste des chapitres.
class LeconResume {
  const LeconResume({
    required this.id,
    required this.numero,
    required this.titre,
    this.nbExercices,
  });

  final int id;
  final int numero;
  final String titre;

  /// Nombre d'exercices, quand la requête le demande (`exercices(count)`).
  final int? nbExercices;

  factory LeconResume.fromJson(Map<String, dynamic> json) {
    // PostgREST renvoie un comptage embarqué sous la forme [{"count": 5}].
    final comptage = json['exercices'];
    int? nb;
    if (comptage is List && comptage.isNotEmpty && comptage.first is Map) {
      nb = _entierOuNull((comptage.first as Map)['count']);
    }
    return LeconResume(
      id: _entier(json['id']),
      numero: _entierOuNull(json['numero']) ?? 1,
      titre: json['titre'] as String,
      nbExercices: nb,
    );
  }
}

/// Un chapitre du programme, table `chapitres`, avec ses leçons visibles.
class Chapitre {
  const Chapitre({
    required this.id,
    required this.numero,
    required this.titre,
    required this.partie,
    required this.statut,
    required this.remarque,
    required this.lecons,
  });

  final int id;
  final int numero;
  final String titre;
  final String? partie;
  final StatutProgramme statut;
  final String? remarque;
  final List<LeconResume> lecons;

  bool get aUneLecon => lecons.isNotEmpty;

  factory Chapitre.fromJson(Map<String, dynamic> json) => Chapitre(
        id: _entier(json['id']),
        numero: _entier(json['numero']),
        titre: json['titre'] as String,
        partie: json['partie'] as String?,
        statut: StatutProgramme.fromDb(json['statut'] as String),
        remarque: json['remarque'] as String?,
        lecons: ((json['lecons'] as List?) ?? const [])
            .map((e) => LeconResume.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Une ligne du bloc « À retenir ».
class ElementARetenir {
  const ElementARetenir({required this.notion, required this.essentiel});

  final String notion;
  final String essentiel;

  factory ElementARetenir.fromJson(Map<String, dynamic> json) => ElementARetenir(
        notion: json['notion'] as String,
        essentiel: json['essentiel'] as String,
      );
}

/// Un exercice, table `exercices`.
///
/// [donnees] et [reponse] gardent le JSON brut : leur forme dépend du type.
/// Conventions (voir le gabarit de leçon) :
/// - QCM : `donnees.questions` = [{q, choix}], `reponse` = indices (à partir de 0) ;
/// - vrai ou faux : `donnees.affirmations`, `reponse` = liste de booléens ;
/// - relier : `donnees.gauche` / `donnees.droite`, `reponse` = {gauche: droite} ;
/// - tableau : `reponse` = liste ordonnée ou {catégorie: [éléments]} ;
/// - calcul : `reponse` = objet dont les feuilles sont des nombres ou des textes.
class Exercice {
  const Exercice({
    required this.id,
    required this.ordre,
    required this.niveau,
    required this.type,
    required this.enonce,
    required this.donnees,
    required this.reponse,
    required this.corrige,
  });

  final int id;
  final int ordre;
  final NiveauExercice niveau;
  final TypeExercice type;

  /// Markdown.
  final String enonce;
  final Object? donnees;
  final Object? reponse;

  /// Markdown, affiché après la réponse de l'élève.
  final String? corrige;

  factory Exercice.fromJson(Map<String, dynamic> json) => Exercice(
        id: _entier(json['id']),
        ordre: _entier(json['ordre']),
        niveau: NiveauExercice.fromDb(json['niveau'] as String),
        type: TypeExercice.fromDb(json['type'] as String),
        enonce: json['enonce'] as String,
        donnees: json['donnees'],
        reponse: json['reponse'],
        corrige: json['corrige'] as String?,
      );
}

/// Où se situe une leçon : classe, matière, chapitre.
class ContexteLecon {
  const ContexteLecon({
    required this.classe,
    required this.matiere,
    required this.matiereSlug,
    required this.chapitre,
    required this.partie,
  });

  final String classe;
  final String matiere;
  final String? matiereSlug;
  final String chapitre;
  final String? partie;

  factory ContexteLecon.fromJson(Map<String, dynamic> json) {
    final matiere = json['matieres'] as Map<String, dynamic>;
    return ContexteLecon(
      classe: (json['classes'] as Map<String, dynamic>)['libelle'] as String,
      matiere: matiere['nom'] as String,
      matiereSlug: matiere['slug'] as String?,
      chapitre: json['titre'] as String,
      partie: json['partie'] as String?,
    );
  }
}

/// Une leçon complète, table `lecons`, avec ses exercices.
class Lecon {
  const Lecon({
    required this.id,
    required this.chapitreId,
    required this.numero,
    required this.titre,
    required this.dateCours,
    required this.objectifs,
    required this.introduction,
    required this.corps,
    required this.aRetenir,
    required this.pointsAVerifier,
    required this.statut,
    required this.exercices,
    required this.contexte,
  });

  final int id;
  final int chapitreId;
  final int numero;
  final String titre;
  final DateTime? dateCours;
  final List<String> objectifs;

  /// Markdown.
  final String? introduction;

  /// Markdown. Un schéma non encore converti en image apparaît comme
  /// une ligne en italique entre crochets.
  final String? corps;
  final List<ElementARetenir> aRetenir;
  final List<String> pointsAVerifier;
  final StatutLecon statut;
  final List<Exercice> exercices;
  final ContexteLecon? contexte;

  factory Lecon.fromJson(Map<String, dynamic> json) {
    final exercices = ((json['exercices'] as List?) ?? const [])
        .map((e) => Exercice.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ordre.compareTo(b.ordre));
    final chapitre = json['chapitres'] as Map<String, dynamic>?;
    final date = json['date_cours'] as String?;
    return Lecon(
      id: _entier(json['id']),
      chapitreId: _entier(json['chapitre_id']),
      numero: _entierOuNull(json['numero']) ?? 1,
      titre: json['titre'] as String,
      dateCours: date == null ? null : DateTime.parse(date),
      objectifs: _textes(json['objectifs']),
      introduction: json['introduction'] as String?,
      corps: json['corps'] as String?,
      aRetenir: ((json['a_retenir'] as List?) ?? const [])
          .map((e) => ElementARetenir.fromJson(e as Map<String, dynamic>))
          .toList(),
      pointsAVerifier: _textes(json['points_a_verifier']),
      statut: StatutLecon.fromDb(json['statut'] as String),
      exercices: exercices,
      contexte: chapitre == null ? null : ContexteLecon.fromJson(chapitre),
    );
  }
}
