import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ChildMealInfoScreen extends StatefulWidget {
  final String childId;

  const ChildMealInfoScreen({Key? key, required this.childId})
      : super(key: key);

  @override
  _ChildMealInfoScreenState createState() => _ChildMealInfoScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _ChildMealInfoScreenState extends State<ChildMealInfoScreen> {
  // Variables pour les allergies alimentaires
  bool? _hasFoodAllergies = false;
  final TextEditingController _foodAllergiesController =
      TextEditingController();

  // Variables pour les régimes alimentaires
  bool? _hasSpecialDiet = false;
  final TextEditingController _specialDietController = TextEditingController();

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
    _foodAllergiesController.dispose();
    _specialDietController.dispose();
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
            // Panneau gauche - Aperçu des informations alimentaires
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
                          SizedBox(width: (maxWidth * 0.015).clamp(8.0, 15.0)),
                          Expanded(
                            child: Text(
                              "Aperçu",
                              style: TextStyle(
                                fontSize: (maxWidth * 0.022).clamp(16.0, 24.0),
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Aperçu des allergies alimentaires
                      Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
                        decoration: BoxDecoration(
                          color: _hasFoodAllergies == null
                              ? Colors.grey.shade50
                              : (_hasFoodAllergies == true
                                  ? primaryRed.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _hasFoodAllergies == null
                                ? Colors.grey.shade200
                                : (_hasFoodAllergies == true
                                    ? primaryRed.withOpacity(0.3)
                                    : Colors.green.withOpacity(0.3)),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Allergies alimentaires",
                              style: TextStyle(
                                fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: maxHeight * 0.02),
                            if (_hasFoodAllergies != null) ...[
                              Container(
                                padding: EdgeInsets.all(
                                    (maxWidth * 0.015).clamp(8.0, 15.0)),
                                decoration: BoxDecoration(
                                  color: _hasFoodAllergies == true
                                      ? primaryRed
                                      : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _hasFoodAllergies == true
                                      ? Icons.warning
                                      : Icons.check,
                                  size: (maxWidth * 0.03).clamp(20.0, 35.0),
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: maxHeight * 0.015),
                              Text(
                                _hasFoodAllergies == true ? "Oui" : "Non",
                                style: TextStyle(
                                  fontSize: (maxWidth * 0.02).clamp(14.0, 22.0),
                                  fontWeight: FontWeight.bold,
                                  color: _hasFoodAllergies == true
                                      ? primaryRed
                                      : Colors.green,
                                ),
                              ),
                              if (_hasFoodAllergies == true &&
                                  _foodAllergiesController.text.isNotEmpty) ...[
                                SizedBox(height: maxHeight * 0.01),
                                Text(
                                  _foodAllergiesController.text,
                                  style: TextStyle(
                                    fontSize:
                                        (maxWidth * 0.016).clamp(12.0, 18.0),
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
                                  size: (maxWidth * 0.03).clamp(20.0, 35.0),
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: maxHeight * 0.015),
                              Text(
                                "Non renseigné",
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

                      // Aperçu du régime alimentaire
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                              (maxWidth * 0.02).clamp(12.0, 20.0)),
                          decoration: BoxDecoration(
                            color: _hasSpecialDiet == null
                                ? Colors.grey.shade50
                                : (_hasSpecialDiet == true
                                    ? primaryBlue.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _hasSpecialDiet == null
                                  ? Colors.grey.shade200
                                  : (_hasSpecialDiet == true
                                      ? primaryBlue.withOpacity(0.3)
                                      : Colors.green.withOpacity(0.3)),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Régime alimentaire",
                                style: TextStyle(
                                  fontSize:
                                      (maxWidth * 0.018).clamp(14.0, 20.0),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: maxHeight * 0.02),
                              if (_hasSpecialDiet != null) ...[
                                Container(
                                  padding: EdgeInsets.all(
                                      (maxWidth * 0.015).clamp(8.0, 15.0)),
                                  decoration: BoxDecoration(
                                    color: _hasSpecialDiet == true
                                        ? primaryBlue
                                        : Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _hasSpecialDiet == true
                                        ? Icons.restaurant_menu
                                        : Icons.check,
                                    size: (maxWidth * 0.03).clamp(20.0, 35.0),
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: maxHeight * 0.015),
                                Text(
                                  _hasSpecialDiet == true ? "Oui" : "Non",
                                  style: TextStyle(
                                    fontSize:
                                        (maxWidth * 0.02).clamp(14.0, 22.0),
                                    fontWeight: FontWeight.bold,
                                    color: _hasSpecialDiet == true
                                        ? primaryBlue
                                        : Colors.green,
                                  ),
                                ),
                                if (_hasSpecialDiet == true &&
                                    _specialDietController.text.isNotEmpty) ...[
                                  SizedBox(height: maxHeight * 0.01),
                                  Text(
                                    _specialDietController.text,
                                    style: TextStyle(
                                      fontSize:
                                          (maxWidth * 0.016).clamp(12.0, 18.0),
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
                                    size: (maxWidth * 0.03).clamp(20.0, 35.0),
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: maxHeight * 0.015),
                                Text(
                                  "Non renseigné",
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
                      ),
                    ],
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
                        "Informations alimentaires",
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
                                Icons.restaurant_menu,
                                color: primaryBlue,
                                size: (maxWidth * 0.02).clamp(16.0, 24.0),
                              ),
                            ),
                            SizedBox(
                                width: (maxWidth * 0.015).clamp(8.0, 15.0)),
                            Expanded(
                              child: Text(
                                "Ces informations sont importantes pour garantir la sécurité et le bien-être de l'enfant pendant les repas.",
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

                      // Contenu du formulaire
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section allergies alimentaires
                              _buildAllergyFormTablet(maxWidth, maxHeight),

                              SizedBox(height: maxHeight * 0.04),

                              // Section régime alimentaire
                              _buildDietFormTablet(maxWidth, maxHeight),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.03),

                      // Bouton Continuer
                      Center(
                        child: Container(
                          width: (maxWidth * 0.25).clamp(200.0, 300.0),
                          child: ElevatedButton.icon(
                            icon: _isSaving
                                ? SizedBox(
                                    width: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    height: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Icon(Icons.arrow_forward,
                                    color: Colors.white,
                                    size: (maxWidth * 0.02).clamp(16.0, 24.0)),
                            label: Text(
                              "Continuer",
                              style: TextStyle(
                                fontSize: (maxWidth * 0.02).clamp(14.0, 20.0),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: _isSaving ? null : _saveMealInfo,
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

  Widget _buildAllergyFormTablet(double maxWidth, double maxHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "L'enfant a-t-il des allergies alimentaires ?",
          style: TextStyle(
            fontSize: (maxWidth * 0.02).clamp(14.0, 22.0),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: maxHeight * 0.02),
        Row(
          children: [
            Expanded(
              child: _buildToggleButtonTablet("Oui", _hasFoodAllergies == true,
                  () {
                setState(() => _hasFoodAllergies = true);
              }, maxWidth, maxHeight),
            ),
            SizedBox(width: maxWidth * 0.02),
            Expanded(
              child: _buildToggleButtonTablet("Non", _hasFoodAllergies == false,
                  () {
                setState(() {
                  _hasFoodAllergies = false;
                  _foodAllergiesController.clear();
                });
              }, maxWidth, maxHeight),
            ),
          ],
        ),
        if (_hasFoodAllergies == true) ...[
          SizedBox(height: maxHeight * 0.03),
          _buildTextFieldTablet(
            "Précisez les allergies alimentaires",
            _foodAllergiesController,
            maxWidth,
            maxHeight,
            maxLines: 3,
          ),
        ],
      ],
    );
  }

  Widget _buildDietFormTablet(double maxWidth, double maxHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "L'enfant suit-il un régime alimentaire spécifique ?",
          style: TextStyle(
            fontSize: (maxWidth * 0.02).clamp(14.0, 22.0),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: maxHeight * 0.02),
        Row(
          children: [
            Expanded(
              child:
                  _buildToggleButtonTablet("Oui", _hasSpecialDiet == true, () {
                setState(() => _hasSpecialDiet = true);
              }, maxWidth, maxHeight),
            ),
            SizedBox(width: maxWidth * 0.02),
            Expanded(
              child:
                  _buildToggleButtonTablet("Non", _hasSpecialDiet == false, () {
                setState(() {
                  _hasSpecialDiet = false;
                  _specialDietController.clear();
                });
              }, maxWidth, maxHeight),
            ),
          ],
        ),
        if (_hasSpecialDiet == true) ...[
          SizedBox(height: maxHeight * 0.03),
          _buildTextFieldTablet(
            "Précisez le régime (halal, kasher, sans gluten, etc.)",
            _specialDietController,
            maxWidth,
            maxHeight,
            maxLines: 3,
            hintText: "Ex: Sans gluten, Végétarien, Halal...",
          ),
        ],
      ],
    );
  }

  Widget _buildToggleButtonTablet(String label, bool isSelected,
      VoidCallback onTap, double maxWidth, double maxHeight) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: (maxHeight * 0.02).clamp(10.0, 18.0)),
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
              fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldTablet(
    String label,
    TextEditingController controller,
    double maxWidth,
    double maxHeight, {
    int maxLines = 1,
    String? hintText,
  }) {
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
        maxLines: maxLines,
        onChanged: (value) => setState(() {}), // Pour rafraîchir l'aperçu
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
          ),
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
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: (maxWidth * 0.014).clamp(10.0, 16.0),
          ),
        ),
        style: TextStyle(fontSize: (maxWidth * 0.018).clamp(14.0, 20.0)),
      ),
    );
  }

  // Méthode pour sauvegarder les informations alimentaires
  Future<void> _saveMealInfo() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String currentUserEmail = user?.email?.toLowerCase() ?? '';
    // Vérifications des champs
    if (_hasFoodAllergies == true && _foodAllergiesController.text.isEmpty) {
      _showError("Veuillez préciser les allergies alimentaires");
      return;
    }

    if (_hasSpecialDiet == true && _specialDietController.text.isEmpty) {
      _showError("Veuillez préciser le régime alimentaire spécial");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
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

      // Mise à jour dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .update({
        'mealInfo': {
          'hasFoodAllergies': _hasFoodAllergies,
          'foodAllergiesDescription':
              _hasFoodAllergies == true ? _foodAllergiesController.text : '',
          'hasSpecialDiet': _hasSpecialDiet,
          'specialDietDescription':
              _hasSpecialDiet == true ? _specialDietController.text : '',
        },
        'lastUpdatedBy': currentUserEmail,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      print("Informations alimentaires sauvegardées avec succès");

      if (mounted) {
        // Redirection vers l'écran de configuration financière
        context.go('/child-financial-info', extra: widget.childId);
      }
    } catch (e) {
      print("Erreur lors de la sauvegarde des informations alimentaires: $e");
      _showError("Une erreur est survenue lors de la sauvegarde");
    } finally {
      setState(() => _isSaving = false);
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
                      Icons.restaurant_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Alimentation',
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
              'assets/images/Icone_Ajout_Enfant.png',
              width: 50,
              height: 50,
            ),
            label: "Ajouter",
          ),
        ],
      ),
    );
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
                        // Back button - CORRECTION ICI
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            // CORRECTION : Utiliser context.go au lieu de Navigator.pop
                            if (widget.childId.isNotEmpty) {
                              print(
                                  "🔄 Retour vers child-pickup-auth avec childId: ${widget.childId}");
                              context.go('/child-pickup-auth',
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

                        // Food Allergies Section
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
                                        Icons.restaurant_menu,
                                        color: primaryBlue,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Informations alimentaires",
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
                                  "Ces informations sont importantes pour garantir la sécurité et le bien-être de l'enfant pendant les repas.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Allergies alimentaires
                                Text(
                                  "L'enfant a-t-il des allergies alimentaires ?",
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
                                          "Oui", _hasFoodAllergies == true, () {
                                        setState(
                                            () => _hasFoodAllergies = true);
                                      }),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildToggleButton(
                                          "Non", _hasFoodAllergies == false,
                                          () {
                                        setState(() {
                                          _hasFoodAllergies = false;
                                          _foodAllergiesController.clear();
                                        });
                                      }),
                                    ),
                                  ],
                                ),

                                if (_hasFoodAllergies == true) ...[
                                  const SizedBox(height: 20),
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
                                      controller: _foodAllergiesController,
                                      decoration: InputDecoration(
                                        labelText:
                                            "Précisez les allergies alimentaires",
                                        labelStyle: TextStyle(
                                            color: Colors.grey.shade600),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: primaryBlue, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                      maxLines: 3,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Régime alimentaire section
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
                                        Icons.food_bank_rounded,
                                        color: primaryBlue,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Régime alimentaire",
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
                                  "L'enfant suit-il un régime alimentaire spécifique ?",
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
                                          "Oui", _hasSpecialDiet == true, () {
                                        setState(() => _hasSpecialDiet = true);
                                      }),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildToggleButton(
                                          "Non", _hasSpecialDiet == false, () {
                                        setState(() {
                                          _hasSpecialDiet = false;
                                          _specialDietController.clear();
                                        });
                                      }),
                                    ),
                                  ],
                                ),
                                if (_hasSpecialDiet == true) ...[
                                  const SizedBox(height: 20),
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
                                      controller: _specialDietController,
                                      decoration: InputDecoration(
                                        labelText:
                                            "Précisez le régime (halal, kasher, sans gluten, etc.)",
                                        labelStyle: TextStyle(
                                            color: Colors.grey.shade600),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: primaryBlue, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        hintText:
                                            "Ex: Sans gluten, Végétarien, Halal...",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                      maxLines: 3,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Continue button
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveMealInfo,
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
                                        "Continuer",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward,
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
}
