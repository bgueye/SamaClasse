// Tests de lecture des lignes Supabase, avec la forme réelle des réponses.
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';

void main() {
  test('Chapitre avec ses leçons publiées et leur nombre d’exercices', () {
    final c = Chapitre.fromJson({
      'id': 64,
      'numero': 1,
      'titre': "L'Afrique au XVIe siècle",
      'partie': 'Le monde au XVIe siècle',
      'statut': 'a_valider',
      'remarque': null,
      'lecons': [
        {
          'id': 4,
          'numero': 1,
          'titre': "L'Afrique au XVIe siècle",
          'exercices': [
            {'count': 6},
          ],
        },
      ],
    });
    expect(c.statut, StatutProgramme.aValider);
    expect(c.aUneLecon, isTrue);
    expect(c.lecons.single.id, 4);
    expect(c.lecons.single.nbExercices, 6);
  });

  test('Leçon résumée sans comptage', () {
    final l = LeconResume.fromJson({'id': 1, 'numero': null, 'titre': 'Titre'});
    expect(l.numero, 1);
    expect(l.nbExercices, isNull);
  });

  test('Matière de la vue matieres_par_classe', () {
    final m = MatiereDeClasse.fromJson({
      'classe_id': 1,
      'matiere_id': 5,
      'slug': 'histoire',
      'nom': 'Histoire',
      'nb_chapitres': 21,
      'nb_lecons': 0,
    });
    expect(m.nbChapitres, 21);
  });

  test('Leçon complète : exercices triés, à retenir, contexte', () {
    final l = Lecon.fromJson({
      'id': 10,
      'chapitre_id': 166,
      'numero': 1,
      'titre': "La structure d'un écosystème",
      'date_cours': null,
      'objectifs': ['Définir un écosystème, son biotope et sa biocénose'],
      'introduction': 'On appelle **écosystème**…',
      'corps': '## I. L’étude du peuplement d’un milieu',
      'a_retenir': [
        {'notion': 'Écosystème', 'essentiel': 'Ensemble formé par le biotope et la biocénose'},
      ],
      'points_a_verifier': ['La partie sur le peuplement animal reste à rédiger à partir du cahier.'],
      'statut': 'a_verifier',
      'exercices': [
        {'id': 31, 'ordre': 2, 'niveau': 'j_applique', 'type': 'qcm', 'enonce': 'Entoure la bonne réponse.', 'donnees': {'questions': []}, 'reponse': [2, 1, 2, 1], 'corrige': '1. c'},
        {'id': 30, 'ordre': 1, 'niveau': 'je_connais', 'type': 'question_cours', 'enonce': 'Définis…', 'donnees': null, 'reponse': null, 'corrige': 'Écosystème…'},
      ],
      'chapitres': {
        'titre': "Structure d'un écosystème",
        'partie': "Notions fondamentales d'écologie",
        'classes': {'libelle': 'Seconde L'},
        'matieres': {'nom': 'SVT', 'slug': 'svt'},
      },
    });
    expect(l.statut, StatutLecon.aVerifier);
    expect(l.exercices.map((e) => e.ordre), [1, 2]);
    expect(l.exercices.last.type, TypeExercice.qcm);
    expect(l.aRetenir.single.notion, 'Écosystème');
    expect(l.contexte?.classe, 'Seconde L');
    expect(l.contexte?.matiereSlug, 'svt');
    expect(l.dateCours, isNull);
  });

  test('Valeur inconnue : FormatException explicite', () {
    expect(() => TypeExercice.fromDb('dictee'), throwsFormatException);
  });
}
