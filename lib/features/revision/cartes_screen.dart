import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/matieres.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../data/data.dart';
import 'outils_cartes.dart';

/// « Interroge-moi » (D35, maquettes `Main` et `CartesParent`), à l'adresse
/// `/lecon/:id/reviser` (`?mode=parent` pour ouvrir le mode parent).
///
/// Les cartes sont les notions « À retenir » de la leçon, lues dans la copie
/// locale (D16) : l'écran marche hors connexion. Deux modes :
/// - élève (tutoiement) : la notion, puis l'essentiel en retournant la carte ;
/// - parent (vouvoiement, comme l'espace parents) : la question à poser et
///   la réponse attendue visible tout de suite, pour faire réciter un enfant
///   sans connaître la leçon. Pas besoin de compte.
///
/// Comme l'écran d'exercices, il ne se recharge pas tout seul quand du
/// contenu nouveau arrive : une séance en cours ne doit pas repartir de zéro.
class CartesScreen extends StatefulWidget {
  const CartesScreen({super.key, required this.leconId, this.mode = ModeCartes.eleve});

  final int leconId;
  final ModeCartes mode;

  @override
  State<CartesScreen> createState() => _CartesScreenState();
}

class _CartesScreenState extends State<CartesScreen> {
  Future<Lecon?>? _chargement;
  late ModeCartes _mode = widget.mode;

  /// Séance en cours ; créée au premier affichage de la leçon chargée.
  SeanceCartes? _seance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chargement ??= _charger();
  }

  Future<Lecon?> _charger() => AppScope.of(context).repository.lecon(widget.leconId);

  void _majSeance(SeanceCartes suivante) => setState(() { _seance = suivante; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LargeurLecture(
          child: FutureBuilder<Lecon?>(
            future: _chargement,
            builder: (context, instantane) {
              if (instantane.connectionState != ConnectionState.done) return const Chargement();
              if (instantane.hasError) {
                return _avecRetour(MessageErreur(
                  erreur: instantane.error!,
                  onReessayer: () => setState(() { _chargement = _charger(); }),
                ));
              }
              final lecon = instantane.data;
              if (lecon == null) {
                return _avecRetour(const MessageVide(
                  titre: 'Leçon pas encore disponible',
                  texte: 'Cette leçon est en cours de vérification. Elle sera bientôt en ligne.',
                ));
              }
              final seance = _seance ??= SeanceCartes.depuis(lecon.aRetenir);
              if (seance.vide) {
                return _avecRetour(MessageVide(
                  titre: 'Pas encore de cartes',
                  texte: 'Cette leçon n’a pas encore de résumé « À retenir » : il n’y a rien à réciter pour l’instant.',
                  action: OutlinedButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go('/lecon/${lecon.id}'),
                    child: const Text('Revenir à la leçon'),
                  ),
                ));
              }
              return _contenu(lecon, seance);
            },
          ),
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

  Widget _contenu(Lecon lecon, SeanceCartes seance) {
    final parent = _mode == ModeCartes.parent;
    final c = lecon.contexte;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 32),
      children: [
        LienRetour(libelle: lecon.titre, repli: '/lecon/${lecon.id}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  parent ? 'Faire réciter' : 'Interroge-moi',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Couleurs.texte),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                parent
                    ? 'Posez la question, puis comparez sa réponse avec le texte.'
                    : 'Réponds dans ta tête, puis retourne la carte.',
                style: const TextStyle(fontSize: 15, height: 1.4, color: Couleurs.texteSecondaire),
              ),
              const SizedBox(height: 14),
              ControleSegmente<ModeCartes>(
                libelleGroupe: 'Qui révise',
                options: const [(ModeCartes.eleve, 'Je révise seul'), (ModeCartes.parent, 'Je fais réciter')],
                valeur: _mode,
                // Changer de mode reprend la séance au début : un adulte qui
                // prend le relais part de la première question.
                onChanged: (m) => setState(() {
                  _mode = m;
                  _seance = seance.recommencer();
                }),
              ),
              const SizedBox(height: 20),
              if (seance.terminee)
                _Bilan(
                  seance: seance,
                  mode: _mode,
                  lecon: lecon,
                  onRevoir: () => _majSeance(seance.revoirRatees()),
                  onRecommencer: () => _majSeance(seance.recommencer()),
                )
              else ...[
                // Wrap plutôt que Row : avec un texte très agrandi, la
                // position passe sous la matière au lieu de déborder.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (c != null) Text('${c.matiere}, ${c.classe}', style: Styles.etiquette),
                    Text(seance.libellePosition(_mode), style: Styles.secondaire),
                  ],
                ),
                const SizedBox(height: 10),
                if (parent)
                  _CarteParent(carte: seance.carte, couleur: couleurMatiere(c?.matiereSlug))
                else
                  _CarteEleve(carte: seance.carte, retournee: seance.retournee, couleur: couleurMatiere(c?.matiereSlug)),
                const SizedBox(height: 18),
                if (!parent && !seance.retournee)
                  FilledButton(
                    onPressed: () => _majSeance(seance.retourner()),
                    child: const Text('Retourner la carte'),
                  )
                else
                  _Reponses(
                    libelleSue: parent ? 'Bien répondu' : 'Je savais',
                    onRepondre: (sue) => _majSeance(seance.repondre(sue: sue)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Bande de la couleur de la matière en haut d'une carte (décor).
class _BandeMatiere extends StatelessWidget {
  const _BandeMatiere({required this.couleur});

  final Color couleur;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: Container(height: 8, color: couleur));
}

/// Cadre commun des cartes : papier, bordure, coins arrondis.
class _Cadre extends StatelessWidget {
  const _Cadre({required this.couleur, required this.child});

  final Color couleur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Couleurs.papier,
        border: Border.all(color: Couleurs.bordureCarte, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BandeMatiere(couleur: couleur),
            Padding(padding: const EdgeInsets.fromLTRB(22, 22, 22, 24), child: child),
          ],
        ),
      ),
    );
  }
}

const _styleEtiquetteCarte = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
  color: Couleurs.texteSecondaire,
);

class _CarteEleve extends StatelessWidget {
  const _CarteEleve({required this.carte, required this.retournee, required this.couleur});

  final ElementARetenir carte;
  final bool retournee;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return _Cadre(
      couleur: couleur,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('NOTION', textAlign: TextAlign.center, style: _styleEtiquetteCarte),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              carte.notion,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w700, color: Couleurs.encre),
            ),
          ),
          if (retournee) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, color: Couleurs.bordure),
            const SizedBox(height: 18),
            // liveRegion : un lecteur d'écran lit l'essentiel dès qu'il paraît.
            Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('L’ESSENTIEL', textAlign: TextAlign.center, style: _styleEtiquetteCarte),
                  const SizedBox(height: 8),
                  Text(
                    carte.essentiel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, height: 1.5, color: Couleurs.texte),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarteParent extends StatelessWidget {
  const _CarteParent({required this.carte, required this.couleur});

  final ElementARetenir carte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cadre(
          couleur: couleur,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Demandez-lui :',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.texteSecondaire),
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text(
                  questionParent(carte.notion),
                  style: const TextStyle(fontSize: 22, height: 1.35, fontWeight: FontWeight.w700, color: Couleurs.encre),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(color: Couleurs.selection, borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ce qu’il faut entendre',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.texteDoux),
                ),
                const SizedBox(height: 8),
                Text(carte.essentiel, style: const TextStyle(fontSize: 18, height: 1.5, color: Couleurs.texte)),
                const SizedBox(height: 12),
                const Text(
                  'Pas besoin de connaître la leçon : comparez sa réponse avec ce texte. '
                  'Les idées comptent plus que les mots exacts.',
                  style: TextStyle(fontSize: 13, height: 1.45, color: Couleurs.texteDoux),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// « À revoir » / « Je savais » (ou « Bien répondu ») : icône et texte, jamais
/// la couleur seule (DESIGN.md).
class _Reponses extends StatelessWidget {
  const _Reponses({required this.libelleSue, required this.onRepondre});

  final String libelleSue;
  final ValueChanged<bool> onRepondre;

  @override
  Widget build(BuildContext context) {
    final aRevoir = OutlinedButton.icon(
      onPressed: () => onRepondre(false),
      icon: const Icon(Icons.replay_rounded),
      label: const Text('À revoir'),
    );
    final sue = FilledButton.icon(
      onPressed: () => onRepondre(true),
      style: FilledButton.styleFrom(backgroundColor: Couleurs.juste, foregroundColor: Couleurs.texteSurEncre),
      icon: const Icon(Icons.check_rounded),
      label: Text(libelleSue),
    );
    // Côte à côte quand la place le permet ; l'un sous l'autre avec un texte
    // très agrandi, pour ne rien couper.
    return LayoutBuilder(
      builder: (context, contraintes) {
        final etroit = contraintes.maxWidth < 320 || MediaQuery.textScalerOf(context).scale(16) > 24;
        if (etroit) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [sue, const SizedBox(height: 10), aRevoir],
          );
        }
        return Row(
          children: [
            Expanded(child: aRevoir),
            const SizedBox(width: 10),
            Expanded(child: sue),
          ],
        );
      },
    );
  }
}

class _Bilan extends StatelessWidget {
  const _Bilan({
    required this.seance,
    required this.mode,
    required this.lecon,
    required this.onRevoir,
    required this.onRecommencer,
  });

  final SeanceCartes seance;
  final ModeCartes mode;
  final Lecon lecon;
  final VoidCallback onRevoir;
  final VoidCallback onRecommencer;

  @override
  Widget build(BuildContext context) {
    final parent = mode == ModeCartes.parent;
    final total = seance.file.length;
    final ratees = seance.aRevoir.length;
    final pluriel = ratees > 1;
    final phrase = parent
        ? 'Bonne réponse à ${seance.sues} question${seance.sues > 1 ? 's' : ''} sur $total.'
        : 'Tu savais ${seance.sues} carte${seance.sues > 1 ? 's' : ''} sur $total.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(parent ? 'C’est fini pour ce soir' : 'Cartes terminées', style: Styles.cahier(taille: 23)),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(phrase, style: const TextStyle(fontSize: 18, height: 1.5, color: Couleurs.texte)),
        ),
        if (ratees > 0) ...[
          const SizedBox(height: 6),
          Text(
            parent
                ? '$ratees notion${pluriel ? 's' : ''} à revoir : vous pouvez ${pluriel ? 'les' : 'la'} reposer tout de suite.'
                : '$ratees carte${pluriel ? 's' : ''} à revoir : reprends-${pluriel ? 'les' : 'la'} maintenant ou plus tard.',
            style: const TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texteDoux),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onRevoir,
            child: Text(parent ? 'Reposer les questions ratées' : 'Revoir les cartes ratées'),
          ),
        ],
        const SizedBox(height: 12),
        if (!parent && lecon.exercices.isNotEmpty) ...[
          FilledButton(
            onPressed: () => context.push('/lecon/${lecon.id}/exercices', extra: lecon),
            child: Text('Faire les exercices (${lecon.exercices.length})'),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onRecommencer, child: const Text('Recommencer toutes les cartes')),
        ] else
          FilledButton(onPressed: onRecommencer, child: const Text('Recommencer')),
      ],
    );
  }
}
