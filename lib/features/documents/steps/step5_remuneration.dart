import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);
const Color _primaryYellow = Color(0xFFF2B705);

class Step5Remuneration extends StatefulWidget {
  final EngagementReciproqueModel model;
  final Function(EngagementReciproqueModel) onUpdate;

  const Step5Remuneration({
    super.key,
    required this.model,
    required this.onUpdate,
  });

  @override
  Step5RemunerationState createState() => Step5RemunerationState();
}

class Step5RemunerationState extends State<Step5Remuneration> {
  late TextEditingController _mensuelController;
  late TextEditingController _horaireController;

  @override
  void initState() {
    super.initState();
    _mensuelController = TextEditingController(
      text: widget.model.salaireMensuelBrut != null
          ? widget.model.salaireMensuelBrut!
              .toStringAsFixed(2)
              .replaceAll('.', ',')
          : '',
    );
    _horaireController = TextEditingController(
      text: widget.model.salaireHoraireBrut != null
          ? widget.model.salaireHoraireBrut!
              .toStringAsFixed(2)
              .replaceAll('.', ',')
          : '',
    );
  }

  @override
  void dispose() {
    _mensuelController.dispose();
    _horaireController.dispose();
    super.dispose();
  }

  bool validate() {
    final mensuel = widget.model.salaireMensuelBrut;
    final horaire = widget.model.salaireHoraireBrut;

    if (mensuel == null || mensuel <= 0) {
      _showError('Le salaire mensuel brut est obligatoire (> 0)');
      return false;
    }
    if (horaire == null || horaire <= 0) {
      _showError('Le salaire horaire brut est obligatoire (> 0)');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? suffixText}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffixText,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _lightBlue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryBlue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _lightBlue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryRed, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          const Text(
            'Rémunération',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 24),

          // Salaire mensuel brut
          TextField(
            controller: _mensuelController,
            decoration: _inputDecoration('Salaire mensuel brut *', suffixText: '€'),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            onChanged: (v) {
              final parsed = double.tryParse(v.replaceAll(',', '.'));
              widget.onUpdate(widget.model.copyWith(salaireMensuelBrut: parsed));
            },
          ),
          const SizedBox(height: 16),

          // Salaire horaire brut
          TextField(
            controller: _horaireController,
            decoration: _inputDecoration('Salaire horaire brut *', suffixText: '€'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            onChanged: (v) {
              final parsed = double.tryParse(v.replaceAll(',', '.'));
              widget.onUpdate(widget.model.copyWith(salaireHoraireBrut: parsed));
            },
          ),
          const SizedBox(height: 24),

          // Note légale
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryYellow.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.warning_amber_rounded,
                    color: _primaryYellow, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Minimum légal 2024 : 3,16 €/heure (hors majoration)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
