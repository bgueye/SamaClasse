// Logique pure de l'écran « Leçons à vérifier » (phase 4), testée seule
// (test/features/validation_test.dart).
//
// Écran interne aux rédacteurs : tutoiement, comme sur la maquette.

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../data/data.dart';

/// Le point [point] de la leçon [leconId] a-t-il été levé ?
PointLeve? pointLeve(List<PointLeve> leves, int leconId, String point) {
  for (final p in leves) {
    if (p.leconId == leconId && p.point == point) return p;
  }
  return null;
}

/// Points de [lecon] qui restent à lever. La comparaison se fait sur le
/// texte, comme dans `publier_lecon` : un point dont le texte a changé dans
/// la leçon doit être relevé.
List<String> pointsRestants(LeconAVerifier lecon, List<PointLeve> leves) =>
    [for (final p in lecon.points) if (pointLeve(leves, lecon.id, p) == null) p];

/// Pastille d'une leçon : « 2 points », « 1 point », ou « Prête » quand tout
/// est levé.
String libellePastille(int restants) => switch (restants) {
      0 => 'Prête',
      1 => '1 point',
      _ => '$restants points',
    };

/// « 4ème, SVT ».
String libelleClasseMatiere(LeconAVerifier l) => '${l.classe}, ${l.matiere}';

/// Phrase sous le titre : « 3 leçons attendent ta relecture, 7 points à
/// lever avec les cahiers. »
String resumeValidation(List<LeconAVerifier> lecons, List<PointLeve> leves) {
  if (lecons.isEmpty) return 'Aucune leçon n’attend ta relecture pour l’instant.';
  final restants = lecons.fold<int>(0, (s, l) => s + pointsRestants(l, leves).length);
  final nbLecons = lecons.length == 1 ? '1 leçon attend ta relecture' : '${lecons.length} leçons attendent ta relecture';
  final nbPoints = switch (restants) {
    0 => 'tous les points sont levés',
    1 => '1 point à lever avec les cahiers',
    _ => '$restants points à lever avec les cahiers',
  };
  return '$nbLecons, $nbPoints. Une leçon n’est visible des élèves qu’une fois publiée.';
}

/// Leçons rangées par classe (ordre du cursus), puis matière, puis titre.
List<LeconAVerifier> trierLecons(List<LeconAVerifier> lecons) => [...lecons]..sort((a, b) {
    final classe = a.ordreClasse.compareTo(b.ordreClasse);
    if (classe != 0) return classe;
    final matiere = a.matiere.compareTo(b.matiere);
    return matiere != 0 ? matiere : a.titre.compareTo(b.titre);
  });

/// Message à afficher pour une erreur de rédaction (tutoiement).
///
/// Les refus de `publier_lecon` (code P0001) ont déjà un message clair en
/// français (« Il reste 1 point(s) à vérifier. ») : on l'affiche tel quel.
String messageErreurRedaction(Object erreur) {
  if (erreur is PostgrestException) {
    switch (erreur.code) {
      case 'P0001':
        return erreur.message;
      case '42501':
        return 'Ton compte n’a pas (ou plus) les droits de rédacteur.';
      case 'P0002':
        return 'Cette leçon n’existe plus.';
      case 'PGRST301':
      case 'PGRST303':
        return 'Ta session a expiré. Reconnecte-toi dans l’espace parents.';
    }
    return 'L’enregistrement n’a pas abouti. Réessaie dans un instant.';
  }
  // Le reste : très probablement le réseau.
  return 'Pas de connexion internet. Vérifie le réseau, puis réessaie.';
}
