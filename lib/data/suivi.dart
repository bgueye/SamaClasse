// Suivi des enfants (phase 3, décision D24) : leçons lues et résultats des
// exercices, gardés sur le téléphone puis envoyés à Supabase.
//
// Règles :
// * Rien n'est noté sans profil enfant choisi sur ce téléphone ET une
//   session : parent connecté, ou téléphone d'enfant lié par un code (D32).
//   Sans compte, l'application reste sans aucun envoi.
// * Jamais le texte saisi : seulement « réussi ou non », le score et la date.
// * Hors connexion, les lignes attendent dans une file sur l'appareil et
//   partent au prochain envoi réussi. Chaque résultat porte un identifiant
//   fabriqué ici (UUID) : renvoyer une ligne déjà reçue est sans effet.
//
// Pas de paquet de détection du réseau (pas de nouvelle dépendance) : on
// retente l'envoi aux moments où l'application s'active (lancement, retour au
// premier plan, connexion du parent, actualisation, nouveau résultat).

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException, SupabaseClient;

import '../core/services/preferences.dart';
import 'compte.dart';
import 'correction.dart';

// ---------------------------------------------------------------------------
// Lignes en attente
// ---------------------------------------------------------------------------

/// Résultat d'un exercice : ligne de la table `resultats`, en attente
/// d'envoi sur le téléphone ou relue depuis la base (écran de suivi).
@immutable
class ResultatExercice {
  const ResultatExercice({
    required this.id,
    required this.enfantId,
    required this.exerciceId,
    required this.reussi,
    required this.autoEvaluation,
    required this.faitLe,
    this.bonnes,
    this.total,
  });

  final String id;
  final int enfantId;
  final int exerciceId;
  final bool reussi;
  final int? bonnes;
  final int? total;
  final bool autoEvaluation;
  final DateTime faitLe;

  /// Même forme que les colonnes de `resultats` : sert à l'envoi et à
  /// l'enregistrement sur l'appareil.
  Map<String, Object?> toJson() => {
        'id': id,
        'enfant_id': enfantId,
        'exercice_id': exerciceId,
        'reussi': reussi,
        'bonnes': bonnes,
        'total': total,
        'auto_evaluation': autoEvaluation,
        'fait_le': faitLe.toUtc().toIso8601String(),
      };

  factory ResultatExercice.fromJson(Map<String, dynamic> json) => ResultatExercice(
        id: json['id'] as String,
        enfantId: (json['enfant_id'] as num).toInt(),
        exerciceId: (json['exercice_id'] as num).toInt(),
        reussi: json['reussi'] as bool,
        bonnes: (json['bonnes'] as num?)?.toInt(),
        total: (json['total'] as num?)?.toInt(),
        autoEvaluation: json['auto_evaluation'] as bool,
        faitLe: DateTime.parse(json['fait_le'] as String),
      );
}

/// Ouverture d'une leçon : ligne de la table `lectures`, en attente d'envoi
/// ou relue depuis la base.
@immutable
class LectureLecon {
  const LectureLecon({required this.enfantId, required this.leconId, required this.lueLe});

  final int enfantId;
  final int leconId;
  final DateTime lueLe;

  Map<String, Object?> toJson() => {
        'enfant_id': enfantId,
        'lecon_id': leconId,
        'lue_le': lueLe.toUtc().toIso8601String(),
      };

  factory LectureLecon.fromJson(Map<String, dynamic> json) => LectureLecon(
        enfantId: (json['enfant_id'] as num).toInt(),
        leconId: (json['lecon_id'] as num).toInt(),
        lueLe: DateTime.parse(json['lue_le'] as String),
      );
}

/// Contenu de la file d'attente.
@immutable
class FileEnvoi {
  const FileEnvoi({this.resultats = const [], this.lectures = const []});

  final List<ResultatExercice> resultats;
  final List<LectureLecon> lectures;

  bool get estVide => resultats.isEmpty && lectures.isEmpty;
  int get taille => resultats.length + lectures.length;

  /// Ajoute une lecture : une seule par enfant et par leçon, la plus récente
  /// (la table n'en garde qu'une de toute façon).
  FileEnvoi avecLecture(LectureLecon l) => FileEnvoi(
        resultats: resultats,
        lectures: [
          for (final x in lectures)
            if (x.enfantId != l.enfantId || x.leconId != l.leconId) x,
          l,
        ],
      );

  FileEnvoi avecResultat(ResultatExercice r) =>
      FileEnvoi(resultats: [...resultats, r], lectures: lectures);

  /// Retire ce qui a été envoyé (ou abandonné), en gardant ce qui a pu être
  /// ajouté pendant l'envoi.
  FileEnvoi sans({Set<String> resultats = const {}, Set<(int, int)> lectures = const {}}) => FileEnvoi(
        resultats: [for (final r in this.resultats) if (!resultats.contains(r.id)) r],
        lectures: [
          for (final l in this.lectures)
            if (!lectures.contains((l.enfantId, l.leconId))) l,
        ],
      );
}

String encoderFile(FileEnvoi file) => jsonEncode({
      'version': 1,
      'resultats': [for (final r in file.resultats) r.toJson()],
      'lectures': [for (final l in file.lectures) l.toJson()],
    });

/// Lit la file enregistrée. Un contenu illisible (version future, fichier
/// abîmé) donne une file vide plutôt qu'un plantage : on perd au pire
/// quelques lignes de suivi, jamais l'accès aux leçons.
FileEnvoi decoderFile(String texte) {
  try {
    final json = jsonDecode(texte) as Map<String, dynamic>;
    if (json['version'] != 1) return const FileEnvoi();
    return FileEnvoi(
      resultats: [
        for (final r in (json['resultats'] as List).cast<Map<String, dynamic>>()) ResultatExercice.fromJson(r),
      ],
      lectures: [
        for (final l in (json['lectures'] as List).cast<Map<String, dynamic>>()) LectureLecon.fromJson(l),
      ],
    );
  } catch (_) {
    return const FileEnvoi();
  }
}

// ---------------------------------------------------------------------------
// Logique pure
// ---------------------------------------------------------------------------

/// UUID version 4, tiré au hasard (générateur cryptographique) : identifiant
/// d'un résultat, fabriqué sur le téléphone pour rendre l'envoi répétable.
/// Écrit ici plutôt qu'avec un paquet : quelques lignes, pas de dépendance.
String genererUuid([Random? hasard]) {
  final r = hasard ?? Random.secure();
  final octets = List<int>.generate(16, (_) => r.nextInt(256));
  octets[6] = (octets[6] & 0x0f) | 0x40; // version 4
  octets[8] = (octets[8] & 0x3f) | 0x80; // variante RFC 4122
  final h = [for (final o in octets) o.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Résultat à noter pour une correction, ou `null` s'il n'y a rien à noter :
/// réponse invalide, ou exercice à comparer sans « Avais-tu juste ? ».
///
/// [autoEvaluation] : la réponse de l'enfant à « Avais-tu juste ? » pour un
/// exercice qu'il compare lui-même au corrigé.
ResultatExercice? resultatDepuis({
  required Correction correction,
  required bool? autoEvaluation,
  required int enfantId,
  required int exerciceId,
  required DateTime maintenant,
  String Function() nouvelId = genererUuid,
}) {
  return switch (correction) {
    CorrectionAuto(:final bonnes, :final total) when total > 0 => ResultatExercice(
        id: nouvelId(),
        enfantId: enfantId,
        exerciceId: exerciceId,
        reussi: bonnes == total,
        bonnes: bonnes,
        total: total,
        autoEvaluation: false,
        faitLe: maintenant,
      ),
    CorrectionManuelle() when autoEvaluation != null => ResultatExercice(
        id: nouvelId(),
        enfantId: enfantId,
        exerciceId: exerciceId,
        reussi: autoEvaluation,
        autoEvaluation: true,
        faitLe: maintenant,
      ),
    _ => null,
  };
}

/// Vrai si la base a refusé la ligne pour de bon : la renvoyer ne servirait à
/// rien et bloquerait la file. Cas : règle RLS (autre compte connecté depuis,
/// profil supprimé, exercice retiré de la publication), clé étrangère
/// disparue, contrainte non respectée.
/// Faux pour le reste (réseau, serveur indisponible, session à rafraîchir) :
/// la ligne attend le prochain essai.
bool estRefusDefinitif(Object erreur) =>
    erreur is PostgrestException && const {'42501', '23503', '23514', '22P02'}.contains(erreur.code);

// ---------------------------------------------------------------------------
// Envoi et stockage (interfaces : remplacées par des faux dans les tests)
// ---------------------------------------------------------------------------

/// Envoi vers Supabase.
abstract class EnvoiSuivi {
  Future<void> envoyerResultats(List<ResultatExercice> resultats);
  Future<void> envoyerLectures(List<LectureLecon> lectures);
}

class EnvoiSupabase implements EnvoiSuivi {
  EnvoiSupabase(this._client);

  final SupabaseClient _client;

  /// `ignoreDuplicates` : `on conflict (id) do nothing`. Un résultat déjà
  /// reçu (envoi précédent coupé avant la réponse) est simplement ignoré.
  @override
  Future<void> envoyerResultats(List<ResultatExercice> resultats) => _client
      .from('resultats')
      .upsert([for (final r in resultats) r.toJson()], onConflict: 'id', ignoreDuplicates: true);

  /// Relire une leçon met sa date à jour (une ligne par enfant et leçon).
  @override
  Future<void> envoyerLectures(List<LectureLecon> lectures) => _client
      .from('lectures')
      .upsert([for (final l in lectures) l.toJson()], onConflict: 'enfant_id,lecon_id');
}

/// Emplacement de la file sur l'appareil.
abstract class StockageFile {
  Future<String?> lire();
  Future<void> ecrire(String texte);
}

class StockageFileLocal implements StockageFile {
  StockageFileLocal([SharedPreferencesAsync? stockage]) : _stockage = stockage ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _stockage;
  static const _cle = 'file_envoi_v1';

  @override
  Future<String?> lire() => _stockage.getString(_cle);

  @override
  Future<void> ecrire(String texte) => _stockage.setString(_cle, texte);
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Note les lectures et les résultats de l'enfant de ce téléphone, les garde
/// sur l'appareil et les envoie dès que possible.
///
/// Les écrans n'attendent jamais ces opérations : un souci de stockage ou de
/// réseau ne doit pas gêner l'élève. Les erreurs sont avalées ici (la ligne
/// reste dans la file, ou est abandonnée si la base la refuse pour de bon).
class SuiviResultats {
  SuiviResultats({
    required this.compte,
    required this.preferences,
    required this.envoi,
    required this.stockage,
    DateTime Function()? horloge,
  }) : _horloge = horloge ?? DateTime.now {
    // Connexion du parent (ou session restaurée) : ce qui attendait part.
    compte.addListener(_surChangementDeCompte);
  }

  void _surChangementDeCompte() {
    if (_sessionPourEnvoyer) envoyer();
  }

  /// Parent connecté, ou session anonyme d'un téléphone d'enfant lié (D32 :
  /// les règles de la base lui permettent d'écrire pour son enfant).
  bool get _sessionPourEnvoyer => compte.estConnecte || compte.estAnonyme;

  /// À appeler si le service est remplacé (tests) : cesse d'écouter le compte.
  void arreter() => compte.removeListener(_surChangementDeCompte);

  final Compte compte;
  final Preferences preferences;
  final EnvoiSuivi envoi;
  final StockageFile stockage;
  final DateTime Function() _horloge;

  /// Toutes les opérations sur la file passent par cette chaîne, une à la
  /// fois : un résultat noté pendant un envoi n'est ni perdu ni envoyé deux
  /// fois.
  Future<void> _chaine = Future.value();

  Future<void> _enSerie(Future<void> Function() operation) {
    final suite = _chaine.then((_) => operation()).catchError((Object _) {});
    _chaine = suite;
    return suite;
  }

  /// Profil à qui attribuer une activité, ou `null` s'il ne faut rien noter
  /// (pas de profil choisi, ou pas de session).
  Future<int?> _enfantANoter() async {
    if (!_sessionPourEnvoyer) return null;
    return (await preferences.enfantActif())?.id;
  }

  Future<FileEnvoi> _lireFile() async {
    final texte = await stockage.lire();
    return texte == null ? const FileEnvoi() : decoderFile(texte);
  }

  /// Oublie tout ce qui attend sur le téléphone (compte supprimé : ces
  /// lignes seraient refusées par la base de toute façon).
  Future<void> viderFile() => _enSerie(() => stockage.ecrire(encoderFile(const FileEnvoi())));

  /// Nombre de lignes qui attendent d'être envoyées.
  Future<int> enAttente() async => (await _lireFile()).taille;

  /// L'enfant de ce téléphone a ouvert la leçon [leconId].
  Future<void> noterLecture(int leconId) => _enSerie(() async {
        final enfant = await _enfantANoter();
        if (enfant == null) return;
        final file = await _lireFile();
        await stockage.ecrire(encoderFile(
          file.avecLecture(LectureLecon(enfantId: enfant, leconId: leconId, lueLe: _horloge())),
        ));
      }).then((_) => envoyer());

  /// L'enfant de ce téléphone a terminé l'exercice [exerciceId].
  Future<void> noterResultat({
    required int exerciceId,
    required Correction correction,
    bool? autoEvaluation,
  }) =>
      _enSerie(() async {
        final enfant = await _enfantANoter();
        if (enfant == null) return;
        final resultat = resultatDepuis(
          correction: correction,
          autoEvaluation: autoEvaluation,
          enfantId: enfant,
          exerciceId: exerciceId,
          maintenant: _horloge(),
        );
        if (resultat == null) return;
        final file = await _lireFile();
        await stockage.ecrire(encoderFile(file.avecResultat(resultat)));
      }).then((_) => envoyer());

  /// Envoie ce qui attend. Sans session, la file attend.
  Future<void> envoyer() => _enSerie(() async {
        if (!_sessionPourEnvoyer) return;
        final file = await _lireFile();
        if (file.estVide) return;

        final envoyes = <String>{};
        final lus = <(int, int)>{};

        if (file.lectures.isNotEmpty) {
          lus.addAll(await _envoyerParLots(
            file.lectures,
            (lot) => envoi.envoyerLectures(lot),
            (l) => (l.enfantId, l.leconId),
          ));
        }
        if (file.resultats.isNotEmpty) {
          envoyes.addAll(await _envoyerParLots(
            file.resultats,
            (lot) => envoi.envoyerResultats(lot),
            (r) => r.id,
          ));
        }
        if (envoyes.isEmpty && lus.isEmpty) return;
        // Relit la file : rien n'a pu s'y ajouter (opérations en série), mais
        // on part de l'état enregistré plutôt que d'une copie.
        final actuelle = await _lireFile();
        await stockage.ecrire(encoderFile(actuelle.sans(resultats: envoyes, lectures: lus)));
      });

  /// Envoie toute la liste d'un coup ; si la base refuse pour de bon (une
  /// ligne fautive fait échouer tout le lot), renvoie ligne par ligne pour
  /// abandonner seulement les fautives. Rend les clés des lignes à retirer
  /// de la file (envoyées ou abandonnées). Une erreur réseau arrête tout :
  /// rien n'est retiré, on réessaiera.
  Future<Set<K>> _envoyerParLots<T, K>(
    List<T> lignes,
    Future<void> Function(List<T>) envoyerLot,
    K Function(T) cle,
  ) async {
    try {
      await envoyerLot(lignes);
      return {for (final l in lignes) cle(l)};
    } catch (e) {
      if (!estRefusDefinitif(e) || lignes.length == 1) {
        return estRefusDefinitif(e) ? {cle(lignes.single)} : {};
      }
    }
    final retirees = <K>{};
    for (final l in lignes) {
      try {
        await envoyerLot([l]);
        retirees.add(cle(l));
      } catch (e) {
        if (estRefusDefinitif(e)) {
          retirees.add(cle(l)); // abandonnée
        } else {
          break; // réseau coupé en cours de route : la suite attendra
        }
      }
    }
    return retirees;
  }
}
