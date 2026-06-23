import 'package:flutter/material.dart';
import 'package:poppins_app/features/calculs/models/mensualisation_params.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue = Color(0xFFDFE9F2);

/// Formulaire de calcul de mensualisation + affichage du résultat.
/// Calcul 100% local, aucun appel réseau, aucune persistance.
class MensualisationFormScreen extends StatefulWidget {
  const MensualisationFormScreen({super.key});

  @override
  State<MensualisationFormScreen> createState() =>
      _MensualisationFormScreenState();
}

class _MensualisationFormScreenState extends State<MensualisationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _joursController = TextEditingController();
  final TextEditingController _heuresJourController = TextEditingController();
  final TextEditingController _semainesController = TextEditingController();
  final TextEditingController _tarifController = TextEditingController();

  bool _anneeComplete = true;
  TypeRemuneration _typeRemuneration = TypeRemuneration.net;

  MensualisationResult? _resultat;

  @override
  void dispose() {
    _joursController.dispose();
    _heuresJourController.dispose();
    _semainesController.dispose();
    _tarifController.dispose();
    super.dispose();
  }

  void _calculer() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _resultat = null);
      return;
    }

    final int jours = int.parse(_joursController.text.replaceAll(',', '.'));
    final double heuresJour =
        double.parse(_heuresJourController.text.replaceAll(',', '.'));
    final double tarif =
        double.parse(_tarifController.text.replaceAll(',', '.'));
    final int? semaines = _anneeComplete
        ? null
        : int.parse(_semainesController.text.replaceAll(',', '.'));

    final params = MensualisationParams(
      joursParSemaine: jours,
      heuresParJour: heuresJour,
      anneeComplete: _anneeComplete,
      semainesAccueil: semaines,
      tarifHoraire: tarif,
      typeRemuneration: _typeRemuneration,
    );

    setState(() => _resultat = params.calculer());
  }

  String _formatMontant(double value) {
    final String fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    return '${parts[0]},${parts[1]} €';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Calculer une mensualisation',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Conditions d'accueil",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _joursController,
                        label: "Nombre de jours d'accueil par semaine",
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0 || n > 7) {
                            return 'Entrez un nombre de jours valide (1 à 7)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _heuresJourController,
                        label: "Nombre d'heures d'accueil par jour",
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          final n = double.tryParse(
                              (v ?? '').trim().replaceAll(',', '.'));
                          if (n == null || n <= 0 || n > 24) {
                            return 'Entrez un nombre d\'heures valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Type d'année",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildChoiceChip(
                              label: 'Année complète',
                              selected: _anneeComplete,
                              onTap: () =>
                                  setState(() => _anneeComplete = true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildChoiceChip(
                              label: 'Année incomplète',
                              selected: !_anneeComplete,
                              onTap: () =>
                                  setState(() => _anneeComplete = false),
                            ),
                          ),
                        ],
                      ),
                      if (!_anneeComplete) ...[
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _semainesController,
                          label: "Nombre de semaines d'accueil programmées",
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (_anneeComplete) return null;
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null || n <= 0 || n > 52) {
                              return 'Entrez un nombre de semaines valide (1 à 52)';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rémunération',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _tarifController,
                        label: 'Tarif horaire (€)',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          final n = double.tryParse(
                              (v ?? '').trim().replaceAll(',', '.'));
                          if (n == null || n <= 0) {
                            return 'Entrez un tarif horaire valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Net ou Brut',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildChoiceChip(
                              label: 'Net',
                              selected:
                                  _typeRemuneration == TypeRemuneration.net,
                              onTap: () => setState(() =>
                                  _typeRemuneration = TypeRemuneration.net),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildChoiceChip(
                              label: 'Brut',
                              selected:
                                  _typeRemuneration == TypeRemuneration.brut,
                              onTap: () => setState(() =>
                                  _typeRemuneration = TypeRemuneration.brut),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _calculer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Calculer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (_resultat != null) ...[
                  const SizedBox(height: 24),
                  _buildResultCard(_resultat!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(MensualisationResult resultat) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _lightBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle, color: _primaryBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'Résultat',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _resultRow(
            'Heures hebdomadaires',
            '${resultat.heuresHebdo.toStringAsFixed(2)} h',
          ),
          const SizedBox(height: 8),
          _resultRow(
            'Heures mensualisées',
            '${resultat.heuresMensualisees.toStringAsFixed(2)} h',
          ),
          const SizedBox(height: 8),
          _resultRow(
            'Salaire mensualisé (${_typeRemuneration.label})',
            _formatMontant(resultat.salaireMensuel),
            highlight: true,
          ),
          const SizedBox(height: 16),
          Text(
            "Calcul indicatif à vérifier selon le contrat, la convention "
            "collective et les règles Pajemploi en vigueur. Hors indemnités "
            "d'entretien, repas, kilomètres éventuels.",
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: highlight ? 14 : 13,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 17 : 14,
            fontWeight: FontWeight.w700,
            color: highlight ? _primaryBlue : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _primaryBlue : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _primaryBlue : const Color(0xFFE5EAF0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
