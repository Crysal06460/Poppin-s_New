import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_scaffold.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class ChildInfoScreen extends StatefulWidget {
  @override
  _ChildInfoScreenState createState() => _ChildInfoScreenState();
}

class _ChildInfoScreenState extends State<ChildInfoScreen> {
  String gender = "";
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController birthDateController = TextEditingController();
  DateTime? selectedDate;
  int _selectedIndex = 2; // Pour la barre de navigation du bas

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    // Initialize the French date locale
    initializeDateFormatting('fr_FR', null);

    DateTime now = DateTime.now();

    final ThemeData theme = Theme.of(context);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      // Set locale to French
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
              surface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
              ),
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 12,
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.0),
            ),
            child: child!,
          ),
        );
      },
      helpText: "Date de naissance",
      cancelText: "ANNULER",
      confirmText: "CONFIRMER",
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        birthDateController.text =
            DateFormat('dd MMMM yyyy', 'fr_FR').format(picked);
      });
    }
  }

  Future<void> _saveChildInfo() async {
    if (gender.isEmpty ||
        firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        selectedDate == null) {
      _showErrorSnackBar("Merci de remplir tous les champs");
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Afficher un indicateur de chargement
    _showLoadingDialog("Enregistrement en cours...");

    try {
      // Récupérer l'email de l'utilisateur actuel (crucial pour l'assignation)
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      // Déterminer l'ID de structure correct à utiliser
      String structureId =
          user.uid; // Par défaut, utiliser l'UID de l'utilisateur

      // Vérifier si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // C'est un membre MAM, utiliser structureId au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "👤 Utilisateur identifié comme membre MAM pour la structure: $structureId");
        }
      }

      // Récupérer la structure associée à l'utilisateur
      DocumentSnapshot structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (!structureDoc.exists) {
        // Fermer le dialogue de chargement avant d'afficher l'erreur
        Navigator.of(context).pop();
        _showErrorSnackBar("Erreur : structure non trouvée.");
        return;
      }

      // Ajouter l'enfant sous `structures/{structureId}/children`
      DocumentReference newChildRef = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .add({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'gender': gender,
        'birthdate': selectedDate!.toIso8601String(),
        'createdAt': Timestamp.now(),

        // CRUCIAL: Ajouter ces champs pour l'assignation correcte du membre
        'assignedMemberEmail': currentUserEmail,
        'createdByEmail': currentUserEmail,
        'lastUpdatedBy': currentUserEmail,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      String childId = newChildRef.id;
      print("✅ Enfant créé et assigné au membre: $currentUserEmail");

      // Fermer le dialogue de chargement
      if (context.mounted) Navigator.of(context).pop();

      // Redirection vers parent-info avec l'ID de l'enfant
      if (context.mounted) {
        context.go('/parent-info', extra: childId);
      }
    } catch (e) {
      // Fermer le dialogue de chargement en cas d'erreur
      if (context.mounted) Navigator.of(context).pop();
      _showErrorSnackBar("Une erreur est survenue lors de l'enregistrement");
      print("❌ Erreur lors de la création de l'enfant: $e");
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryBlue),
                SizedBox(width: 20),
                Text(message),
              ],
            ),
          ),
        );
      },
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
  void initState() {
    super.initState();
    // Initialize date formatting for French locale
    initializeDateFormatting('fr_FR', null);
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      context.go('/home');
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: lightBlue,
                      foregroundColor: primaryBlue,
                      padding: EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGenderButton("Fille", Icons.female, primaryRed),
                      const SizedBox(width: 30),
                      _buildGenderButton("Garçon", Icons.male, primaryBlue),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildTextField("Prénom", firstNameController),
                  _buildTextField("Nom", lastNameController),

                  // Champ de date amélioré
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        "Date de naissance",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedDate != null
                                  ? primaryBlue
                                  : Colors.grey.shade300,
                              width: selectedDate != null ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                            boxShadow: selectedDate != null
                                ? [
                                    BoxShadow(
                                      color: primaryBlue.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: selectedDate != null
                                      ? lightBlue
                                      : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.calendar_today_rounded,
                                  color: selectedDate != null
                                      ? primaryBlue
                                      : Colors.grey,
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                selectedDate != null
                                    ? birthDateController.text
                                    : "Choisir une date de naissance",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: selectedDate != null
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                                ),
                              ),
                              Spacer(),
                              if (selectedDate != null)
                                Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: lightBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    color: primaryBlue,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),
                  Center(
                    child: _buildButton(
                      text: "Suivant",
                      icon: Icons.arrow_forward,
                      onPressed: _saveChildInfo,
                      color: primaryBlue,
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

  Widget _buildTextField(String label, TextEditingController controller,
      {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
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
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              prefixIcon: icon != null ? Icon(icon, color: primaryBlue) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryBlue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderButton(String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          gender = label;
        });
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: gender == label
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.7),
                        color,
                      ],
                    )
                  : null,
              color: gender == label ? null : Colors.grey.shade200,
              shape: BoxShape.circle,
              boxShadow: gender == label
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              size: 55,
              color: gender == label ? Colors.white : Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: gender == label ? FontWeight.bold : FontWeight.w500,
              color: gender == label ? color : Colors.black87,
            ),
          ),
        ],
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
                    Image.asset(
                      'assets/images/Icone_Ajout_Enfant.png',
                      width: 30,
                      height: 30,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.child_care_rounded,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ajouter un enfant',
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
    return BottomNavigationBar(
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: primaryBlue,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      items: [
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Dashboard.png',
            width: 60,
            height: 60,
          ),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/maison_icon.png',
            width: 60,
            height: 60,
          ),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Ajout_Enfant.png',
            width: 60,
            height: 60,
          ),
          label: "Ajouter",
        ),
      ],
    );
  }

  Widget _buildButton(
      {required String text,
      required IconData icon,
      required VoidCallback onPressed,
      required Color color}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
      ),
    );
  }
}
