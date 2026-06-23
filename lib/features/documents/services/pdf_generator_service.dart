import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';

/// Génère un PDF calqué sur le modèle officiel Pajemploi.
class PdfGeneratorService {
  static const _bleu = PdfColor(0.239, 0.616, 0.949);
  static const _bleuClair = PdfColor(0.875, 0.914, 0.949);
  static const _gris = PdfColor(0.45, 0.45, 0.45);
  static const _noir = PdfColors.black;
  static const _blanc = PdfColors.white;

  final _dateFmt = DateFormat('dd/MM/yyyy');

  String _fmtDate(DateTime? d) => d != null ? _dateFmt.format(d) : '__  /  __  /  ______';
  String _fmtDouble(double? v) => v != null ? v.toStringAsFixed(2).replaceAll('.', ',') : '';
  String _fmtInt(int? v) => v != null ? '$v' : '';

  // Remplace les guillemets typographiques par des apostrophes droites
  // (Helvetica fallback ne supporte pas U+2018/U+2019)
  String _s(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"');
  }

  // ── Case à cocher dessinée (pas de caractère Unicode) ──────────────────────
  pw.Widget _case(bool checked, pw.TextStyle style) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 8,
          height: 8,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _noir, width: 0.6),
            color: _blanc,
          ),
          child: checked
              ? pw.Center(
                  child: pw.Text(
                    'X',
                    style: pw.TextStyle(
                      font: style.font,
                      fontSize: 6,
                      color: _noir,
                    ),
                  ),
                )
              : null,
        ),
        pw.SizedBox(width: 2),
      ],
    );
  }

  // ── Ligne de champ soulignée ────────────────────────────────────────────────
  pw.Widget _champ(String label, String? valeur, pw.TextStyle lStyle, pw.TextStyle vStyle) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('$label ', style: lStyle),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 1),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4)),
              ),
              child: pw.Text(valeur ?? '', style: vStyle),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ligne ville / code postal ───────────────────────────────────────────────
  pw.Widget _champVilleCP(String? ville, String? cp, pw.TextStyle lStyle, pw.TextStyle vStyle) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Ville ', style: lStyle),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.only(bottom: 1),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4)),
                  ),
                  child: pw.Text(ville ?? '', style: vStyle),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Code postal ', style: lStyle),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.only(bottom: 1),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4)),
                  ),
                  child: pw.Text(cp ?? '', style: vStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Ligne Mme / M. ──────────────────────────────────────────────────────────
  pw.Widget _civilite(Civilite? civ, pw.TextStyle style) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _case(civ == Civilite.mme, style),
          pw.Text(' Mme   ', style: style),
          _case(civ == Civilite.monsieur, style),
          pw.Text(' M.', style: style),
        ],
      ),
    );
  }

  // ── Ligne En qualité de ─────────────────────────────────────────────────────
  pw.Widget _qualite(QualiteEmployeur? q, pw.TextStyle style) {
    final opts = [
      (QualiteEmployeur.pere, 'père'),
      (QualiteEmployeur.mere, 'mère'),
      (QualiteEmployeur.tuteur, 'tuteur'),
      (QualiteEmployeur.autre, 'autre'),
    ];
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text('En qualité de :  ', style: style),
          ...opts.expand((opt) => [
                _case(q == opt.$1, style),
                pw.Text(' ${opt.$2}   ', style: style),
              ]),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Génération principale
  // ────────────────────────────────────────────────────────────────────────────

  Future<Uint8List> genererEngagementPdf(EngagementReciproqueModel model) async {
    final doc = pw.Document(title: 'Engagement Réciproque', author: "Poppin's");

    pw.MemoryImage? icone;
    pw.MemoryImage? titreImg;
    try {
      final iconeBytes = await rootBundle.load('assets/images/poppins_icone_pdf.png');
      icone = pw.MemoryImage(iconeBytes.buffer.asUint8List());
      final titreBytes = await rootBundle.load('assets/images/poppins_titre_pdf.png');
      titreImg = pw.MemoryImage(titreBytes.buffer.asUint8List());
    } catch (_) {}

    // Open Sans = Unicode complet (€, apostrophes typographiques, accents)
    // Fallback Helvetica si pas de réseau au premier lancement
    pw.Font fontN;
    pw.Font fontB;
    pw.Font fontI;
    try {
      fontN = await PdfGoogleFonts.openSansRegular();
      fontB = await PdfGoogleFonts.openSansBold();
      fontI = await PdfGoogleFonts.openSansItalic();
    } catch (_) {
      fontN = pw.Font.helvetica();
      fontB = pw.Font.helveticaBold();
      fontI = pw.Font.helveticaOblique();
    }

    // Police manuscrite Waltograph pour "Lu et approuvé"
    pw.Font? fontWaltograph;
    try {
      final wData = await rootBundle.load('fonts/waltographUI.ttf');
      fontWaltograph = pw.Font.ttf(wData.buffer.asByteData());
    } catch (_) {}

    final sN = pw.TextStyle(font: fontN, fontSize: 8, color: _noir);
    final sB = pw.TextStyle(font: fontB, fontSize: 8, color: _noir);
    final sI = pw.TextStyle(font: fontI, fontSize: 7, color: _gris);
    final sLabel = pw.TextStyle(font: fontN, fontSize: 7, color: _gris);
    pw.Widget sectionHeader(String titre) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 5),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: _bleu,
          child: pw.Text(
            titre,
            style: pw.TextStyle(font: fontB, fontSize: 10, color: _blanc),
          ),
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // ── EN-TÊTE ────────────────────────────────────────────────────
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(width: 40),
                  if (titreImg != null)
                    pw.Expanded(child: pw.Center(
                        child: pw.Image(titreImg, height: 40, fit: pw.BoxFit.contain)))
                  else
                    pw.Expanded(child: pw.Center(
                        child: pw.Text("Poppin's",
                            style: pw.TextStyle(font: fontB, fontSize: 18, color: _bleu)))),
                  if (icone != null)
                    pw.Image(icone, width: 48, height: 48)
                  else
                    pw.SizedBox(width: 48),
                ],
              ),
            ),
            // ── TITRE ──────────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(bottom: 8, top: 4),
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: pw.BoxDecoration(
                color: _bleu,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Center(
                child: pw.Text(
                  'Engagement réciproque - promesse d\'embauche',
                  style: pw.TextStyle(font: fontB, fontSize: 13, color: _blanc),
                ),
              ),
            ),

            // ── DEUX COLONNES EMPLOYEUR / SALARIÉ ─────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Colonne gauche — Employeur
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _bleuClair, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Futur employeur', style: sB),
                        pw.SizedBox(height: 5),
                        _civilite(model.civiliteEmployeur, sN),
                        _champ('Nom', _s(model.nomEmployeur), sLabel, sB),
                        _champ('Prénom', _s(model.prenomEmployeur), sLabel, sB),
                        _champ('Adresse', _s(model.adresseEmployeur), sLabel, sB),
                        _champVilleCP(_s(model.villeEmployeur), _s(model.codePostalEmployeur), sLabel, sB),
                        _qualite(model.qualiteEmployeur, sN),
                        _champ('Téléphone', _s(model.telephoneEmployeur), sLabel, sB),
                        _champ('E-mail', _s(model.emailEmployeur), sLabel, sB),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                // Colonne droite — Salarié
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _bleuClair, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(children: [
                          pw.Text('Futur salarié', style: sB),
                          pw.SizedBox(width: 6),
                          pw.Text('Assistant maternel agréé', style: sN.copyWith(color: _gris)),
                        ]),
                        pw.SizedBox(height: 5),
                        _civilite(model.civiliteSalarie, sN),
                        _champ('Nom', _s(model.nomSalarie), sLabel, sB),
                        _champ('Prénom', _s(model.prenomSalarie), sLabel, sB),
                        _champ('Adresse', _s(model.adresseSalarie), sLabel, sB),
                        _champVilleCP(_s(model.villeSalarie), _s(model.codePostalSalarie), sLabel, sB),
                        _champ('Téléphone', _s(model.telephoneSalarie), sLabel, sB),
                        _champ('E-mail', _s(model.emailSalarie), sLabel, sB),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),

            // ── ENFANT ────────────────────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Pour l\'accueil de l\'enfant (Nom et Prénom)  ', style: sN),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.only(bottom: 1),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4)),
                    ),
                    child: pw.Text(_s(model.nomEnfant), style: sB),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.all(7),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _bleuClair, width: 0.8),
              ),
              child: pw.RichText(
                text: pw.TextSpan(
                  style: sN,
                  children: [
                    const pw.TextSpan(
                      text: 'Il est convenu d\'une promesse d\'embauche avec signature de contrat à compter du  ',
                    ),
                    pw.TextSpan(text: _fmtDate(model.dateDebutContrat), style: sB),
                    const pw.TextSpan(text: '\nsur les bases suivantes :'),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 7),

            // ── CONDITIONS D'ACCUEIL ──────────────────────────────────────
            sectionHeader('Conditions d\'accueil'),
            _ligneCondition('Durée hebdomadaire — nombre d\'heures',
                _fmtDouble(model.heuresParSemaine), '/ semaine', sN, sB),
            _ligneCondition('Durée mensuelle — nombre d\'heures',
                _fmtDouble(model.heuresParMois), '/ mois', sN, sB),
            _ligneCondition('Nombre de semaines d\'accueil dans l\'année',
                _fmtInt(model.semainesParAn), '/ an', sN, sB),
            pw.SizedBox(height: 6),

            // ── RÉMUNÉRATION ──────────────────────────────────────────────
            sectionHeader('Rémunération'),
            pw.Row(
              children: [
                pw.Expanded(child: _salaire('Salaire mensuel brut',
                    _fmtDouble(model.salaireMensuelBrut), sN, sB, fontB)),
                pw.SizedBox(width: 10),
                pw.Expanded(child: _salaire('Salaire horaire brut',
                    _fmtDouble(model.salaireHoraireBrut), sN, sB, fontB)),
              ],
            ),
            pw.SizedBox(height: 8),

            // ── TEXTE LÉGAL ───────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(7),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _bleuClair, width: 0.5),
              ),
              child: pw.Text(
                'Si l\'une des parties décide de ne pas donner suite à cet accord de principe, '
                'elle versera à l\'autre une indemnité forfaitaire compensatrice calculée sur la base '
                'd\'un demi-mois de salaire brut défini par ce présent engagement (sauf sur présentation '
                'd\'un justificatif, en cas de décès de l\'enfant ou retrait, suspension, ou '
                'non-renouvellement de l\'agrément de l\'assistant maternel).',
                style: sI,
                textAlign: pw.TextAlign.justify,
              ),
            ),
            pw.SizedBox(height: 10),

            // ── SIGNATURES ────────────────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _blocSignature(
                    'Signature du futur employeur',
                    model.civiliteEmployeur?.label,
                    model.prenomEmployeur,
                    model.nomEmployeur,
                    model.signatureEmployeur,
                    sB, sI, fontWaltograph,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _blocSignature(
                    'Signature du futur salarié',
                    model.civiliteSalarie?.label,
                    model.prenomSalarie,
                    model.nomSalarie,
                    model.signatureSalarie,
                    sB, sI, fontWaltograph,
                  ),
                ),
              ],
            ),

            pw.Expanded(child: pw.SizedBox()),

            // ── PIED DE PAGE ──────────────────────────────────────────────
            pw.Divider(color: _bleuClair, thickness: 0.5),
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Fait à ', style: sN),
                    pw.Container(
                      width: 100,
                      padding: const pw.EdgeInsets.only(bottom: 1),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4)),
                      ),
                      child: pw.Text(_s(model.lieuSignature), style: sN),
                    ),
                    pw.Text('  le  ', style: sN),
                    pw.Text(_fmtDate(model.dateSignature), style: sN),
                  ],
                ),
                pw.Text('1 / 1', style: sLabel),
              ],
            ),
            pw.SizedBox(height: 3),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  pw.Widget _ligneCondition(
    String label, String valeur, String suffixe,
    pw.TextStyle sN, pw.TextStyle sB,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text('$label  ', style: sN),
          pw.Container(
            width: 55,
            padding: const pw.EdgeInsets.only(bottom: 1),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.5)),
            ),
            child: pw.Text(valeur, style: sB, textAlign: pw.TextAlign.center),
          ),
          pw.Text('  $suffixe', style: sN),
        ],
      ),
    );
  }

  pw.Widget _salaire(
    String label, String valeur,
    pw.TextStyle sN, pw.TextStyle sB, pw.Font fontB,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _bleuClair, width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.Text('$label  ', style: sN),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 1),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4)),
              ),
              child: pw.Text(valeur, style: sB, textAlign: pw.TextAlign.right),
            ),
          ),
          pw.Text('  €',
              style: pw.TextStyle(font: fontB, fontSize: 10, color: _bleu)),
        ],
      ),
    );
  }

  pw.Widget _blocSignature(
    String titre,
    String? civilite, String? prenom, String? nom,
    Uint8List? sigBytes,
    pw.TextStyle sB, pw.TextStyle sI, pw.Font? fontWaltograph,
  ) {
    final identite = [civilite, prenom, nom].whereType<String>().join(' ').trim();
    final styleWalt = fontWaltograph != null
        ? pw.TextStyle(font: fontWaltograph, fontSize: 14, color: _noir)
        : sI.copyWith(fontSize: 10);
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _bleuClair, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(titre, style: sB.copyWith(fontSize: 9, color: _bleu)),
          if (identite.isNotEmpty)
            pw.Text(identite, style: sI.copyWith(fontSize: 7.5)),
          pw.SizedBox(height: 4),
          pw.Text('Lu et approuvé', style: styleWalt),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 60,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _gris, width: 0.5)),
            child: sigBytes != null
                ? pw.Image(pw.MemoryImage(sigBytes), fit: pw.BoxFit.contain)
                : pw.SizedBox(),
          ),
        ],
      ),
    );
  }

  // ── Méthodes publiques ───────────────────────────────────────────────────────

  Future<void> imprimerPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  Future<void> partagerPdf(Uint8List pdfBytes, String nomFichier) async {
    final path = await sauvegarderEnLocal(pdfBytes, nomFichier);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: nomFichier),
    );
  }

  Future<String> sauvegarderEnLocal(Uint8List pdfBytes, String nomFichier) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$nomFichier');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file.path;
  }

  String genererNomFichier(EngagementReciproqueModel model) {
    final nom = (model.nomEnfant ?? 'Inconnu').replaceAll(' ', '_');
    final date = DateFormat('yyyyMMdd').format(model.dateSignature ?? DateTime.now());
    return 'Engagement_${nom}_$date.pdf';
  }
}
