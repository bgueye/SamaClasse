import 'package:flutter/material.dart';

import '../../data/data.dart';
import '../app_scope.dart';
import '../theme/couleurs.dart';

/// Bandeau discret en haut de l'application quand on lit la copie locale
/// faute de réseau : « Hors connexion · contenu du 13/11/2026 ».
///
/// Placé une seule fois autour de toutes les pages (`MaterialApp.builder`).
/// Quand il est visible, il prend la marge du haut (barre d'état) à sa
/// charge et la retire aux pages, pour qu'elles ne la comptent pas deux fois.
class BandeauHorsConnexion extends StatelessWidget {
  const BandeauHorsConnexion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EtatContenu>(
      valueListenable: AppScope.of(context).repository.etat,
      builder: (context, etat, _) {
        if (!etat.horsConnexion) return child;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Material (et non ColoredBox) : le bandeau est au-dessus des pages,
            // hors de tout Scaffold, et un texte sans Material ancêtre prendrait
            // le style d'erreur de Flutter (souligné jaune).
            Material(
              color: Couleurs.segment,
              child: SafeArea(
                bottom: false,
                child: Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const ExcludeSemantics(
                          child: Icon(Icons.cloud_off_rounded, size: 18, color: Couleurs.texteSecondaire),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            texteHorsConnexion(etat.copieDu),
                            style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
            ),
          ],
        );
      },
    );
  }
}

/// « Hors connexion · contenu du 13/11/2026 ».
String texteHorsConnexion(DateTime? copieDu) {
  if (copieDu == null) return 'Hors connexion';
  final d = copieDu.toLocal();
  String deux(int n) => n.toString().padLeft(2, '0');
  return 'Hors connexion · contenu du ${deux(d.day)}/${deux(d.month)}/${d.year}';
}
