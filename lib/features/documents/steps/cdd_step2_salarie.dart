import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class CddStep2Salarie extends StatefulWidget {
  final ContratCddModel model;
  final Function(ContratCddModel) onUpdate;

  const CddStep2Salarie({super.key, required this.model, required this.onUpdate});

  @override
  CddStep2SalarieState createState() => CddStep2SalarieState();
}

class CddStep2SalarieState extends State<CddStep2Salarie> {
  late final TextEditingController _nomNaissCtrl;
  late final TextEditingController _nomUsageCtrl;
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _villeCtrl;
  late final TextEditingController _cpCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _secuCtrl;
  late final TextEditingController _agremtRefCtrl;
  late final TextEditingController _rcProNomCtrl;
  late final TextEditingController _rcProPoliceCtrl;
  late final TextEditingController _autoNomCtrl;
  late final TextEditingController _autoPoliceCtrl;

  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _nomNaissCtrl = TextEditingController(text: widget.model.nomNaissanceSalarie ?? '');
    _nomUsageCtrl = TextEditingController(text: widget.model.nomUsageSalarie ?? '');
    _prenomCtrl = TextEditingController(text: widget.model.prenomSalarie ?? '');
    _adresseCtrl = TextEditingController(text: widget.model.adresseSalarie ?? '');
    _villeCtrl = TextEditingController(text: widget.model.villeSalarie ?? '');
    _cpCtrl = TextEditingController(text: widget.model.codePostalSalarie ?? '');
    _telCtrl = TextEditingController(text: widget.model.telephoneSalarie ?? '');
    _emailCtrl = TextEditingController(text: widget.model.emailSalarie ?? '');
    _secuCtrl = TextEditingController(text: widget.model.numeroSecu ?? '');
    _agremtRefCtrl = TextEditingController(text: widget.model.referenceAgrement ?? '');
    _rcProNomCtrl = TextEditingController(text: widget.model.assuranceRCProNom ?? '');
    _rcProPoliceCtrl = TextEditingController(text: widget.model.assuranceRCProPolice ?? '');
    _autoNomCtrl = TextEditingController(text: widget.model.assuranceAutoNom ?? '');
    _autoPoliceCtrl = TextEditingController(text: widget.model.assuranceAutoPolice ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nomNaissCtrl, _nomUsageCtrl, _prenomCtrl, _adresseCtrl, _villeCtrl, _cpCtrl, _telCtrl, _emailCtrl, _secuCtrl, _agremtRefCtrl, _rcProNomCtrl, _rcProPoliceCtrl, _autoNomCtrl, _autoPoliceCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  bool validate() {
    if ((widget.model.nomNaissanceSalarie ?? '').trim().length < 2) {
      _showError('Le nom de naissance de l\'assistante est obligatoire');
      return false;
    }
    if ((widget.model.prenomSalarie ?? '').trim().length < 2) {
      _showError('Le prénom de l\'assistante est obligatoire');
      return false;
    }
    if ((widget.model.adresseSalarie ?? '').trim().isEmpty) {
      _showError('L\'adresse de l\'assistante est obligatoire');
      return false;
    }
    if ((widget.model.villeSalarie ?? '').trim().isEmpty) {
      _showError('La ville de l\'assistante est obligatoire');
      return false;
    }
    if ((widget.model.codePostalSalarie ?? '').trim().length != 5) {
      _showError('Le code postal doit contenir 5 chiffres');
      return false;
    }
    if ((widget.model.telephoneSalarie ?? '').trim().isEmpty) {
      _showError('Le téléphone de l\'assistante est obligatoire');
      return false;
    }
    if ((widget.model.referenceAgrement ?? '').trim().isEmpty) {
      _showError('La référence de l\'agrément est obligatoire');
      return false;
    }
    if (widget.model.dateLivraisonAgrement == null && widget.model.dateRenouvellementAgrement == null) {
      _showError('La date de l\'agrément (livraison ou renouvellement) est obligatoire');
      return false;
    }
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

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryBlue, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
      );

  Future<void> _pickDate(DateTime? current, void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2040),
      locale: const Locale('fr'),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _primaryBlue, onPrimary: Colors.white)), child: child!),
    );
    if (picked != null) onPicked(picked);
  }

  Widget _dateField(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(text: date != null ? _dateFmt.format(date) : ''),
          decoration: _dec(label).copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, color: _primaryBlue, size: 20), hintText: 'JJ/MM/AAAA'),
        ),
      ),
    );
  }

  Widget _blockTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _primaryBlue)),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assistant maternel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
          const SizedBox(height: 4),
          const Text('Informations de l\'assistante maternelle agréée', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
          const SizedBox(height: 20),

          _blockTitle('Identité'),

          TextField(controller: _nomNaissCtrl, decoration: _dec('Nom de naissance *'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomNaissanceSalarie: v))),
          const SizedBox(height: 14),
          TextField(controller: _nomUsageCtrl, decoration: _dec('Nom d\'usage', hint: 'Si différent du nom de naissance'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomUsageSalarie: v))),
          const SizedBox(height: 14),
          TextField(controller: _prenomCtrl, decoration: _dec('Prénom *'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(prenomSalarie: v))),
          const SizedBox(height: 14),
          TextField(controller: _adresseCtrl, decoration: _dec('Adresse *'), textCapitalization: TextCapitalization.sentences, onChanged: (v) => widget.onUpdate(widget.model.copyWith(adresseSalarie: v))),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(flex: 6, child: TextField(controller: _villeCtrl, decoration: _dec('Ville *'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(villeSalarie: v)))),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: TextField(controller: _cpCtrl, decoration: _dec('CP *'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)], onChanged: (v) => widget.onUpdate(widget.model.copyWith(codePostalSalarie: v)))),
          ]),
          const SizedBox(height: 14),
          TextField(controller: _telCtrl, decoration: _dec('Téléphone *'), keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], onChanged: (v) => widget.onUpdate(widget.model.copyWith(telephoneSalarie: v))),
          const SizedBox(height: 14),
          TextField(controller: _emailCtrl, decoration: _dec('E-mail'), keyboardType: TextInputType.emailAddress, onChanged: (v) => widget.onUpdate(widget.model.copyWith(emailSalarie: v))),
          const SizedBox(height: 14),
          TextField(controller: _secuCtrl, decoration: _dec('N° de Sécurité sociale'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)], onChanged: (v) => widget.onUpdate(widget.model.copyWith(numeroSecu: v))),

          _blockTitle('Agrément'),

          TextField(controller: _agremtRefCtrl, decoration: _dec('Référence de l\'agrément *'), onChanged: (v) => widget.onUpdate(widget.model.copyWith(referenceAgrement: v))),
          const SizedBox(height: 14),
          _dateField('Date de délivrance', widget.model.dateLivraisonAgrement, () {
            _pickDate(widget.model.dateLivraisonAgrement, (d) {
              setState(() {});
              widget.onUpdate(widget.model.copyWith(dateLivraisonAgrement: d));
            });
          }),
          const SizedBox(height: 8),
          const Text('ou date du dernier renouvellement :', style: TextStyle(fontSize: 12, color: Color(0xFF636E72))),
          const SizedBox(height: 8),
          _dateField('Date de renouvellement', widget.model.dateRenouvellementAgrement, () {
            _pickDate(widget.model.dateRenouvellementAgrement, (d) {
              setState(() {});
              widget.onUpdate(widget.model.copyWith(dateRenouvellementAgrement: d));
            });
          }),

          _blockTitle('Assurances'),

          const Text('Responsabilité Civile Professionnelle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
          const SizedBox(height: 10),
          TextField(controller: _rcProNomCtrl, decoration: _dec('Nom de la compagnie'), onChanged: (v) => widget.onUpdate(widget.model.copyWith(assuranceRCProNom: v))),
          const SizedBox(height: 10),
          TextField(controller: _rcProPoliceCtrl, decoration: _dec('N° de police'), onChanged: (v) => widget.onUpdate(widget.model.copyWith(assuranceRCProPolice: v))),
          const SizedBox(height: 18),
          const Text('Assurance automobile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
          const SizedBox(height: 10),
          TextField(controller: _autoNomCtrl, decoration: _dec('Nom de la compagnie'), onChanged: (v) => widget.onUpdate(widget.model.copyWith(assuranceAutoNom: v))),
          const SizedBox(height: 10),
          TextField(controller: _autoPoliceCtrl, decoration: _dec('N° de police'), onChanged: (v) => widget.onUpdate(widget.model.copyWith(assuranceAutoPolice: v))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
