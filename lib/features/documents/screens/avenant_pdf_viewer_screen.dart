import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:poppins_app/features/documents/models/avenant_model.dart';
import 'package:poppins_app/features/documents/services/avenant_pdf_service.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed  = Color(0xFFD94350);

class AvenantPdfViewerScreen extends StatefulWidget {
  final AvenantModel? model;
  final Uint8List? pdfBytes;
  final String titre;

  const AvenantPdfViewerScreen({
    super.key, this.model, this.pdfBytes, required this.titre,
  }) : assert(model != null || pdfBytes != null, 'Provide model or pdfBytes');

  @override
  State<AvenantPdfViewerScreen> createState() => _AvenantPdfViewerScreenState();
}

class _AvenantPdfViewerScreenState extends State<AvenantPdfViewerScreen> {
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
      final bytes = await AvenantPdfService().genererPdf(widget.model!);
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _primaryBlue),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: Text(widget.titre,
            style: const TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700, fontSize: 16),
            overflow: TextOverflow.ellipsis),
      ),
      body: Column(children: [
        if (widget.model != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF27AE60),
            child: const Row(children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Avenant genere et enregistre !',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
          ),
        Expanded(
          child: _error != null
              ? Center(child: Text('Erreur : $_error', style: const TextStyle(color: _primaryRed)))
              : _bytes == null
                  ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
                  : PdfPreview(
                      build: (_) => _bytes!,
                      allowPrinting: true, allowSharing: true,
                      canChangeOrientation: false, canChangePageFormat: false, canDebug: false,
                      pdfPreviewPageDecoration: const BoxDecoration(color: Color(0xFFF7F9FC)),
                    ),
        ),
      ]),
    );
  }
}
