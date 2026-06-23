import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:poppins_app/features/documents/services/contrat_cdd_storage_service.dart';
import 'package:poppins_app/features/documents/screens/contrat_cdd_wizard_screen.dart';
import 'package:poppins_app/features/documents/screens/contrat_cdd_pdf_viewer_screen.dart';
import 'package:poppins_app/features/documents/widgets/contrat_cdd_card.dart';
import 'package:poppins_app/features/documents/services/contrat_cdd_pdf_service.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class ContratCddListScreen extends StatelessWidget {
  final String userId;

  const ContratCddListScreen({super.key, required this.userId});

  void _creerNouveauContrat(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ContratCddWizardScreen(userId: userId)));
  }

  Future<void> _voirPdf(BuildContext context, Map<String, dynamic> contrat) async {
    final url = contrat['url'] as String?;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL du PDF non disponible.'), behavior: SnackBarBehavior.floating));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Chargement du PDF…'),
      ]),
      duration: Duration(seconds: 30),
      behavior: SnackBarBehavior.floating,
    ));

    try {
      final response = await http.get(Uri.parse(url));
      messenger.hideCurrentSnackBar();

      if (response.statusCode == 200 && context.mounted) {
        final nomFichier = (contrat['nomFichier'] as String?) ?? 'Contrat CDD';
        final nomAffiche = nomFichier.replaceAll('CDD_', '').replaceAll('.pdf', '').replaceAll('_', ' ');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContratCddPdfViewerScreen(pdfBytes: response.bodyBytes, nomEnfant: nomAffiche)),
        );
      } else if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Erreur HTTP ${response.statusCode}'), behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: _primaryRed, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _partagerPdf(BuildContext context, Map<String, dynamic> contrat) async {
    final url = contrat['url'] as String?;
    if (url == null || url.isEmpty) return;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final nomFichier = (contrat['nomFichier'] as String?) ?? 'contrat_cdd.pdf';
        await ContratCddPdfService().partagerPdf(response.bodyBytes, nomFichier);
      }
    } catch (_) {}
  }

  Future<void> _supprimerContrat(BuildContext context, Map<String, dynamic> contrat) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le contrat ?'),
        content: const Text('Cette action est irréversible. Le fichier PDF sera également supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme == true && context.mounted) {
      try {
        await ContratCddStorageService().supprimerContrat(userId, contrat['id'] as String, contrat['nomFichier'] as String);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: _primaryBlue),
        title: const Text('Contrats CDD', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline, color: _primaryBlue, size: 28),
              tooltip: 'Nouveau contrat CDD',
              onPressed: () => _creerNouveauContrat(context),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ContratCddStorageService().listerContratsGeneres(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primaryBlue));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}', style: const TextStyle(color: _primaryRed)));
          }

          final contrats = snapshot.data ?? [];

          if (contrats.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: contrats.length,
            itemBuilder: (ctx, i) {
              final contrat = contrats[i];
              return ContratCddCard(
                contrat: contrat,
                onVoir: () => _voirPdf(context, contrat),
                onPartager: () => _partagerPdf(context, contrat),
                onSupprimer: () => _supprimerContrat(context, contrat),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _creerNouveauContrat(context),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau CDD', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: _lightBlue, shape: BoxShape.circle),
              child: const Icon(Icons.article_outlined, size: 44, color: _primaryBlue),
            ),
            const SizedBox(height: 20),
            const Text('Aucun contrat CDD', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D3436))),
            const SizedBox(height: 8),
            const Text(
              'Créez votre premier contrat CDD d\'assistant maternel agréé en remplissant le formulaire étape par étape.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF636E72)),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _creerNouveauContrat(context),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Créer un contrat CDD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
