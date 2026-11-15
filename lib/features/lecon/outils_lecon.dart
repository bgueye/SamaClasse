import 'dart:ui' show Size;

/// Hauteur d'écran en dessous de laquelle l'en-tête de la leçon passe sur une
/// seule ligne. Un téléphone en paysage fait 360 à 430 px de haut : l'en-tête
/// sur deux lignes (environ 125 px) y mangeait près d'un tiers de la page.
const hauteurEnteteCompacte = 520.0;

/// Largeur minimale pour mettre le lien de retour et les onglets côte à côte
/// sans tronquer les onglets (écran partagé étroit : on garde deux lignes).
const largeurEnteteCompacte = 600.0;

/// Vrai quand l'en-tête de la leçon doit tenir sur une seule ligne : écran
/// bas et assez large, c'est-à-dire un téléphone en paysage. Une tablette en
/// paysage (plus de 520 px de haut) garde l'en-tête habituel.
bool enteteCompacte(Size ecran) =>
    ecran.height < hauteurEnteteCompacte && ecran.width >= largeurEnteteCompacte;
