// Contenu disponible hors connexion (décision D16).
//
// Principe : une copie de tout le contenu publié est gardée sur l'appareil.
// Les écrans lisent cette copie (affichage immédiat, même sans réseau) et
// une synchronisation la met à jour en arrière-plan :
//
//   lancement ──► lecture de la copie locale ──► synchronisation en arrière-plan
//                       │                              │
//                       ▼                              ▼
//              écrans affichés tout de suite   contenu différent ? version + 1
//                                              → les écrans ouverts se rechargent
//
// Sans copie (premier lancement), les écrans attendent la première
// synchronisation ; si elle échoue, ils affichent « Impossible de charger »
// et « Réessayer » relance une synchronisation.
//
// État partagé par `ValueNotifier` (piste prévue par D9), sans bibliothèque.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'copie_locale.dart';
import 'instantane.dart';
import 'models.dart';
import 'samaclasse_repository.dart';
import 'telechargement_supabase.dart';

class ContenuHorsLigne implements SamaClasseRepository {
  ContenuHorsLigne({
    required SourceContenu source,
    required StockageCopie stockage,
    DateTime Function()? horloge,
  })  : _source = source,
        _stockage = stockage,
        _horloge = horloge ?? DateTime.now;

  final SourceContenu _source;
  final StockageCopie _stockage;

  /// Remplaçable dans les tests, pour des dates connues.
  final DateTime Function() _horloge;

  final _etat = ValueNotifier(const EtatContenu());

  /// Copie affichée (null tant qu'aucune n'est disponible).
  CopieContenu? _copie;

  /// Empreinte du contenu affiché, pour savoir si une mise à jour change quelque chose.
  String? _empreinte;

  /// Lecture initiale de la copie locale, faite une seule fois.
  Future<void>? _demarrage;

  /// Synchronisation en cours : les appels simultanés la partagent.
  Future<void>? _synchroEnCours;

  @override
  ValueListenable<EtatContenu> get etat => _etat;

  /// Lit la copie locale puis, s'il y en a une, lance une synchronisation en
  /// arrière-plan. Appelé au démarrage de l'application (et sinon par la
  /// première lecture d'un écran). Peut être appelé plusieurs fois.
  Future<void> demarrer() => _demarrage ??= _lireCopieLocale();

  Future<void> _lireCopieLocale() async {
    final copie = await _stockage.lire();
    if (copie != null) {
      _afficher(copie);
      // La copie suffit pour afficher ; la mise à jour se fait à côté.
      // `ignore()` : sans réseau, l'échec est normal et déjà noté dans `etat`.
      _synchroniser().ignore();
    }
  }

  /// Télécharge tout le contenu publié, l'enregistre et l'affiche.
  /// Lève l'erreur réseau en cas d'échec (après avoir noté « hors connexion »).
  Future<void> _synchroniser() => _synchroEnCours ??= _telecharger().whenComplete(() => _synchroEnCours = null);

  Future<void> _telecharger() async {
    try {
      final contenu = await _source.telechargerTout();
      final copie = CopieContenu(contenu: contenu, telechargeeLe: _horloge());
      final avait = _copie != null;
      final change = _afficher(copie);
      await _stockage.ecrire(copie);
      _etat.value = _etat.value.copyWith(
        horsConnexion: false,
        copieDu: copie.telechargeeLe,
        // On ne prévient les écrans que si ce qu'ils affichent a changé :
        // au premier téléchargement, ils attendaient déjà ce contenu.
        version: avait && change ? _etat.value.version + 1 : null,
      );
    } catch (_) {
      // Avec une copie, on reste utilisable : seul le bandeau change.
      if (_copie != null) _etat.value = _etat.value.copyWith(horsConnexion: true);
      rethrow;
    }
  }

  /// Remplace la copie affichée. Renvoie vrai si le contenu a changé.
  bool _afficher(CopieContenu copie) {
    final empreinte = jsonEncode(copie.contenu.toJson());
    final change = empreinte != _empreinte;
    _copie = copie;
    _empreinte = empreinte;
    if (_etat.value.copieDu == null) {
      _etat.value = _etat.value.copyWith(copieDu: copie.telechargeeLe);
    }
    return change;
  }

  /// Le contenu à afficher : la copie si elle existe, sinon la première
  /// synchronisation (dont l'erreur remonte à l'écran).
  Future<Instantane> _contenu() async {
    await demarrer();
    if (_copie == null) await _synchroniser();
    return _copie!.contenu;
  }

  @override
  Future<void> actualiser() async {
    await demarrer();
    try {
      await _synchroniser();
    } catch (_) {
      // Déjà noté dans `etat` ; la copie reste affichée.
    }
  }

  @override
  Future<List<Classe>> classes() async => (await _contenu()).classes();

  @override
  Future<List<MatiereDeClasse>> matieres(int classeId) async => (await _contenu()).matieres(classeId);

  @override
  Future<List<Chapitre>> chapitres({required int classeId, required int matiereId}) async =>
      (await _contenu()).chapitres(classeId: classeId, matiereId: matiereId);

  @override
  Future<Lecon?> lecon(int id) async => (await _contenu()).lecon(id);

  @override
  Future<List<Lecon>> lecons() async => (await _contenu()).lecons();
}
