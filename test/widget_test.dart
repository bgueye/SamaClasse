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

  group('tableau de classement avec donnees.categories (D14)', () {
    final classement = Exercice.fromJson({
      'id': 33,
      'ordre': 3,
      'niveau': 'j_applique',
      'type': 'tableau',
      'enonce': 'Classe ces mélanges.',
      'donnees': {
        'categories': {'homogene': 'Homogène', 'heterogene': 'Hétérogène'},
      },
      'reponse': {
        'homogene': ['eau sucrée'],
        'heterogene': ['eau + sable'],
      },
      'corrige': null,
    });

    testWidgets('les puces affichent les libellés accentués et renvoient la clé', (tester) async {
      Object? recu;
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: SaisieExercice(
          exercice: classement,
          reponse: const {'homogene': <String>[], 'heterogene': <String>[]},
          correction: null,
          onChanged: (v) => recu = v,
        ),
      )));
      expect(find.text('Homogène'), findsNWidgets(2)); // une puce par élément à classer
      expect(find.text('Homogene'), findsNothing);

      await tester.tap(find.text('Hétérogène').first); // premier élément : « eau + sable »
      expect((recu as Map)['heterogene'], ['eau + sable']);
    });

    testWidgets('corrigé : « Attendu » utilise aussi le libellé accentué', (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: SaisieExercice(
          exercice: classement,
          // Les deux éléments placés à l'envers.
          reponse: const {
            'homogene': ['eau + sable'],
            'heterogene': ['eau sucrée'],
          },
          correction: const CorrectionAuto([false, false]),
          onChanged: (_) {},
        ),
      )));
      expect(find.text('Attendu : Homogène'), findsOneWidget);
      expect(find.text('Attendu : Hétérogène'), findsOneWidget);
    });
  });
}
