import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../core/widgets/markdown_cahier.dart';
import '../../data/data.dart';
import 'outils_projection.dart';

/// Mode projection (D35, maquette `Projection`), à l'adresse
/// `/lecon/:id/projection` : la leçon partie par partie, en très grand,
/// pour un vidéoprojecteur ou un grand écran en classe.
///
/// Commandes : boutons, ou clavier d'un ordinateur relié au projecteur
/// (flèches, Page suivante/précédente, Espace, Échap pour quitter). Le texte
/// est celui de la leçon (copie locale, D16 : marche hors connexion).
class ProjectionScreen extends StatefulWidget {
  const ProjectionScreen({super.key, required this.leconId});

  final int leconId;

  @override
  State<ProjectionScreen> createState() => _ProjectionScreenState();
}

class _ProjectionScreenState extends State<ProjectionScreen> {
  Future<Lecon?>? _chargement;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chargement ??= _charger();
  }

  Future<Lecon?> _charger() =>
      AppScope.of(context).repository.lecon(widget.leconId);

  void _quitter() =>
      context.canPop() ? context.pop() : context.go('/lecon/${widget.leconId}');

  /// Avance ou recule de [pas] parties depuis la position actuelle (et non
  /// celle de la dernière construction : plusieurs appuis rapides entre deux
  /// images comptent chacun).
  void _decaler(int pas, int total) {
    final suivant = (_index + pas).clamp(0, total - 1);
    if (suivant != _index) setState(() => _index = suivant);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.papier,
      body: SafeArea(
        child: FutureBuilder<Lecon?>(
          future: _chargement,
          builder: (context, instantane) {
            if (instantane.connectionState != ConnectionState.done) {
              return const Chargement();
            }
            if (instantane.hasError) {
              return _avecRetour(
                MessageErreur(
                  erreur: instantane.error!,
                  onReessayer: () => setState(() {
                    _chargement = _charger();
                  }),
                ),
              );
            }
            final lecon = instantane.data;
            if (lecon == null) {
              return _avecRetour(
                const MessageVide(
                  titre: 'Leçon pas encore disponible',
                  texte:
                      'Cette leçon est en cours de vérification. Elle sera bientôt en ligne.',
                ),
              );
            }
            final diapos = diapositives(lecon);
            final index = _index.clamp(0, diapos.length - 1);
            return CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _decaler(1, diapos.length),
                const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                    _decaler(1, diapos.length),
                const SingleActivator(LogicalKeyboardKey.space): () =>
                    _decaler(1, diapos.length),
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _decaler(-1, diapos.length),
                const SingleActivator(LogicalKeyboardKey.pageUp): () =>
                    _decaler(-1, diapos.length),
                const SingleActivator(LogicalKeyboardKey.escape): _quitter,
              },
              child: Focus(
                autofocus: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ExcludeFocus : un bouton touché ne garde pas le focus,
                    // sinon Espace et les flèches agiraient sur lui au lieu
                    // de changer de partie. Le clavier pilote la projection
                    // (flèches, Espace, Échap) ; les boutons servent au doigt
                    // et à la souris.
                    ExcludeFocus(
                      child: _Entete(
                        lecon: lecon,
                        position: 'Partie ${index + 1} sur ${diapos.length}',
                        onPrecedent: index > 0
                            ? () => _decaler(-1, diapos.length)
                            : null,
                        onSuivant: index < diapos.length - 1
                            ? () => _decaler(1, diapos.length)
                            : null,
                        onQuitter: _quitter,
                      ),
                    ),
                    Expanded(
                      child: _Page(
                        key: ValueKey(index),
                        diapositive: diapos[index],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _avecRetour(Widget enfant) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: LienRetour(libelle: 'Retour', repli: '/lecon/${widget.leconId}'),
      ),
      Expanded(child: enfant),
    ],
  );
}

/// Bandeau du haut : titre, position, précédent / suivant, quitter. Sur un
/// écran étroit, il passe sur deux lignes (Wrap) au lieu de déborder.
class _Entete extends StatelessWidget {
  const _Entete({
    required this.lecon,
    required this.position,
    required this.onPrecedent,
    required this.onSuivant,
    required this.onQuitter,
  });

  final Lecon lecon;
  final String position;
  final VoidCallback? onPrecedent;
  final VoidCallback? onSuivant;
  final VoidCallback onQuitter;

  @override
  Widget build(BuildContext context) {
    final c = lecon.contexte;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Couleurs.papier,
        border: Border(bottom: BorderSide(color: Couleurs.bordure)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 16, 6),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  lecon.titre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Couleurs.texte,
                  ),
                ),
                if (c != null)
                  Text(
                    '${c.matiere}, ${c.classe}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Couleurs.texteSecondaire,
                    ),
                  ),
              ],
            ),
            // Wrap : avec un texte très agrandi, les commandes passent à la
            // ligne au lieu de déborder.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    position,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Couleurs.texteSecondaire,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Partie précédente',
                  onPressed: onPrecedent,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton.outlined(
                  tooltip: 'Partie suivante',
                  onPressed: onSuivant,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                OutlinedButton(
                  onPressed: onQuitter,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  child: const Text('Quitter la projection'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Une diapositive : marge rouge, titre de partie en cursive rouge, texte de
/// la leçon agrandi selon la largeur de l'écran (et jamais plus petit que la
/// taille de texte choisie sur l'appareil). Défile si la partie est longue.
class _Page extends StatelessWidget {
  const _Page({super.key, required this.diapositive});

  final Diapositive diapositive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final systeme = MediaQuery.textScalerOf(context).scale(16) / 16;
        final facteur = math.max(
          systeme,
          agrandissementProjection(contraintes.maxWidth),
        );
        final margeGauche = contraintes.maxWidth >= 900 ? 140.0 : 56.0;
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(facteur)),
          child: Stack(
            children: [
              // Marge rouge du cahier : décor.
              Positioned(
                left: margeGauche - 36,
                top: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: Container(width: 3, color: Couleurs.marge),
                ),
              ),
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(margeGauche, 20, 48, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          diapositive.titre,
                          style: Styles.cahier(
                            taille: 20,
                            couleur: Couleurs.marge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (diapositive.markdown.isNotEmpty)
                        MarkdownCahier(data: diapositive.markdown),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
