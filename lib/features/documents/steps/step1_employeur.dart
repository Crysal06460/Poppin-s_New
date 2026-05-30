import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class Step1Employeur extends StatefulWidget {
  final EngagementReciproqueModel model;
  final Function(EngagementReciproqueModel) onUpdate;

  const Step1Employeur({
    super.key,
    required this.model,
    required this.onUpdate,
  });

  @override
  Step1EmployeurState createState() => Step1EmployeurState();
}

class Step1EmployeurState extends State<Step1Employeur> {
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _adresseController;
  late TextEditingController _villeController;
  late TextEditingController _cpController;
  late TextEditingController _telController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nomController =
        TextEditingController(text: widget.model.nomEmployeur ?? '');
    _prenomController =
        TextEditingController(text: widget.model.prenomEmployeur ?? '');
    _adresseController =
        TextEditingController(text: widget.model.adresseEmployeur ?? '');
    _villeController =
        TextEditingController(text: widget.model.villeEmployeur ?? '');
    _cpController =
        TextEditingController(text: widget.model.codePostalEmployeur ?? '');
    _telController =
        TextEditingController(text: widget.model.telephoneEmployeur ?? '');
    _emailController =
        TextEditingController(text: widget.model.emailEmployeur ?? '');
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _cpController.dispose();
    _telController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool validate() {
    if (widget.model.civiliteEmployeur == null) {
      _showError('Veuillez sélectionner une civilité');
      return false;
    }
    if ((widget.model.nomEmployeur ?? '').trim().length < 2) {
      _showError('Le nom doit contenir au moins 2 caractères');
      return false;
    }
    if ((widget.model.prenomEmployeur ?? '').trim().length < 2) {
      _showError('Le prénom doit contenir au moins 2 caractères');
      return false;
    }
    if ((widget.model.adresseEmployeur ?? '').trim().isEmpty) {
      _showError('L\'adresse est obligatoire');
      return false;
    }
    if ((widget.model.villeEmployeur ?? '').trim().isEmpty) {
      _showError('La ville est obligatoire');
      return false;
    }
    if ((widget.model.codePostalEmployeur ?? '').trim().length != 5) {
      _showError('Le code postal doit contenir 5 chiffres');
      return false;
    }
    if (widget.model.qualiteEmployeur == null) {
      _showError('Veuillez sélectionner la qualité de l\'employeur');
      return false;
    }
    final tel = (widget.model.telephoneEmployeur ?? '').trim();
    if (tel.isNotEmpty && tel.length != 10) {
      _showError('Le téléphone doit contenir 10 chiffres');
      return false;
    }
    final email = (widget.model.emailEmployeur ?? '').trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Adresse email invalide (vérifiez le @ et le .)');
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          const Text(
            'Futur employeur (Parent / Tuteur)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'La personne qui emploie l\'assistante maternelle',
            style: TextStyle(fontSize: 14, color: Color(0xFF636E72)),
          ),
          const SizedBox(height: 24),

          // Civilité
          const Text(
            'Civilité *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: Civilite.values.map((civilite) {
              final selected = widget.model.civiliteEmployeur == civilite;
              return ChoiceChip(
                label: Text(
                  civilite.label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF2D3436),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: selected,
                selectedColor: _primaryBlue,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? _primaryBlue : _lightBlue,
                ),
                onSelected: (_) {
                  setState(() {});
                  widget.onUpdate(
                    widget.model.copyWith(civiliteEmployeur: civilite),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Nom
          TextField(
            controller: _nomController,
            decoration: _inputDecoration('Nom *'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(nomEmployeur: v));
            },
          ),
          const SizedBox(height: 16),

          // Prénom
          TextField(
            controller: _prenomController,
            decoration: _inputDecoration('Prénom *'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(prenomEmployeur: v));
            },
          ),
          const SizedBox(height: 16),

          // Adresse
          TextField(
            controller: _adresseController,
            decoration: _inputDecoration('Adresse complète *'),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(adresseEmployeur: v));
            },
          ),
          const SizedBox(height: 16),

          // Ville
          TextField(
            controller: _villeController,
            decoration: _inputDecoration('Ville *'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(villeEmployeur: v));
            },
          ),
          const SizedBox(height: 16),

          // Code Postal
          TextField(
            controller: _cpController,
            decoration: _inputDecoration('Code Postal *'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(codePostalEmployeur: v));
            },
          ),
          const SizedBox(height: 24),

          // Qualité
          const Text(
            'Qualité *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QualiteEmployeur.values.map((qualite) {
              final selected = widget.model.qualiteEmployeur == qualite;
              return ChoiceChip(
                label: Text(
                  qualite.label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF2D3436),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: selected,
                selectedColor: _primaryBlue,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? _primaryBlue : _lightBlue,
                ),
                onSelected: (_) {
                  setState(() {});
                  widget.onUpdate(
                    widget.model.copyWith(qualiteEmployeur: qualite),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Téléphone (optionnel, chiffres uniquement, 10 max)
          TextField(
            controller: _telController,
            decoration: _inputDecoration('Téléphone'),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(telephoneEmployeur: v));
            },
          ),
          const SizedBox(height: 16),

          // Email (optionnel)
          TextField(
            controller: _emailController,
            decoration: _inputDecoration('Email'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(emailEmployeur: v));
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
