import 'package:flutter/material.dart';

// Couleurs Poppins
const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue = Color(0xFFDFE9F2);

/// Barre de progression horizontale du wizard en 7 étapes.
///
/// Affiche 7 cercles numérotés avec icônes et labels, reliés par une ligne.
/// - Étape courante : cercle bleu rempli, label en gras
/// - Étapes validées (index < etapeCourante - 1) : cercle vert avec ✓
/// - Étapes futures : cercle gris
class WizardProgressBar extends StatelessWidget {
  /// Numéro de l'étape courante (1 à 7)
  final int etapeCourante;

  /// Nombre d'étapes complétées (0 à 6)
  final int etapesValidees;

  const WizardProgressBar({
    super.key,
    required this.etapeCourante,
    required this.etapesValidees,
  });

  // Labels des étapes
  static const List<String> _labels = [
    'Employeur',
    'Salarié',
    'Enfant',
    'Conditions',
    'Salaire',
    'Lieu & Date',
    'Signatures',
  ];

  // Icônes des étapes
  static const List<IconData> _icones = [
    Icons.person_outline,
    Icons.badge_outlined,
    Icons.child_care,
    Icons.schedule_outlined,
    Icons.euro_symbol,
    Icons.place_outlined,
    Icons.draw_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 80,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(7, (index) {
              final numeroEtape = index + 1;
              final estCourante = numeroEtape == etapeCourante;
              final estValidee = index < etapesValidees;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cercle + label
                  _buildEtape(
                    numero: numeroEtape,
                    label: _labels[index],
                    icone: _icones[index],
                    estCourante: estCourante,
                    estValidee: estValidee,
                  ),
                  // Ligne de connexion (pas après la dernière étape)
                  if (index < 6)
                    _buildLigneConnexion(estValidee: estValidee),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Construit un cercle avec son label pour une étape donnée.
  Widget _buildEtape({
    required int numero,
    required String label,
    required IconData icone,
    required bool estCourante,
    required bool estValidee,
  }) {
    // Couleur du cercle selon l'état
    final Color couleurFond;
    final Color couleurBordure;
    final Widget contenuCercle;

    if (estValidee) {
      // Étape complétée : vert avec coche
      couleurFond = const Color(0xFF27AE60);
      couleurBordure = const Color(0xFF27AE60);
      contenuCercle = const Icon(
        Icons.check,
        color: Colors.white,
        size: 16,
      );
    } else if (estCourante) {
      // Étape courante : bleu rempli
      couleurFond = _primaryBlue;
      couleurBordure = _primaryBlue;
      contenuCercle = Icon(
        icone,
        color: Colors.white,
        size: 16,
      );
    } else {
      // Étape future : gris
      couleurFond = Colors.white;
      couleurBordure = const Color(0xFFBDC3C7);
      contenuCercle = Icon(
        icone,
        color: const Color(0xFFBDC3C7),
        size: 16,
      );
    }

    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cercle animé
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: couleurFond,
              shape: BoxShape.circle,
              border: Border.all(color: couleurBordure, width: 2),
              boxShadow: estCourante
                  ? [
                      BoxShadow(
                        color: _primaryBlue.withAlpha(77),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Center(child: contenuCercle),
          ),
          const SizedBox(height: 4),
          // Label de l'étape
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  estCourante ? FontWeight.w700 : FontWeight.w400,
              color: estCourante
                  ? _primaryBlue
                  : estValidee
                      ? const Color(0xFF27AE60)
                      : const Color(0xFF95A5A6),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Ligne de connexion entre deux cercles.
  Widget _buildLigneConnexion({required bool estValidee}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 20,
      height: 2,
      color: estValidee
          ? const Color(0xFF27AE60)
          : _lightBlue,
    );
  }
}
