// Brouillons des scripts oraux de « À retenir » (contenu/scripts_retenir/,
// D37) : chaque fichier doit pouvoir aller tel quel dans
// `lecons.script_retenir` et se lire correctement à voix haute.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';

/// Langues prévues par le lecteur (D34) ; une autre serait sautée.
const _langues = {'fr-FR', 'en-GB', 'es-ES'};

/// Lettres seules que la voix française lit mal : « m » devient « monsieur »
/// (abréviation « M. ») ; à écrire « èmme ». Relevé à l'écoute le 20/11/2026.
final _lettresMalLues = RegExp(r"(?<![\p{L}\p{N}’'])[mM](?![\p{L}\p{N}’'])", unicode: true);

/// Caractères mal lus par la synthèse vocale : à dire en mots.
final _symboles = RegExp(r'[×÷→←↔≤≥≠≈±√∞/\\+=<>|*_#`²³⁰¹⁴-⁹⁻ⁿᵖᵐ\[\]{}]');

void main() {
  final dossier = Directory('contenu/scripts_retenir');
  final fichiers = dossier.existsSync()
      ? (dossier.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  test('au moins un brouillon', () => expect(fichiers, isNotEmpty));

  for (final fichier in fichiers) {
    final nom = fichier.uri.pathSegments.last;
    group(nom, () {
      final brut = jsonDecode(fichier.readAsStringSync());

      test('nom de fichier lecon_<id>.json', () {
        expect(RegExp(r'^lecon_\d+\.json$').hasMatch(nom), isTrue);
      });

      test('liste de passages complets, rien de perdu à la lecture', () {
        expect(brut, isA<List>());
        final passages = SegmentAudio.listeDepuis(brut);
        // listeDepuis ignore les éléments mal formés : il ne doit rien ignorer.
        expect(passages.length, (brut as List).length);
        for (final p in brut) {
          expect((p as Map).keys.toSet(), {'lang', 'texte'}, reason: '$p');
        }
      });

      test('langues prévues, aucun symbole ni Markdown', () {
        for (final p in SegmentAudio.listeDepuis(brut)) {
          expect(_langues, contains(p.lang), reason: p.texte);
          expect(_symboles.hasMatch(p.texte), isFalse, reason: 'symbole dans : ${p.texte}');
          expect(p.texte, isNot(contains('  ')), reason: 'double espace dans : ${p.texte}');
          if (p.lang == 'fr-FR') {
            expect(_lettresMalLues.hasMatch(p.texte), isFalse, reason: 'lettre « m » seule dans : ${p.texte}');
          }
        }
      });

      test('ouverture « … À retenir : … » et fin « Fin du résumé »', () {
        final passages = SegmentAudio.listeDepuis(brut);
        expect(passages.first.lang, 'fr-FR');
        expect(passages.first.texte, contains('À retenir :'));
        expect(passages.last.texte, startsWith('Fin du résumé.'));
      });
    });
  }
}
