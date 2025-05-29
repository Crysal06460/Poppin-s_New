import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

class StructureInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? extraData;

  const StructureInfoScreen({
    Key? key,
    this.extraData,
  }) : super(key: key);

  @override
  _StructureInfoScreenState createState() => _StructureInfoScreenState();
}

class _StructureInfoScreenState extends State<StructureInfoScreen> {
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController structureNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController phoneController =
      TextEditingController(); // Nouveau champ pour téléphone

  bool isLoading = false;
  String? errorMessage;
  String? structureType;
  String? structureId;
  Color primaryColor = primaryBlue;
  bool isMAM = false; // Pour contrôler l'affichage du champ Nom de la structure

  @override
  void initState() {
    super.initState();

    // Solution temporaire pour les tests: Décommentez cette ligne pour forcer le mode MAM
    // isMAM = true; structureType = 'MAM'; primaryColor = primaryRed;

    // Récupérer les données extras transmises par l'écran précédent
    if (widget.extraData != null) {
      structureType = widget.extraData?['structureType'];
      structureId = widget.extraData?['structureId'];

      print("📌 extraData reçu: ${widget.extraData}");
      print("📌 Structure Type reçu dans initState: $structureType");

      // Vérification de différentes valeurs possibles pour MAM
      // Accepter 'MAM', 'mam', ou toute valeur contenant 'mam'
      isMAM = structureType == 'MAM' ||
          structureType == 'mam' ||
          structureType?.toLowerCase().contains('mam') == true;

      // Gérer aussi le cas où le type est 'assistante_maternelle'
      if (structureType == 'assistante_maternelle') {
        structureType = 'AssistanteMaternelle';
        isMAM = false;
      }

      print("📌 isMAM défini à: $isMAM dans initState");

      // Définir la couleur primaire en fonction du type de structure
      primaryColor = isMAM ? primaryRed : primaryBlue;
    } else {
      // Si aucune donnée n'est transmise, essayer de récupérer depuis Firestore
      _fetchStructureType();
    }
  }

  Future<void> _fetchStructureType() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('structures')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          setState(() {
            structureType = data['structureType'];
            isMAM = structureType == 'MAM' ||
                structureType?.toLowerCase() == 'mam' ||
                structureType?.toLowerCase().contains('mam') == true;
            primaryColor = isMAM ? primaryRed : primaryBlue;

            // Si c'est une AssistanteMaternelle, pré-remplir le nom de la structure
            if (!isMAM && data['firstName'] != null) {
              firstNameController.text = data['firstName'];
              structureNameController.text =
                  data['firstName']; // Pré-remplir avec le prénom
            }
          });
        }
      }
    } catch (e) {
      print("❌ Erreur lors de la récupération du type de structure: $e");
    }
  }

  Future<void> _saveStructureInfo() async {
    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => errorMessage = "Utilisateur non authentifié");
        return;
      }

      // Validation des champs
      if (!_validateFields()) {
        setState(() => isLoading = false);
        return;
      }

      // Préparation des données communes
      Map<String, dynamic> structureData = {
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'ownerFirstName': firstNameController.text.trim(),
        'ownerLastName': lastNameController.text.trim(),
        'address': addressController.text.trim(),
        'postalCode': postalCodeController.text.trim(),
        'city': cityController.text.trim(),
        'phone': phoneController.text.trim(), // Ajout du numéro de téléphone
        'email': user.email,
        'structureType':
            structureType ?? (isMAM ? 'MAM' : 'AssistanteMaternelle'),
      };

      // Si c'est une MAM, utiliser le nom saisi, sinon utiliser seulement le prénom comme nom de structure
      if (isMAM) {
        structureData['structureName'] = structureNameController.text.trim();
      } else {
        // Pour AssistanteMaternelle, utiliser seulement le prénom
        structureData['structureName'] = firstNameController.text.trim();
      }

      // Mise à jour du document structure
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .update(structureData);

      // Créer ou mettre à jour le document "founder"
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('members')
          .doc('member_1')
          .set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': user.email ?? "",
        'isFounder':
            true, // Nous gardons cette valeur pour la logique d'affichage
        'memberNumber': 1, // Ajouter le numéro séquentiel
        'createdAt': FieldValue.serverTimestamp(),
      });

      context.go('/home');
    } catch (e) {
      setState(() => errorMessage = "Erreur : $e");
      print("❌ Erreur lors de l'enregistrement : $e");
    }

    setState(() => isLoading = false);
  }

  bool _validateFields() {
    // Validation générale
    if (firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        addressController.text.isEmpty) {
      setState(() => errorMessage = "Tous les champs doivent être remplis.");
      return false;
    }

    // Validation du code postal
    if (postalCodeController.text.length != 5 ||
        !RegExp(r'^\d{5}$').hasMatch(postalCodeController.text)) {
      setState(() =>
          errorMessage = "Le code postal doit contenir exactement 5 chiffres.");
      return false;
    }

    // Validation du numéro de téléphone
    if (phoneController.text.length != 10 ||
        !RegExp(r'^\d{10}$').hasMatch(phoneController.text)) {
      setState(() => errorMessage =
          "Le numéro de téléphone doit contenir exactement 10 chiffres.");
      return false;
    }

    // Validation nom de la structure si MAM
    if (isMAM && structureNameController.text.isEmpty) {
      setState(() => errorMessage =
          "Le nom de la structure est obligatoire pour une MAM.");
      return false;
    }

    // Validation ville
    if (cityController.text.isEmpty) {
      setState(() => errorMessage = "La ville est obligatoire.");
      return false;
    }

    return true;
  }

  Future<void> _fetchCityFromPostalCode(String postalCode) async {
    if (postalCode.length == 5 && RegExp(r'^\d{5}$').hasMatch(postalCode)) {
      final url = Uri.parse(
          "https://geo.api.gouv.fr/communes?codePostal=$postalCode&fields=nom&format=json");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            cityController.text = data[0]['nom'];
          });
        }
      }
    }
  }

  void _updateStructureNameIfNeeded() {
    if (!isMAM) {
      // Pour AssistanteMaternelle: le nom de structure est le prénom
      structureNameController.text = firstNameController.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    print("🔍 Dans build - isMAM = $isMAM, structureType = $structureType");

    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;

    // Déterminer si on est sur iPad
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Informations sur la structure",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 24 : 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        centerTitle: true,
      ),
      body: isTablet ? _buildTabletContent(screenSize) : _buildPhoneContent(),
    );
  }

  Widget _buildTabletContent(Size screenSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        // Calculer des dimensions en pourcentages
        final double sideMargin = maxWidth * 0.04; // 4% de marge sur les côtés
        final double topMargin = maxHeight * 0.02; // 2% de marge en haut

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              sideMargin, topMargin, sideMargin, maxHeight * 0.02),
          child: Column(
            children: [
              // Section d'en-tête moderne avec gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(maxWidth * 0.04),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icône avec design moderne
                    Container(
                      width: maxWidth * 0.12,
                      height: maxWidth * 0.12,
                      padding: EdgeInsets.all(maxWidth * 0.025),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.business,
                        size: maxWidth * 0.06,
                        color: primaryColor,
                      ),
                    ),

                    SizedBox(width: maxWidth * 0.03),

                    // Titre et description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Informations de votre ${isMAM ? 'MAM' : 'activité'}",
                            style: TextStyle(
                              fontSize: maxWidth * 0.026,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: maxHeight * 0.01),
                          Text(
                            "Complétez les informations ci-dessous pour finaliser votre profil professionnel",
                            style: TextStyle(
                              fontSize: maxWidth * 0.016,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: maxHeight * 0.04),

              // Formulaire principal avec design moderne
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 4),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(maxWidth * 0.035),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre de la section formulaire
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(maxWidth * 0.012),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: primaryColor,
                              size: maxWidth * 0.02,
                            ),
                          ),
                          SizedBox(width: maxWidth * 0.015),
                          Text(
                            "Informations professionnelles",
                            style: TextStyle(
                              fontSize: maxWidth * 0.022,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.03),

                      // Formulaire en deux colonnes pour optimiser l'espace iPad
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Colonne gauche
                          Expanded(
                            child: Column(
                              children: [
                                // Champ Nom de la structure (uniquement pour MAM)
                                if (isMAM) ...[
                                  _buildTabletTextField(
                                    structureNameController,
                                    "Nom de la MAM",
                                    icon: Icons.business_outlined,
                                    color: primaryColor,
                                    helperText: "Entrez le nom de votre MAM",
                                    maxWidth: maxWidth,
                                    maxHeight: maxHeight,
                                  ),
                                  SizedBox(height: maxHeight * 0.025),
                                ],

                                // Prénom
                                _buildTabletTextField(
                                  firstNameController,
                                  "Prénom",
                                  icon: Icons.person_outline,
                                  color: primaryColor,
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                  onChanged: (value) {
                                    if (!isMAM) {
                                      structureNameController.text = value;
                                    }
                                  },
                                ),

                                SizedBox(height: maxHeight * 0.025),

                                // Nom
                                _buildTabletTextField(
                                  lastNameController,
                                  "Nom",
                                  icon: Icons.person_outline,
                                  color: primaryColor,
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                ),

                                SizedBox(height: maxHeight * 0.025),

                                // Téléphone
                                _buildTabletTextField(
                                  phoneController,
                                  "Téléphone",
                                  icon: Icons.phone_outlined,
                                  isNumeric: true,
                                  maxLength: 10,
                                  color: primaryColor,
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: maxWidth * 0.04),

                          // Colonne droite
                          Expanded(
                            child: Column(
                              children: [
                                // Adresse
                                _buildTabletTextField(
                                  addressController,
                                  "Adresse",
                                  icon: Icons.location_on_outlined,
                                  color: primaryColor,
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                ),

                                SizedBox(height: maxHeight * 0.025),

                                // Code postal
                                _buildTabletTextField(
                                  postalCodeController,
                                  "Code postal",
                                  icon: Icons.pin_outlined,
                                  isNumeric: true,
                                  maxLength: 5,
                                  color: primaryColor,
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                  onChanged: (value) {
                                    _fetchCityFromPostalCode(value);
                                  },
                                ),

                                SizedBox(height: maxHeight * 0.025),

                                // Ville
                                _buildTabletTextField(
                                  cityController,
                                  "Ville",
                                  icon: Icons.location_city_outlined,
                                  isReadOnly: true,
                                  color: primaryColor,
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.025),

                      // Message d'erreur adaptatif
                      if (errorMessage != null)
                        Container(
                          padding: EdgeInsets.all(maxWidth * 0.025),
                          decoration: BoxDecoration(
                            color: primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: primaryRed.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: primaryRed.withOpacity(0.1),
                                offset: const Offset(0, 2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(maxWidth * 0.01),
                                decoration: BoxDecoration(
                                  color: primaryRed.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.error_outline,
                                  color: primaryRed,
                                  size: maxWidth * 0.02,
                                ),
                              ),
                              SizedBox(width: maxWidth * 0.02),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(
                                    fontSize: maxWidth * 0.016,
                                    color: primaryRed,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: maxHeight * 0.04),

              // Bouton d'action adaptatif pour iPad
              _buildTabletActionButton(maxWidth, maxHeight),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletTextField(
    TextEditingController controller,
    String label, {
    bool isNumeric = false,
    int? maxLength,
    bool isReadOnly = false,
    Function(String)? onChanged,
    required IconData icon,
    required Color color,
    String? helperText,
    required double maxWidth,
    required double maxHeight,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        maxLength: maxLength,
        readOnly: isReadOnly,
        inputFormatters:
            isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: maxWidth * 0.016,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: color, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          prefixIcon: Container(
            margin: EdgeInsets.all(maxWidth * 0.015),
            padding: EdgeInsets.all(maxWidth * 0.01),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: maxWidth * 0.018,
            ),
          ),
          counterText: "",
          helperText: helperText,
          helperStyle:
              helperText != null ? TextStyle(fontSize: maxWidth * 0.014) : null,
          contentPadding: EdgeInsets.symmetric(
            vertical: maxHeight * 0.02,
            horizontal: maxWidth * 0.02,
          ),
        ),
        onChanged: onChanged,
        style: TextStyle(
          fontSize: maxWidth * 0.018,
          color: isReadOnly ? Colors.grey : Colors.black,
        ),
        cursorColor: color,
      ),
    );
  }

  Widget _buildTabletActionButton(double maxWidth, double maxHeight) {
    return Container(
      width: maxWidth * 0.4, // 40% de la largeur de l'écran
      height: maxHeight * 0.08, // 8% de la hauteur de l'écran
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _saveStructureInfo,
        icon: isLoading
            ? SizedBox(
                width: maxWidth * 0.025,
                height: maxWidth * 0.025,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
            : Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: maxWidth * 0.022,
              ),
        label: Text(
          "VALIDER",
          style: TextStyle(
            fontSize: maxWidth * 0.02,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(
            color: primaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Icône avec un cercle de fond
          Container(
            width: 120,
            height: 120,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business,
              size: 70,
              color: primaryColor,
            ),
          ),

          const SizedBox(height: 20),

          // Titre
          Text(
            "Ajoutez les informations de votre ${isMAM ? 'MAM' : 'activité'}",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          // Champ Nom de la structure (uniquement affiché pour les MAM)
          if (isMAM) ...[
            _buildTextField(
              structureNameController,
              "Nom de la MAM",
              icon: Icons.business_outlined,
              color: primaryColor,
              helperText: "Entrez le nom de votre MAM",
            ),
            const SizedBox(height: 15),
          ],

          // Champs de formulaire
          _buildTextField(
            firstNameController,
            "Prénom",
            icon: Icons.person_outline,
            color: primaryColor,
            onChanged: (value) {
              if (!isMAM) {
                // Mettre à jour automatiquement le nom de la structure pour AssistanteMaternelle
                structureNameController.text = value;
              }
            },
          ),

          const SizedBox(height: 15),

          _buildTextField(lastNameController, "Nom",
              icon: Icons.person_outline, color: primaryColor),

          const SizedBox(height: 15),

          _buildTextField(addressController, "Adresse",
              icon: Icons.location_on_outlined, color: primaryColor),

          const SizedBox(height: 15),

          _buildTextField(postalCodeController, "Code postal",
              icon: Icons.pin_outlined,
              isNumeric: true,
              maxLength: 5,
              color: primaryColor, onChanged: (value) {
            _fetchCityFromPostalCode(value);
          }),

          const SizedBox(height: 15),

          _buildTextField(cityController, "Ville",
              icon: Icons.location_city_outlined,
              isReadOnly: true,
              color: primaryColor),

          const SizedBox(height: 15),

          // Nouveau champ pour le téléphone
          _buildTextField(phoneController, "Téléphone",
              icon: Icons.phone_outlined,
              isNumeric: true,
              maxLength: 10,
              color: primaryColor),

          const SizedBox(height: 20),

          // Message d'erreur
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: primaryRed,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryRed,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 30),

          // Bouton de validation
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _saveStructureInfo,
              icon: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                  : Icon(Icons.check, color: Colors.white),
              label: Text(
                "VALIDER",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumeric = false,
    int? maxLength,
    bool isReadOnly = false,
    Function(String)? onChanged,
    required IconData icon,
    required Color color,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      maxLength: maxLength,
      readOnly: isReadOnly,
      // Formatage pour n'accepter que les chiffres pour les champs numériques
      inputFormatters:
          isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color.withOpacity(0.8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        prefixIcon: Icon(icon, color: color),
        counterText: "",
        helperText: helperText,
        helperStyle: helperText != null ? const TextStyle(fontSize: 12) : null,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 16,
        color:
            isReadOnly ? Colors.grey : Colors.black, // Grisé si lecture seule
      ),
      cursorColor: color,
    );
  }
}
