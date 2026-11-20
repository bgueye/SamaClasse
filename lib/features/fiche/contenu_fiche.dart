// Contenu de la « Fiche à imprimer » d'une leçon (D35, maquettes `Fiche` et
// `FicheCorrige`), sans rien savoir du PDF : une suite de blocs simples,
// testée seule (test/features/fiche_test.dart). `fiche_pdf.dart` les dessine.
//
// Pensée pour la photocopie : du texte, des cases et des lignes, rien qui
// dépende de la couleur. Les schémas (images en ligne) ne sont pas
// imprimés : leur description renvoie à l'application.

import 'package:flutter/foundation.dart';

import '../../data/data.dart';
import '../exercices/outils_exercices.dart';

/// Un bloc de la fiche.
@immutable
sealed class BlocFiche {
  const BlocFiche();
}

/// Une ligne de texte (paragraphe, question numérotée, puce « • »).
class TexteFiche extends BlocFiche {
  const TexteFiche(this.texte);
  final String texte;

  @override
  bool operator ==(Object other) => other is TexteFiche && other.texte == texte;
  @override
  int get hashCode => texte.hashCode;
  @override
  String toString() => 'TexteFiche($texte)';
}

/// Un tableau Markdown de l'énoncé : la première ligne est l'en-tête ; les
/// cases vides restent à remplir à la main.
class TableauFiche extends BlocFiche {
  const TableauFiche(this.lignes);
  final List<List<String>> lignes;
}

/// Schéma de l'énoncé, non imprimé : sa description seulement.
class SchemaFiche extends BlocFiche {
  const SchemaFiche(this.description);
  final String description;
}

/// Lignes vides pour écrire la réponse.
class LignesFiche extends BlocFiche {
  const LignesFiche(this.nombre);
  final int nombre;

  @override
  bool operator ==(Object other) => other is LignesFiche && other.nombre == nombre;
  @override
  int get hashCode => nombre.hashCode;
  @override
  String toString() => 'LignesFiche($nombre)';
}

/// Une question de QCM : une case à cocher par choix.
class ChoixFiche extends BlocFiche {
  const ChoixFiche(this.question, this.choix);
  final String question;
  final List<String> choix;
}

/// Affirmations avec une case « V » et une case « F » chacune.
class VraiFauxFiche extends BlocFiche {
  const VraiFauxFiche(this.affirmations);
  final List<String> affirmations;
}

/// Deux colonnes à relier : chiffres à gauche, lettres à droite.
class RelierFiche extends BlocFiche {
  const RelierFiche(this.gauche, this.droite);
  final List<String> gauche;
  final List<String> droite;
}

/// Un libellé suivi d'une ligne à remplir, par valeur attendue.
class ChampsFiche extends BlocFiche {
  const ChampsFiche(this.libelles);
  final List<String> libelles;
}

/// Éléments à classer, puis une ligne par catégorie.
class ClassementFiche extends BlocFiche {
  const ClassementFiche(this.elements, this.categories);
  final List<String> elements;
  final List<String> categories;
}

/// Un exercice de la fiche : énoncé, zone de réponse, et ce qui va dans le
/// corrigé.
@immutable
class ExerciceFiche {
  const ExerciceFiche({
    required this.numero,
    required this.niveau,
    required this.enonce,
    required this.reponse,
    required this.corrige,
  });

  final int numero;
  final String niveau;
  final List<BlocFiche> enonce;
  final List<BlocFiche> reponse;
  final List<BlocFiche> corrige;
}

/// Toute la fiche d'une leçon.
@immutable
class ContenuFiche {
  const ContenuFiche({
    required this.titre,
    required this.surTitre,
    required this.retenir,
    required this.exercices,
    required this.lien,
  });

  final String titre;

  /// « Histoire, 4ème · Leçon 1 ».
  final String surTitre;
  final List<ElementARetenir> retenir;
  final List<ExerciceFiche> exercices;

  /// Adresse de la leçon sur le site, imprimée en bas de page.
  final String lien;
}

/// Adresse publique d'une leçon (web : adresses sans « # », D35).
String lienLecon(int leconId) => 'https://samaclasse.app/lecon/$leconId';

/// Nom du document proposé à l'enregistrement : « Fiche - L'Afrique au XVIe siècle ».
String nomFiche(Lecon lecon) => 'Fiche - ${lecon.titre}';

/// La fiche complète de [lecon].
ContenuFiche contenuFiche(Lecon lecon) {
  final c = lecon.contexte;
  final surTitre = [
    if (c != null) '${c.matiere}, ${c.classe}',
    'Leçon ${lecon.numero}',
  ].join(' · ');
  return ContenuFiche(
    titre: lecon.titre,
    surTitre: surTitre,
    retenir: lecon.aRetenir,
    exercices: [
      for (final (i, e) in lecon.exercices.indexed)
        ExerciceFiche(
          numero: i + 1,
          niveau: e.niveau.libelle,
          enonce: blocsDepuisMarkdown(e.enonce),
          reponse: zoneReponse(e),
          corrige: corrigeFiche(e),
        ),
    ],
    lien: lienLecon(lecon.id),
  );
}

final _image = RegExp(r'!\[([^\]]*)\]\([^)]*\)');
final _lien = RegExp(r'\[([^\]]+)\]\([^)]*\)');
final _numero = RegExp(r'^\d+[.)]\s');

/// Texte sans les marques Markdown en ligne (gras, italique, code, liens).
String sansMarques(String texte) => texte
    .replaceAllMapped(_lien, (m) => m[1]!)
    .replaceAll('**', '')
    .replaceAll('__', '')
    .replaceAll('`', '')
    // Italique *mot* : seulement une étoile collée à un mot, pour garder les
    // multiplications « 3 * 4 » éventuelles.
    .replaceAllMapped(RegExp(r'\*(\S(?:[^*]*\S)?)\*'), (m) => m[1]!)
    .trim();

/// Blocs d'un texte Markdown d'énoncé ou de corrigé : lignes de texte,
/// tableaux, schémas. Les titres perdent leurs « # », les puces deviennent
/// « • », les lignes vides séparent seulement.
List<BlocFiche> blocsDepuisMarkdown(String? markdown) {
  if (markdown == null || markdown.trim().isEmpty) return const [];
  final blocs = <BlocFiche>[];
  List<List<String>>? tableau;

  void fermerTableau() {
    if (tableau != null && tableau!.isNotEmpty) blocs.add(TableauFiche(tableau!));
    tableau = null;
  }

  for (final brute in markdown.split('\n')) {
    final ligne = brute.trim();
    if (ligne.startsWith('|')) {
      final cases = ligne.substring(1, ligne.endsWith('|') ? ligne.length - 1 : ligne.length).split('|');
      // Ligne de séparation « | --- | :---: | » : rien à imprimer.
      if (cases.every((c) => RegExp(r'^\s*:?-{2,}:?\s*$').hasMatch(c))) continue;
      (tableau ??= []).add([for (final c in cases) sansMarques(c)]);
      continue;
    }
    fermerTableau();
    if (ligne.isEmpty) continue;
    final image = _image.firstMatch(ligne);
    if (image != null) {
      blocs.add(SchemaFiche(image[1]!.trim()));
      final reste = sansMarques(ligne.replaceAll(_image, ''));
      if (reste.isNotEmpty) blocs.add(TexteFiche(reste));
      continue;
    }
    var texte = ligne.replaceFirst(RegExp(r'^#+\s*'), '');
    texte = texte.replaceFirst(RegExp(r'^[-*+]\s+'), '• ');
    texte = sansMarques(texte);
    if (texte.isNotEmpty) blocs.add(TexteFiche(texte));
  }
  fermerTableau();
  return blocs;
}

/// Nombre de questions numérotées (« 1. », « 2) ») d'un énoncé.
int questionsNumerotees(String enonce) =>
    enonce.split('\n').where((l) => _numero.hasMatch(sansMarques(l.trim()))).length;

/// Zone de réponse imprimée sous l'énoncé, selon le type d'exercice
/// (formats dans EXERCICES.md).
List<BlocFiche> zoneReponse(Exercice e) {
  final donnees = e.donnees;
  final reponse = e.reponse;
  final enonceATableau = blocsDepuisMarkdown(e.enonce).any((b) => b is TableauFiche);
  switch (e.type) {
    case TypeExercice.qcm:
      final questions = donnees is Map && donnees['questions'] is List ? donnees['questions'] as List : const [];
      return [
        for (final q in questions.whereType<Map>())
          ChoixFiche(sansMarques('${q['q'] ?? ''}'), [for (final c in (q['choix'] as List? ?? const [])) sansMarques('$c')]),
      ];
    case TypeExercice.vraiFaux:
      final affirmations = donnees is Map && donnees['affirmations'] is List ? donnees['affirmations'] as List : const [];
      return [
        VraiFauxFiche([for (final a in affirmations) sansMarques('$a')]),
        // « Si c'est faux, corrige la phrase » : de la place pour corriger.
        if (e.enonce.toLowerCase().contains('corrige')) ...const [TexteFiche('Corrections :'), LignesFiche(2)],
      ];
    case TypeExercice.relier:
      if (reponse is! Map) return const [LignesFiche(4)];
      final droite = donnees is Map && donnees['droite'] is List
          ? List<String>.from(donnees['droite'] as List)
          : reponse.values.map((v) => '$v').toList();
      return [RelierFiche(ordreGauche(reponse, donnees), droite)];
    case TypeExercice.tableau:
      // Le tableau de l'énoncé, imprimé avec ses cases vides, suffit.
      if (enonceATableau) return const [];
      if (reponse is List) return [ChampsFiche([for (var i = 1; i <= reponse.length; i++) '$i.'])];
      if (reponse is Map && reponse.values.every((v) => v is List)) {
        return [ClassementFiche(elementsAClasser(reponse), [for (final c in categoriesDuClassement(e)) c.libelle])];
      }
      return const [LignesFiche(6)];
    case TypeExercice.calcul:
      final chemins = cheminsAttendus(e);
      return chemins.isEmpty ? const [LignesFiche(4)] : [ChampsFiche([for (final c in chemins) libelleChemin(c)])];
    case TypeExercice.questionCours:
      final n = questionsNumerotees(e.enonce);
      return [LignesFiche(n == 0 ? 4 : (n * 2).clamp(2, 16))];
    case TypeExercice.redaction:
      return const [LignesFiche(8)];
    case TypeExercice.epreuve:
      return const [LignesFiche(10)];
    case TypeExercice.documents:
    case TypeExercice.experience:
      return const [LignesFiche(6)];
  }
}

/// Ce que le corrigé imprime pour [e] : son corrigé rédigé, sinon la réponse
/// attendue mise en mots.
List<BlocFiche> corrigeFiche(Exercice e) {
  final redige = blocsDepuisMarkdown(e.corrige);
  if (redige.isNotEmpty) return redige;
  final r = e.reponse;
  return switch (e.type) {
    TypeExercice.qcm when r is List => _corrigeQcm(e, r),
    TypeExercice.vraiFaux when r is List => [
        for (final (i, v) in r.indexed) TexteFiche('${i + 1}. ${v == true ? 'Vrai' : 'Faux'}'),
      ],
    TypeExercice.relier when r is Map => [
        for (final g in ordreGauche(r, e.donnees)) TexteFiche('$g → ${r[g] ?? ''}'),
      ],
    TypeExercice.calcul when r is Map => [
        for (final MapEntry(:key, :value) in valeursAttendues(e).entries)
          TexteFiche('${libelleChemin(key)} : ${formaterValeur(value)}'),
      ],
    TypeExercice.tableau when r is List => [
        for (final (i, v) in r.indexed) TexteFiche('${i + 1}. ${formaterValeur(v)}'),
      ],
    TypeExercice.tableau when r is Map && r.values.every((v) => v is List) => [
        for (final c in categoriesDuClassement(e)) TexteFiche('${c.libelle} : ${(r[c.cle] as List).join(', ')}'),
      ],
    _ => const [TexteFiche('Correction libre : voir avec l’enseignant.')],
  };
}

List<BlocFiche> _corrigeQcm(Exercice e, List r) {
  final donnees = e.donnees;
  final questions = donnees is Map && donnees['questions'] is List ? donnees['questions'] as List : const [];
  return [
    for (final (i, indice) in r.indexed)
      if (i < questions.length && questions[i] is Map && indice is int && indice < ((questions[i] as Map)['choix'] as List).length)
        TexteFiche('${i + 1}. ${sansMarques('${((questions[i] as Map)['choix'] as List)[indice]}')}')
      else
        TexteFiche('${i + 1}. ${formaterValeur(indice)}'),
  ];
}
