import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class Step4ConditionsAccueil extends StatefulWidget {
  final EngagementReciproqueModel model;
  final Function(EngagementReciproqueModel) onUpdate;

  const Step4ConditionsAccueil({
    super.key,
    required this.model,
    required this.onUpdate,
  });

  @override
  Step4ConditionsAccueilState createState() => Step4ConditionsAccueilState();
}

class Step4ConditionsAccueilState extends State<Step4ConditionsAccueil> {
  late TextEditingController _hSemController;
  late TextEditingController _semAnnController;
  late TextEditingController _hMoisController;

  double? _suggestionHeuresmois;

  @override
  void initState() {
    super.initState();
    _hSemController = TextEditingController(
      text: widget.model.heuresParSemaine != null
          ? widget.model.heuresParSemaine!
              .toStringAsFixed(2)
              .replaceAll('.', ',')
          : '',
    );
    _semAnnController = TextEditingController(
      text: widget.model.semainesParAn?.toString() ?? '',
    );
    _hMoisController = TextEditingController(
      text: widget.model.heuresParMois != null
          ? widget.model.heuresParMois!
              .toStringAsFixed(2)
              .replaceAll('.', ',')
          : '',
    );

    _calculerSuggestion();
  }

  @override
  void dispose() {
    _hSemController.dispose();
    _semAnnController.dispose();
    _hMoisController.dispose();
    super.dispose();
  }

  void _calculerSuggestion() {
    final hSem = widget.model.heuresParSemaine;
    final semAnn = widget.model.semainesParAn;
    if (hSem != null && hSem > 0 && semAnn != null && semAnn > 0) {
      _suggestionHeuresmois = hSem * (semAnn / 12.0);
    } else {
      _suggestionHeuresmois = null;
    }
  }

  void _appliquerSuggestion() {
    if (_suggestionHeuresmois != null) {
      final valeur = _suggestionHeuresmois!;
      _hMoisController.text =
          valeur.toStringAsFixed(2).replaceAll('.', ',');
      widget.onUpdate(widget.model.copyWith(heuresParMois: valeur));
    }
  }

  bool validate() {
    final hSem = widget.model.heuresParSemaine;
    final hMois = widget.model.heuresParMois;
    final semAnn = widget.model.semainesParAn;

    if (hSem == null || hSem <= 0) {
      _showError('Les heures par semaine sont obligatoires (> 0)');
      return false;
    }
    if (hSem > 48) {
      _showError('Les heures par semaine ne peuvent pas dépasser 48');
      return false;
    }
    if (semAnn == null || semAnn < 1 || semAnn > 52) {
      _showError('Les semaines par an doivent être comprises entre 1 et 52');
      return false;
    }
    if (hMois == null || hMois <= 0) {
      _showError('Les heures par mois sont obligatoires (> 0)');
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
            'Conditions d\'accueil',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 24),

          // Heures par semaine
          TextField(
            controller: _hSemController,
            decoration: _inputDecoration('Heures par semaine *', suffixText: 'h/sem'),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            onChanged: (v) {
              final parsed =
                  double.tryParse(v.replaceAll(',', '.'));
              widget.onUpdate(
                widget.model.copyWith(heuresParSemaine: parsed),
              );
              setState(() {
                _calculerSuggestion();
              });
            },
          ),
          const SizedBox(height: 16),

          // Semaines par an
          TextField(
            controller: _semAnnController,
            decoration: _inputDecoration('Semaines par an *', suffixText: 'sem/an'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            onChanged: (v) {
              final parsed = int.tryParse(v);
              widget.onUpdate(
                widget.model.copyWith(semainesParAn: parsed),
              );
              setState(() {
                _calculerSuggestion();
              });
            },
          ),
          const SizedBox(height: 16),

          // Heures par mois
          TextField(
            controller: _hMoisController,
            decoration: _inputDecoration('Heures par mois *', suffixText: 'h/mois'),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            onChanged: (v) {
              final parsed =
                  double.tryParse(v.replaceAll(',', '.'));
              widget.onUpdate(
                widget.model.copyWith(heuresParMois: parsed),
              );
            },
          ),

          // Suggestion heures par mois
          if (_suggestionHeuresmois != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text(
                    'Suggestion : ${_suggestionHeuresmois!.toStringAsFixed(2).replaceAll('.', ',')} h/mois',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF636E72),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _appliquerSuggestion,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Appliquer',
                      style: TextStyle(
                        color: _primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
