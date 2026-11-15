import 'package:flutter/widgets.dart';

import '../data/data.dart';
import 'services/preferences.dart';

/// Donne accès au dépôt Supabase, aux préférences et au compte parent dans
/// tout l'arbre de widgets.
///
/// À lire dans `didChangeDependencies` ou `build`, pas dans `initState`.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repository,
    required this.preferences,
    required this.compte,
    required this.suivi,
    required super.child,
  });

  final SamaClasseRepository repository;
  final Preferences preferences;

  /// Compte parent (phase 2). C'est un `ChangeNotifier` : pour suivre la
  /// connexion et la déconnexion, l'écouter avec un `ListenableBuilder`
  /// (AppScope lui-même ne change pas quand on se connecte).
  final Compte compte;

  /// Lectures et résultats de l'enfant de ce téléphone (phase 3, D24). Les
  /// écrans l'appellent sans attendre : il ne doit jamais gêner l'élève.
  final SuiviResultats suivi;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope introuvable au-dessus de ce widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repository != oldWidget.repository ||
      preferences != oldWidget.preferences ||
      compte != oldWidget.compte ||
      suivi != oldWidget.suivi;
}
