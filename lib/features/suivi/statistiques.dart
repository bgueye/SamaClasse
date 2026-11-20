// Calculs de l'écran « Suivi de mes enfants » (phase 3), hors des widgets
// pour être testés seuls (test/features/suivi_test.dart).
//
// Tout se calcule sur le téléphone, à partir des lectures et des résultats
// renvoyés par la base (déjà limités aux enfants du parent connecté) et des
// leçons de la copie locale.

import 'package:flutter/foundation.dart';

import '../../data/data.dart';

/// Début de la semaine en cours : lundi 0 h, heure du téléphone. Une semaine
/// d'école commence le lundi.
DateTime debutSemaine(DateTime maintenant) {
  final local = maintenant.toLocal();
  final jour = DateTime(local.year, local.month, local.day);
  return jour.subtract(Duration(days: jour.weekday - DateTime.monday));
}

/// Les trois chiffres de « Cette semaine ».
@immutable
class BilanSemaine {
  const BilanSemaine({required this.leconsLues, required this.exercicesFaits, required this.reussis});

  final int leconsLues;
  final int exercicesFaits;
  final int reussis;

  /// Part d'exercices réussis, arrondie ; `null` sans exercice (on affiche
  /// alors un tiret : « 0 % » laisserait croire à des échecs).
  int? get pourcentage => exercicesFaits == 0 ? null : (reussis * 100 / exercicesFaits).round();

  @override
  bool operator ==(Object other) =>
      other is BilanSemaine &&
      other.leconsLues == leconsLues &&
      other.exercicesFaits == exercicesFaits &&
      other.reussis == reussis;

  @override
  int get hashCode => Object.hash(leconsLues, exercicesFaits, reussis);

  @override
  String toString() => 'BilanSemaine($leconsLues lues, $reussis/$exercicesFaits)';
}

/// Activité de l'enfant [enfantId] depuis lundi 0 h.
///
/// Une leçon relue plusieurs fois compte une fois (la base n'en garde qu'une
/// ligne). Un exercice refait compte à chaque fois : c'est du travail fait.
BilanSemaine bilanSemaine({
  required int enfantId,
  required List<LectureLecon> lectures,
  required List<ResultatExercice> resultats,
  required DateTime maintenant,
}) {
  final debut = debutSemaine(maintenant);
  bool cetteSemaine(DateTime d) => !d.toLocal().isBefore(debut);
  final semaine = [for (final r in resultats) if (r.enfantId == enfantId && cetteSemaine(r.faitLe)) r];
  return BilanSemaine(
    leconsLues: lectures.where((l) => l.enfantId == enfantId && cetteSemaine(l.lueLe)).length,
    exercicesFaits: semaine.length,
    reussis: semaine.where((r) => r.reussi).length,
  );
}

/// Un exercice fait, avec ce qu'il faut pour l'afficher.
@immutable
class ExerciceFait {
  const ExerciceFait({required this.resultat, required this.lecon, required this.exercice});

  final ResultatExercice resultat;
  final Lecon lecon;
  final Exercice exercice;
}

/// Les [nombre] derniers exercices de l'enfant, du plus récent au plus
/// ancien. Un exercice qui n'est plus publié (introuvable dans les leçons)
/// est sauté : on ne saurait pas quoi en afficher.
List<ExerciceFait> derniersExercices({
  required int enfantId,
  required List<ResultatExercice> resultats,
  required List<Lecon> lecons,
  int nombre = 5,
}) {
  final index = <int, (Lecon, Exercice)>{
    for (final l in lecons)
      for (final e in l.exercices) e.id: (l, e),
  };
  final tries = [for (final r in resultats) if (r.enfantId == enfantId) r]
    ..sort((a, b) => b.faitLe.compareTo(a.faitLe));
  return [
    for (final r in tries)
      if (index[r.exerciceId] case (final lecon, final exercice))
        ExerciceFait(resultat: r, lecon: lecon, exercice: exercice),
  ].take(nombre).toList();
}

/// Dernière leçon lue par l'enfant [enfantId] qui a des notions « À
/// retenir » (de quoi le faire réciter, D35) ; `null` s'il n'y en a pas.
///
/// Une leçon qui n'est plus publiée (absente de [lecons]) est sautée, comme
/// dans [derniersExercices].
Lecon? derniereLeconARetenir({
  required int enfantId,
  required List<LectureLecon> lectures,
  required List<Lecon> lecons,
}) {
  final parId = {for (final l in lecons) l.id: l};
  final tries = [for (final l in lectures) if (l.enfantId == enfantId) l]
    ..sort((a, b) => b.lueLe.compareTo(a.lueLe));
  for (final lecture in tries) {
    final lecon = parId[lecture.leconId];
    if (lecon != null && lecon.aRetenir.isNotEmpty) return lecon;
  }
  return null;
}

/// Score affiché en face d'un exercice. Toujours en mots : la réussite n'est
/// jamais signalée par la couleur seule (DESIGN.md).
String libelleScore(ResultatExercice r) {
  if (r.autoEvaluation) return r.reussi ? 'Juste, selon l’enfant' : 'À revoir, selon l’enfant';
  return '${r.bonnes} sur ${r.total}';
}

/// Leçons publiées de la classe [libelleClasse], rangées par matière puis
/// dans l'ordre du programme.
List<Lecon> leconsDeClasse(List<Lecon> lecons, String libelleClasse) {
  return [for (final l in lecons) if (l.contexte?.classe == libelleClasse) l]..sort((a, b) {
      final matiere = (a.contexte?.matiere ?? '').compareTo(b.contexte?.matiere ?? '');
      if (matiere != 0) return matiere;
      final chapitre = a.chapitreId.compareTo(b.chapitreId);
      return chapitre != 0 ? chapitre : a.numero.compareTo(b.numero);
    });
}

String libelleExercices(int n) => n == 1 ? '1 exercice' : '$n exercices';

/// « 7 leçons et 34 exercices pour l’instant. »
String resumeDisponibles(List<Lecon> lecons) {
  if (lecons.isEmpty) return 'Pas encore de leçon publiée.';
  final nbExercices = lecons.fold<int>(0, (s, l) => s + l.exercices.length);
  final nbLecons = lecons.length == 1 ? '1 leçon' : '${lecons.length} leçons';
  return '$nbLecons et ${libelleExercices(nbExercices)} pour l’instant.';
}
