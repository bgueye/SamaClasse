# Base de données Supabase

Projet **samaclasse**, ref `earcfeorkfeenqprsxpg`, région Paris (eu-west-3),
organisation « bgueye ». Séparé du projet At-Tijaniya.
URL : `https://earcfeorkfeenqprsxpg.supabase.co`.

Le SQL de référence est dans `supabase/migrations/` :

| Version | Nom | Contenu |
| --- | --- | --- |
| 20261112123201 | `schema_programme_lecons` | énumérations, tables, trigger `updated_at`, RLS |
| 20261112133342 | `vue_matieres_par_classe` | vue des compteurs, index |

## Contenu au 14/11/2026

| Classe | Code | Cycle | Ordre | Chapitres | Leçons | Publiées |
| --- | --- | --- | --- | --- | --- | --- |
| 4ème | `4e` | moyen | 9 | 111 | 8 | 6 |
| Seconde L | `2nde-L` | secondaire | 11 | 81 | 5 | 4 |

10 matières, 11 sources, 63 exercices. 10 leçons publiées par Bocar ; les
3 autres sont au statut `a_verifier`. Les valeurs de `ordre` (4ème = 9, Seconde L = 11) correspondent
à la position dans le cursus complet (CI = 1 … Terminale = 13) : garder cette
numérotation pour les classes ajoutées. À décider avant d'ajouter Seconde S :
les séries d'une même année partagent-elles le même `ordre` ?

Matières (`slug` → nom) : `mathematiques`, `sciences-physiques`, `svt`,
`francais`, `histoire`, `geographie`, `anglais`, `espagnol`,
`education-civique`, `economie`. Le `slug` sert de clé à la couleur de
protège-cahier (`lib/core/theme/matieres.dart`) : une nouvelle matière doit y
recevoir sa couleur.

## Schéma

```
classes ─┐
         ├─< chapitres >── matieres
sources ─┘       │  (source_id, facultatif)
                 └─< lecons ─< exercices
                        └─< lecon_sources >── sources

auth.users ─< enfants >── classes        (phase 2, D21)
auth.users ─── redacteurs                (phase 2, D23)
enfants ─< lectures >── lecons           (phase 3, D24)
enfants ─< resultats >── exercices       (phase 3, D24)
lecons ─< points_leves                   (phase 4, D25)
```

### `classes`
| Colonne | Type | Notes |
| --- | --- | --- |
| `id` | smallint identité | |
| `code` | text, unique | `4e`, `2nde-L` |
| `libelle` | text | affiché : « 4ème », « Seconde L » |
| `cycle` | text | `elementaire`, `moyen` ou `secondaire` (contrainte CHECK) |
| `ordre` | smallint | ordre du cursus |

### `matieres`
`id` smallint identité, `slug` text unique, `nom` text.

### `sources`
`id` smallint identité, `libelle` text unique, `fiabilite` text, `url` text.

### `chapitres`
| Colonne | Type | Notes |
| --- | --- | --- |
| `id` | bigint identité | |
| `classe_id` | → `classes`, on delete restrict | |
| `matiere_id` | → `matieres`, on delete restrict | |
| `numero` | smallint | unique par (classe, matière) ; ordre du programme |
| `titre` | text | |
| `partie` | text, facultatif | regroupement affiché dans l'écran matière |
| `statut` | `statut_programme`, défaut `a_valider` | fiabilité de la ligne du programme |
| `source_id` | → `sources`, on delete set null | |
| `remarque` | text | note interne, **ne pas afficher aux élèves** |

### `lecons`
| Colonne | Type | Notes |
| --- | --- | --- |
| `id` | bigint identité | |
| `chapitre_id` | → `chapitres`, on delete cascade | |
| `numero` | smallint, défaut 1 | unique par chapitre |
| `titre` | text | |
| `date_cours` | date, facultatif | date notée dans le cahier |
| `objectifs` | text[] | « Ce que tu vas apprendre » |
| `introduction` | text | Markdown |
| `corps` | text | Markdown, titres de partie en `##` |
| `a_retenir` | jsonb, défaut `[]` | `[{"notion": "...", "essentiel": "..."}]` |
| `points_a_verifier` | text[] | doubles à lever avant publication, **jamais affichés aux élèves** |
| `statut` | `statut_lecon`, défaut `brouillon` | |
| `artefact_url` | text | lien vers la version de travail (artefact claude.ai) |
| `created_at`, `updated_at` | timestamptz | `updated_at` mis à jour par le trigger `lecons_updated_at` |

### `exercices`
| Colonne | Type | Notes |
| --- | --- | --- |
| `id` | bigint identité | |
| `lecon_id` | → `lecons`, on delete cascade | |
| `ordre` | smallint | unique par leçon |
| `niveau` | `niveau_exercice` | |
| `type` | `type_exercice` | |
| `enonce` | text | Markdown |
| `donnees` | jsonb | matériel de l'exercice, selon le type |
| `reponse` | jsonb | réponse attendue, selon le type |
| `corrige` | text | Markdown, affiché après la réponse |

Formats de `donnees` et `reponse` : voir `EXERCICES.md`.

### `lecon_sources`
Clé (`lecon_id`, `source_id`), `nature` (`nature_source`).

### `enfants` (phase 2, D21)
`id`, `parent_id` (compte parent, rempli par défaut avec `auth.uid()`),
`prenom` (1 à 40 caractères), `classe_id`, `created_at`. 10 profils au plus
par compte (déclencheur `limiter_enfants`). Aucune autre donnée sur l'enfant.

### `redacteurs` (phase 2, D23)
`id` (compte), `ajoute_le`. Ajout à la main seulement :
`insert into public.redacteurs (id) select id from auth.users where email = '…';`

### `lectures` (phase 3, D24)
Clé (`enfant_id`, `lecon_id`), `lue_le` (heure du téléphone, dernière
ouverture). Envoyée en « upsert » : relire une leçon met la date à jour.

### `resultats` (phase 3, D24)
`id` (UUID fabriqué par le téléphone : un envoi répété est sans effet avec
`on conflict (id) do nothing`), `enfant_id`, `exercice_id`, `reussi`,
`bonnes` et `total` (exercice corrigé par l'application) ou
`auto_evaluation = true` sans score (« Avais-tu juste ? »), `fait_le` (heure
du téléphone), `recu_le`. Contraintes : score cohérent, `reussi` égal à
`bonnes = total`. **Aucun texte saisi par l'élève.**

### `points_leves` (phase 4, D25)
`id`, `lecon_id`, `point` (copie du texte du point), `leve_par`, `leve_le`,
`commentaire` (facultatif, 500 caractères au plus). Historique figé une fois
la leçon publiée.

### Publication (phase 4)
Colonnes `lecons.publiee_le` et `lecons.publiee_par`. Fonction
`publier_lecon(id)` (`security definer`, `search_path = ''`) : appelant
rédacteur, leçon « à vérifier », chaque point de `points_a_verifier` présent
dans `points_leves` ; passe la leçon à `publiee`, vide la liste, note qui et
quand. Fonction `est_redacteur()` (security invoker), utilisée par les règles.

### Suppression du compte (phase 5)
Fonction `supprimer_mon_compte()` (`security definer`, sans paramètre) :
supprime le compte de la session. En cascade : profils enfants, leurs
lectures et résultats, rôle rédacteur. Anonymisés (`set null`) :
`points_leves.leve_par`, `lecons.publiee_par`. Testée le 15/11/2026 (compte
fictif annulé) : un autre parent n'est pas touché. Avertissement attendu du
conseiller de sécurité, comme pour `publier_lecon`.

**Le téléchargement de l'application filtre `statut = 'publiee'` lui-même**
(requête, puis `Instantane.seulementPublie`) : un rédacteur connecté lit
aussi les leçons non publiées.

### Vue `matieres_par_classe` (security_invoker)
`classe_id`, `matiere_id`, `slug`, `nom`, `nb_chapitres`, `nb_lecons`
(leçons **publiées**). Comme elle applique les RLS de la personne qui lit, les
compteurs sont justes pour un élève.

## Énumérations

| Type | Valeurs |
| --- | --- |
| `statut_programme` | `officiel`, `source`, `cahier`, `a_valider`, `a_completer` |
| `statut_lecon` | `brouillon`, `a_verifier`, `publiee` |
| `niveau_exercice` | `je_connais`, `j_applique`, `je_reflechis` |
| `type_exercice` | `qcm`, `vrai_faux`, `relier`, `tableau`, `question_cours`, `documents`, `experience`, `calcul`, `redaction`, `epreuve` |
| `nature_source` | `cahier`, `complement`, `programme` |

Les énumérations Dart (`lib/data/models.dart`) reprennent ces valeurs ; une
valeur inconnue lève une `FormatException` explicite. Ajouter une valeur en
base impose de l'ajouter côté Dart dans la même livraison.

## Règles RLS

RLS activée sur toutes les tables. Contenu en lecture seule pour `anon` et
`authenticated` ; comptes (phase 2) réservés à leur propriétaire :

| Table | Qui voit quoi |
| --- | --- |
| `classes`, `matieres`, `sources`, `chapitres` | tout (programme public) |
| `lecons` | `statut = 'publiee'` seulement |
| `exercices`, `lecon_sources` | seulement ceux d'une leçon publiée |
| `enfants` | `authenticated` : ses propres enfants seulement (lecture, ajout, modification, suppression) ; `anon` : rien |
| `redacteurs` | `authenticated` : sa propre ligne (savoir s'il est rédacteur) ; aucune écriture ; `anon` : rien |
| `lectures` | `authenticated` : celles de ses enfants (lecture, ajout, mise à jour), leçons publiées seulement ; pas de suppression ; `anon` : rien |
| `resultats` | `authenticated` : ceux de ses enfants (lecture, ajout), exercices publiés seulement ; ni modification ni suppression ; `anon` : rien |
| `lecons`, `exercices`, `lecon_sources` (en plus) | rédacteur : tout, quel que soit le statut |
| `points_leves` | rédacteur : lecture, ajout (point réellement à vérifier, en son nom), suppression avant publication ; `anon` et non-rédacteurs : rien |

Tests du 14/11/2026 (deux comptes simulés) : un parent ne voit, ne modifie
ni ne supprime les enfants d'un autre, ne peut pas lui en donner un, ne peut
pas se déclarer rédacteur ; le 11e profil est refusé.
Tests du 15/11/2026 (phase 3) : un parent n'écrit ni ne lit les résultats et
lectures d'un autre ; exercice ou leçon non publiés refusés ; score
incohérent refusé ; un résultat ne se modifie ni ne se supprime ; un envoi
répété n'ajoute rien ; supprimer un profil supprime ses données.
Tests du 15/11/2026 (phase 4, leçons fictives annulées) : un parent ou `anon`
ne voit que les leçons publiées, ne lève aucun point, ne publie pas ; un
rédacteur voit tout, ne lève qu'un point réel en son nom, ne publie qu'une
leçon « à vérifier » dont tous les points sont levés, une seule fois.
Conseiller de sécurité : avertissement attendu sur `publier_lecon`
(`security definer` exécutable par `authenticated`), voulu, contrôles faits
dans la fonction.

Aucune politique d'écriture sur le contenu : la saisie se fait aujourd'hui par le tableau de
bord ou une connexion d'administration, jamais depuis l'application.
Conséquence pour le code : une leçon non publiée renvoie `null`
(`maybeSingle`), et l'écran affiche « Leçon pas encore disponible ».

## Stockage des schémas (D15)

Espace de stockage **public** `schemas` (migration `stockage_schemas`) :
150 Ko maximum par fichier, PNG, JPEG ou WebP seulement (pas de SVG).
Bocar dépose les images par le tableau de bord, puis les insère dans le
Markdown avec une description obligatoire :
`![Description](https://earcfeorkfeenqprsxpg.supabase.co/storage/v1/object/public/schemas/<chemin>)`.

Aucune politique sur `storage.objects` : un fichier se télécharge par son
adresse publique, mais `anon` et `authenticated` ne peuvent ni lister
l'espace, ni déposer, remplacer ou supprimer un fichier (vérifié le
14/11/2026). Ne pas ajouter de politique « select » : elle permettrait
seulement de lister tous les fichiers.

Hors connexion, les images ne sont pas gardées sur le téléphone : la
description s'affiche à leur place (à revoir quand les schémas seront nombreux).

## Requêtes de l'application

Depuis la décision D16 (hors connexion), l'application télécharge **tout le
contenu publié** en quatre requêtes lancées ensemble
(`lib/data/telechargement_supabase.dart`), environ 50 Ko au 13/11/2026, et
le garde sur l'appareil :

```dart
// classes, dans l'ordre du cursus
from('classes').select('id, code, libelle, cycle, ordre').order('ordre');

// matières de toutes les classes, avec compteurs
from('matieres_par_classe')
  .select('classe_id, matiere_id, slug, nom, nb_chapitres, nb_lecons').order('nom');

// tous les chapitres, avec leçons publiées et nombre d'exercices
from('chapitres')
  .select('id, classe_id, matiere_id, numero, titre, partie, statut, '
          'lecons(id, numero, titre, exercices(count))')
  .order('numero').order('numero', referencedTable: 'lecons');

// toutes les leçons publiées, complètes
from('lecons')
  .select('id, chapitre_id, numero, titre, date_cours, objectifs, introduction, corps, '
          'a_retenir, statut, exercices(id, ordre, niveau, type, enonce, donnees, reponse, corrige), '
          'chapitres(titre, partie, classes(libelle), matieres(nom, slug))')
  .order('ordre', referencedTable: 'exercices');
```

Les colonnes de rédaction (`chapitres.remarque`, `lecons.points_a_verifier`,
`lecons.artefact_url`) ne sont pas demandées : elles ne sont donc ni
téléchargées ni gardées sur les téléphones. Limite : 1 000 lignes par requête
(réglage par défaut de PostgREST) ; 192 chapitres pour deux classes.
Pour tout le cursus, passer à une synchronisation par classe.

`exercices(count)` renvoie `[{"count": 5}]` : `LeconResume.fromJson` le lit.

## Modifier le schéma

1. Proposer la migration à Bocar (SQL + effet sur les RLS) et attendre son accord.
2. Une migration = un fichier `supabase/migrations/<horodatage>_<nom>.sql`,
   noms en snake_case français (`comptes_et_roles`, `reponses_eleves`).
3. Toute nouvelle table : `enable row level security` + politiques explicites
   dans la même migration. Fonctions : `security definer` seulement si
   indispensable, avec `set search_path = ''`.
4. Vues : `with (security_invoker = true)`.
5. Index sur toutes les clés étrangères.
6. Vérifier : requêtes en `set local role anon` / `authenticated`, puis
   conseillers de sécurité et de performance.
7. Mettre à jour ce document, les modèles Dart et leurs tests.

## Données de travail interdites à l'affichage

`chapitres.remarque`, `lecons.points_a_verifier`, `lecons.artefact_url`,
`sources.fiabilite` sont des informations de rédaction. Elles ne doivent
apparaître que dans les écrans réservés au rédacteur (phase 4).
