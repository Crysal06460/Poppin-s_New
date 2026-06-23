import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class CddStep5Remuneration extends StatefulWidget {
  final ContratCddModel model;
  final Function(ContratCddModel) onUpdate;

  const CddStep5Remuneration({super.key, required this.model, required this.onUpdate});

  @override
  CddStep5RemunerationState createState() => CddStep5RemunerationState();
}

class CddStep5RemunerationState extends State<CddStep5Remuneration> {
  late final TextEditingController _brutCtrl;
  late final TextEditingController _netCtrl;
  late final TextEditingController _majBrutCtrl;
  late final TextEditingController _majNetCtrl;
  late final TextEditingController _tauxMajCtrl;
  late final TextEditingController _majH45BrutCtrl;
  late final TextEditingController _majH45NetCtrl;
  late final TextEditingController _mensuelBrutCtrl;
  late final TextEditingController _mensuelNetCtrl;
  late final TextEditingController _indNbHeuresCtrl;
  late final TextEditingController _indMontantCtrl;
  late final TextEditingController _repasEmpCtrl;
  late final TextEditingController _repasSalCtrl;
  late final TextEditingController _kmCtrl;
  late final TextEditingController _jourPaiCtrl;

  @override
  void initState() {
    super.initState();
    _brutCtrl = TextEditingController(text: _fmt(widget.model.salaireHoraireBrut));
    _netCtrl = TextEditingController(text: _fmt(widget.model.salaireHoraireNet));
    _majBrutCtrl = TextEditingController(text: _fmt(widget.model.salaireHoraireMajoreBrut));
    _majNetCtrl = TextEditingController(text: _fmt(widget.model.salaireHoraireMajoreNet));
    _tauxMajCtrl = TextEditingController(text: _fmt(widget.model.tauxMajorationHeuresMajorees));
    _majH45BrutCtrl = TextEditingController(text: _fmt(widget.model.salaireHoraireMajoreesBrut));
    _majH45NetCtrl = TextEditingController(text: _fmt(widget.model.salaireHorairesMajoreesNet));
    _mensuelBrutCtrl = TextEditingController(text: _fmt(widget.model.salaireMensuelBrut));
    _mensuelNetCtrl = TextEditingController(text: _fmt(widget.model.salaireMensuelNet));
    _indNbHeuresCtrl = TextEditingController(text: _fmt(widget.model.nbHeuresJourneeIndemniteEntretien));
    _indMontantCtrl = TextEditingController(text: _fmt(widget.model.montantHoraireIndemniteEntretien));
    _repasEmpCtrl = TextEditingController(text: _fmt(widget.model.montantRepasEmployeur));
    _repasSalCtrl = TextEditingController(text: _fmt(widget.model.montantRepasSalarie));
    _kmCtrl = TextEditingController(text: _fmt(widget.model.indemnitesKmParKm));
    _jourPaiCtrl = TextEditingController(text: widget.model.jourPaiementSalaire != null ? '${widget.model.jourPaiementSalaire}' : '');
  }

  String _fmt(double? v) => v != null ? v.toStringAsFixed(2).replaceAll('.', ',') : '';
  double? _parse(String v) => double.tryParse(v.replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [
      _brutCtrl, _netCtrl, _majBrutCtrl, _majNetCtrl, _tauxMajCtrl,
      _majH45BrutCtrl, _majH45NetCtrl, _mensuelBrutCtrl, _mensuelNetCtrl,
      _indNbHeuresCtrl, _indMontantCtrl, _repasEmpCtrl, _repasSalCtrl,
      _kmCtrl, _jourPaiCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool validate() {
    if (widget.model.salaireHoraireBrut == null) {
      _showError('Le salaire horaire brut de base est obligatoire');
      return false;
    }
    if (widget.model.salaireHoraireNet == null) {
      _showError('Le salaire horaire net de base est obligatoire');
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

  void _recalcMensuel() => _recalcFromModel(widget.model);

  void _recalcFromModel(ContratCddModel m) {
    final brut = m.salaireHoraireBrut;
    final net = m.salaireHoraireNet;
    final heures = m.heuresParSemaine;
    final semaines = m.nombreSemaines;

    if (brut != null && heures != null && semaines != null) {
      final mb = double.parse((brut * heures * semaines / 12).toStringAsFixed(2));
      final mn = net != null ? double.parse((net * heures * semaines / 12).toStringAsFixed(2)) : null;
      setState(() {
        _mensuelBrutCtrl.text = mb.toStringAsFixed(2).replaceAll('.', ',');
        if (mn != null) _mensuelNetCtrl.text = mn.toStringAsFixed(2).replaceAll('.', ',');
      });
      widget.onUpdate(m.copyWith(salaireMensuelBrut: mb, salaireMensuelNet: mn));
      return;
    }
    widget.onUpdate(m);
  }

  InputDecoration _dec(String label, {String? suffix, String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryBlue, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _primaryBlue)),
      );

  Widget _checkRow(String label, bool val, void Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!val),
      child: Row(children: [
        Icon(val ? Icons.check_box : Icons.check_box_outline_blank, color: val ? _primaryBlue : const Color(0xFF95A5A6), size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF2D3436)))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rémunération', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
          const SizedBox(height: 4),
          const Text('Article 5 — Salaire, indemnités et frais', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),

          // Indemnité de fin de contrat
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD700).withAlpha(120))),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF856404)),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Indemnité de fin de contrat (précarité) : 10 % de la rémunération totale brute perçue pendant le contrat, versée à la fin du CDD.',
                style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
              )),
            ]),
          ),

          // ── Salaire horaire de base ────────────────────────────────────
          _sectionTitle('Salaire horaire de base'),

          Row(children: [
            Expanded(child: TextField(
              controller: _brutCtrl,
              decoration: _dec('Brut *', suffix: '€'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                _recalcFromModel(widget.model.copyWith(salaireHoraireBrut: _parse(v)));
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _netCtrl,
              decoration: _dec('Net *', suffix: '€'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                _recalcFromModel(widget.model.copyWith(salaireHoraireNet: _parse(v)));
              },
            )),
          ]),

          // ── Heures complémentaires ─────────────────────────────────────
          _sectionTitle('Heures complémentaires (< 45h/semaine)'),
          const Text('Optionnel — si les parties prévoient une majoration pour les heures complémentaires', style: TextStyle(fontSize: 12, color: Color(0xFF636E72))),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(child: TextField(controller: _majBrutCtrl, decoration: _dec('Brut majoré', suffix: '€'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(salaireHoraireMajoreBrut: _parse(v))))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _majNetCtrl, decoration: _dec('Net majoré', suffix: '€'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(salaireHoraireMajoreNet: _parse(v))))),
          ]),

          // ── Heures majorées > 45h ──────────────────────────────────────
          _sectionTitle('Heures majorées (> 45h/semaine)'),
          const Text('Majoration minimum 10% selon la convention collective', style: TextStyle(fontSize: 12, color: Color(0xFF636E72))),
          const SizedBox(height: 10),

          TextField(controller: _tauxMajCtrl, decoration: _dec('Taux de majoration', suffix: '%', hint: 'min. 10'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(tauxMajorationHeuresMajorees: _parse(v)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _majH45BrutCtrl, decoration: _dec('Brut majoré', suffix: '€'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(salaireHoraireMajoreesBrut: _parse(v))))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _majH45NetCtrl, decoration: _dec('Net majoré', suffix: '€'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(salaireHorairesMajoreesNet: _parse(v))))),
          ]),

          // ── Salaire mensuel de base ────────────────────────────────────
          _sectionTitle('Salaire mensuel de base'),

          if (widget.model.heuresParSemaine != null && widget.model.nombreSemaines != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.calculate_outlined, size: 16, color: _primaryBlue),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Formule : brut horaire × ${widget.model.heuresParSemaine}h × ${widget.model.nombreSemaines} sem. ÷ 12',
                  style: const TextStyle(fontSize: 12, color: _primaryBlue),
                )),
                TextButton(
                  onPressed: _recalcMensuel,
                  child: const Text('Calculer', style: TextStyle(fontSize: 12, color: _primaryBlue)),
                ),
              ]),
            ),

          Row(children: [
            Expanded(child: TextField(controller: _mensuelBrutCtrl, decoration: _dec('Brut mensuel', suffix: '€'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(salaireMensuelBrut: _parse(v))))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _mensuelNetCtrl, decoration: _dec('Net mensuel', suffix: '€'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(salaireMensuelNet: _parse(v))))),
          ]),

          // ── Indemnité d'entretien ──────────────────────────────────────
          _sectionTitle('Indemnité d\'entretien'),
          const Text('Minimum 2,65 €/jour. Renseignez pour une journée type.', style: TextStyle(fontSize: 12, color: Color(0xFF636E72))),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(child: TextField(controller: _indNbHeuresCtrl, decoration: _dec('Durée journée', suffix: 'h', hint: 'ex : 9'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(nbHeuresJourneeIndemniteEntretien: _parse(v))))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _indMontantCtrl, decoration: _dec('Montant horaire', suffix: '€'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(montantHoraireIndemniteEntretien: _parse(v))))),
          ]),

          // ── Frais de repas ─────────────────────────────────────────────
          _sectionTitle('Frais de repas'),

          _checkRow('Repas fournis par l\'employeur', widget.model.repasParEmployeur, (v) {
            widget.onUpdate(widget.model.copyWith(repasParEmployeur: v, repasParSalarie: v ? false : widget.model.repasParSalarie));
            setState(() {});
          }),

          if (widget.model.repasParEmployeur)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 4),
              child: TextField(controller: _repasEmpCtrl, decoration: _dec('Montant par repas', suffix: '€/repas'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(montantRepasEmployeur: _parse(v)))),
            ),

          const SizedBox(height: 10),
          _checkRow('Repas fournis par l\'assistante maternelle', widget.model.repasParSalarie, (v) {
            widget.onUpdate(widget.model.copyWith(repasParSalarie: v, repasParEmployeur: v ? false : widget.model.repasParEmployeur));
            setState(() {});
          }),

          if (widget.model.repasParSalarie)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 4),
              child: TextField(controller: _repasSalCtrl, decoration: _dec('Montant par repas', suffix: '€/repas'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => widget.onUpdate(widget.model.copyWith(montantRepasSalarie: _parse(v)))),
            ),

          // ── Frais de déplacement ───────────────────────────────────────
          _sectionTitle('Frais de déplacement'),

          TextField(
            controller: _kmCtrl,
            decoration: _dec('Indemnité kilométrique', suffix: '€/km', hint: 'Conforme au barème fiscal'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(indemnitesKmParKm: _parse(v))),
          ),

          // ── Date de paiement ───────────────────────────────────────────
          _sectionTitle('Date de paiement du salaire'),

          TextField(
            controller: _jourPaiCtrl,
            decoration: _dec('Jour du mois (1 à 28)', hint: 'ex : 5 ou 28'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(jourPaiementSalaire: int.tryParse(v))),
          ),
          const SizedBox(height: 14),

          _checkRow('Accord Pajemploi+ (versement via Urssaf)', widget.model.accordPajemploiPlus, (v) {
            widget.onUpdate(widget.model.copyWith(accordPajemploiPlus: v));
            setState(() {});
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
