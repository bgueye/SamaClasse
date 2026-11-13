import '../../data/models.dart';

/// Une partie du programme et ses chapitres, dans l'ordre.
class PartieDeChapitres {
  PartieDeChapitres(this.titre, this.chapitres);

  /// `null` quand les chapitres n'ont pas de partie dans la base.
  final String? titre;
  final List<Chapitre> chapitres;
}

/// Regroupe les chapitres (déjà triés par numéro) par partie consécutive.
/// Deux blocs séparés de la même partie restent deux groupes : l'ordre du
/// programme prime.
List<PartieDeChapitres> regrouperParPartie(Iterable<Chapitre> chapitres) {
  final parties = <PartieDeChapitres>[];
  for (final c in chapitres) {
    if (parties.isNotEmpty && parties.last.titre == c.partie) {
      parties.last.chapitres.add(c);
    } else {
      parties.add(PartieDeChapitres(c.partie, [c]));
    }
  }
  return parties;
}

/// Texte d'état d'un chapitre : « Leçon prête, 5 exercices ».
String etatChapitre(Chapitre c) {
  if (!c.aUneLecon) return 'Leçon pas encore disponible';
  final lecons = c.lecons.length == 1 ? 'Leçon prête' : '${c.lecons.length} leçons prêtes';
  final nbExercices = c.lecons.fold<int?>(0, (somme, l) {
    if (somme == null || l.nbExercices == null) return null;
    return somme + l.nbExercices!;
  });
  if (nbExercices == null || nbExercices == 0) return lecons;
  return '$lecons, $nbExercices exercice${nbExercices > 1 ? 's' : ''}';
}
