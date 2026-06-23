import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/features/documents/models/contrat_cdi_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class CdiStep3EnfantLieu extends StatefulWidget {
  final ContratCdiModel model;
  final Function(ContratCdiModel) onUpdate;

  const CdiStep3EnfantLieu({super.key, required this.model, required this.onUpdate});

  @override
  CdiStep3EnfantLieuState createState() => CdiStep3EnfantLieuState();
}

class CdiStep3EnfantLieuState extends State<CdiStep3EnfantLieu> {
  late final TextEditingController _nomEnfantCtrl;
  late final TextEditingController _prenomEnfantCtrl;
  late final TextEditingController _lieuAdresseCtrl;
  late final TextEditingController _periodeEssaiCtrl;
  late final TextEditingController _nbJoursAdaptCtrl;
  late final TextEditingController _notesAdaptCtrl;

  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _nomEnfantCtrl = TextEditingController(text: widget.model.nomEnfant ?? '');
    _prenomEnfantCtrl = TextEditingController(text: widget.model.prenomEnfant ?? '');
    _lieuAdresseCtrl = TextEditingController(text: widget.model.lieuTravailAdresse ?? '');
    _periodeEssaiCtrl = TextEditingController(text: widget.model.dureePeriodeEssai ?? '');
    _nbJoursAdaptCtrl = TextEditingController(
        text: widget.model.dureePeriodeAdaptationJours != null ? '${widget.model.dureePeriodeAdaptationJours}' : '');
    _notesAdaptCtrl = TextEditingController(text: widget.model.notesAdaptation ?? '');
  }

  @override
  void dispose() {
    _nomEnfantCtrl.dispose();
    _prenomEnfantCtrl.dispose();
    _lieuAdresseCtrl.dispose();
    _periodeEssaiCtrl.dispose();
    _nbJoursAdaptCtrl.dispose();
    _notesAdaptCtrl.dispose();
    super.dispose();
  }

  bool validate() {
    if ((widget.model.nomEnfant ?? '').trim().isEmpty) {
      _showError('Le nom de l\'enfant est obligatoire');
      return false;
    }
    if ((widget.model.prenomEnfant ?? '').trim().isEmpty) {
      _showError('Le prénom de l\'enfant est obligatoire');
      return false;
    }
    if (widget.model.dateNaissanceEnfant == null) {
      _showError('La date de naissance de l\'enfant est obligatoire');
      return false;
    }
    if (widget.model.lieuTravailType == null) {
      _showError('Veuillez sélectionner le lieu de travail');
      return false;
    }
    if ((widget.model.lieuTravailAdresse ?? '').trim().isEmpty) {
      _showError('L\'adresse du lieu de travail est obligatoire');
      return false;
    }
    if (widget.model.dateEmbauche == null) {
      _showError('La date d\'embauche est obligatoire');
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
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryRed)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryRed, width: 2)),
      );

  Future<void> _pickDate(DateTime? current, void Function(DateTime) onPicked, {DateTime? firstDate, DateTime? lastDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2040),
      locale: const Locale('fr'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _primaryBlue, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Widget _dateField(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(text: date != null ? _dateFmt.format(date) : ''),
          decoration: _dec(label).copyWith(
            suffixIcon: const Icon(Icons.calendar_today_outlined, color: _primaryBlue, size: 20),
            hintText: 'JJ/MM/AAAA',
          ),
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
          const Text('Enfant, lieu & date d\'effet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
          const SizedBox(height: 4),
          const Text('Informations sur l\'enfant accueilli et les modalités du contrat', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
          const SizedBox(height: 20),

          // ── Enfant ────────────────────────────────────────────────────
          _blockTitle('Enfant accueilli'),

          Row(children: [
            Expanded(child: TextField(controller: _nomEnfantCtrl, decoration: _dec('Nom *'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(nomEnfant: v)))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _prenomEnfantCtrl, decoration: _dec('Prénom *'), textCapitalization: TextCapitalization.words, onChanged: (v) => widget.onUpdate(widget.model.copyWith(prenomEnfant: v)))),
          ]),
          const SizedBox(height: 14),

          _dateField('Date de naissance *', widget.model.dateNaissanceEnfant, () {
            _pickDate(widget.model.dateNaissanceEnfant, (d) {
              setState(() {});
              widget.onUpdate(widget.model.copyWith(dateNaissanceEnfant: d));
            }, firstDate: DateTime(2000), lastDate: DateTime.now());
          }),

          // ── Lieu de travail ───────────────────────────────────────────
          _blockTitle('2. Lieu de travail'),

          const Text('Le lieu de travail et d\'accueil de l\'enfant est exclusivement fixé :', style: TextStyle(fontSize: 13, color: Color(0xFF636E72))),
          const SizedBox(height: 12),

          _lieuChoice(LieuTravailType.domicileSalarie, 'Au domicile du salarié', Icons.home_outlined),
          const SizedBox(height: 8),
          _lieuChoice(LieuTravailType.maisonAma, 'Dans une Maison d\'Assistants Maternels (MAM)', Icons.apartment_outlined),
          const SizedBox(height: 14),

          TextField(
            controller: _lieuAdresseCtrl,
            decoration: _dec('Adresse du lieu de travail *'),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(lieuTravailAdresse: v)),
          ),

          // ── Date d'effet ──────────────────────────────────────────────
          _blockTitle('3. Date d\'effet du contrat'),

          _dateField('Date d\'embauche *', widget.model.dateEmbauche, () {
            _pickDate(widget.model.dateEmbauche, (d) {
              setState(() {});
              widget.onUpdate(widget.model.copyWith(dateEmbauche: d));
            });
          }),
          const SizedBox(height: 16),

          // Période d'essai
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _lightBlue.withAlpha(120), borderRadius: BorderRadius.circular(12), border: Border.all(color: _lightBlue)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Période d\'essai (facultative)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryBlue)),
                const SizedBox(height: 10),
                TextField(
                  controller: _periodeEssaiCtrl,
                  decoration: _dec('Durée de la période d\'essai', hint: 'ex : 1 mois'),
                  onChanged: (v) => widget.onUpdate(widget.model.copyWith(dureePeriodeEssai: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Période d'adaptation
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _lightBlue.withAlpha(120), borderRadius: BorderRadius.circular(12), border: Border.all(color: _lightBlue)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Période d\'adaptation (max 30 jours calendaires)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryBlue)),
                const SizedBox(height: 10),

                TextField(
                  controller: _nbJoursAdaptCtrl,
                  decoration: _dec('Durée (jours calendaires)', hint: 'ex : 15'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    widget.onUpdate(widget.model.copyWith(dureePeriodeAdaptationJours: n));
                  },
                ),
                const SizedBox(height: 12),

                _dateField('Du', widget.model.dateDebutAdaptation, () {
                  _pickDate(widget.model.dateDebutAdaptation, (d) {
                    setState(() {});
                    widget.onUpdate(widget.model.copyWith(dateDebutAdaptation: d));
                  });
                }),
                const SizedBox(height: 10),

                _dateField('Au', widget.model.dateFinAdaptation, () {
                  _pickDate(widget.model.dateFinAdaptation, (d) {
                    setState(() {});
                    widget.onUpdate(widget.model.copyWith(dateFinAdaptation: d));
                  });
                }),
                const SizedBox(height: 12),

                TextField(
                  controller: _notesAdaptCtrl,
                  decoration: _dec('Notes / informations complémentaires', hint: 'Précisions sur la période d\'adaptation…').copyWith(alignLabelWithHint: true),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => widget.onUpdate(widget.model.copyWith(notesAdaptation: v.trim().isEmpty ? null : v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _lieuChoice(LieuTravailType type, String label, IconData icon) {
    final sel = widget.model.lieuTravailType == type;
    return GestureDetector(
      onTap: () {
        setState(() {});
        widget.onUpdate(widget.model.copyWith(lieuTravailType: type));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? _primaryBlue.withAlpha(20) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? _primaryBlue : _lightBlue, width: sel ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: sel ? _primaryBlue : const Color(0xFF95A5A6), size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? _primaryBlue : const Color(0xFF2D3436)))),
            if (sel) const Icon(Icons.check_circle, color: _primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }
}
