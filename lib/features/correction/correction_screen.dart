import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/couleurs.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../data/data.dart';
import '../validation/outils_validation.dart';
import 'apercu_texte.dart';
import 'reserve_redacteurs.dart';

/// Texte corrigé d'une leçon (D33), à l'adresse `/lecon/12/correction` :
/// la copie de travail de la correction en cours, affichée comme la leçon.
/// Le rédacteur la relit avant de lever les points dans « Leçons à
/// vérifier ». Rien n'y est modifiable : le texte se corrige dans
/// l'artefact.
class CorrectionScreen extends StatelessWidget {
  const CorrectionScreen({super.key, required this.leconId});

  final int leconId;

  @override
  Widget build(BuildContext context) {
    final compte = AppScope.of(context).compte;
    return Scaffold(
      backgroundColor: Couleurs.papier,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: compte,
          builder: (context, _) => compte.estConnecte
              ? _Correction(key: ValueKey(compte.email), leconId: leconId)
              : ReserveRedacteurs(connecte: false, repli: '/lecon/$leconId'),
        ),
      ),
    );
  }
}

class _Correction extends StatefulWidget {
  const _Correction({super.key, required this.leconId});

  final int leconId;

  @override
  State<_Correction> createState() => _CorrectionState();
}

/// `redacteur` faux : compte non rédacteur. `correction` nulle : aucune
/// correction en cours pour cette leçon.
typedef _Donnees = ({bool redacteur, CorrectionLecon? correction});

class _CorrectionState extends State<_Correction> {
  Future<_Donnees>? _chargement;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chargement ??= _charger();
  }

  Future<_Donnees> _charger() async {
    final redaction = AppScope.of(context).redaction;
    if (!await redaction.estRedacteur()) return (redacteur: false, correction: null);
    return (redacteur: true, correction: await redaction.correctionDe(widget.leconId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Donnees>(
      future: _chargement,
      builder: (context, instantane) {
        Widget avecRetour(Widget enfant) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: LienRetour(libelle: 'Retour', repli: '/validation'),
                ),
                Expanded(child: enfant),
              ],
            );
        if (instantane.hasError) {
          return avecRetour(MessageErreur(
            erreur: instantane.error!,
            onReessayer: () => setState(() {
              _chargement = _charger();
            }),
          ));
        }
        if (instantane.connectionState != ConnectionState.done) return avecRetour(const Chargement());
        final donnees = instantane.data!;
        if (!donnees.redacteur) return ReserveRedacteurs(connecte: true, repli: '/lecon/${widget.leconId}');
        final c = donnees.correction;
        if (c == null) {
          return avecRetour(const MessageVide(
            titre: 'Pas de correction en cours',
            texte: 'Cette leçon n’a pas de correction en cours : elle a pu être publiée ou abandonnée.',
          ));
        }
        return avecRetour(LargeurLecture(
          child: ApercuTexte(
            texte: c.texte,
            entete: EncadreApercu(
              icone: Icons.rate_review_outlined,
              lignes: [
                'Correction en cours : ${c.motif}',
                etatTexteCorrection(c),
                'Les élèves voient encore la version en ligne.',
              ],
            ),
          ),
        ));
      },
    );
  }
}
