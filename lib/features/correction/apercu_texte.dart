import 'package:flutter/material.dart';

import '../../core/theme/couleurs.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/markdown_cahier.dart';
import '../../core/widgets/page_seyes.dart';
import '../../data/data.dart';

/// Titre cursif, comme sur la page d'une leçon.
final _styleTitre = Styles.cahier(taille: 23, hauteurLigne: interligne * 2);

/// Texte d'une leçon (copie de travail d'une correction ou version
/// archivée, D33) sur une page de cahier, tel que les élèves le liraient :
/// titre, objectifs, introduction, corps, puis « À retenir ». Pour que le
/// rédacteur relise la version corrigée avant de lever les points.
class ApercuTexte extends StatelessWidget {
  const ApercuTexte({super.key, required this.texte, this.entete});

  final TexteRedige texte;

  /// Bloc affiché au-dessus du titre (raison de la correction, version…).
  final Widget? entete;

  @override
  Widget build(BuildContext context) {
    return PageSeyes(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entete != null) ...[entete!, const SizedBox(height: interligne)],
          Semantics(
            header: true,
            child: SurLigneSeyes(style: _styleTitre, child: Text(texte.titre, style: _styleTitre)),
          ),
          if (texte.objectifs.isNotEmpty) ...[
            const _TitreSection('Ce que tu vas apprendre'),
            for (final o in texte.objectifs)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: Styles.lecon),
                  Expanded(child: Text(o, style: Styles.lecon)),
                ],
              ),
            const SizedBox(height: interligne),
          ],
          if (texte.introduction?.trim().isNotEmpty ?? false) ...[
            const _TitreSection('Introduction'),
            MarkdownCahier(data: texte.introduction!, surSeyes: true),
            const SizedBox(height: interligne),
          ],
          if (texte.corps?.trim().isNotEmpty ?? false) MarkdownCahier(data: texte.corps!, surSeyes: true),
          if (texte.aRetenir.isNotEmpty) ...[
            const SizedBox(height: interligne),
            const _TitreSection('À retenir'),
            for (final r in texte.aRetenir)
              Padding(
                padding: const EdgeInsets.only(bottom: interligne),
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.notion, style: Styles.lecon.copyWith(fontWeight: FontWeight.w700, color: Couleurs.encre)),
                      Text(r.essentiel, style: Styles.lecon),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  const _TitreSection(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(texte, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: interligne / 17)),
      );
}

/// Encadré d'information au-dessus d'un aperçu : icône + texte (jamais la
/// couleur seule).
class EncadreApercu extends StatelessWidget {
  const EncadreApercu({super.key, required this.icone, required this.lignes});

  final IconData icone;
  final List<String> lignes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Couleurs.selection, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: Couleurs.encre, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, l) in lignes.indexed)
                  Text(
                    l,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
                      color: Couleurs.texte,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
