// Chargement des vraies polices de l'application dans les tests.
//
// Par défaut, les tests dessinent tout avec une police de test à chasse fixe
// (chaque lettre est un carré). C'est bien pour la plupart des tests, mais
// pas pour mesurer l'alignement sur les lignes Seyès ni pour des captures :
// la position de la ligne de base dépend des métriques de la vraie police.

import 'dart:io';

import 'package:flutter/services.dart';

Future<void> _charger(String famille, List<String> fichiers) async {
  final chargeur = FontLoader(famille);
  for (final f in fichiers) {
    chargeur.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await chargeur.load();
}

/// Charge Atkinson Hyperlegible Next, Playwrite FR Moderne et, si le SDK
/// Flutter est trouvé, les icônes Material. À appeler dans `setUpAll`.
Future<void> chargerPolicesReelles() async {
  await _charger('AtkinsonHyperlegibleNext', [
    'assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf',
    'assets/fonts/AtkinsonHyperlegibleNext-SemiBold.ttf',
    'assets/fonts/AtkinsonHyperlegibleNext-Bold.ttf',
  ]);
  await _charger('PlaywriteFRModerne', ['assets/fonts/PlaywriteFRModerne-Regular.ttf']);
  // Polices de secours (D17) : sans elles, exposants et flèches seraient des
  // cases vides dans les captures (les tests n'ont pas de police système).
  await _charger('NotoSansSecours', ['assets/fonts/NotoSansSecours-Regular.ttf']);
  await _charger('NotoSansMathSecours', ['assets/fonts/NotoSansMathSecours-Regular.ttf']);
  final flutter = Platform.environment['FLUTTER_ROOT'];
  final icones = '$flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  if (flutter != null && File(icones).existsSync()) {
    await _charger('MaterialIcons', [icones]);
  }
}
