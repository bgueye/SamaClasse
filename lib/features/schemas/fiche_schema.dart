import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/services/choix_image.dart';
import '../../core/services/reduction_image.dart';
import '../../core/theme/couleurs.dart';
import '../../core/widgets/composants.dart';
import '../../data/data.dart';
import 'outils_schemas.dart';

/// Ouvre la fenêtre « Ajouter un schéma » en plein écran pour l'image
/// [octets] (photo ou image de la galerie, pas encore réduite).
///
/// Rend `true` si le schéma a été ajouté à la leçon.
Future<bool> afficherFicheSchema(
  BuildContext context, {
  required TexteLecon texte,
  required Uint8List octets,
  required Redaction redaction,
  required ChoixImage choixImage,
}) async {
  final ajoute = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => FicheSchema(texte: texte, octets: octets, redaction: redaction, choixImage: choixImage),
  ));
  return ajoute ?? false;
}

/// Fenêtre « Ajouter un schéma » :
/// 1. l'image est réduite sous 150 Ko (aperçu, dimensions et poids) ;
/// 2. le rédacteur écrit la description (obligatoire : lecteurs d'écran,
///    affichage hors connexion) ;
/// 3. il choisit la partie (introduction ou corps) et l'endroit, entre deux
///    paragraphes ;
/// 4. « Ajouter à la leçon » dépose l'image puis l'insère dans le texte. Si
///    l'insertion échoue, l'image déposée est supprimée aussitôt : aucun
///    fichier orphelin dans l'espace `schemas`.
class FicheSchema extends StatefulWidget {
  const FicheSchema({
    super.key,
    required this.texte,
    required this.octets,
    required this.redaction,
    required this.choixImage,
  });

  final TexteLecon texte;
  final Uint8List octets;
  final Redaction redaction;
  final ChoixImage choixImage;

  @override
  State<FicheSchema> createState() => _FicheSchemaState();
}

class _FicheSchemaState extends State<FicheSchema> {
  late final Future<ImageReduite> _reduction = widget.choixImage.reduire(widget.octets);
  final _description = TextEditingController();

  late TexteLecon _texte = widget.texte;
  late ChampLecon _champ = _champParDefaut(widget.texte);

  /// Nombre de paragraphes après lesquels insérer (0 : au début).
  late int _apres = _finDe(_texte, _champ);

  String? _erreurDescription;

  /// Erreur de l'envoi, affichée au-dessus du bouton.
  String? _erreur;

  /// Vrai quand l'erreur vient d'une leçon modifiée entre-temps : on propose
  /// de la recharger.
  bool _texteChange = false;
  bool _envoi = false;

  /// Le corps s'il a du texte, sinon l'introduction.
  static ChampLecon _champParDefaut(TexteLecon t) =>
      (t.corps?.trim().isNotEmpty ?? false) || !(t.introduction?.trim().isNotEmpty ?? false)
          ? ChampLecon.corps
          : ChampLecon.introduction;

  /// Par défaut, le schéma va à la fin de la partie.
  static int _finDe(TexteLecon t, ChampLecon champ) => reperes(t.texte(champ)).last.apres;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _changerChamp(ChampLecon champ) => setState(() {
        _champ = champ;
        _apres = _finDe(_texte, champ);
      });

  Future<void> _recharger() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final texte = await widget.redaction.texteLecon(_texte.id);
      if (!mounted) return;
      if (texte == null) {
        setState(() => _erreur = 'Cette leçon n’existe plus.');
        return;
      }
      setState(() {
        _texte = texte;
        _apres = _finDe(texte, _champ);
        _texteChange = false;
      });
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreurSchema(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _ajouter(ImageReduite image) async {
    final erreur = erreurDescription(_description.text);
    if (erreur != null) {
      setState(() => _erreurDescription = erreur);
      return;
    }
    setState(() {
      _erreurDescription = null;
      _erreur = null;
      _envoi = true;
    });
    final redaction = widget.redaction;
    String? chemin;
    try {
      chemin = await redaction.deposerImage(leconId: _texte.id, octets: image.octets, extension: image.extension);
      // `null` = à la fin : le serveur compte lui-même les paragraphes.
      final fin = _apres == _finDe(_texte, _champ);
      await redaction.ajouterSchema(
        leconId: _texte.id,
        champ: _champ,
        apres: fin ? null : _apres,
        texteAttendu: _texte.texte(_champ),
        chemin: chemin,
        description: nettoyerDescription(_description.text),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Image déposée mais pas insérée : on la supprime (sans gravité si ça
      // échoue aussi, elle n'est utilisée nulle part).
      if (chemin != null) {
        try {
          await redaction.supprimerImage(chemin);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _erreur = messageErreurSchema(e);
          _texteChange = estTexteChange(e);
          _envoi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Pas de fermeture pendant l'envoi : l'image pourrait rester orpheline.
      canPop: !_envoi,
      child: Scaffold(
        backgroundColor: Couleurs.papier,
        body: SafeArea(
          child: LargeurLecture(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _envoi ? null : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Fermer sans ajouter',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: const Text(
                            'Ajouter un schéma',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Couleurs.texte),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<ImageReduite>(
                    future: _reduction,
                    builder: (context, instantane) {
                      if (instantane.hasError) return _ErreurImage(message: messageErreurSchema(instantane.error!));
                      if (!instantane.hasData) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Préparation de l’image…', style: TextStyle(fontSize: 15, color: Couleurs.texteDoux)),
                            ],
                          ),
                        );
                      }
                      return _formulaire(instantane.data!);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulaire(ImageReduite image) {
    final liste = reperes(_texte.texte(_champ));
    final fin = liste.last.apres;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text('Leçon : ${_texte.titre}', style: const TextStyle(fontSize: 15, height: 1.4, color: Couleurs.texteDoux)),
        const SizedBox(height: 16),
        // Aperçu de l'image telle qu'elle sera déposée.
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            border: Border.all(color: Couleurs.bordureCarte),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(
            image.octets,
            fit: BoxFit.contain,
            semanticLabel: 'Aperçu du schéma',
            errorBuilder: (context, _, _) => const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.image_outlined, size: 40, color: Couleurs.texteSecondaire)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${image.largeur} × ${image.hauteur} px · ${libellePoids(image.octets.length)}',
          style: const TextStyle(fontSize: 13, color: Couleurs.texteSecondaire),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _description,
          enabled: !_envoi,
          minLines: 2,
          maxLines: 4,
          maxLength: longueurMaxDescription,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Description (obligatoire)',
            hintText: 'Par exemple : les trois états de l’eau et les changements d’état entre eux',
            helperText: 'Lue aux élèves malvoyants, et affichée à la place de l’image hors connexion.',
            helperMaxLines: 3,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            errorText: _erreurDescription,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: const Text('Où le placer ?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        // Puces plutôt qu'un sélecteur à segments : avec un texte agrandi,
        // elles passent à la ligne entières au lieu de couper les mots. La
        // puce choisie porte une coche (pas seulement une couleur).
        Semantics(
          label: 'Partie de la leçon',
          container: true,
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final c in ChampLecon.values)
                ChoiceChip(
                  label: Text(c.libelle),
                  selected: _champ == c,
                  showCheckmark: true,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: _envoi ? null : (_) => _changerChamp(c),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (liste.length == 1)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Cette partie est vide : le schéma y sera seul.',
              style: TextStyle(fontSize: 15, height: 1.4, color: Couleurs.texteDoux),
            ),
          )
        else
          RadioGroup<int>(
            groupValue: _apres,
            onChanged: (v) {
              if (!_envoi && v != null) setState(() => _apres = v);
            },
            child: Column(
              children: [
                for (final r in liste)
                  RadioListTile<int>(
                    value: r.apres,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      r.apres == 0
                          ? 'Au début'
                          : r.apres == fin
                              ? 'À la fin, après : ${r.apercu}'
                              : 'Après : ${r.apercu}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (_erreur != null)
          Semantics(
            liveRegion: true,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Couleurs.fauxFond, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Couleurs.faux, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_erreur!, style: const TextStyle(fontSize: 15, height: 1.4, color: Couleurs.fauxTexte)),
                        if (_texteChange)
                          TextButton(onPressed: _envoi ? null : _recharger, child: const Text('Recharger la leçon')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: _envoi ? null : () => _ajouter(image),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: _envoi
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_envoi ? 'Envoi…' : 'Ajouter à la leçon'),
        ),
      ],
    );
  }
}

/// Image illisible ou impossible à réduire.
class _ErreurImage extends StatelessWidget {
  const _ErreurImage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 48, color: Couleurs.texteSecondaire),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.45)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Choisir une autre image')),
          ],
        ),
      ),
    );
  }
}
