import 'package:flutter/material.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue   = Color(0xFFDFE9F2);

class AvenantWizardProgressBar extends StatelessWidget {
  final int etapeCourante;
  final int totalEtapes;

  const AvenantWizardProgressBar({super.key, required this.etapeCourante, required this.totalEtapes});

  static const _labels = ['Contrat & Employeur', 'Salarie', 'Modifications', 'Signatures'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Column(children: [
        Row(children: List.generate(totalEtapes, (i) {
          final done    = i < etapeCourante;
          final current = i == etapeCourante;
          return Expanded(
            child: Row(children: [
              Expanded(child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done || current ? _primaryBlue : _lightBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                    color: done || current ? _primaryBlue : const Color(0xFFB2BEC3),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ])),
              if (i < totalEtapes - 1) const SizedBox(width: 4),
            ]),
          );
        })),
      ]),
    );
  }
}
