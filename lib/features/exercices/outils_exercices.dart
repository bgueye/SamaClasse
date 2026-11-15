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

/// Vrai si l'élève n'a rien rempli : aucune case cochée, aucune paire
/// reliée, aucun champ saisi (espaces seuls compris).
///
/// Sert au suivi des parents (phase 3) : un exercice validé sans réponse ne
/// dit rien du niveau de l'enfant, il n'est donc pas noté (décision de Bocar
/// du 15/11/2026). Parcourt la réponse quelle que soit sa forme (liste,
/// dictionnaire, texte), comme la produit [reponseInitiale] puis la saisie.
bool reponseVide(Object? reponse) => switch (reponse) {
      null => true,
      final String s => s.trim().isEmpty,
      final List l => l.every(reponseVide),
      final Map m => m.values.every(reponseVide),
      _ => false, // un nombre, un booléen : une réponse a été donnée
    };

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

/// Catégories d'un tableau de classement, dans l'ordre d'affichage, avec
/// leur libellé (décision D14, format dans EXERCICES.md).
///
/// Les clés viennent de `reponse` (ce sont elles que la correction compare).
/// `donnees.categories`, facultatif, donne le libellé affichable de chaque
/// clé (« homogene » → « Homogène ») :
/// - une clé de `donnees.categories` absente de `reponse` est ignorée (aucun
///   élément ne pourrait y aller) ;
/// - un libellé absent, vide ou mal formé retombe sur [libelleCle].
///
/// Ordre : alphabétique des libellés, sans tenir compte des accents. On ne
/// peut pas se fier à l'ordre des clés : la base les range dans un objet
/// `jsonb` par longueur puis par ordre alphabétique (« cotiers, insulaire,
/// continentaux »), quel que soit l'ordre d'écriture. L'ordre alphabétique est
/// prévisible et ne trahit pas la réponse.
List<({String cle, String libelle})> categoriesDuClassement(Exercice exercice) {
  final attendu = exercice.reponse;
  if (attendu is! Map) return const [];
  final cles = attendu.keys.cast<String>().toList();

  final donnees = exercice.donnees;
  final fournis = donnees is Map && donnees['categories'] is Map ? donnees['categories'] as Map : const {};
  String libelle(String cle) {
    final texte = fournis[cle];
    return texte is String && texte.trim().isNotEmpty ? texte.trim() : libelleCle(cle);
  }

  return [for (final cle in cles) (cle: cle, libelle: libelle(cle))]
    ..sort((a, b) => normaliser(a.libelle).compareTo(normaliser(b.libelle)));
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
