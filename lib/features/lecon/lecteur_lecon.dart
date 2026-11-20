// « Écouter la leçon » : lecture à voix haute du script d'une leçon
// (`lecons.script_audio`) avec la synthèse vocale du téléphone.
//
// Deux parties :
// - LecteurLecon, la logique (ordre des passages, voix, pause, sauts), sans
//   widget : testée avec un faux MoteurVocal ;
// - BarreLecteur, la barre affichée en bas de l'écran de leçon.
//
// Chaque passage est lu dans sa langue (fr-FR, en-GB, es-ES…). Une langue
// absente du téléphone n'est jamais lue par une autre voix (de l'anglais lu
// par une voix française serait faux et trompeur) : le passage est sauté et
// la barre invite à installer la voix.

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/services/moteur_vocal.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/composants.dart';
import '../../data/segment_audio.dart';

enum EtatLecteur { arrete, lecture, pause }

/// Variantes proches essayées quand la voix exacte manque, dans l'ordre.
const Map<String, List<String>> _replis = {
  'en-GB': ['en-US'],
  'en-US': ['en-GB'],
  'fr-FR': ['fr-CA'],
  'es-ES': ['es-US', 'es-MX'],
};

/// Langues à essayer pour un passage en [demandee] : elle-même, ses
/// variantes connues, puis la langue sans région (`en`).
///
/// Jamais une autre langue : mieux vaut sauter le passage que le lire avec
/// une voix étrangère.
List<String> languesAEssayer(String demandee) {
  final base = demandee.split(RegExp('[-_]')).first;
  return {demandee, ...?_replis[demandee], base}.toList();
}

/// Nom d'une langue pour l'avertissement « voix absente » : l'élève ne
/// connaît pas les codes BCP-47.
String nomLangue(String code) => switch (code.split(RegExp('[-_]')).first.toLowerCase()) {
      'fr' => 'française',
      'en' => 'anglaise',
      'es' => 'espagnole',
      'de' => 'allemande',
      'ar' => 'arabe',
      'pt' => 'portugaise',
      'it' => 'italienne',
      _ => code,
    };

/// Texte de l'avertissement pour les langues sans voix sur ce téléphone.
String messageVoixAbsentes(Iterable<String> langues) {
  final noms = {for (final l in langues) nomLangue(l)}.toList();
  final liste = 'Voix ${noms.join(', ')}';
  final pluriel = noms.length > 1;
  return '$liste absente${pluriel ? 's' : ''} de ce téléphone : ces passages sont sautés. '
      'Installe-${pluriel ? 'les' : 'la'} dans les réglages de synthèse vocale.';
}

/// Lit le script d'une leçon passage par passage, en changeant de voix selon
/// la langue de chaque passage.
class LecteurLecon extends ChangeNotifier {
  LecteurLecon(this.segments, this._moteur);

  final List<SegmentAudio> segments;
  final MoteurVocal _moteur;

  EtatLecteur _etat = EtatLecteur.arrete;
  EtatLecteur get etat => _etat;

  int _index = 0;

  /// Passage en cours (ou celui qui sera lu à la reprise).
  int get index => _index;

  /// Langues demandées par le script mais absentes du téléphone.
  final Set<String> languesAbsentes = {};

  /// Un peu plus lent que la normale (0,5 avec flutter_tts), pour des élèves.
  static const double vitesse = 0.45;

  /// Langue utilisable trouvée pour chaque langue demandée (`null` : aucune).
  /// Mise en cache : la question au moteur est lente sur certains téléphones.
  final Map<String, String?> _languesResolues = {};
  bool _pret = false;
  bool _detruit = false;

  /// Chaque pause, arrêt ou saut incrémente la session : une boucle de
  /// lecture plus ancienne voit qu'elle est périmée et s'arrête sans rien
  /// toucher. Utile aussi si un moteur ne termine pas `dire` sur un arrêt.
  int _session = 0;

  void _notifier() {
    if (!_detruit) notifyListeners();
  }

  Future<String?> _langueUtilisable(String demandee) async {
    if (_languesResolues.containsKey(demandee)) return _languesResolues[demandee];
    for (final langue in languesAEssayer(demandee)) {
      if (await _moteur.langueDisponible(langue)) return _languesResolues[demandee] = langue;
    }
    _languesResolues[demandee] = null;
    languesAbsentes.add(demandee);
    _notifier();
    return null;
  }

  /// Lit à partir du passage en cours (depuis son début) jusqu'à la fin.
  Future<void> lire() async {
    if (segments.isEmpty || _etat == EtatLecteur.lecture || _detruit) return;
    final session = ++_session;
    _etat = EtatLecteur.lecture;
    _notifier();
    if (!_pret) {
      await _moteur.preparer(vitesse: vitesse);
      _pret = true;
    }

    while (session == _session) {
      final segment = segments[_index];
      final langue = await _langueUtilisable(segment.lang);
      if (session != _session) return;
      if (langue != null) {
        await _moteur.choisirLangue(langue);
        if (session != _session) return;
        await _moteur.dire(segment.texte);
      }
      if (session != _session) return;
      if (_index >= segments.length - 1) {
        // Fin du script : retour à l'état arrêté, au premier passage.
        _etat = EtatLecteur.arrete;
        _index = 0;
        _notifier();
        return;
      }
      _index++;
      _notifier();
    }
  }

  /// Pause portable (Android, iOS, web) : on arrête la voix et on garde la
  /// position ; la reprise relit le passage en cours depuis son début (la
  /// vraie pause au milieu d'une phrase n'existe pas partout).
  Future<void> pause() async {
    if (_etat != EtatLecteur.lecture) return;
    _session++;
    _etat = EtatLecteur.pause;
    _notifier();
    await _moteur.arreter();
  }

  /// Arrête la voix et revient au premier passage.
  Future<void> arreter() async {
    _session++;
    _etat = EtatLecteur.arrete;
    _index = 0;
    _notifier();
    await _moteur.arreter();
  }

  /// Saute au passage [nouvelIndex] ; la lecture continue si elle était en
  /// cours, sinon le lecteur attend en pause sur ce passage.
  Future<void> allerA(int nouvelIndex) async {
    if (segments.isEmpty) return;
    final relancer = _etat == EtatLecteur.lecture;
    _session++;
    _index = nouvelIndex.clamp(0, segments.length - 1);
    _etat = EtatLecteur.pause;
    _notifier();
    await _moteur.arreter();
    if (relancer) await lire();
  }

  Future<void> precedent() => allerA(_index - 1);
  Future<void> suivant() => allerA(_index + 1);

  @override
  void dispose() {
    _detruit = true;
    _session++;
    // Sans attendre : l'écran disparaît, la voix doit se taire.
    _moteur.arreter().ignore();
    super.dispose();
  }
}

/// Barre « Écouter la leçon », en bas de l'écran de leçon.
///
/// Ne s'affiche pas (aucun espace réservé) si la leçon n'a pas de script.
/// La voix se met en pause dès qu'un autre écran passe par-dessus
/// (exercices, schémas…, ouverts par `push` : l'écran de leçon reste alors en
/// mémoire) et s'arrête quand l'écran de leçon est fermé.
class BarreLecteur extends StatefulWidget {
  const BarreLecteur({super.key, required this.segments, this.titre = 'Écouter la leçon'});

  final List<SegmentAudio> segments;

  /// Ce qui est lu, affiché à l'arrêt et sur le bouton Lecture :
  /// « Écouter la leçon » ou « Écouter l’essentiel » (D37).
  final String titre;

  @override
  State<BarreLecteur> createState() => _BarreLecteurState();
}

class _BarreLecteurState extends State<BarreLecteur> {
  /// Créé seulement si la leçon a un script : pas de moteur vocal pour rien.
  LecteurLecon? _lecteur;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.segments.isNotEmpty) {
      _lecteur ??= LecteurLecon(widget.segments, AppScope.of(context).creerMoteurVocal());
    }
    // Dépendance à la route : rappelé quand un écran la recouvre ou la
    // découvre. Pause (et non arrêt) pour reprendre au même passage en
    // revenant des exercices.
    if (!(ModalRoute.isCurrentOf(context) ?? true)) _lecteur?.pause();
  }

  @override
  void dispose() {
    _lecteur?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lecteur = _lecteur;
    if (lecteur == null) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Couleurs.papier,
        border: Border(top: BorderSide(color: Couleurs.bordure)),
      ),
      child: LargeurLecture(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: ListenableBuilder(listenable: lecteur, builder: (context, _) => _contenu(lecteur)),
        ),
      ),
    );
  }

  Widget _contenu(LecteurLecon l) {
    final enLecture = l.etat == EtatLecteur.lecture;
    final arrete = l.etat == EtatLecteur.arrete;
    final dernier = l.segments.length - 1;
    final numero = l.index + 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (l.languesAbsentes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            // Icône et texte : l'avertissement ne repose pas sur la couleur.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1, right: 6),
                  child: Icon(Icons.warning_amber_rounded, size: 18, color: Couleurs.etiquette),
                ),
                Expanded(
                  child: Text(
                    messageVoixAbsentes(l.languesAbsentes),
                    style: Styles.secondaire.copyWith(color: Couleurs.texte),
                  ),
                ),
              ],
            ),
          ),
        // Le passage lu s'affiche pour que l'élève suive des yeux.
        Text(
          arrete ? widget.titre : l.segments[l.index].texte,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: arrete
              ? const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Couleurs.encre)
              : const TextStyle(fontSize: 15, color: Couleurs.texte),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: arrete ? 0 : numero / l.segments.length,
          color: Couleurs.encre,
          backgroundColor: Couleurs.segment,
          // Étiquette parlante pour les lecteurs d'écran ; la valeur (en %)
          // est calculée par Flutter, qui la veut numérique.
          semanticsLabel: arrete
              ? 'Progression de la lecture'
              : 'Passage $numero sur ${l.segments.length}',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Passage précédent',
              color: Couleurs.encre,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: l.index > 0 ? l.precedent : null,
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: enLecture ? 'Pause' : (l.etat == EtatLecteur.pause ? 'Reprendre' : widget.titre),
              style: IconButton.styleFrom(
                backgroundColor: Couleurs.encre,
                foregroundColor: Couleurs.texteSurEncre,
              ),
              iconSize: 32,
              icon: Icon(enLecture ? Icons.pause_rounded : Icons.play_arrow_rounded),
              onPressed: enLecture ? l.pause : l.lire,
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Passage suivant',
              color: Couleurs.encre,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: l.index < dernier ? l.suivant : null,
            ),
            IconButton(
              tooltip: 'Arrêter',
              color: Couleurs.encre,
              icon: const Icon(Icons.stop_rounded),
              onPressed: arrete ? null : l.arreter,
            ),
          ],
        ),
      ],
    );
  }
}
