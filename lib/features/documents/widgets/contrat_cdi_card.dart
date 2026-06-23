import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class ContratCdiCard extends StatelessWidget {
  final Map<String, dynamic> contrat;
  final VoidCallback onVoir;
  final VoidCallback onPartager;
  final VoidCallback onSupprimer;

  const ContratCdiCard({
    super.key,
    required this.contrat,
    required this.onVoir,
    required this.onPartager,
    required this.onSupprimer,
  });

  String _formaterDate(dynamic createdAt) {
    if (createdAt == null) return 'Date inconnue';
    try {
      return DateFormat('dd/MM/yyyy').format((createdAt as Timestamp).toDate());
    } catch (_) {
      return 'Date inconnue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nomFichier = (contrat['nomFichier'] as String?) ?? 'Contrat CDI';
    final dateStr = _formaterDate(contrat['createdAt']);
    final nomAffiche = nomFichier.replaceAll('CDI_', '').replaceAll('.pdf', '').replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icône
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.article_outlined, color: _primaryBlue, size: 28),
            ),
            const SizedBox(width: 12),

            // Nom + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CDI — $nomAffiche',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2D3436)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF95A5A6)),
                      const SizedBox(width: 4),
                      Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF95A5A6))),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: onVoir, icon: const Icon(Icons.visibility_outlined), color: _primaryBlue, iconSize: 22, padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
                IconButton(onPressed: onPartager, icon: const Icon(Icons.share_outlined), color: const Color(0xFF636E72), iconSize: 22, padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
                IconButton(onPressed: onSupprimer, icon: const Icon(Icons.delete_outline), color: _primaryRed, iconSize: 22, padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
