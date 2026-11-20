// Découpage d'une leçon en « diapositives » pour le mode projection (D35,
// maquette `Projection`), hors des widgets pour être testé seul
// (test/features/projection_test.dart).
//
// Une diapositive par partie du cours (titres « ## » du Markdown, comme
// « I – L'arrivée des Européens »), précédée d'une ouverture (titre,
// objectifs, introduction) et suivie de « À retenir ». Le texte reste celui
// de la leçon : rien n'est réécrit, seulement découpé.

import 'package:flutter/foundation.dart';

import '../../data/data.dart';

@immutable
class Diapositive {
  const Diapositive({required this.titre, required this.markdown});

  /// Titre affiché en cursive rouge (titre de partie).
  final String titre;

  /// Contenu Markdown, affiché par `MarkdownCahier`.
  final String markdown;

  @override
  bool operator ==(Object other) => other is Diapositive && other.titre == titre && other.markdown == markdown;

  @override
  int get hashCode => Object.hash(titre, markdown);

  @override
  String toString() => 'Diapositive($titre)';
}

final _titrePartie = RegExp(r'^##\s+(.+?)\s*$');

/// Les diapositives de [lecon], dans l'ordre de la leçon.
List<Diapositive> diapositives(Lecon lecon) {
  final resultat = <Diapositive>[];

  // Ouverture : objectifs et introduction, sous le titre de la leçon.
  final ouverture = [
    if (lecon.objectifs.isNotEmpty) ...[
      '**Ce que tu vas apprendre**',
      '',
      for (final o in lecon.objectifs) '- $o',
      '',
    ],
    if (lecon.introduction?.trim().isNotEmpty ?? false) lecon.introduction!.trim(),
  ].join('\n').trim();

  // Le corps, coupé à chaque titre « ## ». Ce qui précède le premier titre
  // rejoint l'ouverture.
  String? titre;
  final tampon = <String>[];
  final avantPremierTitre = <String>[];
  void fermer() {
    if (titre != null) resultat.add(Diapositive(titre: titre, markdown: tampon.join('\n').trim()));
    tampon.clear();
  }

  for (final ligne in (lecon.corps ?? '').split('\n')) {
    final m = _titrePartie.firstMatch(ligne);
    if (m != null) {
      fermer();
      titre = m[1]!;
    } else if (titre == null) {
      avantPremierTitre.add(ligne);
    } else {
      tampon.add(ligne);
    }
  }
  fermer();

  final debut = [ouverture, avantPremierTitre.join('\n').trim()].where((t) => t.isNotEmpty).join('\n\n');
  if (debut.isNotEmpty || resultat.isEmpty) {
    resultat.insert(0, Diapositive(titre: lecon.titre, markdown: debut));
  }

  if (lecon.aRetenir.isNotEmpty) {
    resultat.add(Diapositive(
      titre: 'À retenir',
      markdown: [for (final r in lecon.aRetenir) '**${r.notion}** : ${r.essentiel}'].join('\n\n'),
    ));
  }
  return resultat;
}

/// Facteur d'agrandissement du texte selon la largeur de l'écran : le texte
/// de base (16 px) passe à environ 34 px sur un écran de projection de
/// 1280 px, sans dépasser 2,4 ni descendre sous 1,2 (téléphone).
double agrandissementProjection(double largeur) => (largeur / 600).clamp(1.2, 2.4);
