// Logique pure de l'écran « Schémas de la leçon » (rédacteurs, phase 5),
// testée seule (test/features/schemas_test.dart).
//
// Écran interne aux rédacteurs : tutoiement, comme « Leçons à vérifier ».

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException, StorageException;

import '../../core/services/reduction_image.dart';
import '../validation/outils_validation.dart' show messageErreurRedaction;

/// Séparateur de paragraphes : une ligne vide (éventuellement faite
/// d'espaces). **Exactement la même règle que `ajouter_schema`** en base
/// (`\n[ \t]*\n`) : le numéro de paragraphe choisi dans l'écran doit désigner
/// le même endroit côté serveur.
final separateurParagraphes = RegExp(r'\n[ \t]*\n');

/// Paragraphes d'un texte de leçon, dans l'ordre. Un texte vide n'en a
/// aucun. Les paragraphes vides (plusieurs lignes vides de suite) sont
/// gardés, pour que la numérotation reste celle du serveur ; l'écran ne les
/// propose simplement pas comme repère.
List<String> decouperParagraphes(String? texte) {
  if (texte == null || texte.trim().isEmpty) return const [];
  return texte.split(separateurParagraphes);
}

final _image = RegExp(r'^!\[([^\]]*)\]\([^)]*\)$');
final _marquesDebut = RegExp(r'^(\s*(#{1,6}|[-*+>]|\d+[.)]|\|)\s*)+');
final _emphase = RegExp(r'(\*\*|__|\*|_|`)');
final _espaces = RegExp(r'\s+');

/// Longueur maximale d'un aperçu de paragraphe.
const longueurApercu = 140;

/// Aperçu d'un paragraphe pour choisir où insérer un schéma : texte sans
/// marques Markdown, sur une ligne, coupé à [longueurApercu] caractères.
/// Une image existante s'affiche « Schéma : sa description ».
String apercuParagraphe(String paragraphe) {
  final p = paragraphe.trim();
  final image = _image.firstMatch(p);
  if (image != null) return 'Schéma : ${image.group(1)!.trim()}';
  final lignes = [
    for (final ligne in p.split('\n'))
      // Ligne de séparation d'un tableau (| --- | --- |) : sans intérêt.
      if (!RegExp(r'^\s*\|?[\s:|-]+\|?\s*$').hasMatch(ligne)) ligne.replaceFirst(_marquesDebut, ''),
  ];
  final texte = lignes.join(' ').replaceAll(_emphase, '').replaceAll('|', ' ').replaceAll(_espaces, ' ').trim();
  if (texte.runes.length <= longueurApercu) return texte;
  return '${String.fromCharCodes(texte.runes.take(longueurApercu - 1)).trimRight()}…';
}

/// Repère proposé dans l'écran : insérer après [apres] paragraphes
/// (0 : au début).
typedef Repere = ({int apres, String apercu});

/// Repères proposés pour insérer un schéma dans un texte : « au début »,
/// puis après chaque paragraphe non vide. Le dernier repère est « à la
/// fin ».
List<Repere> reperes(String? texte) {
  final paragraphes = decouperParagraphes(texte);
  return [
    (apres: 0, apercu: ''),
    for (var i = 0; i < paragraphes.length; i++)
      if (paragraphes[i].trim().isNotEmpty) (apres: i + 1, apercu: apercuParagraphe(paragraphes[i])),
  ];
}

/// Longueurs permises pour la description (contrainte de `schemas_lecons`).
const longueurMinDescription = 3;
const longueurMaxDescription = 300;

/// Description sans espaces superflus (une seule ligne).
String nettoyerDescription(String saisie) => saisie.replaceAll(_espaces, ' ').trim();

/// Message d'erreur du champ « Description », ou `null` si elle convient.
/// Mêmes règles que `ajouter_schema`.
String? erreurDescription(String saisie) {
  final d = nettoyerDescription(saisie);
  if (d.isEmpty) return 'Décris le schéma : c’est ce que lisent les élèves malvoyants, et ce qui s’affiche hors connexion.';
  if (d.runes.length < longueurMinDescription) return 'La description est trop courte.';
  if (d.runes.length > longueurMaxDescription) return 'La description ne doit pas dépasser $longueurMaxDescription caractères.';
  if (d.contains('[') || d.contains(']')) return 'Les crochets [ ] ne sont pas permis dans la description.';
  return null;
}

/// Vrai si `ajouter_schema` a refusé parce que le texte de la leçon a changé
/// depuis son affichage (code 40001) : l'écran propose de la recharger.
bool estTexteChange(Object erreur) => erreur is PostgrestException && erreur.code == '40001';

/// Message à afficher pour une erreur d'ajout ou de retrait de schéma
/// (tutoiement).
String messageErreurSchema(Object erreur) {
  if (erreur is ImageIllisible) {
    return 'Cette image est illisible. Choisis une photo au format JPEG ou PNG.';
  }
  if (erreur is ImageTropLourde) {
    return 'Impossible de réduire cette image sous 150 Ko. Recadre-la sur le schéma, puis recommence.';
  }
  if (erreur is StorageException) {
    return switch (erreur.statusCode) {
      '413' => 'L’image est trop lourde : 150 Ko au plus.',
      '415' => 'Ce format d’image n’est pas accepté (JPEG, PNG ou WebP).',
      '401' || '403' => 'Ton compte n’a pas (ou plus) les droits de rédacteur.',
      _ => 'L’envoi de l’image n’a pas abouti. Vérifie le réseau, puis réessaie.',
    };
  }
  if (erreur is PostgrestException) {
    switch (erreur.code) {
      case '40001':
        return 'La leçon a changé entre-temps. Recharge-la, puis recommence.';
      case '22023':
        // Refus expliqué en français par la fonction (description, chemin).
        return erreur.message;
      case '23505':
        return 'Cette image est déjà utilisée. Recommence l’ajout.';
      case 'P0002':
        return 'Ce schéma ou cette leçon n’existe plus. Recharge la page.';
    }
  }
  return messageErreurRedaction(erreur);
}

/// Phrase sous le titre de l'écran.
String resumeSchemas(int nombre, {required bool publiee}) {
  final combien = switch (nombre) {
    0 => 'Aucun schéma ajouté depuis l’application pour l’instant.',
    1 => '1 schéma ajouté depuis l’application.',
    _ => '$nombre schémas ajoutés depuis l’application.',
  };
  return publiee
      ? '$combien Leçon publiée : un schéma ajouté apparaît chez les élèves à leur prochaine mise à jour.'
      : '$combien Leçon pas encore publiée : les élèves verront ses schémas une fois publiée.';
}
