import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class Step6LieuDate extends StatefulWidget {
  final EngagementReciproqueModel model;
  final Function(EngagementReciproqueModel) onUpdate;

  const Step6LieuDate({
    super.key,
    required this.model,
    required this.onUpdate,
  });

  @override
  Step6LieuDateState createState() => Step6LieuDateState();
}

class Step6LieuDateState extends State<Step6LieuDate> {
  late TextEditingController _lieuController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();

    // Pré-remplir le lieu depuis villeSalarie si non défini
    final lieuInitial = widget.model.lieuSignature ??
        widget.model.villeSalarie ??
        '';
    _lieuController = TextEditingController(text: lieuInitial);

    // Pré-remplir la date de signature si non définie
    if (widget.model.dateSignature == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUpdate(
          widget.model.copyWith(
            lieuSignature: lieuInitial.isNotEmpty ? lieuInitial : null,
            dateSignature: DateTime.now(),
          ),
        );
      });
    } else if (widget.model.lieuSignature == null && lieuInitial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUpdate(
          widget.model.copyWith(lieuSignature: lieuInitial),
        );
      });
    }
  }

  @override
  void dispose() {
    _lieuController.dispose();
    super.dispose();
  }

  bool validate() {
    if ((widget.model.lieuSignature ?? '').trim().isEmpty) {
      _showError('Le lieu de signature est obligatoire');
      return false;
    }
    if (widget.model.dateSignature == null) {
      _showError('La date de signature est obligatoire');
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
      initialDate: widget.model.dateSignature ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {});
      widget.onUpdate(widget.model.copyWith(dateSignature: picked));
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
    final dateSignature = widget.model.dateSignature;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          const Text(
            'Lieu et date de signature',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 24),

          // Fait à (lieu)
          TextField(
            controller: _lieuController,
            decoration: _inputDecoration('Fait à (ville) *'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(lieuSignature: v));
            },
          ),
          const SizedBox(height: 16),

          // Date de signature
          const Text(
            'Date de signature *',
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
                  color: dateSignature != null ? _primaryBlue : _lightBlue,
                  width: dateSignature != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: dateSignature != null
                        ? _primaryBlue
                        : const Color(0xFF636E72),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    dateSignature != null
                        ? _dateFormat.format(dateSignature)
                        : 'Sélectionner une date',
                    style: TextStyle(
                      fontSize: 16,
                      color: dateSignature != null
                          ? const Color(0xFF2D3436)
                          : const Color(0xFF636E72),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
