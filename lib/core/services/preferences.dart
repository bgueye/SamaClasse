// Préférences gardées sur l'appareil : classe choisie et dernière leçon
// ouverte (pour « Reprendre où tu t'es arrêté »). Rien n'est envoyé au serveur.

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

class Preferences {
  Preferences([SharedPreferencesAsync? stockage]) : _stockage = stockage ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _stockage;

  static const _cleClasse = 'classe_id';
  static const _cleDerniereLecon = 'derniere_lecon';

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
}
