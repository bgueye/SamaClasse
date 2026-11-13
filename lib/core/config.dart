// Configuration lue au lancement :
//   flutter run --dart-define-from-file=config/supabase.json
//
// La clé publishable est faite pour être embarquée dans l'application :
// la sécurité des données repose sur les règles RLS de la base.

abstract final class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseCle = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get estComplete => supabaseUrl.isNotEmpty && supabaseCle.isNotEmpty;
}
