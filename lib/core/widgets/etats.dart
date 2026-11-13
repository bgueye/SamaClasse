import 'package:flutter/material.dart';

import '../theme/couleurs.dart';

/// Indicateur de chargement centré, annoncé aux lecteurs d'écran.
class Chargement extends StatelessWidget {
  const Chargement({super.key, this.message = 'Chargement…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: message,
        liveRegion: true,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

/// Erreur de chargement, avec un bouton pour réessayer.
class MessageErreur extends StatelessWidget {
  const MessageErreur({super.key, required this.erreur, this.onReessayer});

  final Object erreur;
  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context) {
    return _Message(
      icone: Icons.wifi_off_rounded,
      titre: 'Impossible de charger',
      texte: 'Vérifie ta connexion internet, puis réessaie.',
      details: erreur.toString(),
      action: onReessayer == null
          ? null
          : FilledButton(onPressed: onReessayer, child: const Text('Réessayer')),
    );
  }
}

/// Écran ou bloc sans contenu (aucune leçon publiée, liste vide…).
class MessageVide extends StatelessWidget {
  const MessageVide({super.key, required this.titre, required this.texte, this.action});

  final String titre;
  final String texte;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _Message(icone: Icons.menu_book_outlined, titre: titre, texte: texte, action: action);
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icone,
    required this.titre,
    required this.texte,
    this.details,
    this.action,
  });

  final IconData icone;
  final String titre;
  final String texte;
  final String? details;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 40, color: Couleurs.texteSecondaire),
              const SizedBox(height: 16),
              Text(
                titre,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                texte,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5, color: Couleurs.texteDoux),
              ),
              if (details != null) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Détails techniques', style: TextStyle(fontSize: 14)),
                  children: [
                    SelectableText(details!, style: const TextStyle(fontSize: 12, color: Couleurs.texteSecondaire)),
                  ],
                ),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}
