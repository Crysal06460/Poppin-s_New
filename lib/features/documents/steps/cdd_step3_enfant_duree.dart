import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class CddStep3EnfantDuree extends StatefulWidget {
  final ContratCddModel model;
  final Function(ContratCddModel) onUpdate;

  const CddStep3EnfantDuree({super.key, required this.model, required this.onUpdate});

  @override
  CddStep3EnfantDureeState createState() => CddStep3EnfantDureeState();
}

class CddStep3EnfantDureeState extends State<CddStep3EnfantDuree> {
  late final TextEditingController _nomEnfantCtrl;
  late final TextEditingController _prenomEnfantCtrl;
  late final TextEditingController _lieuAdresseCtrl;
  late final TextEditingController _motifCtrl;
  late final TextEditingController _personneRemplaceeCtrl;
  late final TextEditingController _personneAbsenteCtrl;
  late final TextEditingController _dureeMiniCtrl;
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
    _motifCtrl = TextEditingController(text: widget.model.motifCdd ?? '');
    _personneRemplaceeCtrl = TextEditingController(text: widget.model.personneRemplaceeNom ?? '');
    _personneAbsenteCtrl = TextEditingController(text: widget.model.personneAbsenteNom ?? '');
    _dureeMiniCtrl = TextEditingController(text: widget.model.dureeMinimaale ?? '');
    _periodeEssaiCtrl = TextEditingController(text: widget.model.dureePeriodeEssai ?? '');
    _nbJoursAdaptCtrl = TextEditingController(text: widget.model.dureePeriodeAdaptationJours != null ? '${widget.model.dureePeriodeAdaptationJours}' : '');
    _notesAdaptCtrl = TextEditingController(text: widget.model.notesAdaptation ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nomEnfantCtrl, _prenomEnfantCtrl, _lieuAdresseCtrl, _motifCtrl, _personneRemplaceeCtrl, _personneAbsenteCtrl, _dureeMiniCtrl, _periodeEssaiCtrl, _nbJoursAdaptCtrl, _notesAdaptCtrl]) {
      c.dispose();
    }
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
    if ((widget.model.motifCdd ?? '').trim().isEmpty) {
      _showError('Le motif du CDD est obligatoire');
      return false;
    }
    if (widget.model.typeDureeCdd == null) {
      _showError('Veuillez sélectionner le type de durée du contrat');
      return false;
    }
    if (widget.model.typeDureeCdd == TypeDureeCdd.datesFixes) {
      if (widget.model.dateDebutContrat == null) {
        _showError('La date de début du contrat est obligatoire');
        return false;
      }
      if (widget.model.dateFinContrat == null) {
        _showError('La date de fin du contrat est obligatoire');
        return false;
      }
    } else {
      if ((widget.model.personneAbsenteNom ?? '').trim().isEmpty) {
        _showError('Le nom de la personne absente est obligatoire');
        return false;
      }
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

  Future<void> _pickDate(DateTime? current, void Function(DateTime) onPicked, {DateTime? firstDate, DateTime? lastDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2040),
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

  Widget _lieuChoice(LieuTravailTypeCdd type, String label, IconData icon) {
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
        child: Row(children: [
          Icon(icon, color: sel ? _primaryBlue : const Color(0xFF95A5A6), size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? _primaryBlue : const Color(0xFF2D3436)))),
          if (sel) const Icon(Icons.check_circle, color: _primaryBlue, size: 20),
        ]),
      ),
    );
  }

  Widget _dureeChoice(TypeDureeCdd type, String titre, String sousTitre, IconData icon) {
    final sel = widget.model.typeDureeCdd == type;
    return GestureDetector(
      onTap: () {
        setState(() {});
        widget.onUpdate(widget.model.copyWith(typeDureeCdd: type));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? _primaryBlue.withAlpha(20) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? _primaryBlue : _lightBlue, width: sel ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: sel ? _primaryBlue : const Color(0xFF95A5A6), size: 26),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sel ? _primaryBlue : const Color(0xFF2D3436))),
            Text(sousTitre, style: const TextStyle(fontSize: 12, color: Color(0xFF636E72))),
          ])),
          if (sel) const Icon(Icons.check_circle, color: _primaryBlue, size: 22),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDatesFixes = widget.model.typeDureeCdd == TypeDureeCdd.datesFixes;
    final isDureeAbsence = widget.model.typeDureeCdd == TypeDureeCdd.dureeAbsence;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enfant, lieu & durée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
          const SizedBox(height: 4),
          const Text('Enfant accueilli, lieu de travail, motif et durée du CDD', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
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
          _lieuChoice(LieuTravailTypeCdd.domicileSalarie, 'Au domicile du salarié', Icons.home_outlined),
          const SizedBox(height: 8),
          _lieuChoice(LieuTravailTypeCdd.maisonAma, 'Dans une Maison d\'Assistants Maternels (MAM)', Icons.apartment_outlined),
          const SizedBox(height: 14),
          TextField(controller: _lieuAdresseCtrl, decoration: _dec('Adresse du lieu de travail *'), textCapitalization: TextCapitalization.sentences, onChanged: (v) => widget.onUpdate(widget.model.copyWith(lieuTravailAdresse: v))),

          // ── Motif CDD ─────────────────────────────────────────────────
          _blockTitle('1. Motif du recours au CDD'),

          TextField(
            controller: _motifCtrl,
            decoration: _dec('Le CDD est conclu en raison de *', hint: 'ex : remplacement d\'un salarié absent, accroissement d\'activité…'),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(motifCdd: v)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _personneRemplaceeCtrl,
            decoration: _dec('Identité de la personne remplacée', hint: 'Si remplacement : M./Mme …'),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(personneRemplaceeNom: v.trim().isEmpty ? null : v)),
          ),

          // ── Durée du contrat ──────────────────────────────────────────
          _blockTitle('3. Durée du contrat'),

          _dureeChoice(TypeDureeCdd.datesFixes, 'Dates fixes', 'Du [date] au [date]', Icons.date_range_outlined),
          const SizedBox(height: 10),
          _dureeChoice(TypeDureeCdd.dureeAbsence, 'Durée d\'absence', 'Fin au retour de la personne remplacée', Icons.person_off_outlined),
          const SizedBox(height: 16),

          if (isDatesFixes) ...[
            _dateField('Date de début *', widget.model.dateDebutContrat, () {
              _pickDate(widget.model.dateDebutContrat, (d) {
                setState(() {});
                widget.onUpdate(widget.model.copyWith(dateDebutContrat: d));
              });
            }),
            const SizedBox(height: 12),
            _dateField('Date de fin *', widget.model.dateFinContrat, () {
              _pickDate(widget.model.dateFinContrat, (d) {
                setState(() {});
                widget.onUpdate(widget.model.copyWith(dateFinContrat: d));
              });
            }),
          ],

          if (isDureeAbsence) ...[
            TextField(
              controller: _personneAbsenteCtrl,
              decoration: _dec('Nom de la personne absente (M./Mme …) *'),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => widget.onUpdate(widget.model.copyWith(personneAbsenteNom: v)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dureeMiniCtrl,
              decoration: _dec('Durée minimale du contrat', hint: 'ex : 1 mois'),
              onChanged: (v) => widget.onUpdate(widget.model.copyWith(dureeMinimaale: v.trim().isEmpty ? null : v)),
            ),
          ],

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
                TextField(controller: _periodeEssaiCtrl, decoration: _dec('Durée de la période d\'essai', hint: 'ex : 1 mois'), onChanged: (v) => widget.onUpdate(widget.model.copyWith(dureePeriodeEssai: v.trim().isEmpty ? null : v))),
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
                  onChanged: (v) => widget.onUpdate(widget.model.copyWith(dureePeriodeAdaptationJours: int.tryParse(v))),
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
                TextFormField(
                  controller: _notesAdaptCtrl,
                  decoration: _dec('Notes / informations complémentaires', hint: 'Modalités particulières de la période d\'adaptation…'),
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
}
