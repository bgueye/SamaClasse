# Design : le cahier d'écolier

Maquettes de référence (canvas Design sur claude.ai) :
https://claude.ai/artifact/3Ci5BP3dorfEx2apfePJhE

| Maquette | Écran | État dans le code |
| --- | --- | --- |
| `Main` | Accueil élève | fait (sans barre de navigation du bas ni bouton profil) |
| `Matiere` | Chapitres d'une matière | fait |
| `Lecon` | Leçon, onglets « La leçon » / « À retenir » | fait (sans bouton « Écouter la leçon ») |
| `Exercice` | Exercice et bilan | fait, avec un écart : un exercice par écran avec toutes ses questions, au lieu d'une affirmation par écran |
| `Parent` | Suivi de mes enfants | fait (phase 3), avec deux écarts : « exercices réussis » au lieu de « bonnes réponses » (c'est ce qui est mesuré), pas de bouton vers la validation (phase 4) |
| `Validation` | Leçons à vérifier, publication | fait (phase 4), avec un écart de texte : « les élèves la verront à la prochaine mise à jour de leur application » au lieu de « la voient maintenant » ; confirmation avant de publier |

Maquettes des idées validées par Bocar le 20/11/2026 (canvas séparé, D35) :
https://claude.ai/artifact/XXUbNZErgvvaKgHve2Bo3M

| Maquette | Écran | Public | État dans le code |
| --- | --- | --- | --- |
| `Main` | « Interroge-moi » : cartes de révision tirées de « À retenir » | élève | fait (20/11/2026), avec un écart : pas de « reviendront dans quelques jours » (pas encore de révision espacée) |
| `CartesParent` | « Fais réciter ton enfant » : question, réponse attendue visible du parent | parent | fait (20/11/2026), avec des écarts : même écran que les cartes (sélecteur « Je révise seul » / « Je fais réciter », sans compte), question « Explique-moi : « notion ». », vouvoiement, pas encore de bouton « Écouter la question » ; ouvert aussi depuis « Suivi » (« Que lui demander ce soir ? ») |
| `Partage` | « Envoyer cette leçon » : lien samaclasse.app par une autre application | tous | fait (20/11/2026) : icône dans l'en-tête de la leçon |
| `Fiche`, `FicheCorrige` | fiche A4 à imprimer (résumé, exercices) et son corrigé séparé | enseignant | fait (20/11/2026) : icône dans l'en-tête de la leçon, un seul PDF (fiche puis corrigé sur une nouvelle page), tous les exercices de la leçon, schémas remplacés par leur description |
| `Indice` | un indice avant le corrigé | élève | à faire ; demande un indice rédigé par question |
| `Essentiel` | « Écouter l’essentiel » : lecture de « À retenir » | élève | fait côté code (20/11/2026, D37) : la barre du bas lit `script_retenir` sur l'onglet « À retenir » ; sans surlignage de la notion lue ; scripts à rédiger |
| `Revision` | « Révision du BFEM » : série mêlée par matière | élève | à faire |
| `ResumeParent` | résumé simple de la semaine et « Que lui demander ce soir ? » | parent | fait (20/11/2026) dans « Suivi » : les trois cases deviennent trois phrases à icône (leçons lues, exercices réussis, jours travaillés), « Écouter le résumé » (voix du téléphone), « Envoyer ce résumé » ; « Que lui demander ce soir ? » montre les trois premières questions. Écart : icône neutre (crayon) pour les exercices, pas de coche verte |
| `Signaler` | « Signaler une erreur » sur une leçon ou un exercice | tous | à faire ; demande une migration |
| `Projection` | mode projection, partie par partie, très gros caractères (web) | enseignant | à faire |
| `Programme` | programme d’une matière : chapitres disponibles, « fait en classe » (web) | enseignant | à faire |

L'idée : l'application ressemble au cahier que l'élève connaît. Encre bleue,
marge rouge, lignes Seyès sur la page de leçon, titres écrits à la main, et une
couleur de protège-cahier par matière.

## Couleurs (`lib/core/theme/couleurs.dart`)

| Nom | Valeur | Usage |
| --- | --- | --- |
| `encre` | #2140C9 | couleur principale, liens, boutons, titres cursifs |
| `encreFoncee` | #16309A | survol |
| `papier` | #FFFFFF | page de leçon, cartes |
| `fond` | #F7F8FC | fond des écrans |
| `marge` | #D62839 | marge rouge, titres de partie dans la leçon |
| `texte` | #121A33 | texte principal |
| `texteDoux` | #3D465C | texte secondaire long |
| `texteSecondaire` | #5B6478 | sous-titres, compteurs |
| `texteAttente` | #8A93A8 | numéros de chapitres sans leçon (jamais pour un texte à lire) |
| `etiquette` | #A84F08 | étiquettes « matière, leçon », niveau d'exercice |
| `texteSurEncre` | #FFFFFF | texte sur fond `encre` (boutons, puce sélectionnée) ; contraste ≈ 7,6:1 |
| `bordure` / `bordureCarte` / `bordureForte` | #E3E7F3 / #DCE2F3 / #C9D3EE | séparateurs, cartes, champs |
| `segment` | #E8ECF8 | fond des sélecteurs à segments |
| `selection` | #EEF1FA | choix sélectionné non corrigé, encadrés neutres |
| `ligneSeyes` / `ligneSeyesFine` | #CBD5EF / #EEF1FA | lignes du cahier |
| `juste` / `justeFond` / `justeTexte` | #0F6B52 / #E3F4EE / #0B3D30 | bonne réponse |
| `faux` / `fauxFond` / `fauxTexte` | #B3192B / #FBE7E9 / #4A0C14 | mauvaise réponse |

Ne jamais écrire une couleur en dur dans un écran : ajouter une entrée à
`Couleurs` si besoin.

## Couleurs des matières (`lib/core/theme/matieres.dart`)

| Slug | Couleur | | Slug | Couleur |
| --- | --- | --- | --- | --- |
| `histoire` | #E07A1F | | `education-civique` | #C99A00 |
| `geographie` | #1C8C9E | | `mathematiques` | #2140C9 |
| `francais` | #D62839 | | `anglais` | #B8336A |
| `svt` | #5BA829 | | `espagnol` | #8C5A2B |
| `sciences-physiques` | #7048C2 | | `economie` | #5D6B7A |

Les sept premières viennent des maquettes ; anglais, espagnol et économie ont
été choisies ensuite (à valider). Elles servent au dos de cahier (`DosCahier`),
jamais comme couleur de texte : plusieurs n'atteignent pas 4,5:1 sur blanc.

## Typographie

- **Atkinson Hyperlegible Next** (400, 600, 700) : tout le texte. Conçue pour
  la lisibilité (lettres bien distinctes), adaptée aux jeunes lecteurs.
- **Playwrite FR Moderne** (400) : titres « écrits à la main » seulement
  (titre de leçon, « À retenir », titres de partie `##` de la leçon,
  « Exercices terminés »). Jamais pour un paragraphe.
- Les deux polices sont **embarquées** (`assets/fonts/`, instances statiques
  tirées des polices variables Google Fonts, licence OFL enregistrée dans
  `LicenseRegistry`). Ne pas passer par `google_fonts` : l'application doit
  fonctionner avec une connexion faible.
- **Polices de secours** (D17) : `NotoSansSecours` puis `NotoSansMathSecours`
  (`policesSecours`, déclarées dans le thème), pour chaque caractère absent
  d'Atkinson ou de Playwrite : exposants (10⁻³, 10ⁿ⁺ᵐ), flèches, grec (Ω, Δ,
  π), symboles mathématiques (ℝ, ≈, ≤), phonétique ([ʃ], [ɑ̃]), ¹ ² ³ en
  cursive, Ŋ ŋ. Sous-ensembles de Noto Sans et Noto Sans Math (OFL), 153 Ko.
  Un style appliqué « tel quel » (boutons, puces) doit répéter
  `fontFamilyFallback: policesSecours` ; `test/core/polices_test.dart` le vérifie.
- Avant de publier un contenu avec de nouveaux symboles, vérifier qu'ils sont
  couverts : relever les caractères utilisés (requête ci-dessous, en lecture),
  puis les comparer aux polices avec `tool/polices/sous_ensembles.py`, et
  l'adapter au besoin. Capture de contrôle : `symboles.png` de l'outil de captures.

  ```sql
  with t as (select coalesce(titre,'')||coalesce(introduction,'')||coalesce(corps,'')
               ||coalesce(a_retenir::text,'') as x from lecons
             union all select coalesce(enonce,'')||coalesce(corrige,'')
               ||coalesce(donnees::text,'')||coalesce(reponse::text,'') from exercices)
  select c, to_hex(ascii(c)) from (select regexp_split_to_table(x,'') c from t) s
  where ascii(c) > 591 group by c order by ascii(c);
  ```

| Style | Taille | Graisse | Usage |
| --- | --- | --- | --- |
| Titre d'écran | 26–28 | 700 | nom de matière |
| Titre de leçon (cursif) | 23, interligne 64 | 400 | page de leçon |
| Titre de partie (cursif, rouge) | 17, interligne 64 | 400 | `##` du corps |
| Texte de leçon | 16, interligne 32 | 400 | `Styles.lecon` |
| Titre de section | 15 | 600, `texteSecondaire` | `Styles.sectionTitre` |
| Étiquette | 13–14 | 600, `etiquette` | `Styles.etiquette` |
| Secondaire | 13 | 400 | `Styles.secondaire` |

## Page Seyès (`PageSeyes`)

- Interligne de 32 px (`interligne`), trois lignes fines entre deux lignes
  fortes, marge rouge de 2 px à 36 px du bord gauche, texte à 52 px.
- Les paragraphes de leçon ont une hauteur de ligne de 32 px pour tomber sur
  les lignes ; les titres prennent deux interlignes (64 px). Règle : tout bloc
  posé sur la page a une hauteur multiple de 32 px.
- Le texte **repose sur les lignes fortes**, comme dans un cahier : elles sont
  tracées à la ligne de base de `Styles.lecon`, mesurée sur la police réelle
  (`ligneDeBase`), pas à une position codée en dur.
- Les titres cursifs (titre de leçon, « À retenir », `#`/`##` du Markdown)
  passent par `SurLigneSeyes`, qui les décale au dessin seulement pour poser
  leur ligne de base sur une ligne forte, sans changer leur hauteur.
- Vérifié par `test/core/seyes_test.dart` (vraies polices, 1 px près).
  L'alignement vaut pour la taille de texte normale : avec un texte agrandi,
  les lignes restent un décor.
- La page défile avec ses lignes (le dessin est sous le contenu, pas fixe).
- Réservée à la leçon. Les exercices et les listes restent sur fond uni.

## Composants partagés

| Composant | Rôle |
| --- | --- |
| `ControleSegmente<T>` | choix de classe, onglets de leçon ; segment actif blanc sur fond `segment` |
| `DosCahier` | trait de couleur de la matière |
| `LienRetour` | « ‹ Mes cours », retour ou repli |
| `LargeurLecture` | limite le contenu à 720 px (web, tablette) |
| `Chargement`, `MessageErreur`, `MessageVide` | les trois états hors contenu |
| `MarkdownCahier` | Markdown sur page Seyès ou fond uni |
| `TuileChoix` | réponse à toucher, états neutre / sélectionné / juste / faux / atténué, icône ✓ ou ✗ |
| `RetourChamp` | « Juste » ou « Attendu : … » sous un champ corrigé |

Boutons : `FilledButton` (action principale, hauteur 52, rayon 12),
`OutlinedButton` (action secondaire), `TextButton` (liens). Une seule action
principale par écran.

## Accessibilité (obligatoire)

- Cibles tactiles ≥ 44 × 44 px (`MaterialTapTargetSize.padded` sur les puces).
- Contraste ≥ 4,5:1 pour tout texte ; les couleurs de matière ne portent
  jamais de texte.
- Juste / faux : toujours une icône et un libellé en plus de la couleur.
- `Semantics(header: true)` sur les titres ; `selected` et
  `inMutuallyExclusiveGroup` sur les choix exclusifs ; `liveRegion` sur les
  retours de correction et le chargement.
- Les décors (dos de cahier, marge, pastilles de progression) sont exclus de
  la sémantique (`ExcludeSemantics`) ; l'information qu'ils portent est dite
  autrement (texte « Exercice 2 sur 5 »).
- Tester avec TalkBack, et avec la taille de texte système à 200 % : rien ne
  doit être coupé (pas de hauteur fixe sur un conteneur de texte).

## Ton des textes

- Tutoiement de l'élève : « Tes matières en 4ème », « Reprendre où tu t’es arrêté ».
- Phrases courtes, vocabulaire du collège. Pas de jargon technique dans
  l'interface (« Impossible de charger » plutôt qu'une exception).
- Les états vides disent ce qui se passe et quand : « Cette leçon est en cours
  de vérification. Elle sera bientôt en ligne. »
- Pas d'emoji. Apostrophe typographique (’).
