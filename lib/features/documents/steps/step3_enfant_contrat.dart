import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class Step3EnfantContrat extends StatefulWidget {
  final EngagementReciproqueModel model;
  final Function(EngagementReciproqueModel) onUpdate;

  const Step3EnfantContrat({
    super.key,
    required this.model,
    required this.onUpdate,
  });

  @override
  Step3EnfantContratState createState() => Step3EnfantContratState();
}

class Step3EnfantContratState extends State<Step3EnfantContrat> {
  late TextEditingController _nomEnfantController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _nomEnfantController =
        TextEditingController(text: widget.model.nomEnfant ?? '');
  }

  @override
  void dispose() {
    _nomEnfantController.dispose();
    super.dispose();
  }

  bool validate() {
    if ((widget.model.nomEnfant ?? '').trim().isEmpty) {
      _showError('Le nom et prénom de l\'enfant sont obligatoires');
      return false;
    }
    if (widget.model.dateDebutContrat == null) {
      _showError('La date de début de contrat est obligatoire');
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.model.dateDebutContrat ??
          DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {});
      widget.onUpdate(widget.model.copyWith(dateDebutContrat: picked));
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
    final dateDebutContrat = widget.model.dateDebutContrat;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          const Text(
            'Enfant accueilli & Date de début',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 24),

          // Nom et prénom de l'enfant
          TextField(
            controller: _nomEnfantController,
            decoration: _inputDecoration('Nom et prénom de l\'enfant *'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(nomEnfant: v));
            },
          ),
          const SizedBox(height: 16),

          // Date de début de contrat
          const Text(
            'Date de début de contrat *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dateDebutContrat != null ? _primaryBlue : _lightBlue,
                  width: dateDebutContrat != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: dateDebutContrat != null
                        ? _primaryBlue
                        : const Color(0xFF636E72),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    dateDebutContrat != null
                        ? _dateFormat.format(dateDebutContrat)
                        : 'Sélectionner une date',
                    style: TextStyle(
                      fontSize: 16,
                      color: dateDebutContrat != null
                          ? const Color(0xFF2D3436)
                          : const Color(0xFF636E72),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Note informative
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: _primaryBlue, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cette date correspond à la prise de fonction effective',
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
