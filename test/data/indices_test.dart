// Brouillons des indices d'exercices (contenu/indices/, D39) : chaque
// fichier doit pouvoir aller tel quel dans `exercices.indice` et s'afficher
// proprement dans l'encadré « Indice ».
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guillemet ouvrant non suivi d'une espace insécable (normale ou fine), ou
/// fermant non précédé d'une : « » » finirait seul en début de ligne.
final _guillemetSansInsecable = RegExp('«(?![  ])|(?<![  ])»');

/// « °C » collé ou précédé d'une espace ordinaire.
final _degreSansInsecable = RegExp('(?<![  ])°C');

void main() {
  final dossier = Directory('contenu/indices');
  final fichiers = dossier.existsSync()
      ? (dossier.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  test('au moins un brouillon', () => expect(fichiers, isNotEmpty));

  // Un exercice n'appartient qu'à une leçon : un identifiant ne doit pas
  // apparaître dans deux fichiers.
  test('aucun exercice dans deux fichiers', () {
    final vus = <String, String>{};
    for (final f in fichiers) {
      final nom = f.uri.pathSegments.last;
      for (final id in (jsonDecode(f.readAsStringSync()) as Map).keys) {
        expect(vus[id], isNull, reason: 'exercice $id dans $nom et ${vus[id]}');
        vus[id as String] = nom;
      }
    }
  });

  for (final fichier in fichiers) {
    final nom = fichier.uri.pathSegments.last;
    group(nom, () {
      final brut = jsonDecode(fichier.readAsStringSync());

      test('nom de fichier lecon_<id>.json', () {
        expect(RegExp(r'^lecon_\d+\.json$').hasMatch(nom), isTrue);
      });

      test('objet « id de l’exercice » → indice', () {
        expect(brut, isA<Map>());
        for (final MapEntry(:key, :value) in (brut as Map).entries) {
          expect(RegExp(r'^\d+$').hasMatch(key as String), isTrue, reason: 'clé $key');
          expect(value, isA<String>(), reason: 'exercice $key');
        }
      });

      test('longueur, guillemets, pas de « Indice : »', () {
        for (final MapEntry(:key, :value) in (brut as Map).entries) {
          final texte = value as String;
          final longueur = texte.trim().runes.length;
          expect(longueur, inInclusiveRange(3, 500), reason: 'exercice $key : $longueur caractères');
          expect(RegExp(r'^\s*\**Indice', caseSensitive: false).hasMatch(texte), isFalse,
              reason: 'pas de « Indice : » au début, exercice $key');
          expect(_guillemetSansInsecable.hasMatch(texte), isFalse, reason: 'guillemet sans espace insécable, exercice $key : $texte');
          expect(_degreSansInsecable.hasMatch(texte), isFalse, reason: '°C sans espace insécable, exercice $key');
          expect(texte, isNot(contains('\n')), reason: 'exercice $key : une seule ligne');
          expect(texte, isNot(contains('  ')), reason: 'double espace, exercice $key');
        }
      });
    });
  }
}
