import 'package:flutter/material.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue = Color(0xFFDFE9F2);

class CddWizardProgressBar extends StatelessWidget {
  final int etapeCourante;
  final int etapesValidees;

  const CddWizardProgressBar({super.key, required this.etapeCourante, required this.etapesValidees});

  static const List<String> _labels = [
    'Employeur', 'Salarié', 'Enfant & Durée', 'Horaires', 'Salaire', 'Repos & Fériés', 'Signatures',
  ];

  static const List<IconData> _icones = [
    Icons.person_outline,
    Icons.badge_outlined,
    Icons.child_care,
    Icons.schedule_outlined,
    Icons.euro_symbol,
    Icons.event_outlined,
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
              final numero = index + 1;
              final estCourante = numero == etapeCourante;
              final estValidee = index < etapesValidees;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEtape(numero: numero, label: _labels[index], icone: _icones[index], estCourante: estCourante, estValidee: estValidee),
                  if (index < 6) _buildLigne(estValidee: estValidee),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildEtape({required int numero, required String label, required IconData icone, required bool estCourante, required bool estValidee}) {
    final Color fond;
    final Color bordure;
    final Widget contenu;

    if (estValidee) {
      fond = const Color(0xFF27AE60);
      bordure = const Color(0xFF27AE60);
      contenu = const Icon(Icons.check, color: Colors.white, size: 16);
    } else if (estCourante) {
      fond = _primaryBlue;
      bordure = _primaryBlue;
      contenu = Icon(icone, color: Colors.white, size: 16);
    } else {
      fond = Colors.white;
      bordure = const Color(0xFFBDC3C7);
      contenu = Icon(icone, color: const Color(0xFFBDC3C7), size: 16);
    }

    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: fond,
              shape: BoxShape.circle,
              border: Border.all(color: bordure, width: 2),
              boxShadow: estCourante ? [BoxShadow(color: _primaryBlue.withAlpha(77), blurRadius: 8, spreadRadius: 1)] : null,
            ),
            child: Center(child: contenu),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: estCourante ? FontWeight.w700 : FontWeight.w400,
                color: estCourante ? _primaryBlue : estValidee ? const Color(0xFF27AE60) : const Color(0xFF95A5A6),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildLigne({required bool estValidee}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 16, height: 2,
      color: estValidee ? const Color(0xFF27AE60) : _lightBlue,
    );
  }
}
