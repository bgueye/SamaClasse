// Tests de ContenuHorsLigne (décision D16) : copie locale de tout le contenu
// publié, mise à jour en arrière-plan, comportement sans réseau.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/data/data.dart';

import '../outils/faux_depot.dart';

final _lundi = DateTime(2026, 11, 13, 20);
final _mardi = DateTime(2026, 11, 14, 8);

/// Une copie enregistrée le lundi (format réel, texte JSON).
String _copieDuLundi([Instantane? contenu]) =>
    encoderCopie(CopieContenu(contenu: contenu ?? instantaneReel(), telechargeeLe: _lundi));

/// Le contenu réel avec une leçon publiée en plus (copie de la leçon 1, id 99).
Instantane _avecUneLeconDePlus() {
  final contenu = instantaneReel();
  contenu.leconsBrutes.add({...contenu.leconsBrutes.first, 'id': 99, 'titre': 'Leçon toute neuve'});
  return contenu;
}

ContenuHorsLigne _contenu(FausseSource source, FauxStockage stockage, {DateTime? maintenant}) =>
    ContenuHorsLigne(source: source, stockage: stockage, horloge: () => maintenant ?? _mardi);

void main() {
  group('seulement les leçons publiées (phase 4)', () {
    // Un rédacteur connecté peut lire les leçons « à vérifier » : elles ne
    // doivent jamais entrer dans la copie locale.
    Instantane avecUneLeconAVerifier() {
      final i = instantaneReel();
      final chapitre = Map<String, dynamic>.from(i.chapitresBruts.first);
      chapitre['lecons'] = [
        ...((chapitre['lecons'] as List?) ?? const []),
        {'id': 500, 'numero': 9, 'titre': 'Leçon à vérifier', 'statut': 'a_verifier', 'exercices': [{'count': 2}]},
      ];
      return Instantane(
        classesBrutes: i.classesBrutes,
        matieresBrutes: i.matieresBrutes,
        chapitresBruts: [chapitre, ...i.chapitresBruts.skip(1)],
        leconsBrutes: [
          ...i.leconsBrutes,
          {...i.leconsBrutes.first, 'id': 500, 'titre': 'Leçon à vérifier', 'statut': 'a_verifier'},
        ],
      );
    }

    test('les leçons non publiées sont écartées partout', () {
      final filtre = avecUneLeconAVerifier().seulementPublie();
      expect(filtre.lecon(500), isNull);
      expect(filtre.lecons().map((l) => l.id), isNot(contains(500)));
      final titres = [
        for (final c in filtre.chapitresBruts)
          for (final l in (c['lecons'] as List? ?? const [])) (l as Map)['titre'],
      ];
      expect(titres, isNot(contains('Leçon à vérifier')));
    });

    test('les leçons publiées et les anciennes copies (sans statut) restent', () {
      final reel = instantaneReel();
      final filtre = reel.seulementPublie();
      expect(filtre.lecons().map((l) => l.id), reel.lecons().map((l) => l.id));
      final sansStatut = Instantane(
        classesBrutes: reel.classesBrutes,
        matieresBrutes: reel.matieresBrutes,
        chapitresBruts: reel.chapitresBruts,
        leconsBrutes: [for (final l in reel.leconsBrutes) {...l}..remove('statut')],
      ).seulementPublie();
      // Lignes brutes : le filtre ne doit pas jeter une ligne sans statut.
      expect(sansStatut.leconsBrutes, hasLength(reel.leconsBrutes.length));
    });
  });

  group('premier lancement, sans copie', () {
    test('télécharge, affiche et enregistre la copie', () async {
      final source = FausseSource();
      final stockage = FauxStockage();
      final contenu = _contenu(source, stockage);

      final classes = await contenu.classes();
      expect(classes.map((c) => c.libelle), ['4ème', 'Seconde L']);
      expect(source.telechargements, 1);
      expect(stockage.ecritures, 1);
      expect(contenu.etat.value.horsConnexion, isFalse);
      expect(contenu.etat.value.copieDu, _mardi);
    });

    test('sans réseau : l’erreur remonte à l’écran, puis « Réessayer » fonctionne', () async {
      final source = FausseSource()..enPanne = true;
      final contenu = _contenu(source, FauxStockage());

      await expectLater(contenu.classes(), throwsA(isA<Exception>()));
      // Pas de copie à afficher : pas de bandeau non plus, c'est l'écran d'erreur.
      expect(contenu.etat.value.horsConnexion, isFalse);

      source.enPanne = false;
      expect(await contenu.classes(), hasLength(2));
    });

    test('plusieurs écrans en même temps : un seul téléchargement', () async {
      final source = FausseSource()..attente = Completer<void>();
      final contenu = _contenu(source, FauxStockage());

      final a = contenu.classes();
      final b = contenu.matieres(1);
      final c = contenu.lecon(1);
      source.attente!.complete();
      await Future.wait([a, b, c]);
      expect(source.telechargements, 1);
    });
  });

  group('avec une copie sur l’appareil', () {
    test('affichage immédiat, sans attendre le serveur', () async {
      // Le serveur ne répond jamais : la copie doit suffire.
      final source = FausseSource()..attente = Completer<void>();
      final contenu = _contenu(source, FauxStockage(_copieDuLundi()));

      final lecon = await contenu.lecon(1);
      expect(lecon?.titre, 'Introduction aux sciences physiques');
      expect(contenu.etat.value.copieDu, _lundi);
      // La mise à jour est bien partie en arrière-plan.
      expect(source.telechargements, 1);
    });

    test('sans réseau : la copie reste, le bandeau « hors connexion » s’affiche', () async {
      final source = FausseSource()..enPanne = true;
      final contenu = _contenu(source, FauxStockage(_copieDuLundi()));

      expect(await contenu.classes(), hasLength(2));
      await pumpEventQueue(); // laisse finir la synchronisation en arrière-plan
      expect(contenu.etat.value.horsConnexion, isTrue);
      expect(contenu.etat.value.copieDu, _lundi);
    });

    test('contenu nouveau sur le serveur : version + 1 et copie remplacée', () async {
      final source = FausseSource(_avecUneLeconDePlus());
      final stockage = FauxStockage(_copieDuLundi());
      final contenu = _contenu(source, stockage);

      expect(await contenu.lecon(99), isNull); // la copie du lundi ne l'a pas
      await pumpEventQueue();
      expect(contenu.etat.value.version, 1);
      expect(contenu.etat.value.copieDu, _mardi);
      expect((await contenu.lecon(99))?.titre, 'Leçon toute neuve');
      // Enregistrée : un prochain lancement hors connexion l'aura.
      expect((await stockage.lire())?.contenu.lecon(99), isNotNull);
    });

    test('contenu identique : pas de version nouvelle (pas de rechargement inutile)', () async {
      final contenu = _contenu(FausseSource(), FauxStockage(_copieDuLundi()));
      await contenu.classes();
      await pumpEventQueue();
      expect(contenu.etat.value.version, 0);
      expect(contenu.etat.value.copieDu, _mardi);
      expect(contenu.etat.value.horsConnexion, isFalse);
    });

    test('retour du réseau : « actualiser » efface le bandeau', () async {
      final source = FausseSource()..enPanne = true;
      final contenu = _contenu(source, FauxStockage(_copieDuLundi()));
      await contenu.classes();
      await pumpEventQueue();
      expect(contenu.etat.value.horsConnexion, isTrue);

      source.enPanne = false;
      await contenu.actualiser();
      expect(contenu.etat.value.horsConnexion, isFalse);
    });

    test('« actualiser » sans réseau ne lève pas d’erreur', () async {
      final source = FausseSource()..enPanne = true;
      final contenu = _contenu(source, FauxStockage(_copieDuLundi()));
      await contenu.actualiser();
      expect(contenu.etat.value.horsConnexion, isTrue);
    });
  });

  test('copie illisible (format ancien ou abîmé) : ignorée, retéléchargée', () async {
    final source = FausseSource();
    final contenu = _contenu(source, FauxStockage('{"ceci": "n’est pas une copie"'));
    expect(await contenu.classes(), hasLength(2));
    expect(source.telechargements, 1);
  });

  group('lecture de la copie, comme les anciennes requêtes', () {
    final instantane = instantaneReel();

    test('matières d’une classe seulement, triées par nom', () {
      final noms = instantane.matieres(1).map((m) => m.nom).toList();
      expect(noms, contains('Sciences physiques'));
      expect(noms, isNot(contains('Économie'))); // matière de Seconde L
      // L'ordre est celui du serveur (collation française : « Éducation
      // civique » avant « Espagnol »), qu'un tri Dart ne reproduirait pas.
      final ordreServeur = [
        for (final m in ((donneesReelles['matieres'] as Map)['1'] as List)) (m as Map)['nom'],
      ];
      expect(noms, ordreServeur);
    });

    test('chapitres d’une matière, dans l’ordre du programme, avec le nombre d’exercices', () {
      final chapitres = instantane.chapitres(classeId: 1, matiereId: 2);
      expect(chapitres, hasLength(12));
      expect(chapitres.map((c) => c.numero), List.generate(12, (i) => i + 1));
      expect(chapitres.first.lecons.single.nbExercices, 5);
    });

    test('leçon absente ou non publiée : null', () {
      expect(instantane.lecon(1)?.exercices, hasLength(5));
      expect(instantane.lecon(12345), isNull);
    });

    test('aller-retour par le format enregistré', () {
      final relu = decoderCopie(encoderCopie(CopieContenu(contenu: instantane, telechargeeLe: _lundi)));
      expect(relu.telechargeeLe, _lundi);
      expect(relu.contenu.chapitres(classeId: 1, matiereId: 2), hasLength(12));
      expect(relu.contenu.lecon(1)?.titre, instantane.lecon(1)?.titre);
    });
  });
}
