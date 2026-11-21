// « Signaler une erreur » (D35, D38, maquette `Signaler`) : fenêtre qui
// monte du bas de l'écran, ouverte depuis une leçon ou un exercice.
//
// Ouverte à tous, sans compte. Quatre états dans la fenêtre : le formulaire,
// l'envoi en cours (bouton désactivé, indicateur), l'erreur (message sous le
// bouton, le formulaire reste rempli pour réessayer) et « Merci, c’est
// envoyé ». Sans réseau, rien n'est gardé pour plus tard (D38).

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/couleurs.dart';
import '../../data/data.dart';

/// Bouton discret « Signaler une erreur », sous une leçon ou un exercice.
///
/// [exercice] et [numeroExercice] : vides pour un signalement sur la leçon.
class BoutonSignaler extends StatelessWidget {
  const BoutonSignaler({super.key, required this.lecon, this.exercice, this.numeroExercice});

  final Lecon lecon;
  final Exercice? exercice;

  /// Numéro affiché à l'élève (« Exercice 4 »), qui peut différer de
  /// `exercice.ordre`.
  final int? numeroExercice;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => afficherSignalement(context, lecon: lecon, exercice: exercice, numeroExercice: numeroExercice),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Signaler une erreur'),
        ),
      );
}

/// Ouvre la fenêtre « Signaler une erreur » sur [lecon], ou sur son
/// [exercice] s'il est donné.
Future<void> afficherSignalement(
  BuildContext context, {
  required Lecon lecon,
  Exercice? exercice,
  int? numeroExercice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Couleurs.papier,
    builder: (context) => FenetreSignalement(lecon: lecon, exercice: exercice, numeroExercice: numeroExercice),
  );
}

/// Sous-titre de la fenêtre : « Exercice 4 · L'Afrique au XVIe siècle » ou
/// « Leçon · L'Afrique au XVIe siècle ».
String sousTitreSignalement(Lecon lecon, {int? numeroExercice}) =>
    '${numeroExercice == null ? 'Leçon' : 'Exercice $numeroExercice'} · ${lecon.titre}';

class FenetreSignalement extends StatefulWidget {
  const FenetreSignalement({super.key, required this.lecon, this.exercice, this.numeroExercice});

  final Lecon lecon;
  final Exercice? exercice;
  final int? numeroExercice;

  @override
  State<FenetreSignalement> createState() => _FenetreSignalementState();
}

class _FenetreSignalementState extends State<FenetreSignalement> {
  final _precision = TextEditingController();
  MotifSignalement? _motif;
  bool _envoi = false;
  bool _envoye = false;
  String? _erreur;

  @override
  void dispose() {
    _precision.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final motif = _motif;
    if (motif == null || _envoi) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await AppScope.of(context).signalement.signaler(
            leconId: widget.lecon.id,
            exerciceId: widget.exercice?.id,
            motif: motif,
            precision: nettoyerPrecision(_precision.text),
          );
      if (mounted) setState(() => _envoye = true);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreurSignalement(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        // Le clavier ne doit pas cacher le champ ni le bouton.
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: _envoye ? _merci() : _formulaire(),
      ),
    );
  }

  Widget _titre(String texte) => Semantics(
        header: true,
        child: Text(texte, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Couleurs.texte)),
      );

  Widget _formulaire() {
    final motifs = motifsProposes(pourExercice: widget.exercice != null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titre('Signaler une erreur'),
        const SizedBox(height: 4),
        Text(
          sousTitreSignalement(widget.lecon, numeroExercice: widget.numeroExercice),
          style: const TextStyle(fontSize: 14, color: Couleurs.texteDoux),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: const Text(
            'Qu’est-ce qui ne va pas ?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Couleurs.texte),
          ),
        ),
        RadioGroup<MotifSignalement>(
          groupValue: _motif,
          onChanged: (m) {
            if (!_envoi) setState(() => _motif = m);
          },
          child: Column(
            children: [
              for (final m in motifs)
                RadioListTile<MotifSignalement>(
                  value: m,
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.libelle, style: const TextStyle(fontSize: 16, color: Couleurs.texte)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _precision,
          enabled: !_envoi,
          minLines: 2,
          maxLines: 4,
          maxLength: longueurMaxPrecision,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Précise si tu veux',
            hintText: 'Par exemple : dans mon cahier, c’est écrit…',
            // Texte d'un enfant, lu par les rédacteurs (D38).
            helperText: 'N’écris pas ton nom ni ton numéro.',
            helperMaxLines: 2,
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          // Désactivé tant qu'aucun motif n'est choisi, et pendant l'envoi.
          onPressed: _motif == null || _envoi ? null : _envoyer,
          child: _envoi
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
                    SizedBox(width: 12),
                    Text('Envoi…'),
                  ],
                )
              : const Text('Envoyer'),
        ),
        if (_motif == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Choisis d’abord ce qui ne va pas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Couleurs.texteSecondaire),
            ),
          ),
        if (_erreur != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône en plus de la couleur (DESIGN.md).
                  const Icon(Icons.error_outline_rounded, color: Couleurs.faux, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_erreur!, style: const TextStyle(fontSize: 14, height: 1.4, color: Couleurs.fauxTexte)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _merci() {
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Couleurs.justeFond,
              child: Icon(Icons.check_rounded, color: Couleurs.juste, size: 30),
            ),
          ),
          const SizedBox(height: 12),
          _titre('Merci, c’est envoyé'),
          const SizedBox(height: 8),
          const Text(
            'Un rédacteur va vérifier. Si l’erreur est confirmée, la leçon sera corrigée pour tout le monde.',
            style: TextStyle(fontSize: 16, height: 1.5, color: Couleurs.texte),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.exercice == null ? 'Revenir à la leçon' : 'Revenir à l’exercice'),
          ),
        ],
      ),
    );
  }
}
