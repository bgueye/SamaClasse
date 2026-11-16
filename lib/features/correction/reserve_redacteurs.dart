import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';

/// Écran des rédacteurs ouvert sans être connecté, ou avec un compte non
/// rédacteur (même message que « Leçons à vérifier »).
class ReserveRedacteurs extends StatelessWidget {
  const ReserveRedacteurs({super.key, required this.connecte, required this.repli});

  final bool connecte;

  /// Page de repli du lien « Retour » (adresse ouverte directement).
  final String repli;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: LienRetour(libelle: 'Retour', repli: repli),
        ),
        Expanded(
          child: MessageVide(
            titre: 'Réservé aux rédacteurs',
            texte: connecte
                ? 'Ton compte n’a pas les droits de rédacteur. Ils se donnent dans le tableau de bord Supabase.'
                : 'Connecte-toi dans l’espace parents avec un compte rédacteur.',
            action: connecte
                ? null
                : FilledButton(
                    onPressed: () => context.go('/compte'),
                    child: const Text('Aller à l’espace parents'),
                  ),
          ),
        ),
      ],
    );
  }
}
