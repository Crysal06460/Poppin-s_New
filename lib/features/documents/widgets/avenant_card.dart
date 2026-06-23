import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue   = Color(0xFFDFE9F2);
const Color _primaryRed  = Color(0xFFD94350);

class AvenantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onVoir;
  final VoidCallback onSupprimer;

  const AvenantCard({
    super.key,
    required this.data,
    required this.docId,
    required this.onVoir,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    final nomFichier = data['nomFichier'] as String? ?? 'Avenant';
    final createdAt  = (data['createdAt'] as Timestamp?)?.toDate();
    final dateFmt    = DateFormat('dd/MM/yyyy');

    // Extraire info du nom de fichier : Avenant_Prenom_Nom_date.pdf
    final parts = nomFichier.replaceAll('.pdf', '').split('_');
    final label = parts.length >= 3 ? '${parts[1]} ${parts[2]}' : nomFichier.replaceAll('.pdf', '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.edit_document, color: _primaryBlue, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Avenant — $label',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2D3436)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (createdAt != null)
            Text('Cree le ${dateFmt.format(createdAt)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF636E72))),
        ])),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, color: _primaryBlue, size: 22),
            tooltip: 'Voir le PDF',
            onPressed: onVoir,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _primaryRed, size: 22),
            tooltip: 'Supprimer',
            onPressed: onSupprimer,
          ),
        ]),
      ]),
    );
  }
}
