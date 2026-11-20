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

/// Les chiffres de « Cette semaine ».
@immutable
class BilanSemaine {
  const BilanSemaine({
    required this.leconsLues,
    required this.exercicesFaits,
    required this.reussis,
    this.joursTravailles = 0,
  });

  final int leconsLues;
  final int exercicesFaits;
  final int reussis;

  /// Jours distincts (heure du téléphone) avec au moins une leçon lue ou un
  /// exercice fait depuis lundi (D35, résumé simple).
  final int joursTravailles;

  /// Part d'exercices réussis, arrondie ; `null` sans exercice (on affiche
  /// alors un tiret : « 0 % » laisserait croire à des échecs).
  int? get pourcentage => exercicesFaits == 0 ? null : (reussis * 100 / exercicesFaits).round();

  @override
  bool operator ==(Object other) =>
      other is BilanSemaine &&
      other.leconsLues == leconsLues &&
      other.exercicesFaits == exercicesFaits &&
      other.reussis == reussis &&
      other.joursTravailles == joursTravailles;

  @override
  int get hashCode => Object.hash(leconsLues, exercicesFaits, reussis, joursTravailles);

  @override
  String toString() => 'BilanSemaine($leconsLues lues, $reussis/$exercicesFaits, $joursTravailles jours)';
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
  final lues = [for (final l in lectures) if (l.enfantId == enfantId && cetteSemaine(l.lueLe)) l];
  DateTime jour(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  return BilanSemaine(
    leconsLues: lues.length,
    exercicesFaits: semaine.length,
    reussis: semaine.where((r) => r.reussi).length,
    // Une leçon relue ne garde que sa dernière date (une ligne par leçon) :
    // un jour de simple relecture peut manquer. Le chiffre reste un minimum.
    joursTravailles: {for (final l in lues) jour(l.lueLe), for (final r in semaine) jour(r.faitLe)}.length,
  );
}

// --- Résumé simple (D35, maquette `ResumeParent`) ---
//
// Phrases à la troisième personne, reprises telles quelles à l'écran (avec
// une majuscule), lues à voix haute et envoyées par « Envoyer ce résumé ».

String _pluriel(int n, String singulier, String pluriel) => n > 1 ? pluriel : singulier;

/// « a lu 3 leçons » ; « n’a pas encore lu de leçon ».
String phraseLecons(BilanSemaine b) => b.leconsLues == 0
    ? 'n’a pas encore lu de leçon'
    : 'a lu ${b.leconsLues} ${_pluriel(b.leconsLues, 'leçon', 'leçons')}';

/// « a réussi 8 exercices sur 10 » ; « n’a pas encore fait d’exercice ».
String phraseExercices(BilanSemaine b) => b.exercicesFaits == 0
    ? 'n’a pas encore fait d’exercice'
    : 'a réussi ${b.reussis} ${_pluriel(b.reussis, 'exercice', 'exercices')} sur ${b.exercicesFaits}';

/// « a travaillé 4 jours sur 7 » ; « n’a pas encore travaillé ».
String phraseJours(BilanSemaine b) => b.joursTravailles == 0
    ? 'n’a pas encore travaillé'
    : 'a travaillé ${b.joursTravailles} ${_pluriel(b.joursTravailles, 'jour', 'jours')} sur 7';

/// Première lettre en majuscule (« A lu 3 leçons »).
String majuscule(String texte) => texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);

/// Le résumé en une phrase : « Cette semaine, Awa a lu 3 leçons, a réussi
/// 8 exercices sur 10 et a travaillé 4 jours sur 7. »
String texteResume(String prenom, BilanSemaine b) {
  if (b.leconsLues == 0 && b.exercicesFaits == 0) {
    return 'Cette semaine, $prenom n’a pas encore travaillé dans SamaClasse.';
  }
  return 'Cette semaine, $prenom ${phraseLecons(b)}, ${phraseExercices(b)} et ${phraseJours(b)}.';
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
