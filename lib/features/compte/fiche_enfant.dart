import 'package:flutter/material.dart';

import '../../core/theme/couleurs.dart';
import '../../data/data.dart';
import 'outils_compte.dart';

/// Saisie d'un profil enfant : prénom et classe (D21, rien d'autre).
typedef SaisieEnfant = ({String prenom, int classeId});

/// Ouvre la fiche d'ajout (sans [enfant]) ou de modification d'un profil.
/// Renvoie la saisie validée, ou `null` si le parent annule.
///
/// Une boîte de dialogue plutôt qu'une page : deux champs seulement, et rien
/// à retrouver par une adresse web.
Future<SaisieEnfant?> afficherFicheEnfant(
  BuildContext context, {
  required List<Classe> classes,
  Enfant? enfant,
}) =>
    showDialog<SaisieEnfant>(
      context: context,
      builder: (context) => FicheEnfant(classes: classes, enfant: enfant),
    );

class FicheEnfant extends StatefulWidget {
  const FicheEnfant({super.key, required this.classes, this.enfant});

  final List<Classe> classes;
  final Enfant? enfant;

  @override
  State<FicheEnfant> createState() => _FicheEnfantState();
}

class _FicheEnfantState extends State<FicheEnfant> {
  late final _champPrenom = TextEditingController(text: widget.enfant?.prenom ?? '');
  late int? _classeId = widget.enfant?.classeId ??
      // Une seule classe proposée : inutile de la faire choisir.
      (widget.classes.length == 1 ? widget.classes.first.id : null);
  String? _erreurPrenom;
  String? _erreurClasse;

  @override
  void dispose() {
    _champPrenom.dispose();
    super.dispose();
  }

  void _enregistrer() {
    final surPrenom = erreurPrenom(_champPrenom.text);
    final surClasse = _classeId == null ? 'Choisissez la classe de l’enfant.' : null;
    if (surPrenom != null || surClasse != null) {
      setState(() {
        _erreurPrenom = surPrenom;
        _erreurClasse = surClasse;
      });
      return;
    }
    Navigator.pop<SaisieEnfant>(context, (prenom: nettoyerPrenom(_champPrenom.text), classeId: _classeId!));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.enfant == null ? 'Ajouter un enfant' : 'Modifier le profil'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _champPrenom,
            autofocus: widget.enfant == null,
            textCapitalization: TextCapitalization.words,
            maxLength: longueurMaxPrenom,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Prénom',
              border: const OutlineInputBorder(),
              errorText: _erreurPrenom,
              // Le compteur « 0/40 » encombre : la limite est rarement atteinte.
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Text('Classe', style: Theme.of(context).textTheme.titleSmall),
          RadioGroup<int>(
            groupValue: _classeId,
            onChanged: (id) => setState(() {
              _classeId = id;
              _erreurClasse = null;
            }),
            child: Column(
              children: [
                for (final c in widget.classes)
                  RadioListTile<int>(value: c.id, title: Text(c.libelle), contentPadding: EdgeInsets.zero),
              ],
            ),
          ),
          if (_erreurClasse != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _erreurClasse!,
                style: const TextStyle(color: Couleurs.faux, fontSize: 13),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
      ],
    );
  }
}
