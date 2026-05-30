import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:poppins_app/features/documents/services/engagement_storage_service.dart';
import 'package:poppins_app/features/documents/screens/engagement_wizard_screen.dart';
import 'package:poppins_app/features/documents/screens/engagement_pdf_viewer_screen.dart';
import 'package:poppins_app/features/documents/widgets/engagement_card.dart';

// Couleurs Poppins
const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _fondApp = Color(0xFFF7F9FC);
const Color _lightBlue = Color(0xFFDFE9F2);

/// Écran listant tous les engagements réciproques générés par l'utilisateur.
///
/// Affiche un [StreamBuilder] sur l'historique Firestore.
/// Permet de créer, voir, partager et supprimer des engagements.
class EngagementListScreen extends StatelessWidget {
  final String userId;

  const EngagementListScreen({super.key, required this.userId});

  /// Navigation vers le wizard de création.
  void _creerNouvelEngagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EngagementWizardScreen(userId: userId),
      ),
    );
  }

  /// Télécharge le PDF depuis Firebase Storage et l'ouvre dans le viewer.
  Future<void> _voirPdf(BuildContext context, Map<String, dynamic> engagement) async {
    final url = engagement['url'] as String?;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL du PDF non disponible.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Chargement du PDF…'),
        ]),
        duration: Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final response = await http.get(Uri.parse(url));
      messenger.hideCurrentSnackBar();

      if (response.statusCode == 200 && context.mounted) {
        final nomFichier = (engagement['nomFichier'] as String?) ?? 'Engagement';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EngagementPdfViewerScreen(
              pdfBytes: response.bodyBytes,
              nomEnfant: nomFichier.replaceAll('Engagement_', '').replaceAll('.pdf', '').replaceAll('_', ' '),
            ),
          ),
        );
      } else if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Erreur HTTP ${response.statusCode}'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: _primaryRed, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  /// Partage simplifié (l'URL est disponible, pas les bytes bruts).
  void _partagerPdf(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Fonctionnalité : ouvrez le PDF puis partagez depuis votre appareil.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Confirmation puis suppression directe dans Firestore.
  Future<void> _supprimerEngagement(
    BuildContext context,
    String id,
  ) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce document ?'),
        content: const Text(
          'Cette action est irréversible. Le fichier PDF restera '
          'dans Firebase Storage mais ne sera plus listé ici.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      // Suppression directe dans Firestore (historique)
      await FirebaseFirestore.instance
          .collection('engagements_reciproques')
          .doc(userId)
          .collection('historique')
          .doc(id)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document supprimé.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression : $e'),
            backgroundColor: _primaryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondApp,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Engagements Réciproques',
          style: TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: _primaryBlue),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: EngagementStorageService().listerEngagementsGeneres(userId),
        builder: (context, snapshot) {
          // ── Chargement ────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryBlue),
            );
          }

          // ── Erreur ────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur de chargement : ${snapshot.error}',
                  style: const TextStyle(color: _primaryRed),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final engagements = snapshot.data ?? [];

          // ── Liste vide ────────────────────────────────────────────────
          if (engagements.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _lightBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        size: 40,
                        color: _primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Aucun engagement généré',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Créez votre premier engagement réciproque',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF636E72),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _creerNouvelEngagement(context),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Créer',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Liste des engagements ─────────────────────────────────────
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: engagements.length,
            itemBuilder: (context, index) {
              final engagement = engagements[index];
              final String id = engagement['id'] as String? ?? '';

              return EngagementCard(
                engagement: engagement,
                onVoir: () => _voirPdf(context, engagement),
                onPartager: () => _partagerPdf(context),
                onSupprimer: () => _supprimerEngagement(context, id),
              );
            },
          );
        },
      ),

      // ── FAB Créer ─────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _creerNouvelEngagement(context),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        tooltip: 'Créer un engagement',
        child: const Icon(Icons.add),
      ),
    );
  }
}
