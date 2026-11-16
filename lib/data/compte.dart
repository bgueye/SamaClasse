// Compte parent et profils enfants (phase 2, décisions D21 et D22).
//
// Seul le parent a un compte Supabase : il se connecte avec un code à
// chiffres reçu par e-mail, sans mot de passe. Ses enfants sont de simples
// profils (prénom, classe) de la table `enfants`, protégée par les règles RLS :
// chaque parent ne voit et ne modifie que les siens.
//
// La lecture du contenu ne dépend jamais du compte : sans connexion, ou sans
// compte, l'application fonctionne comme avant.
//
// Téléphone d'un enfant (D32) : une session anonyme, liée à un seul profil
// par un code du parent (liaison.dart). Ce n'est PAS une connexion de
// parent : `estConnecte` reste faux, `estAnonyme` est vrai.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'liaison.dart';
import 'suivi.dart';

/// Profil d'un enfant, tel que stocké dans la table `enfants`.
@immutable
class Enfant {
  const Enfant({required this.id, required this.prenom, required this.classeId});

  final int id;
  final String prenom;
  final int classeId;

  factory Enfant.fromJson(Map<String, dynamic> json) => Enfant(
        id: (json['id'] as num).toInt(),
        prenom: json['prenom'] as String,
        classeId: (json['classe_id'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is Enfant && other.id == id && other.prenom == prenom && other.classeId == classeId;

  @override
  int get hashCode => Object.hash(id, prenom, classeId);
}

/// Contrat du compte, utilisé par les écrans (via `AppScope`).
///
/// `ChangeNotifier` : les écrans se reconstruisent à la connexion et à la
/// déconnexion (`ListenableBuilder`). Pas de gestionnaire d'état externe :
/// c'est la piste prévue par docs/ARCHITECTURE.md pour le compte connecté.
/// Abstrait pour que les tests passent un faux compte sans réseau.
abstract class Compte extends ChangeNotifier {
  /// Adresse e-mail du parent connecté, `null` sans connexion (et pour la
  /// session anonyme d'un téléphone d'enfant).
  String? get email;

  /// Un parent est connecté sur ce téléphone.
  bool get estConnecte => email != null;

  /// Session anonyme ouverte sur ce téléphone (téléphone d'enfant, lié ou en
  /// cours de liaison, D32).
  bool get estAnonyme;

  /// Envoie un code de connexion à [email]. Crée le compte s'il n'existe pas.
  Future<void> envoyerCode(String email);

  /// Vérifie le [code] reçu ; en cas de succès, le compte est connecté et la
  /// session est gardée sur l'appareil (elle survit au redémarrage).
  Future<void> verifierCode(String email, String code);

  Future<void> deconnecter();

  /// Supprime définitivement le compte connecté (exigence de Google Play),
  /// avec ses profils enfants et leur suivi ; puis le compte est déconnecté.
  Future<void> supprimerCompte();

  /// Profils enfants du compte connecté, par ordre de création.
  Future<List<Enfant>> enfants();

  Future<Enfant> ajouterEnfant({required String prenom, required int classeId});

  Future<Enfant> modifierEnfant(Enfant enfant);

  Future<void> supprimerEnfant(int id);

  /// Leçons lues par les enfants du compte (phase 3). Une ligne par enfant et
  /// par leçon : la dernière ouverture.
  Future<List<LectureLecon>> lectures();

  /// Résultats des enfants du compte, du plus récent au plus ancien, limités
  /// aux [limite] derniers (assez pour « Cette semaine » et « Derniers
  /// exercices »).
  Future<List<ResultatExercice>> resultats({int limite = 500});

  // --- Téléphones des enfants (D32) ---

  /// Parent : code à donner à l'enfant pour lier son téléphone à son profil
  /// (6 chiffres, 10 minutes, usage unique).
  Future<CodeLiaison> creerCodeLiaison(int enfantId);

  /// Parent : téléphones liés aux profils de ses enfants.
  Future<List<AppareilLie>> appareils();

  /// Parent : délie un téléphone (il n'enverra plus rien).
  Future<void> delierAppareil(String appareilId);

  /// Téléphone de l'enfant : ouvre une session anonyme si besoin, puis donne
  /// le [code]. Rend le profil auquel le téléphone est désormais lié ;
  /// lève [CodeLiaisonRefuse] si le code est faux ou expiré.
  Future<Enfant> lierCeTelephone(String code);

  /// Téléphone de l'enfant : profil auquel il est lié, ou `null` s'il ne
  /// l'est plus (délié par le parent, profil supprimé).
  Future<Enfant?> enfantDeCeTelephone();

  /// Téléphone de l'enfant : « Ce n'est plus mon téléphone ». Supprime la
  /// session anonyme (et donc la liaison).
  Future<void> delierCeTelephone();
}

/// Compte réel, adossé à Supabase Auth et à la table `enfants`.
class CompteSupabase extends Compte {
  CompteSupabase(this._client) {
    // Connexion, déconnexion, session restaurée au lancement ou expirée :
    // on prévient les écrans à chaque changement.
    _abonnement = _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _abonnement;

  /// Colonnes explicites : on ne demande que ce dont l'application a besoin
  /// (`parent_id` est imposé par les règles RLS, inutile de le relire).
  static const _colonnes = 'id, prenom, classe_id';

  @override
  String? get email {
    final compte = _client.auth.currentUser;
    // Session anonyme (téléphone d'enfant) : pas un parent.
    if (compte == null || compte.isAnonymous) return null;
    return compte.email;
  }

  @override
  bool get estAnonyme => _client.auth.currentUser?.isAnonymous ?? false;

  @override
  Future<void> envoyerCode(String email) => _client.auth.signInWithOtp(
        email: email,
        // Premier passage d'un parent : le compte est créé à la vérification
        // du code. Pas de lien de redirection : on saisit le code (D22).
        shouldCreateUser: true,
      );

  @override
  Future<void> verifierCode(String email, String code) async {
    await _client.auth.verifyOTP(email: email, token: code, type: OtpType.email);
  }

  @override
  Future<void> deconnecter() => _client.auth.signOut();

  @override
  Future<void> supprimerCompte() async {
    // La fonction ne vise que le compte de la session (aucun paramètre).
    await _client.rpc<void>('supprimer_mon_compte');
    // Le compte n'existe plus : on efface la session locale. Le serveur peut
    // refuser la déconnexion d'un compte disparu, sans gravité.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  @override
  Future<List<Enfant>> enfants() async {
    final lignes = await _client.from('enfants').select(_colonnes).order('created_at').order('id');
    return lignes.map(Enfant.fromJson).toList();
  }

  @override
  Future<Enfant> ajouterEnfant({required String prenom, required int classeId}) async {
    // `parent_id` est rempli par la base (valeur par défaut `auth.uid()`).
    final ligne = await _client
        .from('enfants')
        .insert({'prenom': prenom, 'classe_id': classeId})
        .select(_colonnes)
        .single();
    return Enfant.fromJson(ligne);
  }

  @override
  Future<Enfant> modifierEnfant(Enfant enfant) async {
    final ligne = await _client
        .from('enfants')
        .update({'prenom': enfant.prenom, 'classe_id': enfant.classeId})
        .eq('id', enfant.id)
        .select(_colonnes)
        .single();
    return Enfant.fromJson(ligne);
  }

  @override
  Future<void> supprimerEnfant(int id) => _client.from('enfants').delete().eq('id', id);

  // Les règles RLS ne renvoient que les lignes des enfants du parent connecté.
  @override
  Future<List<LectureLecon>> lectures() async {
    final lignes = await _client.from('lectures').select('enfant_id, lecon_id, lue_le');
    return lignes.map(LectureLecon.fromJson).toList();
  }

  @override
  Future<List<ResultatExercice>> resultats({int limite = 500}) async {
    final lignes = await _client
        .from('resultats')
        .select('id, enfant_id, exercice_id, reussi, bonnes, total, auto_evaluation, fait_le')
        .order('fait_le', ascending: false)
        .limit(limite);
    return lignes.map(ResultatExercice.fromJson).toList();
  }

  // --- Téléphones des enfants (D32) ---

  @override
  Future<CodeLiaison> creerCodeLiaison(int enfantId) async {
    final lignes = await _client.rpc<List<dynamic>>('creer_code_liaison', params: {'p_enfant_id': enfantId});
    final ligne = lignes.single as Map<String, dynamic>;
    return CodeLiaison(code: ligne['code'] as String, expireLe: DateTime.parse(ligne['expire_le'] as String));
  }

  @override
  Future<List<AppareilLie>> appareils() async {
    final lignes = await _client.from('appareils').select('id, enfant_id, appareil, lie_le').order('lie_le');
    return lignes.map(AppareilLie.fromJson).toList();
  }

  @override
  Future<void> delierAppareil(String appareilId) =>
      _client.rpc<void>('delier_appareil', params: {'p_appareil': appareilId});

  @override
  Future<Enfant> lierCeTelephone(String code) async {
    // Une seule session anonyme par téléphone : on la garde entre deux
    // essais (le nombre d'essais lui est compté).
    if (_client.auth.currentUser == null) await _client.auth.signInAnonymously();
    final reponse = await _client.rpc<Map<String, dynamic>>('utiliser_code_liaison', params: {
      'p_code': code,
      'p_appareil': typeAppareil(plateforme: defaultTargetPlatform, web: kIsWeb),
    });
    if (reponse['lie'] != true) {
      throw CodeLiaisonRefuse((reponse['essais_restants'] as num?)?.toInt() ?? 0);
    }
    notifyListeners();
    return Enfant(
      id: (reponse['enfant_id'] as num).toInt(),
      prenom: reponse['prenom'] as String,
      classeId: (reponse['classe_id'] as num).toInt(),
    );
  }

  @override
  Future<Enfant?> enfantDeCeTelephone() async {
    if (!estAnonyme) return null;
    // Les règles ne montrent à un téléphone lié que le profil de son enfant.
    final lignes = await _client.from('enfants').select(_colonnes).limit(1);
    return lignes.isEmpty ? null : Enfant.fromJson(lignes.first);
  }

  @override
  Future<void> delierCeTelephone() async {
    if (!estAnonyme) return;
    // Supprime la session anonyme : la liaison disparaît avec elle.
    await _client.rpc<void>('supprimer_mon_compte');
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  @override
  void dispose() {
    _abonnement.cancel();
    super.dispose();
  }
}
