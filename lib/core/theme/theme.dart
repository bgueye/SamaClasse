import 'package:flutter/material.dart';

import 'couleurs.dart';

const policeTexte = 'AtkinsonHyperlegibleNext';
const policeCahier = 'PlaywriteFRModerne';

/// Polices de secours (décision D17), essayées dans l'ordre pour chaque
/// caractère absent de la police principale : exposants (10⁻³), flèches,
/// grec, alphabet phonétique, puis symboles mathématiques (ℝ, ≈, ≤).
/// Embarquées pour ne dépendre ni de la police du téléphone ni, sur le web,
/// d'un téléchargement (hors connexion, ces caractères seraient des cases vides).
const policesSecours = ['NotoSansSecours', 'NotoSansMathSecours'];

/// Hauteur d'un interligne Seyès : le texte de leçon s'aligne sur ces lignes.
const interligne = 32.0;

/// Styles de texte récurrents.
abstract final class Styles {
  /// Titre écrit « à la main » (Playwrite FR Moderne).
  static TextStyle cahier({double taille = 23, Color couleur = Couleurs.encre, double? hauteurLigne}) =>
      TextStyle(
        fontFamily: policeCahier,
        fontSize: taille,
        color: couleur,
        height: hauteurLigne == null ? 1.5 : hauteurLigne / taille,
      );

  static const sectionTitre = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Couleurs.texteSecondaire,
  );

  static const secondaire = TextStyle(fontSize: 13, color: Couleurs.texteSecondaire);

  static const etiquette = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Couleurs.etiquette,
  );

  /// Texte courant posé sur les lignes Seyès.
  static const lecon = TextStyle(fontSize: 16, height: interligne / 16, color: Couleurs.texte);
}

ThemeData themeSamaClasse() {
  final schema = ColorScheme.fromSeed(
    seedColor: Couleurs.encre,
    primary: Couleurs.encre,
    onPrimary: Couleurs.texteSurEncre,
    surface: Couleurs.fond,
    onSurface: Couleurs.texte,
    error: Couleurs.faux,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    fontFamily: policeTexte,
    // Hérité par tous les textes, y compris ceux qui précisent leur police
    // (titres cursifs, boutons) : un TextStyle sans secours garde celui-ci.
    fontFamilyFallback: policesSecours,
    scaffoldBackgroundColor: Couleurs.fond,
  );
  final boutonForme = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  // Les boutons appliquent ce style tel quel, sans hériter du thème : les
  // polices de secours doivent y être répétées (vérifié par polices_test.dart).
  const boutonTexte = TextStyle(
    fontFamily: policeTexte,
    fontFamilyFallback: policesSecours,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Couleurs.texte, displayColor: Couleurs.texte),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: boutonForme,
        textStyle: boutonTexte,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: boutonForme,
        foregroundColor: Couleurs.encre,
        side: const BorderSide(color: Couleurs.encre, width: 1.5),
        textStyle: boutonTexte,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: Couleurs.encre,
        textStyle: boutonTexte.copyWith(fontSize: 15),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Couleurs.bordure, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Couleurs.papier,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Couleurs.bordureForte, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Couleurs.encre, width: 2),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      // La couleur est indispensable : ce style remplace celui de Material 3
      // (couleur comprise), et un texte sans couleur est peint en blanc.
      // C'était le défaut des puces « Avais-tu juste ? » (blanc sur blanc).
      // Une puce qui veut un autre texte (blanc sur encre) le précise elle-même.
      // Même chose pour les polices de secours, à répéter ici.
      labelStyle: const TextStyle(
        fontFamily: policeTexte,
        fontFamilyFallback: policesSecours,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Couleurs.texte,
      ),
      side: const BorderSide(color: Couleurs.bordureForte, width: 1.5),
    ),
  );
}
