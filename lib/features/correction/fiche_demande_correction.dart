import 'package:flutter/material.dart';

import '../../core/theme/couleurs.dart';
import '../validation/outils_validation.dart';

/// Ce que le rédacteur a saisi pour demander une correction.
typedef DemandeCorrection = ({String motif, List<String> points});

/// Ouvre la fenêtre « Demander une correction » pour la leçon [titre] (D33).
/// Rend la raison et les points, ou `null` si le rédacteur annule.
Future<DemandeCorrection?> afficherDemandeCorrection(BuildContext context, {required String titre}) =>
    showDialog<DemandeCorrection>(context: context, builder: (context) => FicheDemandeCorrection(titre: titre));

/// La leçon reste en ligne pendant la correction ; on note ici ce qu'il faut
/// corriger et les points à vérifier avec les cahiers une fois le texte
/// corrigé. Tutoiement (écran des rédacteurs).
class FicheDemandeCorrection extends StatefulWidget {
  const FicheDemandeCorrection({super.key, required this.titre});

  final String titre;

  @override
  State<FicheDemandeCorrection> createState() => _FicheDemandeCorrectionState();
}

class _FicheDemandeCorrectionState extends State<FicheDemandeCorrection> {
  final _motif = TextEditingController();
  final _points = TextEditingController();
  String? _erreurMotif;
  String? _erreurPoints;

  @override
  void dispose() {
    _motif.dispose();
    _points.dispose();
    super.dispose();
  }

  void _valider() {
    final em = erreurMotif(_motif.text);
    final ep = erreurPoints(_points.text);
    if (em != null || ep != null) {
      setState(() {
        _erreurMotif = em;
        _erreurPoints = ep;
      });
      return;
    }
    Navigator.pop<DemandeCorrection>(context, (motif: _motif.text.trim(), points: decouperPoints(_points.text)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Demander une correction'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '« ${widget.titre} » reste en ligne, telle quelle, jusqu’à la publication de la correction.',
            style: const TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texteDoux),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _motif,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: longueurMaxMotif,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Ce qu’il faut corriger',
              hintText: 'Par exemple : la date du cours est fausse',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              errorText: _erreurMotif,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _points,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Points à vérifier, un par ligne',
              hintText: 'Par exemple : la date du cours est-elle le 12/11 ?',
              helperText: 'Ils seront levés avec les cahiers avant de publier la correction.',
              helperMaxLines: 3,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              errorText: _erreurPoints,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _valider, child: const Text('Demander')),
      ],
    );
  }
}
