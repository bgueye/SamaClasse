import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_scope.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/matieres.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../data/data.dart';
import 'fiche_lever.dart';
import 'outils_validation.dart';

/// « Leçons à vérifier » (phase 4, maquette `Validation`), à l'adresse
/// `/validation`. Réservé aux rédacteurs (D23).
///
/// Pour chaque leçon « à vérifier » : les points à lever avec les cahiers
/// (chaque case cochée est enregistrée dans l'historique, D25), le lien vers
/// l'artefact pour corriger la leçon (D26), et « Publier la leçon », actif
/// seulement quand tous les points sont levés.
///
/// En dessous, les corrections en cours des leçons publiées (D33) : texte
/// corrigé à relire, points à lever, puis « Publier la correction » ou
/// « Abandonner ». Publier (leçon ou correction) est réservé aux
/// validateurs. Tutoiement, comme la maquette.
class ValidationScreen extends StatelessWidget {
  const ValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compte = AppScope.of(context).compte;
    return Scaffold(
      body: SafeArea(
        child: LargeurLecture(
          child: ListenableBuilder(
            listenable: compte,
            builder: (context, _) => compte.estConnecte
                ? _Validation(key: ValueKey(compte.email))
                : const _Reserve(connecte: false),
          ),
        ),
      ),
    );
  }
}

/// Écran ouvert sans être connecté, ou avec un compte non rédacteur.
class _Reserve extends StatelessWidget {
  const _Reserve({required this.connecte});

  final bool connecte;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: LienRetour(libelle: 'Mes cours'),
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

class _Validation extends StatefulWidget {
  const _Validation({super.key});

  @override
  State<_Validation> createState() => _ValidationState();
}

class _ValidationState extends State<_Validation> {
  late AppScope _scope;
  Future<bool>? _chargement;

  // Données chargées, puis mises à jour au fil des cases cochées.
  List<LeconAVerifier> _lecons = const [];
  List<PointLeve> _leves = const [];

  /// Corrections en cours (D33), et celles publiées ou abandonnées pendant
  /// cette visite (retirées de la liste).
  List<CorrectionLecon> _corrections = const [];
  final _correctionsFermees = <int>{};

  /// Compte validateur : peut publier et abandonner (D33).
  bool _validateur = false;

  /// Correction dépliée.
  int? _correctionOuverte;

  /// Leçon dépliée.
  int? _ouverte;

  /// Leçons publiées pendant cette visite (gardées dans la liste, comme sur
  /// la maquette, avec la pastille « Publiée »).
  final _publiees = <int>{};

  /// Opérations en cours (« leconId|point » ou « publier|leconId ») : la case
  /// ou le bouton concerné attend la réponse, sans double envoi.
  final _enCours = <String>{};

  /// Message de réussite en haut de la liste (« … est publiée »).
  String? _bandeau;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    _chargement ??= _charger();
  }

  /// Rend `false` si le compte n'est pas rédacteur.
  Future<bool> _charger() async {
    final redaction = _scope.redaction;
    if (!await redaction.estRedacteur()) return false;
    final (lecons, leves, corrections, validateur) = await (
      redaction.leconsAVerifier(),
      redaction.pointsLeves(),
      redaction.correctionsEnCours(),
      redaction.estValidateur(),
    ).wait;
    _lecons = trierLecons(lecons);
    _leves = leves;
    _corrections = corrections;
    _validateur = validateur;
    _correctionsFermees.clear();
    return true;
  }

  void _recharger() => setState(() {
        _publiees.clear();
        _bandeau = null;
        _chargement = _charger();
      });

  Future<void> _actualiser() async {
    final suite = _charger();
    setState(() {
      _publiees.clear();
      _bandeau = null;
      _chargement = suite;
    });
    await suite.then((_) {}, onError: (Object _) {});
  }

  void _annoncer(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Lève un point (fenêtre « Lever ce point », avec la réponse) ou annule
  /// un point levé. Chaque point levé laisse une trace dans l'historique
  /// (D25) ; l'annuler n'est possible qu'avant la publication.
  Future<void> _basculer(LeconAVerifier lecon, String point) =>
      _basculerPoint(leconId: lecon.id, point: point, existant: pointLeve(_leves, lecon.id, point), cle: '${lecon.id}|$point');

  /// Même chose pour un point d'une correction en cours (D33).
  Future<void> _basculerCorrection(CorrectionLecon c, String point) => _basculerPoint(
        leconId: c.leconId,
        point: point,
        existant: pointLeveCorrection(_leves, c.id, point),
        cle: 'c${c.id}|$point',
        correctionId: c.id,
      );

  Future<void> _basculerPoint({
    required int leconId,
    required String point,
    required PointLeve? existant,
    required String cle,
    int? correctionId,
  }) async {
    if (_enCours.contains(cle)) return;

    String? reponse;
    if (existant == null) {
      final saisie = await afficherFicheLever(context, point: point);
      if (saisie == null || !mounted) return; // annulé
      reponse = nettoyerReponse(saisie);
    } else if (existant.commentaire != null) {
      // Annuler effacerait la réponse écrite : on demande d'abord.
      final confirme = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Annuler ce point ?'),
          content: const Text('Ta réponse sera effacée et le point redeviendra à vérifier.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Annuler le point')),
          ],
        ),
      );
      if (confirme != true || !mounted) return;
    }

    setState(() => _enCours.add(cle));
    try {
      if (existant == null) {
        final leve = await _scope.redaction.leverPoint(
          leconId: leconId,
          point: point,
          commentaire: reponse,
          correctionId: correctionId,
        );
        if (mounted) setState(() => _leves = [..._leves, leve]);
      } else {
        await _scope.redaction.annulerPoint(existant.id);
        if (mounted) setState(() => _leves = [for (final p in _leves) if (p.id != existant.id) p]);
      }
    } catch (e) {
      if (mounted) _annoncer(messageErreurRedaction(e));
    } finally {
      if (mounted) setState(() => _enCours.remove(cle));
    }
  }

  Future<void> _ouvrirArtefact(String adresse) async {
    final uri = Uri.tryParse(adresse);
    var ouvert = false;
    if (uri != null) {
      try {
        ouvert = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ouvert = false;
      }
    }
    if (!ouvert && mounted) _annoncer('Impossible d’ouvrir le lien de la leçon.');
  }

  Future<void> _publier(LeconAVerifier lecon) async {
    final cle = 'publier|${lecon.id}';
    if (_enCours.contains(cle)) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Publier « ${lecon.titre} » ?'),
        content: const Text(
          'Les élèves la verront à la prochaine mise à jour de leur application. '
          'Une leçon publiée ne se dépublie pas depuis l’application.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publier')),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _enCours.add(cle));
    try {
      await _scope.redaction.publier(lecon.id);
      if (!mounted) return;
      setState(() {
        _publiees.add(lecon.id);
        _bandeau = '« ${lecon.titre} » est publiée. Les élèves la verront à la prochaine mise à jour de leur application.';
      });
      // La copie locale de ce téléphone se met à jour tout de suite.
      _scope.repository.actualiser().ignore();
    } catch (e) {
      if (mounted) _annoncer(messageErreurRedaction(e));
    } finally {
      if (mounted) setState(() => _enCours.remove(cle));
    }
  }

  /// Validateur : met la correction en ligne (D33).
  Future<void> _publierCorrection(CorrectionLecon c) async {
    final cle = 'publierC|${c.id}';
    if (_enCours.contains(cle)) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Publier la correction de « ${c.titreEnLigne} » ?'),
        content: const Text(
          'Le texte corrigé remplacera la version en ligne ; les élèves le verront à la prochaine mise à jour '
          'de leur application. La version actuelle reste dans l’historique.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publier')),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _enCours.add(cle));
    try {
      final numero = await _scope.redaction.publierCorrection(c.id);
      if (!mounted) return;
      setState(() {
        _correctionsFermees.add(c.id);
        _bandeau = 'La correction de « ${c.texte.titre} » est en ligne (version $numero). '
            'Les élèves la verront à la prochaine mise à jour de leur application.';
      });
      _scope.repository.actualiser().ignore();
    } catch (e) {
      if (mounted) _annoncer(messageErreurRedaction(e));
    } finally {
      if (mounted) setState(() => _enCours.remove(cle));
    }
  }

  /// Validateur, ou rédacteur qui l'a demandée : ferme la correction sans la
  /// publier ; les images ajoutées dedans sont supprimées.
  Future<void> _abandonnerCorrection(CorrectionLecon c) async {
    final cle = 'abandonC|${c.id}';
    if (_enCours.contains(cle)) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner cette correction ?'),
        content: const Text(
          'La leçon reste en ligne telle quelle. Le texte de travail, les points levés et les schémas '
          'ajoutés dans cette correction sont abandonnés.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Couleurs.faux),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _enCours.add(cle));
    try {
      final chemins = await _scope.redaction.abandonnerCorrection(c.id);
      // Images utilisées nulle part en ligne : un échec ne laisse qu'un
      // fichier inutile.
      for (final chemin in chemins) {
        try {
          await _scope.redaction.supprimerImage(chemin);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _correctionsFermees.add(c.id));
      _annoncer('Correction abandonnée. La leçon reste en ligne telle quelle.');
    } catch (e) {
      if (mounted) _annoncer(messageErreurRedaction(e));
    } finally {
      if (mounted) setState(() => _enCours.remove(cle));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _chargement,
      builder: (context, instantane) {
        final entete = <Widget>[
          const LienRetour(libelle: 'Retour', repli: '/compte'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
            child: Semantics(
              header: true,
              child: const Text(
                'Leçons à vérifier',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Couleurs.texte),
              ),
            ),
          ),
        ];
        if (instantane.hasError) {
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 24, 0), child: Column(children: entete)),
            Expanded(child: MessageErreur(erreur: instantane.error!, onReessayer: _recharger)),
          ]);
        }
        if (!instantane.hasData) {
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 24, 0), child: Column(children: entete)),
            const Expanded(child: Chargement()),
          ]);
        }
        if (instantane.data == false) return const _Reserve(connecte: true);

        final aVerifier = [for (final l in _lecons) if (!_publiees.contains(l.id)) l];
        final corrections = [for (final c in _corrections) if (!_correctionsFermees.contains(c.id)) c];
        return RefreshIndicator(
          onRefresh: _actualiser,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
            children: [
              ...entete,
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                child: Text(
                  resumeValidation(aVerifier, _leves),
                  style: const TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texteDoux),
                ),
              ),
              if (_bandeau != null) Padding(padding: const EdgeInsets.fromLTRB(12, 14, 0, 0), child: _Bandeau(_bandeau!)),
              const SizedBox(height: 12),
              if (_lecons.isEmpty && corrections.isEmpty)
                const MessageVide(
                  titre: 'Rien à vérifier',
                  texte: 'Toutes les leçons sont publiées ou encore en brouillon, et aucune correction n’est en cours.',
                )
              else
                for (final l in _lecons)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _CarteLecon(
                      lecon: l,
                      leves: _leves,
                      ouverte: _ouverte == l.id,
                      publiee: _publiees.contains(l.id),
                      enCours: _enCours,
                      onBasculer: () => setState(() => _ouverte = _ouverte == l.id ? null : l.id),
                      onPoint: (point) => _basculer(l, point),
                      onArtefact: l.artefactUrl == null ? null : () => _ouvrirArtefact(l.artefactUrl!),
                      onSchemas: () => context.push('/lecon/${l.id}/schemas'),
                      onPublier: () => _publier(l),
                      validateur: _validateur,
                    ),
                  ),
              // Corrections des leçons publiées (D33).
              if (corrections.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 28, 0, 4),
                  child: Semantics(header: true, child: const Text('Corrections en cours', style: Styles.sectionTitre)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 0, 8),
                  child: Text(
                    resumeCorrections(corrections.length),
                    style: const TextStyle(fontSize: 14, height: 1.45, color: Couleurs.texteDoux),
                  ),
                ),
                for (final c in corrections)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _CarteCorrection(
                      correction: c,
                      leves: _leves,
                      ouverte: _correctionOuverte == c.id,
                      enCours: _enCours,
                      validateur: _validateur,
                      onBasculer: () => setState(() => _correctionOuverte = _correctionOuverte == c.id ? null : c.id),
                      onPoint: (point) => _basculerCorrection(c, point),
                      onTexte: () => context.push('/lecon/${c.leconId}/correction'),
                      onSchemas: () => context.push('/lecon/${c.leconId}/schemas'),
                      onPublier: () => _publierCorrection(c),
                      onAbandonner: () => _abandonnerCorrection(c),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Message de réussite : icône et texte (jamais la couleur seule), annoncé
/// aux lecteurs d'écran.
class _Bandeau extends StatelessWidget {
  const _Bandeau(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Couleurs.justeFond, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded, color: Couleurs.juste, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(texte, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Couleurs.justeTexte)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteLecon extends StatelessWidget {
  const _CarteLecon({
    required this.lecon,
    required this.leves,
    required this.ouverte,
    required this.publiee,
    required this.enCours,
    required this.onBasculer,
    required this.onPoint,
    required this.onArtefact,
    required this.onSchemas,
    required this.onPublier,
    required this.validateur,
  });

  final LeconAVerifier lecon;
  final List<PointLeve> leves;
  final bool ouverte;
  final bool publiee;
  final Set<String> enCours;
  final VoidCallback onBasculer;
  final ValueChanged<String> onPoint;
  final VoidCallback? onArtefact;
  final VoidCallback onSchemas;
  final VoidCallback onPublier;

  /// Seul un validateur publie (D33).
  final bool validateur;

  @override
  Widget build(BuildContext context) {
    final restants = pointsRestants(lecon, leves).length;
    final publication = enCours.contains('publier|${lecon.id}');
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Couleurs.bordure))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: ouverte,
            button: true,
            child: InkWell(
              onTap: onBasculer,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      DosCahier(couleur: couleurMatiere(lecon.matiereSlug), largeur: 6, hauteur: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lecon.titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
                            const SizedBox(height: 3),
                            Text(libelleClasseMatiere(lecon), style: Styles.secondaire),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Pastille(texte: publiee ? 'Publiée' : libellePastille(restants), publiee: publiee),
                      Icon(
                        ouverte ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: Couleurs.texteSecondaire,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (ouverte)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 0, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (lecon.points.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Aucun point à vérifier sur cette leçon.', style: TextStyle(fontSize: 14, color: Couleurs.texteDoux)),
                    ),
                  for (final p in lecon.points) _CasePoint(
                    texte: p,
                    coche: pointLeve(leves, lecon.id, p) != null,
                    reponse: pointLeve(leves, lecon.id, p)?.commentaire,
                    // Après publication, l'historique est figé (D25).
                    actif: !publiee && !enCours.contains('${lecon.id}|$p'),
                    onChanged: () => onPoint(p),
                  ),
                  if (onArtefact != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onArtefact,
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        label: const Text('Ouvrir la leçon pour la corriger'),
                      ),
                    ),
                  // Schémas du cahier (phase 5), aussi avant publication.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: publiee ? null : onSchemas,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                      label: const Text('Ajouter ou retirer des schémas'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: publiee || restants > 0 || publication || !validateur ? null : onPublier,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text(
                      publiee
                          ? 'Leçon publiée'
                          : publication
                              ? 'Publication…'
                              : restants > 0
                                  ? 'Coche tous les points pour publier'
                                  : validateur
                                      ? 'Publier la leçon'
                                      : 'Un validateur publiera la leçon',
                      textAlign: TextAlign.center,
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

/// Une correction en cours (D33) : raison, état du texte, points à lever,
/// et les actions (relire, schémas, publier, abandonner).
class _CarteCorrection extends StatelessWidget {
  const _CarteCorrection({
    required this.correction,
    required this.leves,
    required this.ouverte,
    required this.enCours,
    required this.validateur,
    required this.onBasculer,
    required this.onPoint,
    required this.onTexte,
    required this.onSchemas,
    required this.onPublier,
    required this.onAbandonner,
  });

  final CorrectionLecon correction;
  final List<PointLeve> leves;
  final bool ouverte;
  final Set<String> enCours;
  final bool validateur;
  final VoidCallback onBasculer;
  final ValueChanged<String> onPoint;
  final VoidCallback onTexte;
  final VoidCallback onSchemas;
  final VoidCallback onPublier;
  final VoidCallback onAbandonner;

  @override
  Widget build(BuildContext context) {
    final c = correction;
    final restants = pointsRestantsCorrection(c, leves).length;
    final publication = enCours.contains('publierC|${c.id}');
    final abandon = enCours.contains('abandonC|${c.id}');
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Couleurs.bordure))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: ouverte,
            button: true,
            child: InkWell(
              onTap: onBasculer,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      DosCahier(couleur: couleurMatiere(c.matiereSlug), largeur: 6, hauteur: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.titreEnLigne, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
                            const SizedBox(height: 3),
                            Text(libelleClasseMatiereCorrection(c), style: Styles.secondaire),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Pastille(texte: libellePastille(restants), publiee: false),
                      Icon(
                        ouverte ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: Couleurs.texteSecondaire,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (ouverte)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 0, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Correction : ${c.motif}', style: const TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texte)),
                  const SizedBox(height: 4),
                  Text(etatTexteCorrection(c), style: Styles.secondaire),
                  const SizedBox(height: 10),
                  for (final p in c.points)
                    _CasePoint(
                      texte: p,
                      coche: pointLeveCorrection(leves, c.id, p) != null,
                      reponse: pointLeveCorrection(leves, c.id, p)?.commentaire,
                      actif: !enCours.contains('c${c.id}|$p'),
                      onChanged: () => onPoint(p),
                    ),
                  Wrap(
                    children: [
                      TextButton.icon(
                        onPressed: onTexte,
                        icon: const Icon(Icons.article_outlined, size: 20),
                        label: const Text('Relire le texte corrigé'),
                      ),
                      TextButton.icon(
                        onPressed: onSchemas,
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                        label: const Text('Ajouter ou retirer des schémas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: restants > 0 || publication || !validateur ? null : onPublier,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text(
                      publication
                          ? 'Publication…'
                          : restants > 0
                              ? 'Coche tous les points pour publier'
                              : validateur
                                  ? 'Publier la correction'
                                  : 'Un validateur publiera la correction',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (validateur || c.parMoi)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: abandon ? null : onAbandonner,
                        style: TextButton.styleFrom(foregroundColor: Couleurs.faux),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: const Text('Abandonner la correction'),
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

class _Pastille extends StatelessWidget {
  const _Pastille({required this.texte, required this.publiee});

  final String texte;
  final bool publiee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: publiee ? Couleurs.justeFond : Couleurs.selection,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: publiee ? Couleurs.juste : Couleurs.etiquette,
        ),
      ),
    );
  }
}

/// Un point à vérifier, avec sa case à cocher (cible tactile ≥ 48 px) et,
/// une fois levé, la réponse du rédacteur.
class _CasePoint extends StatelessWidget {
  const _CasePoint({
    required this.texte,
    required this.coche,
    required this.reponse,
    required this.actif,
    required this.onChanged,
  });

  final String texte;
  final bool coche;
  final String? reponse;
  final bool actif;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Couleurs.papier,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Couleurs.bordureCarte, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          value: coche,
          onChanged: actif ? (_) => onChanged() : null,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Couleurs.encre,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(texte, style: const TextStyle(fontSize: 14, height: 1.45, color: Couleurs.texte)),
          subtitle: reponse == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Ta réponse : $reponse',
                    style: const TextStyle(fontSize: 14, height: 1.4, color: Couleurs.texteDoux, fontStyle: FontStyle.italic),
                  ),
                ),
        ),
      ),
    );
  }
}
