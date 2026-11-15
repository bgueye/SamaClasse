# Architecture

## Vue d'ensemble

```
Écran (StatefulWidget + FutureBuilder)
   │  AppScope.of(context)
   ▼
SamaClasseRepository (contrat)  =  ContenuHorsLigne
   │                                  │  copie locale (shared_preferences)
   │                                  │  + synchronisation en arrière-plan
   │                                  ▼
   │                          TelechargementSupabase ──► Supabase (clé publishable, RLS)
   ▼
Modèles (fromJson)  ──►  fonctions pures (correction, libellés, regroupements)
```

Hors connexion (décision D16) : tout le contenu publié (environ 50 Ko) est
téléchargé en quatre requêtes et gardé sur l'appareil. Les écrans lisent cette
copie (affichage immédiat) ; une synchronisation la met à jour au lancement et
quand on tire pour actualiser. Si le contenu a changé, `etat.version` augmente
et les écrans ouverts se rechargent (`RechargeSiNouveauContenu`, sauf l'écran
d'exercices pour ne pas effacer les réponses). Sans réseau, le bandeau
`BandeauHorsConnexion` l'indique. Sans copie ni réseau (premier lancement),
l'écran affiche l'erreur et « Réessayer ».

Trois couches seulement, volontairement :

1. **Données** (`lib/data/`) : modèles immuables construits depuis le JSON de
   Supabase, le contenu hors connexion et son téléchargement, la correction
   des exercices.
2. **Noyau** (`lib/core/`) : configuration, thème, préférences locales,
   composants partagés.
3. **Fonctionnalités** (`lib/features/<nom>/`) : un dossier par écran ou groupe
   d'écrans, avec ses widgets et ses fonctions pures.

Pas de gestionnaire d'état externe. Le compte parent (phase 2) suit la piste
prévue : un `ChangeNotifier` (`Compte`) exposé par `AppScope`, que les écrans
écoutent avec un `ListenableBuilder`. Pour un autre besoin d'état partagé
(progression…), même piste ; en discuter avant d'ajouter une dépendance.

## Arborescence

```
lib/
  main.dart                     Supabase.initialize, AppScope, licences des polices,
                                écran « Configuration manquante » si pas de clés
  app.dart                      MaterialApp.router, thème, localisation fr
  router.dart                   routes go_router + PageIntrouvable
  core/
    config.dart                 SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY (dart-define)
    version.dart                version affichée, à garder égale à pubspec.yaml (testé)
    app_scope.dart              InheritedWidget : repository + preferences + compte + suivi
                                + redaction
    services/preferences.dart   SharedPreferencesAsync : classe choisie, dernière leçon,
                                profil enfant de ce téléphone (EnfantActif)
    theme/couleurs.dart         palette (voir DESIGN.md)
    theme/matieres.dart         couleur de protège-cahier par slug de matière
    theme/theme.dart            ThemeData, Styles, interligne Seyès (32 px)
    widgets/composants.dart     DosCahier, LienRetour, ControleSegmente, LargeurLecture
    widgets/etats.dart          Chargement, MessageErreur, MessageVide
    widgets/page_seyes.dart     page de cahier défilante (lignes + marge)
    widgets/markdown_cahier.dart rendu Markdown des leçons et exercices
    widgets/schema_cahier.dart  schémas insérés dans le Markdown (D15) : filtre d'adresse, description de secours
  data/
    models.dart                 Classe, MatiereDeClasse, Chapitre, LeconResume, Lecon,
                                Exercice, ElementARetenir, ContexteLecon + énumérations
    samaclasse_repository.dart  contrat des écrans : classes(), matieres(), chapitres(),
                                lecon(), etat, actualiser() ; EtatContenu
    contenu_hors_ligne.dart     ContenuHorsLigne : copie locale + synchronisation (D16)
    telechargement_supabase.dart les quatre requêtes Supabase (colonnes explicites)
    instantane.dart             tout le contenu publié en JSON brut, lecture par écran
    copie_locale.dart           enregistrement sur l'appareil (clé contenu_v1)
    correction.dart             corriger(), estAutoCorrigeable(), normaliser()…
    compte.dart                 Enfant, Compte (contrat, ChangeNotifier), CompteSupabase :
                                connexion par code e-mail (D22), table enfants (D21)
    redaction.dart              Redaction, RedactionSupabase : leçons à vérifier, points
                                levés (D25), publication par publier_lecon (phase 4)
    suivi.dart                  SuiviResultats : lectures et résultats de l'enfant de ce
                                téléphone, file d'attente locale, envoi au retour du réseau (D24)
    data.dart                   export groupé
  features/
    a_propos/a_propos_screen.dart     présentation, version, licences, crédit (D18)
    accueil/accueil_screen.dart       classe, reprise, matières, « Bonjour Awa ! »,
                                      boutons « Espace parents » et « À propos »
    compte/compte_screen.dart         espace parents : connexion (e-mail puis code),
                                      « Mes enfants » (vouvoiement : public parents)
    compte/fiche_enfant.dart          fiche prénom + classe (boîte de dialogue)
    compte/outils_compte.dart         validation des saisies, messageErreurCompte()
    suivi/suivi_screen.dart           « Suivi de mes enfants » (maquette Parent, phase 3)
    suivi/statistiques.dart           debutSemaine(), bilanSemaine(), derniersExercices()…
    validation/validation_screen.dart « Leçons à vérifier » (maquette Validation, rédacteurs)
    validation/outils_validation.dart pointsRestants(), resumeValidation(), messages d'erreur
    matiere/matiere_screen.dart       chapitres par partie, filtre
    matiere/regroupement.dart         regrouperParPartie(), etatChapitre()
    lecon/lecon_screen.dart           onglets « La leçon » / « À retenir »
    exercices/exercices_screen.dart   série d'exercices, bilan
    exercices/outils_exercices.dart   reponseInitiale(), libelleChemin()…
    exercices/saisies/                une zone de réponse par type (voir EXERCICES.md)
test/
  data/                         modèles et correction, sur de vrais exercices
  features/                     fonctions pures des écrans
  features/ecrans_test.dart     les quatre écrans : états, parcours, débordements à 200 %
  features/hors_connexion_test.dart bandeau, mode avion, mise à jour automatique des écrans
  features/puces_test.dart      lisibilité des puces de choix
  features/compte_test.dart     espace parents : saisies, erreurs, écrans, 200 %
  features/suivi_test.dart      suivi des enfants : semaine, derniers exercices, écran, 200 %
  features/validation_test.dart validation : points, publication, rôle, écran, 200 %
  data/contenu_hors_ligne_test.dart synchronisation, copie locale, erreurs réseau
  data/suivi_test.dart          file d'attente du suivi : hors connexion, doublons, refus, écrans
  core/seyes_test.dart          alignement du texte sur les lignes Seyès (vraies polices)
  outils/faux_depot.dart        FauxDepot, FaussesPreferences, FauxCompte, FauxEnvoi, FausseRedaction,
                                FauxStockageFile, lancerApp(),
                                FausseSource, FauxStockage, instantaneReel()
  outils/polices.dart           chargement des vraies polices dans un test
  fixtures/supabase.json        réponses Supabase réelles (rôle anon, sans artefact_url)
  widget_test.dart              composants et zones de réponse
  flutter_test_config.dart      réglage commun : un tap qui manque sa cible fait échouer le test
tool/captures/                  captures d'écran (flutter test tool/captures/…), images dans build/captures/
tool/polices/sous_ensembles.py  fabrique les polices de secours (Python + fontTools, D17)
tool/icone/icone_test.dart      dessine l'icône (D19) → assets/icone/, puis
                                dart run flutter_launcher_icons && dart run flutter_native_splash:create
assets/icone/                   images sources de l'icône et de l'écran de lancement
flutter_launcher_icons.yaml,
flutter_native_splash.yaml      réglages des deux générateurs (dépendances de développement)
supabase/migrations/            SQL du schéma, identique à la base
config/supabase.json            URL + clé publishable (publique par nature)
assets/fonts/                   polices embarquées (dont les polices de secours, D17) + licences OFL
```

## Routes

| Adresse | Écran | Données chargées |
| --- | --- | --- |
| `/` | `AccueilScreen` | `classes()`, puis `matieres(classeId)` ; préférences locales |
| `/classe/:classeId/matiere/:matiereId` | `MatiereScreen` | `classes()`, `matieres()`, `chapitres()` en parallèle |
| `/lecon/:leconId` | `LeconScreen` | `lecon(id)` ; mémorise la dernière leçon |
| `/lecon/:leconId/exercices` | `ExercicesScreen` | la `Lecon` passée en `extra`, sinon `lecon(id)` |
| `/a-propos` | `AProposScreen` | aucune (page fixe : présentation, version, licences, D18) |
| `/compte` | `CompteScreen` | connexion si pas de compte ; sinon `compte.enfants()` et `classes()` |
| `/validation` | `ValidationScreen` | `redaction.estRedacteur()`, puis `leconsAVerifier()` et `pointsLeves()` |
| `/suivi` | `SuiviScreen` | envoie d'abord la file du suivi, puis `compte.enfants()`, `lectures()`, `resultats()`, `classes()`, `lecons()` |

Règles :
- Les identifiants viennent de l'URL ; un identifiant non numérique affiche
  `PageIntrouvable`.
- `extra` n'est qu'un raccourci : l'écran doit savoir recharger ses données
  (ouverture directe d'une adresse sur le web, rechargement de la page).
- Retour : `LienRetour` fait `pop()` s'il y a un écran précédent, sinon `go()`
  vers une adresse de repli.

## Modèle d'écran

```dart
class XScreen extends StatefulWidget { … }

class _XScreenState extends State<XScreen> {
  Future<Donnees>? _chargement;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chargement ??= _charger();            // une seule fois
  }

  Future<Donnees> _charger() async {
    final repo = AppScope.of(context).repository;   // lu avant tout await
    return …;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: FutureBuilder<Donnees>(
            future: _chargement,
            builder: (context, instantane) {
              if (instantane.hasError) {
                return MessageErreur(
                  erreur: instantane.error!,
                  onReessayer: () => setState(() { _chargement = _charger(); }),
                );
              }
              if (!instantane.hasData) return const Chargement();
              // contenu, ou MessageVide si la liste est vide
            },
          ),
        ),
      );
}
```

- Envelopper le contenu dans `LargeurLecture` (720 px maximum) pour le web et
  les tablettes.
- Listes longues : `ListView.builder` / `SliverList`, avec `RefreshIndicator`.
- Jamais de `BuildContext` utilisé après un `await` sans vérifier `mounted`.

## Recettes

### Ajouter une requête

1. Ajouter les colonnes ou la table à `TelechargementSupabase.telechargerTout`
   (sélection explicite des colonnes, jamais de données de rédaction, tri
   explicite avec `order` et `referencedTable`), puis la lecture dans
   `Instantane` et, si l'écran en a besoin, la méthode dans le contrat
   `SamaClasseRepository` (et `ContenuHorsLigne`, `FauxDepot`).
   Changer la forme de l'instantané impose de passer la clé `contenu_v1` à
   `contenu_v2` dans `copie_locale.dart` (les anciennes copies sont ignorées).
2. Ajouter ou adapter le modèle (`fromJson`) dans `models.dart`.
3. Ajouter un test de `fromJson` avec la forme réelle de la réponse (la relever
   avec `execute_sql` ou dans le tableau de bord).
4. Vérifier en rôle `anon` que la règle RLS laisse passer ce qu'il faut, et
   seulement ça.

### Ajouter un écran

1. Dossier `lib/features/<nom>/`, écran sur le modèle ci-dessus.
2. Route dans `lib/router.dart`, adresse lisible et en français.
3. Fonctions pures dans un fichier à part, avec tests dans `test/features/`.
4. Vérifier les quatre états et l'accessibilité (voir `DESIGN.md`).

### Ajouter un type d'exercice

Voir `EXERCICES.md`, section « Ajouter un type ».

## Configuration et secrets

- `config/supabase.json` est lu par `--dart-define-from-file`. Il contient
  l'URL et la clé **publishable** : elle est faite pour être embarquée, la
  sécurité repose sur les RLS. Il peut rester dans le dépôt.
- Aucune autre clé dans le dépôt. Si une fonction serveur (Edge Function)
  devient nécessaire, ses secrets vont dans les secrets Supabase.
- Sans configuration, `main.dart` affiche un écran d'explication au lieu de
  planter.

## Dépendances

| Paquet | Usage |
| --- | --- |
| `supabase_flutter` ^2.17.1 | Accès à la base. Le code utilise déjà `publishableKey`. La v3 n'existe qu'en préversion (`3.0.0-dev`, au 13/11/2026 ; dernière stable 2.18.3). Migration à planifier à sa sortie stable, voir FEUILLE_DE_ROUTE. |
| `go_router` | Navigation et adresses web |
| `flutter_markdown_plus` | Texte des leçons, énoncés, corrigés |
| `shared_preferences` (`SharedPreferencesAsync`) | Préférences locales |
| `flutter_localizations` | Textes Material en français |

Toute nouvelle dépendance se discute d'abord (poids de l'application, entretien).
