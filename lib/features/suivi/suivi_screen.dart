import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/services/moteur_vocal.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/matieres.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../data/data.dart';
import '../revision/outils_cartes.dart' show questionParent;
import 'statistiques.dart';

/// « Suivi de mes enfants » (phase 3, maquette `Parent`), à l'adresse
/// `/suivi`. Pour chaque enfant : l'activité de la semaine, les derniers
/// exercices et les leçons disponibles dans sa classe.
///
/// Parents seulement (vouvoiement). Sans connexion, renvoie vers l'espace
/// parents. Lecture seule : rien ne se modifie ici.
class SuiviScreen extends StatelessWidget {
  const SuiviScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compte = AppScope.of(context).compte;
    return Scaffold(
      body: SafeArea(
        child: LargeurLecture(
          child: ListenableBuilder(
            listenable: compte,
            builder: (context, _) => compte.estConnecte
                ? _SuiviConnecte(key: ValueKey(compte.email))
                : const _NonConnecte(),
          ),
        ),
      ),
    );
  }
}

/// Adresse ouverte sans être connecté (lien web, déconnexion ailleurs).
class _NonConnecte extends StatelessWidget {
  const _NonConnecte();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: LienRetour(libelle: 'Mes cours'),
        ),
        Expanded(
          child: MessageVide(
            titre: 'Connectez-vous pour voir le suivi',
            texte: 'Le suivi de vos enfants se trouve dans l’espace parents.',
            action: FilledButton(
              onPressed: () => context.go('/compte'),
              child: const Text('Aller à l’espace parents'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tout ce que l'écran affiche, chargé d'un coup.
typedef _DonneesSuivi = ({
  List<Enfant> enfants,
  List<LectureLecon> lectures,
  List<ResultatExercice> resultats,
  List<Classe> classes,
  List<Lecon> lecons,
});

class _SuiviConnecte extends StatefulWidget {
  const _SuiviConnecte({super.key});

  @override
  State<_SuiviConnecte> createState() => _SuiviConnecteState();
}

class _SuiviConnecteState extends State<_SuiviConnecte> {
  late AppScope _scope;
  Future<_DonneesSuivi>? _chargement;

  /// Enfant affiché ; au départ, celui de ce téléphone s'il y en a un.
  int? _enfantId;

  /// Compte rédacteur : le crayon « Leçons à vérifier » s'affiche (phase 4).
  bool _redacteur = false;

  /// « Écouter le résumé » (D35) : moteur créé au premier appui, arrêté en
  /// quittant l'écran ou quand un autre écran passe par-dessus.
  MoteurVocal? _moteur;
  bool _parle = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    _chargement ??= _charger();
    if (!(ModalRoute.isCurrentOf(context) ?? true)) _arreterLecture();
  }

  @override
  void dispose() {
    _moteur?.arreter().ignore();
    super.dispose();
  }

  void _arreterLecture() {
    if (!_parle) return;
    _moteur?.arreter().ignore();
    if (mounted) setState(() => _parle = false);
  }

  /// Lit [texte] avec la voix française ; un second appui arrête.
  Future<void> _ecouter(String texte) async {
    if (_parle) return _arreterLecture();
    final moteur = _moteur ??= _scope.creerMoteurVocal();
    setState(() => _parle = true);
    try {
      await moteur.preparer(vitesse: 0.45);
      await moteur.choisirLangue('fr-FR');
      await moteur.dire(texte);
    } catch (_) {
      // Pas de voix : rien de grave, le résumé reste écrit.
    }
    if (mounted) setState(() => _parle = false);
  }

  Future<void> _envoyer(String texte) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await _scope.partage.envoyer(texte, sujet: 'Résumé de la semaine');
    } catch (_) {
      messager.showSnackBar(const SnackBar(content: Text('L’envoi n’a pas marché. Réessayez dans un instant.')));
    }
  }

  Future<_DonneesSuivi> _charger() async {
    // D'abord, ce qui attend sur ce téléphone (exercices faits hors
    // connexion) : le parent voit alors des chiffres à jour. Sans réseau,
    // l'envoi échoue en silence et le chargement ci-dessous dira l'erreur.
    await _scope.suivi.envoyer();
    final (enfants, lectures, resultats, classes, lecons, actif) = await (
      _scope.compte.enfants(),
      _scope.compte.lectures(),
      _scope.compte.resultats(),
      _scope.repository.classes(),
      _scope.repository.lecons(),
      _scope.preferences.enfantActif(),
    ).wait;
    // Sans réseau ou en cas d'erreur, pas de crayon : rien de grave.
    _redacteur = await _scope.redaction.estRedacteur().catchError((Object _) => false);
    if (_enfantId == null || !enfants.any((e) => e.id == _enfantId)) {
      _enfantId = enfants.any((e) => e.id == actif?.id) ? actif!.id : enfants.firstOrNull?.id;
    }
    return (enfants: enfants, lectures: lectures, resultats: resultats, classes: classes, lecons: lecons);
  }

  void _recharger() => setState(() { _chargement = _charger(); });

  Future<void> _actualiser() async {
    final suite = _charger();
    setState(() { _chargement = suite; });
    await suite.then((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DonneesSuivi>(
      future: _chargement,
      builder: (context, instantane) {
        final entete = <Widget>[
          const LienRetour(libelle: 'Espace parents', repli: '/compte'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: const Text(
                      'Suivi de mes enfants',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Couleurs.texte),
                    ),
                  ),
                ),
                // Rédacteurs seulement (maquette `Parent`).
                if (_redacteur)
                  IconButton.outlined(
                    onPressed: () => context.push('/validation'),
                    tooltip: 'Leçons à vérifier',
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
          ),
        ];
        if (instantane.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(12, 8, 24, 0), child: Column(children: entete)),
              Expanded(child: MessageErreur(erreur: instantane.error!, onReessayer: _recharger)),
            ],
          );
        }
        if (!instantane.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(12, 8, 24, 0), child: Column(children: entete)),
              const Expanded(child: Chargement()),
            ],
          );
        }
        final donnees = instantane.data!;
        return RefreshIndicator(
          onRefresh: _actualiser,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
            children: [
              ...entete,
              const SizedBox(height: 16),
              if (donnees.enfants.isEmpty)
                MessageVide(
                  titre: 'Aucun profil pour l’instant',
                  texte: 'Ajoutez le profil de votre enfant dans l’espace parents pour suivre son travail.',
                  action: FilledButton(
                    onPressed: () => context.go('/compte'),
                    child: const Text('Ajouter un enfant'),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _contenu(donnees),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _contenu(_DonneesSuivi d) {
    final enfant = d.enfants.firstWhere((e) => e.id == _enfantId, orElse: () => d.enfants.first);
    final libelles = {for (final c in d.classes) c.id: c.libelle};
    final classe = libelles[enfant.classeId] ?? 'sa classe';
    final bilan = bilanSemaine(
      enfantId: enfant.id,
      lectures: d.lectures,
      resultats: d.resultats,
      maintenant: DateTime.now(),
    );
    final derniers = derniersExercices(enfantId: enfant.id, resultats: d.resultats, lecons: d.lecons);
    final aReciter = derniereLeconARetenir(enfantId: enfant.id, lectures: d.lectures, lecons: d.lecons);
    final disponibles = leconsDeClasse(d.lecons, classe);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.enfants.length > 1) ...[
          _ChoixEnfant(
            enfants: d.enfants,
            classes: libelles,
            choisi: enfant.id,
            onChoisir: (id) => setState(() => _enfantId = id),
          ),
          const SizedBox(height: 24),
        ] else ...[
          // Un seul enfant : pas de choix à faire, son nom suffit.
          Text('${enfant.prenom}, $classe', style: Styles.cahier(taille: 20)),
          const SizedBox(height: 20),
        ],
        _ResumeSemaine(
          bilan: bilan,
          parle: _parle,
          onEcouter: () => _ecouter(texteResume(enfant.prenom, bilan)),
          onEnvoyer: () => _envoyer('${texteResume(enfant.prenom, bilan)} (SamaClasse)'),
        ),
        const SizedBox(height: 26),
        // « Que lui demander ce soir ? » (D35) : seulement s'il a lu une
        // leçon qui a des notions à réciter.
        if (aReciter != null) ...[
          _ACeSoir(prenom: enfant.prenom, lecon: aReciter),
          const SizedBox(height: 26),
        ],
        const _TitreSection('Derniers exercices'),
        if (derniers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucun exercice pour l’instant. Les exercices faits avec le profil de l’enfant apparaîtront ici.',
              style: TextStyle(fontSize: 15, height: 1.4, color: Couleurs.texteDoux),
            ),
          )
        else
          for (final x in derniers) _LigneExercice(fait: x),
        const SizedBox(height: 26),
        _TitreSection('Leçons disponibles en $classe'),
        Text(resumeDisponibles(disponibles), style: const TextStyle(fontSize: 14, color: Couleurs.texteDoux)),
        const SizedBox(height: 6),
        for (final l in disponibles) _LigneLecon(lecon: l),
      ],
    );
  }
}

class _TitreSection extends StatelessWidget {
  const _TitreSection(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(header: true, child: Text(texte, style: Styles.sectionTitre)),
      );
}

/// Un bouton par enfant (prénom et classe), deux par ligne comme sur la
/// maquette ; l'enfant affiché est en bleu encre, et annoncé « sélectionné »
/// aux lecteurs d'écran.
class _ChoixEnfant extends StatelessWidget {
  const _ChoixEnfant({
    required this.enfants,
    required this.classes,
    required this.choisi,
    required this.onChoisir,
  });

  final List<Enfant> enfants;
  final Map<int, String> classes;
  final int choisi;
  final ValueChanged<int> onChoisir;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Choisir l’enfant',
      child: LayoutBuilder(
        builder: (context, contraintes) {
          const ecart = 10.0;
          final largeur = (contraintes.maxWidth - ecart) / 2;
          return Wrap(
            spacing: ecart,
            runSpacing: ecart,
            children: [
              for (final e in enfants)
                SizedBox(
                  width: largeur,
                  child: _BoutonEnfant(
                    prenom: e.prenom,
                    classe: classes[e.classeId] ?? '',
                    choisi: e.id == choisi,
                    onTap: () => onChoisir(e.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BoutonEnfant extends StatelessWidget {
  const _BoutonEnfant({required this.prenom, required this.classe, required this.choisi, required this.onTap});

  final String prenom;
  final String classe;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texte = choisi ? Couleurs.texteSurEncre : Couleurs.texte;
    return Semantics(
      selected: choisi,
      button: true,
      child: Material(
        color: choisi ? Couleurs.encre : Couleurs.papier,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: choisi ? Couleurs.encre : Couleurs.bordureForte, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(prenom, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: texte)),
                  const SizedBox(height: 2),
                  Text(classe, style: TextStyle(fontSize: 13, color: texte)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les trois chiffres de la semaine, dans un cadre blanc.
class _LigneExercice extends StatelessWidget {
  const _LigneExercice({required this.fait});

  final ExerciceFait fait;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Couleurs.bordure))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: LayoutBuilder(
            builder: (context, contraintes) {
              // Score en mots, pas en couleur seule.
              final score = Text(
                libelleScore(fait.resultat),
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
              );
              // Texte très agrandi : le score passe sous le type, pour que
              // le titre de la leçon garde toute la largeur.
              final dessous = contraintes.maxWidth < MediaQuery.textScalerOf(context).scale(330);
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fait.lecon.titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
                  const SizedBox(height: 2),
                  Text(fait.exercice.type.libelle, style: Styles.secondaire),
                  if (dessous) ...[const SizedBox(height: 4), score],
                ],
              );
              return Row(
                children: [
                  DosCahier(couleur: couleurMatiere(fait.lecon.contexte?.matiereSlug), largeur: 6, hauteur: 32),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: details),
                  if (!dessous) ...[
                    const SizedBox(width: 12),
                    // Colonne de largeur fixe : tous les scores alignés à droite.
                    Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: score)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Encart « Que lui demander ce soir ? » : la dernière leçon lue et le
/// bouton qui ouvre les cartes en mode parent.
class _ACeSoir extends StatelessWidget {
  const _ACeSoir({required this.prenom, required this.lecon});

  final String prenom;
  final Lecon lecon;

  @override
  Widget build(BuildContext context) {
    final matiere = lecon.contexte?.matiere;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Couleurs.papier,
        border: Border.all(color: Couleurs.bordureCarte, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: const Text(
                'Que lui demander ce soir ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Couleurs.texte),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dernière leçon lue par $prenom : ${lecon.titre}${matiere == null ? '' : ' (${matiere.toLowerCase()})'}.',
              style: const TextStyle(fontSize: 15, height: 1.4, color: Couleurs.texteDoux),
            ),
            const SizedBox(height: 10),
            // Les premières questions, pour commencer tout de suite.
            for (final n in lecon.aRetenir.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Couleurs.fond, borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(questionParent(n.notion), style: const TextStyle(fontSize: 16, height: 1.4, color: Couleurs.texte)),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: () => context.push('/lecon/${lecon.id}/reviser?mode=parent'),
              icon: const Icon(Icons.record_voice_over_outlined),
              label: Text('Faire réciter $prenom'),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Cette semaine » en trois lignes à grosse icône (D35, maquette
/// `ResumeParent`) : des phrases plutôt que des chiffres seuls, lisibles par
/// un parent qui ne connaît pas l'application. Puis « Écouter le résumé » et
/// « Envoyer ce résumé ».
class _ResumeSemaine extends StatelessWidget {
  const _ResumeSemaine({
    required this.bilan,
    required this.parle,
    required this.onEcouter,
    required this.onEnvoyer,
  });

  final BilanSemaine bilan;
  final bool parle;
  final VoidCallback onEcouter;
  final VoidCallback onEnvoyer;

  @override
  Widget build(BuildContext context) {
    final lignes = [
      (Icons.menu_book_outlined, Couleurs.selection, Couleurs.encre, phraseLecons(bilan)),
      // Icône neutre : une coche verte annoncerait une réussite, même pour
      // « n'a pas encore fait d'exercice » ou « 2 sur 10 ».
      (Icons.edit_outlined, Couleurs.selection, Couleurs.encre, phraseExercices(bilan)),
      (Icons.calendar_month_outlined, Couleurs.fond, Couleurs.texte, phraseJours(bilan)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _TitreSection('Cette semaine')),
            IconButton.outlined(
              tooltip: parle ? 'Arrêter la lecture' : 'Écouter le résumé',
              onPressed: onEcouter,
              icon: Icon(parle ? Icons.stop_rounded : Icons.volume_up_outlined),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Couleurs.papier,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Couleurs.bordureCarte, width: 1.5),
          ),
          child: Column(
            children: [
              for (final (i, (icone, fond, couleur, phrase)) in lignes.indexed) ...[
                if (i > 0) const Divider(height: 1, thickness: 1, color: Couleurs.bordure),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Décor : la phrase dit tout.
                      ExcludeSemantics(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: fond,
                            shape: BoxShape.circle,
                            border: Border.all(color: Couleurs.bordureCarte),
                          ),
                          child: Icon(icone, color: couleur, size: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          majuscule(phrase),
                          style: const TextStyle(fontSize: 17, height: 1.35, color: Couleurs.texte),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onEnvoyer,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Envoyer ce résumé'),
        ),
      ],
    );
  }
}

class _LigneLecon extends StatelessWidget {
  const _LigneLecon({required this.lecon});

  final Lecon lecon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Couleurs.bordure))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              DosCahier(couleur: couleurMatiere(lecon.contexte?.matiereSlug), largeur: 6, hauteur: 32),
              const SizedBox(width: 14),
              Expanded(child: Text(lecon.titre, style: const TextStyle(fontSize: 15, height: 1.3))),
              const SizedBox(width: 12),
              Text(libelleExercices(lecon.exercices.length), style: Styles.secondaire),
            ],
          ),
        ),
      ),
    );
  }
}
