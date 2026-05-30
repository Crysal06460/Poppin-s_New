import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Couleurs Poppins
const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

/// Carte représentant un engagement réciproque généré.
///
/// Affiche le nom du fichier, la date de création et 3 actions :
/// voir, partager, supprimer.
class EngagementCard extends StatelessWidget {
  /// Données Firestore : {id, nomFichier, url, createdAt (Timestamp)}
  final Map<String, dynamic> engagement;

  /// Ouvrir/visualiser le PDF
  final VoidCallback onVoir;

  /// Partager le PDF
  final VoidCallback onPartager;

  /// Supprimer le document
  final VoidCallback onSupprimer;

  const EngagementCard({
    super.key,
    required this.engagement,
    required this.onVoir,
    required this.onPartager,
    required this.onSupprimer,
  });

  /// Formate un Timestamp Firestore en "dd/MM/yyyy".
  String _formaterDate(dynamic createdAt) {
    if (createdAt == null) return 'Date inconnue';
    try {
      final date = (createdAt as Timestamp).toDate();
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return 'Date inconnue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nomFichier =
        (engagement['nomFichier'] as String?) ?? 'Document Engagement';
    final String dateStr = _formaterDate(engagement['createdAt']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ─── Icône document ──────────────────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: _primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),

            // ─── Nom fichier + date ──────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nomFichier,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3436),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: Color(0xFF95A5A6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF95A5A6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Actions ────────────────────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Voir
                IconButton(
                  onPressed: onVoir,
                  icon: const Icon(Icons.visibility_outlined),
                  color: _primaryBlue,
                  tooltip: 'Voir',
                  iconSize: 22,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
                // Partager
                IconButton(
                  onPressed: onPartager,
                  icon: const Icon(Icons.share_outlined),
                  color: const Color(0xFF636E72),
                  tooltip: 'Partager',
                  iconSize: 22,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
                // Supprimer
                IconButton(
                  onPressed: onSupprimer,
                  icon: const Icon(Icons.delete_outline),
                  color: _primaryRed,
                  tooltip: 'Supprimer',
                  iconSize: 22,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
