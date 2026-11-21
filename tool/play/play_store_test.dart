// Éléments graphiques de la fiche Google Play (docs/PLAY_STORE.md).
//
// Lancer :
//   flutter test tool/play/play_store_test.dart
// Produit, dans build/play/ (ignoré par git, à envoyer dans la Play Console) :
//   icone_512.png          icône de la fiche : 512 × 512, carré plein (Google
//                          arrondit lui-même les coins), même dessin que
//                          l'icône de l'application (D19)
//   presentation_1024x500.png  image de présentation (« feature graphic »)
//
// Image de présentation : le protège-cahier bleu de l'icône (lignes Seyès,
// marge rouge), le nom en écriture de cahier, une phrase d'accroche, et une
// page de cahier « À retenir » inclinée à droite. Google peut recadrer les
// bords ou poser un bouton de lecture au centre (vidéo) : le texte important
// reste dans la moitié gauche, loin des bords.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samaclasse/core/theme/couleurs.dart';
import 'package:samaclasse/core/theme/theme.dart';

import '../../test/outils/polices.dart';
import '../icone/icone_test.dart' as icone;

/// Rend [enfant] à sa taille exacte (densité 1) et l'enregistre en PNG, en
/// vérifiant le format attendu par Google.
Future<void> _enregistrer(WidgetTester tester, Widget enfant, String chemin, {required Size taille}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cle = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: cle, child: enfant)),
  ));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final limite = cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await limite.toImage();
    expect((image.width, image.height), (taille.width.toInt(), taille.height.toInt()));
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    File(chemin)
      ..createSync(recursive: true)
      ..writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

/// Fond « protège-cahier » : bleu encre, lignes Seyès claires, marge rouge.
class _Couverture extends CustomPainter {
  const _Couverture();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Couleurs.encre);
    final ligne = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 3;
    for (var y = 46.0; y < size.height; y += 64) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ligne);
    }
    canvas.drawLine(
      const Offset(92, 0),
      Offset(92, size.height),
      Paint()
        ..color = Couleurs.marge
        ..strokeWidth = 7,
    );
  }

  @override
  bool shouldRepaint(_Couverture ancien) => false;
}

/// Page de cahier blanche : lignes Seyès bleu pâle, marge rouge, « À retenir »
/// en écriture de cahier et trois notions (texte réel de la leçon 1).
class _PageCahier extends StatelessWidget {
  const _PageCahier();

  @override
  Widget build(BuildContext context) {
    const notion = TextStyle(fontFamily: policeTexte, fontSize: 21, fontWeight: FontWeight.w700, color: Couleurs.encre);
    const texte = TextStyle(fontFamily: policeTexte, fontSize: 19, height: 1.35, color: Couleurs.texte);
    return Container(
      width: 330,
      height: 410,
      decoration: BoxDecoration(
        color: Couleurs.papier,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 14))],
      ),
      clipBehavior: Clip.antiAlias,
      child: const CustomPaint(
        painter: _LignesPage(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(64, 26, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('À retenir', style: TextStyle(fontFamily: policeCahier, fontSize: 34, height: 1.6, color: Couleurs.encre)),
              SizedBox(height: 10),
              Text('Phénomène physique', style: notion),
              Text('Ne modifie pas la nature du corps', style: texte),
              SizedBox(height: 14),
              Text('Phénomène chimique', style: notion),
              Text('Modifie la nature du corps', style: texte),
              SizedBox(height: 14),
              Text('Changement d’état', style: notion),
              Text('Nature et masse conservées', style: texte),
            ],
          ),
        ),
      ),
    );
  }
}

class _LignesPage extends CustomPainter {
  const _LignesPage();

  @override
  void paint(Canvas canvas, Size size) {
    final ligne = Paint()
      ..color = Couleurs.ligneSeyes
      ..strokeWidth = 1.5;
    for (var y = 30.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ligne);
    }
    canvas.drawLine(
      const Offset(46, 0),
      Offset(46, size.height),
      Paint()
        ..color = Couleurs.marge
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_LignesPage ancien) => false;
}

/// Image de présentation, 1024 × 500.
class _Presentation extends StatelessWidget {
  const _Presentation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1024,
      height: 500,
      child: CustomPaint(
        painter: const _Couverture(),
        child: Stack(
          children: [
            Positioned(
              left: 130,
              top: 0,
              bottom: 0,
              width: 440,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toujours sur une ligne : l'écriture de cahier est large,
                  // le nom se réduit plutôt que de se couper.
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SamaClasse',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(fontFamily: policeCahier, fontSize: 60, height: 1.5, color: Couleurs.papier),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Leçons et exercices corrigés du programme sénégalais',
                    style: TextStyle(
                      fontFamily: policeTexte,
                      fontSize: 34,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: Couleurs.papier,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Indices, révisions, suivi des parents\nMême sans internet',
                    style: TextStyle(
                      fontFamily: policeTexte,
                      fontSize: 24,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 56,
              top: 45,
              child: Transform.rotate(angle: -4 * math.pi / 180, child: const _PageCahier()),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(chargerPolicesReelles);

  testWidgets('icône 512 × 512', (tester) async {
    await _enregistrer(
      tester,
      const icone.IconeSamaClasse(taille: 512),
      'build/play/icone_512.png',
      taille: const Size(512, 512),
    );
  });

  testWidgets('image de présentation 1024 × 500', (tester) async {
    await _enregistrer(tester, const _Presentation(), 'build/play/presentation_1024x500.png', taille: const Size(1024, 500));
  });
}
