import 'package:flutter/widgets.dart';

import '../data/data.dart';
import 'services/preferences.dart';

/// Donne accès au dépôt Supabase et aux préférences dans tout l'arbre de widgets.
///
/// À lire dans `didChangeDependencies` ou `build`, pas dans `initState`.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repository,
    required this.preferences,
    required super.child,
  });

  final SamaClasseRepository repository;
  final Preferences preferences;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope introuvable au-dessus de ce widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repository != oldWidget.repository || preferences != oldWidget.preferences;
}
