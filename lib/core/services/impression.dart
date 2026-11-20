// Impression d'un PDF (« Fiche à imprimer », D35).
//
// Derrière une interface, comme ChoixImage : `printing` ouvre l'aperçu
// d'impression du système (Android) ou du navigateur (web), absent de
// `flutter test`. Les tests passent un faux qui fabrique le document sans
// rien ouvrir.

import 'dart:typed_data';

import 'package:printing/printing.dart';

abstract class Impression {
  const Impression();

  /// Ouvre l'aperçu d'impression du document fabriqué par [document]. Depuis
  /// l'aperçu, on peut aussi l'enregistrer en PDF ou l'envoyer.
  Future<void> imprimer({required String nom, required Future<Uint8List> Function() document});
}

/// Aperçu d'impression du système (paquet `printing`).
class ImpressionSysteme extends Impression {
  const ImpressionSysteme();

  @override
  Future<void> imprimer({required String nom, required Future<Uint8List> Function() document}) async {
    // Format fixe (A4) : le document est mis en page une fois pour toutes,
    // quel que soit le papier proposé par l'imprimante.
    await Printing.layoutPdf(name: nom, onLayout: (_) => document());
  }
}
