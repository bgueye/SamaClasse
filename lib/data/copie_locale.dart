// Copie locale du contenu publié, gardée sur l'appareil (décision D16).
//
// Stockage : `shared_preferences`, déjà utilisé pour les préférences ; pas de
// nouvelle dépendance. Une seule entrée JSON, environ 50 Ko au 13/11/2026.
// Comme pour `Preferences`, une erreur de stockage ne bloque jamais
// l'application : sans copie lisible, on fait comme s'il n'y en avait pas.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'instantane.dart';

/// Le contenu et la date à laquelle il a été téléchargé.
class CopieContenu {
  const CopieContenu({required this.contenu, required this.telechargeeLe});

  final Instantane contenu;
  final DateTime telechargeeLe;
}

/// Où la copie est gardée. Interface pour la remplacer dans les tests.
abstract interface class StockageCopie {
  /// La copie enregistrée, ou `null` s'il n'y en a pas (ou si elle est illisible).
  Future<CopieContenu?> lire();

  Future<void> ecrire(CopieContenu copie);
}

class CopieLocale implements StockageCopie {
  CopieLocale([SharedPreferencesAsync? stockage]) : _stockage = stockage ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _stockage;

  /// Le numéro de version dans la clé permet de changer de format plus tard :
  /// une ancienne copie est alors simplement ignorée, puis remplacée.
  static const _cle = 'contenu_v1';

  @override
  Future<CopieContenu?> lire() async {
    try {
      final texte = await _stockage.getString(_cle);
      if (texte == null) return null;
      return decoderCopie(texte);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> ecrire(CopieContenu copie) async {
    try {
      await _stockage.setString(_cle, encoderCopie(copie));
    } catch (_) {
      // Sans gravité : la copie sera simplement retéléchargée au prochain lancement.
    }
  }
}

/// Format enregistré : `{"telechargee_le": "…", "contenu": {…}}`.
String encoderCopie(CopieContenu copie) => jsonEncode({
      'telechargee_le': copie.telechargeeLe.toIso8601String(),
      'contenu': copie.contenu.toJson(),
    });

/// Lève une erreur si le texte n'est pas une copie valide.
CopieContenu decoderCopie(String texte) {
  final json = jsonDecode(texte) as Map<String, dynamic>;
  return CopieContenu(
    contenu: Instantane.fromJson(json['contenu'] as Map<String, dynamic>),
    telechargeeLe: DateTime.parse(json['telechargee_le'] as String),
  );
}
