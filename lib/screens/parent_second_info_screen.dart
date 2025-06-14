import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ParentSecondInfoScreen extends StatefulWidget {
  final String childId;

  const ParentSecondInfoScreen({Key? key, required this.childId})
      : super(key: key);

  @override
  _ParentSecondInfoScreenState createState() => _ParentSecondInfoScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

String structureName = "Chargement...";
bool isLoadingStructure = true;

class _ParentSecondInfoScreenState extends State<ParentSecondInfoScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? errorMessage;
  bool _isLoading = false;
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
    // AJOUT : Charger les infos de structure
    _loadStructureInfo();
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

  Future<void> _loadStructureInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoadingStructure = false);
        return;
      }

      // Récupérer l'email de l'utilisateur actuel
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      // Vérifier si l'utilisateur est un membre MAM
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
              "🔄 Parent Second Info: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // Récupération des informations de la structure avec l'ID correct
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
      } else {
        setState(() {
          structureName = 'Structure inconnue';
          isLoadingStructure = false;
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des infos de structure: $e");
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
            // Panneau gauche - Aperçu des informations du deuxième parent
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

                      // Aperçu des informations du deuxième parent
                      Expanded(
                        child: Container(
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
                              // Titre
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
                                      Icons.people,
                                      color: primaryBlue,
                                      size: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    ),
                                  ),
                                  SizedBox(
                                      width:
                                          (maxWidth * 0.01).clamp(6.0, 12.0)),
                                  Flexible(
                                    child: Text(
                                      "Parent 2",
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

                              // Prénom
                              _buildInfoRowTablet(
                                  "Prénom",
                                  _firstNameController.text.isEmpty
                                      ? "Non renseigné"
                                      : _firstNameController.text,
                                  maxWidth),
                              SizedBox(
                                  height: maxHeight *
                                      0.03), // Augmenté de 0.02 à 0.03

// Nom
                              _buildInfoRowTablet(
                                  "Nom",
                                  _lastNameController.text.isEmpty
                                      ? "Non renseigné"
                                      : _lastNameController.text,
                                  maxWidth),
                              SizedBox(
                                  height: maxHeight *
                                      0.03), // Augmenté de 0.02 à 0.03

// Email
                              _buildInfoRowTablet(
                                  "Email",
                                  _emailController.text.isEmpty
                                      ? "Non renseigné"
                                      : _emailController.text,
                                  maxWidth),
                              SizedBox(
                                  height: maxHeight *
                                      0.03), // Augmenté de 0.02 à 0.03

// Téléphone
                              _buildInfoRowTablet(
                                  "Téléphone",
                                  _phoneController.text.isEmpty
                                      ? "Non renseigné"
                                      : _phoneController.text,
                                  maxWidth),

                              // Message d'erreur s'il y en a une
                              if (errorMessage != null) ...[
                                SizedBox(height: maxHeight * 0.03),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(
                                      (maxWidth * 0.015).clamp(10.0, 15.0)),
                                  decoration: BoxDecoration(
                                    color: primaryRed.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: primaryRed),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: primaryRed,
                                        size: (maxWidth * 0.018)
                                            .clamp(16.0, 20.0),
                                      ),
                                      SizedBox(width: maxWidth * 0.01),
                                      Expanded(
                                        child: Text(
                                          errorMessage!,
                                          style: TextStyle(
                                            color: primaryRed,
                                            fontWeight: FontWeight.w500,
                                            fontSize: (maxWidth * 0.015)
                                                .clamp(12.0, 16.0),
                                          ),
                                        ),
                                      ),
                                    ],
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
                        "Informations parent 2",
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
                                Icons.info_outline,
                                color: primaryBlue,
                                size: (maxWidth * 0.02).clamp(16.0, 24.0),
                              ),
                            ),
                            SizedBox(
                                width: (maxWidth * 0.015).clamp(8.0, 15.0)),
                            Expanded(
                              child: Text(
                                "Veuillez renseigner les informations du deuxième parent",
                                style: TextStyle(
                                  fontSize:
                                      (maxWidth * 0.016).clamp(12.0, 18.0),
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Champs de saisie
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildTextFieldTablet(
                                  "Prénom",
                                  _firstNameController,
                                  Icons.person,
                                  maxWidth,
                                  maxHeight),
                              SizedBox(height: maxHeight * 0.03),
                              _buildTextFieldTablet("Nom", _lastNameController,
                                  Icons.person_outline, maxWidth, maxHeight),
                              SizedBox(height: maxHeight * 0.03),
                              _buildTextFieldTablet("Email", _emailController,
                                  Icons.email, maxWidth, maxHeight,
                                  inputType: TextInputType.emailAddress),
                              SizedBox(height: maxHeight * 0.03),
                              _buildTextFieldTablet(
                                  "Numéro de téléphone",
                                  _phoneController,
                                  Icons.phone,
                                  maxWidth,
                                  maxHeight,
                                  inputType: TextInputType.phone,
                                  maxLength: 10,
                                  onlyNumbers: true),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.03),

                      // Boutons d'action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Bouton Retour
                          Container(
                            width: (maxWidth * 0.12).clamp(150.0, 200.0),
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.arrow_back,
                                  color: primaryBlue,
                                  size: (maxWidth * 0.018).clamp(16.0, 22.0)),
                              label: Text(
                                "Retour",
                                style: TextStyle(
                                  fontSize:
                                      (maxWidth * 0.018).clamp(14.0, 18.0),
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      if (widget.childId.isNotEmpty) {
                                        print(
                                            "🔄 Retour vers add-second-parent avec childId: ${widget.childId}");
                                        context.go('/add-second-parent',
                                            extra: widget.childId);
                                      } else {
                                        _showError(
                                            "Erreur : ID d'enfant manquant !");
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: lightBlue,
                                foregroundColor: primaryBlue,
                                padding: EdgeInsets.symmetric(
                                    horizontal:
                                        (maxWidth * 0.02).clamp(15.0, 25.0),
                                    vertical:
                                        (maxHeight * 0.02).clamp(12.0, 18.0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),

                          SizedBox(width: (maxWidth * 0.02).clamp(15.0, 25.0)),

                          // Bouton Suivant
                          Container(
                            width: (maxWidth * 0.18).clamp(220.0, 280.0),
                            child: ElevatedButton.icon(
                              icon: _isLoading
                                  ? SizedBox(
                                      width:
                                          (maxWidth * 0.018).clamp(16.0, 22.0),
                                      height:
                                          (maxWidth * 0.018).clamp(16.0, 22.0),
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Icon(Icons.arrow_forward,
                                      color: Colors.white,
                                      size:
                                          (maxWidth * 0.018).clamp(16.0, 22.0)),
                              label: Text(
                                "Suivant",
                                style: TextStyle(
                                  fontSize:
                                      (maxWidth * 0.018).clamp(14.0, 18.0),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed:
                                  _isLoading ? null : _validateAndProceed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal:
                                        (maxWidth * 0.025).clamp(20.0, 35.0),
                                    vertical:
                                        (maxHeight * 0.02).clamp(12.0, 18.0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 3,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildTextFieldTablet(String label, TextEditingController controller,
      IconData icon, double maxWidth, double maxHeight,
      {TextInputType inputType = TextInputType.text,
      int? maxLength,
      bool onlyNumbers = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
            keyboardType: inputType,
            maxLength: maxLength,
            inputFormatters:
                onlyNumbers ? [FilteringTextInputFormatter.digitsOnly] : [],
            onChanged: (value) => setState(() {}), // Pour rafraîchir l'aperçu
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: primaryBlue),
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: (maxWidth * 0.02).clamp(12.0, 20.0),
                vertical: (maxHeight * 0.02).clamp(12.0, 20.0),
              ),
              hintStyle: TextStyle(color: Colors.grey.shade500),
              counterText: "",
            ),
            style: TextStyle(fontSize: (maxWidth * 0.018).clamp(14.0, 20.0)),
          ),
        ),
      ],
    );
  }

  Future<void> _validateAndProceed() async {
    setState(() {
      errorMessage = null;
    });

    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String email = _emailController.text.trim().toLowerCase();
    String phone = _phoneController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty) {
      _showError("Tous les champs sont obligatoires.");
      return;
    }

    if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
        .hasMatch(email)) {
      _showError("Veuillez entrer un email valide.");
      return;
    }

    if (!RegExp(r"^\d{10}$").hasMatch(phone)) {
      _showError(
          "Le numéro de téléphone doit contenir exactement 10 chiffres.");
      return;
    }

    setState(() => _isLoading = true);
    print("🔍 Vérification de l'email: $email");

    try {
      // Vérifier si l'email existe déjà dans la collection 'users'
      final userDocSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(email).get();

      if (userDocSnapshot.exists) {
        final userData = userDocSnapshot.data() ?? {};
        print("📋 Email trouvé dans users avec rôle: ${userData['role']}");

        if (userData['role'] == 'assmat' || userData['role'] == 'mamMember') {
          _showError(
              "Cet email est déjà utilisé par un professionnel. Veuillez en utiliser un autre.");
          setState(() => _isLoading = false);
          return;
        }
      }

      // Vérifier si l'email est celui de l'utilisateur connecté
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("Erreur : Utilisateur non connecté !");
        setState(() => _isLoading = false);
        return;
      }

      final userEmail = user.email?.toLowerCase() ?? '';
      if (userEmail == email) {
        _showError(
            "Vous ne pouvez pas utiliser votre propre email comme email du parent. Veuillez en utiliser un autre.");
        setState(() => _isLoading = false);
        return;
      }

      // Identifier la structure à utiliser
      String structureId = user.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          structureId = userData['structureId'];
          print(
              "🔄 Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // Vérifier si l'email est déjà utilisé pour un autre enfant dans la même structure
      final childrenCollection = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children');
      final childrenSnapshot = await childrenCollection.get();

      for (var doc in childrenSnapshot.docs) {
        if (doc.id == widget.childId) continue;

        final childData = doc.data();

        if (childData['parent1'] != null &&
            childData['parent1']['email'] != null &&
            childData['parent1']['email'].toString().toLowerCase() == email) {
          _showError(
              "Cet email est déjà utilisé pour un autre parent dans votre structure.");
          setState(() => _isLoading = false);
          return;
        }

        if (childData['parent2'] != null &&
            childData['parent2']['email'] != null &&
            childData['parent2']['email'].toString().toLowerCase() == email) {
          _showError(
              "Cet email est déjà utilisé pour un autre parent dans votre structure.");
          setState(() => _isLoading = false);
          return;
        }
      }

      // Vérifier si cet email est déjà utilisé pour le premier parent de cet enfant
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .get();

      if (childDoc.exists) {
        final childData = childDoc.data() ?? {};
        final parent1Data = childData['parent1'] ?? {};

        if (parent1Data['email'] != null &&
            parent1Data['email'].toString().toLowerCase() == email) {
          _showError(
              "Cet email est déjà utilisé pour le premier parent. Veuillez en utiliser un autre.");
          setState(() => _isLoading = false);
          return;
        }
      }

      // Rechercher dans toutes les structures si l'email est utilisé pour un professionnel
      final structuresSnapshot =
          await FirebaseFirestore.instance.collection('structures').get();
      for (var structureDoc in structuresSnapshot.docs) {
        final structureData = structureDoc.data();
        if (structureData['ownerEmail']?.toString().toLowerCase() == email) {
          _showError(
              "Cet email est déjà utilisé par un professionnel. Veuillez en utiliser un autre.");
          setState(() => _isLoading = false);
          return;
        }

        if (structureData['type'] == 'mam' &&
            structureData['members'] != null) {
          final List<dynamic> members = structureData['members'] ?? [];
          for (var member in members) {
            if (member['email']?.toString().toLowerCase() == email) {
              _showError(
                  "Cet email est déjà utilisé par un membre MAM. Veuillez en utiliser un autre.");
              setState(() => _isLoading = false);
              return;
            }
          }
        }
      }

      print("✅ Email validé avec succès: $email");

      // Sauvegarder les infos du deuxième parent dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .update({
        'parent2': {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
        }
      });

      print(
          "✅ Infos du deuxième parent sauvegardées. Redirection vers schedule-info avec childId: ${widget.childId}");

      if (mounted) {
        context.go('/parent-second-address', extra: widget.childId);
      }
    } catch (e) {
      print(
          "❌ Erreur lors de la validation ou de la sauvegarde du deuxième parent: $e");
      _showError("Une erreur est survenue lors de la sauvegarde");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            if (widget.childId.isNotEmpty) {
                              print(
                                  "🔄 Retour vers add-second-parent avec childId: ${widget.childId}");
                              context.go('/add-second-parent',
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
                                        Icons.people,
                                        color: primaryBlue,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Informations parent 2",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: primaryBlue,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Veuillez renseigner les informations du deuxième parent :",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        _buildTextField(
                            "Prénom", _firstNameController, Icons.person),
                        _buildTextField(
                            "Nom", _lastNameController, Icons.person_outline),
                        _buildTextField("Email", _emailController, Icons.email,
                            inputType: TextInputType.emailAddress),
                        _buildTextField("Numéro de téléphone", _phoneController,
                            Icons.phone,
                            inputType: TextInputType.phone,
                            maxLength: 10,
                            onlyNumbers: true),
                        if (errorMessage != null)
                          Container(
                            margin: EdgeInsets.only(top: 15),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: primaryRed),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline, color: primaryRed),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      color: primaryRed,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildSecondaryButton(
                                text: "Retour",
                                icon: Icons.arrow_back,
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        if (widget.childId.isNotEmpty) {
                                          print(
                                              "🔄 Retour vers add-second-parent avec childId: ${widget.childId}");
                                          context.go('/add-second-parent',
                                              extra: widget.childId);
                                        } else {
                                          _showError(
                                              "Erreur : ID d'enfant manquant !");
                                        }
                                      },
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              flex: 2,
                              child: _buildButton(
                                text: "Suivant",
                                icon: Icons.arrow_forward,
                                onPressed:
                                    _isLoading ? null : _validateAndProceed,
                                color: primaryBlue,
                                isLoading: _isLoading,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 60),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {TextInputType inputType = TextInputType.text,
      int? maxLength,
      bool onlyNumbers = false}) {
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
            keyboardType: inputType,
            maxLength: maxLength,
            inputFormatters:
                onlyNumbers ? [FilteringTextInputFormatter.digitsOnly] : [],
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: primaryBlue),
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
              counterText: "",
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
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
                      structureName, // CHANGEMENT : utiliser structureName au lieu de "Poppins"
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
                      Icons.people,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Parent 2',
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

  Widget _buildButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(icon, color: Colors.white, size: 22),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: primaryBlue, size: 22),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: lightBlue,
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  void _showError(String message) {
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
}
