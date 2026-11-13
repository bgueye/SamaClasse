import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/recharge.dart';
import '../../core/services/preferences.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/matieres.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../data/data.dart';

/// Accueil élève : choix de la classe, reprise de la dernière leçon,
/// liste des matières avec leurs compteurs.
class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> with RechargeSiNouveauContenu {
  late AppScope _scope;
  Future<List<Classe>>? _classes;
  Future<List<MatiereDeClasse>>? _matieres;
  int? _classeId;
  DerniereLecon? _derniere;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    if (_classes == null) {
      _classes = _chargerClasses();
      _chargerDerniereLecon();
    }
  }

  Future<List<Classe>> _chargerClasses() async {
    final classes = await _scope.repository.classes();
    if (classes.isEmpty) return classes;
    final memorisee = await _scope.preferences.classeChoisie();
    final id = classes.any((c) => c.id == memorisee) ? memorisee! : classes.first.id;
    if (mounted) {
      setState(() {
        _classeId = id;
        _matieres = _chargerMatieres(id);
      });
    }
    return classes;
  }

  /// Lance le chargement des matières d'une classe.
  ///
  /// `ignore()` marque une éventuelle erreur comme prise en charge dès la
  /// création du `Future` : le `FutureBuilder` des matières n'existe qu'au
  /// rendu suivant, et une erreur très rapide (mode avion) serait sinon
  /// signalée comme « non gérée » dans les journaux. Le `FutureBuilder` reçoit
  /// quand même l'erreur et affiche « Réessayer ».
  Future<List<MatiereDeClasse>> _chargerMatieres(int classeId) =>
      _scope.repository.matieres(classeId)..ignore();

  Future<void> _chargerDerniereLecon() async {
    final derniere = await _scope.preferences.derniereLecon();
    if (mounted) setState(() => _derniere = derniere);
  }

  void _choisirClasse(int id) {
    if (id == _classeId) return;
    setState(() {
      _classeId = id;
      _matieres = _chargerMatieres(id);
    });
    _scope.preferences.choisirClasse(id);
  }

  /// Contenu nouveau arrivé en arrière-plan (RechargeSiNouveauContenu).
  @override
  void recharger() => setState(() { _classes = _chargerClasses(); });

  /// Tirer pour actualiser : demande d'abord une mise à jour au serveur
  /// (sans réseau, la copie locale reste et le bandeau s'affiche).
  Future<void> _actualiser() async {
    await _scope.repository.actualiser();
    if (!mounted) return;
    final classes = _chargerClasses();
    setState(() { _classes = classes; });
    await classes;
    await _matieres;
  }

  Future<void> _ouvrir(String chemin) async {
    await context.push(chemin);
    // Au retour, la dernière leçon lue a pu changer.
    await _chargerDerniereLecon();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Classe>>(
          future: _classes,
          builder: (context, instantane) {
            if (instantane.hasError) {
              return MessageErreur(
                erreur: instantane.error!,
                onReessayer: () => setState(() { _classes = _chargerClasses(); }),
              );
            }
            if (!instantane.hasData) return const Chargement();
            final classes = instantane.data!;
            if (classes.isEmpty) {
              return const MessageVide(
                titre: 'Aucune classe pour l’instant',
                texte: 'Le programme n’a pas encore été ajouté.',
              );
            }
            final classe = classes.firstWhere((c) => c.id == _classeId, orElse: () => classes.first);
            return RefreshIndicator(
              onRefresh: _actualiser,
              child: LargeurLecture(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _entete(classes)),
                    if (_derniere != null) SliverToBoxAdapter(child: _CarteReprise(lecon: _derniere!, onTap: () => _ouvrir('/lecon/${_derniere!.id}'))),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
                      sliver: SliverToBoxAdapter(
                        child: Semantics(
                          header: true,
                          child: Text('Tes matières en ${classe.libelle}', style: Styles.sectionTitre),
                        ),
                      ),
                    ),
                    _listeMatieres(),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _entete(List<Classe> classes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'SamaClasse',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Couleurs.encre),
            ),
          ),
          const SizedBox(height: 18),
          if (classes.length > 1)
            ControleSegmente<int>(
              libelleGroupe: 'Choisir la classe',
              options: [for (final c in classes) (c.id, c.libelle)],
              valeur: _classeId,
              onChanged: _choisirClasse,
            ),
        ],
      ),
    );
  }

  Widget _listeMatieres() {
    return FutureBuilder<List<MatiereDeClasse>>(
      future: _matieres,
      builder: (context, instantane) {
        if (instantane.hasError) {
          return SliverToBoxAdapter(
            child: MessageErreur(
              erreur: instantane.error!,
              onReessayer: () => setState(() { _matieres = _chargerMatieres(_classeId!); }),
            ),
          );
        }
        if (!instantane.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(32), child: Chargement()),
          );
        }
        final matieres = instantane.data!;
        if (matieres.isEmpty) {
          return const SliverToBoxAdapter(
            child: MessageVide(
              titre: 'Pas encore de matière',
              texte: 'Le programme de cette classe n’a pas encore été ajouté.',
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.separated(
            itemCount: matieres.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final m = matieres[i];
              return _LigneMatiere(
                matiere: m,
                onTap: () => _ouvrir('/classe/${m.classeId}/matiere/${m.matiereId}'),
              );
            },
          ),
        );
      },
    );
  }
}

/// Sous-titre d'une matière : « 1 leçon prête sur 12 chapitres »,
/// « Pas encore de leçon, 1 chapitre au programme ». Accorde au singulier
/// quand il n'y a qu'un seul chapitre (Éducation civique en 4ème).
String detailMatiere(MatiereDeClasse m) {
  final chapitres = m.nbChapitres == 1 ? '1 chapitre' : '${m.nbChapitres} chapitres';
  if (m.nbLecons == 0) {
    return 'Pas encore de leçon, $chapitres au programme';
  }
  final lecons = m.nbLecons == 1 ? '1 leçon prête' : '${m.nbLecons} leçons prêtes';
  return '$lecons sur $chapitres';
}

class _LigneMatiere extends StatelessWidget {
  const _LigneMatiere({required this.matiere, required this.onTap});

  final MatiereDeClasse matiere;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              DosCahier(couleur: couleurMatiere(matiere.slug)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(matiere.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(detailMatiere(matiere), style: Styles.secondaire),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Couleurs.texteSecondaire),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteReprise extends StatelessWidget {
  const _CarteReprise({required this.lecon, required this.onTap});

  final DerniereLecon lecon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: const Text('Reprendre où tu t’es arrêté', style: Styles.sectionTitre)),
          const SizedBox(height: 10),
          Material(
            color: Couleurs.papier,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Couleurs.bordureCarte, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  const Positioned(
                    left: 20,
                    top: 0,
                    bottom: 0,
                    child: ExcludeSemantics(child: SizedBox(width: 2, child: ColoredBox(color: Couleurs.marge))),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(34, 18, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${lecon.matiere}, ${lecon.classe}', style: Styles.etiquette.copyWith(fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(lecon.titre, style: Styles.cahier(taille: 19)),
                        const SizedBox(height: 14),
                        const ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Couleurs.encre,
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              child: Text(
                                'Continuer la lecture',
                                style: TextStyle(color: Couleurs.texteSurEncre, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
