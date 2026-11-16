import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/services/preferences.dart';
import '../../core/theme/couleurs.dart';
import '../../core/widgets/composants.dart';
import 'outils_liaison.dart';

/// Espace parents d'un téléphone d'enfant lié (D32) : pas de compte, pas de
/// profils, seulement « Ce téléphone est celui d'Awa » et « Ce n'est plus mon
/// téléphone ». Tutoiement.
class TelephoneLie extends StatefulWidget {
  const TelephoneLie({super.key, required this.enfant});

  final EnfantActif enfant;

  @override
  State<TelephoneLie> createState() => _TelephoneLieState();
}

class _TelephoneLieState extends State<TelephoneLie> {
  bool _enCours = false;

  Future<void> _delier() async {
    final prenom = widget.enfant.prenom;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ce n’est plus ton téléphone ?'),
        content: Text(
          'Ce téléphone ne sera plus lié au profil ${dePrenom(prenom)} : il n’enverra plus rien à ton parent. '
          'Ce qui a déjà été envoyé reste dans son suivi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Couleurs.faux),
            child: const Text('Délier ce téléphone'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _enCours = true);
    final scope = AppScope.of(context);
    try {
      // Ce qui attend part d'abord : c'est encore le téléphone de l'enfant.
      await scope.suivi.envoyer();
      await scope.compte.delierCeTelephone();
      await scope.preferences.choisirEnfant(null);
      await scope.suivi.viderFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce téléphone n’est plus lié.')));
      }
      // L'espace parents repasse tout seul à la connexion (compte écouté).
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreurLiaison(e))));
        setState(() => _enCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prenom = widget.enfant.prenom;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
      children: [
        const LienRetour(libelle: 'Mes cours'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Téléphone ${dePrenom(prenom)}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Couleurs.encre),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Couleurs.selection, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.phone_android_rounded, color: Couleurs.encre),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ce téléphone est lié au profil ${dePrenom(prenom)}. Tes leçons lues et tes résultats aux '
                        'exercices sont envoyés à ton parent, qui suit ton travail sur son téléphone.',
                        style: const TextStyle(fontSize: 16, height: 1.5, color: Couleurs.texte),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ce que tu écris dans les exercices reste sur ton téléphone : seuls le résultat et le '
                'score partent.',
                style: TextStyle(fontSize: 14, height: 1.45, color: Couleurs.texteSecondaire),
              ),
              const SizedBox(height: 28),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _enCours ? null : _delier,
                  style: TextButton.styleFrom(foregroundColor: Couleurs.faux),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Ce n’est plus mon téléphone'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
