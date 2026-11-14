// Préférences gardées sur l'appareil : classe choisie, dernière leçon
// ouverte (pour « Reprendre où tu t'es arrêté ») et profil enfant utilisé sur
// ce téléphone (phase 2). Rien n'est envoyé au serveur.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DerniereLecon {
  const DerniereLecon({
    required this.id,
    required this.titre,
    required this.matiere,
    required this.matiereSlug,
    required this.classe,
  });

  final int id;
  final String titre;
  final String matiere;
  final String? matiereSlug;
  final String classe;

  Map<String, Object?> toJson() => {
        'id': id,
        'titre': titre,
        'matiere': matiere,
        'matiere_slug': matiereSlug,
        'classe': classe,
      };

  factory DerniereLecon.fromJson(Map<String, dynamic> json) => DerniereLecon(
        id: (json['id'] as num).toInt(),
        titre: json['titre'] as String,
        matiere: json['matiere'] as String,
        matiereSlug: json['matiere_slug'] as String?,
        classe: json['classe'] as String,
      );
}

/// Profil enfant choisi sur ce téléphone (« Utiliser sur ce téléphone »).
///
/// Gardé localement pour l'afficher sans réseau (« Bonjour Awa ! ») ; la
/// phase 3 s'en servira pour rattacher les résultats au bon enfant.
class EnfantActif {
  const EnfantActif({required this.id, required this.prenom});

  final int id;
  final String prenom;

  Map<String, Object?> toJson() => {'id': id, 'prenom': prenom};

  factory EnfantActif.fromJson(Map<String, dynamic> json) =>
      EnfantActif(id: (json['id'] as num).toInt(), prenom: json['prenom'] as String);
}

class Preferences {
  Preferences([SharedPreferencesAsync? stockage]) : _stockage = stockage ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _stockage;

  static const _cleClasse = 'classe_id';
  static const _cleDerniereLecon = 'derniere_lecon';
  static const _cleEnfantActif = 'enfant_actif';

  /// Les préférences ne doivent jamais bloquer l'application : en cas
  /// d'erreur du stockage, on fait comme s'il était vide.
  Future<int?> classeChoisie() async {
    try {
      return await _stockage.getInt(_cleClasse);
    } catch (_) {
      return null;
    }
  }

  Future<void> choisirClasse(int classeId) async {
    try {
      await _stockage.setInt(_cleClasse, classeId);
    } catch (_) {
      // Sans gravité : la préférence ne sera simplement pas retenue.
    }
  }

  Future<DerniereLecon?> derniereLecon() async {
    try {
      final texte = await _stockage.getString(_cleDerniereLecon);
      if (texte == null) return null;
      return DerniereLecon.fromJson(jsonDecode(texte) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> memoriserLecon(DerniereLecon lecon) async {
    try {
      await _stockage.setString(_cleDerniereLecon, jsonEncode(lecon.toJson()));
    } catch (_) {
      // Sans gravité : la préférence ne sera simplement pas retenue.
    }
  }

  Future<EnfantActif?> enfantActif() async {
    try {
      final texte = await _stockage.getString(_cleEnfantActif);
      if (texte == null) return null;
      return EnfantActif.fromJson(jsonDecode(texte) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Retient [enfant] comme profil de ce téléphone ; `null` l'oublie (à la
  /// déconnexion, ou quand le profil est supprimé).
  Future<void> choisirEnfant(EnfantActif? enfant) async {
    try {
      if (enfant == null) {
        await _stockage.remove(_cleEnfantActif);
      } else {
        await _stockage.setString(_cleEnfantActif, jsonEncode(enfant.toJson()));
      }
    } catch (_) {
      // Sans gravité : la préférence ne sera simplement pas retenue.
    }
  }
}
