import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/features/documents/models/avenant_model.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue   = Color(0xFFDFE9F2);

class AvenantStep3Modifications extends StatefulWidget {
  final AvenantModel model;
  final Function(AvenantModel) onUpdate;
  const AvenantStep3Modifications({super.key, required this.model, required this.onUpdate});

  @override
  State<AvenantStep3Modifications> createState() => _AvenantStep3State();
}

class _AvenantStep3State extends State<AvenantStep3Modifications> {
  late final TextEditingController _modifCtrl;
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _modifCtrl = TextEditingController(text: widget.model.modificationsTexte ?? '');
  }

  @override
  void dispose() { _modifCtrl.dispose(); super.dispose(); }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label, hintText: hint,
    filled: true, fillColor: Colors.white,
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryBlue, width: 2)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBlue)),
    alignLabelWithHint: true,
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.model.dateExecution ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2040),
      locale: const Locale('fr'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _primaryBlue, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) {
      widget.onUpdate(widget.model.copyWith(dateExecution: picked));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Modifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _primaryBlue)),
        const SizedBox(height: 4),
        const Text('Decrivez les clauses modifiees par cet avenant', style: TextStyle(fontSize: 14, color: Color(0xFF636E72))),
        const SizedBox(height: 24),

        // Conseil
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _lightBlue, borderRadius: BorderRadius.circular(12)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline, color: _primaryBlue, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Exemples : modification des horaires, du salaire, du lieu de travail, du nombre de semaines de garde...\n'
              'Precisez les nouvelles valeurs et les anciennes si necessaire.',
              style: TextStyle(fontSize: 12, color: _primaryBlue),
            )),
          ]),
        ),
        const SizedBox(height: 16),

        // Zone de texte
        TextField(
          controller: _modifCtrl,
          decoration: _dec(
            'Il est convenu de modifier les dispositions suivantes *',
            hint: 'Ex : A compter du [date], le salaire mensuel brut est porte de X a Y euros.\n'
                'Les horaires de travail sont modifies comme suit : ...',
          ),
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => widget.onUpdate(widget.model.copyWith(
              modificationsTexte: v.trim().isEmpty ? null : v)),
        ),
        const SizedBox(height: 20),

        // Date d'exécution
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: TextField(
              controller: TextEditingController(
                  text: widget.model.dateExecution != null
                      ? _dateFmt.format(widget.model.dateExecution!)
                      : ''),
              decoration: _dec('Date d\'execution de l\'avenant *').copyWith(
                hintText: 'JJ/MM/AAAA',
                suffixIcon: const Icon(Icons.calendar_today_outlined, color: _primaryBlue, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'La date d\'execution est la date a partir de laquelle les nouvelles dispositions s\'appliquent.',
          style: TextStyle(fontSize: 12, color: Color(0xFF636E72), fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
