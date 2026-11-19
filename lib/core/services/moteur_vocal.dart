// Synthèse vocale du téléphone, pour « Écouter la leçon ».
//
// Derrière une interface, comme ChoixImage : `flutter_tts` passe par un canal
// natif absent de `flutter test`. Les tests passent un faux moteur à
// `AppScope` et vérifient ainsi tout le comportement du lecteur (ordre des
// passages, changement de voix, pause, saut d'une langue absente) sans
// téléphone.

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Ce dont le lecteur de leçon a besoin d'un moteur de synthèse vocale.
abstract class MoteurVocal {
  /// Réglages faits une fois, avant la première lecture.
  Future<void> preparer({required double vitesse});

  /// `true` si une voix existe pour [langue] (code BCP-47, ex. `en-GB`).
  Future<bool> langueDisponible(String langue);

  Future<void> choisirLangue(String langue);

  /// Lit [texte] et ne se termine qu'à la fin de la lecture (ou à [arreter]).
  Future<void> dire(String texte);

  Future<void> arreter();
}

/// Moteur réel : la synthèse vocale du système (paquet `flutter_tts`).
///
/// Android et iOS : moteur du téléphone (voix à installer dans les réglages
/// de synthèse vocale). Web : API Web Speech, voix fournies par le
/// navigateur.
class MoteurFlutterTts implements MoteurVocal {
  MoteurFlutterTts();

  // Créé au premier usage : construire FlutterTts branche le canal natif,
  // inutile tant que l'élève n'a pas appuyé sur Lecture.
  late final FlutterTts _tts = FlutterTts();

  @override
  Future<void> preparer({required double vitesse}) async {
    // Sans cela, `speak` rend la main tout de suite et les passages se
    // couperaient les uns les autres.
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(vitesse);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS : la catégorie par défaut se tait quand le téléphone est en mode
      // silencieux. « playback » lit quand même, comme une vidéo : l'élève a
      // appuyé lui-même sur Lecture. Un échec ne doit pas empêcher la lecture.
      try {
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, const []);
      } catch (_) {}
    }
  }

  @override
  Future<bool> langueDisponible(String langue) async {
    try {
      return await _tts.isLanguageAvailable(langue) == true;
    } catch (_) {
      // Web (ou plateforme qui ne sait pas répondre) : on suppose la langue
      // disponible plutôt que de ne rien lire du tout.
      return true;
    }
  }

  @override
  Future<void> choisirLangue(String langue) => _tts.setLanguage(langue);

  @override
  Future<void> dire(String texte) => _tts.speak(texte);

  @override
  Future<void> arreter() => _tts.stop();
}
