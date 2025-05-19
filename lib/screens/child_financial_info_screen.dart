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

class _ChildFinancialInfoScreenState extends State<ChildFinancialInfoScreen> {
  // Variables pour le tableau mensuel
  bool? _useMonthlyTable = null;
  final TextEditingController _monthlySalaryController =
      TextEditingController();
  final TextEditingController _careExpensesController = TextEditingController();
  final TextEditingController _mealExpensesController = TextEditingController();
  final TextEditingController _kmExpensesController = TextEditingController();

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
    _monthlySalaryController.dispose();
    _careExpensesController.dispose();
    _mealExpensesController.dispose();
    _kmExpensesController.dispose();
    super.dispose();
  }

  // Méthode pour sauvegarder les informations financières
  Future<void> _saveFinancialInfo() async {
    // Si on n'utilise pas le tableau mensuel, on retourne directement à l'accueil
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
          'careExpenses': double.tryParse(
                  _careExpensesController.text.replaceAll(',', '.')) ??
              0,
          'mealExpenses': double.tryParse(
                  _mealExpensesController.text.replaceAll(',', '.')) ??
              0,
          'kmExpenses': double.tryParse(
                  _kmExpensesController.text.replaceAll(',', '.')) ??
              0,
        },
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
                      Icons.monetization_on_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '10 - Tableau mensuel',
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
                                  "Configuration du tableau mensuel",
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
                            "Le tableau mensuel permet de suivre automatiquement la facturation et de générer des récapitulatifs mensuels.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Question
                          Text(
                            "Souhaitez-vous utiliser le tableau mensuel ?",
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
                                  setState(() => _useMonthlyTable = false);
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Détails du tableau mensuel
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
                                    "Informations financières",
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
                              "Salaire net mensuel :",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildCurrencyTextField(
                                _monthlySalaryController, "Montant en €", "€"),

                            const SizedBox(height: 20),

                            // Frais d'entretien
                            Text(
                              "Frais d'entretien par jour :",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildCurrencyTextField(_careExpensesController,
                                "Montant en €", "€/jour"),

                            const SizedBox(height: 20),

                            // Frais de repas
                            Text(
                              "Frais de repas par jour :",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildCurrencyTextField(_mealExpensesController,
                                "Montant en €", "€/jour"),

                            const SizedBox(height: 20),

                            // Frais kilométriques
                            Text(
                              "Frais kilométriques par km :",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildCurrencyTextField(
                                _kmExpensesController, "Montant en €", "€/km"),
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
                      border: Border.all(color: primaryBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: primaryBlue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Une invitation sera automatiquement envoyée aux parents par email pour accéder à l'application Poppins.",
                            style: TextStyle(color: primaryBlue, fontSize: 14),
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
                      onPressed:
                          _useMonthlyTable == null ? null : _saveFinancialInfo,
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
