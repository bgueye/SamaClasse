import 'package:flutter/material.dart';

import '../../core/theme/couleurs.dart';
import 'outils_validation.dart';

/// Ouvre la fenêtre « Lever ce point ». Renvoie la réponse saisie (texte,
/// éventuellement vide pour un simple constat), ou `null` si le rédacteur
/// annule.
///
/// Beaucoup de points sont des questions (« … figurent-elles dans le
/// cahier ? ») : on ne les lève pas sans dire ce qu'on a trouvé. La réponse
/// est gardée dans l'historique (D25) et affichée sous le point.
Future<String?> afficherFicheLever(BuildContext context, {required String point}) =>
    showDialog<String>(context: context, builder: (context) => FicheLever(point: point));

class FicheLever extends StatefulWidget {
  const FicheLever({super.key, required this.point});

  final String point;

  @override
  State<FicheLever> createState() => _FicheLeverState();
}

class _FicheLeverState extends State<FicheLever> {
  final _champ = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  void _lever() {
    final erreur = erreurReponse(widget.point, _champ.text);
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }
    Navigator.pop<String>(context, _champ.text);
  }

  @override
  Widget build(BuildContext context) {
    final question = estQuestion(widget.point);
    return AlertDialog(
      title: const Text('Lever ce point'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Le point lui-même, pour répondre sans revenir en arrière.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Couleurs.selection, borderRadius: BorderRadius.circular(10)),
            child: Text(widget.point, style: const TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texte)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _champ,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: longueurMaxReponse,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: question ? 'Ta réponse (obligatoire)' : 'Ta réponse (facultative)',
              hintText: question
                  ? 'Ce que tu as trouvé dans le cahier, et ce que tu as corrigé'
                  : 'Par exemple : conforme au cahier, page 12',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              errorText: _erreur,
              errorMaxLines: 3,
            ),
          ),
          if (question)
            const Text(
              'Si la réponse oblige à corriger la leçon, corrige d’abord l’artefact, puis lève le point.',
              style: TextStyle(fontSize: 13, height: 1.4, color: Couleurs.texteSecondaire),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _lever, child: const Text('Lever le point')),
      ],
    );
  }
}
