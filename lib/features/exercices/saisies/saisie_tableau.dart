import 'package:flutter/material.dart';

import '../../../data/data.dart';
import '../outils_exercices.dart';
import 'commun.dart';

/// Tableau ordonné : une case à remplir par réponse attendue.
class SaisieTableauOrdonne extends StatelessWidget {
  const SaisieTableauOrdonne({
    super.key,
    required this.exercice,
    required this.reponse,
    required this.onChanged,
    required this.details,
  });

  final Exercice exercice;
  final List<String> reponse;
  final ValueChanged<Object?> onChanged;
  final List<bool>? details;

  @override
  Widget build(BuildContext context) {
    final attendu = (exercice.reponse as List).cast<String>();
    final corrige = details != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < attendu.length && i < reponse.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: ValueKey('tableau-${exercice.id}-$i'),
                  initialValue: reponse[i],
                  readOnly: corrige,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Case ${i + 1}'),
                  onChanged: (texte) {
                    final copie = List<String>.of(reponse);
                    copie[i] = texte;
                    onChanged(copie);
                  },
                ),
                if (detail(details, i) != null) RetourChamp(juste: detail(details, i)!, attendu: attendu[i]),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tableau de classement : chaque élément va dans une catégorie.
class SaisieClassement extends StatelessWidget {
  const SaisieClassement({
    super.key,
    required this.exercice,
    required this.reponse,
    required this.onChanged,
    required this.corrige,
  });

  final Exercice exercice;
  final Map<String, List<String>> reponse;
  final ValueChanged<Object?> onChanged;
  final bool corrige;

  String? _categorieChoisie(String element) {
    for (final entree in reponse.entries) {
      if (entree.value.contains(element)) return entree.key;
    }
    return null;
  }

  void _placer(String element, String categorie) {
    final copie = {
      for (final entree in reponse.entries) entree.key: entree.value.where((e) => e != element).toList(),
    };
    copie[categorie] = [...?copie[categorie], element];
    onChanged(copie);
  }

  @override
  Widget build(BuildContext context) {
    final attendu = exercice.reponse as Map;
    final categories = attendu.keys.cast<String>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final element in elementsAClasser(attendu))
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(element, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final categorie in categories)
                      ChoiceChip(
                        label: Text(libelleCle(categorie)),
                        selected: _categorieChoisie(element) == categorie,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: corrige ? null : (_) => _placer(element, categorie),
                      ),
                  ],
                ),
                if (corrige)
                  Builder(builder: (context) {
                    final bonne = categorieAttendue(attendu, element);
                    final juste = bonne != null && _categorieChoisie(element) == bonne;
                    return RetourChamp(juste: juste, attendu: bonne == null ? null : libelleCle(bonne));
                  }),
              ],
            ),
          ),
      ],
    );
  }
}
