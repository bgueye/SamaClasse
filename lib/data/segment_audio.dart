/// Un passage du script de lecture d'une leçon (colonne `lecons.script_audio`).
///
/// Format en base : `[{"lang": "fr-FR", "texte": "..."}, ...]`, liste
/// ordonnée. `lang` est un code BCP-47 passé tel quel au moteur de synthèse
/// vocale ; `texte` est déjà rédigé pour l'oral (pas de Markdown) : l'app le
/// lit sans jamais le modifier ni le fabriquer à partir du corps de la leçon.
class SegmentAudio {
  const SegmentAudio({required this.lang, required this.texte});

  final String lang;
  final String texte;

  /// Un passage sans langue est lu en français, la langue de l'interface.
  factory SegmentAudio.fromJson(Map<String, dynamic> json) => SegmentAudio(
        lang: (json['lang'] as String?) ?? 'fr-FR',
        texte: (json['texte'] as String?) ?? '',
      );

  /// Convertit la valeur brute de `script_audio` (null ou liste JSON).
  ///
  /// Tolérante plutôt que stricte : un élément mal formé est ignoré au lieu
  /// de faire échouer l'ouverture de toute la leçon. Une leçon sans script
  /// renvoie une liste vide : le lecteur ne s'affiche pas.
  static List<SegmentAudio> listeDepuis(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map((m) => SegmentAudio.fromJson(Map<String, dynamic>.from(m)))
        .where((s) => s.texte.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) => other is SegmentAudio && other.lang == lang && other.texte == texte;

  @override
  int get hashCode => Object.hash(lang, texte);
}
