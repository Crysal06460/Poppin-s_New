import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';

class ContratCddPdfService {
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

  // ── Widget helpers ───────────────────────────────────────────────────────────

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

  pw.Widget _tableauPlanning(ContratCddModel m, pw.Font bold, pw.Font regular) {
    final lS = pw.TextStyle(font: bold,    fontSize: 7, color: _blanc);
    final cS = pw.TextStyle(font: regular, fontSize: 8);
    final lignes = m.lignesPlanning.where((l) => l.jourTravail.trim().isNotEmpty).toList();
    final emptyRow = pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('', style: cS)),
      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('', style: cS)),
      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('', style: cS)),
    ]);
    return pw.Table(
      border: pw.TableBorder.all(color: _gris, width: 0.4),
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(4), 2: pw.FlexColumnWidth(2)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bleu),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Jours de travail', style: lS)),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Horaires de travail', style: lS)),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Nb heures', style: lS)),
          ],
        ),
        if (lignes.isEmpty) ...[emptyRow, emptyRow, emptyRow]
        else ...lignes.map((l) => pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_v(l.jourTravail), style: cS)),
          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_v(l.horairesTravail), style: cS)),
          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_v(l.nbHeuresTravail), style: cS)),
        ])),
      ],
    );
  }

  // ── Génération principale ────────────────────────────────────────────────────

  Future<Uint8List> genererPdf(ContratCddModel m) async {
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
    final tSm = pw.TextStyle(font: regular, fontSize: 7,  color: _gris);
    final tB  = pw.TextStyle(font: bold,    fontSize: 8,  color: _noir);
    final tIt = pw.TextStyle(font: italic,  fontSize: 7,  color: _gris);

    final hasParent2 = (m.telephoneParent2 ?? '').isNotEmpty || (m.emailParent2 ?? '').isNotEmpty;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => _buildHeader(bold, regular, icone, titre, ctx.pageNumber, ctx.pagesCount),
      footer:  (ctx) => _buildFooter(regular, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) => [

        // ── Titre page 1 ──────────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 8, top: 4),
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: pw.BoxDecoration(color: _bleu, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Center(child: pw.Text('Contrat de travail à durée déterminée (CDD)',
              style: pw.TextStyle(font: bold, fontSize: 13, color: _blanc))),
        ),

        // ── Particulier employeur ─────────────────────────────────────────────
        _sectionHeader('Entre le particulier employeur :', bold),
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
          pw.Expanded(child: _ligneChamp('Téléphone :', _v(m.telephoneEmployeur), tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('E-mail :', _v(m.emailEmployeur), tL, tV)),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text('En qualité de : ', style: tL),
          pw.SizedBox(width: 4),
          _case(m.qualiteEmployeur == QualiteCddEmployeur.pere, bold),   pw.SizedBox(width: 2), pw.Text('père  ', style: tS),
          _case(m.qualiteEmployeur == QualiteCddEmployeur.mere, bold),   pw.SizedBox(width: 2), pw.Text('mère  ', style: tS),
          _case(m.qualiteEmployeur == QualiteCddEmployeur.tuteur, bold), pw.SizedBox(width: 2), pw.Text('tuteur  ', style: tS),
          _case(m.qualiteEmployeur == QualiteCddEmployeur.autre, bold),  pw.SizedBox(width: 2), pw.Text('autre', style: tS),
        ]),
        pw.SizedBox(height: 4),
        _ligneChamp('N° Pajemploi : Y', _v(m.numeroPajemploi), tL, tV),
        pw.Text('Code IDCC : 3239', style: tSm),

        // ── Parent 2 (conditionnel) ───────────────────────────────────────────
        if (hasParent2) ...[
          pw.SizedBox(height: 6),
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

        // ── Assistant maternel ────────────────────────────────────────────────
        pw.SizedBox(height: 6),
        _sectionHeader('Et l\'assistant maternel :', bold),
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
          pw.Expanded(child: _ligneChamp('Téléphone :', _v(m.telephoneSalarie), tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('E-mail :', _v(m.emailSalarie), tL, tV)),
        ]),
        _ligneChamp('N° de Sécurité sociale :', _v(m.numeroSecu), tL, tV),
        _ligneChamp('Référence de l\'agrément :', _v(m.referenceAgrement), tL, tV),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Date de délivrance :', _d(m.dateLivraisonAgrement), tL, tV)),
          pw.SizedBox(width: 8),
          pw.Text('ou renouvellement :', style: tL),
          pw.SizedBox(width: 4),
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 1),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4))),
            child: pw.Text(_d(m.dateRenouvellementAgrement), style: tV),
          )),
        ]),
        pw.SizedBox(height: 4),
        pw.Text('Assurance «Responsabilité Civile Professionnelle» (coordonnées de la compagnie) :', style: tB),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Compagnie :', _v(m.assuranceRCProNom), tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('N° de police :', _v(m.assuranceRCProPolice), tL, tV)),
        ]),
        pw.SizedBox(height: 3),
        pw.Text('Assurance automobile (coordonnées de la compagnie) :', style: tB),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Compagnie :', _v(m.assuranceAutoNom), tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('N° de police :', _v(m.assuranceAutoPolice), tL, tV)),
        ]),

        // ── Article 1 — Engagement ────────────────────────────────────────────
        _sectionHeader('1. Engagement', bold),
        _subHeader('Convention collective', bold),
        pw.Text(
          'Ce contrat est régi par les dispositions de la Convention collective nationale de la branche du secteur des particuliers '
          'employeurs et de l\'emploi à domicile. Le salarié est informé de la possibilité de consulter le texte de la Convention '
          'collective nationale sur le site internet www.legifrance.gouv.fr.',
          style: tS,
        ),
        pw.SizedBox(height: 4),
        _subHeader('Motif du recours à un contrat à durée déterminée', bold),
        pw.Text('Le CDD est conclu en raison :', style: tS),
        pw.SizedBox(height: 2),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          constraints: const pw.BoxConstraints(minHeight: 24),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _gris, width: 0.5)),
          child: pw.Text(_v(m.motifCdd).isEmpty ? ' ' : _v(m.motifCdd), style: tV),
        ),
        if ((m.personneRemplaceeNom ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 3),
          _ligneChamp('(Personne remplacée) :', _v(m.personneRemplaceeNom), tL, tV),
        ],
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

        // ── Article 2 — Lieu de travail ───────────────────────────────────────
        _sectionHeader('2. Lieu de travail et d\'accueil de l\'enfant', bold),
        pw.Text('Le lieu de travail et d\'accueil de l\'enfant est exclusivement fixé :', style: tB),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          _case(m.lieuTravailType == LieuTravailTypeCdd.domicileSalarie, bold), pw.SizedBox(width: 4),
          pw.Text('Au domicile du salarié situé : ', style: tS),
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 1),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4))),
            child: pw.Text(m.lieuTravailType == LieuTravailTypeCdd.domicileSalarie ? _v(m.lieuTravailAdresse) : '', style: tV),
          )),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(m.lieuTravailType == LieuTravailTypeCdd.maisonAma, bold), pw.SizedBox(width: 4),
          pw.Text('Ou dans une maison d\'assistants maternels située : ', style: tS),
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 1),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gris, width: 0.4))),
            child: pw.Text(m.lieuTravailType == LieuTravailTypeCdd.maisonAma ? _v(m.lieuTravailAdresse) : '', style: tV),
          )),
        ]),

        // ── Article 3 — Date d'effet ──────────────────────────────────────────
        _sectionHeader('3. Date d\'effet du contrat', bold),
        pw.Text('Le présent contrat est établi pour l\'accueil de l\'enfant :', style: tS),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Nom :', _v(m.nomEnfant), tL, tV)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _ligneChamp('Prénom :', _v(m.prenomEnfant), tL, tV)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _ligneChamp('Né(e) le :', _d(m.dateNaissanceEnfant), tL, tV)),
        ]),
        pw.SizedBox(height: 6),
        _subHeader('Durée du contrat', bold),
        pw.Row(children: [
          _case(m.typeDureeCdd == TypeDureeCdd.datesFixes, bold), pw.SizedBox(width: 4),
          pw.Text('Ce contrat est conclu à partir du ', style: tS),
          pw.Text(_d(m.dateDebutContrat), style: tB),
          pw.Text(' jusqu\'au ', style: tS),
          pw.Text(_d(m.dateFinContrat), style: tB),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(m.typeDureeCdd == TypeDureeCdd.dureeAbsence, bold), pw.SizedBox(width: 4),
          pw.Text('Ce contrat est conclu pour la durée de l\'absence de ', style: tS),
          pw.Text(_vb(m.personneAbsenteNom), style: tB),
        ]),
        if (m.typeDureeCdd == TypeDureeCdd.dureeAbsence && (m.dureeMinimaale ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Row(children: [
            pw.Text('et pour une durée minimale de ', style: tS),
            pw.Text(_v(m.dureeMinimaale), style: tB),
            pw.Text('. Il prendra fin au retour de ', style: tS),
            pw.Text(_vb(m.personneAbsenteNom), style: tB),
            pw.Text(' à son poste de travail.', style: tS),
          ]),
        ],
        pw.SizedBox(height: 5),
        _subHeader('Période d\'essai', bold),
        pw.Text(
          'La période d\'essai ainsi que le délai de prévenance en cas de rupture durant la période d\'essai sont facultatifs.',
          style: tIt,
        ),
        pw.SizedBox(height: 2),
        _ligneChamp('Durée de la période d\'essai :', _v(m.dureePeriodeEssai), tL, tV),
        pw.SizedBox(height: 5),
        _subHeader('Période d\'adaptation', bold),
        pw.Text(
          'La période d\'adaptation débute le premier jour de travail effectif, pour une durée maximale de 30 jours calendaires.',
          style: tS,
        ),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.Text('Les parties conviennent d\'une période d\'adaptation de ', style: tS),
          pw.Text(_i(m.dureePeriodeAdaptationJours), style: tB),
          pw.Text(' jours calendaires, organisée du ', style: tS),
          pw.Text(_d(m.dateDebutAdaptation), style: tB),
          pw.Text(' au ', style: tS),
          pw.Text(_d(m.dateFinAdaptation), style: tB),
          pw.Text('.', style: tS),
        ]),
        pw.SizedBox(height: 2),
        pw.Text(
          'Pendant cette période d\'adaptation, incluse dans la période d\'essai, le salarié sera rémunéré sur la base du '
          'salaire mensuel du présent contrat duquel sera déduite la rémunération des heures de travail non effectué.',
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

        // ── Article 4 — Durée et horaires ─────────────────────────────────────
        _sectionHeader('4. Durée et horaires d\'accueil', bold),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          const pw.TextSpan(text: 'Le salarié accueille l\'enfant pendant '),
          pw.TextSpan(text: _i(m.nombreSemaines), style: tB),
          const pw.TextSpan(text: ' semaines. (Préciser le nombre de semaines de garde effective sur les 12 mois consécutifs.)'),
        ])),
        pw.SizedBox(height: 4),
        if (!m.planningParEcrit) ...[
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            _case(true, bold), pw.SizedBox(width: 4),
            pw.Text('Le salarié travaille ', style: tS),
            pw.Text(_e(m.heuresParSemaine, dec: 1), style: tB),
            pw.Text(' heures et jours par semaine :', style: tS),
          ]),
          pw.SizedBox(height: 6),
          _tableauPlanning(m, bold, regular),
        ] else ...[
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            _case(true, bold), pw.SizedBox(width: 4),
            pw.Expanded(child: pw.RichText(text: pw.TextSpan(style: tS, children: [
              const pw.TextSpan(text: 'Les jours et horaires de travail sont définis par un planning de travail remis au salarié par écrit dans le respect d\'un délai de prévenance de '),
              pw.TextSpan(text: _i(m.delaiPrevenancePlanningEcrit), style: tB),
              const pw.TextSpan(text: ' semaines calendaires. (À définir entre les parties. Ce délai ne peut être inférieur à 2 mois calendaires.)'),
            ]))),
          ]),
        ],
        pw.SizedBox(height: 3),
        pw.Text('La durée maximale de travail est fixée à 48 heures par semaine, calculée sur une moyenne de 4 mois.', style: tIt),

        // ── Article 5 — Rémunération ──────────────────────────────────────────
        _sectionHeader('5. Rémunération à la date d\'embauche', bold),
        _subHeader('Salaire horaire de base', bold),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Salaire horaire brut de base :', '${_e(m.salaireHoraireBrut)} €', tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('Salaire horaire net de base :', '${_e(m.salaireHoraireNet)} €', tL, tV)),
        ]),
        pw.SizedBox(height: 4),
        pw.Text(
          'Si le salarié est amené à effectuer des heures complémentaires (au-delà de l\'horaire contractuel et en-deçà de '
          '45 heures hebdomadaires), celles-ci sont rémunérées au taux horaire normal. Les heures complémentaires peuvent donner '
          'lieu à une majoration de salaire, sur décision écrite des parties prévue dans le contrat de travail (article 110-2 de '
          'la convention collective).',
          style: tS,
        ),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Salaire horaire brut majoré :', '${_e(m.salaireHoraireMajoreBrut)} €', tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('Salaire horaire net majoré :', '${_e(m.salaireHoraireMajoreNet)} €', tL, tV)),
        ]),
        pw.SizedBox(height: 4),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'Si le salarié est amené à effectuer des heures majorées', style: tB),
          const pw.TextSpan(text: ' (au-delà de 45 heures hebdomadaires), celles-ci donneront lieu à une majoration du salaire et seront rémunérées au taux horaire brut majoré de '),
          pw.TextSpan(text: '${_e(m.tauxMajorationHeuresMajorees, dec: 0)} %', style: tB),
          const pw.TextSpan(text: ' (ce taux ne pouvant être inférieur à 10% selon l\'article 110-1 de la convention collective).'),
        ])),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Salaire horaire brut majoré :', '${_e(m.salaireHoraireMajoreesBrut)} €', tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('Salaire horaire net majoré :', '${_e(m.salaireHorairesMajoreesNet)} €', tL, tV)),
        ]),
        pw.SizedBox(height: 5),
        _subHeader('Salaire mensuel de base', bold),
        pw.Text(
          'Le salaire mensuel brut est calculé de la façon suivante :',
          style: tS,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'salaire horaire brut × nombre d\'heures de travail hebdomadaire × nombre de semaines programmées ÷ 12 mois',
          style: pw.TextStyle(font: bold, fontSize: 8, color: _noir),
        ),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(child: _ligneChamp('Salaire mensuel brut de base :', '${_e(m.salaireMensuelBrut)} €', tL, tV)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _ligneChamp('Salaire mensuel net de base :', '${_e(m.salaireMensuelNet)} €', tL, tV)),
        ]),
        pw.SizedBox(height: 8),
        _subHeader('Indemnités d\'entretien, frais de repas et indemnités de déplacement', bold),
        pw.SizedBox(height: 3),
        _subHeader('Indemnités d\'entretien', bold),
        pw.Text(
          'Le montant horaire de cette indemnité est prévu dans le contrat de travail. Il varie en fonction de la durée de travail '
          'effectif, sans pouvoir être inférieur à 90% du minimum garanti lorsque la durée de travail journalière est de neuf (9) heures.',
          style: tS,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Quel que soit le nombre d\'heures de travail effectif par jour de travail, le montant journalier de cette indemnité '
          'ne peut pas être inférieur à 2,65 €.',
          style: tS,
        ),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Text('Pour une journée de ', style: tS),
          pw.Text(_e(m.nbHeuresJourneeIndemniteEntretien, dec: 1), style: tB),
          pw.Text(' heures, le montant horaire de l\'indemnité d\'entretien est de ', style: tS),
          pw.Text('${_e(m.montantHoraireIndemniteEntretien)} €', style: tB),
          pw.Text('.', style: tS),
        ]),
        pw.SizedBox(height: 5),
        _subHeader('Frais de repas', bold),
        pw.Text('Les repas sont fournis par (cocher la mention utile) :', style: tS),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(m.repasParEmployeur, bold), pw.SizedBox(width: 4),
          pw.Text('Le particulier employeur sur une base de ', style: tS),
          pw.Text(m.montantRepasEmployeur != null ? '${_e(m.montantRepasEmployeur)} €/repas.' : '_______  €/repas.', style: tV),
        ]),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          _case(m.repasParSalarie, bold), pw.SizedBox(width: 4),
          pw.Text('L\'assistant maternel agréé sur une base de ', style: tS),
          pw.Text(m.montantRepasSalarie != null ? '${_e(m.montantRepasSalarie)} €/repas.' : '_______  €/repas.', style: tV),
        ]),
        pw.SizedBox(height: 5),
        _subHeader('Frais de déplacement', bold),
        pw.Row(children: [
          pw.Text(_e(m.indemnitesKmParKm), style: tB),
          pw.Text(' €/km (ne peut être ni inférieur au barème de l\'administration ni supérieur au barème fiscal).', style: tS),
        ]),
        pw.SizedBox(height: 5),
        _subHeader('Indemnité de fin de contrat', bold),
        pw.Text(
          'À l\'issue de son contrat, le salarié bénéficiera d\'une indemnité de fin de contrat (Indemnité de précarité) '
          'égale à 10% de la rémunération brute totale (art. L. 1243-8 du Code du Travail).',
          style: tS,
        ),
        pw.SizedBox(height: 5),
        _subHeader('Date de paiement du salaire', bold),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          const pw.TextSpan(text: 'La rémunération mensuelle (y compris les indemnités d\'entretien, et le cas échéant les indemnités de repas et de déplacement), est versée au salarié le '),
          pw.TextSpan(text: _i(m.jourPaiementSalaire), style: tB),
          const pw.TextSpan(text: ' de chaque mois.'),
        ])),
        pw.SizedBox(height: 3),
        pw.Text(
          'Optionnel : le salarié donne son accord pour que le particulier employeur confie le versement de la rémunération '
          'à l\'Urssaf service Pajemploi, à travers le dispositif Pajemploi+.',
          style: tIt,
        ),

        // ── Article 6 — Repos hebdomadaire ────────────────────────────────────
        _sectionHeader('6. Repos hebdomadaire', bold),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          pw.TextSpan(text: 'La période de repos hebdomadaire du salarié est fixée au : ', style: tB),
          pw.TextSpan(text: _vb(m.jourReposHebdomadaire), style: tV),
          const pw.TextSpan(text: ' (préciser le jour de la semaine) auquel s\'ajoute le repos quotidien de 11 heures.'),
        ])),
        pw.SizedBox(height: 4),
        pw.Text(
          'Cependant, l\'enfant peut exceptionnellement être confié au salarié, avec son accord écrit. Les parties conviennent '
          'alors que le travail pendant la période de repos hebdomadaire est :',
          style: tS,
        ),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(m.travailReposMajore, bold), pw.SizedBox(width: 4),
          pw.Text('rémunéré au taux horaire dû, majoré à hauteur de 25%.', style: tS),
        ]),
        pw.SizedBox(height: 2),
        pw.Text('OU', style: tIt),
        pw.SizedBox(height: 2),
        pw.Row(children: [
          _case(m.travailReposRecupere, bold), pw.SizedBox(width: 4),
          pw.Text('récupéré par un repos équivalent à la durée de travail, majoré de 25%.', style: tS),
        ]),

        // ── Article 7 — Jours fériés ──────────────────────────────────────────
        _sectionHeader('7. Jours fériés', bold),
        pw.Text('Le 1er mai sera (cocher la mention utile) :', style: tS),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          _case(m.premierMaiChome, bold), pw.SizedBox(width: 4),
          pw.Text('chômé. Le paiement du jour férié est inclus dans la mensualisation.', style: tS),
        ]),
        pw.SizedBox(height: 2),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _case(!m.premierMaiChome, bold), pw.SizedBox(width: 4),
          pw.Expanded(child: pw.Text(
            'travaillé. En contrepartie, le salarié bénéficie d\'une rémunération majorée à hauteur de 100% '
            '(soit une rémunération doublée par rapport à la rémunération habituelle).',
            style: tS,
          )),
        ]),
        pw.SizedBox(height: 5),
        pw.Text(
          'Les jours fériés ordinaires travaillés (cocher uniquement les cases correspondant au(x) jour(s) férié(s) travaillé(s)) :',
          style: tS,
        ),
        pw.SizedBox(height: 4),
        _buildJoursFeries(m, bold, tS),
        pw.SizedBox(height: 4),
        pw.Text(
          'Le jour férié chômé qui tombe un jour habituellement travaillé par le salarié est rémunéré dans les conditions '
          'prévues par l\'article 47-2 du socle commun de la convention collective.',
          style: tS,
        ),
        pw.SizedBox(height: 3),
        pw.RichText(text: pw.TextSpan(style: tS, children: [
          const pw.TextSpan(text: 'En contrepartie du travail un jour férié ordinaire, le salarié perçoit, au titre des heures effectuées, une rémunération majorée de '),
          pw.TextSpan(text: '${_e(m.tauxMajorationJoursFeries, dec: 0)} %', style: tB),
          const pw.TextSpan(text: ' (taux de majoration ne pouvant être inférieur à 10%), calculée sur la base du salaire habituel fixé au présent contrat.'),
        ])),

        // ── Article 8 — Congés payés ──────────────────────────────────────────
        _sectionHeader('8. Congés payés', bold),
        pw.Text(
          '(Article 48-1-1 du socle commun et 102-1 et 102-2 du socle spécifique « assistant maternel » de la convention collective)',
          style: tIt,
        ),
        pw.SizedBox(height: 5),
        _subHeader('Prise des congés annuels', bold),
        pw.Text(
          'Les congés payés annuels doivent être pris. Lorsque le salarié accueille les enfants de plusieurs particuliers '
          'employeurs, ceux-ci s\'efforcent de fixer d\'un commun accord, ',
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
          'Lorsque le salarié n\'acquiert pas 30 jours ouvrables de congés payés au cours de la période de référence, visée à '
          'l\'article 48-1-1-1 du socle commun de la convention collective, il bénéficie de congés complémentaires non rémunérés '
          'pour lui permettre de bénéficier d\'un repos annuel de 30 jours ouvrables.',
          style: tS,
        ),
        pw.SizedBox(height: 5),
        _subHeader('Rémunération de l\'indemnité de congés payés', bold),
        pw.Text(
          'La rémunération des congés payés dus, s\'effectue selon la règle du 1/10e, versé à la fin du contrat.',
          style: tS,
        ),

        // ── Article 9 — Confidentialité ───────────────────────────────────────
        _sectionHeader('9. Confidentialité', bold),
        pw.Text(
          'Les parties s\'engagent à conserver confidentielles les informations personnelles transmises entre elles dans le cadre '
          'de l\'exécution du présent contrat. Elles prennent les mesures nécessaires pour garantir cette confidentialité.',
          style: tS,
        ),

        // ── Article 10 — Conditions particulières ─────────────────────────────
        _sectionHeader('10. Conditions particulières à définir s\'il y a lieu', bold),
        pw.Text(
          'Les parties peuvent prévoir certaines règles particulières pour l\'accueil ou l\'accompagnement des enfants accueillis, '
          'adaptées à leur situation (activités conseillées ou à proscrire, utilisation d\'un cahier de liaison, présence d\'animaux …) :',
          style: tS,
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          constraints: const pw.BoxConstraints(minHeight: 50),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _gris, width: 0.5)),
          child: pw.Text(_v(m.conditionsParticulieres).isEmpty ? ' ' : _v(m.conditionsParticulieres), style: tV),
        ),

        // ── Signatures ────────────────────────────────────────────────────────
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
              pw.Text('Fait à : ', style: tL),
              pw.Expanded(child: _champ(m.lieuSignature, tV)),
              pw.SizedBox(width: 20),
              pw.Text('Le : ', style: tL),
              _champ(_d(m.dateSignature), tV, minWidth: 80),
            ]),
          ]),
        ),
        pw.SizedBox(height: 16),

        // Signatures
        if (hasParent2) ...[
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: _blocSignature('Signature du particulier employeur', m.signatureEmployeur, m.luEtApprouveEmployeur, bold, tS, tSm, fontWaltograph)),
            pw.SizedBox(width: 16),
            pw.Expanded(child: _blocSignature('Signature du Parent 2', m.signatureParent2, m.luEtApprouveParent2, bold, tS, tSm, fontWaltograph)),
            pw.SizedBox(width: 16),
            pw.Expanded(child: _blocSignature('Signature de l\'assistant maternel', m.signatureSalarie, m.luEtApproveSalarie, bold, tS, tSm, fontWaltograph)),
          ]),
        ] else
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: _blocSignature('Signature du particulier employeur', m.signatureEmployeur, m.luEtApprouveEmployeur, bold, tS, tSm, fontWaltograph)),
            pw.SizedBox(width: 24),
            pw.Expanded(child: _blocSignature('Signature de l\'assistant maternel', m.signatureSalarie, m.luEtApproveSalarie, bold, tS, tSm, fontWaltograph)),
          ]),
        pw.SizedBox(height: 16),
      ],
    ));

    return pdf.save();
  }

  // ── Jours fériés grid ────────────────────────────────────────────────────────

  pw.Widget _buildJoursFeries(ContratCddModel m, pw.Font bold, pw.TextStyle tS) {
    final jours = [
      '1er janvier',
      'Vendredi Saint (Alsace-Moselle uniquement)',
      'Lundi de Pâques',
      '8 mai',
      'Jeudi de l\'Ascension',
      'Lundi de Pentecôte',
      'Abolition de l\'esclavage (DROM uniquement)',
      '14 juillet',
      '15 août',
      '1er novembre',
      '11 novembre',
      '25 décembre',
      '26 décembre (Alsace-Moselle uniquement)',
    ];
    final mid = (jours.length / 2).ceil();
    final col1 = jours.sublist(0, mid);
    final col2 = jours.sublist(mid);

    pw.Widget item(String j) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            _case(m.joursFeriesOrdTravailles.contains(j), bold),
            pw.SizedBox(width: 4),
            pw.Expanded(child: pw.Text(j, style: tS)),
          ]),
        );

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(child: pw.Column(children: col1.map(item).toList())),
      pw.SizedBox(width: 12),
      pw.Expanded(child: pw.Column(children: col2.map(item).toList())),
    ]);
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
          child: pngBytes != null ? pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.contain) : pw.SizedBox(),
        ),
      ]),
    );
  }

  // ── Header / Footer ──────────────────────────────────────────────────────────

  pw.Widget _buildHeader(pw.Font bold, pw.Font regular, pw.MemoryImage icone, pw.MemoryImage titre, int page, int total) {
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
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _bleuClair, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(child: pw.Text('Contrat CDD — Assistant maternel agréé', style: pw.TextStyle(font: bold, fontSize: 8, color: _bleu))),
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
