import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:poppins_app/features/documents/models/avenant_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed  = Color(0xFFD94350);
const Color _lightBlue   = Color(0xFFDFE9F2);
const Color _green       = Color(0xFF27AE60);

class AvenantStep4Signatures extends StatefulWidget {
  final AvenantModel model;
  final Function(AvenantModel) onUpdate;
  const AvenantStep4Signatures({super.key, required this.model, required this.onUpdate});

  @override
  AvenantStep4SignaturesState createState() => AvenantStep4SignaturesState();
}

class AvenantStep4SignaturesState extends State<AvenantStep4Signatures> {
  late final SignatureController _ctrlEmployeur;
  late final SignatureController _ctrlSalarie;
  late final TextEditingController _lieuCtrl;
  late final TextEditingController _approvalEmployeur;
  late final TextEditingController _approvalSalarie;
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _ctrlEmployeur   = SignatureController(penStrokeWidth: 2, penColor: Colors.black, exportBackgroundColor: Colors.white);
    _ctrlSalarie     = SignatureController(penStrokeWidth: 2, penColor: Colors.black, exportBackgroundColor: Colors.white);
    _lieuCtrl        = TextEditingController(text: widget.model.lieuSignature ?? '');
    _approvalEmployeur = TextEditingController();
    _approvalSalarie   = TextEditingController();
  }

  @override
  void dispose() {
    _ctrlEmployeur.dispose(); _ctrlSalarie.dispose();
    _lieuCtrl.dispose(); _approvalEmployeur.dispose(); _approvalSalarie.dispose();
    super.dispose();
  }

  bool _isLuEtApprouve(String text) {
    final n = text.trim().toLowerCase().replaceAll('é', 'e').replaceAll('è', 'e');
    return n == 'lu et approuve';
  }

  Future<bool> exporterEtValider() async {
    if ((widget.model.lieuSignature ?? '').trim().isEmpty) { _showError('Le lieu de signature est obligatoire'); return false; }
    if (widget.model.dateSignature == null) { _showError('La date de signature est obligatoire'); return false; }
    if (!_isLuEtApprouve(_approvalEmployeur.text)) { _showError('Tapez "Lu et approuve" pour l\'employeur'); return false; }
    if (!_isLuEtApprouve(_approvalSalarie.text)) { _showError('Tapez "Lu et approuve" pour l\'assistant maternel'); return false; }
    if (!_ctrlEmployeur.isNotEmpty) { _showError('La signature de l\'employeur est obligatoire'); return false; }
    if (!_ctrlSalarie.isNotEmpty) { _showError('La signature de l\'assistant maternel est obligatoire'); return false; }

    final pngEmp = await _ctrlEmployeur.toPngBytes();
    final pngSal = await _ctrlSalarie.toPngBytes();
    if (pngEmp == null || pngSal == null) { _showError('Erreur export signatures'); return false; }

    widget.onUpdate(widget.model.copyWith(
      luEtApprouveEmployeur: _approvalEmployeur.text.trim(),
      luEtApproveSalarie: _approvalSalarie.text.trim(),
      signatureEmployeur: pngEmp,
      signatureSalarie: pngSal,
    ));
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: _primaryRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: Colors.white,
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
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
    final ok = _isLuEtApprouve(approvalCtrl.text);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2D3436))),
            const SizedBox(height: 2),
            Text(sousTitre, style: const TextStyle(fontSize: 12, color: Color(0xFF636E72))),
          ])),
          if (ctrl.isNotEmpty)
            TextButton(
              onPressed: () { ctrl.clear(); onClear(); setState(() {}); },
              child: const Text('Effacer', style: TextStyle(fontSize: 12, color: _primaryRed)),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: approvalCtrl, onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Tapez : Lu et approuve',
            hintStyle: const TextStyle(color: Color(0xFFB2BEC3), fontSize: 13),
            filled: true, fillColor: ok ? const Color(0xFFEAFAF1) : const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ok ? _green : _lightBlue, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ok ? _green : _lightBlue, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ok ? _green : _primaryBlue, width: 1.5)),
            suffixIcon: ok ? const Icon(Icons.check_circle, color: _green, size: 20) : null,
          ),
          style: const TextStyle(fontSize: 14),
        ),
        if (ok) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: _lightBlue)),
            child: const Text('Lu et approuve', style: TextStyle(fontFamily: 'Waltograph', fontSize: 20, color: Color(0xFF2D3436))),
          ),
        ],
        const SizedBox(height: 12),
        Stack(alignment: Alignment.center, children: [
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _lightBlue, width: 1.5)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Signature(controller: ctrl, height: 130, backgroundColor: Colors.white),
            ),
          ),
          if (ctrl.isEmpty)
            IgnorePointer(child: Text('Signez ici',
                style: TextStyle(fontSize: 16, color: const Color(0xFF636E72).withValues(alpha: 0.5), fontStyle: FontStyle.italic))),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Lieu, date & signatures', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
        const SizedBox(height: 4),
        const Text('Tapez "Lu et approuve" puis signez dans chaque zone', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
        const SizedBox(height: 24),

        TextField(
          controller: _lieuCtrl, decoration: _dec('Fait a (ville) *'),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => widget.onUpdate(widget.model.copyWith(lieuSignature: v)),
        ),
        const SizedBox(height: 14),

        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: widget.model.dateSignature ?? DateTime.now(),
              firstDate: DateTime(2020), lastDate: DateTime(2040),
              locale: const Locale('fr'),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _primaryBlue, onPrimary: Colors.white)),
                child: child!,
              ),
            );
            if (picked != null) { widget.onUpdate(widget.model.copyWith(dateSignature: picked)); setState(() {}); }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: TextEditingController(
                  text: widget.model.dateSignature != null ? _dateFmt.format(widget.model.dateSignature!) : ''),
              decoration: _dec('Le (date) *').copyWith(
                suffixIcon: const Icon(Icons.calendar_today_outlined, color: _primaryBlue, size: 20),
                hintText: 'JJ/MM/AAAA',
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(12)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: _primaryBlue, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Chaque signature doit etre precedee de la mention "Lu et approuve".\n'
              'L\'avenant est etabli en deux exemplaires (un pour chaque partie).',
              style: TextStyle(fontSize: 12, color: _primaryBlue),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        _buildSignaturePad(
          titre: 'Signature de l\'assistant maternel',
          sousTitre: widget.model.prenomSalarie != null
              ? '${widget.model.prenomSalarie} ${widget.model.nomNaissanceSalarie ?? ''}'.trim()
              : 'Assistant maternel',
          ctrl: _ctrlSalarie, approvalCtrl: _approvalSalarie,
          onClear: () => widget.onUpdate(widget.model.copyWith(signatureSalarie: null)),
        ),
        const SizedBox(height: 20),

        _buildSignaturePad(
          titre: 'Signature de l\'employeur',
          sousTitre: widget.model.prenomEmployeur != null
              ? '${widget.model.prenomEmployeur} ${widget.model.nomNaissanceEmployeur ?? ''}'.trim()
              : 'Employeur',
          ctrl: _ctrlEmployeur, approvalCtrl: _approvalEmployeur,
          onClear: () => widget.onUpdate(widget.model.copyWith(signatureEmployeur: null)),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF4F4F4), borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'La signature electronique manuscrite est juridiquement reconnue en France pour ce type de document (Art. 1367 Code Civil)',
            style: TextStyle(fontSize: 13, color: Color(0xFF636E72), fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
