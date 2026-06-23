import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:poppins_app/features/documents/models/contrat_cdi_model.dart';

class ContratCdiPdfService {
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
  String _e(double? v, {int dec = 2}) =>
      v != null ? v.toStringAsFixed(dec).replaceAll('.', ',') : '_______';
  String _i(int? v, {String fallback = '___'}) => v != null ? '$v' : fallback;

  // ── Widgets helpers ──────────────────────────────────────────────────────────

  pw.Widget _case(bool checked, pw.Font bold) => pw.Container(
        width: 10, height: 10,
        decoration: pw.BoxDecoration(
          color: checked ? _bleu : _blanc,
          border: pw.Border.all(color: _bleu, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
        child: checked
            ? pw.CustomPaint(
                size: const PdfPoint(10, 10),
                painter: (canvas, size) {
                  canvas
                    ..setStrokeColor(PdfColors.white)
                    ..setLineWidth(1.3)
                    ..moveTo(1.5, 5.5)
                    ..lineTo(3.5, 2.5)
                    ..lineTo(8.5, 7.5)
                    ..strokePath();
                },
              )
            : null,
      );

  pw.Widget _radio(bool checked, pw.Font bold) => pw.Container(
        width: 10, height: 10,
        decoration: pw.BoxDecoration(
          color: checked ? _bleu : _blanc,
          border: pw.Border.all(color: _bleu, width: 0.8),
          shape: pw.BoxShape.circle,
        ),
        child: checked
            ? pw.Center(child: pw.Container(width: 4, height: 4, decoration: const pw.BoxDecoration(color: _blanc, shape: pw.BoxShape.circle)))
            : null,
      );

  pw.Widget _champ(String? valeur, pw.TextStyle vS, {double minWidth = 60}) =>
      pw.Container(
        constraints: pw.BoxConstraints(minWidth: minWidth),
        padding: const pw.EdgeInsets.only(bottom: 1),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4))),
        child: pw.Text(_vb(valeur), style: vS),
      );

  pw.Widget _ligneChamp(String label, String? valeur, pw.TextStyle lS, pw.TextStyle vS) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('$label ', style: lS),
          pw.Expanded(child: _champ(valeur, vS)),
        ]),
      );

  pw.Widget _sectionHeader(String titre, pw.Font bold) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10, bottom: 5),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: _bleu,
        child: pw.Text(titre, style: pw.TextStyle(font: bold, fontSize: 10, color: _blanc, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _subHeader(String titre, pw.Font bold) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 5, bottom: 2),
        child: pw.Text(titre, style: pw.TextStyle(font: bold, fontSize: 9, color: _bleu)),
      );

  pw.Widget _tableauPlanning(ContratCdiModel m, pw.Font bold, pw.Font regular) {
    final lS = pw.TextStyle(font: bold,    fontSize: 7, color: _blanc);
    final cS = pw.TextStyle(font: regular, fontSize: 8);
    final lignes = m.lignesPlanning.where((l) => l.jourTravail.trim().isNotEmpty).toList();
    final rows = lignes.isEmpty ? [_emptyRow(cS), _emptyRow(cS), _emptyRow(cS)] : lignes.map((l) => pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_v(l.jourTravail), style: cS)),
      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_v(l.horairesTravail), style: cS)),
      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_v(l.nbHeuresTravail), style: cS)),
    ])).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: _gris, width: 0.4),
      columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(4), 2: const pw.FlexColumnWidth(2)},
      children: [
        pw.TableRow(decoration: const pw.BoxDecoration(color: _bleu), children: [
          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Jours de travail', style: lS)),
          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Horaires de travail', style: lS)),
          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Nombre d\'heures', style: lS)),
        ]),
        ...rows,
      ],
    );
  }

  pw.TableRow _emptyRow(pw.TextStyle s) => pw.TableRow(children: [
    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('', style: s)),
    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('', style: s)),
    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('', style: s)),
  ]);

  // ── PDF principal ─────────────────────────────────────────────────────────────

  Future<Uint8List> genererPdf(ContratCdiModel m) async {
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

    final tL  = pw.TextStyle(font: bold,    fontSize: 8, color: _gris);
    final tV  = pw.TextStyle(font: regular, fontSize: 8, color: _noir);
    final tS  = pw.TextStyle(font: regular, fontSize: 8, color: _noir);
    final tB  = pw.TextStyle(font: bold,    fontSize: 8, color: _noir);
    final tSm = pw.TextStyle(font: regular, fontSize: 7, color: _gris);
    final tIt = pw.TextStyle(font: italic,  fontSize: 7, color: _gris);
    final tSmB = pw.TextStyle(font: bold,   fontSize: 7, color: _gris);

    final cas1 = m.typeAccueil == TypeAccueilCdi.cas1_52semaines;
    final cas2 = m.typeAccueil == TypeAccueilCdi.cas2_46semaines;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => _buildHeader(bold, regular, icone, titre, ctx.pageNumber, ctx.pagesCount),
      footer:  (ctx) => _buildFooter(regular, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) => [

        // ─── Titre ──────────────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          margin: const pw.EdgeInsets.only(bottom: 8, top: 4),
          decoration: pw.BoxDecoration(color: _bleu, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Center(child: pw.Text('Contrat de travail à durée indéterminée (CDI)', style: pw.TextStyle(font: bold, fontSize: 13, color: _blanc))),
        ),

        // ─── Employeur ──────────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Entre le particulier employeur :', style: pw.TextStyle(font: bold, fontSize: 9, color: _bleu)),
            pw.SizedBox(height: 4),
            _ligneChamp('Nom de naissance :', _v(m.nomNaissanceEmployeur), tL, tV),
            pw.Row(children: [
              pw.Expanded(child: _ligneChamp('Nom d\'usage :', _v(m.nomUsageEmployeur), tL, tV)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _ligneChamp('Prénom :', _v(m.prenomEmployeur), tL, tV)),
            ]),
            _ligneChamp('Adresse :', _v(m.adresseEmployeur), tL, tV),
            pw.Row(children: [
              pw.Expanded(flex: 6, child: _ligneChamp('Ville :', _v(m.villeEmployeur), tL, tV)),
              pw.SizedBox(width: 12),
              pw.Expanded(flex: 4, child: _ligneChamp('Code postal :', _v(m.codePostalEmployeur), tL, tV)),
            ]),
            pw.Row(children: [
              pw.Expanded(child: _ligneChamp('N° de téléphone :', _v(m.telephoneEmployeur), tL, tV)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _ligneChamp('E-mail :', _v(m.emailEmployeur), tL, tV)),
            ]),
            pw.SizedBox(height: 3),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('En qualité de : ', style: tL),
              pw.SizedBox(width: 4),
              _case(m.qualiteEmployeur == QualiteCdiEmployeur.pere,   bold), pw.SizedBox(width: 2), pw.Text('père  ', style: tS),
              _case(m.qualiteEmployeur == QualiteCdiEmployeur.mere,   bold), pw.SizedBox(width: 2), pw.Text('mère  ', style: tS),
              _case(m.qualiteEmployeur == QualiteCdiEmployeur.tuteur, bold), pw.SizedBox(width: 2), pw.Text('tuteur  ', style: tS),
              _case(m.qualiteEmployeur == QualiteCdiEmployeur.autre,  bold), pw.SizedBox(width: 2), pw.Text('autre :', style: tS),
            ]),
            pw.SizedBox(height: 2),
            _ligneChamp('N° Pajemploi : Y', _v(m.numeroPajemploi), tL, tV),
            pw.Text('Code IDCC : 3239', style: tSm),
          ]),
        ),
        pw.SizedBox(height: 6),

        // ─── Parent 2 (conditionnel) ──────────────────────────────────────────
        if ((m.telephoneParent2 ?? '').isNotEmpty || (m.emailParent2 ?? '').isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _bleuClair, width: 0.8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Parent 2 :', style: pw.TextStyle(font: bold, fontSize: 9, color: _bleu)),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Expanded(child: _ligneChamp('Tél. :', _v(m.telephoneParent2), tL, tV)),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _ligneChamp('E-mail :', _v(m.emailParent2), tL, tV)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 6),
        ],

        // ─── Salarié ─────────────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Et l\'assistant maternel :', style: pw.TextStyle(font: bold, fontSize: 9, color: _bleu)),
            pw.SizedBox(height: 4),
            _ligneChamp('Nom de naissance :', _v(m.nomNaissanceSalarie), tL, tV),
            pw.Row(children: [
              pw.Expanded(child: _ligneChamp('Nom d\'usage :', _v(m.nomUsageSalarie), tL, tV)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _ligneChamp('Prénom :', _v(m.prenomSalarie), tL, tV)),
            ]),
            _ligneChamp('Adresse :', _v(m.adresseSalarie), tL, tV),
            pw.Row(children: [
              pw.Expanded(flex: 6, child: _ligneChamp('Ville :', _v(m.villeSalarie), tL, tV)),
              pw.SizedBox(width: 12),
              pw.Expanded(flex: 4, child: _ligneChamp('Code postal :', _v(m.codePostalSalarie), tL, tV)),
            ]),
            pw.Row(children: [
              pw.Expanded(child: _ligneChamp('N° de téléphone :', _v(m.telephoneSalarie), tL, tV)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _ligneChamp('E-mail :', _v(m.emailSalarie), tL, tV)),
            ]),
            _ligneChamp('N° de Sécurité sociale :', _v(m.numeroSecu), tL, tV),
            _ligneChamp('Référence de l\'agrément :', _v(m.referenceAgrement), tL, tV),
            pw.Row(children: [
              pw.Expanded(child: _ligneChamp('Date de délivrance de l\'agrément :', _d(m.dateLivraisonAgrement), tL, tV)),
              pw.SizedBox(width: 6),
              pw.Text('ou date du dernier renouvellement :', style: tL),
              pw.SizedBox(width: 4),
              pw.Expanded(child: _champ(_d(m.dateRenouvellementAgrement), tV)),
            ]),
            pw.SizedBox(height: 3),
            pw.Text('Assurance «Responsabilité Civile Professionnelle» (coordonnées de la compagnie) :', style: tB),
            pw.Row(children: [
              pw.Expanded(child: _champ(_v(m.assuranceRCProNom), tV)),
              pw.SizedBox(width: 12),
              pw.Text('N° de police : ', style: tL),
              _champ(_v(m.assuranceRCProPolice), tV, minWidth: 80),
            ]),
            pw.SizedBox(height: 3),
            pw.Text('Assurance automobile (coordonnées de la compagnie) :', style: tB),
            pw.Row(children: [
              pw.Expanded(child: _champ(_v(m.assuranceAutoNom), tV)),
              pw.SizedBox(width: 12),
              pw.Text('N° de police : ', style: tL),
              _champ(_v(m.assuranceAutoPolice), tV, minWidth: 80),
            ]),
          ]),
        ),

        // ─── Article 1 ───────────────────────────────────────────────────────
        _sectionHeader('1. Engagement', bold),
        _subHeader('Convention collective', bold),
        pw.Text(
          'Ce contrat est régi par les dispositions de la Convention collective nationale de la branche du secteur des particuliers employeurs '
          'et de l\'emploi à domicile. Le salarié est informé de la possibilité de consulter le texte de la Convention collective nationale '
          'sur le site internet www.legifrance.gouv.fr.',
          style: tS,
        ),
        pw.SizedBox(height: 4),
        _subHeader('Retraite complémentaire et prévoyance', bold),
        pw.Text('Les institutions compétentes en matière de retraite et de prévoyance sont :', style: tS),
        pw.SizedBox(height: 2),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('- Ircem AGIRC / ARRCO', style: tS),
            pw.SizedBox(height: 1),
            pw.Text('- Ircem prévoyance', style: tS),
          ]),
        ),
        pw.SizedBox(height: 2),
        pw.Text('Toutes deux domiciliées : 261 avenue des Nations-Unies – BP 593 – 59060 ROUBAIX Cedex.', style: tS),

        // ─── Article 2 ───────────────────────────────────────────────────────
        _sectionHeader('2. Lieu de travail et d\'accueil de l\'enfant', bold),
        pw.Text('Le lieu de travail et d\'accueil de l\'enfant est exclusivement fixé :', style: tB),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: _bleuClair,
          child: pw.Row(children: [
            _case(m.lieuTravailType == LieuTravailType.domicileSalarie, bold), pw.SizedBox(width: 4),
            pw.Text('Au domicile du salarié ', style: tB), pw.Text('situé : ', style: tS),
            pw.Expanded(child: _champ(m.lieuTravailType == LieuTravailType.domicileSalarie ? _v(m.lieuTravailAdresse) : null, tV)),
          ]),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: _bleuClair,
          child: pw.Row(children: [
            _case(m.lieuTravailType == LieuTravailType.maisonAma, bold), pw.SizedBox(width: 4),
            pw.Text('Ou dans une maison d\'assistants maternels ', style: tB), pw.Text('située : ', style: tS),
            pw.Expanded(child: _champ(m.lieuTravailType == LieuTravailType.maisonAma ? _v(m.lieuTravailAdresse) : null, tV)),
          ]),
        ),

        // ─── Article 3 ───────────────────────────────────────────────────────
        _sectionHeader('3. Date d\'effet du contrat', bold),
        pw.Text('Le présent contrat est établi pour l\'accueil de l\'enfant :', style: tB),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Text('Nom : ', style: tL),
          pw.Expanded(child: _champ(_v(m.nomEnfant), tV)),
          pw.SizedBox(width: 8),
          pw.Text('Prénom : ', style: tL),
          pw.Expanded(child: _champ(_v(m.prenomEnfant), tV)),
          pw.SizedBox(width: 8),
          pw.Text('Né(e) le : ', style: tL),
          _champ(_d(m.dateNaissanceEnfant), tV, minWidth: 55),
        ]),
        pw.SizedBox(height: 4),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          const pw.TextSpan(text: 'Il prendra effet à la date de l\'embauche, le '),
          pw.TextSpan(text: _d(m.dateEmbauche), style: tB),
          const pw.TextSpan(text: ', pour une durée indéterminée. (À compter du premier jour de la période d\'essai).'),
        ])),
        pw.SizedBox(height: 6),

        _subHeader('Période d\'essai', bold),
        pw.Text('(Articles 44-1 du socle commun et 95-1 du socle spécifique « assistant maternel » de la convention collective).', style: tIt),
        pw.SizedBox(height: 3),
        _ligneChamp('Durée de la période d\'essai :', _v(m.dureePeriodeEssai), tL, tV),
        pw.SizedBox(height: 3),
        pw.Text('La période d\'essai ainsi que le délai de prévenance en cas de rupture durant la période d\'essai sont facultatifs.', style: tS),

        pw.SizedBox(height: 6),
        _subHeader('Période d\'adaptation', bold),
        pw.Text('(Article 94 du socle spécifique « assistant maternel » de la convention collective).', style: tIt),
        pw.SizedBox(height: 2),
        pw.Text('La période d\'adaptation débute le premier jour de travail effectif, pour une durée maximale de 30 jours calendaires.', style: tS),
        pw.SizedBox(height: 2),
        if (m.dureePeriodeAdaptationJours != null)
          pw.RichText(text: pw.TextSpan(style: tS, children: [
            const pw.TextSpan(text: 'Les parties conviennent d\'une période d\'adaptation de '),
            pw.TextSpan(text: _i(m.dureePeriodeAdaptationJours), style: tB),
            const pw.TextSpan(text: ' jours calendaires, organisée du '),
            pw.TextSpan(text: _d(m.dateDebutAdaptation), style: tB),
            const pw.TextSpan(text: ' au '),
            pw.TextSpan(text: _d(m.dateFinAdaptation), style: tB),
            const pw.TextSpan(text: '.'),
          ]))
        else
          pw.Row(children: [
            pw.Text('Les parties conviennent d\'une période d\'adaptation de ', style: tS),
            _champ(null, tV, minWidth: 30),
            pw.Text(' jours calendaires, organisée du ', style: tS),
            _champ(null, tV, minWidth: 40),
            pw.Text(' au ', style: tS),
            _champ(null, tV, minWidth: 40),
            pw.Text('.', style: tS),
          ]),
        pw.SizedBox(height: 2),
        pw.Text(
          'Pendant cette période d\'adaptation, incluse dans la période d\'essai, le salarié sera rémunéré sur la base du salaire mensuel du '
          'présent contrat duquel sera déduite la rémunération des heures de travail non effectué.',
          style: tS,
        ),
        if (m.notesAdaptation != null && m.notesAdaptation!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _bleuClair, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              color: _bleuClair,
            ),
            child: pw.Text(m.notesAdaptation!.trim(), style: tS),
          ),
        ],

        // ─── Article 4 ───────────────────────────────────────────────────────
        _sectionHeader('4. Durée et horaires d\'accueil', bold),
        pw.Text('(Articles 97-1, 97-2 et 98-1-1 du socle spécifique « assistant maternel » de la convention collective).', style: tIt),
        pw.SizedBox(height: 4),
        pw.Text('L\'enfant sera accueilli (au choix) :', style: tB),
        pw.SizedBox(height: 6),

        // Cas n°1
        pw.Text('Cas n°1 :', style: pw.TextStyle(font: bold, fontSize: 9, color: _bleu)),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(cas1, bold), pw.SizedBox(width: 4),
          pw.RichText(text: pw.TextSpan(style: tS, children: [
            pw.TextSpan(text: 'Accueil de l\'enfant sur 52 semaines ', style: tB),
            const pw.TextSpan(text: '(y compris les congés, par période de 12 mois consécutifs)'),
          ])),
        ]),
        pw.SizedBox(height: 3),
        if (cas1) ...[
          pw.Row(children: [
            pw.Text('Le salarié travaille ', style: tS),
            _champ(_e(m.heuresParSemaine, dec: 1), tB, minWidth: 30),
            pw.Text(' heures / semaine réparties comme suit :', style: tS),
          ]),
          pw.SizedBox(height: 4),
          _tableauPlanning(m, bold, regular),
          pw.SizedBox(height: 4),
          pw.RichText(text: pw.TextSpan(style: tS, children: [
            const pw.TextSpan(text: 'Les parties conviennent de la possibilité de modifier les éléments mentionnés ci-dessus, sous réserve du respect d\'un délai de prévenance de '),
            pw.TextSpan(text: _i(m.delaiPrevenanceSemaines), style: tB),
            const pw.TextSpan(text: ' semaines calendaires. (À définir entre les parties.)'),
          ])),
        ] else
          pw.Row(children: [
            pw.Text('Le salarié travaille ', style: tS),
            _champ(null, tV, minWidth: 30),
            pw.Text(' heures / semaine réparties comme suit :', style: tS),
          ]),
        pw.Text('La durée maximale de travail est fixée à 48 heures par semaine, calculée sur une moyenne de 4 mois.', style: tS),
        pw.SizedBox(height: 8),

        // Cas n°2
        pw.Text('Cas n°2 :', style: pw.TextStyle(font: bold, fontSize: 9, color: _bleu)),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(cas2, bold), pw.SizedBox(width: 4),
          pw.RichText(text: pw.TextSpan(style: tS, children: [
            pw.TextSpan(text: 'Accueil de l\'enfant sur 46 semaines ou moins ', style: tB),
            const pw.TextSpan(text: '(hors congés, par période de 12 mois consécutifs)'),
          ])),
        ]),
        pw.SizedBox(height: 3),
        if (cas2) ...[
          pw.RichText(text: pw.TextSpan(style: tS, children: [
            const pw.TextSpan(text: 'Le salarié accueille l\'enfant pendant '),
            pw.TextSpan(text: _i(m.nombreSemainesGarde), style: tB),
            const pw.TextSpan(text: ' semaines. (Préciser le nombre de semaines de garde effective sur les 12 mois consécutifs.)'),
          ])),
          pw.SizedBox(height: 3),
          if (!m.planningParEcrit) ...[
            pw.Row(children: [
              _radio(true, bold), pw.SizedBox(width: 4),
              pw.Text('Le salarié travaille ', style: tS),
              _champ(_e(m.heuresParSemaine, dec: 1), tB, minWidth: 30),
              pw.Text(' heures et ', style: tS),
              _champ(null, tV, minWidth: 20),
              pw.Text(' jours par semaine :', style: tS),
            ]),
            pw.SizedBox(height: 4),
            _tableauPlanning(m, bold, regular),
            pw.SizedBox(height: 4),
            pw.RichText(text: pw.TextSpan(style: tS, children: [
              const pw.TextSpan(text: 'Les parties conviennent de la possibilité de modifier les éléments mentionnés ci-dessus, sous réserve du respect d\'un délai de prévenance de '),
              pw.TextSpan(text: _i(m.delaiPrevenanceSemaines), style: tB),
              const pw.TextSpan(text: ' semaines calendaires (à définir entre les parties).'),
            ])),
            pw.SizedBox(height: 3),
            pw.Text('OU', style: tB),
            pw.SizedBox(height: 3),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _radio(false, bold), pw.SizedBox(width: 4),
              pw.Expanded(child: pw.Text(
                'Les jours et horaires de travail sont définis par un planning de travail remis au salarié par écrit dans le respect d\'un délai de prévenance de '
                '${_i(m.delaiPrevenancePlanningEcrit)} semaines calendaires (à définir entre les parties). Ce délai ne peut être inférieur à 2 mois calendaires.',
                style: tS,
              )),
            ]),
          ] else ...[
            pw.Row(children: [
              _radio(false, bold), pw.SizedBox(width: 4),
              pw.Text('Le salarié travaille ', style: tS),
              _champ(null, tV, minWidth: 30),
              pw.Text(' heures et ', style: tS),
              _champ(null, tV, minWidth: 20),
              pw.Text(' jours par semaine.', style: tS),
            ]),
            pw.SizedBox(height: 3),
            pw.Text('OU', style: tB),
            pw.SizedBox(height: 3),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _radio(true, bold), pw.SizedBox(width: 4),
              pw.Expanded(child: pw.RichText(text: pw.TextSpan(style: tS, children: [
                const pw.TextSpan(text: 'Les jours et horaires de travail sont définis par un planning de travail remis au salarié par écrit dans le respect d\'un délai de prévenance de '),
                pw.TextSpan(text: _i(m.delaiPrevenancePlanningEcrit), style: tB),
                const pw.TextSpan(text: ' semaines calendaires (à définir entre les parties). Ce délai ne peut être inférieur à 2 mois calendaires.'),
              ]))),
            ]),
          ],
        ] else
          pw.Row(children: [
            pw.Text('Le salarié accueille l\'enfant pendant ', style: tS),
            _champ(null, tV, minWidth: 30),
            pw.Text(' semaines.', style: tS),
          ]),
        pw.SizedBox(height: 2),
        pw.Text('La durée maximale de travail est fixée à 48 heures par semaine, calculée sur une moyenne de 4 mois.', style: tS),

        // ─── Article 5 ───────────────────────────────────────────────────────
        _sectionHeader('5. Rémunération à la date d\'embauche', bold),

        _subHeader('Salaire horaire de base', bold),
        pw.Row(children: [
          pw.Text('Salaire horaire brut de base : ', style: tS),
          _champ('${_e(m.salaireHoraireBrut)} €', tB, minWidth: 50),
          pw.SizedBox(width: 16),
          pw.Text('Salaire horaire net de base : ', style: tS),
          _champ('${_e(m.salaireHoraireNet)} €', tB, minWidth: 50),
        ]),
        pw.SizedBox(height: 5),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'Si le salarié est amené à effectuer des heures complémentaires ', style: tB),
          const pw.TextSpan(text: '(au-delà de l\'horaire contractuel et en-deçà de 45 heures hebdomadaires), celles-ci sont rémunérées au taux horaire normal. '
              'Les heures complémentaires peuvent donner lieu à une majoration de salaire, sur décision écrite des parties prévue dans le contrat de travail '
              '(article 110-2 de la convention collective).'),
        ])),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Text('Salaire horaire brut de base majoré : ', style: tS),
          _champ(m.salaireHoraireMajoreBrut != null ? '${_e(m.salaireHoraireMajoreBrut)} €' : null, tB, minWidth: 50),
          pw.SizedBox(width: 16),
          pw.Text('Salaire horaire net de base majoré : ', style: tS),
          _champ(m.salaireHoraireMajoreNet != null ? '${_e(m.salaireHoraireMajoreNet)} €' : null, tB, minWidth: 50),
        ]),
        pw.SizedBox(height: 5),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'Si le salarié est amené à effectuer des heures majorées ', style: tB),
          const pw.TextSpan(text: '(au-delà de 45 heures hebdomadaires), celles-ci donneront lieu à une majoration du salaire et seront rémunérées au taux horaire brut majoré de '),
          pw.TextSpan(text: m.tauxMajorationHeuresMajorees != null ? '${_e(m.tauxMajorationHeuresMajorees, dec: 0)}%' : '_____', style: tB),
          const pw.TextSpan(text: ' (ce taux ne pouvant être inférieur à 10% selon l\'article 110-1 de la convention collective).'),
        ])),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Text('Salaire horaire brut de base majoré : ', style: tS),
          _champ(m.salaireHoraireMajoreesBrut != null ? '${_e(m.salaireHoraireMajoreesBrut)} €' : null, tB, minWidth: 50),
          pw.SizedBox(width: 16),
          pw.Text('Salaire horaire net de base majoré : ', style: tS),
          _champ(m.salaireHorairesMajoreesNet != null ? '${_e(m.salaireHorairesMajoreesNet)} €' : null, tB, minWidth: 50),
        ]),

        pw.SizedBox(height: 6),
        _subHeader('Salaire mensuel de base', bold),

        // Cas 1
        pw.Text('Cas n°1 :', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.Text('Accueil de l\'enfant 52 semaines, y compris les congés, sur une période de 12 mois consécutifs', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.SizedBox(height: 2),
        pw.Text('Le salaire mensuel brut est calculé de la façon suivante :', style: tS),
        pw.SizedBox(height: 2),
        pw.Text('salaire horaire brut  ×  nombre d\'heures de travail hebdomadaire  ×  52 semaines  ÷  12 mois', style: tSmB),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.Text('Salaire mensuel brut de base : ', style: tS),
          _champ(cas1 && m.salaireMensuelBrut != null ? '${_e(m.salaireMensuelBrut)} €' : null, tB, minWidth: 50),
          pw.SizedBox(width: 16),
          pw.Text('Salaire mensuel net de base : ', style: tS),
          _champ(cas1 && m.salaireMensuelNet != null ? '${_e(m.salaireMensuelNet)} €' : null, tB, minWidth: 50),
        ]),
        pw.SizedBox(height: 5),

        // Cas 2
        pw.Text('Cas n°2 :', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.Text('Accueil de l\'enfant 46 semaines ou moins, hors congés, sur une période de 12 mois consécutifs', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.SizedBox(height: 2),
        pw.Text('Le salaire mensuel brut est calculé de la façon suivante :', style: tS),
        pw.SizedBox(height: 2),
        pw.Text('salaire horaire brut  ×  nombre d\'heures de travail hebdomadaire  ×  nombre de semaines programmées  ÷  12 mois', style: tSmB),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.Text('Salaire mensuel brut de base : ', style: tS),
          _champ(cas2 && m.salaireMensuelBrut != null ? '${_e(m.salaireMensuelBrut)} €' : null, tB, minWidth: 50),
          pw.SizedBox(width: 16),
          pw.Text('Salaire mensuel net de base : ', style: tS),
          _champ(cas2 && m.salaireMensuelNet != null ? '${_e(m.salaireMensuelNet)} €' : null, tB, minWidth: 50),
        ]),

        pw.SizedBox(height: 5),
        pw.Text('Régularisation prévisionnelle réalisée chaque année à la fin du mois anniversaire du contrat', style: tB),
        pw.SizedBox(height: 2),
        pw.Text(
          'Selon l\'article 109-2 de la convention collective, une régularisation prévisionnelle est réalisée chaque année à la date anniversaire '
          'du contrat du travail, en comparant les salaires mensualisés versés pendant les douze (12) derniers mois écoulés, aux salaires '
          'qui auraient dû être versés en application du contrat de travail, au titre des heures réellement effectuées. Cette régularisation est '
          'établie par un écrit, signé par les parties.',
          style: tS,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Au cours de l\'exécution du contrat de travail, les régularisations prévisionnelles annuelles se compensent entre elles et n\'entraînent pas de règlement.',
          style: tS,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'À la fin du contrat de travail, les sommes restant dues au titre de la régularisation sont déclarées et font l\'objet d\'un règlement dans '
          'les conditions prévues à l\'article 56 du socle commun de la convention collective.',
          style: tS,
        ),

        pw.SizedBox(height: 6),
        _subHeader('Indemnités d\'entretien, frais de repas et indemnités de déplacement', bold),

        pw.Text('Indemnités d\'entretien', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Le montant horaire de cette indemnité est prévu dans le contrat de travail. Il varie en fonction de la durée de travail effectif, '
          'sans pouvoir être inférieur à 90% du minimum garanti lorsque la durée de travail journalière est de neuf (9) heures.',
          style: tS,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Quel que soit le nombre d\'heures de travail effectif par jour de travail, le montant journalier de cette indemnité ne peut pas être inférieur à 2,65 €.',
          style: tS,
        ),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.Text('Pour une journée de ', style: tS),
          _champ(m.nbHeuresJourneeIndemniteEntretien != null ? _e(m.nbHeuresJourneeIndemniteEntretien, dec: 1) : null, tB, minWidth: 25),
          pw.Text(' heures, le montant horaire de l\'indemnité d\'entretien est de ', style: tS),
          _champ(m.montantHoraireIndemniteEntretien != null ? '${_e(m.montantHoraireIndemniteEntretien)} €' : null, tB, minWidth: 40),
          pw.Text('.', style: tS),
        ]),

        pw.SizedBox(height: 10),
        pw.Text('Frais de repas', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.SizedBox(height: 2),
        pw.Text('Les repas sont fournis par (cocher la mention utile) :', style: tS),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          _case(m.repasParEmployeur, bold), pw.SizedBox(width: 4),
          pw.Text('Le particulier employeur sur une base de ', style: tS),
          _champ(m.repasParEmployeur && m.montantRepasEmployeur != null ? '${_e(m.montantRepasEmployeur)}' : null, tB, minWidth: 30),
          pw.Text(' €/repas.', style: tS),
        ]),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          _case(m.repasParSalarie, bold), pw.SizedBox(width: 4),
          pw.Text('L\'assistant maternel agréé sur une base de ', style: tS),
          _champ(m.repasParSalarie && m.montantRepasSalarie != null ? '${_e(m.montantRepasSalarie)}' : null, tB, minWidth: 30),
          pw.Text(' €/repas.', style: tS),
        ]),

        pw.SizedBox(height: 10),
        pw.Text('Frais de déplacement', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          _champ(m.indemnitesKmParKm != null ? '${_e(m.indemnitesKmParKm)}' : null, tB, minWidth: 30),
          pw.Text(' €/km (ne peut être ni inférieur au barème de l\'administration ni supérieur au barème fiscal).', style: tS),
        ]),

        pw.SizedBox(height: 10),
        pw.Text('Indemnité de fin de contrat', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.SizedBox(height: 2),
        pw.Text(
          'En fin de CDI, en cas de retrait d\'enfant, l\'employeur doit verser une indemnité de rupture si l\'enfant est accueilli depuis au moins '
          '9 mois. Elle est égale à 1/80e du total des salaires bruts perçus pendant la durée du contrat (hors indemnités non soumises à '
          'contributions et cotisations sociales telles que l\'indemnité kilométrique, l\'indemnité d\'entretien et les frais de repas).',
          style: tS,
        ),

        pw.SizedBox(height: 10),
        pw.Text('Date de paiement du salaire', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.SizedBox(height: 2),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          const pw.TextSpan(text: 'La rémunération mensuelle (y compris les indemnités d\'entretien, et le cas échéant les indemnités de repas et de déplacement), '
              'est versée au salarié le '),
          pw.TextSpan(text: _i(m.jourPaiementSalaire), style: tB),
          const pw.TextSpan(text: ' de chaque mois.'),
        ])),
        pw.SizedBox(height: 3),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'Optionnel : ', style: tB),
          const pw.TextSpan(text: 'le salarié donne son accord pour que le particulier employeur confie le versement de la rémunération à l\'Urssaf service Pajemploi, '
              'à travers le dispositif Pajemploi+.  '),
          pw.WidgetSpan(child: _case(m.accordPajemploiPlus, bold)),
        ])),

        // ─── Article 6 ───────────────────────────────────────────────────────
        _sectionHeader('6. Repos hebdomadaire', bold),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'La période de repos hebdomadaire du salarié est fixée au : ', style: tB),
          pw.TextSpan(text: _vb(m.jourReposHebdomadaire), style: tB),
          const pw.TextSpan(text: '  (préciser le jour de la semaine) auquel s\'ajoute le repos quotidien de 11 heures.'),
        ])),
        pw.SizedBox(height: 3),
        pw.Text(
          'Cependant, l\'enfant peut exceptionnellement être confié au salarié, avec son accord écrit. Les parties conviennent alors que '
          'le travail pendant la période de repos hebdomadaire est :',
          style: tS,
        ),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(m.travailReposMajore, bold), pw.SizedBox(width: 4),
          pw.Text('rémunéré au taux horaire dû, majoré à hauteur de 25%.', style: tS),
        ]),
        pw.SizedBox(height: 3),
        pw.Text('OU', style: tB),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(m.travailReposRecupere, bold), pw.SizedBox(width: 4),
          pw.Text('récupéré par un repos équivalent à la durée de travail, majoré de 25%.', style: tS),
        ]),

        // ─── Article 7 ───────────────────────────────────────────────────────
        _sectionHeader('7. Jours fériés', bold),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'Le 1er mai sera ', style: tB),
          const pw.TextSpan(text: '(cocher la mention utile) :'),
        ])),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(m.premierMaiChome, bold), pw.SizedBox(width: 4),
          pw.RichText(text: pw.TextSpan(style: tS, children: [
            pw.TextSpan(text: 'chômé. ', style: tB),
            const pw.TextSpan(text: 'Le paiement du jour férié est inclus dans la mensualisation.'),
          ])),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _case(!m.premierMaiChome, bold), pw.SizedBox(width: 4),
          pw.Expanded(child: pw.RichText(text: pw.TextSpan(style: tS, children: [
            pw.TextSpan(text: 'travaillé. ', style: tB),
            const pw.TextSpan(text: 'En contrepartie, le salarié bénéficie d\'une rémunération majorée à hauteur de 100% (soit une rémunération doublée par rapport à la rémunération habituelle).'),
          ]))),
        ]),
        pw.SizedBox(height: 6),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'Les jours fériés ordinaires travaillés ', style: tB),
          const pw.TextSpan(text: '(cocher uniquement les cases correspondant au(x) jour(s) férié(s) travaillé(s)) :'),
        ])),
        pw.SizedBox(height: 4),
        _grilleJoursFeries(m, bold, regular),
        pw.SizedBox(height: 4),
        pw.Text(
          'Le jour férié chômé qui tombe un jour habituellement travaillé par le salarié est rémunéré dans les conditions prévues par l\'article 47-2 du socle commun de la convention collective.',
          style: tS,
        ),
        pw.SizedBox(height: 3),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          const pw.TextSpan(text: 'En contrepartie du travail un jour férié ordinaire, le salarié perçoit, au titre des heures effectuées, une rémunération majorée de '),
          pw.TextSpan(text: m.tauxMajorationJoursFeries != null ? '${_e(m.tauxMajorationJoursFeries, dec: 0)}%' : '_____', style: tB),
          const pw.TextSpan(text: ' (taux de majoration ne pouvant être inférieur à 10%), calculée sur la base du salaire habituel fixé au présent contrat.'),
        ])),

        // ─── Article 8 ───────────────────────────────────────────────────────
        _sectionHeader('8. Congés annuels', bold),
        pw.Text('(Article 48-1-1 du socle commun et 102-1 et 102-2 du socle spécifique « assistant maternel » de la convention collective)', style: tIt),
        pw.SizedBox(height: 5),

        _subHeader('Prise des congés annuels', bold),
        pw.Text(
          'Les congés payés annuels doivent être pris. Lorsque le salarié accueille les enfants de plusieurs particuliers employeurs, ceux-ci '
          's\'efforcent de fixer d\'un commun accord, ',
          style: tS,
        ),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'au plus tard le 1er mars de chaque année', style: tB),
          const pw.TextSpan(text: ', la date des congés. À défaut d\'accord entre tous les particuliers employeurs, le salarié fixe lui-même ses semaines de congés annuels. Il communique alors les dates de ses congés annuels par écrit à chacun de ses particuliers employeurs, '),
          pw.TextSpan(text: 'au plus tard le 1er mars de chaque année', style: tB),
          const pw.TextSpan(text: ', répartis comme suit :'),
        ])),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 2, bottom: 1),
          child: pw.Text('- 4 semaines pendant la période du 1er mai au 31 octobre de l\'année ;', style: tS),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
          child: pw.Text('- 1 semaine en hiver.', style: tS),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Lorsque le salarié travaille pour un seul particulier employeur, à défaut d\'accord entre les parties sur les dates des congés, '
          'c\'est le particulier employeur qui, au plus tard le 1er mars de chaque année, fixe ces dates et en informe le salarié. '
          'Lorsque le salarié n\'acquiert pas 30 jours ouvrables de congés payés au cours de la période de référence, visée à l\'article 48-1-1-1 du socle commun '
          'de la convention collective, il bénéficie de congés complémentaires non rémunérés pour lui permettre de bénéficier d\'un repos annuel de 30 jours ouvrables.',
          style: tS,
        ),

        pw.SizedBox(height: 5),
        _subHeader('Indemnité de congés annuels', bold),

        pw.Text('Cas n°1 :', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.Text('Accueil de l\'enfant 52 semaines, y compris les congés, sur une période de 12 mois consécutifs', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.SizedBox(height: 2),
        pw.Text('L\'indemnité des congés payés est versée au salarié au moment où les congés sont pris, en lieu et place de la rémunération.', style: tS),
        pw.SizedBox(height: 5),

        pw.Text('Cas n°2 :', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.Text('Accueil de l\'enfant 46 semaines ou moins, hors congés, sur une période de 12 mois consécutifs', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Il est convenu entre les parties que l\'indemnité des congés payés pour l\'année de référence écoulée, calculée au 31 mai de chaque année, '
          's\'ajoute au salaire mensuel de base prévu au présent contrat.',
          style: tS,
        ),
        pw.SizedBox(height: 3),
        pw.Text('Elle est versée (à choisir) :', style: tS),
        pw.SizedBox(height: 2),
        ...[
          MapEntry(ModeVersementCP.enJuin,          'soit en une seule fois au mois de juin,'),
          MapEntry(ModeVersementCP.prisePrincipale, 'soit en une seule fois lors de la prise principale des congés payés,'),
          MapEntry(ModeVersementCP.furetAMesure,    'soit au fur et à mesure de la prise des congés payés au prorata du nombre de jours ouvrables de congés pris.'),
        ].map((e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(children: [
                _case(cas2 && m.modeVersementCP == e.key, bold), pw.SizedBox(width: 4),
                pw.Text(e.value, style: tS),
              ]),
            )),

        pw.SizedBox(height: 5),
        _subHeader('Rémunération de l\'indemnité de congés payés', bold),
        pw.Text(
          'L\'indemnité de congés payés est calculée par comparaison entre les méthodes suivantes, étant précisé que le montant le plus avantageux pour le salarié sera retenu :',
          style: tS,
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, top: 2, bottom: 1),
          child: pw.Text('- La rémunération brute que le salarié aurait perçue pour une durée de travail égale à celle du congé payé.', style: tS),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
          child: pw.Text(
            '- Le dixième (1/10ème) de la rémunération totale brute, hors éventuelle indemnité visée au chapitre VIII du socle commun de la présente convention collective, '
            'perçue par lui au cours de la période de référence pour l\'acquisition des congés payés à rémunérer, y compris celle versée au titre des congés payés pris au cours de ladite période.',
            style: tS,
          ),
        ),

        // ─── Article 9 ───────────────────────────────────────────────────────
        _sectionHeader('9. Confidentialité', bold),
        pw.Text(
          'Les parties s\'engagent à conserver confidentielles les informations personnelles transmises entre elles dans le cadre de l\'exécution '
          'du présent contrat. Elles prennent les mesures nécessaires pour garantir cette confidentialité.',
          style: tS,
        ),

        // ─── Article 10 ──────────────────────────────────────────────────────
        _sectionHeader('10. Conditions particulières à définir s\'il y a lieu', bold),
        pw.Text(
          'Les parties peuvent prévoir certaines règles particulières pour l\'accueil ou l\'accompagnement des enfants accueillis, adaptées à '
          'leur situation (activités conseillées ou à proscrire, utilisation d\'un cahier de liaison, présence d\'animaux …) :',
          style: tS,
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          constraints: const pw.BoxConstraints(minHeight: 50),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _gris, width: 0.5)),
          child: pw.Text(_v(m.conditionsParticulieres).isEmpty ? ' ' : _v(m.conditionsParticulieres), style: tV),
        ),
        // ─── Signatures ──────────────────────────────────────────────────────
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _gris, width: 0.5)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Le présent contrat est établi en deux exemplaires.', style: tB),
            pw.SizedBox(height: 2),
            pw.Text('Un exemplaire est remis au salarié et l\'autre est conservé par le particulier employeur.', style: tS),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              pw.Text('Fait à : ', style: tS),
              pw.Expanded(child: _champ(_v(m.lieuSignature), tB)),
              pw.SizedBox(width: 20),
              pw.Text('Le : ', style: tS),
              _champ(_d(m.dateSignature), tB, minWidth: 70),
            ]),
            pw.SizedBox(height: 16),
            if ((m.telephoneParent2 ?? '').isNotEmpty || (m.emailParent2 ?? '').isNotEmpty) ...[
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _blocSignature('Signature du particulier employeur', m.signatureEmployeur, m.luEtApprouveEmployeur, bold, tS, tSm, fontWaltograph)),
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: _blocSignature('Signature du Parent 2', m.signatureParent2, m.luEtApprouveParent2, bold, tS, tSm, fontWaltograph)),
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: _blocSignature('Signature de l\'assistant maternel', m.signatureSalarie, m.luEtApproveSalarie, bold, tS, tSm, fontWaltograph)),
                ],
              ),
            ] else
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _blocSignature('Signature du particulier employeur', m.signatureEmployeur, m.luEtApprouveEmployeur, bold, tS, tSm, fontWaltograph)),
                  pw.SizedBox(width: 24),
                  pw.Expanded(child: _blocSignature('Signature de l\'assistant maternel', m.signatureSalarie, m.luEtApproveSalarie, bold, tS, tSm, fontWaltograph)),
                ],
              ),
          ]),
        ),
        pw.SizedBox(height: 8),
      ],
    ));

    return pdf.save();
  }

  // ── Grille jours fériés ──────────────────────────────────────────────────────

  pw.Widget _grilleJoursFeries(ContratCdiModel m, pw.Font bold, pw.Font regular) {
    const jours = [
      '1er janvier',                       '14 juillet',
      'Vendredi Saint (Alsace-Moselle)',               '15 août',
      'Lundi de Pâques',                              '1er novembre',
      '8 mai',                                        '11 novembre',
      'Jeudi de l\'Ascension',                        '25 décembre',
      'Lundi de Pentecôte',                           '26 décembre (Alsace-Moselle)',
      'Abolition de l\'esclavage (DROM)',             '',
    ];
    final tS = pw.TextStyle(font: regular, fontSize: 7.5, color: _noir);

    final cells = <pw.Widget>[];
    for (final j in jours) {
      if (j.isEmpty) {
        cells.add(pw.SizedBox());
        continue;
      }
      final checked = m.joursFeriesOrdTravailles.contains(j) ||
          m.joursFeriesOrdTravailles.any((x) => x.startsWith(j.split(' ').first) && j.isNotEmpty);
      cells.add(pw.Row(children: [
        _case(checked, bold), pw.SizedBox(width: 3),
        pw.Expanded(child: pw.Text(j, style: tS)),
      ]));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _bleuClair, width: 0.3),
      columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1)},
      children: List.generate((cells.length / 2).ceil(), (i) {
        final left  = cells[i * 2];
        final right = (i * 2 + 1 < cells.length) ? cells[i * 2 + 1] : pw.SizedBox();
        return pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(3), child: left),
          pw.Padding(padding: const pw.EdgeInsets.all(3), child: right),
        ]);
      }),
    );
  }

  // ── Bloc signature ───────────────────────────────────────────────────────────

  pw.Widget _blocSignature(String titre, Uint8List? pngBytes, String? luEtApprouve, pw.Font bold, pw.TextStyle tS, pw.TextStyle tSm, pw.Font? fontWaltograph) {
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

  // ── Header / Footer ──────────────────────────────────────────────────────────

  pw.Widget _buildHeader(pw.Font bold, pw.Font regular, pw.MemoryImage icone, pw.MemoryImage titre, int page, int total) {
    if (page == 1) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(width: 40),
            pw.Expanded(
              child: pw.Center(child: pw.Image(titre, height: 40, fit: pw.BoxFit.contain)),
            ),
            pw.Image(icone, width: 48, height: 48),
          ],
        ),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _bleuClair, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(child: pw.Text('Contrat CDI — Assistant maternel agréé', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu))),
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
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _bleuClair, width: 0.5))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('$page / $total', style: pw.TextStyle(font: regular, fontSize: 7, color: _gris)),
      ]),
    );
  }

  // ── Partager / Imprimer ──────────────────────────────────────────────────────

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
