import 'package:flutter/material.dart';

import '../../core/theme/couleurs.dart';
import '../../core/theme/theme.dart';
import '../../core/version.dart';
import '../../core/widgets/composants.dart';

/// Page « À propos » (décision D18) : présentation, origine des leçons,
/// données, version, licences et crédit. Texte relu et validé par Bocar le
/// 13/11/2026 ; pas d'adresse de contact, à sa demande.
///
/// Page fixe, sans chargement : pas d'état d'attente ni d'erreur à gérer.
class AProposScreen extends StatelessWidget {
  const AProposScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LargeurLecture(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
            children: [
              const LienRetour(libelle: 'Mes cours'),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: const Text(
                        'SamaClasse',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Couleurs.encre),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Le programme scolaire du Sénégal, leçon par leçon.', style: Styles.cahier(taille: 18)),
                    const SizedBox(height: 20),
                    const _Paragraphe(
                      '« Sama classe », c’est « ma classe » en wolof. Pour chaque classe et chaque '
                      'matière, tu retrouves les chapitres du programme, les leçons et des exercices '
                      'corrigés pour t’entraîner.',
                    ),
                    const _Titre('D’où viennent les leçons ?'),
                    const _Paragraphe(
                      'Elles suivent les cahiers d’élèves : le plan du cours est respecté, les '
                      'compléments sont signalés, rien n’est inventé. Chaque leçon est relue et '
                      'vérifiée avant d’être mise en ligne. Le programme s’appuie sur les documents '
                      'officiels et sur les cahiers. De nouvelles leçons arrivent au fil de l’année.',
                    ),
                    const _Titre('Tes données'),
                    // À revoir en phase 3 : quand les résultats seront
                    // enregistrés pour les enfants qui ont un profil,
                    // « rien n’est envoyé » ne sera plus vrai pour eux.
                    const _Paragraphe(
                      'Pas besoin de compte pour lire les leçons et faire les exercices. Tes '
                      'réponses restent sur ton téléphone : rien n’est envoyé. Les leçons sont '
                      'gardées sur le téléphone pour être lues même sans connexion.',
                    ),
                    // Seule partie vouvoyée de la page : elle s'adresse aux
                    // parents, comme l'espace parents (phase 2, D21).
                    const _Titre('Pour les parents'),
                    const _Paragraphe(
                      'Un compte facultatif permet de créer le profil de vos enfants. Nous '
                      'enregistrons seulement votre adresse e-mail, ainsi que le prénom et la '
                      'classe de chaque enfant. Vous pouvez supprimer un profil à tout moment.',
                    ),
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('Conçue par Bocar Gueye', style: TextStyle(fontSize: 15, color: Couleurs.texteDoux)),
                    const SizedBox(height: 4),
                    const Text('Version $versionApplication', style: Styles.secondaire),
                    const SizedBox(height: 8),
                    TextButton(
                      // La page de Flutter liste les licences enregistrées dans
                      // main.dart (polices OFL) et celles des paquets utilisés.
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: 'SamaClasse',
                        applicationVersion: versionApplication,
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                      child: const Text('Licences'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 6),
        child: Semantics(
          header: true,
          child: Text(texte, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      );
}

class _Paragraphe extends StatelessWidget {
  const _Paragraphe(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) =>
      Text(texte, style: const TextStyle(fontSize: 16, height: 1.5, color: Couleurs.texteDoux));
}
