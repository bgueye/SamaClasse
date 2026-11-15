# SamaClasse : consignes pour Claude Code

Application Flutter (Android, iOS, web) du programme scolaire sénégalais : pour
chaque classe et chaque matière, les chapitres du programme, les leçons et leurs
exercices corrigés. Publics : élèves (collège, lycée), parents, enseignants.
Données dans Supabase (projet `samaclasse`, ref `earcfeorkfeenqprsxpg`, Paris).
Développeur et propriétaire : Bocar Gueye. Démarrage avec deux classes : 4ème et
Seconde L.

Toute l'interface, les commentaires et les messages de commit sont en **français**.

## Commandes

```powershell
flutter pub get
flutter analyze                                          # doit finir sans erreur ni avertissement
flutter test                                             # tous les tests, sans réseau
flutter run --dart-define-from-file=config/supabase.json # lancer (F5 dans VS Code)
flutter run -d chrome --dart-define-from-file=config/supabase.json
```

Premier lancement sur une machine : `powershell -ExecutionPolicy Bypass -File .\installer.ps1`
(génère android/ios/web, ajoute la permission INTERNET Android, lance les tests).

## Avant de dire qu'une tâche est finie

1. `flutter analyze` sans erreur ni avertissement.
2. `flutter test` vert ; un test ajouté ou mis à jour pour toute logique pure
   (données, correction, regroupement, formatage).
3. Pour un écran : vérifier les quatre états (chargement, erreur avec
   « Réessayer », vide, contenu) et l'affichage sur téléphone (390 px) et sur le
   web large.
4. Pour un changement de base : migration dans `supabase/migrations/`, testée
   en rôle `anon` (et `authenticated` si concerné), puis conseillers de sécurité
   Supabase sans alerte.

## État du code (14/11/2026)

- **Phase 0 terminée** (13/11/2026) : le squelette compile, vérifié à la main
  sur Android (Galaxy S23 Ultra, Android 17) et sur Chrome.
- **Phase 1 terminée côté code** (14/11/2026), détail et état dans
  `docs/FEUILLE_DE_ROUTE.md` :
  - hors connexion : copie locale du contenu publié (D16), vérifiée en mode avion ;
  - libellés des catégories des tableaux (D14) ;
  - polices de secours pour les symboles absents (D17) ;
  - page « À propos » (D18) ;
  - icône et écran de lancement, variante « Couverture » (D19), générés depuis
    `assets/icone/` (marche à suivre dans `docs/ARCHITECTURE.md`) ;
  - schémas des leçons (D15) : espace de stockage public `schemas` (migration
    `stockage_schemas`) et affichage par `SchemaCahier` ; seules les images de
    cet espace sont chargées, sinon la description s'affiche.
- Reste à vérifier par Bocar : l'icône et l'écran de lancement sur le
  téléphone, un schéma réel déposé dans `schemas`, les libellés des tableaux
  17 et 31 à compléter en base.
- Prochaine étape : la phase 2 (comptes et rôles), qui attend les décisions
  de Bocar sur la connexion des élèves mineurs et la méthode de connexion
  (« Décisions ouvertes » 4 et 5).
- `flutter analyze` : aucun problème ; `flutter test` : 147/147, sans réseau
  (tests d'écrans sur la vraie application avec `test/outils/faux_depot.dart`
  et `FauxCompte`, alignement Seyès, puces, hors connexion, schémas, compte).
- Pour un nouvel écran : ajouter ses cas à `test/features/ecrans_test.dart`
  (quatre états, 200 %) et le regarder avec `tool/captures/captures_test.dart`.
- Écrans livrés : accueil, matière, leçon, exercices, « À propos », « Espace
  parents ». La lecture ne demande jamais de compte.
- 10 leçons sur 13 sont publiées en base (14/11/2026) : c'est normal que les
  autres affichent « Leçon pas encore disponible ».
- Phase 2 en cours : tables `enfants` et `redacteurs` (migration
  `comptes_parents_enfants`, D21 à D23) et « Espace parents » (`/compte` :
  connexion par code e-mail, profils enfants), essayé avec succès sur le
  téléphone le 15/11/2026. E-mails envoyés par Gmail pour les essais (D22).
- Dépôt distant : `origin` = https://github.com/bgueye/SamaClasse (branche
  `main`). Toujours demander avant de pousser.

## Règles impératives

- **Ne jamais contourner les règles RLS.** L'application n'utilise que la clé
  publishable (`config/supabase.json`). Aucune clé `service_role` / secrète dans
  le code, les tests, les scripts ou le dépôt.
- **Ne jamais modifier le contenu pédagogique** (leçons, exercices, chapitres)
  ni changer un statut de leçon sans demande explicite de Bocar. En particulier,
  ne jamais passer une leçon à `publiee` : c'est lui qui publie, après
  vérification sur les cahiers. Ne rien ajouter à la base sans lui demander.
- **Ne pas modifier le schéma sans accord** : proposer la migration, expliquer
  son effet sur les règles RLS, attendre la validation.
- Garder l'application **simple** : pas de nouvelle dépendance ni de couche
  d'architecture (Riverpod, Bloc, génération de code…) sans en discuter. Les
  évolutions lourdes vont dans une version ultérieure.
- Ne pas mettre de notes de travail visibles des élèves dans les textes
  affichés (« à vérifier », « Note : »…).
- Respecter `docs/DESIGN.md` : couleurs via `Couleurs`, styles via `Styles`,
  jamais de couleur en dur dans un écran ; cibles tactiles ≥ 44 px ; contraste
  ≥ 4,5:1 ; l'état juste/faux jamais signalé par la couleur seule.

## Conventions de code

- Dart ≥ 3.8, Flutter ≥ 3.32. Lints : `analysis_options.yaml` (flutter_lints +
  guillemets simples, `const`, `final`).
- Noms en français (`chargerClasses`, `MessageVide`, `regrouperParPartie`) ;
  champs Dart en camelCase, colonnes SQL en snake_case.
- État : `StatefulWidget` + `FutureBuilder`, le `Future` créé une seule fois
  (dans `didChangeDependencies` avec `??=`), jamais dans `build`. Pour relancer :
  `setState(() { _chargement = _charger(); });` (corps en bloc : un `setState`
  ne doit pas renvoyer de `Future`).
- Accès aux données uniquement par `SamaClasseRepository` (`lib/data/`), obtenu
  par `AppScope.of(context)`. Pas d'appel `Supabase.instance` dans les écrans.
  Dans l'application, c'est `ContenuHorsLigne` (copie locale synchronisée,
  D16) ; les requêtes Supabase sont dans `TelechargementSupabase`.
- Un écran de lecture se recharge seul quand du contenu nouveau arrive
  (`with RechargeSiNouveauContenu`) ; jamais l'écran d'exercices.
- Logique pure (correction, libellés, regroupements) hors des widgets, dans des
  fonctions testables.
- Navigation : go_router, routes déclarées dans `lib/router.dart`, adresses
  valables sur le web (paramètres d'URL, `extra` seulement comme raccourci avec
  rechargement de secours).
- Textes : tutoiement de l'élève, phrases courtes, apostrophe typographique (’)
  dans les chaînes affichées, espaces avant « : ».

## Où trouver quoi

| Sujet | Document |
| --- | --- |
| Dossiers, couches, recettes (ajouter un écran, une requête) | `docs/ARCHITECTURE.md` |
| Tables, énumérations, RLS, formats JSON, migrations | `docs/BASE_DE_DONNEES.md` |
| Charte « cahier d'écolier », composants, accessibilité, maquettes | `docs/DESIGN.md` |
| Types d'exercices : données, saisie, correction | `docs/EXERCICES.md` |
| Règles éditoriales et cycle de publication des leçons | `docs/CONTENU.md` |
| Étapes suivantes, critères d'acceptation, décisions ouvertes | `docs/FEUILLE_DE_ROUTE.md` |
| Décisions déjà prises et leurs raisons | `docs/DECISIONS.md` |

## Supabase

- Si le serveur MCP Supabase est disponible : `list_tables`, `execute_sql` pour
  lire, `apply_migration` pour une migration validée, `get_advisors` après.
  Sinon : Supabase CLI (`supabase migration new <nom>`, `supabase db push`).
- Tester une règle RLS en se mettant à la place du client :
  `begin; set local role anon; select …; rollback;`
- Après une migration, recopier le fichier SQL dans `supabase/migrations/`
  (même horodatage que dans la base) pour que le dépôt reste la référence.
