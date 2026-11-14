// Compte parent et profils enfants (phase 2, décisions D21 et D22).
//
// Seul le parent a un compte Supabase : il se connecte avec un code à
// 6 chiffres reçu par e-mail, sans mot de passe. Ses enfants sont de simples
// profils (prénom, classe) de la table `enfants`, protégée par les règles RLS :
// chaque parent ne voit et ne modifie que les siens.
//
// La lecture du contenu ne dépend jamais du compte : sans connexion, ou sans
// compte, l'application fonctionne comme avant.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  /// Adresse e-mail du parent connecté, `null` sans connexion.
  String? get email;

  bool get estConnecte => email != null;

  /// Envoie un code de connexion à [email]. Crée le compte s'il n'existe pas.
  Future<void> envoyerCode(String email);

  /// Vérifie le [code] reçu ; en cas de succès, le compte est connecté et la
  /// session est gardée sur l'appareil (elle survit au redémarrage).
  Future<void> verifierCode(String email, String code);

  Future<void> deconnecter();

  /// Profils enfants du compte connecté, par ordre de création.
  Future<List<Enfant>> enfants();

  Future<Enfant> ajouterEnfant({required String prenom, required int classeId});

  Future<Enfant> modifierEnfant(Enfant enfant);

  Future<void> supprimerEnfant(int id);
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
  String? get email => _client.auth.currentUser?.email;

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

  @override
  void dispose() {
    _abonnement.cancel();
    super.dispose();
  }
}
