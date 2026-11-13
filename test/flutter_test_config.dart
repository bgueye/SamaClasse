// Réglages communs à tous les tests de test/ (fichier lu par `flutter test`).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Un tap qui tombe à côté de sa cible (élément hors de l'écran, caché par un
  // autre) ne donne par défaut qu'un avertissement : le test continue comme
  // si l'élève avait touché, et échoue plus loin pour une raison obscure.
  // On en fait une erreur immédiate et claire.
  WidgetController.hitTestWarningShouldBeFatal = true;
  await testMain();
}
