# Base de données Supabase

Projet **samaclasse**, ref `earcfeorkfeenqprsxpg`, région Paris (eu-west-3),
organisation « bgueye ». Séparé du projet At-Tijaniya.
URL : `https://earcfeorkfeenqprsxpg.supabase.co`.

Le SQL de référence est dans `supabase/migrations/` :

| Version | Nom | Contenu |
| --- | --- | --- |
| 20261112123201 | `schema_programme_lecons` | énumérations, tables, trigger `updated_at`, RLS |
| 20261112133342 | `vue_matieres_par_classe` | vue des compteurs, index |

## Contenu au 13/11/2026

| Classe | Code | Cycle | Ordre | Chapitres | Leçons | Publiées |
| --- | --- | --- | --- | --- | --- | --- |
| 4ème | `4e` | moyen | 9 | 111 | 8 | 1 |
| Seconde L | `2nde-L` | secondaire | 11 | 81 | 5 | 0 |

10 matières, 11 sources, 63 exercices. Seule la leçon « Introduction aux
sciences physiques » (4ème) est publiée ; les 12 autres sont au statut
`a_verifier`. Les valeurs de `ordre` (4ème = 9, Seconde L = 11) correspondent
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

RLS activée sur toutes les tables. Lecture seule pour `anon` et `authenticated` :

| Table | Qui voit quoi |
| --- | --- |
| `classes`, `matieres`, `sources`, `chapitres` | tout (programme public) |
| `lecons` | `statut = 'publiee'` seulement |
| `exercices`, `lecon_sources` | seulement ceux d'une leçon publiée |

Aucune politique d'écriture : la saisie se fait aujourd'hui par le tableau de
bord ou une connexion d'administration, jamais depuis l'application.
Conséquence pour le code : une leçon non publiée renvoie `null`
(`maybeSingle`), et l'écran affiche « Leçon pas encore disponible ».

## Requêtes de l'application

```dart
// classes, dans l'ordre du cursus
from('classes').select('id, code, libelle, cycle, ordre').order('ordre');

// matières d'une classe, avec compteurs
from('matieres_par_classe').select().eq('classe_id', id).order('nom');

// chapitres d'une matière, avec leçons publiées et nombre d'exercices
from('chapitres')
  .select('id, numero, titre, partie, statut, remarque, lecons(id, numero, titre, exercices(count))')
  .eq('classe_id', c).eq('matiere_id', m)
  .order('numero').order('numero', referencedTable: 'lecons');

// leçon complète
from('lecons')
  .select('*, exercices(*), chapitres(titre, partie, classes(libelle), matieres(nom, slug))')
  .eq('id', id).order('ordre', referencedTable: 'exercices').maybeSingle();
```

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
