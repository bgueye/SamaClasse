// Correction des exercices SamaClasse.
//
// Les types à réponse fermée (QCM, vrai ou faux, relier, tableau, calcul)
// sont corrigés automatiquement quand leur `reponse` suit les conventions
// du gabarit. Les autres types affichent simplement le corrigé.

import 'models.dart';

/// Résultat d'une correction.
sealed class Correction {
  const Correction();
}

/// Correction faite par l'application.
final class CorrectionAuto extends Correction {
  const CorrectionAuto(this.details);

  /// Un booléen par élément attendu (question, affirmation, case…),
  /// dans l'ordre de l'exercice.
  final List<bool> details;

  int get bonnes => details.where((juste) => juste).length;
  int get total => details.length;
  bool get toutJuste => bonnes == total;
}

/// L'élève compare lui-même sa réponse avec le corrigé.
final class CorrectionManuelle extends Correction {
  const CorrectionManuelle(this.corrige);

  final String? corrige;
}

/// La réponse de l'élève n'a pas la forme attendue (bug d'écran, en principe).
final class ReponseInvalide extends Correction {
  const ReponseInvalide(this.raison);

  final String raison;
}

/// Corrige [reponseEleve] pour [exercice].
///
/// Forme attendue de [reponseEleve] selon le type :
/// - QCM : `List<int?>` (indice choisi par question, `null` si pas de réponse) ;
/// - vrai ou faux : `List<bool?>` ;
/// - relier : `Map<String, String>` (élément de gauche → élément de droite) ;
/// - tableau : `List<String>` ou `Map<String, List<String>>`, comme la réponse attendue ;
/// - calcul : `Map<String, Object>` dont les clés sont les chemins de
///   [cheminsAttendus] (par exemple `totaux.0`, `aire_minimale_m2`).
Correction corriger(Exercice exercice, Object? reponseEleve) {
  final attendu = exercice.reponse;
  final manuelle = CorrectionManuelle(exercice.corrige);
  if (!estAutoCorrigeable(exercice)) return manuelle;

  switch (exercice.type) {
    case TypeExercice.qcm:
      return _comparerListes<int>(attendu as List, reponseEleve, (a, e) => a == e);
    case TypeExercice.vraiFaux:
      return _comparerListes<bool>(attendu as List, reponseEleve, (a, e) => a == e);
    case TypeExercice.relier:
      return _corrigerRelier(attendu as Map, reponseEleve, exercice.donnees);
    case TypeExercice.tableau:
      if (attendu is List) {
        return _comparerListes<String>(attendu, reponseEleve, memeTexte);
      }
      return _corrigerClassement(attendu as Map, reponseEleve);
    case TypeExercice.calcul:
      return _corrigerCalcul(attendu as Map, reponseEleve);
    default:
      return manuelle;
  }
}

/// Indique si l'application peut corriger seule cet exercice.
bool estAutoCorrigeable(Exercice exercice) {
  final r = exercice.reponse;
  switch (exercice.type) {
    case TypeExercice.qcm:
      return r is List && r.every((v) => v is int);
    case TypeExercice.vraiFaux:
      return r is List && r.every((v) => v is bool);
    case TypeExercice.relier:
      return r is Map && r.values.every((v) => v is String);
    case TypeExercice.tableau:
      if (r is List) return r.every((v) => v is String);
      if (r is Map) return r.values.every((v) => v is List && v.every((x) => x is String));
      return false;
    case TypeExercice.calcul:
      if (r is! Map) return false;
      final feuilles = _aplatir(r);
      return feuilles.isNotEmpty && feuilles.values.every((v) => v is num || v is String);
    default:
      return false;
  }
}

/// Chemins des valeurs attendues pour un calcul, dans l'ordre :
/// `{"totaux": [5, 7], "aire": 8}` donne `totaux.0`, `totaux.1`, `aire`.
List<String> cheminsAttendus(Exercice exercice) {
  final r = exercice.reponse;
  return r is Map ? _aplatir(r).keys.toList() : const [];
}

/// Valeurs attendues d'un calcul, par chemin (voir [cheminsAttendus]).
Map<String, Object?> valeursAttendues(Exercice exercice) {
  final r = exercice.reponse;
  return r is Map ? _aplatir(r) : const {};
}

/// Compare deux textes sans tenir compte de la casse, des accents,
/// des espaces en trop, de la ponctuation finale ni du type d'apostrophe.
bool memeTexte(String a, String b) => normaliser(a) == normaliser(b);

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ç': 'c', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
};

String normaliser(String texte) {
  final buffer = StringBuffer();
  for (final rune in texte.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    buffer.write(_accents[c] ?? (c == '’' || c == 'ʼ' ? "'" : c));
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[\s.;,!?:]+$'), '');
}

/// Un entier attendu (date, effectif, durée) doit être donné exactement ;
/// un décimal est accepté à 0,1 % près (et à 1e-9 près pour zéro).
bool memeNombre(num attendu, num eleve) {
  if (attendu is int) return eleve == attendu;
  final ecart = (attendu - eleve).abs();
  return ecart <= 1e-9 || ecart <= attendu.abs() * 1e-3;
}

/// Lit un nombre saisi par l'élève : « 8,5 », « 1 000 », « -3 ».
num? lireNombre(Object? valeur) {
  if (valeur is num) return valeur;
  if (valeur == null) return null;
  final texte = '$valeur'.replaceAll(',', '.').replaceAll(RegExp(r'\s'), '');
  return num.tryParse(texte);
}

Correction _comparerListes<T>(
  List attendu,
  Object? eleve,
  bool Function(T attendu, T eleve) egal,
) {
  if (eleve is! List) return const ReponseInvalide('Une liste de réponses est attendue.');
  if (eleve.length != attendu.length) {
    return ReponseInvalide('${attendu.length} réponses attendues, ${eleve.length} reçues.');
  }
  final details = <bool>[];
  for (var i = 0; i < attendu.length; i++) {
    final e = eleve[i];
    details.add(e is T && egal(attendu[i] as T, e));
  }
  return CorrectionAuto(details);
}

Correction _corrigerRelier(Map attendu, Object? eleve, Object? donnees) {
  if (eleve is! Map) return const ReponseInvalide('Des paires à relier sont attendues.');
  final details = <bool>[];
  for (final g in ordreGauche(attendu, donnees)) {
    final bon = attendu[g] as String?;
    final choisi = eleve[g];
    details.add(bon != null && choisi is String && memeTexte(bon, choisi));
  }
  return CorrectionAuto(details);
}

/// Ordre d'affichage de la colonne de gauche d'un exercice « relier » :
/// celui de `donnees.gauche` s'il existe, sinon celui des clés de la réponse.
List<String> ordreGauche(Map attendu, Object? donnees) =>
    (donnees is Map && donnees['gauche'] is List)
        ? List<String>.from(donnees['gauche'] as List)
        : attendu.keys.cast<String>().toList();

Correction _corrigerClassement(Map attendu, Object? eleve) {
  if (eleve is! Map) return const ReponseInvalide('Un classement par catégorie est attendu.');
  final details = <bool>[];
  for (final entree in attendu.entries) {
    final choix = eleve[entree.key];
    final placesParEleve = choix is List ? choix.whereType<String>().toList() : const <String>[];
    for (final element in (entree.value as List).cast<String>()) {
      details.add(placesParEleve.any((p) => memeTexte(p, element)));
    }
  }
  return CorrectionAuto(details);
}

Correction _corrigerCalcul(Map attendu, Object? eleve) {
  if (eleve is! Map) return const ReponseInvalide('Des valeurs par champ sont attendues.');
  final details = <bool>[];
  _aplatir(attendu).forEach((chemin, bon) {
    final valeur = eleve[chemin];
    if (bon is num) {
      final nombre = lireNombre(valeur);
      details.add(nombre != null && memeNombre(bon, nombre));
    } else {
      details.add(valeur is String && memeTexte(bon as String, valeur));
    }
  });
  return CorrectionAuto(details);
}

/// Aplatit un JSON en {chemin: feuille} : listes indexées, objets par clé.
Map<String, Object?> _aplatir(Object? valeur, [String prefixe = '']) {
  final resultat = <String, Object?>{};
  String cle(Object k) => prefixe.isEmpty ? '$k' : '$prefixe.$k';
  if (valeur is Map) {
    valeur.forEach((k, v) => resultat.addAll(_aplatir(v, cle(k as Object))));
  } else if (valeur is List) {
    for (var i = 0; i < valeur.length; i++) {
      resultat.addAll(_aplatir(valeur[i], cle(i)));
    }
  } else {
    resultat[prefixe] = valeur;
  }
  return resultat;
}
