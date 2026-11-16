import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/services/preferences.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../data/data.dart';
import '../liaison/fiche_code_liaison.dart';
import '../liaison/outils_liaison.dart';
import '../liaison/telephone_lie.dart';
import 'fiche_enfant.dart';
import 'outils_compte.dart';

/// « Espace parents » (phase 2, D21 et D22), à l'adresse `/compte`.
///
/// Sans connexion : connexion en deux étapes (e-mail, puis code chiffré reçu
/// par e-mail), et l'accès « J'ai un code de mon parent » pour le téléphone
/// d'un enfant (D32). Connecté : la liste des profils enfants. Téléphone
/// d'enfant lié : [TelephoneLie], sans aucun accès au compte du parent.
/// L'écran suit le compte (`ListenableBuilder`) : il bascule tout seul d'une
/// vue à l'autre à la connexion et à la déconnexion.
class CompteScreen extends StatelessWidget {
  const CompteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compte = AppScope.of(context).compte;
    return Scaffold(
      body: SafeArea(
        child: LargeurLecture(
          child: ListenableBuilder(
            listenable: compte,
            builder: (context, _) => compte.estConnecte
                // Clé par adresse : un autre compte repart d'une liste neuve.
                ? MesEnfants(key: ValueKey(compte.email))
                : compte.estAnonyme
                    ? const _VueTelephoneEnfant()
                    : const ConnexionParent(),
          ),
        ),
      ),
    );
  }
}

/// Session anonyme ouverte : téléphone d'enfant lié (profil retenu avec
/// `lie`), sinon liaison pas aboutie, et l'on montre la connexion habituelle.
class _VueTelephoneEnfant extends StatefulWidget {
  const _VueTelephoneEnfant();

  @override
  State<_VueTelephoneEnfant> createState() => _VueTelephoneEnfantState();
}

class _VueTelephoneEnfantState extends State<_VueTelephoneEnfant> {
  Future<EnfantActif?>? _actif;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actif ??= AppScope.of(context).preferences.enfantActif();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EnfantActif?>(
      future: _actif,
      builder: (context, instantane) {
        if (instantane.connectionState != ConnectionState.done) return const Chargement();
        final actif = instantane.data;
        return actif != null && actif.lie ? TelephoneLie(enfant: actif) : const ConnexionParent();
      },
    );
  }
}

/// En-tête commun aux deux vues : retour, titre, phrase d'explication.
class _Entete extends StatelessWidget {
  const _Entete({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LienRetour(libelle: 'Mes cours'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Espace parents',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Couleurs.encre),
                ),
              ),
              const SizedBox(height: 8),
              Text(texte, style: const TextStyle(fontSize: 16, height: 1.5, color: Couleurs.texteDoux)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Message d'erreur sous un formulaire : icône + texte (jamais la couleur
/// seule, DESIGN.md), annoncé aux lecteurs d'écran dès qu'il apparaît.
class _ErreurFormulaire extends StatelessWidget {
  const _ErreurFormulaire(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Couleurs.fauxFond,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Couleurs.faux, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 15, height: 1.4, color: Couleurs.fauxTexte)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connexion
// ---------------------------------------------------------------------------

/// Connexion du parent : e-mail, puis code. Pas de mot de passe (D22).
class ConnexionParent extends StatefulWidget {
  const ConnexionParent({super.key});

  @override
  State<ConnexionParent> createState() => _ConnexionParentState();
}

class _ConnexionParentState extends State<ConnexionParent> {
  final _champEmail = TextEditingController();
  final _champCode = TextEditingController();

  /// Adresse à laquelle le code a été envoyé ; `null` tant qu'on est à
  /// l'étape de l'e-mail.
  String? _emailEnvoye;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _champEmail.dispose();
    _champCode.dispose();
    super.dispose();
  }

  /// Lance une demande au serveur en gérant l'attente et l'erreur affichée.
  Future<void> _executer(Future<void> Function() action) async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreurCompte(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _envoyerCode() async {
    if (_enCours) return;
    final email = nettoyerEmail(_champEmail.text);
    if (!emailValide(email)) {
      setState(() => _erreur = 'Saisissez une adresse e-mail complète, par exemple prenom@exemple.com.');
      return;
    }
    await _executer(() async {
      await AppScope.of(context).compte.envoyerCode(email);
      if (mounted) {
        setState(() {
          _emailEnvoye = email;
          _champCode.clear();
        });
      }
    });
  }

  Future<void> _verifierCode() async {
    if (_enCours) return;
    final code = nettoyerCode(_champCode.text);
    if (!codeComplet(code)) {
      setState(() => _erreur = 'Saisissez tous les chiffres du code reçu par e-mail.');
      return;
    }
    // En cas de succès, le compte prévient CompteScreen, qui affiche la liste.
    await _executer(() => AppScope.of(context).compte.verifierCode(_emailEnvoye!, code));
  }

  void _changerAdresse() => setState(() {
        _emailEnvoye = null;
        _erreur = null;
      });

  @override
  Widget build(BuildContext context) {
    final etapeCode = _emailEnvoye != null;
    return ListView(
      // Une liste neuve à chaque étape : on repart du haut, où se trouvent
      // l'explication et le champ (sinon, à 200 %, on resterait défilé vers
      // le bas, le champ du code hors de l'écran).
      key: ValueKey(etapeCode),
      padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
      children: [
        _Entete(
          texte: etapeCode
              ? 'Nous avons envoyé un code à $_emailEnvoye. '
                  'S’il n’arrive pas, regardez dans les courriers indésirables.'
              : 'Connectez-vous pour créer les profils de vos enfants. Pas de mot de passe : '
                  'vous recevez un code par e-mail. Sans compte, toutes les leçons restent accessibles.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 0, 0),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: etapeCode ? _etapeCode() : _etapeEmail(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _etapeEmail() => [
        TextField(
          controller: _champEmail,
          enabled: !_enCours,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _envoyerCode(),
          decoration: const InputDecoration(labelText: 'Adresse e-mail', border: OutlineInputBorder()),
        ),
        if (_erreur != null) _ErreurFormulaire(_erreur!),
        const SizedBox(height: 18),
        _BoutonAction(libelle: 'Recevoir un code', enCours: _enCours, onPressed: _envoyerCode),
        // Téléphone d'un enfant (D32) : pas de compte, un code du parent.
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: const Text('C’est le téléphone d’un enfant ?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Liez-le à son profil avec un code affiché sur le téléphone du parent. L’enfant n’a pas '
          'besoin du compte de son parent.',
          style: TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texteDoux),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _enCours ? null : () => context.push('/lier'),
          icon: const Icon(Icons.phonelink_lock_outlined),
          label: const Text('J’ai un code de mon parent'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ];

  List<Widget> _etapeCode() => [
        TextField(
          controller: _champCode,
          enabled: !_enCours,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          // Chiffres et espaces (code collé « 123 456 »), nettoyés ensuite.
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _verifierCode(),
          style: const TextStyle(fontSize: 22, letterSpacing: 6),
          decoration: const InputDecoration(labelText: 'Code reçu par e-mail', border: OutlineInputBorder()),
        ),
        if (_erreur != null) _ErreurFormulaire(_erreur!),
        const SizedBox(height: 18),
        _BoutonAction(libelle: 'Valider le code', enCours: _enCours, onPressed: _verifierCode),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: _enCours ? null : _envoyerCode, child: const Text('Renvoyer le code')),
            TextButton(onPressed: _enCours ? null : _changerAdresse, child: const Text('Changer d’adresse')),
          ],
        ),
      ];
}

/// Bouton principal d'un formulaire, avec indicateur pendant la demande.
class _BoutonAction extends StatelessWidget {
  const _BoutonAction({required this.libelle, required this.enCours, required this.onPressed});

  final String libelle;
  final bool enCours;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enCours ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: enCours
          ? Semantics(
              label: 'Envoi en cours',
              child: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Couleurs.encre),
              ),
            )
          : Text(libelle, textAlign: TextAlign.center),
    );
  }
}

// ---------------------------------------------------------------------------
// Mes enfants
// ---------------------------------------------------------------------------

/// Profils enfants du compte connecté : ajout, modification, suppression,
/// choix du profil utilisé sur ce téléphone, déconnexion.
class MesEnfants extends StatefulWidget {
  const MesEnfants({super.key});

  @override
  State<MesEnfants> createState() => _MesEnfantsState();
}

/// Ce dont la liste a besoin : les profils, les classes pour afficher leur
/// nom et les proposer dans la fiche, et les téléphones liés (D32 ; `null`
/// s'ils n'ont pas pu être chargés : la liste s'affiche quand même).
typedef _DonneesEnfants = ({List<Enfant> enfants, List<Classe> classes, List<AppareilLie>? appareils});

class _MesEnfantsState extends State<MesEnfants> {
  late AppScope _scope;
  Future<_DonneesEnfants>? _chargement;
  EnfantActif? _actif;

  /// Une opération (ajout, suppression…) est en cours : boutons désactivés
  /// pour éviter un double envoi.
  bool _occupe = false;

  /// Compte rédacteur : bouton « Leçons à vérifier » (phase 4).
  bool _redacteur = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    if (_chargement == null) {
      _chargement = _charger();
      _scope.preferences.enfantActif().then((e) {
        if (mounted) setState(() => _actif = e);
      });
      _scope.redaction.estRedacteur().then((r) {
        if (mounted) setState(() => _redacteur = r);
      }, onError: (Object _) {});
    }
  }

  Future<_DonneesEnfants> _charger() async {
    // En parallèle : les classes viennent de la copie locale (immédiat), les
    // profils du serveur.
    final (enfants, classes, appareils) = await (
      _scope.compte.enfants(),
      _scope.repository.classes(),
      // Les téléphones liés ne doivent pas empêcher d'afficher les profils.
      _scope.compte.appareils().then<List<AppareilLie>?>((a) => a, onError: (Object _) => null),
    ).wait;
    return (enfants: enfants, classes: classes, appareils: appareils);
  }

  void _recharger() => setState(() { _chargement = _charger(); });

  void _annoncer(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Exécute une opération sur les profils, affiche l'erreur éventuelle,
  /// puis recharge la liste.
  Future<void> _operation(Future<void> Function() action) async {
    setState(() => _occupe = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _annoncer(messageErreurCompte(e));
    } finally {
      if (mounted) {
        setState(() => _occupe = false);
        _recharger();
      }
    }
  }

  Future<void> _ajouter(List<Classe> classes) async {
    final saisie = await afficherFicheEnfant(context, classes: classes);
    if (saisie == null || !mounted) return;
    await _operation(() async {
      final enfant = await _scope.compte.ajouterEnfant(prenom: saisie.prenom, classeId: saisie.classeId);
      // Premier profil du compte : on le choisit d'office pour ce téléphone.
      if (_actif == null) await _utiliser(enfant, annoncer: false);
      if (mounted) _annoncer('Profil de ${enfant.prenom} ajouté.');
    });
  }

  Future<void> _modifier(Enfant enfant, List<Classe> classes) async {
    final saisie = await afficherFicheEnfant(context, classes: classes, enfant: enfant);
    if (saisie == null || !mounted) return;
    await _operation(() async {
      final modifie = await _scope.compte.modifierEnfant(
        Enfant(id: enfant.id, prenom: saisie.prenom, classeId: saisie.classeId),
      );
      // Le profil de ce téléphone garde son prénom et sa classe à jour.
      if (_actif?.id == modifie.id) await _utiliser(modifie, annoncer: false);
      if (mounted) _annoncer('Profil de ${modifie.prenom} modifié.');
    });
  }

  Future<void> _supprimer(Enfant enfant) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le profil de ${enfant.prenom} ?'),
        content: const Text('Le profil sera supprimé sur tous vos téléphones. Les leçons restent accessibles.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Couleurs.faux),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    await _operation(() async {
      await _scope.compte.supprimerEnfant(enfant.id);
      if (_actif?.id == enfant.id) {
        await _scope.preferences.choisirEnfant(null);
        if (mounted) setState(() => _actif = null);
      }
      if (mounted) _annoncer('Profil de ${enfant.prenom} supprimé.');
    });
  }

  /// « Lier un téléphone » : le code à donner à l'enfant (D32), puis la
  /// liste des téléphones rechargée.
  Future<void> _lierTelephone(Enfant enfant) async {
    await afficherCodeLiaison(context, compte: _scope.compte, enfant: enfant);
    if (mounted) _recharger();
  }

  Future<void> _delierTelephone(Enfant enfant, AppareilLie appareil) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Délier ce téléphone ?'),
        content: Text(
          'Ce téléphone (${libelleAppareil(appareil)}) n’enverra plus le suivi ${dePrenom(enfant.prenom)}. '
          'Ce qui a déjà été envoyé reste dans son suivi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Couleurs.faux),
            child: const Text('Délier'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _occupe = true);
    try {
      await _scope.compte.delierAppareil(appareil.id);
      if (mounted) _annoncer('Le téléphone ${dePrenom(enfant.prenom)} est délié.');
    } catch (e) {
      if (mounted) _annoncer(messageErreurParentLiaison(e));
    } finally {
      if (mounted) {
        setState(() => _occupe = false);
        _recharger();
      }
    }
  }

  /// Retient [enfant] comme profil de ce téléphone et choisit sa classe à
  /// l'accueil.
  Future<void> _utiliser(Enfant enfant, {bool annoncer = true}) async {
    final actif = EnfantActif(id: enfant.id, prenom: enfant.prenom);
    await _scope.preferences.choisirEnfant(actif);
    await _scope.preferences.choisirClasse(enfant.classeId);
    if (!mounted) return;
    setState(() => _actif = actif);
    if (annoncer) _annoncer('${enfant.prenom} utilise maintenant ce téléphone.');
  }

  /// Suppression définitive du compte (exigence de Google Play), après une
  /// confirmation où l'on tape son adresse e-mail.
  Future<void> _supprimerCompte() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmationSuppression(email: _scope.compte.email),
    );
    if (confirme != true || !mounted) return;
    setState(() => _occupe = true);
    try {
      await _scope.compte.supprimerCompte();
      // Rien de ce compte ne doit rester sur le téléphone.
      await _scope.preferences.choisirEnfant(null);
      await _scope.suivi.viderFile();
      if (mounted) _annoncer('Votre compte a été supprimé.');
    } catch (e) {
      if (mounted) {
        _annoncer(messageErreurCompte(e));
        setState(() => _occupe = false);
      }
    }
    // En cas de succès, CompteScreen remplace cette vue par la connexion.
  }

  Future<void> _deconnecter() async {
    setState(() => _occupe = true);
    try {
      // Le profil de ce téléphone appartient au compte : on l'oublie aussi.
      await _scope.preferences.choisirEnfant(null);
      await _scope.compte.deconnecter();
    } catch (e) {
      if (mounted) {
        _annoncer(messageErreurCompte(e));
        setState(() => _occupe = false);
      }
    }
    // En cas de succès, CompteScreen remplace cette vue par la connexion.
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DonneesEnfants>(
      future: _chargement,
      builder: (context, instantane) {
        final Widget corps;
        if (instantane.hasError) {
          corps = MessageErreur(erreur: instantane.error!, onReessayer: _recharger);
        } else if (!instantane.hasData) {
          corps = const Padding(padding: EdgeInsets.all(32), child: Chargement());
        } else {
          corps = _liste(instantane.data!);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
          children: [
            _Entete(texte: 'Connecté avec ${_scope.compte.email}.'),
            // Rédacteurs (phase 4) : toujours visible, même sans profil enfant.
            if (_redacteur)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/validation'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Leçons à vérifier'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            const SizedBox(height: 20),
            corps,
            const SizedBox(height: 28),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _occupe ? null : _deconnecter,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Se déconnecter'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _occupe ? null : _supprimerCompte,
                style: TextButton.styleFrom(foregroundColor: Couleurs.faux),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Supprimer mon compte'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _liste(_DonneesEnfants donnees) {
    final ajouter = OutlinedButton.icon(
      onPressed: _occupe ? null : () => _ajouter(donnees.classes),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Ajouter un enfant'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
    if (donnees.enfants.isEmpty) {
      return MessageVide(
        titre: 'Aucun profil pour l’instant',
        texte: 'Ajoutez le profil de votre enfant : son prénom et sa classe suffisent.',
        action: FilledButton.icon(
          onPressed: _occupe ? null : () => _ajouter(donnees.classes),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter un enfant'),
        ),
      );
    }
    final libelles = {for (final c in donnees.classes) c.id: c.libelle};
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Suivi du travail des enfants (phase 3).
          FilledButton.icon(
            onPressed: () => context.push('/suivi'),
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Voir le suivi de mes enfants'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 24),
          Semantics(header: true, child: const Text('Mes enfants', style: Styles.sectionTitre)),
          const SizedBox(height: 10),
          for (final e in donnees.enfants)
            _CarteEnfant(
              enfant: e,
              classe: libelles[e.classeId] ?? 'Classe inconnue',
              actif: _actif?.id == e.id,
              occupe: _occupe,
              appareils: donnees.appareils == null ? null : appareilsDe(donnees.appareils!, e.id),
              onUtiliser: () => _utiliser(e),
              onModifier: () => _modifier(e, donnees.classes),
              onSupprimer: () => _supprimer(e),
              onLier: () => _lierTelephone(e),
              onDelier: (a) => _delierTelephone(e, a),
            ),
          // 10 profils au plus par compte (règle de la base) : bouton masqué
          // une fois la limite atteinte plutôt qu'une erreur après coup.
          if (donnees.enfants.length < 10) ...[const SizedBox(height: 6), ajouter],
        ],
      ),
    );
  }
}

/// Confirmation de la suppression du compte : on explique ce qui disparaît,
/// puis on fait taper l'adresse e-mail du compte.
class _ConfirmationSuppression extends StatefulWidget {
  const _ConfirmationSuppression({required this.email});

  final String? email;

  @override
  State<_ConfirmationSuppression> createState() => _ConfirmationSuppressionState();
}

class _ConfirmationSuppressionState extends State<_ConfirmationSuppression> {
  final _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valide = confirmationSuppression(_champ.text, widget.email);
    return AlertDialog(
      title: const Text('Supprimer votre compte ?'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Votre compte, les profils de vos enfants et tout leur suivi (leçons lues, résultats) '
            'seront supprimés définitivement. Les leçons restent accessibles sans compte.',
            style: TextStyle(fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 16),
          Text('Pour confirmer, tapez votre adresse : ${widget.email ?? ''}', style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 8),
          TextField(
            controller: _champ,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Adresse e-mail', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: valide ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: Couleurs.faux),
          child: const Text('Supprimer définitivement'),
        ),
      ],
    );
  }
}

class _CarteEnfant extends StatelessWidget {
  const _CarteEnfant({
    required this.enfant,
    required this.classe,
    required this.actif,
    required this.occupe,
    required this.appareils,
    required this.onUtiliser,
    required this.onModifier,
    required this.onSupprimer,
    required this.onLier,
    required this.onDelier,
  });

  final Enfant enfant;
  final String classe;
  final bool actif;
  final bool occupe;

  /// Téléphones liés à ce profil (D32) ; `null` s'ils n'ont pas pu être
  /// chargés.
  final List<AppareilLie>? appareils;
  final VoidCallback onUtiliser;
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;
  final VoidCallback onLier;
  final ValueChanged<AppareilLie> onDelier;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: Couleurs.papier,
        borderRadius: BorderRadius.circular(16),
        // Profil de ce téléphone : bordure encre, mais aussi le texte
        // « Utilisé sur ce téléphone » (pas la couleur seule).
        border: Border.all(color: actif ? Couleurs.encre : Couleurs.bordureCarte, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(enfant.prenom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(classe, style: const TextStyle(fontSize: 15, color: Couleurs.texteDoux)),
          if (actif) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.phone_android_rounded, size: 18, color: Couleurs.encre),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Utilisé sur ce téléphone',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.encre),
                  ),
                ),
              ],
            ),
          ],
          // Téléphones de l'enfant liés par un code (D32).
          for (final a in appareils ?? const <AppareilLie>[])
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.phonelink_lock_outlined, size: 18, color: Couleurs.texteDoux),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      libelleAppareil(a),
                      style: const TextStyle(fontSize: 14, color: Couleurs.texteDoux),
                    ),
                  ),
                  TextButton(
                    onPressed: occupe ? null : () => onDelier(a),
                    style: TextButton.styleFrom(foregroundColor: Couleurs.faux),
                    child: Text('Délier', semanticsLabel: 'Délier ce téléphone ${dePrenom(enfant.prenom)}'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // Wrap : à 200 % de taille de texte, les boutons passent à la ligne.
          Wrap(
            children: [
              TextButton(
                onPressed: occupe ? null : onLier,
                child: Text('Lier un téléphone', semanticsLabel: 'Lier le téléphone ${dePrenom(enfant.prenom)}'),
              ),
              if (!actif)
                TextButton(onPressed: occupe ? null : onUtiliser, child: const Text('Utiliser sur ce téléphone')),
              TextButton(
                onPressed: occupe ? null : onModifier,
                child: Text('Modifier', semanticsLabel: 'Modifier le profil de ${enfant.prenom}'),
              ),
              TextButton(
                onPressed: occupe ? null : onSupprimer,
                style: TextButton.styleFrom(foregroundColor: Couleurs.faux),
                child: Text('Supprimer', semanticsLabel: 'Supprimer le profil de ${enfant.prenom}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
