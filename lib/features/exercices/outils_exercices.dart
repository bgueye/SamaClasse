// Fonctions pures autour des exercices : réponse vide de départ, libellés.

import '../../data/data.dart';

/// Réponse « vide » d'un exercice, dans la forme attendue par [corriger].
Object? reponseInitiale(Exercice exercice) {
  if (!estAutoCorrigeable(exercice)) return '';
  final attendu = exercice.reponse;
  switch (exercice.type) {
    case TypeExercice.qcm:
      return List<int?>.filled((attendu as List).length, null);
    case TypeExercice.vraiFaux:
      return List<bool?>.filled((attendu as List).length, null);
    case TypeExercice.relier:
      return <String, String>{};
    case TypeExercice.tableau:
      if (attendu is List) return List<String>.filled(attendu.length, '');
      return {for (final cle in (attendu as Map).keys) cle as String: <String>[]};
    case TypeExercice.calcul:
      return <String, Object>{};
    default:
      return '';
  }
}

/// « aire_minimale_m2 » → « Aire minimale m2 ».
String libelleCle(String cle) {
  final texte = cle.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (texte.isEmpty) return cle;
  return texte[0].toUpperCase() + texte.substring(1);
}

/// Libellé d'un champ de calcul à partir de son chemin :
/// « totaux.0 » → « Totaux n° 1 », « 476 » → « 476 ».
String libelleChemin(String chemin) {
  final morceaux = chemin.split('.');
  final libelles = <String>[];
  for (var i = 0; i < morceaux.length; i++) {
    final indice = int.tryParse(morceaux[i]);
    if (indice != null && i > 0) {
      libelles.add('n° ${indice + 1}');
    } else {
      libelles.add(libelleCle(morceaux[i]));
    }
  }
  return libelles.join(' ');
}

/// Nombre au format français : 8.5 → « 8,5 ».
String formaterValeur(Object? valeur) {
  if (valeur is double) {
    final texte = valeur == valeur.roundToDouble() ? valeur.toInt().toString() : valeur.toString();
    return texte.replaceAll('.', ',');
  }
  return '${valeur ?? ''}';
}

/// Éléments à classer d'un tableau de classement, triés pour ne pas
/// trahir la réponse par leur ordre.
List<String> elementsAClasser(Map attendu) {
  final elements = <String>[
    for (final liste in attendu.values) ...(liste as List).cast<String>(),
  ];
  elements.sort((a, b) => normaliser(a).compareTo(normaliser(b)));
  return elements;
}

/// Catégorie attendue d'un élément dans un tableau de classement.
String? categorieAttendue(Map attendu, String element) {
  for (final entree in attendu.entries) {
    if ((entree.value as List).cast<String>().any((e) => memeTexte(e, element))) {
      return entree.key as String;
    }
  }
  return null;
}
