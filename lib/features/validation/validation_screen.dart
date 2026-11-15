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
/// seulement quand tous les points sont levés. Tutoiement, comme la maquette.
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
    final (lecons, leves) = await (redaction.leconsAVerifier(), redaction.pointsLeves()).wait;
    _lecons = trierLecons(lecons);
    _leves = leves;
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
  Future<void> _basculer(LeconAVerifier lecon, String point) async {
    final cle = '${lecon.id}|$point';
    if (_enCours.contains(cle)) return;
    final existant = pointLeve(_leves, lecon.id, point);

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
        final leve = await _scope.redaction.leverPoint(leconId: lecon.id, point: point, commentaire: reponse);
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
              if (_lecons.isEmpty)
                const MessageVide(
                  titre: 'Rien à vérifier',
                  texte: 'Toutes les leçons sont publiées ou encore en brouillon.',
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
                      onPublier: () => _publier(l),
                    ),
                  ),
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
    required this.onPublier,
  });

  final LeconAVerifier lecon;
  final List<PointLeve> leves;
  final bool ouverte;
  final bool publiee;
  final Set<String> enCours;
  final VoidCallback onBasculer;
  final ValueChanged<String> onPoint;
  final VoidCallback? onArtefact;
  final VoidCallback onPublier;

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
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: publiee || restants > 0 || publication ? null : onPublier,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text(
                      publiee
                          ? 'Leçon publiée'
                          : publication
                              ? 'Publication…'
                              : restants > 0
                                  ? 'Coche tous les points pour publier'
                                  : 'Publier la leçon',
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
