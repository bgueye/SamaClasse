import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/couleurs.dart';

/// Dos de protège-cahier : la couleur de la matière.
class DosCahier extends StatelessWidget {
  const DosCahier({super.key, required this.couleur, this.largeur = 8, this.hauteur = 36});

  final Color couleur;
  final double largeur;
  final double? hauteur;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: largeur,
        height: hauteur,
        decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}

/// Lien « < Retour » en haut d'écran. Revient en arrière s'il y a un écran
/// précédent, sinon va vers [repli] (cas d'un lien ouvert directement sur le web).
class LienRetour extends StatelessWidget {
  const LienRetour({super.key, required this.libelle, this.repli = '/'});

  final String libelle;
  final String repli;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.canPop() ? context.pop() : context.go(repli),
        icon: const Icon(Icons.chevron_left_rounded, size: 24),
        label: Text(libelle, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 4, right: 12)),
      ),
    );
  }
}

/// Sélecteur à segments des maquettes (choix de classe, onglets de leçon).
class ControleSegmente<T> extends StatelessWidget {
  const ControleSegmente({
    super.key,
    required this.options,
    required this.valeur,
    required this.onChanged,
    required this.libelleGroupe,
  });

  final List<(T, String)> options;
  final T? valeur;
  final ValueChanged<T> onChanged;
  final String libelleGroupe;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: libelleGroupe,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Couleurs.segment, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            for (final (cle, libelle) in options)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _Segment(
                    libelle: libelle,
                    actif: cle == valeur,
                    onTap: () => onChanged(cle),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.libelle, required this.actif, required this.onTap});

  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: actif,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: actif ? Couleurs.papier : Colors.transparent,
        elevation: actif ? 1 : 0,
        shadowColor: const Color(0x1F121A33),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(
                  libelle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: actif ? Couleurs.encre : Couleurs.texteSecondaire,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Largeur maximale du contenu sur tablette et sur le web.
class LargeurLecture extends StatelessWidget {
  const LargeurLecture({super.key, required this.child, this.maxLargeur = 720});

  final Widget child;
  final double maxLargeur;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxLargeur),
        child: child,
      ),
    );
  }
}
