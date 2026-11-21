import 'package:flutter/widgets.dart';

import '../data/data.dart';
import 'services/choix_image.dart';
import 'services/impression.dart';
import 'services/moteur_vocal.dart';
import 'services/partage.dart';
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
    required this.redaction,
    required this.signalement,
    this.choixImage = const ChoixImageSysteme(),
    this.creerMoteurVocal = MoteurFlutterTts.new,
    this.partage = const PartageSysteme(),
    this.impression = const ImpressionSysteme(),
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

  /// Validation et publication des leçons (phase 4), pour les rédacteurs.
  final Redaction redaction;

  /// « Signaler une erreur » (D38) : ouvert à tous, même sans compte. Un
  /// faux dans les tests.
  final EnvoiSignalement signalement;

  /// Appareil photo et galerie, pour ajouter un schéma à une leçon
  /// (rédacteurs, phase 5). Remplacé par un faux dans les tests.
  final ChoixImage choixImage;

  /// Fabrique du moteur de synthèse vocale de « Écouter la leçon » : un
  /// moteur par écran de leçon, détruit avec lui. Un faux dans les tests.
  final MoteurVocal Function() creerMoteurVocal;

  /// « Envoyer cette leçon » (D35) : partage du système, presse-papiers.
  /// Un faux dans les tests.
  final Partage partage;

  /// « Fiche à imprimer » (D35) : aperçu d'impression du système. Un faux
  /// dans les tests.
  final Impression impression;

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
      suivi != oldWidget.suivi ||
      redaction != oldWidget.redaction ||
      signalement != oldWidget.signalement ||
      choixImage != oldWidget.choixImage ||
      creerMoteurVocal != oldWidget.creerMoteurVocal ||
      partage != oldWidget.partage ||
      impression != oldWidget.impression;
}
