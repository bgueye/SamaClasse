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
import 'package:samaclasse/core/services/impression.dart';
import 'package:samaclasse/core/services/moteur_vocal.dart';
import 'package:samaclasse/core/services/partage.dart';
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
    List<AppareilLie>? appareils,
    this.lieA,
  })  : _email = connecte,
        _enfants = [...?enfants],
        lecturesEnBase = [...?lectures],
        resultatsEnBase = [...?resultats],
        appareilsEnBase = [...?appareils],
        anonyme = lieA != null;

  // --- Téléphones des enfants (D32) ---

  /// Session anonyme ouverte sur ce faux téléphone.
  bool anonyme;

  /// Profil auquel ce faux téléphone est lié (session anonyme), `null` sinon.
  Enfant? lieA;

  /// Codes « en base » : code → profil, comme `codes_liaison`.
  final codesLiaison = <String, Enfant>{};
  final List<AppareilLie> appareilsEnBase;
  final appareilsDelies = <String>[];
  var _prochainCode = 482913;

  /// Essais restants pour ce téléphone (5 par heure en base).
  var essaisRestants = 5;

  @override
  bool get estAnonyme => anonyme;

  @override
  Future<CodeLiaison> creerCodeLiaison(int enfantId) async {
    await _avant('creerCode');
    final enfant = _enfants.firstWhere((e) => e.id == enfantId);
    final code = '${_prochainCode++}';
    codesLiaison[code] = enfant;
    return CodeLiaison(code: code, expireLe: DateTime.now().add(const Duration(minutes: 10)));
  }

  @override
  Future<List<AppareilLie>> appareils() async {
    await _avant('appareils');
    return List.of(appareilsEnBase);
  }

  @override
  Future<void> delierAppareil(String appareilId) async {
    await _avant('delierAppareil');
    appareilsEnBase.removeWhere((a) => a.id == appareilId);
    appareilsDelies.add(appareilId);
  }

  @override
  Future<Enfant> lierCeTelephone(String code) async {
    await _avant('lier');
    anonyme = true;
    notifyListeners();
    final enfant = codesLiaison.remove(code);
    if (enfant == null) {
      essaisRestants--;
      throw CodeLiaisonRefuse(essaisRestants);
    }
    lieA = enfant;
    return enfant;
  }

  @override
  Future<Enfant?> enfantDeCeTelephone() async {
    await _avant('enfantDeCeTelephone');
    return anonyme ? lieA : null;
  }

  @override
  Future<void> delierCeTelephone() async {
    await _avant('delierCeTelephone');
    anonyme = false;
    lieA = null;
    notifyListeners();
  }

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
    anonyme = false;
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
    bool? validateur,
    List<LeconAVerifier>? lecons,
    List<PointLeve>? leves,
    Map<int, TexteLecon>? textes,
    List<SchemaLecon>? schemas,
    List<CorrectionLecon>? corrections,
    List<VersionLecon>? versions,
  })  : validateur = validateur ?? redacteur,
        lecons = [...?lecons],
        leves = [...?leves],
        textes = {...?textes},
        schemas = [...?schemas],
        corrections = [...?corrections],
        versionsEnBase = [...?versions],
        fichiers = {for (final s in [...?schemas]) s.chemin};

  bool redacteur;

  /// Validateur (D33) : par défaut, un rédacteur des tests l'est aussi.
  bool validateur;

  /// Corrections ouvertes « en base » (D33) et versions publiées.
  final List<CorrectionLecon> corrections;
  final List<VersionLecon> versionsEnBase;
  final correctionsFermees = <int, String>{}; // id → « publiee » ou « abandonnee »
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
  Future<PointLeve> leverPoint({required int leconId, required String point, String? commentaire, int? correctionId}) async {
    await _avant('lever');
    _exigerRedacteur();
    const refus = PostgrestException(message: 'new row violates row-level security policy', code: '42501');
    if (correctionId != null) {
      final c = corrections.where((c) => c.id == correctionId).firstOrNull;
      if (c == null || !c.points.contains(point)) throw refus;
    } else {
      final lecon = lecons.firstWhere((l) => l.id == leconId);
      if (!lecon.points.contains(point) || publiees.contains(leconId)) throw refus;
    }
    final p = PointLeve(
      id: _prochainId++,
      leconId: leconId,
      point: point,
      leveLe: DateTime.now(),
      commentaire: commentaire,
      correctionId: correctionId,
    );
    leves.add(p);
    return p;
  }

  @override
  Future<void> annulerPoint(int id) async {
    await _avant('annuler');
    _exigerRedacteur();
    leves.removeWhere((p) => p.id == id);
  }

  void _exigerValidateur() {
    if (!redacteur || !validateur) throw const PostgrestException(message: 'Seul un validateur peut publier.', code: '42501');
  }

  @override
  Future<void> publier(int leconId) async {
    await _avant('publier');
    _exigerValidateur();
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
    final t = textes[leconId];
    final c = _ouverte(leconId);
    if (t == null || c == null) return t;
    // Correction ouverte : la copie de travail, comme la vraie rédaction.
    return TexteLecon(
      id: t.id,
      titre: c.texte.titre,
      publiee: t.publiee,
      introduction: c.texte.introduction,
      corps: c.texte.corps,
      correctionId: c.id,
    );
  }

  CorrectionLecon? _ouverte(int leconId) => corrections.where((c) => c.leconId == leconId).firstOrNull;

  /// Remplace le texte de travail d'une correction (le circuit artefact).
  void corrigerTexte(int correctionId, {String? introduction, String? corps}) {
    final i = corrections.indexWhere((c) => c.id == correctionId);
    final c = corrections[i];
    corrections[i] = _avecTexte(
      c,
      TexteRedige(
        titre: c.texte.titre,
        objectifs: c.texte.objectifs,
        introduction: introduction ?? c.texte.introduction,
        corps: corps ?? c.texte.corps,
        aRetenir: c.texte.aRetenir,
      ),
      modifiee: true,
    );
  }

  static CorrectionLecon _avecTexte(CorrectionLecon c, TexteRedige texte, {bool modifiee = false}) => CorrectionLecon(
        id: c.id,
        leconId: c.leconId,
        titreEnLigne: c.titreEnLigne,
        classe: c.classe,
        ordreClasse: c.ordreClasse,
        matiere: c.matiere,
        matiereSlug: c.matiereSlug,
        texte: texte,
        points: c.points,
        motif: c.motif,
        demandeeLe: c.demandeeLe,
        modifieeLe: modifiee ? c.demandeeLe.add(const Duration(hours: 1)) : c.modifieeLe,
        parMoi: c.parMoi,
      );

  // --- Corrections et versions (D33) ---

  @override
  Future<bool> estValidateur() async {
    await _avant('estValidateur');
    return redacteur && validateur;
  }

  @override
  Future<List<CorrectionLecon>> correctionsEnCours() async {
    await _avant('corrections');
    _exigerRedacteur();
    return List.of(corrections);
  }

  @override
  Future<CorrectionLecon?> correctionDe(int leconId) async {
    await _avant('correctionDe');
    _exigerRedacteur();
    return _ouverte(leconId);
  }

  @override
  Future<int> demanderCorrection({required int leconId, required String motif, required List<String> points}) async {
    await _avant('demander');
    _exigerRedacteur();
    final t = textes[leconId];
    if (t == null || !t.publiee) {
      throw const PostgrestException(message: 'Seule une leçon publiée se corrige ainsi.', code: 'P0001');
    }
    if (_ouverte(leconId) != null) {
      throw const PostgrestException(message: 'Une correction de cette leçon est déjà en cours.', code: 'P0001');
    }
    final c = CorrectionLecon(
      id: _prochainId++,
      leconId: leconId,
      titreEnLigne: t.titre,
      classe: '4ème',
      ordreClasse: 9,
      matiere: 'Sciences physiques',
      matiereSlug: 'sciences-physiques',
      texte: TexteRedige(titre: t.titre, objectifs: const [], introduction: t.introduction, corps: t.corps, aRetenir: const []),
      points: points,
      motif: motif,
      demandeeLe: DateTime(2026, 11, 16, 18),
      modifieeLe: DateTime(2026, 11, 16, 18),
      parMoi: true,
    );
    corrections.add(c);
    return c.id;
  }

  void _archiver(int leconId, TexteRedige texte, String motif) {
    final numero = versionsEnBase.where((v) => v.leconId == leconId).fold<int>(0, (m, v) => v.numero > m ? v.numero : m) + 1;
    versionsEnBase.add(VersionLecon(
      id: _prochainId++,
      leconId: leconId,
      numero: numero,
      motif: motif,
      publieeLe: DateTime(2026, 11, 16, 20),
      texte: texte,
    ));
  }

  @override
  Future<int> publierCorrection(int correctionId) async {
    await _avant('publierCorrection');
    _exigerValidateur();
    final c = corrections.firstWhere((c) => c.id == correctionId);
    final restants = c.points.where((p) => !leves.any((x) => x.correctionId == c.id && x.point == p)).length;
    if (restants > 0) throw PostgrestException(message: 'Il reste $restants point(s) à vérifier.', code: 'P0001');
    final t = textes[c.leconId]!;
    textes[c.leconId] = TexteLecon(
      id: t.id,
      titre: c.texte.titre,
      publiee: true,
      introduction: c.texte.introduction,
      corps: c.texte.corps,
    );
    corrections.remove(c);
    correctionsFermees[c.id] = 'publiee';
    _archiver(c.leconId, c.texte, c.motif);
    return versionsEnBase.last.numero;
  }

  @override
  Future<List<String>> abandonnerCorrection(int correctionId) async {
    await _avant('abandonner');
    final c = corrections.firstWhere((c) => c.id == correctionId);
    if (!redacteur || !(validateur || c.parMoi)) {
      throw const PostgrestException(message: 'Seul un validateur peut abandonner.', code: '42501');
    }
    final chemins = [for (final s in schemas) if (s.correctionId == c.id) s.chemin];
    schemas.removeWhere((s) => s.correctionId == c.id);
    corrections.remove(c);
    correctionsFermees[c.id] = 'abandonnee';
    return chemins;
  }

  @override
  Future<List<VersionLecon>> versions(int leconId) async {
    await _avant('versions');
    _exigerRedacteur();
    return [for (final v in versionsEnBase) if (v.leconId == leconId) v]..sort((a, b) => b.numero.compareTo(a.numero));
  }

  @override
  Future<int> revenirAVersion(int versionId) async {
    await _avant('revenir');
    _exigerValidateur();
    final v = versionsEnBase.firstWhere((v) => v.id == versionId);
    if (_ouverte(v.leconId) != null) {
      throw const PostgrestException(message: 'Une correction de cette leçon est en cours.', code: 'P0001');
    }
    final t = textes[v.leconId];
    if (t != null) {
      textes[v.leconId] = TexteLecon(id: t.id, titre: v.texte.titre, publiee: t.publiee, introduction: v.texte.introduction, corps: v.texte.corps);
    }
    _archiver(v.leconId, v.texte, 'Retour à la version ${v.numero}');
    return versionsEnBase.last.numero;
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
    final correction = t.publiee ? _ouverte(leconId) : null;
    if (t.publiee && correction == null && !validateur) {
      throw const PostgrestException(message: 'Leçon publiée : demande d’abord une correction.', code: '42501');
    }
    final actuel = (correction == null
            ? t.texte(champ)
            : (champ == ChampLecon.introduction ? correction.texte.introduction : correction.texte.corps)) ??
        '';
    if (actuel != (texteAttendu ?? '')) {
      throw const PostgrestException(message: 'La leçon a changé entre-temps.', code: '40001');
    }
    final ligne = '![$description](https://exemple.supabase.co/storage/v1/object/public/schemas/$chemin)';
    final morceaux = actuel.trim().isEmpty ? <String>[] : actuel.split(separateurParagraphes);
    final position = apres == null || apres > morceaux.length ? morceaux.length : apres;
    final nouveau = ([...morceaux]..insert(position, ligne)).join('\n\n');
    if (correction != null) {
      final i = corrections.indexOf(correction);
      corrections[i] = _avecTexte(
        correction,
        TexteRedige(
          titre: correction.texte.titre,
          objectifs: correction.texte.objectifs,
          introduction: champ == ChampLecon.introduction ? nouveau : correction.texte.introduction,
          corps: champ == ChampLecon.corps ? nouveau : correction.texte.corps,
          aRetenir: correction.texte.aRetenir,
        ),
      );
    } else {
      textes[leconId] = TexteLecon(
        id: t.id,
        titre: t.titre,
        publiee: t.publiee,
        introduction: champ == ChampLecon.introduction ? nouveau : t.introduction,
        corps: champ == ChampLecon.corps ? nouveau : t.corps,
      );
    }
    final s = SchemaLecon(
      id: _prochainId++,
      leconId: leconId,
      champ: champ,
      chemin: chemin,
      description: description,
      ajouteLe: DateTime(2026, 11, 16),
      correctionId: correction?.id,
    );
    schemas.add(s);
    return s.id;
  }

  @override
  Future<String> retirerSchema(int schemaId) async {
    await _avant('retirer');
    _exigerRedacteur();
    final s = schemas.firstWhere((x) => x.id == schemaId);
    final t = textes[s.leconId];
    final dansCorrection = s.correctionId != null && corrections.any((c) => c.id == s.correctionId);
    if (!dansCorrection && (t?.publiee ?? false) && (!validateur || _ouverte(s.leconId) != null)) {
      throw const PostgrestException(message: 'Ce schéma est en ligne : seul un validateur peut le retirer.', code: '42501');
    }
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

/// Synthèse vocale sans téléphone (« Écouter la leçon »).
///
/// [journal] garde chaque appel (`langue fr-FR`, `dire Bonjour.`, `arrêt`).
/// Automatique par défaut : chaque passage se termine aussitôt. Avec
/// `automatique: false`, un passage dure jusqu'à [finirPassage] ou à un
/// arrêt, pour observer une pause ou un saut en pleine lecture.
class FauxMoteurVocal implements MoteurVocal {
  FauxMoteurVocal({this.langues = const {'fr-FR', 'en-GB'}, this.automatique = true});

  /// Voix installées sur le « téléphone ».
  final Set<String> langues;
  final bool automatique;

  final journal = <String>[];
  double? vitesse;
  Completer<void>? _passage;

  /// Un passage est en train d'être dit (mode non automatique).
  bool get parle => _passage != null;

  /// Termine le passage en cours, comme la fin naturelle d'une phrase.
  /// Ensuite, `pumpEventQueue()` (ou `tester.pump()` dans un test d'écran)
  /// laisse la boucle de lecture passer au passage suivant.
  void finirPassage() {
    final p = _passage;
    _passage = null;
    p?.complete();
  }

  @override
  Future<void> preparer({required double vitesse}) async => this.vitesse = vitesse;

  @override
  Future<bool> langueDisponible(String langue) async => langues.contains(langue);

  @override
  Future<void> choisirLangue(String langue) async => journal.add('langue $langue');

  @override
  Future<void> dire(String texte) {
    journal.add('dire $texte');
    if (automatique) return Future.value();
    return (_passage = Completer<void>()).future;
  }

  @override
  Future<void> arreter() async {
    journal.add('arrêt');
    // Comme Android : l'arrêt termine la phrase en cours.
    final p = _passage;
    _passage = null;
    p?.complete();
  }
}

/// Partage sans téléphone : garde ce qui a été envoyé ou copié.
class FauxPartage extends Partage {
  final envois = <String>[];
  final copies = <String>[];

  @override
  Future<void> envoyer(String texte, {String? sujet}) async => envois.add(texte);

  @override
  Future<void> copier(String texte) async => copies.add(texte);
}

/// Impression sans imprimante : fabrique le document (pour vérifier qu'il se
/// construit) et garde son nom et sa taille.
class FausseImpression extends Impression {
  final noms = <String>[];
  final documents = <Uint8List>[];

  @override
  Future<void> imprimer({required String nom, required Future<Uint8List> Function() document}) async {
    noms.add(nom);
    documents.add(await document());
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
  MoteurVocal? moteurVocal,
  Partage? partage,
  Impression? impression,
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
    // Toujours un faux : flutter_tts n'a pas de canal natif dans les tests.
    creerMoteurVocal: () => moteurVocal ?? FauxMoteurVocal(),
    partage: partage ?? FauxPartage(),
    impression: impression ?? FausseImpression(),
    child: SamaClasseApp(emplacementInitial: chemin),
  ));
}
