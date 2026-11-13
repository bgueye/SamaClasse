import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';
import 'package:samaclasse/features/accueil/accueil_screen.dart' show detailMatiere;
import 'package:samaclasse/features/exercices/outils_exercices.dart';
import 'package:samaclasse/features/matiere/regroupement.dart';

Exercice exo(String type, Object? reponse) => Exercice.fromJson({
      'id': 1,
      'ordre': 1,
      'niveau': 'je_connais',
      'type': type,
      'enonce': 'Énoncé',
      'donnees': null,
      'reponse': reponse,
      'corrige': null,
    });

Chapitre chap(int numero, String? partie, {int lecons = 0}) => Chapitre.fromJson({
      'id': numero,
      'numero': numero,
      'titre': 'Chapitre $numero',
      'partie': partie,
      'statut': 'officiel',
      'remarque': null,
      'lecons': [
        for (var i = 0; i < lecons; i++)
          {
            'id': numero * 10 + i,
            'numero': i + 1,
            'titre': 'Leçon',
            'exercices': [
              {'count': 3},
            ],
          },
      ],
    });

void main() {
  group('reponseInitiale', () {
    test('QCM : un null par question', () {
      expect(reponseInitiale(exo('qcm', [2, 1, 2])), [null, null, null]);
    });

    test('tableau de classement : une liste vide par catégorie', () {
      expect(
        reponseInitiale(exo('tableau', {'homogene': ['air'], 'heterogene': ['eau + sable']})),
        {'homogene': <String>[], 'heterogene': <String>[]},
      );
    });

    test('exercice libre : texte vide', () {
      expect(reponseInitiale(exo('redaction', null)), '');
    });
  });

  test('libellés des champs de calcul', () {
    expect(libelleChemin('totaux.0'), 'Totaux n° 1');
    expect(libelleChemin('aire_minimale_m2'), 'Aire minimale m2');
    expect(libelleChemin('476'), '476');
  });

  test('formaterValeur écrit les décimaux à la française', () {
    expect(formaterValeur(8.5), '8,5');
    expect(formaterValeur(8.0), '8');
    expect(formaterValeur(3775), '3775');
    expect(formaterValeur('Ve siècle'), 'Ve siècle');
  });

  test('elementsAClasser trie sans tenir compte des accents', () {
    expect(
      elementsAClasser({'a': ['eau sucrée', 'air'], 'b': ['Écorce']}),
      ['air', 'eau sucrée', 'Écorce'],
    );
    expect(categorieAttendue({'a': ['eau sucrée']}, 'eau sucree'), 'a');
  });

  group('regroupement des chapitres', () {
    test('parties consécutives', () {
      final parties = regrouperParPartie([chap(1, 'A'), chap(2, 'A'), chap(3, 'B'), chap(4, null)]);
      expect(parties.map((p) => p.titre), ['A', 'B', null]);
      expect(parties.first.chapitres.length, 2);
    });

    test('état d’un chapitre', () {
      expect(etatChapitre(chap(1, null)), 'Leçon pas encore disponible');
      expect(etatChapitre(chap(1, null, lecons: 1)), 'Leçon prête, 3 exercices');
      expect(etatChapitre(chap(1, null, lecons: 2)), '2 leçons prêtes, 6 exercices');
    });
  });

  group('sous-titre d’une matière', () {
    MatiereDeClasse matiere(int chapitres, int lecons) => MatiereDeClasse.fromJson({
          'classe_id': 1,
          'matiere_id': 1,
          'slug': 'histoire',
          'nom': 'Histoire',
          'nb_chapitres': chapitres,
          'nb_lecons': lecons,
        });

    test('sans leçon, accord du nombre de chapitres', () {
      expect(detailMatiere(matiere(14, 0)), 'Pas encore de leçon, 14 chapitres au programme');
      // Éducation civique en 4ème : un seul chapitre (affichait « 1 chapitres »).
      expect(detailMatiere(matiere(1, 0)), 'Pas encore de leçon, 1 chapitre au programme');
    });

    test('avec des leçons prêtes', () {
      expect(detailMatiere(matiere(12, 1)), '1 leçon prête sur 12 chapitres');
      expect(detailMatiere(matiere(12, 3)), '3 leçons prêtes sur 12 chapitres');
      expect(detailMatiere(matiere(1, 1)), '1 leçon prête sur 1 chapitre');
    });
  });

  group('catégories d’un tableau de classement (D14)', () {
    const reponse = {
      'homogene': ['eau sucrée', 'air'],
      'heterogene': ['eau + sable'],
    };
    Exercice classement(Object? donnees) => Exercice.fromJson({
          'id': 1,
          'ordre': 1,
          'niveau': 'j_applique',
          'type': 'tableau',
          'enonce': 'Classe ces mélanges.',
          'donnees': donnees,
          'reponse': reponse,
          'corrige': null,
        });
    List<String> libelles(Object? donnees) =>
        categoriesDuClassement(classement(donnees)).map((c) => c.libelle).toList();

    test('sans donnees.categories : libellés tirés des clés, par ordre alphabétique', () {
      expect(libelles(null), ['Heterogene', 'Homogene']);
      expect(libelles({'autre': 1}), ['Heterogene', 'Homogene']);
    });

    test('avec donnees.categories : libellés accentués, triés sans tenir compte des accents', () {
      final categories = categoriesDuClassement(classement({
        'categories': {'homogene': 'Homogène', 'heterogene': 'Hétérogène'},
      }));
      expect(categories.map((c) => c.libelle), ['Hétérogène', 'Homogène']);
      // Les clés restent celles de `reponse` : la correction n'est pas touchée.
      expect(categories.map((c) => c.cle), ['heterogene', 'homogene']);
    });

    test('ordre indépendant de l’ordre des clés (la base range les objets jsonb à sa façon)', () {
      // Exercice 31 (Afrique de l'Ouest) : la base renvoie « cotiers, insulaire, continentaux ».
      final e = Exercice.fromJson({
        'id': 31,
        'ordre': 3,
        'niveau': 'j_applique',
        'type': 'tableau',
        'enonce': 'Classe ces pays.',
        'donnees': {
          'categories': {'cotiers': 'Côtiers', 'insulaire': 'Insulaire', 'continentaux': 'Continentaux'},
        },
        'reponse': {
          'cotiers': ['Sénégal'],
          'insulaire': ['Cap-Vert'],
          'continentaux': ['Mali'],
        },
        'corrige': null,
      });
      expect(categoriesDuClassement(e).map((c) => c.libelle), ['Continentaux', 'Côtiers', 'Insulaire']);
    });

    test('champ incomplet : les clés oubliées gardent le libellé tiré de la clé', () {
      expect(libelles({'categories': {'heterogene': 'Hétérogène'}}), ['Hétérogène', 'Homogene']);
    });

    test('clé inconnue de la réponse : ignorée', () {
      expect(libelles({'categories': {'gaz': 'Gaz', 'homogene': 'Homogène'}}), ['Heterogene', 'Homogène']);
    });

    test('libellé vide ou mal formé : retour au libellé tiré de la clé', () {
      expect(libelles({'categories': {'homogene': '  ', 'heterogene': 3}}), ['Heterogene', 'Homogene']);
      expect(libelles({'categories': ['Homogène', 'Hétérogène']}), ['Heterogene', 'Homogene']);
    });
  });
}
