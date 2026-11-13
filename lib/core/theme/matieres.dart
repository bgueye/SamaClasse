import 'package:flutter/painting.dart';

/// Couleur de protège-cahier de chaque matière (clé : `matieres.slug`).
/// Les sept premières viennent des maquettes.
const _couleursMatieres = <String, Color>{
  'histoire': Color(0xFFE07A1F),
  'geographie': Color(0xFF1C8C9E),
  'francais': Color(0xFFD62839),
  'svt': Color(0xFF5BA829),
  'sciences-physiques': Color(0xFF7048C2),
  'education-civique': Color(0xFFC99A00),
  'mathematiques': Color(0xFF2140C9),
  'anglais': Color(0xFFB8336A),
  'espagnol': Color(0xFF8C5A2B),
  'economie': Color(0xFF5D6B7A),
};

const _couleurParDefaut = Color(0xFF8A93A8);

Color couleurMatiere(String? slug) => _couleursMatieres[slug] ?? _couleurParDefaut;
