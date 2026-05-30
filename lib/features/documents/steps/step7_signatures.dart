import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);
const Color _green = Color(0xFF27AE60);

class Step7Signatures extends StatefulWidget {
  final EngagementReciproqueModel model;
  final Function(EngagementReciproqueModel) onUpdate;

  const Step7Signatures({
    super.key,
    required this.model,
    required this.onUpdate,
  });

  @override
  Step7SignaturesState createState() => Step7SignaturesState();
}

class Step7SignaturesState extends State<Step7Signatures> {
  late final SignatureController _controllerEmployeur;
  late final SignatureController _controllerSalarie;
  late final TextEditingController _approvalEmployeur;
  late final TextEditingController _approvalSalarie;

  @override
  void initState() {
    super.initState();
    _controllerEmployeur = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _controllerSalarie = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _approvalEmployeur = TextEditingController();
    _approvalSalarie = TextEditingController();
  }

  @override
  void dispose() {
    _controllerEmployeur.dispose();
    _controllerSalarie.dispose();
    _approvalEmployeur.dispose();
    _approvalSalarie.dispose();
    super.dispose();
  }

  // Accepte "lu et approuvé" avec ou sans accent, peu importe la casse
  bool _isLuEtApprouve(String text) {
    final n = text.trim().toLowerCase().replaceAll('é', 'e').replaceAll('è', 'e');
    return n == 'lu et approuve';
  }

  bool validate() {
    if (widget.model.signatureEmployeur == null) {
      _showError("La signature de l'employeur est obligatoire");
      return false;
    }
    if (widget.model.signatureSalarie == null) {
      _showError('La signature du salarié est obligatoire');
      return false;
    }
    return true;
  }

  Future<bool> exporterEtValider() async {
    // Vérifier la saisie "Lu et approuvé"
    if (!_isLuEtApprouve(_approvalEmployeur.text)) {
      _showError('Tapez "Lu et approuvé" dans le champ employeur');
      return false;
    }
    if (!_isLuEtApprouve(_approvalSalarie.text)) {
      _showError('Tapez "Lu et approuvé" dans le champ salarié');
      return false;
    }

    final sigEmpExistante = widget.model.signatureEmployeur;
    final sigSalExistante = widget.model.signatureSalarie;

    if (sigEmpExistante == null && !_controllerEmployeur.isNotEmpty) {
      _showError('Veuillez signer dans la zone employeur');
      return false;
    }
    if (sigSalExistante == null && !_controllerSalarie.isNotEmpty) {
      _showError('Veuillez signer dans la zone salarié');
      return false;
    }

    Uint8List? bytesEmp = sigEmpExistante;
    if (_controllerEmployeur.isNotEmpty) {
      bytesEmp = await _controllerEmployeur.toPngBytes();
      if (bytesEmp == null) {
        _showError("Erreur lors de l'export de la signature employeur");
        return false;
      }
    }

    Uint8List? bytesSal = sigSalExistante;
    if (_controllerSalarie.isNotEmpty) {
      bytesSal = await _controllerSalarie.toPngBytes();
      if (bytesSal == null) {
        _showError('Erreur lors de l\'export de la signature salarié');
        return false;
      }
    }

    widget.onUpdate(
      widget.model.copyWith(
        signatureEmployeur: bytesEmp,
        signatureSalarie: bytesSal,
      ),
    );

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

  String _buildEmployeurLabel() {
    final civilite = widget.model.civiliteEmployeur?.label ?? '';
    final prenom = widget.model.prenomEmployeur ?? '';
    final nom = widget.model.nomEmployeur ?? '';
    return '$civilite $prenom $nom'.trim();
  }

  String _buildSalarieLabel() {
    final civilite = widget.model.civiliteSalarie?.label ?? '';
    final prenom = widget.model.prenomSalarie ?? '';
    final nom = widget.model.nomSalarie ?? '';
    return '$civilite $prenom $nom'.trim();
  }

  Widget _buildSignatureSection({
    required String personLabel,
    required SignatureController controller,
    required TextEditingController approvalController,
    required bool isSigned,
    required Widget? existingSignatureImage,
    required VoidCallback onClear,
  }) {
    final approvalOk = _isLuEtApprouve(approvalController.text);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  personLabel.isNotEmpty ? personLabel : 'Signataire',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3436),
                  ),
                ),
              ),
              if (isSigned || controller.isNotEmpty)
                TextButton(
                  onPressed: () {
                    controller.clear();
                    onClear();
                    setState(() {});
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Effacer',
                    style: TextStyle(color: _primaryRed, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Champ "Lu et approuvé"
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: approvalController,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Tapez : Lu et approuvé',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB2BEC3),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: approvalOk
                        ? const Color(0xFFEAFAF1)
                        : const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: approvalOk ? _green : _lightBlue,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: approvalOk ? _green : _lightBlue,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: approvalOk ? _green : _primaryBlue,
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: approvalOk
                        ? const Icon(Icons.check_circle, color: _green, size: 20)
                        : null,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),

          // Aperçu manuscrit si le texte est valide
          if (approvalOk) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _lightBlue),
              ),
              child: const Text(
                'Lu et approuvé',
                style: TextStyle(
                  fontFamily: 'Waltograph',
                  fontSize: 20,
                  color: Color(0xFF2D3436),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Zone de signature
          if (isSigned && existingSignatureImage != null && controller.isEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 130,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _lightBlue),
                ),
                child: existingSignatureImage,
              ),
            )
          else
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _lightBlue),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Signature(
                      controller: controller,
                      height: 130,
                      backgroundColor: const Color(0xFFF7F9FC),
                    ),
                  ),
                ),
                if (controller.isEmpty)
                  IgnorePointer(
                    child: Text(
                      'Signez ici',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF636E72).withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sigEmp = widget.model.signatureEmployeur;
    final sigSal = widget.model.signatureSalarie;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Signatures',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tapez "Lu et approuvé" puis signez dans chaque zone',
            style: TextStyle(fontSize: 14, color: Color(0xFF636E72)),
          ),
          const SizedBox(height: 24),

          _buildSignatureSection(
            personLabel: _buildEmployeurLabel(),
            controller: _controllerEmployeur,
            approvalController: _approvalEmployeur,
            isSigned: sigEmp != null,
            existingSignatureImage: sigEmp != null
                ? Image.memory(sigEmp, fit: BoxFit.contain)
                : null,
            onClear: () {
              widget.onUpdate(widget.model.copyWith(signatureEmployeur: null));
            },
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          _buildSignatureSection(
            personLabel: _buildSalarieLabel(),
            controller: _controllerSalarie,
            approvalController: _approvalSalarie,
            isSigned: sigSal != null,
            existingSignatureImage: sigSal != null
                ? Image.memory(sigSal, fit: BoxFit.contain)
                : null,
            onClear: () {
              widget.onUpdate(widget.model.copyWith(signatureSalarie: null));
            },
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '⚖️ La signature électronique manuscrite est juridiquement reconnue en France pour ce type de document (Art. 1367 Code Civil)',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF636E72),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
