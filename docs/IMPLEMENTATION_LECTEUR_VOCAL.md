# SamaClasse — Implémentation du lecteur vocal « Écouter la leçon »

Document de passation pour Claude Code. Rédigé le 19/11/2026.

## 1. Objectif

Ajouter sur l'écran de leçon une barre « Écouter la leçon » qui lit le cours à voix haute avec la synthèse vocale du téléphone. Chaque passage du script est lu dans sa langue : le français avec une voix française, l'anglais avec une voix anglaise, l'espagnol avec une voix espagnole.

C'est la première étape d'un projet plus large (un « prof » qui explique le cours et aide aux exercices). Cette tâche ne couvre **que le lecteur**.

## 2. Contexte du projet

- Application Flutter (Android, iOS, web) adossée à Supabase. Projet Supabase `samaclasse`, ref `earcfeorkfeenqprsxpg`.
- Accès aux données en **lecture seule** depuis l'app, avec `supabase_flutter` ^2.17.1 et la `publishableKey`. Les clés sont passées par `--dart-define-from-file=config/supabase.json`.
- Organisation connue du code (à vérifier dans le dépôt, elle peut avoir évolué) :
  - `lib/data/` : modèles, dépôt Supabase, correction automatique des exercices ;
  - routes go_router : `/`, `/classe/:id/matiere/:id`, `/lecon/:id`, `/lecon/:id/exercices` ;
  - écran de leçon : page à lignes Seyès, onglets « La leçon » et « À retenir ».
- Identité visuelle : le cahier d'écolier (encre bleue `#2140C9`, marge rouge). Titres en Playwrite FR Moderne, textes en Atkinson Hyperlegible Next, une couleur par matière. La barre doit utiliser le thème de l'app, sans couleurs codées en dur.
- Langue de l'interface : français.

## 3. Ce qui existe déjà dans la base (ne rien recréer)

Une migration `lecons_script_audio` a été appliquée le 19/11/2026 :

```sql
alter table public.lecons add column if not exists script_audio jsonb;
alter table public.lecons add constraint lecons_script_audio_is_array
  check (script_audio is null or jsonb_typeof(script_audio) = 'array');
```

**Format de `lecons.script_audio`** : une liste ordonnée de passages.

```json
[
  {"lang": "fr-FR", "texte": "Anglais, classe de quatrième. Leçon : le présent simple."},
  {"lang": "en-GB", "texte": "The present simple."}
]
```

- `lang` est un code BCP-47, passé tel quel à `flutter_tts` (`fr-FR`, `en-GB`, `es-ES`…).
- `texte` est rédigé pour l'oral : pas de Markdown, tableaux et symboles déjà convertis en phrases.
- `null` signifie que la leçon n'a pas de script : la barre ne doit pas s'afficher.

**Données de test** : seule la leçon **id 28** (« The present simple », 4e, anglais) a un script, de 47 passages en `fr-FR` et `en-GB`.

> ⚠️ **RLS** : l'app ne voit que les leçons au statut `publiee`. La leçon 28 est au statut `a_verifier` : elle est **invisible depuis l'app** tant que le propriétaire du projet ne l'a pas publiée. **Ne modifie ni les politiques RLS, ni le statut des leçons.** Si la leçon 28 n'est pas visible au moment du test, signale-le au lieu de contourner la règle.

## 4. Travail à faire

1. **Dépendance** : `flutter pub add flutter_tts`. Ne fixe pas la version à la main.
2. **Android** (Android 11 et plus) : dans `android/app/src/main/AndroidManifest.xml`, ajoute dans `<queries>` (crée le bloc s'il n'existe pas, comme enfant de `<manifest>`) :
   ```xml
   <intent>
       <action android:name="android.intent.action.TTS_SERVICE" />
   </intent>
   ```
   Vérifie aussi que `minSdkVersion` respecte le minimum exigé par la version installée de `flutter_tts` (voir son README).
   Si le dossier `android/` est régénéré par `installer.ps1` (`flutter create`), ajoute la même modification à ce script, sinon elle sera perdue.
3. **Modèle** : crée `lib/data/segment_audio.dart` (code en 6.1).
4. **Modèle `Lecon`** : ajoute un champ `final List<SegmentAudio> scriptAudio;`, rempli avec `SegmentAudio.listeDepuis(json['script_audio'])`. Vérifie que la requête du dépôt récupère bien `script_audio` : c'est automatique avec `select('*')`, sinon ajoute la colonne à la liste.
5. **Lecteur** : crée le fichier du lecteur (code en 6.2). Place-le là où le projet range les widgets de l'écran de leçon ; `lib/lecon/lecteur_lecon.dart` n'est qu'une proposition. Adapte les imports en conséquence.
6. **Écran de leçon** : affiche `BarreLecteur(segments: lecon.scriptAudio)`, de préférence en `bottomNavigationBar` du `Scaffold`, pour qu'elle reste visible quand on change d'onglet. La barre ne doit pas masquer le contenu de la page.
7. **Arrêt de la lecture** : la voix doit s'arrêter quand on quitte l'écran (retour arrière, passage aux exercices). C'est le cas si `BarreLecteur` est détruite avec l'écran (`dispose()` appelle `stop()`). Vérifie-le : avec un `StatefulShellRoute` ou un écran gardé en mémoire, il faut appeler `arreter()` explicitement.
8. **Tests** : ajoute un test unitaire pour `SegmentAudio.listeDepuis` (code en 6.3). Lance `flutter analyze` et `flutter test` ; tout doit passer sans nouvel avertissement.

## 5. Comportement attendu

| Situation | Comportement |
| --- | --- |
| Leçon sans script (`null` ou liste vide) | Aucune barre, aucun espace réservé |
| Appui sur Lecture | Lit les passages dans l'ordre, en changeant de voix selon `lang` |
| Pause | Arrête la voix, garde la position ; la reprise relit le passage en cours depuis son début |
| Précédent / Suivant | Saute au passage voisin ; continue la lecture si elle était en cours |
| Arrêt | Arrête la voix et revient au premier passage |
| Fin du script | Revient à l'état arrêté, au premier passage |
| Voix exacte absente (ex. en-GB) | Essaie une variante (en-US) ; `fr-FR` → `fr-CA` ; `es-ES` → `es-US`, `es-MX` |
| Langue complètement absente du téléphone | **Saute** le passage (jamais d'anglais lu par une voix française) et affiche un avertissement qui invite à installer la voix |
| Pendant la lecture | Le passage en cours s'affiche (2 lignes maximum) et une barre indique la progression |

La vitesse est de 0,45, un peu plus lente que la normale (0,5), pour des élèves. Les boutons ont des `tooltip` en français : ils servent aussi d'étiquettes pour les lecteurs d'écran.

## 6. Code proposé

Ce code a été écrit **sans pouvoir être compilé** (pas de SDK Flutter là où il a été rédigé). Relis-le, corrige-le si l'analyseur signale un problème, et adapte-le aux conventions du projet : nommage, gestion d'état, organisation des dossiers. Si le projet utilise déjà une solution de gestion d'état (Riverpod, Provider…), tu peux y brancher `LecteurLecon` plutôt que de garder le `ListenableBuilder`, à condition que le comportement de la section 5 reste identique.

### 6.1 `lib/data/segment_audio.dart`

```dart
/// Un passage du script de lecture d'une leçon (colonne `lecons.script_audio`).
///
/// Format en base : `[{"lang": "fr-FR", "texte": "..."}, ...]`
/// `lang` est un code BCP-47 passé tel quel au moteur de synthèse vocale.
class SegmentAudio {
  const SegmentAudio({required this.lang, required this.texte});

  final String lang;
  final String texte;

  factory SegmentAudio.fromJson(Map<String, dynamic> json) => SegmentAudio(
        lang: (json['lang'] as String?) ?? 'fr-FR',
        texte: (json['texte'] as String?) ?? '',
      );

  /// Convertit la valeur brute de `script_audio` (null ou liste JSON).
  /// Une leçon sans script renvoie une liste vide : le lecteur ne s'affiche pas.
  static List<SegmentAudio> listeDepuis(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map((m) => SegmentAudio.fromJson(Map<String, dynamic>.from(m)))
        .where((s) => s.texte.trim().isNotEmpty)
        .toList(growable: false);
  }
}
```

### 6.2 `lib/lecon/lecteur_lecon.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/segment_audio.dart';

enum EtatLecteur { arrete, lecture, pause }

/// Lit le script d'une leçon passage par passage, en changeant de voix
/// selon la langue de chaque passage (fr-FR, en-GB, es-ES...).
class LecteurLecon extends ChangeNotifier {
  LecteurLecon(this.segments);

  final List<SegmentAudio> segments;
  final FlutterTts _tts = FlutterTts();

  EtatLecteur etat = EtatLecteur.arrete;
  int index = 0;

  /// Langues demandées par le script mais absentes du téléphone.
  final Set<String> languesAbsentes = {};

  /// Vitesse un peu plus lente que la normale (0,5) pour des élèves.
  static const double vitesse = 0.45;

  /// Si la langue exacte manque, on essaie une variante proche.
  static const Map<String, List<String>> _replis = {
    'en-GB': ['en-US', 'en'],
    'en-US': ['en-GB', 'en'],
    'fr-FR': ['fr-CA', 'fr'],
    'es-ES': ['es-US', 'es-MX', 'es'],
  };

  final Map<String, String?> _languesResolues = {};
  bool _pret = false;

  /// Chaque pause, arrêt ou saut incrémente la session : la boucle de
  /// lecture en cours voit qu'elle est périmée et s'arrête proprement.
  int _session = 0;

  Future<void> _initialiser() async {
    if (_pret) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(vitesse);
    _pret = true;
  }

  Future<String?> _langueUtilisable(String demandee) async {
    if (_languesResolues.containsKey(demandee)) {
      return _languesResolues[demandee];
    }
    for (final langue in [demandee, ...?_replis[demandee]]) {
      if (await _tts.isLanguageAvailable(langue) == true) {
        return _languesResolues[demandee] = langue;
      }
    }
    _languesResolues[demandee] = null;
    languesAbsentes.add(demandee);
    notifyListeners();
    return null;
  }

  Future<void> lire() async {
    if (segments.isEmpty || etat == EtatLecteur.lecture) return;
    await _initialiser();
    final session = ++_session;
    etat = EtatLecteur.lecture;
    notifyListeners();

    while (true) {
      final segment = segments[index];
      final langue = await _langueUtilisable(segment.lang);
      if (session != _session) return;
      // Voix absente : on saute le passage plutôt que de lire de l'anglais
      // avec une voix française ; la barre affiche un avertissement.
      if (langue != null) {
        await _tts.setLanguage(langue);
        await _tts.speak(segment.texte);
      }
      if (session != _session) return;
      // On ne dépasse jamais le dernier passage : la barre lit segments[index].
      if (index >= segments.length - 1) break;
      index++;
      notifyListeners();
    }

    etat = EtatLecteur.arrete;
    index = 0;
    notifyListeners();
  }

  /// Pause portable (Android et iOS) : on arrête la voix et on garde la
  /// position ; la reprise relit le passage en cours depuis son début.
  Future<void> pause() async {
    if (etat != EtatLecteur.lecture) return;
    _session++;
    await _tts.stop();
    etat = EtatLecteur.pause;
    notifyListeners();
  }

  Future<void> arreter() async {
    _session++;
    await _tts.stop();
    etat = EtatLecteur.arrete;
    index = 0;
    notifyListeners();
  }

  Future<void> allerA(int nouvelIndex) async {
    if (segments.isEmpty) return;
    final relancer = etat == EtatLecteur.lecture;
    _session++;
    await _tts.stop();
    index = nouvelIndex.clamp(0, segments.length - 1);
    etat = EtatLecteur.pause;
    notifyListeners();
    if (relancer) await lire();
  }

  Future<void> precedent() => allerA(index - 1);
  Future<void> suivant() => allerA(index + 1);

  @override
  void dispose() {
    _session++;
    _tts.stop();
    super.dispose();
  }
}

/// Barre « Écouter la leçon », à placer en bas de l'écran de leçon :
/// `Scaffold(bottomNavigationBar: BarreLecteur(segments: lecon.scriptAudio))`.
/// Elle ne s'affiche pas si la leçon n'a pas de script.
class BarreLecteur extends StatefulWidget {
  const BarreLecteur({super.key, required this.segments});

  final List<SegmentAudio> segments;

  @override
  State<BarreLecteur> createState() => _BarreLecteurState();
}

class _BarreLecteurState extends State<BarreLecteur> {
  late final LecteurLecon _lecteur = LecteurLecon(widget.segments);

  @override
  void dispose() {
    _lecteur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.segments.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: _lecteur,
      builder: (context, _) {
        final l = _lecteur;
        final enLecture = l.etat == EtatLecteur.lecture;
        final dernier = l.segments.length - 1;

        return Material(
          elevation: 3,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (l.languesAbsentes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Voix absente sur ce téléphone : '
                        '${l.languesAbsentes.join(', ')}. '
                        'Installe-la dans les réglages de synthèse vocale.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  // Le passage lu s'affiche pour que l'élève suive.
                  if (l.etat != EtatLecteur.arrete)
                    Text(
                      l.segments[l.index].texte,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: l.etat == EtatLecteur.arrete
                        ? 0
                        : (l.index + 1) / l.segments.length,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Passage précédent',
                        icon: const Icon(Icons.skip_previous),
                        onPressed: l.index > 0 ? l.precedent : null,
                      ),
                      IconButton.filled(
                        tooltip: enLecture ? 'Pause' : 'Écouter la leçon',
                        iconSize: 32,
                        icon: Icon(enLecture ? Icons.pause : Icons.play_arrow),
                        onPressed: enLecture ? l.pause : l.lire,
                      ),
                      IconButton(
                        tooltip: 'Passage suivant',
                        icon: const Icon(Icons.skip_next),
                        onPressed: l.index < dernier ? l.suivant : null,
                      ),
                      IconButton(
                        tooltip: 'Arrêter',
                        icon: const Icon(Icons.stop),
                        onPressed:
                            l.etat == EtatLecteur.arrete ? null : l.arreter,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

### 6.3 Test unitaire `test/segment_audio_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
// Adapter le chemin au nom du package (voir pubspec.yaml).
import 'package:samaclasse/data/segment_audio.dart';

void main() {
  group('SegmentAudio.listeDepuis', () {
    test('null ou valeur non liste → liste vide', () {
      expect(SegmentAudio.listeDepuis(null), isEmpty);
      expect(SegmentAudio.listeDepuis('texte'), isEmpty);
      expect(SegmentAudio.listeDepuis({'lang': 'fr-FR'}), isEmpty);
    });

    test('lit les passages dans l\'ordre', () {
      final s = SegmentAudio.listeDepuis([
        {'lang': 'fr-FR', 'texte': 'Bonjour.'},
        {'lang': 'en-GB', 'texte': 'Hello.'},
      ]);
      expect(s.length, 2);
      expect(s[0].lang, 'fr-FR');
      expect(s[1].texte, 'Hello.');
    });

    test('ignore les passages vides et les éléments non objets', () {
      final s = SegmentAudio.listeDepuis([
        {'lang': 'fr-FR', 'texte': '   '},
        42,
        {'texte': 'Sans langue.'},
      ]);
      expect(s.length, 1);
      expect(s.single.lang, 'fr-FR'); // langue par défaut
    });
  });
}
```

## 7. Points de vigilance

- **Vitesse** : sur Android comme sur iOS, 0,5 correspond à peu près à la vitesse normale avec `flutter_tts` (1,0 est rapide). Vérifie ce comportement avec la version installée.
- **iOS** : vérifie que la lecture fonctionne téléphone en mode silencieux. Si ce n'est pas le cas, configure la catégorie audio avec `setIosAudioCategory` de `flutter_tts`, sans toucher au reste du projet.
- **Web** : `flutter_tts` passe par l'API Web Speech, dont les voix dépendent du navigateur. Le lecteur ne doit pas planter si `isLanguageAvailable` n'est pas pris en charge : entoure l'appel d'un `try/catch` qui considère alors la langue comme disponible.
- **Le texte du script n'est jamais modifié dans l'app** : il est rédigé et validé en base. L'app ne doit pas tenter de produire elle-même un texte à lire à partir du Markdown du corps.
- **Ne change pas** le schéma de la base, les politiques RLS, ni le statut des leçons.

## 8. Critères de fin

- [ ] `flutter analyze` sans nouvel avertissement, `flutter test` au vert.
- [ ] Sur une leçon sans script : aucune barre visible.
- [ ] Sur la leçon 28 (une fois visible) : lecture complète en alternant voix française et voix anglaise ; pause, reprise, précédent, suivant et arrêt conformes à la section 5.
- [ ] La voix s'arrête quand on quitte l'écran de leçon.
- [ ] Un court compte rendu : fichiers créés ou modifiés, écarts avec ce document et leur raison, ce qui n'a pas pu être testé.
