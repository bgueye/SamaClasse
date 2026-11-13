# Décisions prises

Chaque décision indique qui l'a prise : **Bocar** (choix du propriétaire) ou
**proposition technique** (choix fait pendant la conception, qu'il peut encore
remettre en cause). À compléter à chaque décision nouvelle, en haut de liste.

---

### D13. Exercices : un exercice par écran, toutes ses questions ensemble
*Proposition technique, 13/11/2026.*
La maquette montrait une affirmation de vrai ou faux par écran. Ce format ne
convient pas aux exercices « relier », tableau ou calcul. Un écran par exercice,
correction de toutes ses questions d'un coup, retour par question.
À revoir si : les tests avec les enfants montrent que c'est trop long sur petit écran.

### D12. Brouillons libres non envoyés
*Proposition technique, 13/11/2026.*
Les réponses libres (questions de cours, rédactions) restent sur l'appareil ;
l'élève compare avec le corrigé et s'auto-évalue. Évite de stocker des textes
d'enfants. L'interface le dit à l'élève : la phase 3 doit respecter cette promesse.

### D11. Correction dans l'application
*Proposition technique, 12/11/2026.*
Les réponses attendues sont lues par l'application et la correction se fait
sur le téléphone : rapide, possible hors connexion. Contrepartie : un élève
curieux peut lire les réponses dans les échanges réseau.
À revoir si : les exercices servent un jour à une évaluation notée (correction
côté serveur par une fonction).

### D10. Polices embarquées, en instances statiques
*Proposition technique, 13/11/2026.*
Atkinson Hyperlegible Next (400/600/700) et Playwrite FR Moderne (400)
embarquées plutôt que téléchargées : l'application doit marcher avec une
connexion faible. Instances statiques pour un rendu fiable des graisses.

### D9. Pas de gestionnaire d'état, `InheritedWidget` + `FutureBuilder`
*Proposition technique, 13/11/2026, dans l'esprit de Bocar : ne pas complexifier trop tôt.*
Trois écrans de lecture n'en ont pas besoin. À revoir à la phase 2 (session
connectée) : d'abord un `ChangeNotifier` dans `AppScope`, une bibliothèque
seulement si nécessaire et après discussion.

### D8. go_router et adresses lisibles
*Proposition technique, 13/11/2026.*
L'application vise aussi le web : chaque écran a une adresse partageable
(`/lecon/12`) et sait recharger ses données sans état préalable.

### D7. Clé publishable passée au lancement
*Proposition technique, 12/11/2026.*
`--dart-define-from-file=config/supabase.json`, rien d'écrit dans le code.
`supabase_flutter` ^2.17.1 avec le paramètre `publishableKey`, qui facilitera
le passage à la v3 (encore en préversion `3.0.0-dev` au 13/11/2026).

### D6. Textes des leçons en Markdown, maths en Unicode
*Proposition technique, appliquée à toutes les leçons en base, 12/11/2026.*
Corps, introduction, énoncés et corrigés en Markdown. Exposants Unicode
(10⁻³), fractions en ligne (7/3), pas de LaTeX.

### D5. Formats JSON des exercices
*Proposition technique, 12/11/2026.* Voir `EXERCICES.md`.

### D4. Leçons visibles seulement une fois publiées
*Bocar, 12/11/2026.*
Une leçon reste `a_verifier` tant que ses points à vérifier ne sont pas levés
avec les cahiers. Les RLS l'imposent. Bocar seul publie.

### D3. Le cahier fait foi
*Bocar.*
Les leçons suivent les cahiers des élèves : plan conservé, compléments signalés,
rien d'inventé. Les erreurs de fond de l'élève sont corrigées et listées.

### D2. Base Supabase dédiée
*Bocar.*
Projet `samaclasse` séparé de celui d'At-Tijaniya.

### D1. Commencer par la 4ème et la Seconde L
*Bocar.*
Les classes de ses enfants, dont les cahiers alimentent les leçons. Le schéma
prévoit tout le cursus (primaire, collège, lycée).
