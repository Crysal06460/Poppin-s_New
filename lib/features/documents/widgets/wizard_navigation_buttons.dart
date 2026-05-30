import 'package:flutter/material.dart';

// Couleurs Poppins
const Color _primaryBlue = Color(0xFF3D9DF2);

/// Barre de navigation en bas du wizard avec boutons Précédent / Suivant.
///
/// - Bouton "Précédent" : outlined, désactivé si [etapeCourante] == 1
/// - Centre : indicateur "Étape X / 7"
/// - Bouton "Suivant" / "Terminer" (si etapeCourante == 7) : ElevatedButton bleu
class WizardNavigationButtons extends StatelessWidget {
  /// Numéro de l'étape courante (1 à 7)
  final int etapeCourante;

  /// Callback bouton Précédent (null = bouton désactivé)
  final VoidCallback? onPrecedent;

  /// Callback bouton Suivant / Terminer
  final VoidCallback onSuivant;

  const WizardNavigationButtons({
    super.key,
    required this.etapeCourante,
    this.onPrecedent,
    required this.onSuivant,
  });

  @override
  Widget build(BuildContext context) {
    final bool estDerniereEtape = etapeCourante == 7;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECF0F1), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // ─── Bouton Précédent ──────────────────────────────────────────
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrecedent,
              icon: Icon(
                Icons.chevron_left,
                color: onPrecedent != null
                    ? const Color(0xFF636E72)
                    : const Color(0xFFBDC3C7),
              ),
              label: Text(
                'Précédent',
                style: TextStyle(
                  color: onPrecedent != null
                      ? const Color(0xFF636E72)
                      : const Color(0xFFBDC3C7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: onPrecedent != null
                      ? const Color(0xFFBDC3C7)
                      : const Color(0xFFECF0F1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // ─── Indicateur d'étape ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Étape $etapeCourante / 7',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF95A5A6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // ─── Bouton Suivant / Terminer ─────────────────────────────────
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onSuivant,
              icon: Icon(
                estDerniereEtape ? Icons.check_circle_outline : Icons.chevron_right,
                color: Colors.white,
              ),
              label: Text(
                estDerniereEtape ? 'Terminer' : 'Suivant',
                style: const TextStyle(
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
