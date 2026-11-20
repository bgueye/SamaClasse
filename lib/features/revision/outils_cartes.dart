// Logique des cartes « Interroge-moi » (D35), hors des widgets pour être
// testée seule (test/features/cartes_test.dart).
//
// Les cartes sont les notions « À retenir » d'une leçon : la notion au recto,
// l'essentiel au verso. Rien n'est gardé d'une séance à l'autre : la
// révision espacée (les cartes ratées qui reviennent quelques jours plus
// tard) viendra plus tard.

import 'package:flutter/foundation.dart';

import '../../data/data.dart';

/// Qui utilise l'écran : l'élève seul, ou un adulte qui le fait réciter.
enum ModeCartes {
  eleve,
  parent;

  /// Valeur du paramètre d'adresse `?mode=` (`parent`, sinon élève).
  static ModeCartes depuisAdresse(String? valeur) => valeur == 'parent' ? parent : eleve;
}

/// Question lue par l'adulte en mode parent, tirée de la notion.
///
/// Forme fixe, avec la notion entre guillemets : impossible de deviner
/// l'article (« les dates », « le déclin ») à partir du seul libellé, et une
/// phrase un peu raide vaut mieux qu'une phrase fausse.
String questionParent(String notion) => 'Explique-moi : « ${notion.trim()} ».';

/// Une séance de cartes, immuable : chaque action renvoie la séance suivante.
///
/// [file] : indices (dans [cartes]) des cartes de ce tour, dans l'ordre ;
/// [position] : carte en cours dans [file] ; [aRevoir] : cartes ratées de ce
/// tour, dans l'ordre où elles ont été vues.
@immutable
class SeanceCartes {
  const SeanceCartes._({
    required this.cartes,
    required this.file,
    required this.position,
    required this.retournee,
    required this.sues,
    required this.aRevoir,
  });

  /// Première séance sur toutes les notions de la leçon, dans leur ordre.
  factory SeanceCartes.depuis(List<ElementARetenir> cartes) => SeanceCartes._(
        cartes: cartes,
        file: [for (var i = 0; i < cartes.length; i++) i],
        position: 0,
        retournee: false,
        sues: 0,
        aRevoir: const [],
      );

  final List<ElementARetenir> cartes;
  final List<int> file;
  final int position;
  final bool retournee;
  final int sues;
  final List<int> aRevoir;

  /// Aucune carte : la leçon n'a pas de notions « À retenir ».
  bool get vide => file.isEmpty;

  /// Toutes les cartes du tour ont reçu une réponse : place au bilan.
  bool get terminee => !vide && position >= file.length;

  /// Carte affichée ; à n'appeler que si la séance n'est ni vide ni terminée.
  ElementARetenir get carte => cartes[file[position]];

  /// « Carte 2 sur 5 » (ou « Question 2 sur 5 » en mode parent).
  String libellePosition(ModeCartes mode) =>
      '${mode == ModeCartes.parent ? 'Question' : 'Carte'} ${position + 1} sur ${file.length}';

  SeanceCartes _copie({int? position, bool? retournee, int? sues, List<int>? aRevoir, List<int>? file}) =>
      SeanceCartes._(
        cartes: cartes,
        file: file ?? this.file,
        position: position ?? this.position,
        retournee: retournee ?? this.retournee,
        sues: sues ?? this.sues,
        aRevoir: aRevoir ?? this.aRevoir,
      );

  /// Montre le verso (l'essentiel).
  SeanceCartes retourner() => terminee || vide ? this : _copie(retournee: true);

  /// Réponse à la carte en cours, puis carte suivante, recto visible.
  SeanceCartes repondre({required bool sue}) {
    if (terminee || vide) return this;
    return _copie(
      position: position + 1,
      retournee: false,
      sues: sues + (sue ? 1 : 0),
      aRevoir: sue ? aRevoir : [...aRevoir, file[position]],
    );
  }

  /// Nouveau tour avec les seules cartes ratées ; inchangé s'il n'y en a pas.
  SeanceCartes revoirRatees() => aRevoir.isEmpty
      ? this
      : _copie(file: aRevoir, position: 0, retournee: false, sues: 0, aRevoir: const []);

  /// Nouveau tour avec toutes les cartes.
  SeanceCartes recommencer() => SeanceCartes.depuis(cartes);
}
