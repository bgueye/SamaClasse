import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/theme.dart';
import 'router.dart';

class SamaClasseApp extends StatefulWidget {
  const SamaClasseApp({super.key, this.emplacementInitial = '/'});

  /// Adresse ouverte au démarrage. Toujours `/` dans l'application ; les tests
  /// d'écrans s'en servent pour ouvrir une page précise avec la vraie
  /// configuration (thème, localisation, routes) plutôt qu'une copie.
  final String emplacementInitial;

  @override
  State<SamaClasseApp> createState() => _SamaClasseAppState();
}

class _SamaClasseAppState extends State<SamaClasseApp> {
  // Créé une seule fois : un routeur recréé à chaque build perdrait la navigation.
  late final GoRouter _routeur = creerRouteur(emplacementInitial: widget.emplacementInitial);

  @override
  void dispose() {
    _routeur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SamaClasse',
      debugShowCheckedModeBanner: false,
      theme: themeSamaClasse(),
      routerConfig: _routeur,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
