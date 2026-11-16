import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/services/preferences.dart';
import '../../core/theme/couleurs.dart';
import '../../core/widgets/composants.dart';
import 'outils_liaison.dart';

/// « J'ai un code de mon parent » (D32), à l'adresse `/lier`.
///
/// Sur le téléphone de l'enfant : il tape le code que son parent lui donne
/// (affiché sur le téléphone du parent). Le téléphone est alors lié à son
/// profil : ses leçons lues et ses résultats partent vers le suivi de son
/// parent, sans qu'il ait le compte de son parent. Tutoiement : l'écran
/// s'adresse à l'enfant.
class LierScreen extends StatelessWidget {
  const LierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compte = AppScope.of(context).compte;
    return Scaffold(
      body: SafeArea(
        child: LargeurLecture(
          child: ListenableBuilder(
            listenable: compte,
            builder: (context, _) => compte.estConnecte ? const _CompteParentOuvert() : const _SaisieCode(),
          ),
        ),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LienRetour(libelle: 'Retour', repli: '/compte'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Lier ce téléphone',
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

/// Un compte parent est ouvert sur ce téléphone : il faut d'abord le fermer
/// (sinon l'enfant garderait l'accès au compte de son parent).
class _CompteParentOuvert extends StatefulWidget {
  const _CompteParentOuvert();

  @override
  State<_CompteParentOuvert> createState() => _CompteParentOuvertState();
}

class _CompteParentOuvertState extends State<_CompteParentOuvert> {
  bool _enCours = false;

  Future<void> _deconnecter() async {
    setState(() => _enCours = true);
    final scope = AppScope.of(context);
    try {
      // Ce qui attendait part d'abord, sous le compte du parent.
      await scope.suivi.envoyer();
      await scope.preferences.choisirEnfant(null);
      await scope.compte.deconnecter();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pas de connexion internet. Vérifie le réseau, puis réessaie.')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AppScope.of(context).compte.email;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
      children: [
        _Entete(
          texte: 'Ce téléphone est connecté au compte parent $email. Pour le lier au profil d’un enfant, '
              'ce compte doit d’abord être déconnecté de ce téléphone.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 0, 0),
          child: FilledButton(
            onPressed: _enCours ? null : _deconnecter,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Déconnecter le compte parent', textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

class _SaisieCode extends StatefulWidget {
  const _SaisieCode();

  @override
  State<_SaisieCode> createState() => _SaisieCodeState();
}

class _SaisieCodeState extends State<_SaisieCode> {
  final _champ = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  Future<void> _lier() async {
    if (_enCours) return;
    final code = nettoyerCodeLiaison(_champ.text);
    if (!codeLiaisonComplet(code)) {
      setState(() => _erreur = 'Tape les 6 chiffres du code affiché sur le téléphone de ton parent.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    final scope = AppScope.of(context);
    try {
      final enfant = await scope.compte.lierCeTelephone(code);
      await scope.preferences.choisirEnfant(EnfantActif(id: enfant.id, prenom: enfant.prenom, lie: true));
      await scope.preferences.choisirClasse(enfant.classeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bonjour ${enfant.prenom} ! Ce téléphone est maintenant lié à ton profil.')),
      );
      // Retour à l'accueil en refermant les pages ouvertes (« Lier », espace
      // parents) : l'accueil relit alors le profil (« Bonjour Awa ! »). Un
      // simple `go('/')` garderait l'accueil tel qu'il était avant.
      final routeur = GoRouter.of(context);
      if (!routeur.canPop()) {
        routeur.go('/');
        return;
      }
      while (routeur.canPop()) {
        routeur.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreurLiaison(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
      children: [
        const _Entete(
          texte: 'Demande à ton parent d’ouvrir SamaClasse sur son téléphone : Espace parents, puis '
              '« Lier un téléphone » sous ton prénom. Tape ici le code qui s’affiche.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _champ,
                enabled: !_enCours,
                autofocus: true,
                keyboardType: TextInputType.number,
                // Chiffres et espaces (« 482 913 »), nettoyés ensuite.
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                  LengthLimitingTextInputFormatter(9),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _lier(),
                style: const TextStyle(fontSize: 26, letterSpacing: 8),
                decoration: const InputDecoration(labelText: 'Code de ton parent', border: OutlineInputBorder()),
              ),
              if (_erreur != null)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Couleurs.fauxFond, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Couleurs.faux, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_erreur!, style: const TextStyle(fontSize: 15, height: 1.4, color: Couleurs.fauxTexte)),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _enCours ? null : _lier,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _enCours
                    ? Semantics(
                        label: 'Liaison en cours',
                        child: const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Couleurs.encre),
                        ),
                      )
                    : const Text('Lier ce téléphone'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tes leçons lues et tes résultats aux exercices seront envoyés à ton parent. Ce que tu '
                'écris dans les exercices reste sur ton téléphone.',
                style: TextStyle(fontSize: 14, height: 1.45, color: Couleurs.texteSecondaire),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
