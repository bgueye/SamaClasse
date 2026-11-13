# SamaClasse

Application Flutter du programme scolaire sénégalais : pour chaque classe et
chaque matière, les chapitres du programme, les leçons et leurs exercices
corrigés. Données dans le projet Supabase **samaclasse**
(`earcfeorkfeenqprsxpg`, Paris).

## Installation (Windows)

Prérequis : Flutter 3.32 ou plus récent (`flutter --version`), Android Studio
ou un téléphone Android en mode développeur, et Chrome pour la version web.

1. Décompresser l'archive dans `C:\Dev\projets\SamaClasse` (le fichier
   `pubspec.yaml` doit se trouver directement dans ce dossier).
2. Ouvrir PowerShell dans ce dossier et lancer :

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\installer.ps1
   ```

   Le script génère les dossiers `android`, `ios` et `web`, ajoute la
   permission Internet à l'application Android, télécharge les paquets, puis
   lance l'analyse et les tests.
3. Lancer l'application :

   ```powershell
   flutter run --dart-define-from-file=config/supabase.json
   ```

   Dans VS Code, la configuration « SamaClasse » (touche F5) passe déjà ce
   paramètre ; « SamaClasse (web, Chrome) » ouvre la version web.

Sans le paramètre `--dart-define-from-file`, l'application affiche un écran
« Configuration manquante » au lieu de planter.

### Installation manuelle (sans le script)

```powershell
flutter create . --project-name samaclasse --org sn.samaclasse --platforms android,ios,web --no-pub
flutter pub get
flutter test
```

Puis ajouter dans `android/app/src/main/AndroidManifest.xml`, juste avant
`<application` :

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Documentation

- `CLAUDE.md` : consignes pour Claude Code (commandes, règles, conventions).
- `docs/` : architecture, base de données, design, exercices, contenu,
  feuille de route, décisions.
- `supabase/migrations/` : SQL du schéma, identique à la base.

## Organisation du code

```
lib/
  main.dart                  démarrage, Supabase, licences des polices
  app.dart                   MaterialApp, thème, français
  router.dart                routes (go_router), aussi valables sur le web
  core/
    config.dart              URL et clé lues depuis config/supabase.json
    app_scope.dart           accès au dépôt et aux préférences
    services/preferences.dart  classe choisie, dernière leçon ouverte (sur l'appareil)
    theme/                   couleurs « cahier », couleur de chaque matière, thème
    widgets/                 page Seyès, Markdown, états (chargement, erreur, vide)…
  data/                      modèles, dépôt Supabase (lecture seule), correction automatique
  features/
    accueil/                 choix de la classe, reprise, liste des matières
    matiere/                 chapitres regroupés par partie, filtre « Leçons prêtes »
    lecon/                   page de cahier : « La leçon » et « À retenir »
    exercices/               un exercice par écran, correction, bilan final
      saisies/               zone de réponse par type d'exercice
test/                        tests sans réseau (données, outils, widgets)
assets/fonts/                Atkinson Hyperlegible Next, Playwrite FR Moderne (licence OFL)
config/supabase.json         URL du projet et clé publishable
```

| Route | Écran |
| --- | --- |
| `/` | Accueil : classe, reprise, matières |
| `/classe/:classeId/matiere/:matiereId` | Chapitres d'une matière |
| `/lecon/:leconId` | Leçon |
| `/lecon/:leconId/exercices` | Exercices de la leçon |

## Exercices

| Type | Saisie | Correction |
| --- | --- | --- |
| QCM | une réponse à toucher par question | automatique |
| Vrai ou faux | Vrai / Faux par affirmation | automatique |
| Relier | choix dans une liste pour chaque élément | automatique |
| Tableau (liste) | une case par réponse | automatique |
| Tableau (classement) | une catégorie par élément | automatique |
| Calcul | un champ par valeur attendue | automatique (« 8,0 » vaut 8) |
| Autres (question de cours, rédaction, documents, expérience, épreuve) | brouillon libre | l'élève compare avec le corrigé et dit s'il avait juste |

Les réponses ne sont pas enregistrées : elles restent en mémoire le temps de
la série d'exercices.

## Sécurité et clés

La clé de `config/supabase.json` est une clé **publishable**, faite pour être
embarquée dans l'application. La protection des données repose sur les règles
RLS de la base : le programme est en lecture publique, et seules les leçons au
statut `publiee` (et leurs exercices) sont visibles. Aujourd'hui, une seule
leçon est publiée (Introduction aux sciences physiques, 4ème) : les autres
matières affichent leurs chapitres, avec « Leçon pas encore disponible ».

## Pas encore couvert

- Comptes et rôles (élève, parent, rédacteur) avec Supabase Auth.
- Enregistrement des réponses et écran « Progrès » pour les parents.
- Écran de validation et de publication des leçons (rédacteur).
- Lecture à voix haute de la leçon (bouton prévu dans les maquettes).

## Paquets

`supabase_flutter` ^2.17.1 (paramètre `publishableKey` ; la v3 n'existe
qu'en préversion `3.0.0-dev` au 13/11/2026, dernière stable 2.18.3), `go_router`, `flutter_markdown_plus`,
`shared_preferences`, `flutter_localizations`. Vérifier les mises à jour avec
`flutter pub outdated`.
