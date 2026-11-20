// « Envoyer cette leçon » et « Fiche à imprimer » (D35, maquettes `Partage`
// et `Fiche`), ouverts depuis l'en-tête de l'écran de leçon.

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/couleurs.dart';
import '../../data/data.dart';
import '../fiche/contenu_fiche.dart';
import '../fiche/fiche_pdf.dart';

/// Message envoyé avec le lien d'une leçon :
/// « Révise « L'Afrique au XVIe siècle » (histoire, 4ème) sur SamaClasse : https://… ».
String messageEnvoi(Lecon lecon) {
  final c = lecon.contexte;
  final ou = c == null ? '' : ' (${c.matiere.toLowerCase()}, ${c.classe})';
  return 'Révise « ${lecon.titre} »$ou sur SamaClasse : ${lienLecon(lecon.id)}';
}

/// Fenêtre « Envoyer cette leçon » : le message, puis l'envoi par une autre
/// application ou la copie du lien.
Future<void> afficherEnvoi(BuildContext context, Lecon lecon) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Couleurs.papier,
    builder: (context) => _FenetreEnvoi(lecon: lecon),
  );
}

class _FenetreEnvoi extends StatefulWidget {
  const _FenetreEnvoi({required this.lecon});

  final Lecon lecon;

  @override
  State<_FenetreEnvoi> createState() => _FenetreEnvoiState();
}

class _FenetreEnvoiState extends State<_FenetreEnvoi> {
  /// Retour affiché sous les boutons (« Lien copié. »).
  String _statut = '';

  Future<void> _faire(Future<void> Function() action, String reussite) async {
    try {
      await action();
      if (mounted) setState(() => _statut = reussite);
    } catch (_) {
      if (mounted) setState(() => _statut = 'L’envoi n’a pas marché. Copie le lien à la place.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final partage = AppScope.of(context).partage;
    final message = messageEnvoi(widget.lecon);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: const Text(
                'Envoyer cette leçon',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Couleurs.texte),
              ),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Couleurs.fond,
                border: Border.all(color: Couleurs.bordureCarte, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Message envoyé',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Couleurs.texteSecondaire),
                    ),
                    const SizedBox(height: 6),
                    Text(message, style: const TextStyle(fontSize: 15, height: 1.5, color: Couleurs.texte)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Le lien ouvre la leçon dans le navigateur, sans compte. Elle se lit aussi dans l’application.',
              style: TextStyle(fontSize: 14, height: 1.45, color: Couleurs.texteDoux),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _faire(
                () => partage.envoyer(message, sujet: widget.lecon.titre),
                'Choisis l’application : WhatsApp, SMS…',
              ),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Envoyer par une application'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _faire(() => partage.copier(lienLecon(widget.lecon.id)), 'Lien copié.'),
              icon: const Icon(Icons.link_rounded),
              label: const Text('Copier le lien'),
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _statut,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Couleurs.justeTexte),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ouvre l'aperçu d'impression de la fiche de [lecon] (fiche puis corrigé).
///
/// Le PDF se fabrique sur l'appareil, hors connexion. Une erreur s'affiche
/// dans un message en bas d'écran ; elle ne bloque rien d'autre.
Future<void> imprimerFiche(BuildContext context, Lecon lecon) async {
  final scope = AppScope.of(context);
  final messager = ScaffoldMessenger.of(context);
  try {
    await scope.impression.imprimer(
      nom: nomFiche(lecon),
      document: () async => fabriquerFichePdf(contenuFiche(lecon), await chargerPolicesFiche()),
    );
  } catch (_) {
    messager.showSnackBar(const SnackBar(content: Text('Impossible de préparer la fiche. Réessaie dans un instant.')));
  }
}
