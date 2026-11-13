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

## État du code (13/11/2026)

- Le squelette, écrit sans compilateur, **compile désormais** (13/11/2026) :
  deux imports manquants corrigés (`page_seyes.dart` dans `lecon_screen.dart`,
  `flutter/foundation.dart` dans `main.dart`). `flutter analyze` : aucun
  problème ; `flutter test` : 74/74, dont des tests d'écrans sur la vraie
  application avec un faux dépôt (`test/outils/faux_depot.dart`),
  l'alignement Seyès et la lisibilité des puces. Vérifié à la main sur
  Android (Galaxy S23 Ultra, Android 17) et sur Chrome.
- **Phase 0 terminée** (13/11/2026). Prochaine étape : la phase 1, dont les
  sujets attendent des décisions de Bocar (voir `docs/FEUILLE_DE_ROUTE.md`,
  « Décisions ouvertes »).
- Pour un nouvel écran : ajouter ses cas à `test/features/ecrans_test.dart`
  (quatre états, 200 %) et le regarder avec `tool/captures/captures_test.dart`.
- Écrans livrés : accueil, matière, leçon, exercices. Lecture seule, sans compte.
- Une seule leçon est publiée en base : c'est normal que les autres matières
  affichent « Leçon pas encore disponible ».

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
