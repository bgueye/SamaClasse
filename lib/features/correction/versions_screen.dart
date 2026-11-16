import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/couleurs.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../data/data.dart';
import '../validation/outils_validation.dart';
import 'apercu_texte.dart';
import 'reserve_redacteurs.dart';

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

/// Versions d'une leçon (D33), à l'adresse `/lecon/12/versions` : chaque
/// version mise en ligne, la plus récente en tête (celle que voient les
/// élèves). Un validateur peut revenir à une version précédente.
class VersionsScreen extends StatelessWidget {
  const VersionsScreen({super.key, required this.leconId});

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
                ? _Versions(key: ValueKey(compte.email), leconId: leconId)
                : ReserveRedacteurs(connecte: false, repli: '/lecon/$leconId'),
          ),
        ),
      ),
    );
  }
}

typedef _Donnees = ({bool redacteur, bool validateur, List<VersionLecon> versions, bool correctionEnCours});

class _Versions extends StatefulWidget {
  const _Versions({super.key, required this.leconId});

  final int leconId;

  @override
  State<_Versions> createState() => _VersionsState();
}

class _VersionsState extends State<_Versions> {
  late AppScope _scope;
  Future<_Donnees>? _chargement;
  bool _occupe = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    _chargement ??= _charger();
  }

  Future<_Donnees> _charger() async {
    final redaction = _scope.redaction;
    if (!await redaction.estRedacteur()) {
      return (redacteur: false, validateur: false, versions: const <VersionLecon>[], correctionEnCours: false);
    }
    final (validateur, versions, correction) = await (
      redaction.estValidateur(),
      redaction.versions(widget.leconId),
      redaction.correctionDe(widget.leconId),
    ).wait;
    return (redacteur: true, validateur: validateur, versions: versions, correctionEnCours: correction != null);
  }

  void _recharger() => setState(() {
        _chargement = _charger();
      });

  void _annoncer(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _ouvrir(VersionLecon version, {required bool enLigne, required _Donnees donnees}) async {
    final revenir = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (context) => _PageVersion(
        version: version,
        enLigne: enLigne,
        // Revenir : validateur seulement, pas sur la version en ligne, ni
        // pendant une correction (la base le refuse aussi).
        peutRevenir: donnees.validateur && !enLigne && !donnees.correctionEnCours,
        correctionEnCours: donnees.correctionEnCours,
      ),
    ));
    if (revenir != true || !mounted) return;
    setState(() => _occupe = true);
    try {
      final numero = await _scope.redaction.revenirAVersion(version.id);
      if (!mounted) return;
      _annoncer('La version ${version.numero} est de nouveau en ligne (version $numero). '
          'Les élèves la verront à leur prochaine mise à jour.');
      _scope.repository.actualiser().ignore();
      _recharger();
    } catch (e) {
      if (mounted) _annoncer(messageErreurRedaction(e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Donnees>(
      future: _chargement,
      builder: (context, instantane) {
        final entete = <Widget>[
          LienRetour(libelle: 'Retour', repli: '/lecon/${widget.leconId}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
            child: Semantics(
              header: true,
              child: const Text(
                'Versions de la leçon',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Couleurs.texte),
              ),
            ),
          ),
        ];
        Widget colonne(Widget corps) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 24, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: entete),
                ),
                Expanded(child: corps),
              ],
            );
        if (instantane.hasError) return colonne(MessageErreur(erreur: instantane.error!, onReessayer: _recharger));
        if (instantane.connectionState != ConnectionState.done) return colonne(const Chargement());
        final donnees = instantane.data!;
        if (!donnees.redacteur) return ReserveRedacteurs(connecte: true, repli: '/lecon/${widget.leconId}');
        if (donnees.versions.isEmpty) {
          return colonne(const MessageVide(
            titre: 'Aucune version',
            texte: 'Les versions apparaissent à la publication de la leçon.',
          ));
        }
        final enLigne = donnees.versions.first.numero;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
          children: [
            ...entete,
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 12),
              child: Text(
                donnees.validateur
                    ? 'La version la plus récente est celle que voient les élèves. Ouvre une version pour la relire, '
                        'ou pour revenir à elle.'
                    : 'La version la plus récente est celle que voient les élèves. Seul un validateur peut revenir à '
                        'une version précédente.',
                style: const TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texteDoux),
              ),
            ),
            for (final v in donnees.versions)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 10),
                child: Material(
                  color: Couleurs.papier,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: v.numero == enLigne ? Couleurs.encre : Couleurs.bordureCarte, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    enabled: !_occupe,
                    onTap: () => _ouvrir(v, enLigne: v.numero == enLigne, donnees: donnees),
                    title: Text(
                      v.numero == enLigne ? 'Version ${v.numero} · en ligne' : 'Version ${v.numero}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${v.motif}\nPubliée le ${_date(v.publieeLe)}', style: const TextStyle(height: 1.4)),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Une version, affichée comme la leçon. Rend `true` si le validateur
/// confirme « Revenir à cette version ».
class _PageVersion extends StatelessWidget {
  const _PageVersion({
    required this.version,
    required this.enLigne,
    required this.peutRevenir,
    required this.correctionEnCours,
  });

  final VersionLecon version;
  final bool enLigne;
  final bool peutRevenir;
  final bool correctionEnCours;

  Future<void> _revenir(BuildContext context) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revenir à la version ${version.numero} ?'),
        content: const Text(
          'Son texte remplacera la version en ligne. La version actuelle reste dans l’historique : '
          'tu pourras y revenir.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revenir')),
        ],
      ),
    );
    if (confirme == true && context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.papier,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: LienRetour(libelle: 'Versions'),
            ),
            // Sur sa propre ligne : le libellé ne tient pas à côté du lien
            // de retour sur un téléphone.
            if (peutRevenir)
              LargeurLecture(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: FilledButton.icon(
                    onPressed: () => _revenir(context),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Revenir à cette version', textAlign: TextAlign.center),
                  ),
                ),
              ),
            Expanded(
              child: LargeurLecture(
                child: ApercuTexte(
                  texte: version.texte,
                  entete: EncadreApercu(
                    icone: Icons.history_rounded,
                    lignes: [
                      enLigne ? 'Version ${version.numero}, en ligne' : 'Version ${version.numero}',
                      version.motif,
                      'Publiée le ${_date(version.publieeLe)}',
                      if (!enLigne && correctionEnCours) 'Une correction est en cours : publie-la ou abandonne-la pour revenir à cette version.',
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
