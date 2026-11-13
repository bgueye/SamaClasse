// Tests de la correction automatique, sur de vrais exercices de la base.
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';

Exercice exo(String type, Object? reponse, {Object? donnees, String? corrige}) => Exercice.fromJson({
      'id': 1,
      'ordre': 1,
      'niveau': 'j_applique',
      'type': type,
      'enonce': 'Énoncé',
      'donnees': donnees,
      'reponse': reponse,
      'corrige': corrige,
    });

void main() {
  group('QCM (digestion, exercice 6)', () {
    final qcm = exo('qcm', [1, 2, 1, 0, 1]);

    test('tout juste', () {
      final c = corriger(qcm, [1, 2, 1, 0, 1]) as CorrectionAuto;
      expect(c.toutJuste, isTrue);
      expect(c.bonnes, 5);
    });

    test('une erreur et une question sans réponse', () {
      final c = corriger(qcm, [1, 0, 1, null, 1]) as CorrectionAuto;
      expect(c.details, [true, false, true, false, true]);
      expect(c.bonnes, 3);
    });

    test('nombre de réponses incorrect', () {
      expect(corriger(qcm, [1, 2]), isA<ReponseInvalide>());
    });
  });

  test('vrai ou faux (digestion, exercice 2)', () {
    final vf = exo('vrai_faux', [false, true, false, false, true, false, true]);
    final c = corriger(vf, [false, true, true, false, true, false, true]) as CorrectionAuto;
    expect(c.details[2], isFalse);
    expect(c.bonnes, 6);
  });

  test('relier (digestion, exercice 4), dans l’ordre de la colonne de gauche', () {
    final relier = exo(
      'relier',
      {
        "L'estomac": 'Brasse les aliments avec le suc gastrique',
        'Les dents': 'Assurent la mastication',
        "L'œsophage": "Transporte les aliments vers l'estomac",
      },
      donnees: {
        'gauche': ['Les dents', "L'œsophage", "L'estomac"],
        'droite': ['…'],
      },
    );
    final c = corriger(relier, {
      'Les dents': 'assurent la mastication',
      "L'œsophage": 'Brasse les aliments avec le suc gastrique',
      "L'estomac": 'Brasse les aliments avec le suc gastrique',
    }) as CorrectionAuto;
    expect(c.details, [true, false, true]);
  });

  test('tableau ordonné (sciences physiques 4e, exercice 2)', () {
    final t = exo('tableau', ['solidification', 'fusion', 'vaporisation', 'liquéfaction', 'sublimation', 'condensation']);
    final c = corriger(t, ['Solidification', 'fusion', 'vaporisation', 'liquefaction', 'condensation', 'sublimation.'])
        as CorrectionAuto;
    expect(c.details, [true, true, true, true, false, false]);
  });

  test('tableau de classement (mélanges et corps purs, exercice 3)', () {
    final t = exo('tableau', {
      'homogene': ['eau sucrée', 'air', 'eau minérale', 'eau + alcool'],
      'heterogene': ['eau + sable', 'eau + huile'],
    });
    final c = corriger(t, {
      'homogene': ['eau sucree', 'air', 'eau + huile'],
      'heterogene': ['eau + sable'],
    }) as CorrectionAuto;
    expect(c.total, 6);
    expect(c.bonnes, 3);
  });

  test('tableau imbriqué (versification) : correction manuelle', () {
    final t = exo('tableau', {
      'disposition': 'croisées (ABAB)',
      'perché / alléché': {'genre': 'masculine', 'qualite': 'suffisante'},
    }, corrige: 'Rimes croisées');
    expect(estAutoCorrigeable(t), isFalse);
    expect(corriger(t, ''), isA<CorrectionManuelle>());
  });

  test('tableau sans réponse attendue : correction manuelle', () {
    expect(corriger(exo('tableau', null, corrige: 'Voir le tableau'), const {}), isA<CorrectionManuelle>());
  });

  group('calcul', () {
    final aire = exo('calcul', {'totaux': [5, 7, 9, 10, 10, 10], 'aire_minimale_m2': 8});

    test('chemins attendus', () {
      expect(cheminsAttendus(aire), ['totaux.0', 'totaux.1', 'totaux.2', 'totaux.3', 'totaux.4', 'totaux.5', 'aire_minimale_m2']);
    });

    test('nombres saisis en texte, virgule décimale acceptée', () {
      final c = corriger(aire, {
        'totaux.0': '5', 'totaux.1': 7, 'totaux.2': 9, 'totaux.3': 10, 'totaux.4': 10, 'totaux.5': 10,
        'aire_minimale_m2': '8,0',
      }) as CorrectionAuto;
      expect(c.toutJuste, isTrue);
    });

    test('réponse mixte texte et nombre (histoire 2nde L, exercice 4)', () {
      final siecles = exo('calcul', {'476': 'Ve siècle', 'duree_annees': 3775});
      final c = corriger(siecles, {'476': 'Ve siecle', 'duree_annees': '3 776'}) as CorrectionAuto;
      expect(c.details, [true, false]);
    });
  });

  test('question de cours : correction manuelle avec le corrigé', () {
    final q = exo('question_cours', null, corrige: 'La nation est…');
    final c = corriger(q, 'ma réponse') as CorrectionManuelle;
    expect(c.corrige, 'La nation est…');
  });

  test('normaliser ignore casse, accents, apostrophes et ponctuation finale', () {
    expect(memeTexte('L’Œsophage.', "l'oesophage"), isTrue);
    expect(memeTexte('  Glandes   salivaires ', 'glandes salivaires'), isTrue);
    expect(memeTexte('fusion', 'diffusion'), isFalse);
  });

  test('lireNombre accepte virgule et espaces', () {
    expect(lireNombre('1 000,5'), 1000.5);
    expect(lireNombre('-3'), -3);
    expect(lireNombre('abc'), isNull);
  });
}
