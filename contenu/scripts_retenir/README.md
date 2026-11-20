# Scripts oraux de « À retenir » (D37)

Brouillons de `lecons.script_retenir`, un fichier par leçon (`lecon_<id>.json`),
à relire par Bocar **avant** toute écriture en base.

## Format

Le même que `lecons.script_audio` (D34) : une liste ordonnée de passages.

```json
[
  {"lang": "fr-FR", "texte": "Histoire, classe de quatrième. À retenir : …"},
  {"lang": "en-GB", "texte": "The present simple."}
]
```

## Règles de rédaction

- Fidèle à « À retenir » de la leçon : rien de plus sur le fond. Un exemple
  n'est ajouté que s'il figure déjà dans la leçon.
- Écrit pour l'oral : phrases complètes et courtes, pas de Markdown, pas de
  symbole (« × », « → », « ≤ », « / », « + », exposants) ; les formules sont
  dites en mots (« dix puissance n »), les lettres épelées (« c h », « e s »).
- Lettres seules mal lues par la voix française : « m » est lu « monsieur »
  (abréviation « M. ») ; écrire « èmme ». Toute nouvelle lettre mal lue
  s'ajoute ici et dans le test.
- Une seule langue par passage : un mot anglais ou espagnol va dans son
  propre passage (`en-GB`, `es-ES`), jamais lu par la voix française.
- Ouverture : « Matière, classe de … À retenir : titre. » ; fin :
  « Fin du résumé. … ».

## Cycle

1. Rédaction du brouillon ici (vérifié par `test/data/scripts_retenir_test.dart` :
   format, langues, aucun symbole).
2. Relecture et corrections par Bocar.
3. Écriture en base (`lecons.script_retenir`), seulement avec son accord,
   leçon par leçon.
