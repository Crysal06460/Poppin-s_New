import 'package:flutter/material.dart';
import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';
import 'package:poppins_app/features/documents/services/contrat_cdd_storage_service.dart';
import 'package:poppins_app/features/documents/screens/contrat_cdd_recap_screen.dart';
import 'package:poppins_app/features/documents/steps/cdd_step1_employeur.dart';
import 'package:poppins_app/features/documents/steps/cdd_step2_salarie.dart';
import 'package:poppins_app/features/documents/steps/cdd_step3_enfant_duree.dart';
import 'package:poppins_app/features/documents/steps/cdd_step4_horaires.dart';
import 'package:poppins_app/features/documents/steps/cdd_step5_remuneration.dart';
import 'package:poppins_app/features/documents/steps/cdd_step6_repos_feries.dart';
import 'package:poppins_app/features/documents/steps/cdd_step7_signatures.dart';
import 'package:poppins_app/features/documents/widgets/cdd_wizard_progress_bar.dart';
import 'package:poppins_app/features/documents/widgets/wizard_navigation_buttons.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);

class ContratCddWizardScreen extends StatefulWidget {
  final String userId;

  const ContratCddWizardScreen({super.key, required this.userId});

  @override
  State<ContratCddWizardScreen> createState() => _ContratCddWizardScreenState();
}

class _ContratCddWizardScreenState extends State<ContratCddWizardScreen> {
  int _etape = 1;
  ContratCddModel _model = ContratCddModel();
  bool _isLoading = true;
  bool _hasBrouillon = false;

  final GlobalKey<CddStep1EmployeurState> _keyStep1 = GlobalKey();
  final GlobalKey<CddStep2SalarieState> _keyStep2 = GlobalKey();
  final GlobalKey<CddStep3EnfantDureeState> _keyStep3 = GlobalKey();
  final GlobalKey<CddStep4HorairesState> _keyStep4 = GlobalKey();
  final GlobalKey<CddStep5RemunerationState> _keyStep5 = GlobalKey();
  final GlobalKey<CddStep6ReposFeriesState> _keyStep6 = GlobalKey();
  final GlobalKey<CddStep7SignaturesState> _keyStep7 = GlobalKey();

  final ContratCddStorageService _storage = ContratCddStorageService();

  @override
  void initState() {
    super.initState();
    _chargerBrouillon();
  }

  void _chargerBrouillon() {
    _storage.chargerBrouillon(widget.userId).then((b) {
      if (!mounted) return;
      if (b != null) {
        setState(() { _hasBrouillon = true; _isLoading = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _afficherDialogBrouillon(b);
        });
      } else {
        setState(() { _hasBrouillon = false; _isLoading = false; });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _afficherDialogBrouillon(ContratCddModel brouillon) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reprendre le brouillon ?'),
        content: const Text('Un brouillon non terminé a été trouvé. Voulez-vous reprendre là où vous en étiez ?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _storage.supprimerBrouillon(widget.userId).catchError((_) {});
            },
            child: const Text('Nouveau', style: TextStyle(color: Color(0xFF636E72))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) setState(() => _model = brouillon);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );
  }

  Future<void> _allerEtapeSuivante() async {
    bool isValid = false;
    switch (_etape) {
      case 1: isValid = _keyStep1.currentState?.validate() ?? false; break;
      case 2: isValid = _keyStep2.currentState?.validate() ?? false; break;
      case 3: isValid = _keyStep3.currentState?.validate() ?? false; break;
      case 4: isValid = _keyStep4.currentState?.validate() ?? false; break;
      case 5: isValid = _keyStep5.currentState?.validate() ?? false; break;
      case 6: isValid = _keyStep6.currentState?.validate() ?? false; break;
      case 7:
        isValid = await (_keyStep7.currentState?.exporterEtValider() ?? Future.value(false));
        break;
    }
    if (!isValid) return;

    if (_etape == 7) {
      if (!mounted) return;
      final etapeACorreger = await Navigator.push<int>(
        context,
        MaterialPageRoute(builder: (_) => ContratCddRecapScreen(model: _model, userId: widget.userId)),
      );
      if (etapeACorreger != null && mounted) {
        setState(() => _etape = etapeACorreger);
      }
      return;
    }

    _storage.sauvegarderBrouillon(widget.userId, _model).catchError((_) {});
    if (mounted) setState(() => _etape++);
  }

  void _allerEtapePrecedente() {
    if (_etape > 1) setState(() => _etape--);
  }

  Future<bool> _onWillPop() async {
    final aDesDonnees = _model.nomNaissanceEmployeur != null || _model.nomNaissanceSalarie != null || _model.nomEnfant != null;
    if (!aDesDonnees) return true;

    final resultat = await showDialog<_ActionRetour>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quitter le wizard ?'),
        content: const Text('Des informations ont été saisies. Voulez-vous sauvegarder un brouillon ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, _ActionRetour.annuler), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, _ActionRetour.quitter), child: const Text('Quitter', style: TextStyle(color: _primaryRed))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _ActionRetour.sauvegarder),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );

    if (resultat == null || resultat == _ActionRetour.annuler) return false;
    if (resultat == _ActionRetour.sauvegarder) {
      try { await _storage.sauvegarderBrouillon(widget.userId, _model); } catch (_) {}
    }
    return true;
  }

  Widget _buildCurrentStep() {
    switch (_etape) {
      case 1: return CddStep1Employeur(key: _keyStep1, model: _model, onUpdate: (m) => setState(() => _model = m));
      case 2: return CddStep2Salarie(key: _keyStep2, model: _model, onUpdate: (m) => setState(() => _model = m));
      case 3: return CddStep3EnfantDuree(key: _keyStep3, model: _model, onUpdate: (m) => setState(() => _model = m));
      case 4: return CddStep4Horaires(key: _keyStep4, model: _model, onUpdate: (m) => setState(() => _model = m));
      case 5: return CddStep5Remuneration(key: _keyStep5, model: _model, onUpdate: (m) => setState(() => _model = m));
      case 6: return CddStep6ReposFeries(key: _keyStep6, model: _model, onUpdate: (m) => setState(() => _model = m));
      case 7: return CddStep7Signatures(key: _keyStep7, model: _model, onUpdate: (m) => setState(() => _model = m));
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _primaryBlue)));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final peutQuitter = await _onWillPop();
        if (peutQuitter && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: BackButton(
            color: _primaryBlue,
            onPressed: () async {
              final peutQuitter = await _onWillPop();
              if (peutQuitter && mounted) Navigator.pop(context);
            },
          ),
          title: const Text('Contrat CDD', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700, fontSize: 17)),
          actions: [
            if (_hasBrouillon)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: const Text('Brouillon', style: TextStyle(fontSize: 11, color: _primaryBlue)),
                  backgroundColor: const Color(0xFFDFE9F2),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            CddWizardProgressBar(etapeCourante: _etape, etapesValidees: _etape - 1),
            Expanded(child: _buildCurrentStep()),
            WizardNavigationButtons(
              etapeCourante: _etape,
              onPrecedent: _etape > 1 ? _allerEtapePrecedente : null,
              onSuivant: _allerEtapeSuivante,
            ),
          ],
        ),
      ),
    );
  }
}

enum _ActionRetour { annuler, quitter, sauvegarder }
