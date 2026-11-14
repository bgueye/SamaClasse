// Icône de SamaClasse (décision D19) : variante A « Couverture » choisie par
// Bocar le 13/11/2026 (protège-cahier bleu encre, lignes Seyès, marge rouge,
// monogramme « Sc » en Playwrite FR Moderne).
//
// Lancer :
//   flutter test tool/icone/icone_test.dart
// Produit, dans assets/icone/ (images sources, gardées dans le dépôt) :
//   icone.png         icône complète 1024 px (iOS, web, anciens Android)
//   icone_fond.png    couche de fond de l'icône adaptative Android
//   icone_lettres.png couche de devant (« Sc » blanc sur transparent)
// puis build/icone/planche.png (aperçu aux tailles réelles).
// Ensuite : dart run flutter_launcher_icons && dart run flutter_native_splash:create
//
// Icône adaptative Android : chaque couche fait 108 dp, dont seuls les 72 dp
// du centre sont visibles (découpe en cercle ou en carré arrondi selon le
// téléphone). Le dessin est donc fait dans la zone visible (les 2/3 du
// centre) ; lignes et marge débordent jusqu'aux bords pour ne jamais laisser
// de trou après la découpe.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/theme/couleurs.dart';
import 'package:samaclasse/core/theme/theme.dart';

import '../../test/outils/polices.dart';

enum Couche { complete, fond, lettres }

/// Zone visible d'une couche d'icône adaptative (72 dp sur 108 dp).
const zoneAdaptative = 72 / 108;

/// L'icône dans un carré de [taille] px. Le dessin occupe la [zoneVisible]
/// du centre (1 pour l'icône complète). Mesures en fractions de la zone
/// visible : rendu identique de 48 à 1024 px.
class IconeSamaClasse extends StatelessWidget {
  const IconeSamaClasse({super.key, required this.taille, this.couche = Couche.complete, this.zoneVisible = 1});

  final double taille;
  final Couche couche;
  final double zoneVisible;

  @override
  Widget build(BuildContext context) {
    final visible = taille * zoneVisible;
    final lettres = Container(
      // Un peu à droite de la marge rouge, comme une lettre écrite sur la page.
      // Et un peu plus bas : la boîte du texte réserve la place des jambages
      // (g, p) que « Sc » n'a pas ; sans ce décalage, les lettres paraissent
      // trop hautes (centre mesuré à 40 % de la hauteur au lieu de 50 %).
      padding: EdgeInsets.only(left: visible * 0.12),
      transform: Matrix4.translationValues(0, visible * 0.145, 0),
      child: Text(
        // « Sc » : monogramme de SamaClasse. Le S seul de Playwrite, presque
        // droit, ne se lit pas comme une écriture de cahier ; avec le c, si.
        'Sc',
        style: TextStyle(fontFamily: policeCahier, fontSize: visible * 0.44, height: 1, color: Couleurs.papier),
      ),
    );
    return SizedBox.square(
      dimension: taille,
      child: switch (couche) {
        Couche.lettres => Center(child: lettres),
        Couche.fond => _fond(visible),
        Couche.complete => Stack(fit: StackFit.expand, children: [_fond(visible), Center(child: lettres)]),
      },
    );
  }

  Widget _fond(double visible) => ColoredBox(
        color: Couleurs.encre,
        child: CustomPaint(painter: _LignesEtMarge(visible: visible)),
      );
}

class _LignesEtMarge extends CustomPainter {
  const _LignesEtMarge({required this.visible});

  /// Côté de la zone visible, centrée dans le carré.
  final double visible;

  @override
  void paint(Canvas canvas, Size size) {
    final t = size.width;
    final origine = (t - visible) / 2;

    // Lignes Seyès (fortes seulement : les fines disparaîtraient en petit),
    // prolongées au-delà de la zone visible dans les deux sens.
    final ligne = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = visible * 0.012;
    final pas = visible * 0.16;
    var y = origine + visible * 0.2;
    while (y - pas > 0) {
      y -= pas;
    }
    for (; y < t; y += pas) {
      canvas.drawLine(Offset(0, y), Offset(t, y), ligne);
    }

    // Marge rouge, sur toute la hauteur.
    final x = origine + visible * 0.27;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, t),
      Paint()
        ..color = Couleurs.marge
        ..strokeWidth = visible * 0.03,
    );
  }

  @override
  bool shouldRepaint(_LignesEtMarge ancien) => ancien.visible != visible;
}

/// Rend [enfant] (exactement 1024 × 1024) et l'enregistre en PNG.
Future<void> _enregistrer(WidgetTester tester, Widget enfant, String chemin) async {
  final cle = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: cle, child: enfant)),
  ));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final limite = cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await limite.toImage();
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    File(chemin)
      ..createSync(recursive: true)
      ..writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(chargerPolicesReelles);

  testWidgets('images sources de l’icône', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _enregistrer(tester, const IconeSamaClasse(taille: 1024), 'assets/icone/icone.png');
    await _enregistrer(
      tester,
      const IconeSamaClasse(taille: 1024, couche: Couche.fond, zoneVisible: zoneAdaptative),
      'assets/icone/icone_fond.png',
    );
    await _enregistrer(
      tester,
      const IconeSamaClasse(taille: 1024, couche: Couche.lettres, zoneVisible: zoneAdaptative),
      'assets/icone/icone_lettres.png',
    );
  });

  testWidgets('aperçu aux tailles réelles', (tester) async {
    tester.view.physicalSize = const Size(760, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Icône adaptative recomposée (fond + lettres), découpée comme sur Android.
    Widget adaptative(double taille, {bool rond = true}) {
      final couches = Stack(children: [
        IconeSamaClasse(taille: taille / zoneAdaptative, couche: Couche.fond, zoneVisible: zoneAdaptative),
        IconeSamaClasse(taille: taille / zoneAdaptative, couche: Couche.lettres, zoneVisible: zoneAdaptative),
      ]);
      final recadree = SizedBox.square(
        dimension: taille,
        child: ClipRect(child: OverflowBox(maxWidth: double.infinity, maxHeight: double.infinity, child: couches)),
      );
      return rond
          ? ClipOval(child: recadree)
          : ClipRRect(borderRadius: BorderRadius.circular(taille * 0.25), child: recadree);
    }

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeSamaClasse(),
      home: Scaffold(
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(40), child: const IconeSamaClasse(taille: 200)),
              adaptative(160),
              adaptative(96),
              adaptative(48),
              adaptative(48, rond: false),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await captureImage(find.byType(Scaffold).evaluate().single);
      final octets = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/icone/planche.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(octets!.buffer.asUint8List());
    });
  });
}
