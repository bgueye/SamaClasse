import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_scope.dart';
import '../../core/theme/couleurs.dart';
import '../../core/theme/matieres.dart';
import '../../core/widgets/composants.dart';
import '../../core/widgets/etats.dart';
import '../../data/data.dart';
import '../accueil/accueil_screen.dart' show detailMatiere;
import 'regroupement.dart';

enum _Filtre { tout, prets }

class _DonneesMatiere {
  const _DonneesMatiere(this.classe, this.matiere, this.chapitres);

  final Classe? classe;
  final MatiereDeClasse? matiere;
  final List<Chapitre> chapitres;
}

/// Chapitres d'une matière dans une classe, regroupés par partie.
class MatiereScreen extends StatefulWidget {
  const MatiereScreen({super.key, required this.classeId, required this.matiereId});

  final int classeId;
  final int matiereId;

  @override
  State<MatiereScreen> createState() => _MatiereScreenState();
}

class _MatiereScreenState extends State<MatiereScreen> {
  Future<_DonneesMatiere>? _chargement;
  _Filtre _filtre = _Filtre.tout;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chargement ??= _charger();
  }

  Future<_DonneesMatiere> _charger() async {
    final repo = AppScope.of(context).repository;
    final resultats = await Future.wait<Object>([
      repo.classes(),
      repo.matieres(widget.classeId),
      repo.chapitres(classeId: widget.classeId, matiereId: widget.matiereId),
    ]);
    final classes = resultats[0] as List<Classe>;
    final matieres = resultats[1] as List<MatiereDeClasse>;
    return _DonneesMatiere(
      classes.where((c) => c.id == widget.classeId).firstOrNull,
      matieres.where((m) => m.matiereId == widget.matiereId).firstOrNull,
      resultats[2] as List<Chapitre>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_DonneesMatiere>(
          future: _chargement,
          builder: (context, instantane) {
            if (instantane.hasError) {
              return Column(
                children: [
                  const LienRetour(libelle: 'Mes cours'),
                  Expanded(
                    child: MessageErreur(
                      erreur: instantane.error!,
                      onReessayer: () => setState(() { _chargement = _charger(); }),
                    ),
                  ),
                ],
              );
            }
            if (!instantane.hasData) return const Chargement();
            return _contenu(instantane.data!);
          },
        ),
      ),
    );
  }

  Widget _contenu(_DonneesMatiere d) {
    final chapitres = _filtre == _Filtre.prets ? d.chapitres.where((c) => c.aUneLecon) : d.chapitres;
    final parties = regrouperParPartie(chapitres);

    return LargeurLecture(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Entete(donnees: d, filtre: _filtre, onFiltre: (f) => setState(() => _filtre = f)),
          Expanded(
            child: parties.isEmpty
                ? MessageVide(
                    titre: _filtre == _Filtre.prets ? 'Aucune leçon prête' : 'Aucun chapitre',
                    texte: _filtre == _Filtre.prets
                        ? 'Les leçons de cette matière arrivent bientôt.'
                        : 'Le programme de cette matière n’a pas encore été ajouté.',
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      final f = _charger();
                      setState(() { _chargement = f; });
                      await f;
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: parties.length,
                      itemBuilder: (context, i) => _BlocPartie(partie: parties[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.donnees, required this.filtre, required this.onFiltre});

  final _DonneesMatiere donnees;
  final _Filtre filtre;
  final ValueChanged<_Filtre> onFiltre;

  @override
  Widget build(BuildContext context) {
    final m = donnees.matiere;
    final sousTitre = [
      if (donnees.classe != null) donnees.classe!.libelle,
      if (m != null) detailMatiere(m),
    ].join(', ');

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Couleurs.papier,
        border: Border(bottom: BorderSide(color: Couleurs.bordure)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LienRetour(libelle: 'Mes cours'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DosCahier(couleur: couleurMatiere(m?.slug), largeur: 10, hauteur: null),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              m?.nom ?? 'Matière',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
                            ),
                          ),
                          if (sousTitre.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(sousTitre, style: const TextStyle(fontSize: 14, color: Couleurs.texteSecondaire)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (f, libelle) in const [
                    (_Filtre.tout, 'Tous les chapitres'),
                    (_Filtre.prets, 'Leçons prêtes'),
                  ])
                    ChoiceChip(
                      label: Text(libelle),
                      selected: filtre == f,
                      showCheckmark: false,
                      selectedColor: Couleurs.encre,
                      labelStyle: TextStyle(
                        color: filtre == f ? Couleurs.texteSurEncre : Couleurs.texte,
                        fontWeight: FontWeight.w600,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => onFiltre(f),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlocPartie extends StatelessWidget {
  const _BlocPartie({required this.partie});

  final PartieDeChapitres partie;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (partie.titre != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Semantics(
                header: true,
                child: Text(
                  partie.titre!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Couleurs.texteSecondaire,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          for (final c in partie.chapitres) ...[
            _LigneChapitre(chapitre: c),
            const Divider(),
          ],
        ],
      ),
    );
  }
}

class _LigneChapitre extends StatelessWidget {
  const _LigneChapitre({required this.chapitre});

  final Chapitre chapitre;

  @override
  Widget build(BuildContext context) {
    final pret = chapitre.aUneLecon;
    final ligne = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${chapitre.numero}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: pret ? Couleurs.encre : Couleurs.texteAttente,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapitre.titre,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: pret ? FontWeight.w600 : FontWeight.w400,
                    color: pret ? Couleurs.texte : Couleurs.texteDoux,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  etatChapitre(chapitre),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: pret ? FontWeight.w600 : FontWeight.w400,
                    color: pret ? Couleurs.juste : Couleurs.texteSecondaire,
                  ),
                ),
                // Plusieurs leçons dans le chapitre : un lien par leçon.
                if (chapitre.lecons.length > 1)
                  for (final l in chapitre.lecons)
                    TextButton(
                      onPressed: () => context.push('/lecon/${l.id}'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                      child: Text('Leçon ${l.numero} : ${l.titre}'),
                    ),
              ],
            ),
          ),
          if (chapitre.lecons.length == 1)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right_rounded, color: Couleurs.texteSecondaire),
            ),
        ],
      ),
    );

    if (chapitre.lecons.length != 1) return ligne;
    return InkWell(
      onTap: () => context.push('/lecon/${chapitre.lecons.single.id}'),
      child: ligne,
    );
  }
}
