# Analyse de la feuille de route de l'app

*20/11/2026. Analyse de l'image
[`feuille_de_route_app.png`](feuille_de_route_app.png)
au regard du code et de la base à cette date. Document de travail : rien
n'est décidé ici. Les décisions prises vont dans `DECISIONS.md`, les étapes
retenues dans `FEUILLE_DE_ROUTE.md`.*

## Ce que dit l'image

Principe : **« D'abord des classes complètes, puis les fonctions. »**

| Colonne | Cartes |
| --- | --- |
| 1. Maintenant : rapide, utile à tous | Mode hors ligne (fait), Signaler une erreur, Recherche et glossaire, Confort de lecture, Play Store (en cours) |
| 2. Ensuite : les comptes | Comptes et rôles (fait), Progression (fait), Révision espacée, Espace parent (résumé de la semaine par WhatsApp), Compositions et examens |
| 3. Pour grandir : les enseignants | Espace enseignant, Contribution de leçons |
| 4. Plus tard | Prof IA, Wolof, Partage WhatsApp |

Le bandeau du bas désigne **le vrai frein, le contenu**. Une flèche relie ce
bandeau à la contribution de leçons, « le levier pour tout couvrir ».

## Constat au 20/11/2026

| Carte | Constat |
| --- | --- |
| **Le contenu** | 23 leçons publiées pour 196 chapitres (l'image dit 194), deux classes, 126 exercices : environ 12 % de la 4ème et de la Seconde L. 22 leçons n'ont pas encore de script audio (D34) ; seule la leçon 28 en a un. |
| **Play Store** | Signature commencée dans `android/app/build.gradle.kts`, pas encore enregistrée dans git. Restent la fiche et le test fermé. |
| **Signaler une erreur** | « Demander une correction » existe, mais pour les rédacteurs seulement (D33). Pour les élèves et les parents, il faut une table de signalements accessible en écriture à une session anonyme, donc une migration, avec une limite d'envois contre le spam. |
| **Recherche et glossaire** | Rien n'existe. Tout le contenu est déjà sur le téléphone (D16) : la recherche peut se faire sur place, sans réseau ni changement de base. Les champs `a_retenir` (notion et essentiel) forment déjà un premier glossaire de plus de 150 notions. |
| **Confort de lecture** | La taille du texte suit le réglage du téléphone, et l'affichage est testé à 200 %. Un réglage dans l'application est simple. Le mode sombre est lourd : `Couleurs` ne contient que des constantes, utilisées partout, et la charte « cahier d'écolier » repose sur le papier blanc (`DESIGN.md`). Question de design à trancher d'abord. |
| **Révision espacée** | La table `resultats` contient ce qu'il faut (`exercice_id`, `reussi`, `fait_le`). Mais un élève sans profil ne garde pas d'historique : il faut un historique local, même sans compte. |
| **Résumé de la semaine par WhatsApp** | L'envoi automatique demande l'API WhatsApp Business : service payant, modèles de messages à faire valider. Alternative gratuite : un bouton « Partager le résumé » qui ouvre WhatsApp avec un texte prêt. |
| **Partage WhatsApp** | Presque prêt : l'application web est en ligne sur samaclasse.app (`.github/workflows/site.yml`) et les adresses `/lecon/12` y fonctionnent. Il manque le bouton de partage. L'ouverture directe dans l'application Android demande les App Links (`assetlinks.json` sur le site), une fois la clé de signature définitive. Peu de travail, utile pour faire connaître l'application. |
| **Compositions et examens** | Surtout du contenu (annales du BFEM et du Bac), plus une table pour les rattacher aux chapitres. |
| **Contribution de leçons** | La moitié du circuit existe : photos dans la base (D31), validation (phase 4), corrections et versions (D33). Il manque le dépôt des photos du cahier et la rédaction au gabarit, faite aujourd'hui à la main avec Claude Code. L'automatiser demande une Edge Function qui appelle un modèle d'IA, avec un coût par leçon. |
| **Espace enseignant** | Le plus gros chantier : nouveau rôle, classes d'élèves, devoirs, règles RLS à revoir. Les enfants n'ont pas d'identifiants (D21) : il faudra choisir comment rattacher un élève à un enseignant. |
| **Prof IA** | Première étape faite : le lecteur vocal (D34). La suite demande un modèle d'IA côté serveur, des règles de sécurité adaptées à des mineurs, et un coût par question. |
| **Wolof** | Aucun téléphone n'a de voix wolof : explications écrites, ou enregistrées par une vraie personne. |

## Rythme du contenu

À 8 leçons publiées toutes les deux semaines (avec exercices et script
audio), il faudrait environ 22 périodes de deux semaines, soit une dizaine de
mois, pour couvrir les deux classes. D'où l'intérêt de la contribution de
leçons.

## Questions ouvertes pour Bocar

1. Rythme du contenu, et choix entre finir la 4ème d'abord ou avancer les
   deux classes ensemble.
2. Mode sombre : le garder malgré la charte papier, ou se limiter à un
   « papier atténué » ?
3. Résumé de la semaine : envoi automatique (API payante) ou partage manuel
   gratuit ?
4. Signaler une erreur : ouvert à tous les élèves, y compris sans profil, ou
   seulement à ceux qui ont un profil ou un parent connecté ?
5. Contribution : qui peut déposer des photos (enseignants invités,
   parents ?), et quel budget pour la rédaction automatique ?

## Découpage en sprints

Mis de côté le 20/11/2026 : Bocar veut en retirer plusieurs points et y
revenir plus tard. Le découpage sera refait à partir de ce constat.
