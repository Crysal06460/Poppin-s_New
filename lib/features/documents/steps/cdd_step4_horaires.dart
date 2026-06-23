import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class CddStep4Horaires extends StatefulWidget {
  final ContratCddModel model;
  final Function(ContratCddModel) onUpdate;

  const CddStep4Horaires({super.key, required this.model, required this.onUpdate});

  @override
  CddStep4HorairesState createState() => CddStep4HorairesState();
}

class CddStep4HorairesState extends State<CddStep4Horaires> {
  late TextEditingController _nbSemainesCtrl;
  late TextEditingController _heuresCtrl;
  late TextEditingController _delaiCtrl;
  late TextEditingController _delaiEcritCtrl;
  late List<TextEditingController> _jourCtrls;
  late List<TextEditingController> _horaireCtrls;
  late List<TextEditingController> _nbHeureCtrls;

  @override
  void initState() {
    super.initState();
    _nbSemainesCtrl = TextEditingController(text: widget.model.nombreSemaines != null ? '${widget.model.nombreSemaines}' : '');
    _heuresCtrl = TextEditingController(text: widget.model.heuresParSemaine != null ? '${widget.model.heuresParSemaine}' : '');
    _delaiCtrl = TextEditingController(text: widget.model.delaiPrevenanceSemaines != null ? '${widget.model.delaiPrevenanceSemaines}' : '');
    _delaiEcritCtrl = TextEditingController(text: widget.model.delaiPrevenancePlanningEcrit != null ? '${widget.model.delaiPrevenancePlanningEcrit}' : '');
    _initLigneControllers();
  }

  void _initLigneControllers() {
    _jourCtrls = widget.model.lignesPlanning.map((l) => TextEditingController(text: l.jourTravail)).toList();
    _horaireCtrls = widget.model.lignesPlanning.map((l) => TextEditingController(text: l.horairesTravail)).toList();
    _nbHeureCtrls = widget.model.lignesPlanning.map((l) => TextEditingController(text: l.nbHeuresTravail)).toList();
  }

  void _disposeLigneControllers() {
    for (final c in [..._jourCtrls, ..._horaireCtrls, ..._nbHeureCtrls]) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _nbSemainesCtrl.dispose();
    _heuresCtrl.dispose();
    _delaiCtrl.dispose();
    _delaiEcritCtrl.dispose();
    _disposeLigneControllers();
    super.dispose();
  }

  bool validate() {
    if (widget.model.nombreSemaines == null) {
      _showError('Veuillez indiquer le nombre de semaines de garde');
      return false;
    }
    final lignesRemplies = widget.model.lignesPlanning.where((l) => l.jourTravail.trim().isNotEmpty).toList();
    if (!widget.model.planningParEcrit && lignesRemplies.isEmpty) {
      _showError('Veuillez renseigner au moins un jour de travail dans le planning');
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _lightBlue)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryBlue, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _lightBlue)),
      );

  void _ajouterLigne() {
    final nouvelles = List<LignePlanningCdd>.from(widget.model.lignesPlanning)..add(LignePlanningCdd());
    widget.onUpdate(widget.model.copyWith(lignesPlanning: nouvelles));
    setState(() {
      _disposeLigneControllers();
      _jourCtrls = nouvelles.map((l) => TextEditingController(text: l.jourTravail)).toList();
      _horaireCtrls = nouvelles.map((l) => TextEditingController(text: l.horairesTravail)).toList();
      _nbHeureCtrls = nouvelles.map((l) => TextEditingController(text: l.nbHeuresTravail)).toList();
    });
  }

  void _supprimerLigne(int index) {
    if (widget.model.lignesPlanning.length <= 1) return;
    final nouvelles = List<LignePlanningCdd>.from(widget.model.lignesPlanning)..removeAt(index);
    widget.onUpdate(widget.model.copyWith(lignesPlanning: nouvelles));
    setState(() {
      _disposeLigneControllers();
      _jourCtrls = nouvelles.map((l) => TextEditingController(text: l.jourTravail)).toList();
      _horaireCtrls = nouvelles.map((l) => TextEditingController(text: l.horairesTravail)).toList();
      _nbHeureCtrls = nouvelles.map((l) => TextEditingController(text: l.nbHeuresTravail)).toList();
    });
  }

  void _updateLigne(int index, {String? jour, String? horaires, String? nbHeures}) {
    final lignes = List<LignePlanningCdd>.from(widget.model.lignesPlanning);
    lignes[index] = lignes[index].copyWith(jourTravail: jour, horairesTravail: horaires, nbHeuresTravail: nbHeures);
    widget.onUpdate(widget.model.copyWith(lignesPlanning: lignes));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Durée et horaires d\'accueil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
          const SizedBox(height: 4),
          const Text('Article 4 — Définissez les horaires de garde', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
          const SizedBox(height: 24),

          // Nombre de semaines
          TextField(
            controller: _nbSemainesCtrl,
            decoration: _dec('Nombre de semaines de garde *', hint: 'ex : 24'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(nombreSemaines: int.tryParse(v))),
          ),
          const SizedBox(height: 14),

          // Heures par semaine
          TextField(
            controller: _heuresCtrl,
            decoration: _dec('Nombre d\'heures / semaine', hint: 'ex : 40'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(heuresParSemaine: double.tryParse(v.replaceAll(',', '.')))),
          ),
          const SizedBox(height: 20),

          // Option planning par écrit
          GestureDetector(
            onTap: () {
              setState(() {});
              widget.onUpdate(widget.model.copyWith(planningParEcrit: !widget.model.planningParEcrit));
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.model.planningParEcrit ? _primaryBlue.withAlpha(20) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.model.planningParEcrit ? _primaryBlue : _lightBlue, width: widget.model.planningParEcrit ? 2 : 1),
              ),
              child: Row(children: [
                Icon(widget.model.planningParEcrit ? Icons.check_box : Icons.check_box_outline_blank, color: widget.model.planningParEcrit ? _primaryBlue : const Color(0xFF95A5A6)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Planning remis par écrit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Les jours et horaires seront définis dans un planning séparé', style: TextStyle(fontSize: 12, color: Color(0xFF636E72))),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Tableau planning
          if (!widget.model.planningParEcrit) ...[
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _lightBlue)),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(color: _primaryBlue, borderRadius: BorderRadius.only(topLeft: Radius.circular(11), topRight: Radius.circular(11))),
                  child: const Row(children: [
                    Expanded(flex: 3, child: Text('Jours de travail', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                    SizedBox(width: 8),
                    Expanded(flex: 4, child: Text('Horaires de travail', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                    SizedBox(width: 8),
                    Expanded(flex: 2, child: Text('Nb heures', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                    SizedBox(width: 32),
                  ]),
                ),
                ...List.generate(widget.model.lignesPlanning.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(children: [
                      Expanded(flex: 3, child: TextField(controller: _jourCtrls[i], decoration: _dec('', hint: 'Lundi'), style: const TextStyle(fontSize: 13), onChanged: (v) => _updateLigne(i, jour: v))),
                      const SizedBox(width: 8),
                      Expanded(flex: 4, child: TextField(controller: _horaireCtrls[i], decoration: _dec('', hint: '08h–17h30'), style: const TextStyle(fontSize: 13), onChanged: (v) => _updateLigne(i, horaires: v))),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: TextField(controller: _nbHeureCtrls[i], decoration: _dec('', hint: '9h'), style: const TextStyle(fontSize: 13), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => _updateLigne(i, nbHeures: v))),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        color: widget.model.lignesPlanning.length > 1 ? _primaryRed : const Color(0xFFBDC3C7),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _supprimerLigne(i),
                      ),
                    ]),
                  );
                }),
                if (widget.model.lignesPlanning.length < 7)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: TextButton.icon(
                      onPressed: _ajouterLigne,
                      icon: const Icon(Icons.add, size: 18, color: _primaryBlue),
                      label: const Text('Ajouter un jour', style: TextStyle(color: _primaryBlue, fontSize: 13)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // Délai de prévenance
          TextField(
            controller: _delaiCtrl,
            decoration: _dec('Délai de prévenance (semaines calendaires, min. 2)', hint: 'ex : 8'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(delaiPrevenanceSemaines: int.tryParse(v))),
          ),

          if (widget.model.planningParEcrit) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _delaiEcritCtrl,
              decoration: _dec('Délai prévenance planning écrit (semaines, min. 2)', hint: 'ex : 8'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
              onChanged: (v) => widget.onUpdate(widget.model.copyWith(delaiPrevenancePlanningEcrit: int.tryParse(v))),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 16, color: _primaryBlue),
              SizedBox(width: 8),
              Expanded(child: Text('Durée maximale : 48 h/semaine, calculée sur une moyenne de 4 mois.', style: TextStyle(fontSize: 12, color: _primaryBlue))),
            ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
