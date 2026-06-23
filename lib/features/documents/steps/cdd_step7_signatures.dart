import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);
const Color _green = Color(0xFF27AE60);

class CddStep7Signatures extends StatefulWidget {
  final ContratCddModel model;
  final Function(ContratCddModel) onUpdate;

  const CddStep7Signatures({super.key, required this.model, required this.onUpdate});

  @override
  CddStep7SignaturesState createState() => CddStep7SignaturesState();
}

class CddStep7SignaturesState extends State<CddStep7Signatures> {
  late final SignatureController _ctrlEmployeur;
  late final SignatureController _ctrlSalarie;
  late SignatureController _ctrlParent2;
  late final TextEditingController _lieuCtrl;
  late final TextEditingController _approvalEmployeur;
  late final TextEditingController _approvalSalarie;
  late final TextEditingController _approvalParent2;

  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _ctrlEmployeur = SignatureController(penStrokeWidth: 2, penColor: Colors.black, exportBackgroundColor: Colors.white);
    _ctrlSalarie = SignatureController(penStrokeWidth: 2, penColor: Colors.black, exportBackgroundColor: Colors.white);
    _ctrlParent2 = SignatureController(penStrokeWidth: 2, penColor: Colors.black, exportBackgroundColor: Colors.white);
    _lieuCtrl = TextEditingController(text: widget.model.lieuSignature ?? '');
    _approvalEmployeur = TextEditingController();
    _approvalSalarie = TextEditingController();
    _approvalParent2 = TextEditingController();
  }

  @override
  void dispose() {
    _ctrlEmployeur.dispose();
    _ctrlSalarie.dispose();
    _ctrlParent2.dispose();
    _lieuCtrl.dispose();
    _approvalEmployeur.dispose();
    _approvalSalarie.dispose();
    _approvalParent2.dispose();
    super.dispose();
  }

  bool _isLuEtApprouve(String text) {
    final n = text.trim().toLowerCase().replaceAll('é', 'e').replaceAll('è', 'e');
    return n == 'lu et approuve';
  }

  Future<bool> exporterEtValider() async {
    if ((widget.model.lieuSignature ?? '').trim().isEmpty) {
      _showError('Le lieu de signature est obligatoire');
      return false;
    }
    if (widget.model.dateSignature == null) {
      _showError('La date de signature est obligatoire');
      return false;
    }
    if (!_isLuEtApprouve(_approvalEmployeur.text)) {
      _showError('Tapez "Lu et approuvé" dans le champ de l\'employeur');
      return false;
    }
    if (!_isLuEtApprouve(_approvalSalarie.text)) {
      _showError('Tapez "Lu et approuvé" dans le champ de l\'assistant maternel');
      return false;
    }
    if (!_ctrlEmployeur.isNotEmpty) {
      _showError('La signature de l\'employeur est obligatoire');
      return false;
    }
    if (!_ctrlSalarie.isNotEmpty) {
      _showError('La signature de l\'assistante maternelle est obligatoire');
      return false;
    }

    final hasParent2 = (widget.model.telephoneParent2 ?? '').isNotEmpty || (widget.model.emailParent2 ?? '').isNotEmpty;
    if (hasParent2 && _approvalParent2.text.trim().isNotEmpty && !_isLuEtApprouve(_approvalParent2.text)) {
      _showError('Tapez "Lu et approuvé" dans le champ du Parent 2');
      return false;
    }

    final pngEmp = await _ctrlEmployeur.toPngBytes();
    final pngSal = await _ctrlSalarie.toPngBytes();
    final pngP2 = _ctrlParent2.isNotEmpty ? await _ctrlParent2.toPngBytes() : null;

    if (pngEmp == null || pngSal == null) {
      _showError('Erreur lors de l\'export des signatures');
      return false;
    }

    widget.onUpdate(widget.model.copyWith(
      luEtApprouveEmployeur: _approvalEmployeur.text.trim(),
      luEtApproveSalarie: _approvalSalarie.text.trim(),
      luEtApprouveParent2: hasParent2 && _approvalParent2.text.trim().isNotEmpty ? _approvalParent2.text.trim() : null,
      signatureEmployeur: pngEmp,
      signatureSalarie: pngSal,
      signatureParent2: pngP2,
    ));
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _primaryRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryBlue, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
      );

  Widget _buildSignaturePad({
    required String titre,
    required String sousTitre,
    required SignatureController ctrl,
    required TextEditingController approvalCtrl,
    required VoidCallback onClear,
  }) {
    final approvalOk = _isLuEtApprouve(approvalCtrl.text);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2D3436))),
                  const SizedBox(height: 2),
                  Text(sousTitre, style: const TextStyle(fontSize: 12, color: Color(0xFF636E72))),
                ]),
              ),
              if (ctrl.isNotEmpty)
                TextButton(
                  onPressed: () {
                    ctrl.clear();
                    onClear();
                    setState(() {});
                  },
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  child: const Text('Effacer', style: TextStyle(fontSize: 12, color: _primaryRed)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Champ "Lu et approuvé"
          TextField(
            controller: approvalCtrl,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Tapez : Lu et approuvé',
              hintStyle: const TextStyle(color: Color(0xFFB2BEC3), fontSize: 13),
              filled: true,
              fillColor: approvalOk ? const Color(0xFFEAFAF1) : const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: approvalOk ? _green : _lightBlue, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: approvalOk ? _green : _lightBlue, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: approvalOk ? _green : _primaryBlue, width: 1.5),
              ),
              suffixIcon: approvalOk ? const Icon(Icons.check_circle, color: _green, size: 20) : null,
            ),
            style: const TextStyle(fontSize: 14),
          ),

          if (approvalOk) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: _lightBlue)),
              child: const Text('Lu et approuvé', style: TextStyle(fontFamily: 'Waltograph', fontSize: 20, color: Color(0xFF2D3436))),
            ),
          ],

          const SizedBox(height: 12),

          // Zone de signature
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _lightBlue, width: 1.5)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Signature(controller: ctrl, height: 130, backgroundColor: Colors.white),
                ),
              ),
              if (ctrl.isEmpty)
                IgnorePointer(
                  child: Text(
                    'Signez ici',
                    style: TextStyle(fontSize: 16, color: const Color(0xFF636E72).withValues(alpha: 0.5), fontStyle: FontStyle.italic),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lieu, date & signatures', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
          const SizedBox(height: 4),
          const Text('Tapez "Lu et approuvé" puis signez dans chaque zone', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
          const SizedBox(height: 24),

          // Lieu de signature
          TextField(
            controller: _lieuCtrl,
            decoration: _dec('Fait à (ville) *'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(lieuSignature: v)),
          ),
          const SizedBox(height: 14),

          // Date de signature
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.model.dateSignature ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2040),
                locale: const Locale('fr'),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _primaryBlue, onPrimary: Colors.white)),
                  child: child!,
                ),
              );
              if (picked != null) {
                widget.onUpdate(widget.model.copyWith(dateSignature: picked));
                setState(() {});
              }
            },
            child: AbsorbPointer(
              child: TextField(
                controller: TextEditingController(text: widget.model.dateSignature != null ? _dateFmt.format(widget.model.dateSignature!) : ''),
                decoration: _dec('Le (date) *').copyWith(
                  suffixIcon: const Icon(Icons.calendar_today_outlined, color: _primaryBlue, size: 20),
                  hintText: 'JJ/MM/AAAA',
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Info légale
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(12)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: _primaryBlue, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Chaque signature doit être précédée de la mention « Lu et approuvé ».\n'
                'Le contrat est établi en deux exemplaires (un pour chaque partie).',
                style: TextStyle(fontSize: 12, color: _primaryBlue),
              )),
            ]),
          ),
          const SizedBox(height: 24),

          // Signature employeur
          _buildSignaturePad(
            titre: 'Signature du particulier employeur',
            sousTitre: widget.model.prenomEmployeur != null
                ? '${widget.model.prenomEmployeur} ${widget.model.nomNaissanceEmployeur ?? ''}'.trim()
                : 'Particulier employeur',
            ctrl: _ctrlEmployeur,
            approvalCtrl: _approvalEmployeur,
            onClear: () => widget.onUpdate(widget.model.copyWith(signatureEmployeur: null)),
          ),
          const SizedBox(height: 20),

          // Signature salarié
          _buildSignaturePad(
            titre: 'Signature de l\'assistant maternel',
            sousTitre: widget.model.prenomSalarie != null
                ? '${widget.model.prenomSalarie} ${widget.model.nomNaissanceSalarie ?? ''}'.trim()
                : 'Assistant maternel',
            ctrl: _ctrlSalarie,
            approvalCtrl: _approvalSalarie,
            onClear: () => widget.onUpdate(widget.model.copyWith(signatureSalarie: null)),
          ),
          const SizedBox(height: 20),

          // Signature Parent 2 (optionnel)
          if ((widget.model.telephoneParent2 ?? '').isNotEmpty || (widget.model.emailParent2 ?? '').isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _lightBlue.withAlpha(180), borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: _primaryBlue, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Parent 2 détecté — signature facultative', style: TextStyle(fontSize: 12, color: _primaryBlue))),
              ]),
            ),
            const SizedBox(height: 12),
            _buildSignaturePad(
              titre: 'Signature du Parent 2',
              sousTitre: 'Facultatif',
              ctrl: _ctrlParent2,
              approvalCtrl: _approvalParent2,
              onClear: () => widget.onUpdate(widget.model.copyWith(signatureParent2: null)),
            ),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF4F4F4), borderRadius: BorderRadius.circular(12)),
            child: const Text(
              '⚖️ La signature électronique manuscrite est juridiquement reconnue en France pour ce type de document (Art. 1367 Code Civil)',
              style: TextStyle(fontSize: 13, color: Color(0xFF636E72), fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
