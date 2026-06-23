import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/features/documents/models/avenant_model.dart';
import 'package:poppins_app/features/documents/services/avenant_pdf_service.dart';
import 'package:poppins_app/features/documents/services/avenant_storage_service.dart';
import 'package:poppins_app/features/documents/screens/avenant_pdf_viewer_screen.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed  = Color(0xFFD94350);
const Color _lightBlue   = Color(0xFFDFE9F2);

class AvenantRecapScreen extends StatefulWidget {
  final AvenantModel model;
  final String userId;
  const AvenantRecapScreen({super.key, required this.model, required this.userId});

  @override
  State<AvenantRecapScreen> createState() => _AvenantRecapScreenState();
}

class _AvenantRecapScreenState extends State<AvenantRecapScreen> {
  bool _isGenerating = false;
  final _dateFmt  = DateFormat('dd/MM/yyyy');
  final _pdfSvc   = AvenantPdfService();
  final _storage  = AvenantStorageService();

  String _d(DateTime? d) => d != null ? _dateFmt.format(d) : '—';
  String _v(String? v) => (v == null || v.trim().isEmpty) ? '—' : v.trim();

  Future<void> _generer() async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await _pdfSvc.genererPdf(widget.model);
      final m     = widget.model;
      final prenom = (m.prenomSalarie ?? 'Salarie').replaceAll(' ', '_');
      final nom    = (m.nomNaissanceSalarie ?? '').replaceAll(' ', '_');
      final date   = DateFormat('yyyyMMdd').format(m.dateSignature ?? DateTime.now());
      final nomFichier = 'Avenant_${prenom}_${nom}_$date.pdf';

      await _storage.sauvegarderPdfGenere(widget.userId, pdfBytes, nomFichier);
      await _storage.supprimerBrouillon(widget.userId);

      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AvenantPdfViewerScreen(
          model: widget.model,
          titre: 'Avenant — ${m.prenomSalarie ?? ''} ${m.nomNaissanceSalarie ?? ''}'.trim(),
        )),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'), backgroundColor: _primaryRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: BackButton(color: _primaryBlue),
        title: const Text('Recapitulatif Avenant',
            style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildBanner(),
          const SizedBox(height: 16),
          _buildSection('Contrat & Employeur', 1, [
            _row('Type contrat', m.typeContratOriginal?.label ?? '—'),
            _row('Date contrat original', _d(m.dateContratOriginal)),
            if ((m.prenomEnfant ?? '').isNotEmpty || (m.nomEnfant ?? '').isNotEmpty)
              _row('Enfant', '${_v(m.prenomEnfant)} ${_v(m.nomEnfant)}'.trim()),
            _row('Employeur', '${_v(m.prenomEmployeur)} ${_v(m.nomNaissanceEmployeur)}'.trim()),
            _row('N° Pajemploi', _v(m.numeroPajemploi)),
          ]),
          _buildSection('Assistant maternel', 2, [
            _row('Salarie', '${_v(m.prenomSalarie)} ${_v(m.nomNaissanceSalarie)}'.trim()),
            _row('Adresse', '${_v(m.adresseSalarie)}, ${_v(m.villeSalarie)} ${_v(m.codePostalSalarie)}'.trim()),
            _row('N° Secu', _v(m.numeroSecu)),
          ]),
          _buildSection('Modifications', 3, [
            _row('Date d\'execution', _d(m.dateExecution)),
            _row('Modifications', (m.modificationsTexte ?? '').length > 80
                ? '${m.modificationsTexte!.substring(0, 80)}...'
                : _v(m.modificationsTexte)),
          ]),
          _buildSection('Signatures', 4, [
            _row('Lieu', _v(m.lieuSignature)),
            _row('Date', _d(m.dateSignature)),
            _row('Signature salarie', m.signatureSalarie != null ? 'Apposee' : 'Manquante'),
            _row('Signature employeur', m.signatureEmployeur != null ? 'Apposee' : 'Manquante'),
          ]),
          const SizedBox(height: 24),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFECF0F1)))),
        child: ElevatedButton.icon(
          onPressed: _isGenerating ? null : _generer,
          icon: _isGenerating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          label: Text(_isGenerating ? 'Generation en cours...' : 'Generer l\'avenant PDF',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primaryBlue, Color(0xFF2980B9)]),
        borderRadius: BorderRadius.circular(14)),
    child: const Row(children: [
      Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verifiez les informations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        SizedBox(height: 2),
        Text('Appuyez sur une section pour modifier.', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ])),
    ]),
  );

  Widget _buildSection(String titre, int etape, List<Widget> rows) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      InkWell(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
        onTap: () => Navigator.pop(context, etape),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(color: _lightBlue, shape: BoxShape.circle),
              child: Center(child: Text('$etape', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryBlue))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2D3436)))),
            const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF95A5A6)),
          ]),
        ),
      ),
      const Divider(height: 1, color: Color(0xFFECF0F1)),
      Padding(padding: const EdgeInsets.all(12), child: Column(children: rows)),
    ]),
  );

  Widget _row(String label, String value) {
    final isWarning = value == 'Manquante';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF636E72)))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: isWarning ? _primaryRed : const Color(0xFF2D3436)))),
      ]),
    );
  }
}
