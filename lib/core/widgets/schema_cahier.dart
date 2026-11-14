import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config.dart';
import '../theme/couleurs.dart';
import '../theme/theme.dart';

/// Chemin des fichiers publics de l'espace de stockage `schemas` (D15).
const _cheminSchemas = '/storage/v1/object/public/schemas/';

/// Vrai si [adresse] désigne une image de l'espace de stockage `schemas` du
/// projet Supabase situé à [urlSupabase].
///
/// Pourquoi filtrer : le Markdown d'une leçon pourrait contenir l'adresse
/// d'une image hébergée n'importe où (copier-coller depuis le web). La
/// charger exposerait l'adresse IP des élèves à un site tiers et afficherait
/// un contenu que Bocar ne maîtrise pas. Seules les images qu'il a déposées
/// dans `schemas` sont donc chargées ; les autres sont remplacées par leur
/// description.
bool estAdresseSchema(Uri adresse, String urlSupabase) {
  final projet = Uri.tryParse(urlSupabase);
  if (projet == null || projet.host.isEmpty) return false;
  return adresse.scheme == 'https' &&
      adresse.host == projet.host &&
      !adresse.hasPort &&
      adresse.path.startsWith(_cheminSchemas) &&
      adresse.path.length > _cheminSchemas.length &&
      // Garde-fou : pas de remontée de dossier (« .. ») dans le chemin.
      !adresse.pathSegments.contains('..');
}

/// Texte affiché à la place d'un schéma qui ne peut pas être montré
/// (hors connexion, erreur de chargement, adresse refusée).
String texteSchemaAbsent(String? description) {
  final d = description?.trim() ?? '';
  return d.isEmpty ? 'Schéma non disponible.' : 'Schéma : $d';
}

/// Schéma d'une leçon ou d'un exercice, inséré dans le Markdown par
/// `![description](adresse)`.
///
/// - L'image occupe la largeur du texte, sans être agrandie au-delà de sa
///   taille réelle (une petite image agrandie devient floue).
/// - Fond blanc et bordure fine : sur une page Seyès, les lignes ne se voient
///   pas à travers une image PNG transparente.
/// - La description est lue par les lecteurs d'écran.
/// - Si l'image ne peut pas être affichée, sa description la remplace : la
///   leçon reste compréhensible, même hors connexion (les images ne sont pas
///   gardées dans la copie locale, D16).
/// - Sur une page Seyès ([surSeyes]), la hauteur occupée est arrondie à un
///   nombre entier d'interlignes pour que le texte suivant reste sur les
///   lignes.
class SchemaCahier extends StatelessWidget {
  const SchemaCahier({
    super.key,
    required this.adresse,
    this.description,
    this.surSeyes = false,
    this.urlSupabase = Config.supabaseUrl,
  });

  final Uri adresse;
  final String? description;
  final bool surSeyes;

  /// Adresse du projet Supabase dont l'espace `schemas` est autorisé.
  /// Paramètre seulement pour les tests ; l'application garde la valeur de
  /// la configuration.
  final String urlSupabase;

  @override
  Widget build(BuildContext context) {
    if (!estAdresseSchema(adresse, urlSupabase)) return _absent();

    final d = description?.trim() ?? '';
    // La description est annoncée aussi pendant le chargement (Image ne
    // l'annonce qu'une fois l'image prête), mais pas en cas d'erreur : le
    // texte de remplacement la contient déjà, elle serait lue deux fois.
    Widget annonce(Widget enfant) =>
        Semantics(image: true, label: d.isEmpty ? null : d, excludeSemantics: true, child: enfant);

    final image = Image.network(
      adresse.toString(),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      frameBuilder: (context, enfant, image, synchrone) {
        if (image == null && !synchrone) return annonce(const _AttenteSchema());
        return annonce(Padding(
          // Un peu d'air au-dessus et au-dessous ; l'arrondi à l'interligne
          // en ajoute encore sur une page Seyès.
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Couleurs.papier,
              border: Border.all(color: Couleurs.bordureForte),
            ),
            child: Padding(padding: const EdgeInsets.all(1), child: enfant),
          ),
        ));
      },
      errorBuilder: (context, erreur, pile) => _absent(),
    );

    final cadre = Align(alignment: Alignment.centerLeft, child: image);

    // SizedBox(width: infinity) : dans le paragraphe Markdown (un Wrap),
    // l'image prend toute la largeur disponible au lieu de rester à côté
    // d'un autre élément.
    final pleineLargeur = SizedBox(width: double.infinity, child: cadre);
    return surSeyes ? HauteurEnInterlignes(child: pleineLargeur) : pleineLargeur;
  }

  /// Description à la place de l'image, en italique, dans le style du texte
  /// courant (donc posée sur les lignes Seyès sans recalage).
  Widget _absent() {
    final base = surSeyes ? Styles.lecon : const TextStyle(fontSize: 16, height: 1.5);
    return SizedBox(
      width: double.infinity,
      child: Text(
        texteSchemaAbsent(description),
        style: base.copyWith(fontStyle: FontStyle.italic, color: Couleurs.texteDoux),
      ),
    );
  }
}

/// Emplacement réservé pendant le chargement d'un schéma : une hauteur fixe
/// (quatre interlignes moins les marges) évite que tout le texte saute de
/// plusieurs lignes à chaque image qui arrive.
class _AttenteSchema extends StatelessWidget {
  const _AttenteSchema();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: interligne * 4 - 8,
        width: double.infinity,
        child: ColoredBox(
          color: Couleurs.selection,
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Couleurs.encre),
            ),
          ),
        ),
      ),
    );
  }
}

/// Arrondit la hauteur de [child] au multiple supérieur de [interligne] et le
/// centre verticalement dans l'espace obtenu.
///
/// Sur une page Seyès, chaque bloc doit mesurer un nombre entier
/// d'interlignes pour que le texte qui suit repose sur les lignes fortes
/// (voir `PageSeyes`). Une image a une hauteur quelconque : on complète.
class HauteurEnInterlignes extends SingleChildRenderObjectWidget {
  const HauteurEnInterlignes({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenduHauteurEnInterlignes();
}

class _RenduHauteurEnInterlignes extends RenderShiftedBox {
  _RenduHauteurEnInterlignes() : super(null);

  @override
  void performLayout() {
    final enfant = child;
    if (enfant == null) {
      size = constraints.smallest;
      return;
    }
    enfant.layout(constraints.loosen(), parentUsesSize: true);
    // Tolérance de 0,01 px : une hauteur déjà juste (64,0000001 après un
    // calcul flottant) ne doit pas gagner un interligne entier.
    final lignes = ((enfant.size.height - 0.01) / interligne).ceil().clamp(0, 1 << 20);
    size = constraints.constrain(Size(enfant.size.width, lignes * interligne));
    (enfant.parentData! as BoxParentData).offset = Offset(0, (size.height - enfant.size.height) / 2);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _arrondi(super.computeMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _arrondi(super.computeMaxIntrinsicHeight(width));

  @override
  double computeMinIntrinsicWidth(double height) => child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) => child?.getMaxIntrinsicWidth(height) ?? 0;

  static double _arrondi(double h) => ((h - 0.01) / interligne).ceil().clamp(0, 1 << 20) * interligne;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final enfant = child;
    if (enfant == null) return constraints.smallest;
    final s = enfant.getDryLayout(constraints.loosen());
    return constraints.constrain(Size(s.width, _arrondi(s.height)));
  }
}
