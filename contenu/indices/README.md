# Indices des exercices (D39)

Brouillons de `exercices.indice`, un fichier par leçon (`lecon_<id>.json`),
à relire par Bocar **avant** toute écriture en base.

## Format

Un objet : l'identifiant de l'exercice (`exercices.id`, en texte) → l'indice.

```json
{
  "33": "Relis la notion « Dates » dans À retenir.",
  "34": "Pour chaque mot, pense à ce qu'il décrit…"
}
```

Un exercice absent du fichier n'a pas d'indice (pas de bouton).

## Règles de rédaction

- **Ne jamais donner la réponse**, ni la recopier en partie : l'indice met
  sur la piste. Il renvoie à une notion de « À retenir » (nom exact, entre
  guillemets), à une méthode (« cherche un verbe conjugué »), ou à une
  question à se poser.
- Un indice pour tout l'exercice, même s'il a plusieurs questions : viser
  la difficulté principale, ou donner une piste par groupe de questions.
- Tutoiement, phrases courtes, 3 à 500 caractères (contrainte de la base) ;
  en pratique une à trois phrases.
- Markdown simple seulement (gras au besoin) ; pas de titre, pas de liste.
- Pas de « Indice : » au début : l'encadré a déjà ce titre.
- Guillemets français avec **espaces insécables** à l'intérieur
  (`« mot »`) : sinon « » » peut se retrouver seul en début de
  ligne. De même devant « °C » (`37 °C`).
- Exercices d'anglais ou d'espagnol : indice en français, les mots de la
  langue étudiée cités tels quels.

## Cycle

1. Rédaction du brouillon ici (vérifié par `test/data/indices_test.dart` :
   format, longueur, guillemets, pas de « Indice : »).
2. Vérification que l'indice ne contient pas la réponse attendue (requête
   en lecture sur `exercices.reponse`, faite avant l'écriture en base).
3. Relecture et corrections par Bocar.
4. Écriture en base (`exercices.indice`), seulement avec son accord, par lot.
   La requête se génère depuis les fichiers, jamais à la main :
   `tool/indices/generer_requete.ps1 -Dossier contenu/indices -Sortie <fichier.sql> [-Lecons 8,9]`.
   Les espaces insécables y deviennent le repère `~NB~`, remplacé par
   `chr(160)` dans la base (recopiées, elles deviendraient des espaces
   ordinaires) ; la requête n'écrit que sur un exercice sans indice.

## État

- 4ème (13 leçons, 69 exercices) : en base le 21/11/2026.
- Seconde L (10 leçons, 57 exercices) : à rédiger.
