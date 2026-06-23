import 'package:flutter/material.dart';
import 'package:poppins_app/features/documents/models/avenant_model.dart';
import 'package:poppins_app/features/documents/services/avenant_storage_service.dart';
import 'package:poppins_app/features/documents/screens/avenant_recap_screen.dart';
import 'package:poppins_app/features/documents/steps/avenant_step1_contrat_employeur.dart';
import 'package:poppins_app/features/documents/steps/avenant_step2_salarie.dart';
import 'package:poppins_app/features/documents/steps/avenant_step3_modifications.dart';
import 'package:poppins_app/features/documents/steps/avenant_step4_signatures.dart';
import 'package:poppins_app/features/documents/widgets/avenant_wizard_progress_bar.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed  = Color(0xFFD94350);

class AvenantWizardScreen extends StatefulWidget {
  final String userId;
  final int initialStep;
  const AvenantWizardScreen({super.key, required this.userId, this.initialStep = 0});

  @override
  State<AvenantWizardScreen> createState() => _AvenantWizardScreenState();
}

class _AvenantWizardScreenState extends State<AvenantWizardScreen> {
  static const int _totalEtapes = 4;
  int _etapeCourante = 0;
  AvenantModel _model = AvenantModel();
  bool _isLoading = true;
  bool _isSaving  = false;

  final GlobalKey<AvenantStep4SignaturesState> _step4Key = GlobalKey();
  final _storage = AvenantStorageService();

  @override
  void initState() {
    super.initState();
    _etapeCourante = widget.initialStep;
    _chargerBrouillon();
  }

  Future<void> _chargerBrouillon() async {
    try {
      final brouillon = await _storage.chargerBrouillon(widget.userId);
      if (brouillon != null && mounted) setState(() => _model = brouillon);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sauvegarderBrouillon() async {
    if (_isSaving) return;
    _isSaving = true;
    try { await _storage.sauvegarderBrouillon(widget.userId, _model); } catch (_) {}
    _isSaving = false;
  }

  void _updateModel(AvenantModel updated) {
    setState(() => _model = updated);
    _sauvegarderBrouillon();
  }

  bool _etapeValide() {
    final m = _model;
    switch (_etapeCourante) {
      case 0:
        return m.typeContratOriginal != null &&
            m.dateContratOriginal != null &&
            (m.nomNaissanceEmployeur ?? '').isNotEmpty &&
            (m.prenomEmployeur ?? '').isNotEmpty;
      case 1:
        return (m.nomNaissanceSalarie ?? '').isNotEmpty &&
            (m.prenomSalarie ?? '').isNotEmpty;
      case 2:
        return (m.modificationsTexte ?? '').isNotEmpty && m.dateExecution != null;
      case 3:
        return (m.lieuSignature ?? '').isNotEmpty && m.dateSignature != null;
      default: return true;
    }
  }

  Future<void> _suivant() async {
    if (_etapeCourante == 3) {
      final ok = await _step4Key.currentState?.exporterEtValider() ?? false;
      if (!ok || !mounted) return;
      final result = await Navigator.push<int>(
        context,
        MaterialPageRoute(builder: (_) => AvenantRecapScreen(model: _model, userId: widget.userId)),
      );
      if (result != null && mounted) setState(() => _etapeCourante = result - 1);
      return;
    }
    setState(() => _etapeCourante++);
    await _sauvegarderBrouillon();
  }

  void _precedent() {
    if (_etapeCourante == 0) { Navigator.pop(context); return; }
    setState(() => _etapeCourante--);
  }

  Widget _buildNavBar() {
    final bool isDerniereEtape = _etapeCourante == _totalEtapes - 1;
    final bool valide = _etapeValide();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECF0F1))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _precedent,
            icon: const Icon(Icons.chevron_left, color: Color(0xFF636E72)),
            label: const Text('Precedent', style: TextStyle(color: Color(0xFF636E72), fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFBDC3C7)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Etape ${_etapeCourante + 1} / $_totalEtapes',
              style: const TextStyle(fontSize: 13, color: Color(0xFF95A5A6), fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: valide ? _suivant : null,
            icon: Icon(isDerniereEtape ? Icons.check_circle_outline : Icons.chevron_right, color: Colors.white),
            label: Text(isDerniereEtape ? 'Terminer' : 'Suivant',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              disabledBackgroundColor: const Color(0xFFBDC3C7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 2,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildEtape() {
    switch (_etapeCourante) {
      case 0: return AvenantStep1ContratEmployeur(model: _model, onUpdate: _updateModel);
      case 1: return AvenantStep2Salarie(model: _model, onUpdate: _updateModel);
      case 2: return AvenantStep3Modifications(model: _model, onUpdate: _updateModel);
      case 3: return AvenantStep4Signatures(key: _step4Key, model: _model, onUpdate: _updateModel);
      default: return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: _primaryBlue)));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quit = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Quitter ?'),
          content: const Text('Votre brouillon est sauvegarde automatiquement.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuer')),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Quitter', style: TextStyle(color: _primaryRed))),
          ],
        ));
        if (quit == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0,
          leading: BackButton(color: _primaryBlue, onPressed: _precedent),
          title: const Text('Avenant au contrat',
              style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700, fontSize: 17)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: AvenantWizardProgressBar(etapeCourante: _etapeCourante, totalEtapes: _totalEtapes),
          ),
        ),
        body: _buildEtape(),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }
}
