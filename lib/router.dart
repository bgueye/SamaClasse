import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/widgets/composants.dart';
import 'core/widgets/etats.dart';
import 'data/data.dart';
import 'features/a_propos/a_propos_screen.dart';
import 'features/accueil/accueil_screen.dart';
import 'features/compte/compte_screen.dart';
import 'features/exercices/exercices_screen.dart';
import 'features/lecon/lecon_screen.dart';
import 'features/liaison/lier_screen.dart';
import 'features/matiere/matiere_screen.dart';
import 'features/schemas/schemas_screen.dart';
import 'features/suivi/suivi_screen.dart';
import 'features/validation/validation_screen.dart';

/// Routes de l'application. Les adresses fonctionnent aussi sur le web :
///   /                               accueil (classes et matières)
///   /classe/1/matiere/5             chapitres d'une matière
///   /lecon/12                       une leçon
///   /lecon/12/exercices             ses exercices
///   /lecon/12/schemas               ses schémas : ajout, retrait (rédacteurs)
///   /a-propos                       présentation, version, licences
///   /compte                         espace parents : connexion, profils enfants
///   /lier                           téléphone d'un enfant : code du parent (D32)
///   /suivi                          suivi de mes enfants (parents connectés)
///   /validation                     leçons à vérifier et publication (rédacteurs)
///
/// [emplacementInitial] sert aux tests (ouvrir directement `/lecon/1`, comme
/// une adresse tapée sur le web) ; l'application démarre toujours sur `/`.
GoRouter creerRouteur({String emplacementInitial = '/'}) => GoRouter(
      initialLocation: emplacementInitial,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AccueilScreen(),
          routes: [
            GoRoute(path: 'a-propos', builder: (context, state) => const AProposScreen()),
            GoRoute(path: 'compte', builder: (context, state) => const CompteScreen()),
            GoRoute(path: 'lier', builder: (context, state) => const LierScreen()),
            GoRoute(path: 'suivi', builder: (context, state) => const SuiviScreen()),
            GoRoute(path: 'validation', builder: (context, state) => const ValidationScreen()),
            GoRoute(
              path: 'classe/:classeId/matiere/:matiereId',
              builder: (context, state) {
                final classeId = int.tryParse(state.pathParameters['classeId'] ?? '');
                final matiereId = int.tryParse(state.pathParameters['matiereId'] ?? '');
                if (classeId == null || matiereId == null) return const PageIntrouvable();
                return MatiereScreen(classeId: classeId, matiereId: matiereId);
              },
            ),
            GoRoute(
              path: 'lecon/:leconId',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['leconId'] ?? '');
                if (id == null) return const PageIntrouvable();
                return LeconScreen(leconId: id);
              },
              routes: [
                GoRoute(
                  path: 'exercices',
                  builder: (context, state) {
                    final id = int.tryParse(state.pathParameters['leconId'] ?? '');
                    if (id == null) return const PageIntrouvable();
                    final lecon = state.extra is Lecon ? state.extra as Lecon : null;
                    return ExercicesScreen(leconId: id, lecon: lecon?.id == id ? lecon : null);
                  },
                ),
                GoRoute(
                  path: 'schemas',
                  builder: (context, state) {
                    final id = int.tryParse(state.pathParameters['leconId'] ?? '');
                    if (id == null) return const PageIntrouvable();
                    return SchemasScreen(leconId: id);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => const PageIntrouvable(),
    );

class PageIntrouvable extends StatelessWidget {
  const PageIntrouvable({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(padding: EdgeInsets.fromLTRB(12, 8, 12, 0), child: LienRetour(libelle: 'Mes cours')),
            Expanded(
              child: MessageVide(
                titre: 'Page introuvable',
                texte: 'Cette adresse ne correspond à aucune page de SamaClasse.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
