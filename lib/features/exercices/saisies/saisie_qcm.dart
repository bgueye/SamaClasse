import 'package:flutter/material.dart';

import '../../../data/data.dart';
import 'commun.dart';

/// QCM : `donnees.questions` = [{q, choix}], réponse = un indice par question.
class SaisieQcm extends StatelessWidget {
  const SaisieQcm({
    super.key,
    required this.exercice,
    required this.reponse,
    required this.onChanged,
    required this.details,
  });

  final Exercice exercice;
  final List<int?> reponse;
  final ValueChanged<Object?> onChanged;

  /// Résultat par question, après correction.
  final List<bool>? details;

  @override
  Widget build(BuildContext context) {
    final donnees = exercice.donnees;
    final questions = donnees is Map && donnees['questions'] is List ? donnees['questions'] as List : const [];
    final attendu = exercice.reponse as List;
    final corrige = details != null;
    final n = [questions.length, reponse.length, attendu.length].reduce((a, b) => a < b ? a : b);

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
                  IntituleQuestion(numero: i + 1, texte: '${(questions[i] as Map)['q']}'),
                  for (final (j, choix) in List<String>.from((questions[i] as Map)['choix'] as List).indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TuileChoix(
                        libelle: choix,
                        etat: _etat(i, j, attendu[i] as int, corrige),
                        onTap: corrige
                            ? null
                            : () {
                                final copie = List<int?>.of(reponse);
                                copie[i] = j;
                                onChanged(copie);
                              },
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  EtatTuile _etat(int question, int choix, int bon, bool corrige) {
    final choisi = reponse[question] == choix;
    if (!corrige) return choisi ? EtatTuile.selectionnee : EtatTuile.neutre;
    if (choix == bon) return EtatTuile.juste;
    if (choisi) return EtatTuile.fausse;
    return EtatTuile.attenuee;
  }
}
