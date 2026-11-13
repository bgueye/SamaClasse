import 'package:flutter/material.dart';

import '../../../data/data.dart';
import 'commun.dart';

/// Vrai ou faux : `donnees.affirmations`, réponse = un booléen par affirmation.
class SaisieVraiFaux extends StatelessWidget {
  const SaisieVraiFaux({
    super.key,
    required this.exercice,
    required this.reponse,
    required this.onChanged,
    required this.details,
  });

  final Exercice exercice;
  final List<bool?> reponse;
  final ValueChanged<Object?> onChanged;
  final List<bool>? details;

  @override
  Widget build(BuildContext context) {
    final donnees = exercice.donnees;
    final affirmations =
        donnees is Map && donnees['affirmations'] is List ? List<String>.from(donnees['affirmations'] as List) : const <String>[];
    final attendu = exercice.reponse as List;
    final corrige = details != null;
    final n = [affirmations.length, reponse.length, attendu.length].reduce((a, b) => a < b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < n; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IntituleQuestion(numero: i + 1, texte: affirmations[i]),
                  Row(
                    children: [
                      for (final (valeur, libelle) in const [(true, 'Vrai'), (false, 'Faux')]) ...[
                        Expanded(
                          child: TuileChoix(
                            libelle: libelle,
                            centre: true,
                            etat: _etat(i, valeur, attendu[i] as bool, corrige),
                            onTap: corrige
                                ? null
                                : () {
                                    final copie = List<bool?>.of(reponse);
                                    copie[i] = valeur;
                                    onChanged(copie);
                                  },
                          ),
                        ),
                        if (valeur) const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  EtatTuile _etat(int i, bool valeur, bool bon, bool corrige) {
    final choisi = reponse[i] == valeur;
    if (!corrige) return choisi ? EtatTuile.selectionnee : EtatTuile.neutre;
    if (valeur == bon) return EtatTuile.juste;
    if (choisi) return EtatTuile.fausse;
    return EtatTuile.attenuee;
  }
}
