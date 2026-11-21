import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../core/widgets/markdown_cahier.dart';
import '../../data/data.dart';
import '../signalement/fiche_signalement.dart';
import 'outils_exercices.dart';
import 'saisies/saisie_exercice.dart';

/// Exercices d'une leçon, un par écran, avec correction immédiate.
class ExercicesScreen extends StatefulWidget {
  const ExercicesScreen({super.key, required this.leconId, this.lecon});

  final int leconId;

  /// Leçon déjà chargée (passée par l'écran de leçon) ; sinon on la recharge.
  final Lecon? lecon;

  @override
  State<ExercicesScreen> createState() => _ExercicesScreenState();
}

class _ExercicesScreenState extends State<ExercicesScreen> {
  Future<Lecon?>? _chargement;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chargement ??= widget.lecon != null
        ? Future.value(widget.lecon)
        : AppScope.of(context).repository.lecon(widget.leconId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Lecon?>(
          future: _chargement,
          builder: (context, instantane) {
            if (instantane.connectionState != ConnectionState.done) return const Chargement();
            final retour = Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: LienRetour(libelle: 'La leçon', repli: '/lecon/${widget.leconId}'),
            );
            if (instantane.hasError) {
              return Column(children: [
                retour,
                Expanded(
                  child: MessageErreur(
                    erreur: instantane.error!,
                    onReessayer: () => setState(() {
                      _chargement = AppScope.of(context).repository.lecon(widget.leconId);
                    }),
                  ),
                ),
              ]);
            }
            final lecon = instantane.data;
            if (lecon == null || lecon.exercices.isEmpty) {
              return Column(children: [
                retour,
                const Expanded(
                  child: MessageVide(
                    titre: 'Pas d’exercices',
                    texte: 'Cette leçon n’a pas encore d’exercices disponibles.',
                  ),
                ),
              ]);
            }
            return LargeurLecture(child: _SerieExercices(lecon: lecon));
          },
        ),
      ),
    );
  }
}

/// Résultat d'un exercice pour le bilan final.
enum _Bilan { reussi, rate, aComparer }

class _SerieExercices extends StatefulWidget {
  const _SerieExercices({required this.lecon});

  final Lecon lecon;

  @override
  State<_SerieExercices> createState() => _SerieExercicesState();
}

class _SerieExercicesState extends State<_SerieExercices> {
  int _index = 0;
  bool _termine = false;

  /// Change à chaque « Recommencer » pour vider les champs de saisie.
  int _tentative = 0;
  final _reponses = <int, Object?>{};
  final _corrections = <int, Correction>{};

  /// Pour les exercices corrigés par l'élève lui-même : « j'avais juste ».
  final _autoEvaluations = <int, bool>{};

  /// Exercices déjà notés pour le suivi pendant cette tentative : un retour
  /// en arrière (« Précédent ») ne note pas deux fois le même exercice.
  final _notes = <int>{};

  /// Exercices dont l'indice est ouvert pendant cette tentative (D39). Rien
  /// n'est noté pour le suivi : l'indice est une aide, sans pénalité.
  final _indicesVus = <int>{};

  final _defilement = ScrollController();

  List<Exercice> get _exercices => widget.lecon.exercices;
  Exercice get _courant => _exercices[_index];

  @override
  void dispose() {
    // Quitter l'écran après « Avais-tu juste ? » sans passer à la suite :
    // le résultat est quand même noté.
    if (!_termine) _noter(_courant);
    _defilement.dispose();
    super.dispose();
  }

  /// Note le résultat de [e] pour le suivi des parents (phase 3, D24), une
  /// seule fois par tentative. Le service ne note rien sans profil enfant ni
  /// parent connecté, et rien du tout s'il n'y a pas encore de résultat
  /// (exercice à comparer sans réponse à « Avais-tu juste ? »).
  void _noter(Exercice e) {
    final correction = _corrections[e.id];
    if (correction == null || _notes.contains(e.id)) return;
    if (correction is! CorrectionAuto && _autoEvaluations[e.id] == null) return;
    // Validé sans rien remplir : rien à apprendre au parent, on ne note pas
    // (décision de Bocar du 15/11/2026). Les questions de cours, elles, ne
    // comptent que par « Avais-tu juste ? » (réponse possible sur le cahier).
    if (correction is CorrectionAuto && reponseVide(_reponse(e))) return;
    _notes.add(e.id);
    _suivi.noterResultat(exerciceId: e.id, correction: correction, autoEvaluation: _autoEvaluations[e.id]).ignore();
  }

  late SuiviResultats _suivi;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Gardé ici : `dispose` ne peut plus lire AppScope.
    _suivi = AppScope.of(context).suivi;
  }

  Object? _reponse(Exercice e) => _reponses.putIfAbsent(e.id, () => reponseInitiale(e));

  void _valider() {
    final e = _courant;
    setState(() => _corrections[e.id] = corriger(e, _reponse(e)));
    // Exercice corrigé par l'application : le résultat est connu tout de suite.
    _noter(e);
  }

  void _aller(int index) {
    // En quittant un exercice à comparer, « Avais-tu juste ? » est répondu.
    _noter(_courant);
    setState(() {
      if (index >= _exercices.length) {
        _termine = true;
      } else {
        _index = index;
      }
    });
    if (_defilement.hasClients) _defilement.jumpTo(0);
  }

  void _recommencer() {
    setState(() {
      _index = 0;
      _termine = false;
      _tentative++;
      _reponses.clear();
      _corrections.clear();
      _autoEvaluations.clear();
      _notes.clear(); // nouvelle tentative : nouveaux résultats
      _indicesVus.clear(); // les indices se referment
    });
  }

  _Bilan? _bilan(Exercice e) {
    final c = _corrections[e.id];
    return switch (c) {
      null => null,
      CorrectionAuto(:final toutJuste) => toutJuste ? _Bilan.reussi : _Bilan.rate,
      _ => switch (_autoEvaluations[e.id]) {
          true => _Bilan.reussi,
          false => _Bilan.rate,
          null => _Bilan.aComparer,
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _entete(),
        Expanded(child: _termine ? _resultat() : _exercice()),
      ],
    );
  }

  Widget _entete() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: LienRetour(libelle: 'La leçon', repli: '/lecon/${widget.lecon.id}')),
              // Flexible : avec un texte système à 200 %, le compteur passe sur
              // deux lignes au lieu de faire déborder la rangée (390 px).
              Flexible(
                child: Text(
                  _termine ? 'Terminé' : 'Exercice ${_index + 1} sur ${_exercices.length}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.texteSecondaire),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  for (final (i, e) in _exercices.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: switch (_bilan(e)) {
                            _Bilan.reussi => Couleurs.juste,
                            _Bilan.rate => Couleurs.faux,
                            _Bilan.aComparer => Couleurs.texteAttente,
                            null => !_termine && i == _index ? Couleurs.encre : Couleurs.bordureCarte,
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exercice() {
    final e = _courant;
    final correction = _corrections[e.id];
    final dernier = _index == _exercices.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            controller: _defilement,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Text('${e.niveau.libelle} · ${e.type.libelle}', style: Styles.etiquette),
              const SizedBox(height: 8),
              MarkdownCahier(data: e.enonce),
              const SizedBox(height: 20),
              SaisieExercice(
                key: ValueKey('saisie-${e.id}-$_tentative'),
                exercice: e,
                reponse: _reponse(e),
                correction: correction,
                onChanged: (valeur) => setState(() => _reponses[e.id] = valeur),
              ),
              // « Voir un indice » (D39) : seulement si l'exercice en a un, et
              // avant la correction. Une fois ouvert, l'indice reste affiché.
              if (e.indice != null) ...[
                if (_indicesVus.contains(e.id)) ...[
                  const SizedBox(height: 12),
                  _EncadreIndice(texte: e.indice!),
                ] else if (correction == null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _indicesVus.add(e.id)),
                      icon: const Icon(Icons.lightbulb_outline_rounded),
                      label: const Text('Voir un indice'),
                    ),
                  ),
                ],
              ],
              if (correction != null) ...[
                const SizedBox(height: 8),
                _RetourCorrection(
                  correction: correction,
                  corrige: e.corrige,
                  autoEvaluation: _autoEvaluations[e.id],
                  onAutoEvaluation: (juste) => setState(() => _autoEvaluations[e.id] = juste),
                ),
              ],
              // Pour tous, même sans compte (D38) : énoncé, saisie ou corrigé.
              const SizedBox(height: 16),
              BoutonSignaler(lecon: widget.lecon, exercice: e, numeroExercice: _index + 1),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Couleurs.fond,
            border: Border(top: BorderSide(color: Couleurs.bordure)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                if (_index > 0) ...[
                  OutlinedButton(onPressed: () => _aller(_index - 1), child: const Text('Précédent')),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: correction == null
                      ? FilledButton(
                          onPressed: _valider,
                          child: Text(estAutoCorrigeable(e) ? 'Valider' : 'Voir le corrigé'),
                        )
                      : FilledButton(
                          onPressed: () => _aller(_index + 1),
                          child: Text(dernier ? 'Voir mon résultat' : 'Exercice suivant'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultat() {
    final bilans = [for (final e in _exercices) _bilan(e)];
    final reussis = bilans.where((b) => b == _Bilan.reussi).length;
    final total = _exercices.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      children: [
        Text('Exercices terminés', style: Styles.cahier(taille: 20)),
        const SizedBox(height: 12),
        Semantics(
          label: '$reussis exercices réussis sur $total',
          excludeSemantics: true,
          child: Text(
            '$reussis sur $total',
            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700, height: 1, letterSpacing: -1),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          reussis == total
              ? 'Tout est juste. Tu peux passer à la leçon suivante.'
              : 'Relis la partie de la leçon qui correspond aux exercices manqués, puis recommence.',
          style: const TextStyle(fontSize: 17, height: 1.5, color: Couleurs.texteDoux),
        ),
        const SizedBox(height: 24),
        for (final (i, e) in _exercices.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              switch (bilans[i]) {
                _Bilan.reussi => Icons.check_circle_rounded,
                _Bilan.rate => Icons.cancel_rounded,
                _ => Icons.help_outline_rounded,
              },
              color: switch (bilans[i]) {
                _Bilan.reussi => Couleurs.juste,
                _Bilan.rate => Couleurs.faux,
                _ => Couleurs.texteSecondaire,
              },
            ),
            title: Text('Exercice ${i + 1} · ${e.type.libelle}'),
            subtitle: Text(_detailBilan(e, bilans[i])),
            onTap: () {
              setState(() => _termine = false);
              _aller(i);
            },
          ),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: _recommencer, child: const Text('Recommencer')),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/lecon/${widget.lecon.id}'),
          child: const Text('Revoir la leçon'),
        ),
      ],
    );
  }

  String _detailBilan(Exercice e, _Bilan? bilan) {
    final c = _corrections[e.id];
    if (c is CorrectionAuto) return '${c.bonnes} sur ${c.total}';
    return switch (bilan) {
      _Bilan.reussi => 'Juste, d’après toi',
      _Bilan.rate => 'À revoir, d’après toi',
      _Bilan.aComparer => 'Compare ta réponse avec le corrigé',
      null => 'Pas fait',
    };
  }
}

class _RetourCorrection extends StatelessWidget {
  const _RetourCorrection({
    required this.correction,
    required this.corrige,
    required this.autoEvaluation,
    required this.onAutoEvaluation,
  });

  final Correction correction;

  /// Corrigé rédigé (Markdown), affiché aussi après une correction automatique :
  /// il contient souvent la justification attendue.
  final String? corrige;
  final bool? autoEvaluation;
  final ValueChanged<bool> onAutoEvaluation;

  @override
  Widget build(BuildContext context) {
    return switch (correction) {
      // Variable de motif déclarée `final` (lint prefer_final_locals).
      final CorrectionAuto c => _Encadre(
          juste: c.toutJuste,
          titre: c.toutJuste
              ? 'Tout est juste !'
              : '${c.bonnes} bonne${c.bonnes > 1 ? 's' : ''} réponse${c.bonnes > 1 ? 's' : ''} sur ${c.total}',
          contenu: corrige == null || corrige!.trim().isEmpty ? null : MarkdownCahier(data: corrige!),
        ),
      CorrectionManuelle() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Encadre(
              juste: null,
              titre: 'Compare avec le corrigé',
              contenu: corrige == null
                  ? const Text(
                      'Pas de corrigé pour cet exercice : montre ta réponse à ton professeur ou à tes parents.',
                      style: TextStyle(fontSize: 16, height: 1.5),
                    )
                  : MarkdownCahier(data: corrige!),
            ),
            const SizedBox(height: 12),
            const Text('Avais-tu juste ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Oui, j’avais juste'),
                  selected: autoEvaluation == true,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => onAutoEvaluation(true),
                ),
                ChoiceChip(
                  label: const Text('Non, je me suis trompé'),
                  selected: autoEvaluation == false,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => onAutoEvaluation(false),
                ),
              ],
            ),
          ],
        ),
      ReponseInvalide(:final raison) => _Encadre(juste: false, titre: 'Réponse incomplète', contenu: Text(raison)),
    };
  }
}

/// Encadré « Indice » (D39, maquette `Indice`) : fond bleu pâle, ampoule et
/// titre à l'encre, annoncé aux lecteurs d'écran quand il apparaît.
class _EncadreIndice extends StatelessWidget {
  const _EncadreIndice({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Couleurs.selection, borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.lightbulb_outline_rounded, color: Couleurs.encre),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Indice', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Couleurs.encre)),
                    const SizedBox(height: 4),
                    MarkdownCahier(data: texte),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Encadre extends StatelessWidget {
  const _Encadre({required this.juste, required this.titre, this.contenu});

  /// `null` : neutre (correction manuelle).
  final bool? juste;
  final String titre;
  final Widget? contenu;

  @override
  Widget build(BuildContext context) {
    final (fond, texte, icone) = switch (juste) {
      true => (Couleurs.justeFond, Couleurs.justeTexte, Icons.check_rounded),
      false => (Couleurs.fauxFond, Couleurs.fauxTexte, Icons.close_rounded),
      null => (Couleurs.selection, Couleurs.texte, Icons.menu_book_rounded),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: texte),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icone, color: texte),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(titre, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: texte)),
                    ),
                  ],
                ),
                if (contenu != null) ...[const SizedBox(height: 10), contenu!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
