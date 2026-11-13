import 'package:flutter/material.dart';

import '../../../data/data.dart';
import 'saisie_calcul.dart';
import 'saisie_qcm.dart';
import 'saisie_relier.dart';
import 'saisie_tableau.dart';
import 'saisie_vrai_faux.dart';

/// Choisit la bonne zone de réponse selon le type d'exercice.
class SaisieExercice extends StatelessWidget {
  const SaisieExercice({
    super.key,
    required this.exercice,
    required this.reponse,
    required this.onChanged,
    required this.correction,
  });

  final Exercice exercice;
  final Object? reponse;
  final ValueChanged<Object?> onChanged;
  final Correction? correction;

  @override
  Widget build(BuildContext context) {
    final details = switch (correction) {
      CorrectionAuto(:final details) => details,
      _ => null,
    };
    final corrige = correction != null;

    if (!estAutoCorrigeable(exercice)) {
      return _SaisieLibre(exercice: exercice, reponse: reponse as String? ?? '', onChanged: onChanged, corrige: corrige);
    }

    return switch (exercice.type) {
      TypeExercice.qcm => SaisieQcm(
          exercice: exercice,
          reponse: List<int?>.from(reponse as List),
          onChanged: onChanged,
          details: details,
        ),
      TypeExercice.vraiFaux => SaisieVraiFaux(
          exercice: exercice,
          reponse: List<bool?>.from(reponse as List),
          onChanged: onChanged,
          details: details,
        ),
      TypeExercice.relier => SaisieRelier(
          exercice: exercice,
          reponse: Map<String, String>.from(reponse as Map),
          onChanged: onChanged,
          details: details,
        ),
      TypeExercice.tableau when exercice.reponse is List => SaisieTableauOrdonne(
          exercice: exercice,
          reponse: List<String>.from(reponse as List),
          onChanged: onChanged,
          details: details,
        ),
      TypeExercice.tableau => SaisieClassement(
          exercice: exercice,
          reponse: {
            for (final e in (reponse as Map).entries) e.key as String: List<String>.from(e.value as List),
          },
          onChanged: onChanged,
          corrige: corrige,
        ),
      TypeExercice.calcul => SaisieCalcul(
          exercice: exercice,
          reponse: Map<String, Object>.from(reponse as Map),
          onChanged: onChanged,
          details: details,
        ),
      _ => _SaisieLibre(exercice: exercice, reponse: '$reponse', onChanged: onChanged, corrige: corrige),
    };
  }
}

/// Réponse libre (question de cours, rédaction…) : un brouillon que
/// l'élève compare ensuite au corrigé. Rien n'est envoyé.
class _SaisieLibre extends StatelessWidget {
  const _SaisieLibre({
    required this.exercice,
    required this.reponse,
    required this.onChanged,
    required this.corrige,
  });

  final Exercice exercice;
  final String reponse;
  final ValueChanged<Object?> onChanged;
  final bool corrige;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('libre-${exercice.id}'),
      initialValue: reponse,
      readOnly: corrige,
      minLines: 4,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        labelText: 'Ta réponse',
        helperText: 'C’est ton brouillon : il reste sur ton téléphone.',
        // Par défaut, l'aide tient sur une ligne et finit par « … » avec un
        // texte agrandi : on la laisse passer à la ligne (DESIGN.md, 200 %).
        helperMaxLines: 4,
        alignLabelWithHint: true,
      ),
      onChanged: onChanged,
    );
  }
}
