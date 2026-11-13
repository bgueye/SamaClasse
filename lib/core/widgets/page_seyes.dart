import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../theme/theme.dart';

/// Page de cahier : lignes Seyès (interligne de 32 px, 3 lignes fines
/// intermédiaires) et marge rouge. Le contenu défile avec les lignes.
///
/// Comme dans un vrai cahier, le texte courant **repose sur les lignes
/// fortes** : elles sont tracées à la hauteur de la ligne de base de
/// [Styles.lecon], mesurée sur la police réelle (voir [ligneDeBase]). Pour
/// que tout le texte tombe juste, chaque bloc de la page doit avoir une
/// hauteur multiple de [interligne] (les styles de leçon y veillent) ; les
/// titres cursifs, plus hauts, sont recalés avec [SurLigneSeyes].
///
/// L'alignement vaut pour la taille de texte normale. Avec un texte système
/// agrandi, les lignes restent un décor : la lisibilité passe avant.
class PageSeyes extends StatelessWidget {
  const PageSeyes({super.key, required this.child});

  final Widget child;

  static const _positionMarge = 36.0;

  /// Marge haute du contenu : la première ligne de texte commence ici.
  static const _hautContenu = 16.0;

  @override
  Widget build(BuildContext context) {
    // Position (depuis le haut de la page) de la première ligne forte :
    // sous la première ligne de texte, à sa ligne de base.
    final premiereLigneForte = _hautContenu + ligneDeBase(_texteCourant(context));

    return LayoutBuilder(
      builder: (context, contraintes) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: contraintes.maxHeight),
          child: ColoredBox(
            color: Couleurs.papier,
            child: CustomPaint(
              painter: _PeintreSeyes(margeX: _positionMarge, premiereLigneForte: premiereLigneForte),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_positionMarge + 16, _hautContenu, 22, 40),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Distance entre le haut de la boîte d'une ligne de texte et sa ligne de
/// base, pour [style] (taille de texte système ignorée).
///
/// Mesurée sur la police réellement chargée plutôt que codée en dur : la
/// valeur dépend des métriques de la police (ascendante, descendante) et de
/// la répartition de l'interlignage par Flutter. Un style sans police
/// explicite prend [policeTexte], comme le thème.
double ligneDeBase(TextStyle style) {
  final peintre = TextPainter(
    text: TextSpan(text: 'Hxg', style: style.fontFamily == null ? style.copyWith(fontFamily: policeTexte) : style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  final distance = peintre.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  peintre.dispose();
  return distance;
}

/// Décale verticalement (au dessin seulement) un titre écrit avec [style]
/// pour que sa ligne de base tombe sur une ligne forte, comme le texte courant.
///
/// Pourquoi un décalage au dessin : la boîte du titre garde sa hauteur
/// (multiple de l'interligne), donc tout ce qui suit reste sur les lignes.
/// Seul le tracé des lettres descend (ou monte) de moins d'un demi-interligne.
class SurLigneSeyes extends StatelessWidget {
  const SurLigneSeyes({super.key, required this.style, required this.child});

  /// Style du texte de [child] (police, taille, hauteur de ligne).
  final TextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Style effectif, comme le verra le widget Text : fusionné avec le style
    // par défaut (Material 3 y fixe une répartition « even » de l'interlignage,
    // qui déplace la ligne de base de plusieurs pixels).
    final effectif = DefaultTextStyle.of(context).style.merge(style);
    final decalage = decalageVersLigne(effectif, texteCourant: _texteCourant(context));
    if (decalage.abs() < 0.5) return child;
    return Transform.translate(offset: Offset(0, decalage), child: child);
  }
}

/// Style effectif du texte courant de leçon à cet endroit de l'arbre.
TextStyle _texteCourant(BuildContext context) => DefaultTextStyle.of(context).style.merge(Styles.lecon);

/// Décalage à appliquer à un texte de [style] pour que sa ligne de base
/// rejoigne celle du [texteCourant] (donc une ligne forte). Compris entre
/// -16 et +16 : on va vers la ligne la plus proche.
double decalageVersLigne(TextStyle style, {required TextStyle texteCourant}) {
  var decalage = (ligneDeBase(texteCourant) - ligneDeBase(style)) % interligne;
  if (decalage > interligne / 2) decalage -= interligne;
  return decalage;
}

class _PeintreSeyes extends CustomPainter {
  const _PeintreSeyes({required this.margeX, required this.premiereLigneForte});

  final double margeX;
  final double premiereLigneForte;

  @override
  void paint(Canvas canvas, Size size) {
    final fine = Paint()
      ..color = Couleurs.ligneSeyesFine
      ..strokeWidth = 1;
    final forte = Paint()
      ..color = Couleurs.ligneSeyes
      ..strokeWidth = 1;
    const pas = interligne / 4;

    // On part de la première ligne forte et on remonte jusqu'au haut de la
    // page, pour que les lignes fines au-dessus du texte soient aussi tracées.
    // `j % 4 == 0` repère les lignes fortes (le % de Dart reste positif).
    final debut = -(premiereLigneForte / pas).floor();
    for (var j = debut;; j++) {
      final y = premiereLigneForte + j * pas;
      if (y >= size.height) break;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), j % 4 == 0 ? forte : fine);
    }

    canvas.drawLine(
      Offset(margeX, 0),
      Offset(margeX, size.height),
      Paint()
        ..color = Couleurs.marge
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PeintreSeyes oldDelegate) =>
      oldDelegate.margeX != margeX || oldDelegate.premiereLigneForte != premiereLigneForte;
}
