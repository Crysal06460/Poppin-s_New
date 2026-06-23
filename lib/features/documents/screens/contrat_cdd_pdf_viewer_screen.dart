import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';
import 'package:poppins_app/features/documents/services/contrat_cdd_pdf_service.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);

class ContratCddPdfViewerScreen extends StatefulWidget {
  /// Pass [model] for the wizard/recap flow — PDF is regenerated on open (hot reload friendly).
  /// Pass [pdfBytes] for the list screen — uses pre-fetched bytes from Firebase.
  final ContratCddModel? model;
  final Uint8List? pdfBytes;
  final String nomEnfant;

  const ContratCddPdfViewerScreen({
    super.key,
    this.model,
    this.pdfBytes,
    required this.nomEnfant,
  }) : assert(model != null || pdfBytes != null, 'Provide model or pdfBytes');

  @override
  State<ContratCddPdfViewerScreen> createState() => _ContratCddPdfViewerScreenState();
}

class _ContratCddPdfViewerScreenState extends State<ContratCddPdfViewerScreen> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.model != null) {
      _generateFromModel();
    } else {
      _bytes = widget.pdfBytes;
    }
  }

  Future<void> _generateFromModel() async {
    try {
      final bytes = await ContratCddPdfService().genererPdf(widget.model!);
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromWizard = widget.model != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _primaryBlue),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: Text(
          'CDD — ${widget.nomEnfant}',
          style: const TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          if (fromWizard)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF27AE60),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contrat CDD généré et enregistré !',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _error != null
                ? Center(child: Text('Erreur : $_error', style: const TextStyle(color: _primaryRed)))
                : _bytes == null
                    ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
                    : PdfPreview(
                        build: (_) => _bytes!,
                        allowPrinting: true,
                        allowSharing: true,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        pdfPreviewPageDecoration: const BoxDecoration(color: Color(0xFFF7F9FC)),
                      ),
          ),
        ],
      ),
    );
  }
}
