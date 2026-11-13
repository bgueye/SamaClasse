// Outils des tests d'écrans : un faux dépôt Supabase, de fausses préférences
// et un lanceur d'application, pour tester les écrans sans réseau.
//
// Les données viennent de `test/fixtures/supabase.json` : réponses réelles de
// Supabase (clé publishable, rôle anon) relevées le 13/11/2026 avec les mêmes
// requêtes que `SamaClasseRepository`. Tester sur le vrai contenu publié fait
// apparaître les débordements que des textes inventés, plus courts, cachent.
// Pour rafraîchir ce fichier : relancer les requêtes de
// `docs/BASE_DE_DONNEES.md`, « Requêtes de l'application », sans
// `artefact_url` (donnée de rédaction, à ne pas mettre dans le dépôt).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/app.dart';
import 'package:samaclasse/core/app_scope.dart';
import 'package:samaclasse/core/services/preferences.dart';
import 'package:samaclasse/data/data.dart';

/// Les réponses Supabase enregistrées, lues une seule fois.
final Map<String, dynamic> donneesReelles =
    jsonDecode(File('test/fixtures/supabase.json').readAsStringSync()) as Map<String, dynamic>;

/// Dépôt sans réseau. `implements` plutôt qu'`extends` : on n'a pas besoin
/// d'un vrai `SupabaseClient`, seules les quatre requêtes publiques comptent.
class FauxDepot implements SamaClasseRepository {
  FauxDepot([Map<String, dynamic>? donnees]) : _donnees = donnees ?? donneesReelles;

  final Map<String, dynamic> _donnees;

  /// Nombre d'échecs à simuler par requête avant qu'elle réussisse
  /// (`{'classes': 1}` : la première demande de classes échoue, comme en
  /// mode avion, la suivante réussit, comme au retour du réseau).
  final pannes = <String, int>{};

  /// Si renseigné, chaque requête attend ce signal : sert à observer l'état
  /// de chargement, puis `attente.complete()` libère les réponses.
  Completer<void>? attente;

  /// Nombre d'appels par requête, pour vérifier qu'un « Réessayer » relance bien.
  final appels = <String, int>{};

  Future<T> _repondre<T>(String requete, T Function() reponse) async {
    appels[requete] = (appels[requete] ?? 0) + 1;
    if (attente != null) await attente!.future;
    final restantes = pannes[requete] ?? 0;
    if (restantes > 0) {
      pannes[requete] = restantes - 1;
      throw const SocketException('Pas de connexion (test)');
    }
    return reponse();
  }

  List<Map<String, dynamic>> _lignes(Object? v) =>
      ((v as List?) ?? const []).cast<Map<String, dynamic>>();

  @override
  Future<List<Classe>> classes() =>
      _repondre('classes', () => _lignes(_donnees['classes']).map(Classe.fromJson).toList());

  @override
  Future<List<MatiereDeClasse>> matieres(int classeId) => _repondre(
        'matieres',
        () => _lignes((_donnees['matieres'] as Map?)?['$classeId']).map(MatiereDeClasse.fromJson).toList(),
      );

  @override
  Future<List<Chapitre>> chapitres({required int classeId, required int matiereId}) => _repondre(
        'chapitres',
        () => _lignes((_donnees['chapitres'] as Map?)?['$classeId-$matiereId']).map(Chapitre.fromJson).toList(),
      );

  /// Comme la vraie requête (`maybeSingle`) : `null` pour une leçon absente
  /// ou non publiée.
  @override
  Future<Lecon?> lecon(int id) => _repondre('lecon', () {
        final ligne = (_donnees['lecons'] as Map?)?['$id'];
        return ligne == null ? null : Lecon.fromJson(ligne as Map<String, dynamic>);
      });
}

/// Préférences en mémoire (le vrai stockage demande une plateforme).
class FaussesPreferences implements Preferences {
  FaussesPreferences({this.classe, this.derniere});

  int? classe;
  DerniereLecon? derniere;

  @override
  Future<int?> classeChoisie() async => classe;

  @override
  Future<void> choisirClasse(int classeId) async => classe = classeId;

  @override
  Future<DerniereLecon?> derniereLecon() async => derniere;

  @override
  Future<void> memoriserLecon(DerniereLecon lecon) async => derniere = lecon;
}

/// Taille d'un téléphone courant (390 × 844, comme dans CLAUDE.md).
const tailleTelephone = Size(390, 844);

/// Navigateur web large.
const tailleWeb = Size(1280, 800);

/// Lance la vraie application sur [chemin], avec un faux dépôt.
///
/// [echelleTexte] simule la taille de texte système (2.0 = 200 %, exigé par
/// DESIGN.md). Un débordement (bandes jaunes et noires) fait échouer le test
/// tout seul : Flutter le signale comme une erreur pendant le test.
Future<void> lancerApp(
  WidgetTester tester, {
  required SamaClasseRepository depot,
  Preferences? preferences,
  String chemin = '/',
  Size taille = tailleTelephone,
  double echelleTexte = 1,
}) async {
  tester.view.physicalSize = taille * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = echelleTexte;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(AppScope(
    // Clé unique : si un test relance l'application, Flutter repart de zéro
    // au lieu de réutiliser l'ancien état (et l'ancien routeur).
    key: UniqueKey(),
    repository: depot,
    preferences: preferences ?? FaussesPreferences(),
    child: SamaClasseApp(emplacementInitial: chemin),
  ));
}
