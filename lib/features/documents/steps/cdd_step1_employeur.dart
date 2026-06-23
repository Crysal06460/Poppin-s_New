import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class CddStep1Employeur extends StatefulWidget {
  final ContratCddModel model;
  final Function(ContratCddModel) onUpdate;

  const CddStep1Employeur({super.key, required this.model, required this.onUpdate});

  @override
  CddStep1EmployeurState createState() => CddStep1EmployeurState();
}

class CddStep1EmployeurState extends State<CddStep1Employeur> {
  late final TextEditingController _nomNaissanceCtrl;
  late final TextEditingController _nomUsageCtrl;
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _villeCtrl;
  late final TextEditingController _cpCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _pajemploiCtrl;
  late final TextEditingController _telParent2Ctrl;
  late final TextEditingController _emailParent2Ctrl;

  @override
  void initState() {
    super.initState();
    _nomNaissanceCtrl = TextEditingController(text: widget.model.nomNaissanceEmployeur ?? '');
    _nomUsageCtrl = TextEditingController(text: widget.model.nomUsageEmployeur ?? '');
    _prenomCtrl = TextEditingController(text: widget.model.prenomEmployeur ?? '');
    _adresseCtrl = TextEditingController(text: widget.model.adresseEmployeur ?? '');
    _villeCtrl = TextEditingController(text: widget.model.villeEmployeur ?? '');
    _cpCtrl = TextEditingController(text: widget.model.codePostalEmployeur ?? '');
    _telCtrl = TextEditingController(text: widget.model.telephoneEmployeur ?? '');
    _emailCtrl = TextEditingController(text: widget.model.emailEmployeur ?? '');
    _pajemploiCtrl = TextEditingController(text: widget.model.numeroPajemploi ?? '');
    _telParent2Ctrl = TextEditingController(text: widget.model.telephoneParent2 ?? '');
    _emailParent2Ctrl = TextEditingController(text: widget.model.emailParent2 ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nomNaissanceCtrl, _nomUsageCtrl, _prenomCtrl, _adresseCtrl, _villeCtrl, _cpCtrl, _telCtrl, _emailCtrl, _pajemploiCtrl, _telParent2Ctrl, _emailParent2Ctrl]) {
      c.dispose();
    }
    super.dispose();
  }

  bool validate() {
    if ((widget.model.nomNaissanceEmployeur ?? '').trim().length < 2) {
      _showError('Le nom de naissance est obligatoire (min. 2 caractères)');
      return false;
    }
    if ((widget.model.prenomEmployeur ?? '').trim().length < 2) {
      _showError('Le prénom est obligatoire (min. 2 caractères)');
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
    final email = (widget.model.emailEmployeur ?? '').trim();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Adresse email invalide');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: _primaryRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryBlue, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Particulier employeur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
          const SizedBox(height: 4),
          const Text('Le parent ou tuteur qui emploie l\'assistante maternelle', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
          const SizedBox(height: 24),

          TextField(controller: _nomNaissanceCtrl, decoration: _dec('Nom de naissance *'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomNaissanceEmployeur: v))),
          const SizedBox(height: 14),
          TextField(controller: _nomUsageCtrl, decoration: _dec('Nom d\'usage', hint: 'Si différent du nom de naissance'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomUsageEmployeur: v))),
          const SizedBox(height: 14),
          TextField(controller: _prenomCtrl, decoration: _dec('Prénom *'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(prenomEmployeur: v))),
          const SizedBox(height: 14),
          TextField(controller: _adresseCtrl, decoration: _dec('Adresse *'), textCapitalization: TextCapitalization.sentences, onChanged: (v) => widget.onUpdate(widget.model.copyWith(adresseEmployeur: v))),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(flex: 6, child: TextField(controller: _villeCtrl, decoration: _dec('Ville *'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(villeEmployeur: v)))),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: TextField(controller: _cpCtrl, decoration: _dec('Code postal *'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)], onChanged: (v) => widget.onUpdate(widget.model.copyWith(codePostalEmployeur: v)))),
          ]),
          const SizedBox(height: 14),
          TextField(controller: _telCtrl, decoration: _dec('Téléphone'), keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], onChanged: (v) => widget.onUpdate(widget.model.copyWith(telephoneEmployeur: v))),
          const SizedBox(height: 14),
          TextField(controller: _emailCtrl, decoration: _dec('E-mail'), keyboardType: TextInputType.emailAddress, onChanged: (v) => widget.onUpdate(widget.model.copyWith(emailEmployeur: v))),
          const SizedBox(height: 20),

          const Text('En qualité de *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: QualiteCddEmployeur.values.map((q) {
              final sel = widget.model.qualiteEmployeur == q;
              return ChoiceChip(
                label: Text(q.label, style: TextStyle(color: sel ? Colors.white : const Color(0xFF2D3436), fontWeight: FontWeight.w600)),
                selected: sel,
                selectedColor: _primaryBlue,
                backgroundColor: Colors.white,
                side: BorderSide(color: sel ? _primaryBlue : _lightBlue),
                onSelected: (_) {
                  setState(() {});
                  widget.onUpdate(widget.model.copyWith(qualiteEmployeur: q));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          TextField(controller: _pajemploiCtrl, decoration: _dec('N° Pajemploi', hint: 'Y + chiffres'), onChanged: (v) => widget.onUpdate(widget.model.copyWith(numeroPajemploi: v))),
          const SizedBox(height: 20),

          // Parent 2 (optionnel)
          const Text('Parent 2 (facultatif)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
          const SizedBox(height: 4),
          const Text('À renseigner uniquement si deux parents co-emploient', style: TextStyle(fontSize: 12, color: Color(0xFF636E72))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _telParent2Ctrl,
                decoration: _dec('Téléphone Parent 2'),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                onChanged: (v) => widget.onUpdate(widget.model.copyWith(telephoneParent2: v.trim().isEmpty ? null : v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _emailParent2Ctrl,
                decoration: _dec('E-mail Parent 2'),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => widget.onUpdate(widget.model.copyWith(emailParent2: v.trim().isEmpty ? null : v)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 16, color: _primaryBlue),
              SizedBox(width: 8),
              Expanded(child: Text('Code IDCC : 3239 (Convention collective nationale)', style: TextStyle(fontSize: 12, color: _primaryBlue))),
            ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
