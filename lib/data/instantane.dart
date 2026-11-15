// Instantané de tout le contenu publié : ce que Supabase renvoie aux quatre
// requêtes de synchronisation, gardé tel quel (JSON brut).
//
// Pourquoi du JSON brut plutôt que des modèles : il s'enregistre sans
// conversion sur l'appareil, et les modèles se construisent avec les mêmes
// `fromJson` que si les lignes venaient du réseau. Les règles d'ordre de
// l'ancienne lecture directe sont conservées : le serveur trie (classes par
// ordre, matières par nom, chapitres et leçons par numéro, exercices par
// ordre), et le filtrage ci-dessous garde cet ordre.

import 'models.dart';

class Instantane {
  Instantane({
    required this.classesBrutes,
    required this.matieresBrutes,
    required this.chapitresBruts,
    required this.leconsBrutes,
  });

  final List<Map<String, dynamic>> classesBrutes;

  /// Toutes les lignes de la vue `matieres_par_classe`, triées par nom.
  final List<Map<String, dynamic>> matieresBrutes;

  /// Tous les chapitres (avec `classe_id` et `matiere_id`), triés par numéro.
  final List<Map<String, dynamic>> chapitresBruts;

  /// Toutes les leçons publiées, complètes (exercices, contexte).
  final List<Map<String, dynamic>> leconsBrutes;

  /// Copie sans aucune leçon non publiée.
  ///
  /// Depuis la phase 4, un rédacteur connecté peut lire les leçons « à
  /// vérifier » (règle RLS). Le téléchargement demande déjà `statut =
  /// 'publiee'` au serveur ; ce filtre est le second garde-fou, côté
  /// téléphone : une leçon non publiée ne doit jamais entrer dans la copie
  /// locale, d'où elle s'afficherait aux élèves comme si elle l'était.
  /// Une ligne sans `statut` est gardée : les anciennes copies ne
  /// contenaient que des leçons publiées.
  Instantane seulementPublie() {
    bool publiee(Object? ligne) {
      final statut = (ligne as Map)['statut'];
      return statut == null || statut == 'publiee';
    }

    return Instantane(
      classesBrutes: classesBrutes,
      matieresBrutes: matieresBrutes,
      chapitresBruts: [
        for (final c in chapitresBruts)
          {
            ...c,
            if (c['lecons'] is List) 'lecons': [for (final l in c['lecons'] as List) if (publiee(l)) l],
          },
      ],
      leconsBrutes: [for (final l in leconsBrutes) if (publiee(l)) l],
    );
  }

  List<Classe> classes() => classesBrutes.map(Classe.fromJson).toList();

  List<MatiereDeClasse> matieres(int classeId) => matieresBrutes
      .where((m) => _entier(m['classe_id']) == classeId)
      .map(MatiereDeClasse.fromJson)
      .toList();

  List<Chapitre> chapitres({required int classeId, required int matiereId}) => chapitresBruts
      .where((c) => _entier(c['classe_id']) == classeId && _entier(c['matiere_id']) == matiereId)
      .map(Chapitre.fromJson)
      .toList();

  List<Lecon> lecons() => leconsBrutes.map(Lecon.fromJson).toList();

  Lecon? lecon(int id) {
    for (final l in leconsBrutes) {
      if (_entier(l['id']) == id) return Lecon.fromJson(l);
    }
    return null;
  }

  // --- Enregistrement sur l'appareil ---

  Map<String, Object?> toJson() => {
        'classes': classesBrutes,
        'matieres': matieresBrutes,
        'chapitres': chapitresBruts,
        'lecons': leconsBrutes,
      };

  /// Relit un instantané enregistré. Lève une erreur si le format ne
  /// correspond pas (copie abîmée, ancienne version) : l'appelant l'ignore.
  factory Instantane.fromJson(Map<String, dynamic> json) => Instantane(
        classesBrutes: _lignes(json['classes']),
        matieresBrutes: _lignes(json['matieres']),
        chapitresBruts: _lignes(json['chapitres']),
        leconsBrutes: _lignes(json['lecons']),
      );

  static List<Map<String, dynamic>> _lignes(Object? v) =>
      (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  static int _entier(Object? v) => (v as num).toInt();
}
