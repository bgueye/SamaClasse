import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/services/choix_image.dart';
import '../../core/theme/couleurs.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../data/data.dart';
import 'fiche_schema.dart';
import 'outils_schemas.dart';

/// « Schémas de la leçon » (rédacteurs, phase 5), à l'adresse
/// `/lecon/12/schemas`.
///
/// On y ouvre l'appareil photo ou la galerie pour ajouter un schéma du
/// cahier à la leçon (fenêtre [FicheSchema]), et on y retire les schémas
/// ajoutés par erreur. Accessible depuis la leçon elle-même (bouton réservé
/// aux rédacteurs) et depuis « Leçons à vérifier », pour les leçons pas
/// encore publiées. Tutoiement, comme les autres écrans des rédacteurs.
class SchemasScreen extends StatelessWidget {
  const SchemasScreen({super.key, required this.leconId});

  final int leconId;

  @override
  Widget build(BuildContext context) {
    final compte = AppScope.of(context).compte;
    return Scaffold(
      body: SafeArea(
        child: LargeurLecture(
          child: ListenableBuilder(
            listenable: compte,
            builder: (context, _) => compte.estConnecte
                ? _Schemas(key: ValueKey(compte.email), leconId: leconId)
                : _Reserve(leconId: leconId, connecte: false),
          ),
        ),
      ),
    );
  }
}

/// Écran ouvert sans être connecté, ou avec un compte non rédacteur.
class _Reserve extends StatelessWidget {
  const _Reserve({required this.leconId, required this.connecte});

  final int leconId;
  final bool connecte;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: LienRetour(libelle: 'Retour', repli: '/lecon/$leconId'),
        ),
        Expanded(
          child: MessageVide(
            titre: 'Réservé aux rédacteurs',
            texte: connecte
                ? 'Ton compte n’a pas les droits de rédacteur. Ils se donnent dans le tableau de bord Supabase.'
                : 'Connecte-toi dans l’espace parents avec un compte rédacteur.',
            action: connecte
                ? null
                : FilledButton(
                    onPressed: () => context.go('/compte'),
                    child: const Text('Aller à l’espace parents'),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Données de l'écran. [texte] est `null` si la leçon n'existe pas.
typedef _Donnees = ({TexteLecon? texte, List<SchemaLecon> schemas, bool validateur});

class _Schemas extends StatefulWidget {
  const _Schemas({super.key, required this.leconId});

  final int leconId;

  @override
  State<_Schemas> createState() => _SchemasState();
}

class _SchemasState extends State<_Schemas> {
  late AppScope _scope;

  /// Rend `null` si le compte n'est pas rédacteur.
  Future<_Donnees?>? _chargement;

  /// Opération en cours (ajout ou retrait) : les boutons attendent.
  bool _occupe = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    _chargement ??= _charger();
  }

  Future<_Donnees?> _charger() async {
    final redaction = _scope.redaction;
    if (!await redaction.estRedacteur()) return null;
    final (texte, schemas, validateur) = await (
      redaction.texteLecon(widget.leconId),
      redaction.schemasLecon(widget.leconId),
      redaction.estValidateur(),
    ).wait;
    return (texte: texte, schemas: schemas, validateur: validateur);
  }

  void _recharger() => setState(() {
        _chargement = _charger();
      });

  void _annoncer(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Photo ou galerie, puis la fenêtre « Ajouter un schéma ».
  Future<void> _ajouter(TexteLecon texte) async {
    final source = await showModalBottomSheet<SourceImage>(
      context: context,
      showDragHandle: true,
      // Texte agrandi : la feuille peut monter plus haut, et défiler.
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              subtitle: const Text('Le schéma du cahier, bien à plat et éclairé'),
              onTap: () => Navigator.pop(context, SourceImage.appareilPhoto),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              subtitle: const Text('Recadre d’abord l’image sur le schéma'),
              onTap: () => Navigator.pop(context, SourceImage.galerie),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final octets = await _scope.choixImage.choisir(source).catchError((Object e) {
      // Autorisation refusée, appareil photo absent…
      if (mounted) _annoncer('Impossible d’ouvrir ${source == SourceImage.appareilPhoto ? 'l’appareil photo' : 'la galerie'}.');
      return null;
    });
    if (octets == null || !mounted) return;

    final ajoute = await afficherFicheSchema(
      context,
      texte: texte,
      octets: octets,
      redaction: _scope.redaction,
      choixImage: _scope.choixImage,
    );
    if (!ajoute || !mounted) return;
    _annoncer(texte.publiee
        ? 'Schéma ajouté. Les élèves le verront à leur prochaine mise à jour.'
        : 'Schéma ajouté à la leçon.');
    // La copie locale de ce téléphone se met à jour tout de suite.
    _scope.repository.actualiser().ignore();
    _recharger();
  }

  Future<void> _retirer(SchemaLecon schema) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce schéma ?'),
        content: Text(
          '« ${schema.description} » disparaît de la leçon, et l’image est supprimée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Couleurs.faux),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _occupe = true);
    try {
      final chemin = await _scope.redaction.retirerSchema(schema.id);
      // Le schéma n'est plus dans la leçon : un échec ici laisse seulement
      // un fichier inutilisé, sans effet pour les élèves.
      try {
        await _scope.redaction.supprimerImage(chemin);
      } catch (_) {}
      if (!mounted) return;
      _annoncer('Schéma retiré de la leçon.');
      _scope.repository.actualiser().ignore();
      _recharger();
    } catch (e) {
      if (mounted) _annoncer(messageErreurSchema(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Donnees?>(
      future: _chargement,
      builder: (context, instantane) {
        final entete = <Widget>[
          LienRetour(libelle: 'Retour', repli: '/lecon/${widget.leconId}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
            child: Semantics(
              header: true,
              child: const Text(
                'Schémas de la leçon',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Couleurs.texte),
              ),
            ),
          ),
        ];
        if (instantane.hasError) {
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 24, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: entete)),
            Expanded(child: MessageErreur(erreur: instantane.error!, onReessayer: _recharger)),
          ]);
        }
        if (instantane.connectionState != ConnectionState.done) {
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 24, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: entete)),
            const Expanded(child: Chargement()),
          ]);
        }
        final donnees = instantane.data;
        if (donnees == null) return _Reserve(leconId: widget.leconId, connecte: true);
        final texte = donnees.texte;
        if (texte == null) {
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 24, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: entete)),
            const Expanded(
              child: MessageVide(titre: 'Leçon introuvable', texte: 'Cette leçon n’existe pas, ou plus.'),
            ),
          ]);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
          children: [
            ...entete,
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
              child: Text(
                texte.titre,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35, color: Couleurs.encre),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
              child: Text(
                resumeSchemas(
                  donnees.schemas.length,
                  publiee: texte.publiee,
                  dansCorrection: texte.dansCorrection,
                  validateur: donnees.validateur,
                ),
                style: const TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texteDoux),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 0, 8),
              child: FilledButton.icon(
                onPressed: _occupe || !peutAjouterSchema(texte, validateur: donnees.validateur)
                    ? null
                    : () => _ajouter(texte),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Ajouter un schéma'),
              ),
            ),
            for (final s in donnees.schemas)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 12),
                child: _CarteSchema(
                  schema: s,
                  adresse: _scope.redaction.adresseImage(s.chemin),
                  dansCorrection: s.correctionId != null && s.correctionId == texte.correctionId,
                  onRetirer: _occupe || !peutRetirerSchema(s, texte, validateur: donnees.validateur)
                      ? null
                      : () => _retirer(s),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 20, 0, 0),
              child: Text(
                'Seuls les schémas ajoutés depuis l’application sont listés ici. Ceux déposés par le '
                'tableau de bord Supabase se retirent en corrigeant le texte de la leçon.',
                style: TextStyle(fontSize: 13, height: 1.45, color: Couleurs.texteSecondaire),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

/// Un schéma ajouté : vignette, description, partie, date, « Retirer ».
class _CarteSchema extends StatelessWidget {
  const _CarteSchema({
    required this.schema,
    required this.adresse,
    required this.onRetirer,
    this.dansCorrection = false,
  });

  /// Ajouté dans la correction en cours : pas encore en ligne (D33).
  final bool dansCorrection;

  final SchemaLecon schema;
  final String adresse;
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Couleurs.papier,
        border: Border.all(color: Couleurs.bordureCarte, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Couleurs.fond,
            height: 160,
            child: Image.network(
              adresse,
              fit: BoxFit.contain,
              // La description est lue juste en dessous.
              excludeFromSemantics: true,
              errorBuilder: (context, _, _) => const Center(
                // Défile si le texte agrandi ne tient pas dans la vignette.
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_outlined, color: Couleurs.texteSecondaire),
                      SizedBox(height: 4),
                      Text(
                        'Image indisponible hors connexion',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Couleurs.texteSecondaire),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schema.description, style: const TextStyle(fontSize: 15, height: 1.4, color: Couleurs.texte)),
                const SizedBox(height: 4),
                Text(
                  '${schema.champ.libelle} · ajouté le ${_date(schema.ajouteLe)}'
                  '${dansCorrection ? ' · dans la correction en cours' : ''}',
                  style: const TextStyle(fontSize: 13, color: Couleurs.texteSecondaire),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRetirer,
                    style: TextButton.styleFrom(foregroundColor: Couleurs.faux),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Retirer'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
