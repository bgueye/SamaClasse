# Fiche Google Play (phase 5)

Textes et réponses à recopier dans la Play Console pour `sn.samaclasse.app`.
Préparé le 21/11/2026 d'après le code et la base à cette date (version
`0.2.0+2`). **Points à trancher par Bocar : section « Décisions ».** Les
longueurs indiquées sont vérifiées (limites de Google entre parenthèses).

## Décisions avant d'envoyer

1. **Tranches d'âge du public cible.** Les élèves de 4ème ont souvent 13 ou
   14 ans, parfois 12. Cocher « moins de 13 ans » soumet l'application au
   programme Familles de Google (exigences plus strictes, examen plus long).
   L'application y est plutôt prête : pas de publicité, pas d'outil de
   mesure, pas de connexion obligatoire, aucune donnée de l'enfant sans le
   parent. Proposition : **13-15, 16-17 et 18 ans et plus** (élèves et
   parents) pour le premier envoi ; ajouter les moins de 13 ans plus tard si
   des classes de 6ème ou 5ème arrivent.
2. **Accès pour l'examen de Google.** Lire et s'exercer ne demandent aucun
   compte, mais l'espace parents et « Leçons à vérifier » demandent une
   connexion par code reçu par e-mail : l'examinateur ne peut pas recevoir
   le code. Proposition : déclarer que ces parties sont restreintes et
   fournir une adresse de test dont Bocar lit les messages (par exemple une
   redirection `examen@samaclasse.app`), ou expliquer qu'elles sont
   facultatives. Aucun mot de passe n'existe.
3. **Empreinte d'adresse IP des signalements** (D38). Gardée une heure, hors
   de toute fiche de l'élève, seulement contre l'envoi en masse. Proposition :
   la déclarer quand même (section « Sécurité des données », « Autres ID »,
   finalité « Prévention de la fraude, sécurité »), par prudence.
4. **Nom d'éditeur** affiché sous le titre : celui du compte développeur
   (« Bocar Gueye » ou « SamaClasse »). Il se règle dans le compte, pas dans
   la fiche.
5. **Test fermé obligatoire ?** Pour un compte développeur **personnel**
   créé après novembre 2023, Google exige un test fermé avec au moins
   12 testeurs pendant 14 jours avant la production. Pour un compte
   d'organisation, ce n'est pas exigé. À vérifier dans la Play Console.

## Fiche principale

### Nom de l'application (30 caractères au plus)

`SamaClasse` (10)

Variante si Bocar veut expliquer dans le titre :
`SamaClasse – Leçons, exercices` (30)

### Description courte (80 caractères au plus)

`Le programme scolaire du Sénégal : leçons et exercices corrigés, même hors ligne` (80)

### Description complète (4 000 caractères au plus)

```text
SamaClasse, c'est le programme scolaire du Sénégal dans ta poche : pour chaque classe et chaque matière, les chapitres du programme, les leçons et leurs exercices corrigés.

POUR LES ÉLÈVES
• Des leçons claires, présentées comme une page de cahier, avec l'essentiel « À retenir ».
• Des exercices corrigés tout de suite : QCM, vrai ou faux, relier, tableaux, calculs et questions de cours.
• Un indice quand tu bloques, avant de voir le corrigé.
• « Interroge-moi » : des cartes de révision pour vérifier ce que tu as retenu.
• « Écouter l'essentiel » : le résumé de chaque leçon lu à voix haute, en anglais et en espagnol pour les leçons de langue.
• Hors connexion : une fois téléchargé, tout le contenu se lit sans internet.
• Aucun compte nécessaire pour lire et s'exercer.

POUR LES PARENTS
• Un espace parents facultatif : connexion par un code reçu par e-mail, sans mot de passe.
• Un profil pour chaque enfant, avec son prénom et sa classe seulement. Son téléphone se lie à son profil avec un code.
• Le suivi de la semaine : leçons lues, exercices réussis, jours travaillés, et « Que lui demander ce soir ? ».
• Jamais ce que l'enfant écrit dans les exercices : seulement le résultat.

POUR LES ENSEIGNANTS
• Une fiche à imprimer pour chaque leçon : résumé, exercices, et corrigé sur une page à part.
• Le mode projection, pour montrer la leçon en classe sur grand écran.
• « Envoyer cette leçon » par WhatsApp, SMS ou toute autre application.

DES LEÇONS VÉRIFIÉES
Chaque leçon suit le cahier des élèves et est relue avant d'être publiée. Une erreur ? Le bouton « Signaler une erreur » prévient l'équipe, qui corrige la leçon pour tout le monde.

CLASSES ET MATIÈRES
Disponibles : 4ème et Seconde L. D'autres classes arrivent.
Matières : français, anglais, espagnol, mathématiques, sciences physiques, SVT, histoire, géographie, éducation civique et économie.

Sans publicité. Données hébergées dans l'Union européenne.
Politique de confidentialité : https://samaclasse.app/confidentialite/
Contact : contact@samaclasse.app
```

(2 033 caractères.)

Points vérifiés dans le code : « Écouter l'essentiel » a un script pour les
23 leçons ; « Écouter la leçon » n'en a qu'un (leçon 28), il n'est donc pas
annoncé. Le hors connexion porte sur tout le contenu publié (D16).

### Catégorie et coordonnées

- Type : application ; catégorie : **Enseignement**.
- Tags proposés : Éducation, Révisions scolaires, Devoirs.
- E-mail : `contact@samaclasse.app` ; site : `https://samaclasse.app`.
- Téléphone : facultatif (laisser vide).

### Éléments graphiques

| Élément | Format exigé | État |
| --- | --- | --- |
| Icône | PNG 512 × 512, 32 bits | **prête** : `build/play/icone_512.png` (dessin D19, carré plein) |
| Image de présentation | PNG ou JPEG 1024 × 500 | **prête** : `build/play/presentation_1024x500.png` |
| Captures téléphone | 2 à 8, rapport 9:16 ou 16:9, côté long ≤ 2 × côté court | **prêtes** : 8 en 1080 × 1920 |

L'icône et l'image de présentation se fabriquent avec
`flutter test tool/play/play_store_test.dart` (formats vérifiés par le test).
L'image de présentation reprend le protège-cahier de l'icône (bleu encre,
lignes Seyès, marge rouge) : à gauche « SamaClasse » en écriture de cahier,
« Leçons et exercices corrigés du programme sénégalais », puis « Indices,
révisions, suivi des parents / Même sans internet » ; à droite, une page de
cahier « À retenir » inclinée (texte réel de la leçon 1). Le texte reste
dans la moitié gauche, loin des bords que Google peut recadrer.

Les 8 captures se fabriquent avec
`flutter test tool/captures/captures_test.dart --plain-name play_store` et
arrivent dans `build/captures/play/` (le test vérifie le format 1080 × 1920) :

1. `1_accueil` : les matières de 4ème et leurs leçons prêtes ;
2. `2_matiere` : sciences physiques, chapitres et leçons prêtes ;
3. `3_lecon` : la leçon sur sa page de cahier ;
4. `4_a_retenir` : « À retenir » et la barre « Écouter l'essentiel » ;
5. `5_exercice_indice` : un exercice avec l'indice ouvert ;
6. `6_exercice_corrige` : le corrigé et « Avais-tu juste ? » ;
7. `7_interroge_moi` : une carte de révision ;
8. `8_suivi` : « Suivi de mes enfants » (profils fictifs Awa et Moussa).

Données : le jeu enregistré des tests, complété avec l'état réel de la base au
21/11/2026 (nombre de leçons par matière, leçon 29, script « À retenir » et
indices de la leçon 1). Limite connue : l'anglais de 4ème, ajouté après le
relevé, manque à la liste de l'accueil (hors de l'écran capturé).

La fiche à imprimer (PDF) n'est pas un écran : elle peut être montrée dans
l'image de présentation plutôt qu'en capture.

## Contenu de l'application (Play Console › Règles › Contenu)

### Règles de confidentialité

`https://samaclasse.app/confidentialite/`

### Publicités

**Non**, l'application ne contient pas de publicité.

### Accès à l'application

Voir la décision 2. Texte proposé si une adresse de test existe :

```text
Lire les leçons et faire les exercices ne demande aucun compte.
L'espace parents (facultatif) se connecte par un code envoyé par e-mail.
Adresse de test : examen@samaclasse.app ; demandez le code depuis
l'application, nous vous le transmettons à la demande à contact@samaclasse.app.
```

### Classification du contenu (questionnaire IARC)

- Catégorie : **Référence, actualités ou éducation**.
- Violence, peur, sexualité, langage grossier, drogues, jeux d'argent :
  **non** partout. Les leçons d'histoire évoquent la traite négrière et la
  colonisation de façon éducative, sans images violentes.
- Les utilisateurs peuvent-ils interagir ou échanger des contenus ? **Non** :
  aucun échange entre utilisateurs. Le texte d'un signalement n'est lu que
  par les rédacteurs ; rien n'est publié.
- Partage de la position : **non**. Achats numériques : **non**.
- Résultat attendu : PEGI 3 / Tout public.

### Public cible et contenu

Voir la décision 1. L'application ne s'adresse pas aux enfants par des
personnages ou des jeux ; c'est un outil scolaire pour élèves et parents.

### Application d'actualités, application gouvernementale, santé, finances

**Non** pour chacune.

### Suppression des données

- URL de demande de suppression : `https://samaclasse.app/suppression-compte/`
- Dans l'application : « Espace parents » › « Supprimer mon compte ».
- Le compte, les profils des enfants, les leçons lues et les résultats sont
  supprimés ; les téléphones liés sont déliés.

## Sécurité des données

### Vue d'ensemble

| Question | Réponse |
| --- | --- |
| L'application collecte-t-elle ou partage-t-elle des données ? | **Oui** (collecte) |
| Les données sont-elles chiffrées en transit ? | **Oui** (HTTPS) |
| Les utilisateurs peuvent-ils demander la suppression ? | **Oui** (dans l'application et par l'URL ci-dessus) |
| Données partagées avec des tiers ? | **Non**. Supabase (hébergement, Paris) et Resend (envoi des codes par e-mail) agissent pour notre compte : ce ne sont pas des partages au sens de Google. |

### Données collectées

Toutes sont **facultatives** : l'application se lit et s'utilise sans compte.
Aucune n'est vendue ni utilisée pour de la publicité.

| Catégorie Google | Donnée réelle | Finalités | Facultatif |
| --- | --- | --- | --- |
| Infos personnelles › Adresse e-mail | e-mail du parent (connexion par code) | Fonctionnalités de l'appli ; Gestion du compte | Oui |
| Infos personnelles › Nom | prénom de chaque enfant | Fonctionnalités de l'appli | Oui |
| Activité dans l'appli › Interactions avec l'appli | leçons lues (date) ; résultats aux exercices (réussi ou non, score, date) ; jamais le texte saisi | Fonctionnalités de l'appli (suivi du parent) | Oui |
| Activité dans l'appli › Autre contenu généré par l'utilisateur | précision facultative d'un signalement d'erreur (500 caractères au plus) | Fonctionnalités de l'appli (correction des leçons) | Oui |
| Photos et vidéos › Photos | schémas photographiés par les rédacteurs (comptes attribués à la main) | Fonctionnalités de l'appli | Oui |
| Identifiants de l'appareil ou autres › Autres ID | identifiant technique anonyme d'un téléphone d'enfant lié ; type d'appareil (« Android ») | Fonctionnalités de l'appli | Oui |
| Identifiants de l'appareil ou autres › Autres ID | empreinte de l'adresse IP d'un signalement, effacée après une heure (décision 3) | Prévention de la fraude, sécurité et conformité | Oui |

**Non collectées** : position, contacts, messages, agenda, fichiers,
audio (la lecture vocale se fait sur le téléphone), santé, finances,
historique de navigation, identifiant publicitaire.

## Version et notes de version

- Version envoyée : nom `0.2.0`, numéro `2` (`pubspec.yaml`). Le numéro doit
  augmenter à chaque envoi ; passer à `0.2.0+3` si un `.aab` numéro 2 a
  déjà été envoyé.
- Paquet : `build/app/outputs/bundle/release/app-release.aab`, signé avec la
  clé d'envoi (voir `ARCHITECTURE.md`, « Signature Android »).
- Notes de version (500 caractères au plus) :

```text
Première version de SamaClasse : les leçons et exercices corrigés de 4ème et de Seconde L, un indice avant le corrigé, « Écouter l'essentiel », les cartes « Interroge-moi », la fiche à imprimer, l'espace parents avec le suivi de la semaine, et « Signaler une erreur ».
```

## Après l'envoi

- Signature : activer la signature d'application par Google Play (proposée
  au premier envoi), puis relever l'empreinte SHA-256 de la clé de Google
  (« Intégrité de l'application ») pour les App Links (`assetlinks.json`).
- Test fermé : liste de testeurs par e-mail (12 au moins si exigé), lien
  d'adhésion à leur envoyer ; 14 jours sans interruption.
