import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:poppins_app/features/documents/models/avenant_model.dart';

class AvenantPdfService {
  static const _bleu      = PdfColor(0.239, 0.616, 0.949);
  static const _bleuClair = PdfColor(0.875, 0.914, 0.949);
  static const _gris      = PdfColor(0.45,  0.45,  0.45);
  static const _noir      = PdfColors.black;
  static const _blanc     = PdfColors.white;

  final _dateFmt = DateFormat('dd/MM/yyyy');

  String _d(DateTime? d) => d != null ? _dateFmt.format(d) : '___________';
  String _v(String? v) {
    if (v == null || v.trim().isEmpty) return '';
    return v.trim()
        .replaceAll('‘', "'").replaceAll('’', "'")
        .replaceAll('“', '"').replaceAll('”', '"');
  }
  String _vb(String? v, {String fallback = '__________'}) =>
      (_v(v).isEmpty) ? fallback : _v(v);

  // ── Widgets helpers ──────────────────────────────────────────────────────────

  pw.Widget _ligneChamp(String label, String? valeur, pw.TextStyle lS, pw.TextStyle vS) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('$label ', style: lS),
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 1),
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4))),
            child: pw.Text(_vb(valeur), style: vS),
          )),
        ]),
      );

  pw.Widget _sectionHeader(String titre, pw.Font bold) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        color: _bleu,
        child: pw.Text(titre,
            style: pw.TextStyle(font: bold, fontSize: 11, color: _blanc)),
      );

  pw.Widget _blocSignature(String titre, Uint8List? pngBytes, String? luEtApprouve,
      pw.Font bold, pw.TextStyle tS, pw.TextStyle tSm, pw.Font? fontWaltograph) {
    final styleWalt = fontWaltograph != null
        ? pw.TextStyle(font: fontWaltograph, fontSize: 14, color: _noir)
        : pw.TextStyle(font: bold, fontSize: 10, color: _noir);
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _bleuClair, width: 0.8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(titre, style: pw.TextStyle(font: bold, fontSize: 9, color: _bleu)),
        pw.SizedBox(height: 4),
        pw.Text((luEtApprouve != null && luEtApprouve.isNotEmpty) ? luEtApprouve : 'Lu et approuvé', style: styleWalt),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 60,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _gris, width: 0.5)),
          child: pngBytes != null
              ? pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.contain)
              : pw.SizedBox(),
        ),
      ]),
    );
  }

  pw.Widget _buildHeader(pw.Font bold, pw.MemoryImage icone, pw.MemoryImage titre,
      int page, int total) {
    if (page == 1) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.SizedBox(width: 40),
          pw.Expanded(child: pw.Center(child: pw.Image(titre, height: 40, fit: pw.BoxFit.contain))),
          pw.Image(icone, width: 48, height: 48),
        ]),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _bleuClair, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(child: pw.Text('Avenant au contrat de travail',
              style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu))),
          pw.SizedBox(width: 4),
          pw.Image(icone, width: 26, height: 26),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Font regular, int page, int total) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _bleuClair, width: 0.5))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('$page / $total',
            style: pw.TextStyle(font: regular, fontSize: 7, color: _gris)),
      ]),
    );
  }

  // ── Génération principale ────────────────────────────────────────────────────

  Future<Uint8List> genererPdf(AvenantModel m) async {
    final pdf     = pw.Document();
    final bold    = await PdfGoogleFonts.notoSansBold();
    final regular = await PdfGoogleFonts.notoSansRegular();
    final italic  = await PdfGoogleFonts.notoSansItalic();

    final iconeBytes = await rootBundle.load('assets/images/poppins_icone_pdf.png');
    final icone = pw.MemoryImage(iconeBytes.buffer.asUint8List());
    final titreBytes = await rootBundle.load('assets/images/poppins_titre_pdf.png');
    final titre = pw.MemoryImage(titreBytes.buffer.asUint8List());
    pw.Font? fontWaltograph;
    try {
      final wData = await rootBundle.load('fonts/waltographUI.ttf');
      fontWaltograph = pw.Font.ttf(wData.buffer.asByteData());
    } catch (_) {}

    final tL  = pw.TextStyle(font: bold,    fontSize: 8,  color: _gris);
    final tV  = pw.TextStyle(font: regular, fontSize: 8,  color: _noir);
    final tS  = pw.TextStyle(font: regular, fontSize: 8,  color: _noir);
    final tB  = pw.TextStyle(font: bold,    fontSize: 8,  color: _noir);
    final tSm = pw.TextStyle(font: regular, fontSize: 7,  color: _gris);
    final tIt = pw.TextStyle(font: italic,  fontSize: 7,  color: _gris);

    final typeLabel = m.typeContratOriginal?.label ?? 'CDI';
    final enfantLabel = [m.prenomEnfant, m.nomEnfant]
        .where((s) => (s ?? '').isNotEmpty).join(' ');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => _buildHeader(bold, icone, titre, ctx.pageNumber, ctx.pagesCount),
      footer:  (ctx) => _buildFooter(regular, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) => [

        // ── Titre ──────────────────────────────────────────────────────────────
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
              'Avenant au contrat de travail',
              style: pw.TextStyle(font: bold, fontSize: 13, color: _blanc),
            ),
          ),
        ),

        // ── Référence contrat original ─────────────────────────────────────────
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'Les parties conviennent de modifier le contrat de travail a duree ', style: tB),
          pw.TextSpan(text: typeLabel == 'CDI' ? 'indeterminee' : 'determinee', style: tB),
          const pw.TextSpan(text: ' signe le : '),
          pw.TextSpan(text: _d(m.dateContratOriginal), style: tB),
          if (enfantLabel.isNotEmpty) ...[
            const pw.TextSpan(text: ' pour l\'accueil de '),
            pw.TextSpan(text: enfantLabel, style: tB),
          ],
          const pw.TextSpan(text: '.'),
        ])),
        pw.SizedBox(height: 2),
        pw.Text('(Le contrat de travail $typeLabel reste en vigueur pour les clauses non modifiees par le present avenant.)',
            style: tIt),

        // ── Employeur ──────────────────────────────────────────────────────────
        _sectionHeader('Entre l\'employeur', bold),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Nom de naissance :', _v(m.nomNaissanceEmployeur), tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('Nom d\'usage :', _v(m.nomUsageEmployeur), tL, tV)),
        ]),
        _ligneChamp('Prenom :', _v(m.prenomEmployeur), tL, tV),
        _ligneChamp('Adresse :', _v(m.adresseEmployeur), tL, tV),
        pw.Row(children: [
          pw.Expanded(flex: 6, child: _ligneChamp('Ville :', _v(m.villeEmployeur), tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(flex: 4, child: _ligneChamp('Code postal :', _v(m.codePostalEmployeur), tL, tV)),
        ]),
        _ligneChamp('N° Pajemploi :', _v(m.numeroPajemploi), tL, tV),

        // ── Salarié ────────────────────────────────────────────────────────────
        _sectionHeader('Et le salarié', bold),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Nom de naissance :', _v(m.nomNaissanceSalarie), tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('Nom d\'usage :', _v(m.nomUsageSalarie), tL, tV)),
        ]),
        _ligneChamp('Prenom :', _v(m.prenomSalarie), tL, tV),
        _ligneChamp('Adresse :', _v(m.adresseSalarie), tL, tV),
        pw.Row(children: [
          pw.Expanded(flex: 6, child: _ligneChamp('Ville :', _v(m.villeSalarie), tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(flex: 4, child: _ligneChamp('Code postal :', _v(m.codePostalSalarie), tL, tV)),
        ]),
        _ligneChamp('N° de Securite sociale :', _v(m.numeroSecu), tL, tV),

        // ── Modifications ──────────────────────────────────────────────────────
        pw.SizedBox(height: 6),
        pw.Text('Il est convenu de modifier les dispositions suivantes :',
            style: tB),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          constraints: const pw.BoxConstraints(minHeight: 120),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _gris, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            _v(m.modificationsTexte).isEmpty ? ' ' : _v(m.modificationsTexte),
            style: tV,
          ),
        ),
        pw.SizedBox(height: 8),
        _ligneChamp('Date d\'execution de l\'avenant :', _d(m.dateExecution), tL, tV),

        // ── Fait à / Le ────────────────────────────────────────────────────────
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _gris, width: 0.5)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(
                'Le present avenant est etabli en deux exemplaires originaux, dont un pour chaque partie.',
                style: tS),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              pw.Text('Fait a : ', style: tL),
              pw.Expanded(child: pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 1),
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4))),
                child: pw.Text(_vb(m.lieuSignature), style: tV),
              )),
              pw.SizedBox(width: 24),
              pw.Text('Le : ', style: tL),
              pw.Container(
                constraints: const pw.BoxConstraints(minWidth: 80),
                padding: const pw.EdgeInsets.only(bottom: 1),
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4))),
                child: pw.Text(_d(m.dateSignature), style: tV),
              ),
            ]),
          ]),
        ),
        pw.SizedBox(height: 20),

        // ── Signatures ─────────────────────────────────────────────────────────
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: _blocSignature(
              'Signature du salarié',
              m.signatureSalarie, m.luEtApproveSalarie,
              bold, tS, tSm, fontWaltograph)),
          pw.SizedBox(width: 24),
          pw.Expanded(child: _blocSignature(
              'Signature de l\'employeur',
              m.signatureEmployeur, m.luEtApprouveEmployeur,
              bold, tS, tSm, fontWaltograph)),
        ]),
        pw.SizedBox(height: 20),
      ],
    ));

    return pdf.save();
  }

  // ── Utilitaires ──────────────────────────────────────────────────────────────

  Future<void> partagerPdf(Uint8List pdfBytes, String nomFichier) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$nomFichier');
    await file.writeAsBytes(pdfBytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: nomFichier));
  }

  Future<void> imprimerPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
  }
}
