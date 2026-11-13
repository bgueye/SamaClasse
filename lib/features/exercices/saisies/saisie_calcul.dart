import 'package:flutter/material.dart';

import '../../../data/data.dart';
import '../outils_exercices.dart';
import 'commun.dart';

/// Calcul : un champ par valeur attendue (nombres ou textes courts).
class SaisieCalcul extends StatelessWidget {
  const SaisieCalcul({
    super.key,
    required this.exercice,
    required this.reponse,
    required this.onChanged,
    required this.details,
  });

  final Exercice exercice;
  final Map<String, Object> reponse;
  final ValueChanged<Object?> onChanged;
  final List<bool>? details;

  @override
  Widget build(BuildContext context) {
    final attendues = valeursAttendues(exercice);
    final chemins = attendues.keys.toList();
    final corrige = details != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, chemin) in chemins.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: ValueKey('calcul-${exercice.id}-$chemin'),
                  initialValue: '${reponse[chemin] ?? ''}',
                  readOnly: corrige,
                  textInputAction: TextInputAction.next,
                  keyboardType: attendues[chemin] is num
                      ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                      : TextInputType.text,
                  decoration: InputDecoration(labelText: libelleChemin(chemin)),
                  onChanged: (texte) => onChanged({...reponse, chemin: texte}),
                ),
                if (detail(details, i) != null)
                  RetourChamp(juste: detail(details, i)!, attendu: formaterValeur(attendues[chemin])),
              ],
            ),
          ),
      ],
    );
  }
}
