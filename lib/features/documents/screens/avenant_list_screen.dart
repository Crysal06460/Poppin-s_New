import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:poppins_app/features/documents/services/avenant_storage_service.dart';
import 'package:poppins_app/features/documents/screens/avenant_wizard_screen.dart';
import 'package:poppins_app/features/documents/screens/avenant_pdf_viewer_screen.dart';
import 'package:poppins_app/features/documents/widgets/avenant_card.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed  = Color(0xFFD94350);
const Color _lightBlue   = Color(0xFFDFE9F2);

class AvenantListScreen extends StatelessWidget {
  final String userId;
  const AvenantListScreen({super.key, required this.userId});

  void _creerNouvelAvenant(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AvenantWizardScreen(userId: userId),
    ));
  }

  Future<void> _voirPdf(BuildContext context, Map<String, dynamic> data) async {
    final url = data['urlPdf'] as String?;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('URL du PDF non disponible.'), behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Chargement du PDF...'),
      ]),
      duration: Duration(seconds: 30),
      behavior: SnackBarBehavior.floating,
    ));

    try {
      final response = await http.get(Uri.parse(url));
      messenger.hideCurrentSnackBar();

      if (response.statusCode == 200 && context.mounted) {
        final nomFichier = (data['nomFichier'] as String?) ?? 'Avenant';
        final titre = nomFichier.replaceAll('.pdf', '').replaceAll('_', ' ');
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AvenantPdfViewerScreen(pdfBytes: response.bodyBytes, titre: titre),
        ));
      } else if (context.mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Erreur HTTP ${response.statusCode}'), behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Erreur : $e'), backgroundColor: _primaryRed, behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _supprimerAvenant(BuildContext context, Map<String, dynamic> data, String docId) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer l\'avenant ?'),
        content: const Text('Cette action est irreversible. Le fichier PDF sera egalement supprime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryRed, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme == true && context.mounted) {
      try {
        await AvenantStorageService().supprimerAvenant(
          userId, docId, data['nomFichier'] as String? ?? '',
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: BackButton(color: _primaryBlue),
        title: const Text('Avenants', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline, color: _primaryBlue, size: 28),
              tooltip: 'Nouvel avenant',
              onPressed: () => _creerNouvelAvenant(context),
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: AvenantStorageService().listeAvenants(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primaryBlue));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}', style: const TextStyle(color: _primaryRed)));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _buildEmptyState(context);

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc  = docs[i];
              final data = doc.data();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AvenantCard(
                  data: data,
                  docId: doc.id,
                  onVoir: () => _voirPdf(context, data),
                  onSupprimer: () => _supprimerAvenant(context, data, doc.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _creerNouvelAvenant(context),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouvel avenant', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(color: _lightBlue, shape: BoxShape.circle),
            child: const Icon(Icons.edit_document, size: 44, color: _primaryBlue),
          ),
          const SizedBox(height: 20),
          const Text('Aucun avenant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D3436))),
          const SizedBox(height: 8),
          const Text(
            'Creez un avenant pour modifier un contrat existant (CDI ou CDD).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF636E72)),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _creerNouvelAvenant(context),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Creer un avenant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ]),
      ),
    );
  }
}
