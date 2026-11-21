// Logique pure de l'écran « Leçons à vérifier » (phase 4), testée seule
// (test/features/validation_test.dart).
//
// Écran interne aux rédacteurs : tutoiement, comme sur la maquette.

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../data/data.dart';

/// Le point [point] de la leçon [leconId] (pas encore publiée) a-t-il été
/// levé ? Les points des corrections (D33) ne comptent pas ici.
PointLeve? pointLeve(List<PointLeve> leves, int leconId, String point) {
  for (final p in leves) {
    if (p.leconId == leconId && p.point == point && p.correctionId == null) return p;
  }
  return null;
}

/// Le point [point] de la correction [correctionId] a-t-il été levé ? Comme
/// dans `publier_correction` : seuls comptent les points de CETTE
/// correction, même si une ancienne avait un point au même texte.
PointLeve? pointLeveCorrection(List<PointLeve> leves, int correctionId, String point) {
  for (final p in leves) {
    if (p.correctionId == correctionId && p.point == point) return p;
  }
  return null;
}

/// Points de la correction qui restent à lever.
List<String> pointsRestantsCorrection(CorrectionLecon c, List<PointLeve> leves) =>
    [for (final p in c.points) if (pointLeveCorrection(leves, c.id, p) == null) p];

/// Longueurs permises pour la raison d'une correction (base : 3 à 500).
const longueurMinMotif = 3;
const longueurMaxMotif = 500;

/// Nombre maximal de points d'une correction (base : 20).
const nombreMaxPoints = 20;

/// Points saisis un par ligne : sans espaces superflus, sans ligne vide ni
/// doublon, dans l'ordre (la base fait de même).
List<String> decouperPoints(String saisie) {
  final vus = <String>{};
  return [
    for (final ligne in saisie.split('\n'))
      if (ligne.trim().isNotEmpty && vus.add(ligne.trim())) ligne.trim(),
  ];
}

/// Message d'erreur du champ « Ce qu'il faut corriger », ou `null`.
String? erreurMotif(String saisie) {
  final m = saisie.trim();
  if (m.runes.length < longueurMinMotif) return 'Explique en quelques mots ce qu’il faut corriger.';
  if (m.runes.length > longueurMaxMotif) return 'Pas plus de $longueurMaxMotif caractères.';
  return null;
}

/// Message d'erreur du champ « Points à vérifier », ou `null`.
String? erreurPoints(String saisie) {
  final points = decouperPoints(saisie);
  if (points.isEmpty) return 'Écris au moins un point à vérifier avec les cahiers (un par ligne).';
  if (points.length > nombreMaxPoints) return 'Pas plus de $nombreMaxPoints points.';
  if (points.any((p) => p.runes.length > 500)) return 'Un point ne doit pas dépasser 500 caractères.';
  return null;
}

/// « Corrigée le 16/11/2026 » ou « Texte pas encore corrigé ».
String etatTexteCorrection(CorrectionLecon c) {
  if (!c.texteCorrige) return 'Texte pas encore corrigé';
  final d = c.modifieeLe.toLocal();
  return 'Texte corrigé le ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Phrase sous « Corrections en cours ».
String resumeCorrections(int nombre) => switch (nombre) {
      1 => '1 leçon publiée est en correction. Elle reste en ligne telle quelle jusqu’à la publication de la correction.',
      _ => '$nombre leçons publiées sont en correction. Elles restent en ligne telles quelles jusqu’à la publication '
          'de leur correction.',
    };

/// « 4ème, SVT » pour une correction.
String libelleClasseMatiereCorrection(CorrectionLecon c) => '${c.classe}, ${c.matiere}';

/// Points de [lecon] qui restent à lever. La comparaison se fait sur le
/// texte, comme dans `publier_lecon` : un point dont le texte a changé dans
/// la leçon doit être relevé.
List<String> pointsRestants(LeconAVerifier lecon, List<PointLeve> leves) =>
    [for (final p in lecon.points) if (pointLeve(leves, lecon.id, p) == null) p];

/// Longueur maximale d'une réponse (contrainte de `points_leves.commentaire`).
const longueurMaxReponse = 500;

/// Le point est-il une question (« … figurent-elles dans le cahier ? ») ?
/// Une question appelle une réponse écrite pour être levée (décision de
/// Bocar du 15/11/2026) ; un simple constat se lève d'une coche.
bool estQuestion(String point) => point.trimRight().endsWith('?');

/// Réponse sans espaces superflus ; `null` si elle est vide.
String? nettoyerReponse(String saisie) {
  final r = saisie.trim();
  return r.isEmpty ? null : r;
}

/// Message d'erreur du champ « Ta réponse », ou `null` s'il est valable.
String? erreurReponse(String point, String saisie) {
  final r = saisie.trim();
  if (r.isEmpty && estQuestion(point)) return 'Écris ta réponse à cette question pour lever le point.';
  if (r.runes.length > longueurMaxReponse) return 'Ta réponse ne doit pas dépasser $longueurMaxReponse caractères.';
  return null;
}

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

// --- Signalements des lecteurs (D38) ---

/// Phrase sous « Signalements ».
String resumeSignalements(int nombre) => switch (nombre) {
      1 => '1 erreur signalée par un lecteur attend ta vérification.',
      _ => '$nombre erreurs signalées par des lecteurs attendent ta vérification.',
    };

/// « Exercice 3 · L'Afrique au XVIe siècle » ou « Leçon · … ». Le numéro est
/// l'ordre de l'exercice dans la leçon, celui que l'élève voit.
String libelleSignalement(Signalement s) => '${_ouSignalement(s) ?? 'Leçon'} · ${s.titreLecon}';

/// « Exercice 3 », « Exercice » (numéro inconnu), ou `null` pour la leçon.
String? _ouSignalement(Signalement s) {
  if (s.exerciceId == null) return null;
  final n = s.ordreExercice;
  return n == null ? 'Exercice' : 'Exercice $n';
}

/// « Reçu le 21/11/2026 à 20:15 » (heure du téléphone).
String recuLeSignalement(Signalement s) {
  final d = s.recuLe.toLocal();
  String deux(int n) => n.toString().padLeft(2, '0');
  return 'Reçu le ${deux(d.day)}/${deux(d.month)}/${d.year} à ${deux(d.hour)}:${deux(d.minute)}';
}

/// Raison proposée pour « Demander une correction » à partir d'un
/// signalement : le motif, l'exercice, puis la précision du lecteur.
/// Tronquée à [longueurMaxMotif] caractères (contrainte de la base).
String motifCorrectionDepuis(Signalement s) {
  final exercice = _ouSignalement(s);
  final ou = exercice == null ? '' : ' (${exercice.toLowerCase()})';
  final precision = s.precision == null ? '' : ' : « ${s.precision} »';
  final texte = 'Signalement d’un lecteur$ou, ${s.motif.libelle.toLowerCase()}$precision';
  final runes = texte.runes.toList();
  return runes.length <= longueurMaxMotif ? texte : '${String.fromCharCodes(runes.take(longueurMaxMotif - 1))}…';
}

/// Message à afficher pour une erreur de rédaction (tutoiement).
///
/// Les refus de `publier_lecon` (code P0001) ont déjà un message clair en
/// français (« Il reste 1 point(s) à vérifier. ») : on l'affiche tel quel.
String messageErreurRedaction(Object erreur) {
  if (erreur is PostgrestException) {
    switch (erreur.code) {
      case 'P0001':
      case '22023':
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
