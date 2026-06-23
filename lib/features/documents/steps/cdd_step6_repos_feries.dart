import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);
const Color _lightBlue = Color(0xFFDFE9F2);

class CddStep6ReposFeries extends StatefulWidget {
  final ContratCddModel model;
  final Function(ContratCddModel) onUpdate;

  const CddStep6ReposFeries({super.key, required this.model, required this.onUpdate});

  @override
  CddStep6ReposFeriesState createState() => CddStep6ReposFeriesState();
}

class CddStep6ReposFeriesState extends State<CddStep6ReposFeries> {
  late final TextEditingController _tauxFeriesCtrl;
  late final TextEditingController _conditionsCtrl;

  static const List<String> _tousJoursFeries = [
    '1er janvier',
    'Vendredi Saint (Alsace-Moselle)',
    'Lundi de Pâques',
    '8 mai',
    'Jeudi de l\'Ascension',
    'Lundi de Pentecôte',
    'Abolition de l\'esclavage (DROM)',
    '14 juillet',
    '15 août',
    '1er novembre',
    '11 novembre',
    '25 décembre',
    '26 décembre (Alsace-Moselle)',
  ];

  static const List<String> _joursOptions = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];

  @override
  void initState() {
    super.initState();
    _tauxFeriesCtrl = TextEditingController(text: widget.model.tauxMajorationJoursFeries != null ? '${widget.model.tauxMajorationJoursFeries}' : '');
    _conditionsCtrl = TextEditingController(text: widget.model.conditionsParticulieres ?? '');
  }

  @override
  void dispose() {
    _tauxFeriesCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
  }

  bool validate() {
    if ((widget.model.jourReposHebdomadaire ?? '').trim().isEmpty) {
      _showError('Le jour de repos hebdomadaire est obligatoire');
      return false;
    }
    if (!widget.model.travailReposMajore && !widget.model.travailReposRecupere) {
      _showError('Veuillez indiquer le mode de compensation en cas de travail pendant le repos');
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

  Widget _radioRow(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? _primaryBlue : const Color(0xFF95A5A6), size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: selected ? _primaryBlue : const Color(0xFF2D3436), fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
      ]),
    );
  }

  Widget _checkFerie(String label) {
    final checked = widget.model.joursFeriesOrdTravailles.contains(label);
    return GestureDetector(
      onTap: () {
        final liste = List<String>.from(widget.model.joursFeriesOrdTravailles);
        if (checked) {
          liste.remove(label);
        } else {
          liste.add(label);
        }
        widget.onUpdate(widget.model.copyWith(joursFeriesOrdTravailles: liste));
        setState(() {});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, color: checked ? _primaryBlue : const Color(0xFF95A5A6), size: 20),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: checked ? _primaryBlue : const Color(0xFF2D3436), fontWeight: checked ? FontWeight.w600 : FontWeight.w400)),
        ]),
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
          const Text('Repos, jours fériés & conditions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
          const SizedBox(height: 4),
          const Text('Articles 6, 7, 8 & 10 du contrat CDD', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),

          // ── Article 6 : Repos hebdomadaire ─────────────────────────────
          _sectionTitle('6. Repos hebdomadaire'),

          DropdownButtonFormField<String>(
            key: ValueKey(widget.model.jourReposHebdomadaire),
            initialValue: widget.model.jourReposHebdomadaire,
            decoration: _dec('Jour de repos hebdomadaire *'),
            items: _joursOptions.map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
            onChanged: (v) {
              widget.onUpdate(widget.model.copyWith(jourReposHebdomadaire: v));
              setState(() {});
            },
          ),
          const SizedBox(height: 16),

          const Text('En cas de travail pendant le repos (avec accord écrit) :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
          const SizedBox(height: 10),

          _radioRow('Rémunéré au taux horaire dû, majoré de 25%', widget.model.travailReposMajore, () {
            widget.onUpdate(widget.model.copyWith(travailReposMajore: true, travailReposRecupere: false));
            setState(() {});
          }),
          const SizedBox(height: 8),
          _radioRow('Récupéré par un repos équivalent, majoré de 25%', widget.model.travailReposRecupere, () {
            widget.onUpdate(widget.model.copyWith(travailReposRecupere: true, travailReposMajore: false));
            setState(() {});
          }),

          // ── Article 7 : Jours fériés ───────────────────────────────────
          _sectionTitle('7. Jours fériés'),

          const Text('1er mai :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
          const SizedBox(height: 8),
          _radioRow('Chômé (inclus dans la mensualisation)', widget.model.premierMaiChome, () {
            widget.onUpdate(widget.model.copyWith(premierMaiChome: true));
            setState(() {});
          }),
          const SizedBox(height: 8),
          _radioRow('Travaillé (rémunération doublée +100%)', !widget.model.premierMaiChome, () {
            widget.onUpdate(widget.model.copyWith(premierMaiChome: false));
            setState(() {});
          }),

          const SizedBox(height: 16),
          const Text('Jours fériés ordinaires travaillés :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _lightBlue)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _tousJoursFeries.map((j) => _checkFerie(j)).toList(),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _tauxFeriesCtrl,
            decoration: _dec('Taux de majoration jours fériés', suffix: '%', hint: 'min. 10%'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(tauxMajorationJoursFeries: double.tryParse(v.replaceAll(',', '.')))),
          ),

          // ── Article 8 : Congés payés ───────────────────────────────────
          _sectionTitle('8. Congés annuels'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(12)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: _primaryBlue, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Pour un CDD, l\'indemnité de congés payés est égale à 1/10e de la rémunération totale brute perçue pendant le contrat. Elle est versée à la fin du contrat.',
                style: TextStyle(fontSize: 12, color: _primaryBlue),
              )),
            ]),
          ),

          // ── Article 10 : Conditions particulières ──────────────────────
          _sectionTitle('10. Conditions particulières'),
          const Text('Optionnel — Règles spécifiques pour l\'accueil de l\'enfant (activités conseillées ou à proscrire, cahier de liaison, présence d\'animaux…)', style: TextStyle(fontSize: 12, color: Color(0xFF636E72))),
          const SizedBox(height: 10),

          TextField(
            controller: _conditionsCtrl,
            decoration: _dec('Conditions particulières', hint: 'Laisser vide si aucune condition particulière').copyWith(
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => widget.onUpdate(widget.model.copyWith(conditionsParticulieres: v.trim().isEmpty ? null : v)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
