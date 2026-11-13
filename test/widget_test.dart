// Tests d'interface sans réseau : composants de base et zones de réponse.
// (Ce fichier remplace aussi celui que `flutter create` génère par défaut.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/theme/theme.dart';
import 'package:samaclasse/core/widgets/etats.dart';
import 'package:samaclasse/core/widgets/page_seyes.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/exercices/saisies/saisie_exercice.dart';

Widget _app(Widget enfant) => MaterialApp(theme: themeSamaClasse(), home: Scaffold(body: enfant));

void main() {
  testWidgets('MessageErreur propose de réessayer', (tester) async {
    var essais = 0;
    await tester.pumpWidget(_app(MessageErreur(erreur: 'hors ligne', onReessayer: () => essais++)));
    await tester.tap(find.text('Réessayer'));
    expect(essais, 1);
  });

  testWidgets('PageSeyes affiche son contenu', (tester) async {
    await tester.pumpWidget(_app(const PageSeyes(child: Text('Introduction'))));
    expect(find.text('Introduction'), findsOneWidget);
  });

  testWidgets('QCM : toucher un choix renvoie l’indice choisi', (tester) async {
    final qcm = Exercice.fromJson({
      'id': 13,
      'ordre': 1,
      'niveau': 'je_connais',
      'type': 'qcm',
      'enonce': 'Entoure la bonne réponse.',
      'donnees': {
        'questions': [
          {'q': 'Le baobab appartient à la strate :', 'choix': ['herbacée', 'arbustive', 'arborescente']},
        ],
      },
      'reponse': [2],
      'corrige': null,
    });
    Object? recu;
    await tester.pumpWidget(_app(SingleChildScrollView(
      child: SaisieExercice(exercice: qcm, reponse: const [null], correction: null, onChanged: (v) => recu = v),
    )));
    await tester.tap(find.text('arborescente'));
    expect(recu, [2]);
  });

  testWidgets('Vrai ou faux corrigé : la bonne réponse est signalée', (tester) async {
    final vf = Exercice.fromJson({
      'id': 23,
      'ordre': 1,
      'niveau': 'je_connais',
      'type': 'vrai_faux',
      'enonce': 'Vrai ou faux ?',
      'donnees': {
        'affirmations': ['Un liquide est compressible.'],
      },
      'reponse': [false],
      'corrige': null,
    });
    await tester.pumpWidget(_app(SingleChildScrollView(
      child: SaisieExercice(
        exercice: vf,
        reponse: const [true],
        correction: const CorrectionAuto([false]),
        onChanged: (_) {},
      ),
    )));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });
}
