// Dessin de la « Fiche à imprimer » en PDF A4 (D35, maquettes `Fiche` et
// `FicheCorrige`), avec le paquet `pdf`.
//
// La fiche d'abord (« À retenir » puis les exercices, avec cases et lignes),
// puis le corrigé, qui commence toujours sur une nouvelle page : l'enseignant
// imprime l'un sans l'autre. Noir et gris seulement, pour la photocopie.
// Polices embarquées de l'application (pas de téléchargement, D17) : le PDF
// se fabrique hors connexion.

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'contenu_fiche.dart';

/// Polices de la fiche, chargées une fois depuis les ressources.
class PolicesFiche {
  const PolicesFiche({required this.texte, required this.gras, required this.cursive, required this.secours});

  final pw.Font texte;
  final pw.Font gras;
  final pw.Font cursive;

  /// Exposants, flèches, symboles mathématiques absents d'Atkinson (D17).
  final List<pw.Font> secours;
}

Future<pw.Font> _police(String fichier) async =>
    pw.Font.ttf(await rootBundle.load('assets/fonts/$fichier'));

/// Charge les polices embarquées (`assets/fonts/`).
Future<PolicesFiche> chargerPolicesFiche() async => PolicesFiche(
      texte: await _police('AtkinsonHyperlegibleNext-Regular.ttf'),
      gras: await _police('AtkinsonHyperlegibleNext-Bold.ttf'),
      cursive: await _police('PlaywriteFRModerne-Regular.ttf'),
      secours: [
        await _police('NotoSansSecours-Regular.ttf'),
        await _police('NotoSansMathSecours-Regular.ttf'),
      ],
    );

// Gris lisibles en photocopie ; noir pour tout ce qui se lit.
const _noir = PdfColor.fromInt(0xFF121A33);
const _gris = PdfColor.fromInt(0xFF5B6478);
const _trait = PdfColor.fromInt(0xFFB4BCCF);

/// Le PDF de [contenu] : fiche, puis corrigé sur une page à part.
Future<Uint8List> fabriquerFichePdf(ContenuFiche contenu, PolicesFiche polices) async {
  final theme = pw.ThemeData.withFont(
    base: polices.texte,
    bold: polices.gras,
    fontFallback: polices.secours,
  ).copyWith(defaultTextStyle: pw.TextStyle(fontSize: 12, lineSpacing: 2, color: _noir, font: polices.texte, fontBold: polices.gras, fontFallback: polices.secours));

  final doc = pw.Document(title: nomFicheDepuis(contenu), author: 'SamaClasse');
  final format = PdfPageFormat.a4.copyWith(
    marginLeft: 1.6 * PdfPageFormat.cm,
    marginRight: 1.6 * PdfPageFormat.cm,
    marginTop: 1.4 * PdfPageFormat.cm,
    marginBottom: 1.2 * PdfPageFormat.cm,
  );

  pw.Widget piedDePage(pw.Context context, String gauche) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _trait, width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(gauche, style: const pw.TextStyle(fontSize: 9, color: _gris)),
            pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: _gris)),
          ],
        ),
      );

  // --- La fiche ---
  doc.addPage(pw.MultiPage(
    pageFormat: format,
    theme: theme,
    footer: (context) => piedDePage(context, 'La leçon complète : ${contenu.lien.replaceFirst('https://', '')}'),
    build: (context) => [
      _entete(contenu, polices, sousTitre: contenu.surTitre),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        for (final libelle in ['Nom :', 'Classe :', 'Date :'])
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(right: 14),
              padding: const pw.EdgeInsets.only(bottom: 3),
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.6))),
              child: pw.Text(libelle),
            ),
          ),
      ]),
      pw.SizedBox(height: 14),
      if (contenu.retenir.isNotEmpty) _retenir(contenu),
      for (final e in contenu.exercices) ...[
        pw.SizedBox(height: 14),
        ..._avecTitre(e, e.enonce),
        if (e.reponse.isNotEmpty) pw.SizedBox(height: 4),
        ..._blocs(e.reponse),
      ],
    ],
  ));

  // --- Le corrigé, toujours sur une nouvelle page ---
  if (contenu.exercices.isNotEmpty) {
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      theme: theme,
      footer: (context) => piedDePage(context, 'Corrigé · à imprimer à part'),
      build: (context) => [
        _entete(contenu, polices, sousTitre: 'Corrigé · réservé à l’enseignant'),
        for (final e in contenu.exercices) ...[
          pw.SizedBox(height: 14),
          ..._avecTitre(e, e.corrige),
        ],
      ],
    ));
  }
  return doc.save();
}

/// Titre du document PDF (métadonnées).
String nomFicheDepuis(ContenuFiche contenu) => 'Fiche - ${contenu.titre}';

pw.Widget _entete(ContenuFiche c, PolicesFiche polices, {required String sousTitre}) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _noir, width: 1.2))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(sousTitre.toUpperCase(), style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.6)),
                pw.SizedBox(height: 4),
                pw.Text(c.titre, style: pw.TextStyle(font: polices.cursive, fontSize: 18, lineSpacing: 6)),
              ],
            ),
          ),
          pw.Text('SamaClasse', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );

pw.Widget _retenir(ContenuFiche c) => pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _noir, width: 1), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('À retenir', style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          for (final r in c.retenir)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: 130, child: pw.Text(r.notion, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: pw.Text(r.essentiel)),
                ],
              ),
            ),
        ],
      ),
    );

pw.Widget _titreExercice(ExerciceFiche e) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text('Exercice ${e.numero} · ${e.niveau}', style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    );

/// Le titre d'un exercice suivi de [blocs], le titre gardé avec le premier
/// bloc : un titre ne reste jamais seul en bas de page.
List<pw.Widget> _avecTitre(ExerciceFiche e, List<BlocFiche> blocs) => [
      if (blocs.isEmpty)
        _titreExercice(e)
      else
        // Inseparable : une colonne seule pourrait encore se couper entre
        // deux pages.
        pw.Inseparable(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_titreExercice(e), _bloc(blocs.first)]),
        ),
      ..._blocs(blocs.skip(1).toList()),
    ];

pw.Widget _case() => pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _noir, width: 0.8)),
    );

pw.Widget _ligne({double hauteur = 20}) => pw.Container(
      height: hauteur,
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _trait, width: 0.6))),
    );

const _lettres = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

List<pw.Widget> _blocs(List<BlocFiche> blocs) => [for (final b in blocs) _bloc(b)];

pw.Widget _bloc(BlocFiche bloc) => switch (bloc) {
      TexteFiche(:final texte) => pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(texte)),
      SchemaFiche(:final description) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text('[Schéma dans l’application : $description]', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic, color: _gris)),
        ),
      LignesFiche(:final nombre) => pw.Column(children: [for (var i = 0; i < nombre; i++) _ligne()]),
      TableauFiche(:final lignes) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Table(
            border: pw.TableBorder.all(color: _gris, width: 0.6),
            children: [
              for (final (i, l) in lignes.indexed)
                pw.TableRow(
                  children: [
                    for (final cellule in l)
                      pw.Container(
                        constraints: const pw.BoxConstraints(minHeight: 20),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: pw.Text(cellule, style: i == 0 ? const pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ChoixFiche(:final question, :final choix) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(question),
              for (final c in choix)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 10, top: 3),
                  child: pw.Row(children: [_case(), pw.SizedBox(width: 6), pw.Expanded(child: pw.Text(c))]),
                ),
            ],
          ),
        ),
      VraiFauxFiche(:final affirmations) => pw.Table(
          columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FixedColumnWidth(28), 2: pw.FixedColumnWidth(28)},
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _trait, width: 0.5), bottom: pw.BorderSide(color: _trait, width: 0.5)),
          children: [
            pw.TableRow(children: [
              pw.Text('Affirmation', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Center(child: pw.Text('V', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('F', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ]),
            for (final (i, a) in affirmations.indexed)
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text('${i + 1}. $a')),
                  pw.Center(child: _case()),
                  pw.Center(child: _case()),
                ],
              ),
          ],
        ),
      RelierFiche(:final gauche, :final droite) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  for (final (i, g) in gauche.indexed) pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('${i + 1}. $g')),
                ])),
                pw.SizedBox(width: 16),
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  for (final (i, d) in droite.indexed)
                    pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('${i < _lettres.length ? _lettres[i] : i + 1}. $d')),
                ])),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text('Réponses : ${[for (var i = 1; i <= gauche.length; i++) '$i → …'].join('   ')}'),
          ],
        ),
      ChampsFiche(:final libelles) => pw.Column(
          children: [
            for (final l in libelles)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [pw.Text(l), pw.SizedBox(width: 6), pw.Expanded(child: _ligne())],
              ),
          ],
        ),
      ClassementFiche(:final elements, :final categories) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('À classer : ${elements.join(' ; ')}'),
            pw.SizedBox(height: 4),
            for (final c in categories)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [pw.Text('$c :', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.SizedBox(width: 6), pw.Expanded(child: _ligne(hauteur: 24))],
              ),
          ],
        ),
    };
