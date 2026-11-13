import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/services/preferences.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../core/widgets/markdown_cahier.dart';
import '../../core/widgets/page_seyes.dart';
import '../../data/data.dart';

enum _Onglet { lecon, retenir }

/// Une leçon sur une page de cahier : onglets « La leçon » et « À retenir ».
class LeconScreen extends StatefulWidget {
  const LeconScreen({super.key, required this.leconId});

  final int leconId;

  @override
  State<LeconScreen> createState() => _LeconScreenState();
}

class _LeconScreenState extends State<LeconScreen> {
  Future<Lecon?>? _chargement;
  _Onglet _onglet = _Onglet.lecon;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chargement ??= _charger();
  }

  Future<Lecon?> _charger() async {
    final scope = AppScope.of(context);
    final lecon = await scope.repository.lecon(widget.leconId);
    final contexte = lecon?.contexte;
    if (lecon != null && contexte != null) {
      await scope.preferences.memoriserLecon(DerniereLecon(
        id: lecon.id,
        titre: lecon.titre,
        matiere: contexte.matiere,
        matiereSlug: contexte.matiereSlug,
        classe: contexte.classe,
      ));
    }
    return lecon;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.papier,
      body: SafeArea(
        child: FutureBuilder<Lecon?>(
          future: _chargement,
          builder: (context, instantane) {
            if (instantane.connectionState != ConnectionState.done) return const Chargement();
            if (instantane.hasError) {
              return _avecRetour(
                'Retour',
                MessageErreur(
                  erreur: instantane.error!,
                  onReessayer: () => setState(() { _chargement = _charger(); }),
                ),
              );
            }
            final lecon = instantane.data;
            if (lecon == null) {
              return _avecRetour(
                'Retour',
                const MessageVide(
                  titre: 'Leçon pas encore disponible',
                  texte: 'Cette leçon est en cours de vérification. Elle sera bientôt en ligne.',
                ),
              );
            }
            return _contenu(lecon);
          },
        ),
      ),
    );
  }

  Widget _avecRetour(String libelle, Widget enfant) => Column(
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: LienRetour(libelle: libelle)),
          Expanded(child: enfant),
        ],
      );

  Widget _contenu(Lecon lecon) {
    final c = lecon.contexte;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Couleurs.papier,
            border: Border(bottom: BorderSide(color: Couleurs.bordure)),
          ),
          child: LargeurLecture(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LienRetour(libelle: c == null ? 'Retour' : '${c.matiere}, ${c.classe}'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ControleSegmente<_Onglet>(
                      libelleGroupe: 'Contenu de la leçon',
                      options: const [(_Onglet.lecon, 'La leçon'), (_Onglet.retenir, 'À retenir')],
                      valeur: _onglet,
                      onChanged: (o) => setState(() => _onglet = o),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: LargeurLecture(
            child: PageSeyes(
              key: ValueKey(_onglet),
              child: _onglet == _Onglet.lecon ? _PageLecon(lecon: lecon) : _PageARetenir(lecon: lecon),
            ),
          ),
        ),
      ],
    );
  }
}

/// Titre cursif d'une page de leçon : deux interlignes par ligne, recalé sur
/// les lignes Seyès par [SurLigneSeyes].
final _styleTitre = Styles.cahier(taille: 23, hauteurLigne: interligne * 2);

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _TitreSection extends StatelessWidget {
  const _TitreSection(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(
          texte,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: interligne / 17),
        ),
      );
}

class _PageLecon extends StatelessWidget {
  const _PageLecon({required this.lecon});

  final Lecon lecon;

  @override
  Widget build(BuildContext context) {
    final c = lecon.contexte;
    final surTitre = [
      if (c?.partie != null) c!.partie!,
      'leçon ${lecon.numero}',
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          surTitre[0].toUpperCase() + surTitre.substring(1),
          style: const TextStyle(fontSize: 14, height: interligne / 14, color: Couleurs.texteSecondaire),
        ),
        Semantics(
          header: true,
          child: SurLigneSeyes(style: _styleTitre, child: Text(lecon.titre, style: _styleTitre)),
        ),
        if (lecon.dateCours != null)
          Text(
            'Cours du ${_date(lecon.dateCours!)}',
            style: const TextStyle(fontSize: 14, height: interligne / 14, color: Couleurs.texteSecondaire),
          ),
        if (lecon.objectifs.isNotEmpty) ...[
          const _TitreSection('Ce que tu vas apprendre'),
          for (final o in lecon.objectifs)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: Styles.lecon),
                Expanded(child: Text(o, style: Styles.lecon)),
              ],
            ),
          const SizedBox(height: interligne),
        ],
        if (lecon.introduction?.trim().isNotEmpty ?? false) ...[
          const _TitreSection('Introduction'),
          MarkdownCahier(data: lecon.introduction!, surSeyes: true),
          const SizedBox(height: interligne),
        ],
        if (lecon.corps?.trim().isNotEmpty ?? false) MarkdownCahier(data: lecon.corps!, surSeyes: true),
        const SizedBox(height: interligne),
        _BoutonExercices(lecon: lecon),
      ],
    );
  }
}

class _PageARetenir extends StatelessWidget {
  const _PageARetenir({required this.lecon});

  final Lecon lecon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: SurLigneSeyes(style: _styleTitre, child: Text('À retenir', style: _styleTitre)),
        ),
        if (lecon.aRetenir.isEmpty)
          const Text('Pas de résumé pour cette leçon.', style: Styles.lecon)
        else
          for (final r in lecon.aRetenir)
            Padding(
              padding: const EdgeInsets.only(bottom: interligne),
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.notion,
                      style: Styles.lecon.copyWith(fontWeight: FontWeight.w700, color: Couleurs.encre),
                    ),
                    Text(r.essentiel, style: Styles.lecon),
                  ],
                ),
              ),
            ),
        _BoutonExercices(lecon: lecon),
      ],
    );
  }
}

class _BoutonExercices extends StatelessWidget {
  const _BoutonExercices({required this.lecon});

  final Lecon lecon;

  @override
  Widget build(BuildContext context) {
    final n = lecon.exercices.length;
    if (n == 0) {
      return const Text('Pas encore d’exercices pour cette leçon.', style: Styles.lecon);
    }
    return FilledButton(
      onPressed: () => context.push('/lecon/${lecon.id}/exercices', extra: lecon),
      child: Text('Faire les exercices ($n)'),
    );
  }
}
