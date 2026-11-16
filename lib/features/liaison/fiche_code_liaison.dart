import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/couleurs.dart';
import '../../data/data.dart';
import 'outils_liaison.dart';

/// Ouvre la fenêtre « Lier un téléphone » pour le profil [enfant].
///
/// Se termine quand la fenêtre se ferme : l'espace parents recharge alors
/// la liste des téléphones liés.
Future<void> afficherCodeLiaison(BuildContext context, {required Compte compte, required Enfant enfant}) =>
    showDialog<void>(
      context: context,
      builder: (context) => FicheCodeLiaison(compte: compte, enfant: enfant, maintenant: DateTime.now),
    );

/// Code de liaison en grand, avec son temps de validité qui défile, et la
/// marche à suivre sur le téléphone de l'enfant (D32). Vouvoiement : la
/// fenêtre s'adresse au parent.
class FicheCodeLiaison extends StatefulWidget {
  const FicheCodeLiaison({super.key, required this.compte, required this.enfant, required this.maintenant});

  final Compte compte;
  final Enfant enfant;

  /// Horloge (remplaçable dans les tests).
  final DateTime Function() maintenant;

  @override
  State<FicheCodeLiaison> createState() => _FicheCodeLiaisonState();
}

class _FicheCodeLiaisonState extends State<FicheCodeLiaison> {
  late Future<CodeLiaison> _code;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _demander();
  }

  /// Demande un code, puis fait défiler le temps restant chaque seconde.
  /// Le minuteur s'arrête à l'expiration : plus rien ne bouge à l'écran.
  void _demander() {
    _minuteur?.cancel();
    _code = widget.compte.creerCodeLiaison(widget.enfant.id);
    _code.then((code) {
      if (!mounted) return;
      _minuteur = Timer.periodic(const Duration(seconds: 1), (minuteur) {
        if (!mounted) return minuteur.cancel();
        if (!code.expireLe.isAfter(widget.maintenant())) minuteur.cancel();
        setState(() {});
      });
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  void _nouveauCode() => setState(_demander);

  @override
  Widget build(BuildContext context) {
    final prenom = widget.enfant.prenom;
    return AlertDialog(
      title: Text('Lier le téléphone ${dePrenom(prenom)}'),
      scrollable: true,
      content: FutureBuilder<CodeLiaison>(
        future: _code,
        builder: (context, instantane) {
          if (instantane.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(messageErreurParentLiaison(instantane.error!), style: const TextStyle(fontSize: 15, height: 1.45)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(onPressed: _nouveauCode, child: const Text('Réessayer')),
                ),
              ],
            );
          }
          if (!instantane.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final code = instantane.data!;
          final reste = code.expireLe.difference(widget.maintenant());
          final expire = reste.inSeconds <= 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sur le téléphone ${dePrenom(prenom)} : ouvrez SamaClasse, touchez Espace parents, puis '
                '« J’ai un code de mon parent », et tapez ce code.',
                style: const TextStyle(fontSize: 15, height: 1.45, color: Couleurs.texteDoux),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: expire ? Couleurs.fond : Couleurs.selection,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Semantics(
                  label: expire ? 'Code expiré' : 'Code : ${codeLiaisonEpele(code.code)}',
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formaterCodeLiaison(code.code),
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        color: expire ? Couleurs.texteAttente : Couleurs.encre,
                        decoration: expire ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Semantics(
                liveRegion: expire,
                child: Text(
                  expire
                      ? 'Ce code a expiré. Demandez-en un nouveau.'
                      : 'Valable encore ${libelleTempsRestant(reste)}, une seule fois.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: expire ? FontWeight.w600 : FontWeight.w400,
                    color: expire ? Couleurs.faux : Couleurs.texteDoux,
                  ),
                ),
              ),
              if (expire) ...[
                const SizedBox(height: 10),
                Center(child: FilledButton(onPressed: _nouveauCode, child: const Text('Nouveau code'))),
              ],
              const SizedBox(height: 14),
              const Text(
                'Ce téléphone enverra seulement les leçons lues et les résultats de cet enfant. '
                'Il n’aura pas accès à votre compte.',
                style: TextStyle(fontSize: 13, height: 1.45, color: Couleurs.texteSecondaire),
              ),
            ],
          );
        },
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}
