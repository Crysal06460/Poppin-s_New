import 'package:flutter/material.dart';
import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';
import 'package:poppins_app/features/documents/services/engagement_storage_service.dart';
import 'package:poppins_app/features/documents/screens/engagement_recap_screen.dart';
import 'package:poppins_app/features/documents/steps/step1_employeur.dart';
import 'package:poppins_app/features/documents/steps/step2_salarie.dart';
import 'package:poppins_app/features/documents/steps/step3_enfant_contrat.dart';
import 'package:poppins_app/features/documents/steps/step4_conditions_accueil.dart';
import 'package:poppins_app/features/documents/steps/step5_remuneration.dart';
import 'package:poppins_app/features/documents/steps/step6_lieu_date.dart';
import 'package:poppins_app/features/documents/steps/step7_signatures.dart';
import 'package:poppins_app/features/documents/widgets/wizard_progress_bar.dart';
import 'package:poppins_app/features/documents/widgets/wizard_navigation_buttons.dart';

// Couleurs Poppins
const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _primaryRed = Color(0xFFD94350);

/// Wizard principal de création d'un engagement réciproque.
///
/// Orchestre 7 étapes de saisie en gérant :
/// - La navigation entre étapes (validation avant passage à la suivante)
/// - La sauvegarde automatique du brouillon dans Firestore
/// - Le chargement d'un brouillon existant au démarrage
/// - La confirmation avant de quitter sans sauvegarder
class EngagementWizardScreen extends StatefulWidget {
  final String userId;

  const EngagementWizardScreen({super.key, required this.userId});

  @override
  State<EngagementWizardScreen> createState() => _EngagementWizardScreenState();
}

class _EngagementWizardScreenState extends State<EngagementWizardScreen> {
  /// Étape courante : 1 à 7
  int _etapeCourante = 1;

  /// Modèle partagé entre toutes les étapes
  EngagementReciproqueModel _model = EngagementReciproqueModel();

  /// Indique si le chargement initial du brouillon est en cours
  bool _isLoading = true;

  /// Indique si un brouillon existe (utilisé pour proposer de le reprendre)
  bool _hasBrouillon = false;

  // ─── GlobalKeys pour accéder aux méthodes validate() des steps ──────────
  final GlobalKey<Step1EmployeurState> _keyStep1 =
      GlobalKey<Step1EmployeurState>();
  final GlobalKey<Step2SalarieState> _keyStep2 =
      GlobalKey<Step2SalarieState>();
  final GlobalKey<Step3EnfantContratState> _keyStep3 =
      GlobalKey<Step3EnfantContratState>();
  final GlobalKey<Step4ConditionsAccueilState> _keyStep4 =
      GlobalKey<Step4ConditionsAccueilState>();
  final GlobalKey<Step5RemunerationState> _keyStep5 =
      GlobalKey<Step5RemunerationState>();
  final GlobalKey<Step6LieuDateState> _keyStep6 =
      GlobalKey<Step6LieuDateState>();
  final GlobalKey<Step7SignaturesState> _keyStep7 =
      GlobalKey<Step7SignaturesState>();

  // ─── Service de stockage ─────────────────────────────────────────────────
  final EngagementStorageService _storageService = EngagementStorageService();

  @override
  void initState() {
    super.initState();
    _chargerBrouillon();
  }

  /// Charge le brouillon depuis Firestore.
  ///
  /// Si un brouillon existe, propose à l'utilisateur de le reprendre
  /// via un dialog (affiché après le premier build).
  void _chargerBrouillon() {
    _storageService.chargerBrouillon(widget.userId).then((brouillon) {
      if (!mounted) return;

      if (brouillon != null) {
        setState(() {
          _hasBrouillon = true;
          _isLoading = false;
        });
        // Affichage du dialog après le premier rendu du widget
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _afficherDialogBrouillon(brouillon);
        });
      } else {
        setState(() {
          _hasBrouillon = false;
          _isLoading = false;
        });
      }
    }).catchError((_) {
      // En cas d'erreur réseau, on ignore et on démarre avec un modèle vide
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  /// Affiche un dialog proposant de reprendre ou d'ignorer le brouillon.
  void _afficherDialogBrouillon(EngagementReciproqueModel brouillon) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reprendre le brouillon ?'),
        content: const Text(
          'Un brouillon non terminé a été trouvé. '
          'Voulez-vous reprendre là où vous en étiez ?',
        ),
        actions: [
          // Nouveau document (ignore le brouillon)
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Nouveau',
              style: TextStyle(color: Color(0xFF636E72)),
            ),
          ),
          // Reprendre le brouillon
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) {
                setState(() => _model = brouillon);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );
  }

  // ─── Navigation ──────────────────────────────────────────────────────────

  /// Valide l'étape courante puis avance vers la suivante ou vers le récap.
  Future<void> _allerEtapeSuivante() async {
    // 1. Valider l'étape courante
    bool isValid = false;
    switch (_etapeCourante) {
      case 1:
        isValid = _keyStep1.currentState?.validate() ?? false;
        break;
      case 2:
        isValid = _keyStep2.currentState?.validate() ?? false;
        break;
      case 3:
        isValid = _keyStep3.currentState?.validate() ?? false;
        break;
      case 4:
        isValid = _keyStep4.currentState?.validate() ?? false;
        break;
      case 5:
        isValid = _keyStep5.currentState?.validate() ?? false;
        break;
      case 6:
        isValid = _keyStep6.currentState?.validate() ?? false;
        break;
      case 7:
        // L'étape 7 a une validation asynchrone (export des signatures PNG)
        isValid = await (_keyStep7.currentState?.exporterEtValider() ?? Future.value(false));
        break;
    }

    if (!isValid) return;

    // 2. Dernière étape : naviguer vers l'écran de récapitulatif.
    // Si l'utilisateur clique "Modifier" sur une section, le recap retourne
    // le numéro de l'étape à corriger → on y saute directement.
    if (_etapeCourante == 7) {
      if (!mounted) return;
      final etapeACorreger = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => EngagementRecapScreen(
            model: _model,
            userId: widget.userId,
          ),
        ),
      );
      if (etapeACorreger != null && mounted) {
        setState(() => _etapeCourante = etapeACorreger);
      }
      return;
    }

    // 3. Sauvegarder le brouillon en arrière-plan (sans bloquer l'UI)
    _storageService.sauvegarderBrouillon(widget.userId, _model).catchError((_) {
      // Erreur silencieuse : le brouillon n'est pas critique pour la navigation
    });

    // 4. Passer à l'étape suivante
    if (mounted) {
      setState(() => _etapeCourante++);
    }
  }

  /// Revient à l'étape précédente sans validation.
  void _allerEtapePrecedente() {
    if (_etapeCourante > 1) {
      setState(() => _etapeCourante--);
    }
  }

  // ─── Gestion du retour arrière ────────────────────────────────────────────

  /// Propose de sauvegarder le brouillon avant de quitter si des données ont été saisies.
  Future<bool> _onWillPop() async {
    // Vérification basique : au moins un champ employeur renseigné
    final bool aDesDonnees = _model.nomEmployeur != null ||
        _model.nomSalarie != null ||
        _model.nomEnfant != null;

    if (!aDesDonnees) {
      return true; // Quitter sans confirmation si aucune donnée saisie
    }

    final resultat = await showDialog<_ActionRetour>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quitter le wizard ?'),
        content: const Text(
          'Des informations ont été saisies. Voulez-vous sauvegarder un brouillon ?',
        ),
        actions: [
          // Annuler : rester dans le wizard
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ActionRetour.annuler),
            child: const Text('Annuler'),
          ),
          // Quitter sans sauvegarder
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ActionRetour.quitter),
            child: const Text(
              'Quitter',
              style: TextStyle(color: _primaryRed),
            ),
          ),
          // Sauvegarder et quitter
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _ActionRetour.sauvegarder),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );

    if (resultat == null || resultat == _ActionRetour.annuler) {
      return false; // Rester dans le wizard
    }

    if (resultat == _ActionRetour.sauvegarder) {
      try {
        await _storageService.sauvegarderBrouillon(widget.userId, _model);
      } catch (_) {
        // Erreur silencieuse : on quitte quand même
      }
    }

    return true; // Quitter
  }

  // ─── Construction des étapes ──────────────────────────────────────────────

  /// Retourne le widget de l'étape courante avec sa clé et son callback onUpdate.
  Widget _buildCurrentStep() {
    switch (_etapeCourante) {
      case 1:
        return Step1Employeur(
          key: _keyStep1,
          model: _model,
          onUpdate: (m) => setState(() => _model = m),
        );
      case 2:
        return Step2Salarie(
          key: _keyStep2,
          model: _model,
          onUpdate: (m) => setState(() => _model = m),
        );
      case 3:
        return Step3EnfantContrat(
          key: _keyStep3,
          model: _model,
          onUpdate: (m) => setState(() => _model = m),
        );
      case 4:
        return Step4ConditionsAccueil(
          key: _keyStep4,
          model: _model,
          onUpdate: (m) => setState(() => _model = m),
        );
      case 5:
        return Step5Remuneration(
          key: _keyStep5,
          model: _model,
          onUpdate: (m) => setState(() => _model = m),
        );
      case 6:
        return Step6LieuDate(
          key: _keyStep6,
          model: _model,
          onUpdate: (m) => setState(() => _model = m),
        );
      case 7:
        return Step7Signatures(
          key: _keyStep7,
          model: _model,
          onUpdate: (m) => setState(() => _model = m),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Affichage du spinner pendant le chargement du brouillon
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: _primaryBlue),
        ),
      );
    }

    return PopScope(
      // Interception du retour arrière système
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final peutQuitter = await _onWillPop();
        if (peutQuitter && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          // Bouton retour personnalisé qui appelle _onWillPop
          leading: BackButton(
            color: _primaryBlue,
            onPressed: () async {
              final peutQuitter = await _onWillPop();
              if (peutQuitter && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            'Engagement Réciproque',
            style: TextStyle(
              color: _primaryBlue,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          // Indicateur de brouillon dans l'AppBar
          actions: [
            if (_hasBrouillon)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: const Text(
                    'Brouillon',
                    style: TextStyle(fontSize: 11, color: _primaryBlue),
                  ),
                  backgroundColor: const Color(0xFFDFE9F2),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // ── Barre de progression ────────────────────────────────────
            WizardProgressBar(
              etapeCourante: _etapeCourante,
              etapesValidees: _etapeCourante - 1,
            ),

            // ── Contenu de l'étape courante ─────────────────────────────
            Expanded(
              child: _buildCurrentStep(),
            ),

            // ── Boutons de navigation ───────────────────────────────────
            WizardNavigationButtons(
              etapeCourante: _etapeCourante,
              onPrecedent:
                  _etapeCourante > 1 ? _allerEtapePrecedente : null,
              onSuivant: () => _allerEtapeSuivante(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum interne pour le dialog de confirmation de sortie
// ─────────────────────────────────────────────────────────────────────────────

enum _ActionRetour { annuler, quitter, sauvegarder }
