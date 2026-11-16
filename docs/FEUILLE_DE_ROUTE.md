# Feuille de route

Les phases s'enchaînent dans l'ordre. Ne pas commencer une phase avant que la
précédente remplisse ses critères d'acceptation, et ne pas lancer une phase
marquée « décisions ouvertes » avant que Bocar ait tranché.

Les schémas SQL proposés aux phases 2 à 4 sont des **pistes à valider**, pas
des décisions.

---

## Phase 0 : stabiliser le squelette ✅ terminée le 13/11/2026

Critères d'acceptation remplis, vérification sur Android validée par Bocar.
Le détail de l'avancement reste ci-dessous pour mémoire.

Le code a été écrit sans compilateur. Objectif : une application qui compile,
passe ses tests et fonctionne sur Android et sur le web.

Tâches :
1. `installer.ps1` (ou les commandes manuelles du README).
2. `flutter analyze` : corriger jusqu'à zéro erreur et zéro avertissement.
   Les infos de style peuvent rester si elles sont justifiées.
3. `flutter test` : tout vert. Si un test est faux (et non le code), le
   corriger en expliquant pourquoi.
4. `flutter pub outdated` : vérifier que les contraintes se résolvent ;
   signaler les versions majeures disponibles (go_router, supabase_flutter v3
   à sa sortie stable)
   sans les adopter d'office.
5. Parcours manuel sur Android et Chrome :
   accueil → 4ème → Sciences physiques → « Introduction aux sciences physiques »
   → onglet « À retenir » → 5 exercices → bilan → « Recommencer ».
   Puis Seconde L : chapitres visibles, « Leçon pas encore disponible ».
6. Vérifier que `exercices(count)` est bien renvoyé en rôle `anon` (sinon le
   texte « Leçon prête, 5 exercices » perd son nombre, sans planter).
7. Vérifier l'alignement du texte sur les lignes Seyès ; ajuster
   `PageSeyes` / `MarkdownCahier` si le texte « flotte » entre les lignes.
8. Mode avion : chaque écran affiche `MessageErreur` et « Réessayer » fonctionne
   au retour du réseau.

Avancement au 13/11/2026 :
- 1 à 3 faits : installation faite, analyse sans aucun problème, 74 tests verts
  (deux imports manquants corrigés ; tests d'écrans ajoutés, voir ci-dessous).
- 4 fait : seul `go_router` a une version majeure (18.x) non adoptée.
  `supabase_flutter` v3 n'existe qu'en préversion (3.0.0-dev.17) ; la dernière
  stable est 2.18.3.
- 6 fait : `exercices(count)` renvoie bien `[{"count": 5}]` avec la clé
  publishable (rôle `anon`).
- 7 fait : le texte flottait 10 px au-dessus des lignes fortes et les titres
  cursifs tombaient entre deux lignes. Les lignes sont désormais tracées à la
  ligne de base du texte (mesurée sur la police) et les titres recalés
  (`SurLigneSeyes`). Test : `test/core/seyes_test.dart` (vraies polices,
  tolérance 1 px).
- 5 et 8 automatisés : `test/features/ecrans_test.dart` lance la vraie
  application avec un faux dépôt (`test/outils/faux_depot.dart`, réponses
  Supabase réelles dans `test/fixtures/`). Il couvre les quatre états de chaque
  écran, « Réessayer » après une panne réseau, `/lecon/1` ouvert directement,
  le parcours complet jusqu'à « Recommencer », Seconde L, et l'absence de
  débordement à 390 px avec un texte à 200 % et sur le web large. Corrigés au
  passage : débordement du compteur « Exercice 1 sur 5 » à 200 %, aide du
  brouillon coupée à 200 %, erreur « non gérée » des matières en mode avion,
  « 1 chapitres » au singulier.
- 5 et 8 vérifiés à la main le 13/11/2026 sur Android (Galaxy S23 Ultra,
  Android 17) : parcours complet, mode avion réel et « Réessayer », taille de
  texte système au maximum, flèches « → » de l'exercice 2 affichées. Aucune
  erreur dans les journaux pendant la session. Défaut trouvé et corrigé ce
  jour-là : texte des puces de choix blanc sur blanc (« Avais-tu juste ? »,
  catégories des tableaux de classement), test `test/features/puces_test.dart`.
- Captures d'écran pour les prochaines vérifications :
  `flutter test tool/captures/captures_test.dart` (images dans `build/captures/`).

Critères d'acceptation :
- analyse et tests verts ;
- parcours complet sans erreur rouge ni débordement (bandes jaunes et noires),
  y compris avec la taille de texte système au maximum ;
- adresse `/lecon/1` ouverte directement dans Chrome : la leçon s'affiche ;
- aucune clé autre que la clé publishable dans le dépôt.

---

## Phase 1 : finitions de la lecture (sans compte)

Décisions prises par Bocar le 13/11/2026 (voir `DECISIONS.md`, D14 à D20).
Ordre de réalisation :

| # | Sujet | Décision | État |
| --- | --- | --- | --- |
| 1 | Hors connexion | tout le contenu publié gardé sur l'appareil, mise à jour en arrière-plan (D16) | fait le 13/11/2026 (95 tests), vérifié sur le téléphone en mode avion |
| 2 | Libellés des catégories | champ facultatif `donnees.categories` (D14) ; Bocar complète les tableaux en base | côté application fait le 13/11/2026 ; tableaux 17 et 31 à compléter en base |
| 3 | Police de secours | sous-ensembles de Noto Sans et Noto Sans Math embarqués (D17) | fait le 13/11/2026 |
| 4 | Page « À propos » | texte rédigé par Claude, validé par Bocar ; pas de contact, crédit « Conçue par Bocar Gueye » (D18) | fait le 13/11/2026 |
| 5 | Icône et écran de lancement | variante A « Couverture » choisie par Bocar (D19) | fait le 14/11/2026, vérifié sur le téléphone par Bocar |
| 6 | Schémas des leçons | stockage Supabase public `schemas` (D15) | fait le 14/11/2026 (espace de stockage et affichage) ; à vérifier avec une vraie image déposée par Bocar |
| — | Lecture à voix haute | reportée (D20) | plus tard |

Critère commun : rien ne doit ralentir l'ouverture de l'application sur un
téléphone d'entrée de gamme avec une connexion 3G.

---

## Phase 2 : comptes et rôles

Objectif : savoir qui utilise l'application (élève, parent, rédacteur) sans
fermer l'accès libre au programme et aux leçons publiées.

### Décisions (tranchées par Bocar le 14/11/2026 : D21, D22, D23)

Choix retenus : 1 a), code chiffré par e-mail, plusieurs rédacteurs
attribués à la main. Migration :
`supabase/migrations/20261114101641_comptes_parents_enfants.sql` (appliquée le 14/11/2026).

Avancement (14/11/2026) : écrans « Espace parents » faits (connexion par code,
« Mes enfants », profil de ce téléphone, déconnexion), 27 tests. Envoi des
e-mails par Gmail (mot de passe d'application), modèles avec `{{ .Token }}`.
Essai réel réussi sur le téléphone le 15/11/2026 (code à 8 chiffres). Reste :
texte « Tes données » de la page « À propos » à revoir avec Bocar (il dit
« Pas de compte à créer ») ; service d'envoi d'e-mails dédié avant la
diffusion (D22).

1. **Comment un élève se connecte-t-il ?** Les élèves sont mineurs.
   - a) Compte parent, profils enfants rattachés (l'enfant n'a pas
     d'identifiants) : le plus simple et le plus prudent pour les données
     d'enfants, mais l'appareil de l'enfant doit être connecté au compte du
     parent.
   - b) Un compte par enfant, créé par le parent.
   - c) Connexion anonyme Supabase, rattachée plus tard à un parent.
2. **Méthode de connexion** : e-mail + mot de passe, lien magique par e-mail,
   ou code par SMS (coût des SMS, fournisseur à choisir).
3. **Rôle rédacteur** : Bocar seul pour l'instant ? Attribué à la main en base.

### Piste technique (à valider)

```sql
create type public.role_utilisateur as enum ('eleve', 'parent', 'redacteur');

create table public.profils (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.role_utilisateur not null default 'parent',
  prenom text not null,
  classe_id smallint references public.classes(id),
  created_at timestamptz not null default now()
);
-- RLS : chacun lit et modifie son profil, sauf la colonne role
-- (pas de politique d'update sur role ; changement par Bocar seulement).
```

Selon la décision 1, une table `enfants` (profils sans compte, rattachés à un
parent) ou `liens_parent_enfant` (deux comptes).

Critères d'acceptation :
- sans compte, l'application fonctionne exactement comme en phase 1 ;
- un utilisateur ne peut ni lire ni modifier le profil d'un autre (testé en
  SQL avec deux utilisateurs) ;
- un utilisateur ne peut pas se donner le rôle `redacteur` ;
- déconnexion propre, session conservée au redémarrage.

---

## Phase 3 : réponses et suivi parent

Décision 6 tranchée par Bocar le 15/11/2026 (D24) : résultats gardés hors
connexion et envoyés au retour du réseau. Migration appliquée le 15/11/2026 :
`supabase/migrations/20261115110503_lectures_resultats.sql`. File d'attente
faite le 15/11/2026 (`lib/data/suivi.dart`, 18 tests) : envoi au lancement, au
retour au premier plan, à la connexion du parent, à l'actualisation et après
chaque résultat. Écran « Suivi de mes enfants » fait le 15/11/2026 (`/suivi`,
18 tests). Texte « À propos » mis à jour et validé par Bocar le 15/11/2026.
Essai réel réussi sur le téléphone le 15/11/2026 : phase 3 terminée côté code. Elle remplace la
piste technique ci-dessous, écrite avant D21 (`profil_id` devient
`enfant_id`).

Objectif : enregistrer les résultats des exercices et donner aux parents
l'écran `Parent` des maquettes (« Suivi de mes enfants »).

Maquette : par enfant, « Cette semaine » (leçons lues, exercices faits, % de
bonnes réponses), « Derniers exercices » (leçon, type, score), « Leçons
disponibles en <classe> ».

### Piste technique (à valider)

```sql
create table public.lectures (      -- une ligne par leçon ouverte
  profil_id uuid not null, lecon_id bigint not null references public.lecons(id) on delete cascade,
  lue_le timestamptz not null default now(),
  primary key (profil_id, lecon_id)
);

create table public.resultats (     -- une ligne par exercice validé
  id bigint generated always as identity primary key,
  profil_id uuid not null,
  exercice_id bigint not null references public.exercices(id) on delete cascade,
  reussi boolean not null,
  bonnes smallint, total smallint,  -- null pour une auto-évaluation
  auto_evaluation boolean not null default false,
  created_at timestamptz not null default now()
);
-- RLS : insertion de ses propres lignes ; lecture par soi-même et par le parent rattaché.
```

Règles :
- ~~**Mettre à jour la page « À propos »**~~ : fait, texte validé par Bocar
  le 15/11/2026.
- **Ne pas enregistrer le texte libre des élèves** : l'écran promet que le
  brouillon « reste sur ton téléphone ». Seuls le résultat et le score partent.
- Données minimales sur les enfants (prénom, classe), rien d'autre.
- La barre de navigation du bas des maquettes (Mes cours, Exercices, Progrès)
  arrive avec cette phase.

Critères d'acceptation :
- un résultat enregistré hors connexion n'est pas perdu (file d'attente
  locale envoyée au retour du réseau), ou bien le choix inverse est documenté ;
- un parent ne voit que ses enfants (testé en SQL) ;
- les chiffres de « Cette semaine » sont vérifiés à la main sur un jeu de test.

---

## Phase 4 : validation et publication (rédacteur)

Décision 7 tranchée par Bocar le 15/11/2026 (D25) : table d'historique des
points levés. Migration :
`supabase/migrations/20261115115025_validation_redacteurs.sql` (appliquée le 15/11/2026). À livrer avec
elle : le téléchargement du contenu filtre `statut = 'publiee'` lui-même, sinon
un rédacteur connecté verrait les leçons non publiées comme si elles l'étaient
(fait le 15/11/2026). Bocar ajouté comme rédacteur le 15/11/2026. Écran
« Leçons à vérifier » fait le 15/11/2026 (`/validation`, `url_launcher` pour
l'artefact, D26). Après le premier essai de Bocar : lever un point se fait
avec une réponse écrite, obligatoire pour une question (fenêtre « Lever ce
point », 20 tests). Essai réussi sur le téléphone le 15/11/2026 : phase 4
terminée côté code.

Objectif : l'écran `Validation` des maquettes, réservé au rôle `redacteur`.

Maquette : liste des leçons non publiées avec le nombre de points à vérifier,
chaque point à cocher, lien « Ouvrir la leçon pour la corriger »
(`artefact_url`), bouton « Publier la leçon » actif seulement quand tous les
points sont cochés, message de confirmation.

### Piste technique (à valider)

- Politiques de lecture supplémentaires : le rôle `redacteur` voit toutes les
  leçons et tous les exercices, quel que soit le statut.
- Publication par une fonction `publier_lecon(lecon_id)` (`security definer`,
  `set search_path = ''`) qui vérifie le rôle, vide `points_a_verifier` et passe
  le statut à `publiee`. Aucune politique d'update directe sur `lecons`.
- Décision ouverte : garder une trace des points levés (table d'historique) ou
  se fier au bloc « Sources et fidélité » de l'artefact.

Critères d'acceptation :
- un compte non rédacteur ne peut ni voir les leçons non publiées ni appeler
  `publier_lecon` avec succès (testé en SQL) ;
- après publication, la leçon apparaît côté élève et le compteur de la matière
  augmente ;
- aucune modification du texte des leçons depuis l'application (l'édition
  reste dans les artefacts).

---

## Phase 5 : diffusion

Décisions de Bocar du 15/11/2026 : identifiant `sn.samaclasse.app` (D28,
fait), hébergement web Cloudflare Pages (D29), domaine `samaclasse.app` (D27),
compte Google Play déjà ouvert. Suppression du compte : migration
`suppression_compte` appliquée le 15/11/2026.

- Android : identifiant `sn.samaclasse.app` (D28, fait le 15/11/2026),
  signature, nom d'éditeur sur le Play Store, fiche, test fermé.
- ~~Web~~ : **en ligne le 15/11/2026** sur https://samaclasse.app
  (Cloudflare Pages, D29 ; domaine D27). Pages « Politique de
  confidentialité » (`/confidentialite/`) et « Supprimer votre compte »
  (`/suppression-compte/`), validées par Bocar ; publication automatique
  par GitHub Actions après les tests. `contact@samaclasse.app` redirigée
  vers Bocar (D30).
- iOS : seulement si un Mac et un compte Apple Developer sont disponibles.
- ~~**Suppression du compte**~~ : fait le 15/11/2026 (fonction
  `supprimer_mon_compte`, bouton « Supprimer mon compte » dans l'espace
  parents, confirmation par l'adresse e-mail) ; page web de demande de
  suppression en ligne avec le site.
- ~~Service d'envoi d'e-mails dédié~~ : fait le 15/11/2026, Resend avec
  `noreply@samaclasse.app` (D22) ; essai de connexion réussi.
- ~~Téléphones des enfants~~ : fait le 16/11/2026, liaison par un code du
  parent, session anonyme limitée au profil de l'enfant (D32).
- Facultatif : enregistrement DMARC (`_dmarc`, `p=none`) dans Cloudflare ;
  redirection de `www.samaclasse.app` vers `samaclasse.app`.
- Passage à `supabase_flutter` v3, une fois sortie en version stable (préversion
  `3.0.0-dev` seulement au 13/11/2026) : suivre le guide de migration
  officiel ; le code utilise déjà `publishableKey`.

---

## Décisions ouvertes : récapitulatif

| # | Question | Phase |
| --- | --- | --- |
| 1 | ~~Format des libellés de catégories des tableaux~~ : tranché (D14) | 1 |
| 2 | ~~Images des schémas : stockage, dépôt~~ : tranché (D15) | 1 |
| 3 | ~~Lecture à voix haute (dépendance)~~ : reportée (D20) | plus tard |
| 4 | ~~Connexion des élèves mineurs~~ : tranché (D21, compte parent et profils enfants) | 2 |
| 5 | ~~Méthode de connexion~~ : tranché (D22, code par e-mail) ; rôle rédacteur : D23 | 2 |
| 6 | ~~Enregistrement hors connexion des résultats~~ : tranché (D24, gardés puis envoyés) | 3 |
| 7 | ~~Historique des points levés~~ : tranché (D25, table d'historique) | 4 |
| 8 | ~~Identifiant Android, hébergement web~~ : tranché (D28 `sn.samaclasse.app`, D29 Cloudflare Pages) ; domaine `samaclasse.app` (D27) | 5 |
| 9 | `ordre` des séries d'une même année (Seconde S / L) | à l'ajout de nouvelles classes |
| 10 | ~~Police de secours pour les symboles absents d'Atkinson et de Playwrite (→, ℝ)~~ : tranché (D17) | 1 |
