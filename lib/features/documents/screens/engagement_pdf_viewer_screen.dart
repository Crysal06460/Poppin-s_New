import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

// Couleurs Poppins
const Color _primaryBlue = Color(0xFF3D9DF2);

/// Écran de prévisualisation du PDF généré.
///
/// Utilise [PdfPreview] du package `printing` qui intègre nativement
/// les boutons d'impression et de partage.
class EngagementPdfViewerScreen extends StatelessWidget {
  /// Contenu binaire du PDF à afficher.
  final Uint8List pdfBytes;

  /// Nom de l'enfant utilisé dans le titre de l'AppBar.
  final String nomEnfant;

  const EngagementPdfViewerScreen({
    super.key,
    required this.pdfBytes,
    required this.nomEnfant,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Bouton fermer (X) plutôt qu'un retour classique
        leading: IconButton(
          icon: const Icon(Icons.close, color: _primaryBlue),
          tooltip: 'Fermer',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Aperçu — $nomEnfant',
          style: const TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfPreviewPageDecoration: const BoxDecoration(
          color: Color(0xFFF7F9FC),
        ),
      ),
    );
  }
}
