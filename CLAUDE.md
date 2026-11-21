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

## État du code (20/11/2026)

- **Phases 0 à 4 terminées côté code**, chacune essayée avec succès sur le
  téléphone (Galaxy S23 Ultra, Android 17). Détail, décisions et état dans
  `docs/FEUILLE_DE_ROUTE.md` et `docs/DECISIONS.md` (D14 à D30).
  - Phase 1, lecture : hors connexion (D16), catégories des tableaux (D14),
    polices de secours (D17), « À propos » (D18), icône et écran de
    lancement (D19), schémas des leçons dans l'espace public `schemas` (D15).
  - Phase 2, comptes : seul le parent a un compte, connexion par code reçu
    par e-mail (D22), profils enfants sans identifiants (D21), rédacteurs
    attribués à la main (D23). E-mails envoyés par Resend depuis
    `noreply@samaclasse.app` ; les modèles « Confirm signup » et « Magic
    Link » de Supabase contiennent tous deux `{{ .Token }}`.
  - Phase 3, suivi : leçons lues et résultats des exercices, gardés hors
    connexion puis envoyés (`lib/data/suivi.dart`, D24) ; écran « Suivi de mes
    enfants ». Jamais le texte saisi par l'élève.
  - Phase 4, validation : écran « Leçons à vérifier » (rédacteurs) ; lever
    un point demande une réponse si c'est une question ; historique dans
    `points_leves` (D25) ; publication par la fonction `publier_lecon` ;
    lien vers l'artefact par `url_launcher` (D26). Bocar est rédacteur.
- **Phase 5, diffusion, en cours** (D27 à D33) :
  - fait : identifiant `sn.samaclasse.app` (D28), « Supprimer mon compte »
    (fonction `supprimer_mon_compte`), site https://samaclasse.app sur
    Cloudflare Pages publié par `.github/workflows/site.yml` après les
    tests (D29), `contact@samaclasse.app` (D30), envoi des e-mails par
    Resend (D22), schémas ajoutés depuis l'application par les rédacteurs
    (écran « Schémas de la leçon », `ajouter_schema`, D31), téléphones des
    enfants liés par un code du parent (session anonyme limitée au profil,
    `lib/data/liaison.dart`, D32), corrections des leçons publiées avec
    versions et rôle validateur (D33), « Écouter la leçon » : barre de
    lecture du script oral `lecons.script_audio` par `flutter_tts`
    (`lib/features/lecon/lecteur_lecon.dart`, D34 ; seule la leçon 28 a un
    script ; à essayer sur le téléphone), « Écouter l’essentiel » (même
    barre sur l'onglet « À retenir », colonne `lecons.script_retenir`, D37 ;
    aucun script rédigé pour l'instant) ;
  - signature Android faite le 21/11/2026 : clé d'envoi hors du dépôt,
    lue par `android/key.properties` (ignoré par git), procédure dans
    `docs/ARCHITECTURE.md`, « Signature Android » ;
  - reste : fiche Play Store et test fermé.
- **« Signaler une erreur »** fait le 21/11/2026 (D38) : ouvert à tous, même
  sans compte, par la fonction `signaler_erreur` (5 envois par heure par
  session ou adresse IP, 100 en tout) ; aucune identité gardée ; lu et
  traité par les rédacteurs (section « Erreurs signalées » de « Leçons à
  vérifier », `traiter_signalement`), mentionné dans la page de
  confidentialité. Reste : essai sur le téléphone.
- **Scripts « À retenir »** (D37) : en base pour les 23 leçons (lots 1 et 2
  le 21/11/2026) ; brouillons dans `contenu/scripts_retenir/`, qui restent
  la référence. Reste : les écouter sur le téléphone.
- **« Voir un indice »** fait côté code le 21/11/2026 (D39) : colonne
  facultative `exercices.indice`, un indice par exercice, sans effet sur le
  suivi. Indices en base pour les 126 exercices (brouillons dans
  `contenu/indices/`, requêtes d'écriture et de contrôle générées par
  `tool/indices/generer_requete.ps1`). Reste : essayer sur le téléphone.
- **Idées D35, à reprendre** : révision du BFEM et programme d'une matière. Liste complète,
  ordre et points ouverts : `docs/FEUILLE_DE_ROUTE.md`, phase 5, « Idées
  pour élèves, parents et enseignants (D35) ».
- Reste à faire par Bocar : photographier les schémas des leçons 8, 9 et
  10 (repères « [Schéma : …] » à retirer ensuite), compléter les libellés
  des tableaux 17 et 31.
- `flutter analyze` : aucun problème ; `flutter test` : 499/499, sans réseau
  (vraie application avec `test/outils/faux_depot.dart` : `FauxDepot`,
  `FauxCompte`, `FauxEnvoi`, `FausseRedaction`, `FauxChoixImage`,
  `FauxMoteurVocal`, `FauxPartage`, `FausseImpression`, `FauxSignalement`).
- Pour un nouvel écran : ses quatre états et 200 % dans un test d'écran
  (`test/features/`), et un coup d'œil avec `tool/captures/captures_test.dart`.
- Écrans livrés : accueil, matière, leçon, exercices, « À propos », « Espace
  parents », « Suivi de mes enfants », « Leçons à vérifier », « Schémas de
  la leçon », « Lier ce téléphone », « Téléphone d'Awa », « Versions de la
  leçon », aperçu d'une correction, « Signaler une erreur » (fenêtre, D38), « Interroge-moi » (cartes de
  révision et mode parent, D35), « Envoyer cette leçon », « Fiche à imprimer »
  (PDF, D36), mode projection (D35). La lecture ne
  demande jamais de compte.
- Les 13 leçons sont publiées (16/11/2026), ainsi que la leçon 28
  (anglais, 4ème, avec un script oral) au 19/11/2026.
- **« Connecté » veut dire « parent connecté »** (`compte.estConnecte`) ; une
  session anonyme (téléphone d'enfant, D32) a `estAnonyme` vrai et
  `estConnecte` faux. Le suivi part pour l'une ou l'autre.
- **Corriger une leçon publiée** (D33) : à la demande de Bocar, écrire le
  texte corrigé dans `corrections_lecons` (la correction ouverte de la
  leçon), **jamais directement dans `lecons`** ; c'est un validateur qui le
  met en ligne depuis l'application. Procédure : `docs/CONTENU.md`.
- Base : 15 migrations, de `schema_programme_lecons` à `exercices_indice`.
  Bocar est rédacteur et validateur. Conseiller de sécurité, attendu : les
  fonctions `security definer` appelables par `authenticated` (contrôles
  faits dans les fonctions), `signaler_erreur` appelable par `anon`
  (voulu, D38), « RLS sans règle » sur `codes_liaison`, `essais_liaison`
  et `envois_signalements` (voulu), « Anonymous Access Policies »
  (sessions anonymes activées ; règles vérifiées, voir
  `docs/BASE_DE_DONNEES.md`).
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
  affichés (« à vérifier », « Note : »…). `points_a_verifier`,
  `artefact_url` et `points_leves` ne s'affichent que dans l'écran des
  rédacteurs.
- **Le contenu des élèves filtre lui-même `statut = 'publiee'`**
  (`TelechargementSupabase`, puis `Instantane.seulementPublie`) : depuis la
  phase 4, un rédacteur connecté lit aussi les leçons non publiées. Ne jamais
  retirer ce filtre en comptant sur les seules règles RLS.
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
| Fiche Google Play, sécurité des données, classification | `docs/PLAY_STORE.md` |

## Supabase

- Si le serveur MCP Supabase est disponible : `list_tables`, `execute_sql` pour
  lire, `apply_migration` pour une migration validée, `get_advisors` après.
  Sinon : Supabase CLI (`supabase migration new <nom>`, `supabase db push`).
- Tester une règle RLS en se mettant à la place du client :
  `begin; set local role anon; select …; rollback;`
- Pour un test qui écrit (comptes ou leçons fictifs) : tout mettre dans un
  bloc `do $$ … $$` qui se termine par `raise exception` avec le journal des
  résultats. L'erreur annule forcément toute la transaction ; vérifier
  ensuite qu'il ne reste rien. Ne jamais publier une vraie leçon pour un
  test : en créer une fictive dans le bloc.
- Après une migration, recopier le fichier SQL dans `supabase/migrations/`
  (même horodatage que dans la base) pour que le dépôt reste la référence.
