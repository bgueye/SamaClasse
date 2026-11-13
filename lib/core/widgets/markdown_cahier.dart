import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../theme/couleurs.dart';
import '../theme/theme.dart';
import 'page_seyes.dart';

/// Texte Markdown des leçons et des exercices.
///
/// Sur une page Seyès ([surSeyes]), les paragraphes s'alignent sur
/// l'interligne de 32 px et les titres de partie (`##`) sont écrits en
/// cursive rouge, comme dans les maquettes.
class MarkdownCahier extends StatelessWidget {
  const MarkdownCahier({super.key, required this.data, this.surSeyes = false});

  final String data;
  final bool surSeyes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corps = surSeyes
        ? Styles.lecon
        : const TextStyle(fontSize: 16, height: 1.5, color: Couleurs.texte);

    final style = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: corps,
      listBullet: corps,
      strong: const TextStyle(fontWeight: FontWeight.w700),
      em: const TextStyle(fontStyle: FontStyle.italic),
      h1: Styles.cahier(taille: 23, hauteurLigne: surSeyes ? interligne * 2 : null),
      h2: surSeyes
          ? Styles.cahier(taille: 17, couleur: Couleurs.marge, hauteurLigne: interligne * 2)
          : const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4),
      h3: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: surSeyes ? interligne / 17 : 1.4,
        color: Couleurs.texte,
      ),
      h4: corps.copyWith(fontWeight: FontWeight.w700),
      blockSpacing: surSeyes ? 0 : 10,
      tableHead: corps.copyWith(fontWeight: FontWeight.w700, height: 1.4),
      tableBody: corps.copyWith(height: 1.4),
      tableBorder: TableBorder.all(color: Couleurs.bordureForte),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      blockquoteDecoration: BoxDecoration(
        color: Couleurs.selection,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding: const EdgeInsets.all(12),
      code: const TextStyle(fontFamily: 'monospace', fontSize: 15),
    );

    return MarkdownBody(
      data: data,
      styleSheet: style,
      softLineBreak: true,
      // Sur une page Seyès, les titres cursifs sont recalés sur les lignes.
      builders: surSeyes ? {'h1': _titreCursif, 'h2': _titreCursif} : const {},
    );
  }
}

final _titreCursif = _TitreCursif();

/// Rendu des titres `#` et `##` sur une page Seyès : posés sur une ligne
/// forte ([SurLigneSeyes]) et annoncés comme titres aux lecteurs d'écran
/// (le rendu Markdown par défaut ne le fait pas).
class _TitreCursif extends MarkdownElementBuilder {
  // Pas de `const` : le constructeur de MarkdownElementBuilder ne l'est pas.
  // Une seule instance partagée suffit (le constructeur ne garde aucun état).
  _TitreCursif();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    // Le type réel est `md.Element` du paquet `markdown`, dépendance de
    // flutter_markdown_plus. On le reçoit en `Object` pour ne pas ajouter ce
    // paquet aux dépendances directes : seul `textContent` nous sert.
    Object element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final texte = (element as dynamic).textContent as String;
    final style = preferredStyle ?? parentStyle ?? Styles.lecon;
    return Semantics(
      header: true,
      child: SurLigneSeyes(style: style, child: Text(texte, style: style)),
    );
  }
}
