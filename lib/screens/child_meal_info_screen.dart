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
  }

  @override
  void dispose() {
    _foodAllergiesController.dispose();
    _specialDietController.dispose();
    super.dispose();
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
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      context.go('/dashboard');
    } else if (index == 1) {
      context.go('/home');
    } else if (index == 2) {
      // Déjà sur cette page
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
                      "Poppins",
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
                      '09 - Alimentation',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
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
                                  "Informations sur l'alimentation",
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
                                  setState(() => _hasFoodAllergies = true);
                                }),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildToggleButton(
                                    "Non", _hasFoodAllergies == false, () {
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
                                  labelStyle:
                                      TextStyle(color: Colors.grey.shade600),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primaryBlue, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
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
                                  labelStyle:
                                      TextStyle(color: Colors.grey.shade600),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primaryBlue, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
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
                                Icon(Icons.arrow_forward, color: Colors.white),
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
