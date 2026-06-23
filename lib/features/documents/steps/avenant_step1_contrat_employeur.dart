import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/features/documents/models/avenant_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue   = Color(0xFFDFE9F2);

class AvenantStep1ContratEmployeur extends StatefulWidget {
  final AvenantModel model;
  final Function(AvenantModel) onUpdate;
  const AvenantStep1ContratEmployeur({super.key, required this.model, required this.onUpdate});

  @override
  State<AvenantStep1ContratEmployeur> createState() => _AvenantStep1State();
}

class _AvenantStep1State extends State<AvenantStep1ContratEmployeur> {
  late final TextEditingController _nomCtrl, _nomUsageCtrl, _prenomCtrl;
  late final TextEditingController _adresseCtrl, _villeCtrl, _cpCtrl;
  late final TextEditingController _pajemploiCtrl;
  late final TextEditingController _enfantNomCtrl, _enfantPrenomCtrl;
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final m = widget.model;
    _nomCtrl        = TextEditingController(text: m.nomNaissanceEmployeur ?? '');
    _nomUsageCtrl   = TextEditingController(text: m.nomUsageEmployeur ?? '');
    _prenomCtrl     = TextEditingController(text: m.prenomEmployeur ?? '');
    _adresseCtrl    = TextEditingController(text: m.adresseEmployeur ?? '');
    _villeCtrl      = TextEditingController(text: m.villeEmployeur ?? '');
    _cpCtrl         = TextEditingController(text: m.codePostalEmployeur ?? '');
    _pajemploiCtrl  = TextEditingController(text: m.numeroPajemploi ?? '');
    _enfantNomCtrl  = TextEditingController(text: m.nomEnfant ?? '');
    _enfantPrenomCtrl = TextEditingController(text: m.prenomEnfant ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nomCtrl,_nomUsageCtrl,_prenomCtrl,_adresseCtrl,_villeCtrl,_cpCtrl,_pajemploiCtrl,_enfantNomCtrl,_enfantPrenomCtrl]) c.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label, hintText: hint,
    filled: true, fillColor: Colors.white,
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryBlue, width: 2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
  );

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.model.dateContratOriginal ?? DateTime(2024),
      firstDate: DateTime(2010), lastDate: DateTime(2035),
      locale: const Locale('fr'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _primaryBlue, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) {
      widget.onUpdate(widget.model.copyWith(dateContratOriginal: picked));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Contrat original & Employeur',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
        const SizedBox(height: 4),
        const Text('Informations sur le contrat a modifier et l\'employeur',
            style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
        const SizedBox(height: 24),

        // Type de contrat
        const Text('Type de contrat a modifier *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
        const SizedBox(height: 8),
        Row(children: [
          _choix(TypeContratOriginal.cdi, 'CDI', m),
          const SizedBox(width: 12),
          _choix(TypeContratOriginal.cdd, 'CDD', m),
        ]),
        const SizedBox(height: 16),

        // Date contrat original
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: TextField(
              controller: TextEditingController(
                  text: m.dateContratOriginal != null ? _dateFmt.format(m.dateContratOriginal!) : ''),
              decoration: _dec('Date de signature du contrat original *').copyWith(
                suffixIcon: const Icon(Icons.calendar_today_outlined, color: _primaryBlue, size: 20),
                hintText: 'JJ/MM/AAAA',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Enfant (facultatif)
        const Text('Enfant concerne (facultatif)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF636E72))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _enfantPrenomCtrl, decoration: _dec('Prenom de l\'enfant'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(prenomEnfant: v.trim().isEmpty ? null : v)))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _enfantNomCtrl, decoration: _dec('Nom de l\'enfant'),
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomEnfant: v.trim().isEmpty ? null : v)))),
        ]),
        const SizedBox(height: 24),

        const Divider(color: _lightBlue),
        const SizedBox(height: 12),
        const Text('L\'employeur',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _primaryBlue)),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: TextField(controller: _nomCtrl, decoration: _dec('Nom de naissance *'),
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomNaissanceEmployeur: v)))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _nomUsageCtrl, decoration: _dec('Nom d\'usage'),
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomUsageEmployeur: v.trim().isEmpty ? null : v)))),
        ]),
        const SizedBox(height: 14),
        TextField(controller: _prenomCtrl, decoration: _dec('Prenom *'),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => widget.onUpdate(widget.model.copyWith(prenomEmployeur: v))),
        const SizedBox(height: 14),
        TextField(controller: _adresseCtrl, decoration: _dec('Adresse'),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => widget.onUpdate(widget.model.copyWith(adresseEmployeur: v.trim().isEmpty ? null : v))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(flex: 6, child: TextField(controller: _villeCtrl, decoration: _dec('Ville'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(villeEmployeur: v.trim().isEmpty ? null : v)))),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: TextField(controller: _cpCtrl, decoration: _dec('Code postal'),
            keyboardType: TextInputType.number,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(codePostalEmployeur: v.trim().isEmpty ? null : v)))),
        ]),
        const SizedBox(height: 14),
        TextField(controller: _pajemploiCtrl, decoration: _dec('N° Pajemploi'),
          keyboardType: TextInputType.number,
          onChanged: (v) => widget.onUpdate(widget.model.copyWith(numeroPajemploi: v.trim().isEmpty ? null : v))),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _choix(TypeContratOriginal type, String label, AvenantModel m) {
    final selected = m.typeContratOriginal == type;
    return Expanded(
      child: GestureDetector(
        onTap: () { widget.onUpdate(m.copyWith(typeContratOriginal: type)); setState(() {}); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? _primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _primaryBlue : _lightBlue, width: 2),
          ),
          child: Center(child: Text(label, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 15,
            color: selected ? Colors.white : const Color(0xFF636E72),
          ))),
        ),
      ),
    );
  }
}
