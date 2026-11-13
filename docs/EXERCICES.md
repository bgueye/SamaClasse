# Exercices : formats, saisie, correction

Chaque exercice a un `niveau` (« Je connais », « J'applique », « Je
réfléchis »), un `type`, un `enonce` en Markdown, et selon le type des
`donnees` (le matériel) et une `reponse` (la réponse attendue) en JSON, plus un
`corrige` en Markdown. Répartition en base au 13/11/2026 :

| Type | Nombre | Corrigé automatiquement |
| --- | --- | --- |
| `question_cours` | 26 | non |
| `tableau` | 11 | oui si la réponse est une liste ou un classement (pas un objet imbriqué) |
| `vrai_faux` | 7 | oui |
| `qcm` | 5 | oui |
| `calcul` | 4 | oui |
| `relier` | 3 | oui |
| `redaction` | 3 | non |
| `epreuve` | 2 | non |
| `documents`, `experience` | 1 + 1 | non |

## Chaîne de traitement

```
Exercice (base)
  → reponseInitiale(exercice)           outils_exercices.dart : réponse vide de la bonne forme
  → SaisieExercice                      saisies/saisie_exercice.dart : choisit la zone de réponse
  → corriger(exercice, reponseEleve)    data/correction.dart
       CorrectionAuto(details)          un booléen par élément, dans l'ordre d'affichage
       CorrectionManuelle(corrige)      l'élève compare et s'auto-évalue
       ReponseInvalide(raison)          forme inattendue (bogue d'écran)
  → retour visuel par élément + corrigé Markdown
```

`estAutoCorrigeable(exercice)` décide entre correction automatique et
manuelle **d'après la forme de `reponse`**, pas seulement d'après le type : une
`reponse` absente ou d'une forme non prévue donne une correction manuelle.

## Formats par type

### `qcm`
```json
"donnees": {"questions": [{"q": "Le baobab appartient à la strate :", "choix": ["herbacée", "arbustive", "arborescente"]}]},
"reponse": [2]
```
Réponse = indice du bon choix (à partir de 0), un par question.
Saisie (`SaisieQcm`) : une `TuileChoix` par choix. Réponse élève : `List<int?>`.

### `vrai_faux`
```json
"donnees": {"affirmations": ["Un gaz a un volume propre.", "Eau + huile est un mélange hétérogène."]},
"reponse": [false, true]
```
Saisie (`SaisieVraiFaux`) : deux tuiles Vrai / Faux par affirmation.
Réponse élève : `List<bool?>`. Si l'énoncé demande de justifier, la
justification est dans le `corrige`, affiché après correction.

### `relier`
```json
"donnees": {"gauche": ["1492", "1500"], "droite": ["Cabral découvre le Brésil", "Christophe Colomb découvre l'Amérique"]},
"reponse": {"1492": "Christophe Colomb découvre l'Amérique", "1500": "Cabral découvre le Brésil"}
```
Ordre d'affichage : `donnees.gauche` (sinon les clés de `reponse`) ; `droite`
est déjà mélangée en base. Saisie (`SaisieRelier`) : un sélecteur par élément
de gauche, qui ouvre une feuille avec les éléments de droite.
Réponse élève : `Map<String, String>`.

### `tableau`, liste ordonnée
```json
"donnees": null,
"reponse": ["solidification", "fusion", "vaporisation"]
```
Saisie (`SaisieTableauOrdonne`) : une case par valeur. Le contenu des colonnes
est décrit dans l'énoncé. Réponse élève : `List<String>`.

### `tableau`, classement
```json
"reponse": {"homogene": ["eau sucrée", "air"], "heterogene": ["eau + sable", "eau + huile"]}
```
Saisie (`SaisieClassement`) : chaque élément (trié sans accents, pour ne pas
trahir la réponse) reçoit une catégorie par des puces. Réponse élève :
`Map<String, List<String>>`. Limite connue : les clés de catégorie s'affichent
via `libelleCle` (« Homogene », sans accent). Piste : un champ
`donnees.categories` avec les libellés affichables, à décider avec Bocar.

### `tableau` imbriqué (non corrigé automatiquement)
```json
"reponse": {"disposition": "croisées (ABAB)", "perché / alléché": {"genre": "masculine", "qualite": "suffisante"}}
```
Saisie libre, puis comparaison avec le corrigé.

### `calcul`
```json
"reponse": {"totaux": [5, 7, 9, 10, 10, 10], "aire_minimale_m2": 8}
"reponse": {"476": "Ve siècle", "duree_annees": 3775}
```
La réponse est aplatie en chemins (`totaux.0`, `aire_minimale_m2`), un champ
par chemin, libellé par `libelleChemin` (« Totaux n° 1 »). Feuilles : nombres
ou textes courts. Réponse élève : `Map<String, Object>` (chemin → texte saisi).

### Types à correction manuelle
`question_cours`, `documents`, `experience`, `redaction`, `epreuve` :
`reponse` est le plus souvent `null` (parfois un objet indicatif, ignoré).
Saisie libre (brouillon non envoyé), bouton « Voir le corrigé », puis
« Oui, j’avais juste » / « Non, je me suis trompé ».

## Règles de comparaison

- Textes (`memeTexte` / `normaliser`) : sans tenir compte de la casse, des
  accents, des espaces en trop, de la ponctuation finale ni du type
  d'apostrophe. « L’Œsophage. » = « l'oesophage ».
- Nombres (`lireNombre`, `memeNombre`) : virgule ou point décimal, espaces de
  milliers acceptés (« 1 000,5 »). Un entier attendu (date, durée, effectif)
  doit être exact ; un décimal est accepté à 0,1 % près.
- QCM, vrai ou faux : une question sans réponse compte faux.

## Bilan de la série

Un exercice est réussi si `CorrectionAuto.toutJuste`, ou si l'élève a répondu
« j’avais juste » après un corrigé. Le bilan affiche « n sur N » et le détail
par exercice. **Rien n'est enregistré** pour l'instant (phase 3).

## Conventions de rédaction des exercices (rappel du gabarit)

- Au moins 3 exercices par leçon, répartis sur les trois niveaux.
- Maths : exposants en caractères Unicode (10⁻³, 10ⁿ⁺ᵐ), fractions en ligne
  (7/3). Pas de LaTeX : le rendu Markdown ne le gère pas.
- Schéma non encore converti : ligne en italique entre crochets dans le texte.

## Ajouter un type d'exercice

1. Accord de Bocar sur le format JSON (`donnees`, `reponse`), écrit ici.
2. Migration : `alter type public.type_exercice add value '<type>';`
3. `TypeExercice` dans `models.dart` (valeur + libellé).
4. `estAutoCorrigeable` et `corriger` dans `correction.dart`, avec l'ordre des
   `details` documenté.
5. `reponseInitiale` dans `outils_exercices.dart`.
6. Un widget `saisies/saisie_<type>.dart` qui respecte : lecture seule une fois
   corrigé, retour par élément (icône + texte), `TuileChoix` / `RetourChamp`.
7. Le brancher dans `SaisieExercice`.
8. Tests : correction sur un exemple réel, `reponseInitiale`, un test de widget.
