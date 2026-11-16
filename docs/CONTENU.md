# Contenu pédagogique : règles et cycle de publication

Ce document explique d'où vient le contenu et comment il passe en ligne. Claude
Code **ne modifie pas le contenu** : ces règles servent à construire les écrans
qui l'affichent et, plus tard, ceux qui permettent de le valider.

## D'où vient le contenu

- **Le programme** (classes, matières, chapitres) : programme officiel,
  fascicules du ministère, sites éducatifs, et les cahiers des élèves. Chaque
  chapitre porte un statut de fiabilité.
- **Les leçons** : rédigées à partir des cahiers des enfants de Bocar
  (4ème et Seconde L), photographiés au fil de l'année. **Le cahier fait foi** :
  plan conservé, compléments signalés « Complément », rien d'inventé.
- Une version de travail de chaque leçon existe sous forme d'artefact sur
  claude.ai (`lecons.artefact_url`). La base est la version diffusée.
- Tableau de référence du programme :
  https://claude.ai/artifact/UQgf85Z2hiZ4jJnnrfD4Gd
- Gabarit de leçon : https://claude.ai/artifact/9rzQ7wL3tE2YRYUUoHkfEd

## Statuts de fiabilité d'un chapitre (`statut_programme`)

| Valeur | Sens |
| --- | --- |
| `officiel` | texte du programme national (Office du Bac, programme SVT 2016) |
| `source` | fascicules ADEM-Dakar du ministère, conformes au programme |
| `cahier` | attesté par les cahiers des élèves, absent des sources en ligne |
| `a_valider` | sites éducatifs privés, à recouper |
| `a_completer` | aucune source fiable (lignes pas encore en base) |

Aujourd'hui l'application n'affiche pas ce statut aux élèves. Le montrer
éventuellement aux enseignants et aux rédacteurs.

## Gabarit d'une leçon (9 blocs)

1. En-tête (classe, matière, chapitre, date du cours) → `chapitre_id`, `titre`, `date_cours`
2. Objectifs (facultatif) → `objectifs`
3. Introduction → `introduction`
4. Corps → `corps` (Markdown, parties en `##`)
5. À retenir → `a_retenir` (`[{notion, essentiel}]`)
6. Exercices (au moins 3, trois niveaux) → table `exercices`
7. Corrigé (facultatif) → `exercices.corrige`
8. Sources et fidélité → `lecon_sources` (et l'artefact)
9. Points à vérifier (facultatif) → `points_a_verifier`

## Insérer un schéma (D15, D31)

**Le plus simple : depuis l'application** (compte rédacteur). Ouvrir la
leçon, toucher l'icône d'image en haut (ou, pour une leçon à vérifier,
« Ajouter ou retirer des schémas » dans « Leçons à vérifier »), puis
« Ajouter un schéma » : photo du cahier ou image de la galerie, description,
endroit (introduction ou corps, entre deux paragraphes). L'application réduit
l'image sous 150 Ko, la dépose dans `schemas/lecons/<id>/` et insère la ligne
Markdown. « Retirer » enlève la ligne et supprime l'image. Recadrer la photo
sur le schéma dans la galerie avant de la choisir.

**Par le tableau de bord** (pour un énoncé ou un corrigé d'exercice, que
l'application ne propose pas encore) :

1. Préparer l'image : PNG, JPEG ou WebP, **moins de 150 Ko** (le serveur
   refuse au-delà). Une largeur de 1 000 à 1 200 pixels suffit ; pas de SVG.
2. La déposer dans l'espace de stockage `schemas` par le tableau de bord
   Supabase (Storage), par exemple `4eme/svt/cycle_eau.png`.
3. L'insérer dans `introduction`, `corps`, un énoncé ou un corrigé, sur une
   ligne à part :
   `![Le cycle de l’eau : évaporation, condensation, précipitations](https://earcfeorkfeenqprsxpg.supabase.co/storage/v1/object/public/schemas/4eme/svt/cycle_eau.png)`

La **description est obligatoire** et doit se suffire à elle-même : elle est
lue par les lecteurs d'écran et s'affiche à la place de l'image hors connexion
ou si l'image ne charge pas (« Schéma : … »). L'application n'affiche que les
images de l'espace `schemas` ; une adresse d'un autre site est remplacée par
sa description.

## Cycle de vie d'une leçon (`statut_lecon`)

```
brouillon ──► a_verifier ──► publiee
                  │   ▲
                  └───┘  points à vérifier levés un à un avec les cahiers
```

- `a_verifier` : la leçon est complète mais a des **points à vérifier**
  (lecture incertaine du cahier, fait douteux, origine des exercices).
  Invisible des élèves.
- Pour publier : comparer ligne à ligne avec les photos du cahier, lever
  chaque point, vider `points_a_verifier`, puis passer à `publiee`.
- **Seul un validateur publie** (Bocar, D33). Une leçon publiée n'est jamais
  repassée en brouillon : elle se corrige à part, en restant en ligne.

## Corriger une leçon publiée (D33)

```
publiee ──► correction ouverte (copie de travail) ──► correction publiée
               │  texte corrigé par Claude Code            (nouvelle version)
               │  points levés avec les cahiers
               └──► abandonnée (la leçon reste telle quelle)
```

1. Un rédacteur ouvre la leçon, menu « Outils du rédacteur » › « Demander une
   correction » : ce qu'il faut corriger, et les points à vérifier (un par
   ligne).
2. Bocar corrige l'artefact, puis demande à Claude Code : « mets la
   correction de la leçon 4 ». **Claude Code écrit dans
   `corrections_lecons` (ligne `etat = 'ouverte'` de la leçon), jamais dans
   `lecons`** : titre, objectifs, introduction, corps, `a_retenir`. Il montre
   le passage modifié avant d'enregistrer.
3. Dans « Leçons à vérifier », section « Corrections en cours » : « Relire
   le texte corrigé », lever chaque point, ajouter les schémas manquants.
4. Le validateur touche « Publier la correction » : le texte passe en ligne,
   une version est archivée. Les élèves le reçoivent à leur mise à jour.
5. Menu « Versions de la leçon » : relire chaque version ; le validateur peut
   revenir à l'une d'elles (hors correction en cours).

Les exercices ne passent pas par une correction : Claude Code les corrige sur
place, à la demande de Bocar (ne jamais supprimer un exercice qui a des
résultats d'enfants).

La maquette `Validation` décrit l'écran qui outillera ce cycle : liste des
leçons à vérifier, points à cocher, lien vers l'artefact, bouton « Publier »
actif seulement quand tous les points sont cochés (phase 4).

## Ce que l'élève ne doit jamais voir

`points_a_verifier`, `chapitres.remarque`, `artefact_url`, la fiabilité des
sources, et toute note de travail dans les textes. Les RLS cachent déjà les
leçons non publiées ; les champs ci-dessus restent à exclure des écrans élèves.

## Points en suspens connus (contenu)

- Introduction aux sciences physiques (4ème) : partie V (« Évolution »)
  annoncée dans le cahier, pas encore écrite.
- Structure d'un écosystème (Seconde L) : partie « peuplement animal » à rédiger.
- Économie (Seconde L) : section 2 inachevée dans le cahier ; matière absente
  du tableau de référence.
- Nombres rationnels (4ème) : la leçon en base est la n° 2, la n° 1 n'est pas
  encore photographiée.
