import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/data.dart';
import 'app_scope.dart';

/// Recharge un écran quand une synchronisation apporte du contenu nouveau
/// (une leçon publiée pendant que l'élève lisait la liste, par exemple).
///
/// L'écran fournit [recharger] (en général
/// `setState(() { _chargement = _charger(); })`). Les données viennent alors
/// de la copie locale déjà à jour : le rechargement est immédiat.
///
/// À ne pas utiliser sur l'écran d'exercices : recharger effacerait les
/// réponses en cours de l'élève.
mixin RechargeSiNouveauContenu<T extends StatefulWidget> on State<T> {
  ValueListenable<EtatContenu>? _etat;
  int _version = 0;

  void recharger();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final etat = AppScope.of(context).repository.etat;
    if (!identical(etat, _etat)) {
      _etat?.removeListener(_surChangement);
      _etat = etat..addListener(_surChangement);
      _version = etat.value.version;
    }
  }

  void _surChangement() {
    final version = _etat!.value.version;
    if (version == _version) return; // Seul le bandeau a changé.
    _version = version;
    if (mounted) recharger();
  }

  @override
  void dispose() {
    _etat?.removeListener(_surChangement);
    super.dispose();
  }
}
