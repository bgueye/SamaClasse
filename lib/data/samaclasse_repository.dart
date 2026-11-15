// Accès aux données SamaClasse, tel que les écrans le voient.
//
// Lecture seule : les élèves et les parents lisent le programme et les
// leçons publiées. Les règles RLS de la base masquent automatiquement les
// leçons au statut « brouillon » ou « à vérifier ».
//
// Ce fichier ne définit que le contrat. Dans l'application, il est rempli par
// `ContenuHorsLigne` (copie locale de tout le contenu publié, synchronisée
// avec Supabase, décision D16) ; dans les tests, par `FauxDepot`. Les écrans
// n'ont pas à savoir d'où viennent les données.

import 'package:flutter/foundation.dart';

import 'models.dart';

abstract interface class SamaClasseRepository {
  /// Toutes les classes, dans l'ordre du cursus.
  Future<List<Classe>> classes();

  /// Les matières d'une classe, avec le nombre de chapitres et de leçons publiées.
  Future<List<MatiereDeClasse>> matieres(int classeId);

  /// Les chapitres d'une matière dans une classe, dans l'ordre du programme,
  /// chacun avec ses leçons publiées et leur nombre d'exercices.
  Future<List<Chapitre>> chapitres({required int classeId, required int matiereId});

  /// Une leçon complète avec ses exercices, ou `null` si elle n'existe pas
  /// ou n'est pas encore publiée.
  Future<Lecon?> lecon(int id);

  /// Toutes les leçons publiées, complètes (contexte et exercices). Sert au
  /// suivi des parents : retrouver la leçon et le type d'un exercice fait,
  /// lister les leçons disponibles d'une classe. Lu dans la copie locale :
  /// une dizaine de leçons aujourd'hui, à revoir si le contenu grossit beaucoup.
  Future<List<Lecon>> lecons();

  /// État de la synchronisation : sert au bandeau « Hors connexion » et à
  /// recharger les écrans quand du contenu nouveau arrive.
  ValueListenable<EtatContenu> get etat;

  /// Demande une mise à jour depuis le serveur (tirer pour actualiser).
  /// Ne lève pas d'erreur : sans réseau, la copie locale reste affichée et
  /// [etat] passe « hors connexion ».
  Future<void> actualiser();
}

/// Où en est le contenu affiché.
@immutable
class EtatContenu {
  const EtatContenu({this.horsConnexion = false, this.copieDu, this.version = 0});

  /// Vrai quand la dernière tentative de mise à jour a échoué et que
  /// l'application affiche sa copie locale.
  final bool horsConnexion;

  /// Date du téléchargement de la copie affichée (null tant qu'il n'y en a pas).
  final DateTime? copieDu;

  /// Augmente chaque fois qu'une mise à jour apporte un contenu **différent**
  /// de celui déjà affiché : les écrans ouverts se rechargent alors.
  final int version;

  EtatContenu copyWith({bool? horsConnexion, DateTime? copieDu, int? version}) => EtatContenu(
        horsConnexion: horsConnexion ?? this.horsConnexion,
        copieDu: copieDu ?? this.copieDu,
        version: version ?? this.version,
      );

  @override
  bool operator ==(Object other) =>
      other is EtatContenu &&
      other.horsConnexion == horsConnexion &&
      other.copieDu == copieDu &&
      other.version == version;

  @override
  int get hashCode => Object.hash(horsConnexion, copieDu, version);
}
