// Script de « Écouter la leçon » (`lecons.script_audio`) : lecture tolérante
// de la colonne, et passage par la copie hors connexion (D16).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';

import '../outils/faux_depot.dart';

void main() {
  group('SegmentAudio.listeDepuis', () {
    test('null ou valeur non liste → liste vide', () {
      expect(SegmentAudio.listeDepuis(null), isEmpty);
      expect(SegmentAudio.listeDepuis('texte'), isEmpty);
      expect(SegmentAudio.listeDepuis({'lang': 'fr-FR'}), isEmpty);
    });

    test('lit les passages dans l’ordre', () {
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

  group('Lecon.scriptAudio', () {
    final ligne = (donneesReelles['lecons'] as Map)['1'] as Map<String, dynamic>;

    test('leçon sans colonne ou colonne nulle → pas de script', () {
      expect(Lecon.fromJson(ligne).scriptAudio, isEmpty);
      expect(Lecon.fromJson({...ligne, 'script_audio': null}).scriptAudio, isEmpty);
    });

    test('script de « À retenir » (D37) : lu à part, vide sans colonne', () {
      expect(Lecon.fromJson(ligne).scriptRetenir, isEmpty);
      final lecon = Lecon.fromJson({
        ...ligne,
        'script_retenir': [
          {'lang': 'fr-FR', 'texte': 'À retenir.'},
        ],
      });
      expect(lecon.scriptRetenir, const [SegmentAudio(lang: 'fr-FR', texte: 'À retenir.')]);
      expect(lecon.scriptAudio, isEmpty);
    });

    test('script gardé dans la copie hors connexion', () {
      final script = [
        {'lang': 'fr-FR', 'texte': 'Leçon : le présent simple.'},
        {'lang': 'en-GB', 'texte': 'The present simple.'},
      ];
      final contenu = Instantane(
        classesBrutes: const [],
        matieresBrutes: const [],
        chapitresBruts: const [],
        leconsBrutes: [
          {...ligne, 'script_audio': script},
        ],
      );
      // Aller-retour par le format enregistré sur le téléphone.
      final relu = Instantane.fromJson(jsonDecode(jsonEncode(contenu.toJson())) as Map<String, dynamic>);
      expect(relu.lecon((ligne['id'] as num).toInt())!.scriptAudio, const [
        SegmentAudio(lang: 'fr-FR', texte: 'Leçon : le présent simple.'),
        SegmentAudio(lang: 'en-GB', texte: 'The present simple.'),
      ]);
    });
  });
}
