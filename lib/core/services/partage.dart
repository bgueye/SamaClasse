// Envoi d'un lien vers une autre application (« Envoyer cette leçon », D35).
//
// Derrière une interface, comme ChoixImage : `share_plus` et le
// presse-papiers passent par des canaux natifs. Les tests passent un faux à
// `AppScope` et vérifient le texte envoyé.

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

abstract class Partage {
  const Partage();

  /// Ouvre la liste « Envoyer avec… » du téléphone (WhatsApp, SMS…), ou le
  /// partage du navigateur sur le web.
  Future<void> envoyer(String texte, {String? sujet});

  /// Copie [texte] dans le presse-papiers.
  Future<void> copier(String texte);
}

/// Partage du système (paquet `share_plus`) et presse-papiers de Flutter.
class PartageSysteme extends Partage {
  const PartageSysteme();

  @override
  Future<void> envoyer(String texte, {String? sujet}) async {
    await SharePlus.instance.share(ShareParams(text: texte, subject: sujet));
  }

  @override
  Future<void> copier(String texte) => Clipboard.setData(ClipboardData(text: texte));
}
