// SamaClasse : le programme scolaire du Sénégal, leçons et exercices.
//
// Lancer avec :
//   flutter run --dart-define-from-file=config/supabase.json

// foundation.dart fournit LicenseRegistry et LicenseEntryWithLineBreaks,
// qui ne sont pas ré-exportés par material.dart ni services.dart.
import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'core/config.dart';
import 'core/services/preferences.dart';
import 'core/theme/couleurs.dart';
import 'core/theme/theme.dart';
import 'data/data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _enregistrerLicencesPolices();

  if (!Config.estComplete) {
    runApp(const _ConfigurationManquante());
    return;
  }

  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseCle);

  // Contenu disponible hors connexion (D16) : copie locale, mise à jour en
  // arrière-plan. `demarrer()` n'est pas attendu : la lecture de la copie se
  // fait pendant que le premier écran se construit, qui l'attendra au besoin.
  final contenu = ContenuHorsLigne(
    source: TelechargementSupabase(Supabase.instance.client),
    stockage: CopieLocale(),
  )..demarrer().ignore();

  runApp(AppScope(
    repository: contenu,
    preferences: Preferences(),
    child: const SamaClasseApp(),
  ));
}

/// Affiche les licences OFL des polices dans la page « Licences » de Flutter.
void _enregistrerLicencesPolices() {
  LicenseRegistry.addLicense(() async* {
    for (final (police, fichier) in const [
      ('Atkinson Hyperlegible Next', 'atkinson-hyperlegible-next-OFL.txt'),
      ('Playwrite FR Moderne', 'playwrite-fr-moderne-OFL.txt'),
      ('Noto Sans (sous-ensemble)', 'noto-sans-OFL.txt'),
      ('Noto Sans Math (sous-ensemble)', 'noto-sans-math-OFL.txt'),
    ]) {
      final texte = await rootBundle.loadString('assets/fonts/licences/$fichier');
      yield LicenseEntryWithLineBreaks([police], texte);
    }
  });
}

/// Lancement sans --dart-define-from-file : on explique quoi faire au lieu de planter.
class _ConfigurationManquante extends StatelessWidget {
  const _ConfigurationManquante();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeSamaClasse(),
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration manquante',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Couleurs.encre),
                ),
                SizedBox(height: 12),
                Text(
                  'L’adresse et la clé Supabase n’ont pas été fournies. Lance l’application avec :',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                SizedBox(height: 12),
                SelectableText(
                  'flutter run --dart-define-from-file=config/supabase.json',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
