import 'package:flutter/painting.dart';

/// Palette « cahier d'écolier » des maquettes SamaClasse.
abstract final class Couleurs {
  // Encre et papier
  static const encre = Color(0xFF2140C9);
  static const encreFoncee = Color(0xFF16309A);
  static const papier = Color(0xFFFFFFFF);
  static const fond = Color(0xFFF7F8FC);
  static const marge = Color(0xFFD62839);

  // Textes (contraste ≥ 4,5:1 sur le fond)
  static const texte = Color(0xFF121A33);
  static const texteDoux = Color(0xFF3D465C);
  static const texteSecondaire = Color(0xFF5B6478);
  static const texteAttente = Color(0xFF8A93A8);
  static const etiquette = Color(0xFFA84F08);

  // Texte posé sur un fond `encre` (bouton principal, puce sélectionnée).
  // Distinct de `papier` : même valeur aujourd'hui, mais un rôle différent
  // (le fond d'une page n'est pas la couleur d'un texte). Contraste ≈ 7,6:1
  // sur `encre`, donc au-dessus du seuil de 4,5:1.
  static const texteSurEncre = Color(0xFFFFFFFF);

  // Traits
  static const bordure = Color(0xFFE3E7F3);
  static const bordureCarte = Color(0xFFDCE2F3);
  static const bordureForte = Color(0xFFC9D3EE);
  static const segment = Color(0xFFE8ECF8);
  static const selection = Color(0xFFEEF1FA);

  // Lignes Seyès
  static const ligneSeyes = Color(0xFFCBD5EF);
  static const ligneSeyesFine = Color(0xFFEEF1FA);

  // Retours de correction
  static const juste = Color(0xFF0F6B52);
  static const justeFond = Color(0xFFE3F4EE);
  static const justeTexte = Color(0xFF0B3D30);
  static const faux = Color(0xFFB3192B);
  static const fauxFond = Color(0xFFFBE7E9);
  static const fauxTexte = Color(0xFF4A0C14);
}
