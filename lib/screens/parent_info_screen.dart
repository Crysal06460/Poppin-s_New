import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ParentInfoScreen extends StatefulWidget {
  final String childId;

  const ParentInfoScreen({Key? key, required this.childId}) : super(key: key);

  @override
  _ParentInfoScreenState createState() => _ParentInfoScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

// ✅ AJOUT : Fonction de validation d'email
bool _isValidEmail(String email) {
  // Expression régulière pour valider l'email
  final emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  return emailRegExp.hasMatch(email.trim());
}

String structureName = "Chargement...";
bool isLoadingStructure = true;

class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String newText = newValue.text[0].toUpperCase() +
        (newValue.text.length > 1 ? newValue.text.substring(1) : '');

    return TextEditingValue(
      text: newText,
      selection: newValue.selection,
    );
  }
}

class CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String newText = newValue.text
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() +
                (word.length > 1 ? word.substring(1).toLowerCase() : ''))
        .join(' ');

    return TextEditingValue(
      text: newText,
      selection: newValue.selection,
    );
  }
}

class _ParentInfoScreenState extends State<ParentInfoScreen> {
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
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
    // Initialize date formatting for French locale
    initializeDateFormatting('fr_FR', null);
    // AJOUT : Charger les infos de structure
    _loadStructureInfo();
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
              "🔄 Parent Info: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
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
            // Panneau gauche - Aperçu des informations parent
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
                      // Titre du panneau - CORRIGÉ
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
                            // AJOUT d'Expanded ici pour éviter l'overflow
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

                      // Aperçu des informations du parent
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
                              // Titre - CORRIGÉ
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
                                      Icons.person_outline,
                                      color: primaryBlue,
                                      size: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    ),
                                  ),
                                  SizedBox(
                                      width:
                                          (maxWidth * 0.01).clamp(6.0, 12.0)),
                                  Flexible(
                                    // CHANGÉ de Text à Flexible
                                    child: Text(
                                      "Informations parent 1",
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
                                  firstNameController.text.isEmpty
                                      ? "Non renseigné"
                                      : firstNameController.text,
                                  maxWidth),
                              SizedBox(
                                  height: maxHeight *
                                      0.03), // Augmenté de 0.02 à 0.03

// Nom
                              _buildInfoRowTablet(
                                  "Nom",
                                  lastNameController.text.isEmpty
                                      ? "Non renseigné"
                                      : lastNameController.text,
                                  maxWidth),
                              SizedBox(
                                  height: maxHeight *
                                      0.03), // Augmenté de 0.02 à 0.03

// Email
                              _buildInfoRowTablet(
                                  "Email",
                                  emailController.text.isEmpty
                                      ? "Non renseigné"
                                      : emailController.text,
                                  maxWidth),
                              SizedBox(
                                  height: maxHeight *
                                      0.03), // Augmenté de 0.02 à 0.03

// Téléphone
                              _buildInfoRowTablet(
                                  "Téléphone",
                                  phoneController.text.isEmpty
                                      ? "Non renseigné"
                                      : phoneController.text,
                                  maxWidth),
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
                        "Informations parent 1",
                        style: TextStyle(
                          fontSize: (maxWidth * 0.025).clamp(18.0, 28.0),
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      // Description - CORRIGÉ
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
                              // AJOUT d'Expanded ici aussi
                              child: Text(
                                "Veuillez renseigner les informations du parent",
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
                                  firstNameController,
                                  Icons.person,
                                  maxWidth,
                                  maxHeight,
                                  shouldCapitalize: true,
                                  capitalizeWords: true),
                              SizedBox(height: maxHeight * 0.03),
                              _buildTextFieldTablet("Nom", lastNameController,
                                  Icons.person_outline, maxWidth, maxHeight,
                                  shouldCapitalize: true,
                                  capitalizeWords: true),
                              SizedBox(height: maxHeight * 0.03),
                              _buildTextFieldTablet("Email", emailController,
                                  Icons.email, maxWidth, maxHeight,
                                  inputType: TextInputType.emailAddress),
                              SizedBox(height: maxHeight * 0.03),
                              _buildTextFieldTablet(
                                  "Numéro de téléphone",
                                  phoneController,
                                  Icons.phone,
                                  maxWidth,
                                  maxHeight,
                                  inputType: TextInputType.number,
                                  maxLength: 10,
                                  onlyNumbers: true),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.03),

                      // Bouton Suivant
                      Center(
                        child: Container(
                          width: (maxWidth * 0.25).clamp(200.0, 300.0),
                          child: ElevatedButton.icon(
                            icon: _isLoading
                                ? SizedBox(
                                    width: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    height: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Icon(Icons.arrow_forward,
                                    color: Colors.white,
                                    size: (maxWidth * 0.02).clamp(16.0, 24.0)),
                            label: Text(
                              "Suivant",
                              style: TextStyle(
                                fontSize: (maxWidth * 0.02).clamp(14.0, 20.0),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: _isLoading ? null : _saveParentInfo,
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

  Future<void> _cleanupFirebaseData() async {
    if (widget.childId.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String currentUserEmail = user.email?.toLowerCase() ?? '';
      String structureId = user.uid;

      // Vérifier si utilisateur MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          structureId = userData['structureId'];
        }
      }

      // Supprimer complètement l'enfant de Firebase
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .delete();

      print("Enfant supprimé de Firebase : ${widget.childId}");
    } catch (e) {
      print("Erreur lors du nettoyage Firebase: $e");
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

  Future<void> _showExitWarning(
      BuildContext context, String destination) async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_rounded, color: primaryRed, size: 24),
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
              style:
                  TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Annuler",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Quitter",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      await _cleanupFirebaseData(); // NETTOYER Firebase avant de quitter
      if (context.mounted) {
        context.go(destination);
      }
    }
  }

  Widget _buildTextFieldTablet(String label, TextEditingController controller,
      IconData icon, double maxWidth, double maxHeight,
      {TextInputType inputType = TextInputType.text,
      int? maxLength,
      bool onlyNumbers = false,
      bool shouldCapitalize = false, // Nouveau paramètre
      bool capitalizeWords = false}) {
    // Nouveau paramètre

    // Construction de la liste des formatters
    List<TextInputFormatter> formatters = [];

    if (onlyNumbers) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    } else if (shouldCapitalize) {
      if (capitalizeWords) {
        formatters.add(CapitalizeWordsFormatter());
      } else {
        formatters.add(CapitalizeFirstLetterFormatter());
      }
    }

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
            inputFormatters: formatters, // Utiliser la liste des formatters
            onChanged: (value) => setState(() {}),
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

  /// ✅ Vérification et sauvegarde dans Firestore
  Future<void> _saveParentInfo() async {
    // Afficher un indicateur de chargement
    setState(() {
      _isLoading = true;
    });

    // ✅ AJOUT : Validation des champs obligatoires
    if (firstNameController.text.trim().isEmpty ||
        lastNameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      _showError("Merci de remplir tous les champs.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // ✅ AJOUT : Validation du format d'email
    if (!_isValidEmail(emailController.text.trim())) {
      _showError(
          "Veuillez saisir une adresse email valide (ex: exemple@gmail.com).");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // ✅ AJOUT : Validation de la longueur du téléphone
    if (phoneController.text.trim().length != 10) {
      _showError(
          "Le numéro de téléphone doit contenir exactement 10 chiffres.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Récupérer l'email saisi et le normaliser
    final String normalizedEmail = emailController.text.trim().toLowerCase();

    if (widget.childId.isEmpty) {
      _showError("Erreur : ID d'enfant manquant !");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("Erreur : Utilisateur non authentifié !");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      print("🔍 Vérification si l'email $normalizedEmail existe déjà...");

      // Vérifier si l'email existe déjà dans la collection 'users'
      final userDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(normalizedEmail)
          .get();

      if (userDocSnapshot.exists) {
        final userData = userDocSnapshot.data() ?? {};
        final String userRole = userData['role'] ?? '';

        print("📧 Email trouvé dans users avec le rôle: $userRole");

        // Vérifier si c'est un utilisateur avec le rôle 'assmat' ou 'mamMember'
        if (userRole == 'assmat' || userRole == 'mamMember') {
          _showError(
              "Cet email est déjà utilisé par un professionnel ($userRole). Veuillez en utiliser un autre.");
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else {
        print("📧 Email non trouvé dans users collection.");
      }

      // Vérification supplémentaire - Rechercher dans toutes les structures
      // pour voir si cet email est utilisé comme compte pro
      final structuresQuery =
          await FirebaseFirestore.instance.collection('structures').get();

      for (var structureDoc in structuresQuery.docs) {
        if (structureDoc.id.toLowerCase() == normalizedEmail) {
          print("⚠️ Email trouvé comme ID de structure: ${structureDoc.id}");
          _showError(
              "Cet email est déjà utilisé comme compte professionnel. Veuillez en utiliser un autre.");
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Vérifier si l'utilisateur connecté utilise cet email
      if (user.email?.toLowerCase() == normalizedEmail) {
        print(
            "⚠️ L'email saisi est le même que celui de l'utilisateur connecté");
        _showError(
            "Vous ne pouvez pas utiliser votre propre email pour un parent. Veuillez saisir l'email du parent.");
        setState(() {
          _isLoading = false;
        });
        return;
      }

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

      print(
          "✅ Sauvegarde des informations du parent avec l'email: $normalizedEmail");

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .update({
        'parent1': {
          'firstName': firstNameController.text.trim(),
          'lastName': lastNameController.text.trim(),
          'email': normalizedEmail,
          'phone': phoneController.text.trim(),
        }
      });

      print(
          "✅ Infos du parent enregistrées. Redirection vers parent-address avec childId: ${widget.childId}");
      if (mounted) {
        context.go('/parent-address', extra: widget.childId);
      }
    } catch (e) {
      print("❌ Erreur Firestore: $e");
      _showError("Une erreur est survenue. Veuillez réessayer.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    print("🛠️ DEBUG: ParentInfoScreen - childId reçu: ${widget.childId}");

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
                          onPressed: () => _showExitWarning(context, '/home'),
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
                                        Icons.person_outline,
                                        color: primaryBlue,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Informations parent 1",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Veuillez renseigner les informations du parent :",
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
                            "Prénom", firstNameController, Icons.person,
                            shouldCapitalize: true, capitalizeWords: true),
                        _buildTextField(
                            "Nom", lastNameController, Icons.person_outline,
                            shouldCapitalize: true, capitalizeWords: true),
                        _buildTextField("Email", emailController, Icons.email,
                            inputType: TextInputType.emailAddress),
                        _buildTextField(
                            "Numéro de téléphone", phoneController, Icons.phone,
                            inputType: TextInputType.number,
                            maxLength: 10,
                            onlyNumbers: true),
                        SizedBox(height: 40),
                        Center(
                          child: _buildButton(
                            text: "Suivant",
                            icon: Icons.arrow_forward,
                            onPressed: _isLoading ? null : _saveParentInfo,
                            color: primaryBlue,
                            isLoading: _isLoading,
                          ),
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

  /// ✅ Fonction pour afficher un message d'erreur
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

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {TextInputType inputType = TextInputType.text,
      int? maxLength,
      bool onlyNumbers = false,
      bool shouldCapitalize = false, // Nouveau paramètre
      bool capitalizeWords = false}) {
    // Nouveau paramètre

    // Construction de la liste des formatters
    List<TextInputFormatter> formatters = [];

    if (onlyNumbers) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    } else if (shouldCapitalize) {
      if (capitalizeWords) {
        formatters.add(CapitalizeWordsFormatter());
      } else {
        formatters.add(CapitalizeFirstLetterFormatter());
      }
    }

    // Déterminer si c'est le champ email pour la validation visuelle
    bool isEmailField = label.toLowerCase().contains('email');
    bool hasEmailError = isEmailField &&
        controller.text.isNotEmpty &&
        !_isValidEmail(controller.text);

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
            inputFormatters: formatters, // Utiliser la liste des formatters
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon:
                  Icon(icon, color: hasEmailError ? primaryRed : primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasEmailError ? primaryRed : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasEmailError ? primaryRed : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasEmailError ? primaryRed : primaryBlue,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              hintStyle: TextStyle(color: Colors.grey.shade500),
              counterText: "",
              errorText: hasEmailError ? "Format d'email invalide" : null,
              errorStyle: TextStyle(color: primaryRed, fontSize: 12),
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
                      structureName, // CHANGEMENT : utiliser structureName au lieu du nom codé en dur
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
                      Icons.family_restroom,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Informations Parent',
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
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
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
          label: "Accueil",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Echanges.png',
            width: 60,
            height: 60,
          ),
          label: "Messages",
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
      margin: EdgeInsets.symmetric(horizontal: 20),
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
