import 'package:flutter/material.dart';

import '../../../core/theme/couleurs.dart';

enum EtatTuile { neutre, selectionnee, juste, fausse, attenuee }

/// Une réponse à toucher (choix de QCM, Vrai, Faux).
/// L'état juste ou faux est donné par une icône en plus de la couleur.
class TuileChoix extends StatelessWidget {
  const TuileChoix({super.key, required this.libelle, required this.etat, this.onTap, this.centre = false});

  final String libelle;
  final EtatTuile etat;
  final VoidCallback? onTap;
  final bool centre;

  @override
  Widget build(BuildContext context) {
    final (fond, bord, texte) = switch (etat) {
      EtatTuile.neutre => (Couleurs.papier, Couleurs.bordureForte, Couleurs.texte),
      EtatTuile.selectionnee => (Couleurs.selection, Couleurs.encre, Couleurs.encre),
      EtatTuile.juste => (Couleurs.justeFond, Couleurs.juste, Couleurs.juste),
      EtatTuile.fausse => (Couleurs.fauxFond, Couleurs.faux, Couleurs.faux),
      EtatTuile.attenuee => (Couleurs.papier, Couleurs.bordure, Couleurs.texteSecondaire),
    };
    final icone = switch (etat) {
      EtatTuile.juste => Icons.check_rounded,
      EtatTuile.fausse => Icons.close_rounded,
      _ => null,
    };

    return Semantics(
      button: onTap != null,
      selected: etat == EtatTuile.selectionnee || etat == EtatTuile.fausse,
      inMutuallyExclusiveGroup: true,
      label: switch (etat) {
        EtatTuile.juste => '$libelle, bonne réponse',
        EtatTuile.fausse => '$libelle, ta réponse, fausse',
        _ => libelle,
      },
      excludeSemantics: true,
      child: Material(
        color: fond,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: bord, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: centre ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  if (icone != null) ...[Icon(icone, color: texte, size: 22), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      libelle,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: texte, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Petite ligne sous un champ après correction : « Juste » ou « Attendu : … ».
class RetourChamp extends StatelessWidget {
  const RetourChamp({super.key, required this.juste, this.attendu});

  final bool juste;
  final String? attendu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            juste ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 20,
            color: juste ? Couleurs.juste : Couleurs.faux,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              juste ? 'Juste' : (attendu == null ? 'Faux' : 'Attendu : $attendu'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: juste ? Couleurs.juste : Couleurs.faux,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numéro + texte d'une question.
class IntituleQuestion extends StatelessWidget {
  const IntituleQuestion({super.key, required this.numero, required this.texte});

  final int numero;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '$numero. $texte',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
      ),
    );
  }
}

/// Détail de correction pour l'élément [i], ou `null` si pas encore corrigé.
bool? detail(List<bool>? details, int i) =>
    details == null || i >= details.length ? null : details[i];
