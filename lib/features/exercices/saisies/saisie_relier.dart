import 'package:flutter/material.dart';

import '../../../core/theme/couleurs.dart';
import '../../../data/data.dart';
import 'commun.dart';

/// Relier : pour chaque élément de gauche, l'élève choisit un élément de droite.
class SaisieRelier extends StatelessWidget {
  const SaisieRelier({
    super.key,
    required this.exercice,
    required this.reponse,
    required this.onChanged,
    required this.details,
  });

  final Exercice exercice;
  final Map<String, String> reponse;
  final ValueChanged<Object?> onChanged;
  final List<bool>? details;

  @override
  Widget build(BuildContext context) {
    final attendu = exercice.reponse as Map;
    final donnees = exercice.donnees;
    final gauche = ordreGauche(attendu, donnees);
    final droite = donnees is Map && donnees['droite'] is List
        ? List<String>.from(donnees['droite'] as List)
        : attendu.values.cast<String>().toList();
    final corrige = details != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, g) in gauche.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(g, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4)),
                const SizedBox(height: 8),
                _Selecteur(
                  element: g,
                  valeur: reponse[g],
                  options: droite,
                  actif: !corrige,
                  onChoix: (choix) => onChanged({...reponse, g: choix}),
                ),
                if (detail(details, i) != null)
                  RetourChamp(juste: detail(details, i)!, attendu: attendu[g] as String?),
              ],
            ),
          ),
      ],
    );
  }
}

class _Selecteur extends StatelessWidget {
  const _Selecteur({
    required this.element,
    required this.valeur,
    required this.options,
    required this.actif,
    required this.onChoix,
  });

  final String element;
  final String? valeur;
  final List<String> options;
  final bool actif;
  final ValueChanged<String> onChoix;

  Future<void> _ouvrir(BuildContext context) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Relier « $element » à :', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final o in options)
              ListTile(
                title: Text(o, style: const TextStyle(fontSize: 16, height: 1.35)),
                selected: o == valeur,
                trailing: o == valeur ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(context).pop(o),
              ),
          ],
        ),
      ),
    );
    if (choix != null) onChoix(choix);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Relier $element',
      value: valeur ?? 'pas encore choisi',
      excludeSemantics: true,
      child: Material(
        color: Couleurs.papier,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: valeur == null ? Couleurs.bordureForte : Couleurs.encre, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: actif ? () => _ouvrir(context) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      valeur ?? 'Choisir…',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        color: valeur == null ? Couleurs.texteSecondaire : Couleurs.texte,
                      ),
                    ),
                  ),
                  if (actif) const Icon(Icons.expand_more_rounded, color: Couleurs.texteSecondaire),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
