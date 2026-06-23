import 'package:flutter/material.dart';
import 'package:poppins_app/features/documents/models/avenant_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue   = Color(0xFFDFE9F2);

class AvenantStep2Salarie extends StatefulWidget {
  final AvenantModel model;
  final Function(AvenantModel) onUpdate;
  const AvenantStep2Salarie({super.key, required this.model, required this.onUpdate});

  @override
  State<AvenantStep2Salarie> createState() => _AvenantStep2State();
}

class _AvenantStep2State extends State<AvenantStep2Salarie> {
  late final TextEditingController _nomCtrl, _nomUsageCtrl, _prenomCtrl;
  late final TextEditingController _adresseCtrl, _villeCtrl, _cpCtrl, _secuCtrl;

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _nomCtrl      = TextEditingController(text: m.nomNaissanceSalarie ?? '');
    _nomUsageCtrl = TextEditingController(text: m.nomUsageSalarie ?? '');
    _prenomCtrl   = TextEditingController(text: m.prenomSalarie ?? '');
    _adresseCtrl  = TextEditingController(text: m.adresseSalarie ?? '');
    _villeCtrl    = TextEditingController(text: m.villeSalarie ?? '');
    _cpCtrl       = TextEditingController(text: m.codePostalSalarie ?? '');
    _secuCtrl     = TextEditingController(text: m.numeroSecu ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nomCtrl,_nomUsageCtrl,_prenomCtrl,_adresseCtrl,_villeCtrl,_cpCtrl,_secuCtrl]) c.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true, fillColor: Colors.white,
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryBlue, width: 2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('L\'assistant maternel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
        const SizedBox(height: 4),
        const Text('Informations sur le salarie', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
        const SizedBox(height: 24),

        Row(children: [
          Expanded(child: TextField(controller: _nomCtrl, decoration: _dec('Nom de naissance *'),
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomNaissanceSalarie: v)))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _nomUsageCtrl, decoration: _dec('Nom d\'usage'),
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomUsageSalarie: v.trim().isEmpty ? null : v)))),
        ]),
        const SizedBox(height: 14),
        TextField(controller: _prenomCtrl, decoration: _dec('Prenom *'),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => widget.onUpdate(widget.model.copyWith(prenomSalarie: v))),
        const SizedBox(height: 14),
        TextField(controller: _adresseCtrl, decoration: _dec('Adresse'),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => widget.onUpdate(widget.model.copyWith(adresseSalarie: v.trim().isEmpty ? null : v))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(flex: 6, child: TextField(controller: _villeCtrl, decoration: _dec('Ville'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(villeSalarie: v.trim().isEmpty ? null : v)))),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: TextField(controller: _cpCtrl, decoration: _dec('Code postal'),
            keyboardType: TextInputType.number,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(codePostalSalarie: v.trim().isEmpty ? null : v)))),
        ]),
        const SizedBox(height: 14),
        TextField(controller: _secuCtrl, decoration: _dec('N° de Securite sociale'),
          keyboardType: TextInputType.number,
          onChanged: (v) => widget.onUpdate(widget.model.copyWith(numeroSecu: v.trim().isEmpty ? null : v))),
        const SizedBox(height: 24),
      ]),
    );
  }
}
