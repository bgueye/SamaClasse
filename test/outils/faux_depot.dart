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
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/app.dart';
import 'package:samaclasse/core/app_scope.dart';
import 'package:samaclasse/core/services/choix_image.dart';
import 'package:samaclasse/core/services/preferences.dart';
import 'package:samaclasse/core/services/reduction_image.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/schemas/outils_schemas.dart' show separateurParagraphes;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException, PostgrestException;

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

  @override
  Future<List<Lecon>> lecons() => _repondre(
        'lecons',
        () => [for (final l in ((_donnees['lecons'] as Map?) ?? const {}).values) Lecon.fromJson(l as Map<String, dynamic>)],
      );

  /// Comme la vraie requête (`maybeSingle`) : `null` pour une leçon absente
  /// ou non publiée.
  @override
  Future<Lecon?> lecon(int id) => _repondre('lecon', () {
        final ligne = (_donnees['lecons'] as Map?)?['$id'];
        return ligne == null ? null : Lecon.fromJson(ligne as Map<String, dynamic>);
      });

  /// Toujours « en ligne » : ce faux dépôt teste les écrans, pas la
  /// synchronisation (voir FausseSource et ContenuHorsLigne pour celle-ci).
  @override
  final ValueNotifier<EtatContenu> etat = ValueNotifier(const EtatContenu());

  @override
  Future<void> actualiser() async {}
}

/// Le jeu enregistré (`test/fixtures/supabase.json`) mis à la forme des
/// quatre requêtes de synchronisation (listes à plat, `classe_id` et
/// `matiere_id` sur chaque chapitre), comme `TelechargementSupabase`.
Instantane instantaneReel([Map<String, dynamic>? donnees]) {
  final d = donnees ?? donneesReelles;
  List<Map<String, dynamic>> copie(Object? v) =>
      ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  return Instantane(
    classesBrutes: copie(d['classes']),
    matieresBrutes: [for (final v in ((d['matieres'] as Map?) ?? const {}).values) ...copie(v)],
    chapitresBruts: [
      for (final MapEntry(:key, :value) in ((d['chapitres'] as Map?) ?? const {}).entries)
        for (final c in copie(value))
          {
            ...c,
            'classe_id': int.parse((key as String).split('-')[0]),
            'matiere_id': int.parse(key.split('-')[1]),
          },
    ],
    leconsBrutes: copie(((d['lecons'] as Map?) ?? const {}).values.toList()),
  );
}

/// Serveur simulé pour ContenuHorsLigne : renvoie [contenu], peut tomber en
/// panne (`enPanne`) ou faire attendre sa réponse (`attente`).
class FausseSource implements SourceContenu {
  FausseSource([Instantane? contenu]) : contenu = contenu ?? instantaneReel();

  Instantane contenu;
  bool enPanne = false;
  Completer<void>? attente;
  int telechargements = 0;

  @override
  Future<Instantane> telechargerTout() async {
    telechargements++;
    if (attente != null) await attente!.future;
    if (enPanne) throw const SocketException('Pas de connexion (test)');
    return contenu;
  }
}

/// Stockage en mémoire pour ContenuHorsLigne. Passe par le vrai format
/// d'enregistrement (texte JSON), pour tester aussi l'aller-retour.
class FauxStockage implements StockageCopie {
  FauxStockage([this.texte]);

  /// Ce qui serait écrit sur l'appareil.
  String? texte;
  int ecritures = 0;

  @override
  Future<CopieContenu?> lire() async {
    if (texte == null) return null;
    try {
      return decoderCopie(texte!);
    } catch (_) {
      return null; // Comme CopieLocale : une copie illisible est ignorée.
    }
  }

  @override
  Future<void> ecrire(CopieContenu copie) async {
    ecritures++;
    texte = encoderCopie(copie);
  }
}

/// Préférences en mémoire (le vrai stockage demande une plateforme).
class FaussesPreferences implements Preferences {
  FaussesPreferences({this.classe, this.derniere, this.enfant});

  int? classe;
  DerniereLecon? derniere;
  EnfantActif? enfant;

  @override
  Future<EnfantActif?> enfantActif() async => enfant;

  @override
  Future<void> choisirEnfant(EnfantActif? e) async => enfant = e;

  @override
  Future<int?> classeChoisie() async => classe;

  @override
  Future<void> choisirClasse(int classeId) async => classe = classeId;

  @override
  Future<DerniereLecon?> derniereLecon() async => derniere;

  @override
  Future<void> memoriserLecon(DerniereLecon lecon) async => derniere = lecon;
}

/// Compte parent sans réseau : un seul code accepté ([codeValable]), profils
/// en mémoire. Reproduit les refus de la base (10 profils au plus).
class FauxCompte extends Compte {
  FauxCompte({
    String? connecte,
    List<Enfant>? enfants,
    List<LectureLecon>? lectures,
    List<ResultatExercice>? resultats,
  })  : _email = connecte,
        _enfants = [...?enfants],
        lecturesEnBase = [...?lectures],
        resultatsEnBase = [...?resultats];

  /// Ce que la base renverrait au parent connecté (déjà filtré par les RLS).
  final List<LectureLecon> lecturesEnBase;
  final List<ResultatExercice> resultatsEnBase;

  static const codeValable = '123456';

  String? _email;
  final List<Enfant> _enfants;
  var _prochainId = 100;

  /// Nombre d'échecs à simuler par opération (`{'enfants': 1}`), comme
  /// `FauxDepot.pannes`.
  final pannes = <String, int>{};

  /// Si renseigné, chaque opération attend ce signal (état de chargement).
  Completer<void>? attente;

  /// Adresses auxquelles un code a été « envoyé ».
  final codesEnvoyes = <String>[];

  List<Enfant> get profils => List.unmodifiable(_enfants);

  Future<void> _avant(String operation) async {
    if (attente != null) await attente!.future;
    final restantes = pannes[operation] ?? 0;
    if (restantes > 0) {
      pannes[operation] = restantes - 1;
      throw const SocketException('Pas de connexion (test)');
    }
  }

  @override
  String? get email => _email;

  @override
  Future<void> envoyerCode(String email) async {
    await _avant('envoyerCode');
    codesEnvoyes.add(email);
  }

  @override
  Future<void> verifierCode(String email, String code) async {
    await _avant('verifierCode');
    if (code != codeValable) {
      throw const AuthApiException('Token has expired or is invalid', statusCode: '403', code: 'otp_expired');
    }
    _email = email;
    notifyListeners();
  }

  @override
  Future<void> deconnecter() async {
    await _avant('deconnecter');
    _email = null;
    notifyListeners();
  }

  /// Vrai après `supprimerCompte()`.
  bool supprime = false;

  @override
  Future<void> supprimerCompte() async {
    await _avant('supprimerCompte');
    supprime = true;
    _enfants.clear();
    lecturesEnBase.clear();
    resultatsEnBase.clear();
    _email = null;
    notifyListeners();
  }

  @override
  Future<List<Enfant>> enfants() async {
    await _avant('enfants');
    return List.of(_enfants);
  }

  @override
  Future<Enfant> ajouterEnfant({required String prenom, required int classeId}) async {
    await _avant('ajouterEnfant');
    if (_enfants.length >= 10) {
      throw const PostgrestException(message: 'Nombre maximal de profils enfants atteint (10).', code: '23514');
    }
    final e = Enfant(id: _prochainId++, prenom: prenom, classeId: classeId);
    _enfants.add(e);
    return e;
  }

  @override
  Future<Enfant> modifierEnfant(Enfant enfant) async {
    await _avant('modifierEnfant');
    final i = _enfants.indexWhere((e) => e.id == enfant.id);
    if (i < 0) throw const PostgrestException(message: 'no rows', code: 'PGRST116');
    _enfants[i] = enfant;
    return enfant;
  }

  @override
  Future<void> supprimerEnfant(int id) async {
    await _avant('supprimerEnfant');
    _enfants.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<LectureLecon>> lectures() async {
    await _avant('lectures');
    return List.of(lecturesEnBase);
  }

  @override
  Future<List<ResultatExercice>> resultats({int limite = 500}) async {
    await _avant('resultats');
    final tries = [...resultatsEnBase]..sort((a, b) => b.faitLe.compareTo(a.faitLe));
    return tries.take(limite).toList();
  }
}

/// Envoi du suivi sans réseau : garde ce qui a été « reçu ». Peut simuler
/// une coupure ([enPanne]) ou un refus de la base pour certaines lignes
/// ([refuses], comme une règle RLS).
class FauxEnvoi implements EnvoiSuivi {
  final resultatsRecus = <ResultatExercice>[];
  final lecturesRecues = <LectureLecon>[];
  bool enPanne = false;

  /// Identifiants d'exercices que la base refuse (code 42501).
  final refuses = <int>{};

  int appels = 0;

  @override
  Future<void> envoyerResultats(List<ResultatExercice> resultats) async {
    appels++;
    if (enPanne) throw const SocketException('Pas de connexion (test)');
    if (resultats.any((r) => refuses.contains(r.exerciceId))) {
      throw const PostgrestException(message: 'new row violates row-level security policy', code: '42501');
    }
    // Comme `on conflict (id) do nothing` : un résultat déjà reçu est ignoré.
    for (final r in resultats) {
      if (!resultatsRecus.any((x) => x.id == r.id)) resultatsRecus.add(r);
    }
  }

  @override
  Future<void> envoyerLectures(List<LectureLecon> lectures) async {
    appels++;
    if (enPanne) throw const SocketException('Pas de connexion (test)');
    lecturesRecues.addAll(lectures);
  }
}

/// File d'envoi en mémoire (le vrai stockage demande une plateforme).
class FauxStockageFile implements StockageFile {
  String? texte;

  @override
  Future<String?> lire() async => texte;

  @override
  Future<void> ecrire(String t) async => texte = t;
}

/// Rédaction sans réseau : reproduit les règles de la base (rôle, point
/// réellement à vérifier, publication seulement si tout est levé).
class FausseRedaction implements Redaction {
  FausseRedaction({
    this.redacteur = false,
    List<LeconAVerifier>? lecons,
    List<PointLeve>? leves,
    Map<int, TexteLecon>? textes,
    List<SchemaLecon>? schemas,
  })  : lecons = [...?lecons],
        leves = [...?leves],
        textes = {...?textes},
        schemas = [...?schemas],
        fichiers = {for (final s in [...?schemas]) s.chemin};

  bool redacteur;
  final List<LeconAVerifier> lecons;
  final List<PointLeve> leves;
  final publiees = <int>[];
  var _prochainId = 1000;

  /// Échecs à simuler par opération, comme `FauxDepot.pannes`.
  final pannes = <String, int>{};

  Future<void> _avant(String operation) async {
    final restantes = pannes[operation] ?? 0;
    if (restantes > 0) {
      pannes[operation] = restantes - 1;
      throw const SocketException('Pas de connexion (test)');
    }
  }

  void _exigerRedacteur() {
    if (!redacteur) throw const PostgrestException(message: 'permission denied', code: '42501');
  }

  @override
  Future<bool> estRedacteur() async {
    await _avant('estRedacteur');
    return redacteur;
  }

  @override
  Future<List<LeconAVerifier>> leconsAVerifier() async {
    await _avant('lecons');
    _exigerRedacteur();
    return [for (final l in lecons) if (!publiees.contains(l.id)) l];
  }

  @override
  Future<List<PointLeve>> pointsLeves() async {
    await _avant('points');
    _exigerRedacteur();
    return List.of(leves);
  }

  @override
  Future<PointLeve> leverPoint({required int leconId, required String point, String? commentaire}) async {
    await _avant('lever');
    _exigerRedacteur();
    final lecon = lecons.firstWhere((l) => l.id == leconId);
    if (!lecon.points.contains(point) || publiees.contains(leconId)) {
      throw const PostgrestException(message: 'new row violates row-level security policy', code: '42501');
    }
    final p = PointLeve(id: _prochainId++, leconId: leconId, point: point, leveLe: DateTime.now(), commentaire: commentaire);
    leves.add(p);
    return p;
  }

  @override
  Future<void> annulerPoint(int id) async {
    await _avant('annuler');
    _exigerRedacteur();
    leves.removeWhere((p) => p.id == id);
  }

  @override
  Future<void> publier(int leconId) async {
    await _avant('publier');
    _exigerRedacteur();
    final lecon = lecons.firstWhere((l) => l.id == leconId);
    final restants = lecon.points.where((p) => !leves.any((x) => x.leconId == leconId && x.point == p)).length;
    if (restants > 0) {
      throw PostgrestException(message: 'Il reste $restants point(s) à vérifier.', code: 'P0001');
    }
    publiees.add(leconId);
  }

  // --- Schémas (phase 5) : imite `ajouter_schema` et `retirer_schema` ---

  /// Texte des leçons « en base ».
  final Map<int, TexteLecon> textes;
  final List<SchemaLecon> schemas;

  /// Fichiers présents dans l'espace `schemas`.
  final Set<String> fichiers;
  var _prochainFichier = 1;

  /// Fichiers supprimés (pour vérifier qu'aucun ne reste orphelin).
  final supprimes = <String>[];

  /// Erreur à renvoyer au prochain `ajouterSchema` (refus du serveur).
  Object? refusAjout;

  @override
  Future<TexteLecon?> texteLecon(int leconId) async {
    await _avant('texte');
    _exigerRedacteur();
    return textes[leconId];
  }

  @override
  Future<List<SchemaLecon>> schemasLecon(int leconId) async {
    await _avant('schemas');
    _exigerRedacteur();
    return [for (final s in schemas) if (s.leconId == leconId) s];
  }

  @override
  Future<String> deposerImage({required int leconId, required Uint8List octets, required String extension}) async {
    await _avant('deposer');
    _exigerRedacteur();
    final chemin = 'lecons/$leconId/fichier-${_prochainFichier++}.$extension';
    fichiers.add(chemin);
    return chemin;
  }

  @override
  Future<int> ajouterSchema({
    required int leconId,
    required ChampLecon champ,
    required int? apres,
    required String? texteAttendu,
    required String chemin,
    required String description,
  }) async {
    await _avant('ajouter');
    _exigerRedacteur();
    final refus = refusAjout;
    if (refus != null) {
      refusAjout = null;
      throw refus;
    }
    final t = textes[leconId]!;
    final actuel = t.texte(champ) ?? '';
    if (actuel != (texteAttendu ?? '')) {
      throw const PostgrestException(message: 'La leçon a changé entre-temps.', code: '40001');
    }
    final ligne = '![$description](https://exemple.supabase.co/storage/v1/object/public/schemas/$chemin)';
    final morceaux = actuel.trim().isEmpty ? <String>[] : actuel.split(separateurParagraphes);
    final position = apres == null || apres > morceaux.length ? morceaux.length : apres;
    final nouveau = ([...morceaux]..insert(position, ligne)).join('\n\n');
    textes[leconId] = TexteLecon(
      id: t.id,
      titre: t.titre,
      publiee: t.publiee,
      introduction: champ == ChampLecon.introduction ? nouveau : t.introduction,
      corps: champ == ChampLecon.corps ? nouveau : t.corps,
    );
    final s = SchemaLecon(
      id: _prochainId++,
      leconId: leconId,
      champ: champ,
      chemin: chemin,
      description: description,
      ajouteLe: DateTime(2026, 11, 16),
    );
    schemas.add(s);
    return s.id;
  }

  @override
  Future<String> retirerSchema(int schemaId) async {
    await _avant('retirer');
    _exigerRedacteur();
    final s = schemas.firstWhere((x) => x.id == schemaId);
    schemas.remove(s);
    return s.chemin;
  }

  @override
  Future<void> supprimerImage(String chemin) async {
    await _avant('supprimer');
    fichiers.remove(chemin);
    supprimes.add(chemin);
  }

  @override
  String adresseImage(String chemin) => 'https://exemple.supabase.co/storage/v1/object/public/schemas/$chemin';
}

/// Appareil photo et galerie sans matériel : rend [octets] (ou `null` pour
/// « l'utilisateur renonce ») et une image déjà réduite, sans isolat.
class FauxChoixImage extends ChoixImage {
  FauxChoixImage({this.octets, this.erreurReduction});

  Uint8List? octets;

  /// Erreur de [reduire] (image illisible, trop lourde).
  Object? erreurReduction;

  final sources = <SourceImage>[];

  @override
  Future<Uint8List?> choisir(SourceImage source) async {
    sources.add(source);
    return octets;
  }

  @override
  Future<ImageReduite> reduire(Uint8List octets) async {
    final erreur = erreurReduction;
    if (erreur != null) throw erreur;
    return ImageReduite(octets: octets, largeur: 1200, hauteur: 800);
  }
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
  Compte? compte,
  FauxEnvoi? envoi,
  Redaction? redaction,
  ChoixImage? choixImage,
  String chemin = '/',
  Size taille = tailleTelephone,
  double echelleTexte = 1,
}) async {
  tester.view.physicalSize = taille * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = echelleTexte;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final prefs = preferences ?? FaussesPreferences();
  final leCompte = compte ?? FauxCompte();
  final suivi = SuiviResultats(
    compte: leCompte,
    preferences: prefs,
    envoi: envoi ?? FauxEnvoi(),
    stockage: FauxStockageFile(),
  );
  addTearDown(suivi.arreter);

  await tester.pumpWidget(AppScope(
    // Clé unique : si un test relance l'application, Flutter repart de zéro
    // au lieu de réutiliser l'ancien état (et l'ancien routeur).
    key: UniqueKey(),
    repository: depot,
    preferences: prefs,
    compte: leCompte,
    suivi: suivi,
    redaction: redaction ?? FausseRedaction(),
    choixImage: choixImage ?? FauxChoixImage(),
    child: SamaClasseApp(emplacementInitial: chemin),
  ));
}
