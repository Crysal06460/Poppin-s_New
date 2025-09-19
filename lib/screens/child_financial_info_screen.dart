import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ChildFinancialInfoScreen extends StatefulWidget {
  final String childId;

  const ChildFinancialInfoScreen({Key? key, required this.childId})
      : super(key: key);

  @override
  _ChildFinancialInfoScreenState createState() =>
      _ChildFinancialInfoScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _ChildFinancialInfoScreenState extends State<ChildFinancialInfoScreen> {
  // Variables pour le mémo mensuel
  bool? _useMonthlyTable = null;
  final TextEditingController _monthlySalaryController =
      TextEditingController();
  final TextEditingController _careExpensesController = TextEditingController();
  final TextEditingController _mealExpensesController = TextEditingController();
  final TextEditingController _kmExpensesController = TextEditingController();

  bool _isSaving = false;
  int _selectedIndex = 2; // Pour la barre de navigation du bas
  String structureName = "Chargement...";
  bool isLoadingStructure = true;
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _loadStructureInfo(); // AJOUT : Charger les infos de structure
  }

  @override
  void dispose() {
    _monthlySalaryController.dispose();
    _careExpensesController.dispose();
    _mealExpensesController.dispose();
    _kmExpensesController.dispose();
    super.dispose();
  }

  Future<void> _loadStructureInfo() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Utilisateur non connecté");
        return;
      }

      final userEmail = user.email?.toLowerCase() ?? '';
      print("📧 Email utilisateur: $userEmail");

      // Vérifier d'abord si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        print("👤 Données utilisateur trouvées: $userData");

        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM
          final structureId = userData['structureId'];
          print("🏢 Utilisateur MAM détecté - ID structure: $structureId");

          final structureDoc = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .get();

          if (structureDoc.exists) {
            final data = structureDoc.data() as Map<String, dynamic>;
            setState(() {
              structureName = data['structureName'] ?? 'Structure inconnue';
              isLoadingStructure = false;
            });
            print("🏢 Nom de structure MAM récupéré: $structureName");
          } else {
            print("❌ Document structure MAM non trouvé");
            setState(() {
              structureName = 'Structure inconnue';
              isLoadingStructure = false;
            });
          }
        } else {
          // Utilisateur normal (assistante maternelle individuelle)
          print("👩‍🍼 Utilisateur assistante maternelle individuelle");
          final structureDoc = await FirebaseFirestore.instance
              .collection('structures')
              .doc(user.uid)
              .get();

          if (structureDoc.exists) {
            final data = structureDoc.data() as Map<String, dynamic>;
            setState(() {
              structureName = data['structureName'] ?? 'Structure inconnue';
              isLoadingStructure = false;
            });
            print("🏢 Nom de structure individuelle récupéré: $structureName");
          } else {
            print("❌ Document structure individuelle non trouvé");
            setState(() {
              structureName = 'Structure inconnue';
              isLoadingStructure = false;
            });
          }
        }
      } else {
        print(
            "❌ Document utilisateur non trouvé, utilisation de l'ID utilisateur par défaut");
        // Fallback : utiliser l'ID utilisateur comme ID de structure
        final structureDoc = await FirebaseFirestore.instance
            .collection('structures')
            .doc(user.uid)
            .get();

        if (structureDoc.exists) {
          final data = structureDoc.data() as Map<String, dynamic>;
          setState(() {
            structureName = data['structureName'] ?? 'Structure inconnue';
            isLoadingStructure = false;
          });
          print("🏢 Nom de structure fallback récupéré: $structureName");
        } else {
          print("❌ Aucun document structure trouvé");
          setState(() {
            structureName = 'Structure inconnue';
            isLoadingStructure = false;
          });
        }
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des infos de structure: $e");
      setState(() {
        structureName = 'Erreur de chargement';
        isLoadingStructure = false;
      });
    }
  }

  Widget _buildTabletLayout() {
    return LayoutBuilder(builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth;
      final double maxHeight = constraints.maxHeight;
      final double sideMargin = (maxWidth * 0.03).clamp(10.0, 30.0);
      final double columnGap = (maxWidth * 0.025).clamp(10.0, 25.0);

      return Padding(
        padding: EdgeInsets.fromLTRB(
            sideMargin, maxHeight * 0.02, sideMargin, maxHeight * 0.02),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panneau gauche - Aperçu des informations
            Expanded(
              flex: 4,
              child: Container(
                margin: EdgeInsets.only(right: columnGap),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all((maxWidth * 0.025).clamp(15.0, 30.0)),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre du panneau
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: lightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.preview_rounded,
                                color: primaryBlue,
                                size: (maxWidth * 0.025).clamp(20.0, 30.0),
                              ),
                            ),
                            SizedBox(
                                width: (maxWidth * 0.015).clamp(8.0, 15.0)),
                            Expanded(
                              child: Text(
                                "Aperçu",
                                style: TextStyle(
                                  fontSize:
                                      (maxWidth * 0.022).clamp(16.0, 24.0),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: maxHeight * 0.04),

                        // Aperçu du choix mémo mensuel
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                              (maxWidth * 0.02).clamp(12.0, 20.0)),
                          decoration: BoxDecoration(
                            color: _useMonthlyTable == null
                                ? Colors.grey.shade50
                                : lightBlue.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _useMonthlyTable == null
                                  ? Colors.grey.shade200
                                  : primaryBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Mémo mensuel",
                                style: TextStyle(
                                  fontSize:
                                      (maxWidth * 0.018).clamp(14.0, 20.0),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: maxHeight * 0.02),
                              if (_useMonthlyTable != null) ...[
                                Container(
                                  padding: EdgeInsets.all(
                                      (maxWidth * 0.015).clamp(8.0, 15.0)),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: _useMonthlyTable == true
                                          ? [
                                              primaryBlue.withOpacity(0.7),
                                              primaryBlue
                                            ]
                                          : [
                                              primaryRed.withOpacity(0.7),
                                              primaryRed
                                            ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _useMonthlyTable == true
                                        ? Icons.check
                                        : Icons.close,
                                    size: (maxWidth * 0.04).clamp(24.0, 40.0),
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: maxHeight * 0.015),
                                Text(
                                  _useMonthlyTable == true ? "Oui" : "Non",
                                  style: TextStyle(
                                    fontSize:
                                        (maxWidth * 0.02).clamp(16.0, 22.0),
                                    fontWeight: FontWeight.bold,
                                    color: _useMonthlyTable == true
                                        ? primaryBlue
                                        : primaryRed,
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: EdgeInsets.all(
                                      (maxWidth * 0.015).clamp(8.0, 15.0)),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.help_outline,
                                    size: (maxWidth * 0.04).clamp(24.0, 40.0),
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: maxHeight * 0.015),
                                Text(
                                  "Non sélectionné",
                                  style: TextStyle(
                                    fontSize:
                                        (maxWidth * 0.018).clamp(14.0, 20.0),
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(height: maxHeight * 0.03),

                        // Aperçu des informations financières
                        if (_useMonthlyTable == true) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(
                                (maxWidth * 0.02).clamp(12.0, 20.0)),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                          (maxWidth * 0.01).clamp(6.0, 12.0)),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.euro_rounded,
                                        color: primaryBlue,
                                        size:
                                            (maxWidth * 0.02).clamp(16.0, 24.0),
                                      ),
                                    ),
                                    SizedBox(
                                        width:
                                            (maxWidth * 0.01).clamp(6.0, 12.0)),
                                    Flexible(
                                      child: Text(
                                        "Recap menusel",
                                        style: TextStyle(
                                          fontSize: (maxWidth * 0.018)
                                              .clamp(14.0, 20.0),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: maxHeight * 0.03),

                                // Salaire net
                                _buildInfoRowTablet(
                                    "Salaire net",
                                    _monthlySalaryController.text.isEmpty
                                        ? "Non renseigné"
                                        : "${_monthlySalaryController.text} €",
                                    maxWidth),
                                SizedBox(height: maxHeight * 0.03),

                                // Frais d'entretien
                                // Les autres lignes ne s'affichent plus dans le mémo mensuel

                                SizedBox(height: maxHeight * 0.03),

                                // Information sur l'invitation
                                Container(
                                  padding: EdgeInsets.all(
                                      (maxWidth * 0.015).clamp(8.0, 15.0)),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: primaryBlue.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: primaryBlue,
                                            size: (maxWidth * 0.018)
                                                .clamp(14.0, 20.0),
                                          ),
                                          SizedBox(
                                              width: (maxWidth * 0.01)
                                                  .clamp(6.0, 12.0)),
                                          Flexible(
                                            child: Text(
                                              "Information importante",
                                              style: TextStyle(
                                                fontSize: (maxWidth * 0.016)
                                                    .clamp(12.0, 18.0),
                                                fontWeight: FontWeight.w600,
                                                color: primaryBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                          height: (maxHeight * 0.01)
                                              .clamp(6.0, 12.0)),
                                      Text(
                                        "Une invitation sera automatiquement envoyée aux parents par email pour accéder à l'application Poppin's.",
                                        style: TextStyle(
                                          color: primaryBlue,
                                          fontSize: (maxWidth * 0.014)
                                              .clamp(10.0, 16.0),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            height: 200, // Hauteur fixe pour éviter l'overflow
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: (maxWidth * 0.04).clamp(32.0, 48.0),
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: maxHeight * 0.02),
                                  Text(
                                    "Les informations financières\nseront affichées ici",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize:
                                          (maxWidth * 0.016).clamp(12.0, 18.0),
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Ajouter un peu d'espace en bas pour éviter que le contenu soit coupé
                        SizedBox(height: maxHeight * 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Panneau droit - Formulaire
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all((maxWidth * 0.025).clamp(15.0, 30.0)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre du formulaire
                      Text(
                        "Configuration du mémo mensuel",
                        style: TextStyle(
                          fontSize: (maxWidth * 0.025).clamp(18.0, 28.0),
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      // Description
                      Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryBlue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(
                                  (maxWidth * 0.01).clamp(6.0, 12.0)),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.table_chart_rounded,
                                color: primaryBlue,
                                size: (maxWidth * 0.02).clamp(16.0, 24.0),
                              ),
                            ),
                            SizedBox(
                                width: (maxWidth * 0.015).clamp(8.0, 15.0)),
                            Expanded(
                              child: Text(
                                "Le mémo mensuel est proposé à titre indicatif et permet de générer le récapitulatif mensuel.",
                                style: TextStyle(
                                  fontSize:
                                      (maxWidth * 0.016).clamp(12.0, 18.0),
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Question
                      Text(
                        "Souhaitez-vous utiliser le mémo mensuel ?",
                        style: TextStyle(
                          fontSize: (maxWidth * 0.02).clamp(16.0, 22.0),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: maxHeight * 0.025),

                      // Boutons Oui/Non
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildToggleButtonTablet(
                              "Oui", _useMonthlyTable == true, () {
                            setState(() => _useMonthlyTable = true);
                          }, maxWidth, maxHeight),
                          SizedBox(width: maxWidth * 0.04),
                          _buildToggleButtonTablet(
                              "Non", _useMonthlyTable == false, () {
                            setState(() => _useMonthlyTable = false);
                          }, maxWidth, maxHeight),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Formulaire financier
                      if (_useMonthlyTable == true) ...[
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildCurrencyTextFieldTablet(
                                    _monthlySalaryController,
                                    "Salaire net mensuel",
                                    "€",
                                    maxWidth,
                                    maxHeight),
                                SizedBox(height: maxHeight * 0.03),
                                _buildCurrencyTextFieldTablet(
                                    _careExpensesController,
                                    "Frais d'entretien par jour",
                                    "€/jour",
                                    maxWidth,
                                    maxHeight),
                                SizedBox(height: maxHeight * 0.03),
                                _buildCurrencyTextFieldTablet(
                                    _mealExpensesController,
                                    "Frais de repas par jour",
                                    "€/jour",
                                    maxWidth,
                                    maxHeight),
                                SizedBox(height: maxHeight * 0.03),
                                _buildCurrencyTextFieldTablet(
                                    _kmExpensesController,
                                    "Frais kilométriques par km",
                                    "€/km",
                                    maxWidth,
                                    maxHeight),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: (maxWidth * 0.04).clamp(32.0, 48.0),
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: maxHeight * 0.02),
                                  Text(
                                    "Cliquer sur Oui pour remplir le mémo mensuel (Salaire net)",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize:
                                          (maxWidth * 0.016).clamp(12.0, 18.0),
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: maxHeight * 0.03),

                      // Bouton Terminer
                      Center(
                        child: Container(
                          width: (maxWidth * 0.25).clamp(200.0, 300.0),
                          child: ElevatedButton(
                            onPressed: _useMonthlyTable == null
                                ? null
                                : _saveFinancialInfo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      (maxWidth * 0.03).clamp(20.0, 40.0),
                                  vertical:
                                      (maxHeight * 0.02).clamp(12.0, 20.0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                            ),
                            child: _isSaving
                                ? SizedBox(
                                    width: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    height: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Terminer",
                                        style: TextStyle(
                                          fontSize: (maxWidth * 0.02)
                                              .clamp(14.0, 20.0),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(
                                          width: (maxWidth * 0.01)
                                              .clamp(6.0, 12.0)),
                                      Icon(Icons.check_circle_outline,
                                          color: Colors.white,
                                          size: (maxWidth * 0.02)
                                              .clamp(16.0, 24.0)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _showExitWarning(
      BuildContext context, String destination) async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: primaryRed,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Attention !",
                  style: TextStyle(
                    color: primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: BoxConstraints(maxWidth: 300),
            child: Text(
              "Si vous quittez l'ajout de l'enfant maintenant, celui-ci ne sera pas ajouté et toutes les informations saisies seront perdues.\n\nÊtes-vous sûr de vouloir quitter ?",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                "Annuler",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Quitter",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      if (context.mounted) {
        context.go(destination);
      }
    }
  }

  Widget _buildInfoRowTablet(String label, String value, double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          "$label:",
          style: TextStyle(
            fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(
            height: (maxWidth * 0.008)
                .clamp(4.0, 8.0)), // Petit espacement entre label et valeur
        // Valeur
        Text(
          value,
          style: TextStyle(
            fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
            fontWeight:
                value.contains("Non") ? FontWeight.normal : FontWeight.w600,
            color:
                value.contains("Non") ? Colors.grey.shade400 : Colors.black87,
            fontStyle:
                value.contains("Non") ? FontStyle.italic : FontStyle.normal,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildToggleButtonTablet(String label, bool isSelected,
      VoidCallback onTap, double maxWidth, double maxHeight) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.all((maxWidth * 0.025).clamp(15.0, 25.0)),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryBlue.withOpacity(0.7),
                        primaryBlue,
                      ],
                    )
                  : null,
              color: isSelected ? null : Colors.grey.shade200,
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Icon(
              isSelected ? Icons.check : Icons.help_outline,
              size: (maxWidth * 0.045).clamp(32.0, 48.0),
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
          SizedBox(height: (maxHeight * 0.015).clamp(8.0, 15.0)),
          Text(
            label,
            style: TextStyle(
              fontSize: (maxWidth * 0.02).clamp(16.0, 22.0),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? primaryBlue : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyTextFieldTablet(TextEditingController controller,
      String labelText, String suffixText, double maxWidth, double maxHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: (maxHeight * 0.015).clamp(8.0, 15.0)),
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 3),
                blurRadius: 5,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            onChanged: (value) => setState(() {}), // Pour rafraîchir l'aperçu
            decoration: InputDecoration(
              labelText: "Montant en €",
              labelStyle: TextStyle(color: Colors.grey.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryBlue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: (maxWidth * 0.02).clamp(12.0, 20.0),
                vertical: (maxHeight * 0.02).clamp(12.0, 20.0),
              ),
              suffixText: suffixText,
              suffixStyle: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*')),
            ],
            style: TextStyle(fontSize: (maxWidth * 0.018).clamp(14.0, 20.0)),
          ),
        ),
      ],
    );
  }

  // Méthode pour sauvegarder les informations financières
  Future<void> _saveFinancialInfo() async {
    // Si on n'utilise pas le mémo mensuel, on retourne directement à l'accueil
    if (_useMonthlyTable == false) {
      // Envoyer l'invitation avant de quitter
      await _sendParentInvitation();
      if (mounted) {
        context.go('/home');
      }
      return;
    }

    // Vérification du salaire mensuel (obligatoire)
    if (_monthlySalaryController.text.isEmpty) {
      _showError("Le salaire mensuel est obligatoire");
      return;
    }

    // Récupérer l'email de l'utilisateur actuel (membre qui ajoute l'enfant)
    final User? user = FirebaseAuth.instance.currentUser;
    final String currentUserEmail = user?.email?.toLowerCase() ?? '';

    setState(() => _isSaving = true);

    try {
      if (user == null) throw Exception("Utilisateur non connecté");

      // Vérifier d'abord si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      // ID de structure à utiliser (par défaut, utiliser l'ID de l'utilisateur)
      String structureId = user.uid;

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "🔄 Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // Mise à jour dans Firestore avec l'email du membre actuel
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .update({
        'financialInfo': {
          'useMonthlyTable': _useMonthlyTable,
          'monthlySalary': double.tryParse(
                  _monthlySalaryController.text.replaceAll(',', '.')) ??
              0,
        },
        // Cleanup des anciens champs au niveau racine si existaient déjà
        'financialInfo.careExpenses': FieldValue.delete(),
        'financialInfo.mealExpenses': FieldValue.delete(),
        'financialInfo.kmExpenses': FieldValue.delete(),
        // Ajouter l'email du membre ACTUEL (qui ajoute l'enfant)
        'assignedMemberEmail': currentUserEmail,
        // Stockez également ces informations supplémentaires pour plus de robustesse
        'lastUpdatedBy': currentUserEmail,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      print(
          "✅ Informations financières sauvegardées avec succès pour le membre: $currentUserEmail");

      // Envoyer l'invitation aux parents
      await _sendParentInvitation();

      if (mounted) {
        // Retour à l'écran d'accueil après avoir complété tout le processus
        context.go('/home');
      }
    } catch (e) {
      print("❌ Erreur lors de la sauvegarde des informations financières: $e");
      _showError("Une erreur est survenue lors de la sauvegarde");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sendParentInvitation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      // Vérifier d'abord si l'utilisateur est un membre MAM
      final userEmail = user.email?.toLowerCase() ?? '';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      // ID de structure à utiliser (par défaut, utiliser l'ID de l'utilisateur)
      String structureId = user.uid;

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "🔄 Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // Récupérer les informations de l'enfant et des parents
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .get();

      final childData = childDoc.data() ?? {};
      final parent1Data = childData['parent1'] ?? {};
      final parent2Data = childData['parent2'] ?? {};

      // Récupérer les informations de la structure
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      final structureName =
          structureDoc.data()?['structureName'] ?? 'Structure d\'accueil';

      // Liste des parents à qui envoyer des invitations
      List<Map<String, dynamic>> parentsToInvite = [];

      // Ajouter le parent 1 s'il a un email
      if (parent1Data['email'] != null &&
          parent1Data['email'].toString().isNotEmpty) {
        parentsToInvite.add({
          'email': parent1Data['email'].toString().toLowerCase(),
          'firstName': parent1Data['firstName'] ?? '',
          'lastName': parent1Data['lastName'] ?? '',
        });
      }

      // Ajouter le parent 2 s'il a un email
      if (parent2Data['email'] != null &&
          parent2Data['email'].toString().isNotEmpty) {
        parentsToInvite.add({
          'email': parent2Data['email'].toString().toLowerCase(),
          'firstName': parent2Data['firstName'] ?? '',
          'lastName': parent2Data['lastName'] ?? '',
        });
      }

      // Vérifier s'il y a des parents à inviter
      if (parentsToInvite.isEmpty) {
        print(
            "⚠️ Aucun email parent trouvé pour l'enfant ${childData['firstName']}");
        return;
      }

      // Définir la date d'expiration (30 jours à partir de maintenant)
      final DateTime expirationDate = DateTime.now().add(Duration(days: 30));

      // Envoyer une invitation à chaque parent
      for (var parentData in parentsToInvite) {
        final String normalizedEmail = parentData['email'];
        print("🔑 Création d'une invitation pour $normalizedEmail");

        // 1. Créer l'entrée d'invitation dans Firestore
        await FirebaseFirestore.instance.collection('invitations').add({
          'email': normalizedEmail,
          'type': 'parent',
          'structureId': structureId,
          'structureName': structureName,
          'childId': widget.childId,
          'childName': childData['firstName'] ?? "Enfant",
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expirationDate),
          'status': 'active',
        });

        print("✅ Invitation enregistrée dans Firestore pour $normalizedEmail");

        // 2. Créer ou mettre à jour l'utilisateur parent dans Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(normalizedEmail)
            .set({
          'role': 'parent',
          'email': normalizedEmail,
          'isFirstLogin': true,
          'childId': widget.childId,
          'structureId': structureId,
          'structureName': structureName,
          'childName': childData['firstName'] ?? "Enfant",
          'createdAt': FieldValue.serverTimestamp(),
          'children': [
            widget.childId
          ], // S'assurer que l'enfant est dans la liste des enfants
        });

        print(
            "✅ Document utilisateur parent créé/mis à jour pour $normalizedEmail");

        // 3. Construire les données du template pour l'email
        final templateData = {
          'firstName': parentData['firstName'] ?? '',
          'lastName': parentData['lastName'] ?? '',
          'childName': childData['firstName'] ?? '',
          'childId': widget.childId,
          'structureName': structureName,
          'structureId': structureId,
          'androidLink':
              'https://play.google.com/store/apps/details?id=com.example.poppins_app',
          'iosLink': 'https://apps.apple.com/app/id123456789',
          'email': normalizedEmail,
          'year': DateTime.now().year.toString(),
        };

        // 4. Ajouter l'email à la file d'attente d'envoi
        await FirebaseFirestore.instance.collection('emailQueue').add({
          'to': normalizedEmail,
          'template': 'parent-invitation',
          'subject': "Invitation Poppins - Pour ${childData['firstName']}",
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'priority': 'high',
          'retryCount': 0,
          'templateData': templateData
        });

        print("✅ Invitation envoyée au parent: $normalizedEmail");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("Invitations envoyées aux parents"),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("❌ Erreur lors de l'envoi des invitations: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de l'envoi des invitations aux parents"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryBlue,
            primaryBlue.withOpacity(0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            children: [
              // Structure name and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      structureName, // MODIFICATION : Utiliser structureName au lieu de "Poppins"
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              // Page title with icon
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Mémo mensuel',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: BottomNavigationBar(
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_Dashboard.png',
              width: 50,
              height: 50,
            ),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/maison_icon.png',
              width: 50,
              height: 50,
            ),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_Echanges.png',
              width: 50,
              height: 50,
            ),
            label: "Echanges",
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      // Dashboard
      _showExitWarning(context, '/dashboard');
    } else if (index == 1) {
      // Home
      _showExitWarning(context, '/home');
    } else if (index == 2) {
      // Déjà sur cette page d'ajout - ne rien faire
    }
  }

  @override
  Widget build(BuildContext context) {
    // Déterminer si on est sur iPad
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: isTabletDevice
                ? _buildTabletLayout() // Layout spécifique pour iPad
                : SingleChildScrollView(
                    // Layout original pour iPhone
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button (seulement pour iPhone) - CORRECTION ICI
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            // CORRECTION : Utiliser context.go au lieu de Navigator.pop
                            if (widget.childId.isNotEmpty) {
                              print(
                                  "🔄 Retour vers child-meal-info avec childId: ${widget.childId}");
                              context.go('/child-meal-info',
                                  extra: widget.childId);
                            } else {
                              _showError("Erreur : ID d'enfant manquant !");
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: lightBlue,
                            foregroundColor: primaryBlue,
                            padding: EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Main card - Monthly Table
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: lightBlue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.table_chart_rounded,
                                        color: primaryBlue,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Configuration du mémo mensuel",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Le mémo mensuel permet de suivre et de générer le récapitulatif mensuel.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Question
                                Text(
                                  "Souhaitez-vous utiliser le mémo mensuel ?",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildToggleButton(
                                          "Oui", _useMonthlyTable == true, () {
                                        setState(() => _useMonthlyTable = true);
                                      }),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildToggleButton(
                                          "Non", _useMonthlyTable == false, () {
                                        setState(
                                            () => _useMonthlyTable = false);
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Détails du mémo mensuel
                        if (_useMonthlyTable == true) ...[
                          const SizedBox(height: 20),
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: lightBlue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.euro_rounded,
                                          color: primaryBlue,
                                          size: 24,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "Récap mensuel",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),

                                  // Salaire mensuel
                                  Text(
                                    "Salaire net :",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCurrencyTextField(
                                      _monthlySalaryController,
                                      "Montant en €",
                                      "€"),

                                  const SizedBox(height: 20),

                                  // (champs supprimés dans le mémo mensuel)
                                  // (supprimé dans le mémo mensuel)

                                  const SizedBox(height: 20),

                                  // (champs supprimés dans le mémo mensuel)
                                  // (supprimé dans le mémo mensuel)

                                  const SizedBox(height: 20),

                                  // (champs supprimés dans le mémo mensuel)
                                  // (supprimé dans le mémo mensuel)
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Information sur l'invitation automatique
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: primaryBlue.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: primaryBlue),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Une invitation sera automatiquement envoyée aux parents par email pour accéder à l'application Poppin's.",
                                  style: TextStyle(
                                      color: primaryBlue, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Terminer button
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            onPressed: _useMonthlyTable == null
                                ? null
                                : _saveFinancialInfo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                            ),
                            child: _isSaving
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Terminer",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.check_circle_outline,
                                          color: Colors.white),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 5,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyTextField(
      TextEditingController controller, String labelText, String suffixText) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 3),
            blurRadius: 5,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixText: suffixText,
          suffixStyle: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*')),
        ],
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
