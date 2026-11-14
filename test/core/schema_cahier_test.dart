// Schémas des leçons (décision D15) : filtre des adresses, texte de
// remplacement, lecteurs d'écran et maintien de l'alignement Seyès.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/theme/theme.dart';
import 'package:samaclasse/core/widgets/markdown_cahier.dart';
import 'package:samaclasse/core/widgets/schema_cahier.dart';

import '../outils/polices.dart';

const _projet = 'https://earcfeorkfeenqprsxpg.supabase.co';
const _schema = '$_projet/storage/v1/object/public/schemas/4eme/svt/cycle_eau.png';

Future<void> _afficher(WidgetTester tester, Widget enfant) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: enfant))),
    );

void main() {
  setUpAll(chargerPolicesReelles);

  group('estAdresseSchema', () {
    bool ok(String adresse) => estAdresseSchema(Uri.parse(adresse), _projet);

    test('accepte une image de l’espace schemas du projet', () {
      expect(ok(_schema), isTrue);
      expect(ok('$_projet/storage/v1/object/public/schemas/a.webp'), isTrue);
    });

    test('refuse les autres adresses', () {
      expect(ok('https://exemple.com/image.png'), isFalse, reason: 'site tiers');
      expect(ok('http://earcfeorkfeenqprsxpg.supabase.co/storage/v1/object/public/schemas/a.png'), isFalse,
          reason: 'pas de https');
      expect(ok('https://autreprojet.supabase.co/storage/v1/object/public/schemas/a.png'), isFalse,
          reason: 'autre projet');
      expect(ok('$_projet/storage/v1/object/public/autre/a.png'), isFalse, reason: 'autre espace');
      expect(ok('$_projet/storage/v1/object/public/schemas/'), isFalse, reason: 'pas de fichier');
      expect(ok('$_projet:8443/storage/v1/object/public/schemas/a.png'), isFalse, reason: 'autre port');
      expect(ok('schemas/a.png'), isFalse, reason: 'adresse relative');
    });

    test('refuse tout sans configuration Supabase', () {
      expect(estAdresseSchema(Uri.parse(_schema), ''), isFalse);
    });
  });

  test('texteSchemaAbsent', () {
    expect(texteSchemaAbsent('Le cycle de l’eau'), 'Schéma : Le cycle de l’eau');
    expect(texteSchemaAbsent('  '), 'Schéma non disponible.');
    expect(texteSchemaAbsent(null), 'Schéma non disponible.');
  });

  group('HauteurEnInterlignes', () {
    Future<double> hauteur(WidgetTester tester, double h) async {
      await _afficher(tester, HauteurEnInterlignes(child: SizedBox(height: h, width: 100)));
      return tester.getSize(find.byType(HauteurEnInterlignes)).height;
    }

    testWidgets('arrondit au multiple supérieur de l’interligne', (tester) async {
      expect(await hauteur(tester, 50), interligne * 2);
      expect(await hauteur(tester, 64), interligne * 2, reason: 'déjà juste : rien à ajouter');
      expect(await hauteur(tester, 64.001), interligne * 2, reason: 'erreur d’arrondi flottant');
      expect(await hauteur(tester, 65), interligne * 3);
      expect(await hauteur(tester, 0), 0);
    });

    testWidgets('le texte qui suit une image garde son pas de 32 px', (tester) async {
      await _afficher(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Avant', style: Styles.lecon),
            HauteurEnInterlignes(child: SizedBox(height: 75, width: 200)),
            Text('Après', style: Styles.lecon),
          ],
        ),
      );
      final ecart = tester.getTopLeft(find.text('Après')).dy - tester.getTopLeft(find.text('Avant')).dy;
      expect(ecart % interligne, 0);
      // L'image est centrée dans l'espace arrondi.
      final image = tester.getRect(find.byType(SizedBox).last);
      final boite = tester.getRect(find.byType(HauteurEnInterlignes));
      expect(image.top - boite.top, closeTo(boite.bottom - image.bottom, 0.01));
    });
  });

  group('SchemaCahier', () {
    testWidgets('adresse refusée : description à la place, rien n’est chargé', (tester) async {
      await _afficher(
        tester,
        const MarkdownCahier(
          data: 'Avant.\n\n![Le cycle de l’eau](https://exemple.com/cycle.png)\n\nAprès.',
          surSeyes: true,
        ),
      );
      expect(find.text('Schéma : Le cycle de l’eau'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('description de remplacement posée sur les lignes Seyès', (tester) async {
      await _afficher(
        tester,
        const MarkdownCahier(
          data: 'Avant.\n\n![Le cycle de l’eau](https://exemple.com/cycle.png)\n\nAprès.',
          surSeyes: true,
        ),
      );
      final avant = tester.getTopLeft(find.text('Avant.')).dy;
      expect((tester.getTopLeft(find.text('Schéma : Le cycle de l’eau')).dy - avant) % interligne, 0);
      expect((tester.getTopLeft(find.text('Après.')).dy - avant) % interligne, 0);
    });

    testWidgets('adresse autorisée : image chargée, description lue par les lecteurs d’écran', (tester) async {
      final semantique = tester.ensureSemantics();
      await _afficher(
        tester,
        SchemaCahier(adresse: Uri.parse(_schema), description: 'Le cycle de l’eau', urlSupabase: _projet),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.bySemanticsLabel('Le cycle de l’eau'), findsOneWidget);
      expect(find.text('Schéma : Le cycle de l’eau'), findsNothing);
      semantique.dispose();
    });
  });

  group('SchemaCahier avec une image réellement chargée', () {
    // Les tests n'ont pas de réseau : un faux client HTTP sert une image PNG
    // fabriquée sur place, à la place de Supabase.
    // Le cache d'images vidé à chaque test : sinon la même adresse
    // renverrait l'image du test précédent.
    tearDown(() {
      imageCache.clear();
      imageCache.clearLiveImages();
    });

    Future<void> chargerAvecImage(WidgetTester tester, {required int largeur, required int hauteur}) async {
      final png = await tester.runAsync(() => _png(largeur, hauteur));
      debugNetworkImageHttpClientProvider = () => _ClientImage(png!);
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _afficher(
        tester,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: MarkdownCahier(
            data: 'Avant.\n\n![Le cycle de l’eau]($_schema)\n\nAprès.',
            surSeyes: true,
            urlSupabase: _projet,
          ),
        ),
      );
      // Le téléchargement et le décodage se font hors du temps simulé.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      // Remis à zéro avant la fin du test : le cadre de test vérifie que les
      // variables de débogage du dessin sont rétablies.
      debugNetworkImageHttpClientProvider = null;
    }

    testWidgets('grande image : pleine largeur, texte suivant sur les lignes', (tester) async {
      await chargerAvecImage(tester, largeur: 1200, hauteur: 500);
      expect(find.byType(RawImage), findsOneWidget, reason: 'l’image doit être affichée');
      final image = tester.getSize(find.byType(RawImage));
      expect(image.width, closeTo(350 - 2, 0.5), reason: 'largeur du texte moins le cadre de 1 px');
      expect(image.height, closeTo(image.width * 500 / 1200, 0.5), reason: 'proportions gardées');
      final avant = tester.getTopLeft(find.text('Avant.')).dy;
      expect((tester.getTopLeft(find.text('Après.')).dy - avant) % interligne, closeTo(0, 0.01));
    });

    testWidgets('petite image : pas agrandie', (tester) async {
      await chargerAvecImage(tester, largeur: 120, hauteur: 60);
      expect(tester.getSize(find.byType(RawImage)), const Size(120, 60));
      final avant = tester.getTopLeft(find.text('Avant.')).dy;
      expect((tester.getTopLeft(find.text('Après.')).dy - avant) % interligne, closeTo(0, 0.01));
    });
  });
}

/// Image PNG unie de [largeur] × [hauteur] pixels.
Future<Uint8List> _png(int largeur, int hauteur) async {
  final enregistreur = ui.PictureRecorder();
  Canvas(enregistreur).drawRect(
    Rect.fromLTWH(0, 0, largeur.toDouble(), hauteur.toDouble()),
    Paint()..color = const Color(0xFF2140C9),
  );
  final image = await enregistreur.endRecording().toImage(largeur, hauteur);
  final octets = await image.toByteData(format: ui.ImageByteFormat.png);
  return octets!.buffer.asUint8List();
}

/// Faux client HTTP : répond à toute requête par [octets] (statut 200).
/// Seules les méthodes utilisées par NetworkImage sont écrites ; les autres
/// passent par noSuchMethod.
class _ClientImage implements HttpClient {
  _ClientImage(this.octets);
  final Uint8List octets;

  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Requete(octets);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Requete implements HttpClientRequest {
  _Requete(this.octets);
  final Uint8List octets;

  @override
  final HttpHeaders headers = _Entetes();

  @override
  Future<HttpClientResponse> close() async => _Reponse(octets);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Entetes implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reponse extends Stream<List<int>> implements HttpClientResponse {
  _Reponse(this.octets);
  final Uint8List octets;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => octets.length;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(octets)
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
