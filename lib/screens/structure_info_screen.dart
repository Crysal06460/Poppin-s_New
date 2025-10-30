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

List<String> citySuggestions = [];

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
  bool isParent = false;

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

      // Vérification de différentes valeurs possibles pour les types
      final normalizedType = structureType?.toLowerCase();
      isMAM =
          normalizedType == 'mam' || normalizedType?.contains('mam') == true;
      isParent = normalizedType == 'parent_employeur' ||
          normalizedType == 'parentemployeur';

      // Gérer aussi le cas où le type est 'assistante_maternelle'
      if (normalizedType == 'assistante_maternelle') {
        structureType = 'AssistanteMaternelle';
        isMAM = false;
        isParent = false;
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
            final normalized = structureType?.toLowerCase();
            isMAM = normalized == 'mam' || normalized?.contains('mam') == true;
            isParent = normalized == 'parent_employeur' ||
                normalized == 'parentemployeur';
            primaryColor = isMAM ? primaryRed : primaryBlue;

            // Si c'est une AssistanteMaternelle, pré-remplir le nom de la structure
            if (!isMAM && !isParent && data['firstName'] != null) {
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
      final String resolvedType = structureType != null
          ? structureType!
          : (isMAM
              ? 'MAM'
              : (isParent ? 'parent_employeur' : 'AssistanteMaternelle'));

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
        'structureType': resolvedType,
      };

      // Si c'est une MAM, utiliser le nom saisi, sinon utiliser seulement le prénom comme nom de structure
      if (isMAM) {
        structureData['structureName'] = structureNameController.text.trim();
      } else {
        // Pour AssistanteMaternelle, utiliser seulement le prénom
        // Pour un parent employeur, on enregistre le nom complet
        structureData['structureName'] = isParent
            ? '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
                .trim()
            : firstNameController.text.trim();
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
    print("🔍 Recherche pour code postal: $postalCode");

    if (postalCode.length == 5 && RegExp(r'^\d{5}$').hasMatch(postalCode)) {
      setState(() {
        isLoading = true;
        // Vider immédiatement le champ ville et les suggestions
        cityController.text = "";
        citySuggestions = [];
      });

      final url = Uri.parse(
          'https://geo.api.gouv.fr/communes?codePostal=$postalCode&fields=nom');
      try {
        print("📡 Appel API: $url");
        final response = await http.get(url);

        if (response.statusCode == 200) {
          List<dynamic> cities = json.decode(response.body);
          print("📍 Villes trouvées: ${cities.length}");

          List<String> newCities = cities
              .map((city) => city['nom'].toString())
              .toSet() // Supprimer les doublons
              .toList();

          // Trier alphabétiquement
          newCities.sort();

          setState(() {
            citySuggestions = newCities;
            isLoading = false;

            if (newCities.isNotEmpty) {
              cityController.text = newCities.first;
              print("✅ Ville sélectionnée: ${newCities.first}");
            } else {
              cityController.text = "";
              print("❌ Aucune ville trouvée");
            }
          });
        } else {
          print("❌ Erreur API: ${response.statusCode}");
          setState(() {
            citySuggestions = [];
            cityController.text = "";
            isLoading = false;
          });
        }
      } catch (e) {
        print("❌ Erreur réseau: $e");
        setState(() {
          citySuggestions = [];
          cityController.text = "";
          isLoading = false;
          errorMessage =
              "Erreur de connexion. Vérifiez votre connexion internet.";
        });

        // Effacer le message d'erreur après 3 secondes
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              errorMessage = null;
            });
          }
        });
      }
    } else {
      setState(() {
        citySuggestions = [];
        if (postalCode.isEmpty) {
          cityController.text = "";
        }
      });
    }
  }

  void _updateStructureNameIfNeeded() {
    if (!isMAM && !isParent) {
      // Pour AssistanteMaternelle: le nom de structure est le prénom
      structureNameController.text = firstNameController.text;
    }
  }

  String _getEntityLabel() {
    if (isMAM) return 'MAM';
    if (isParent) return 'profil parent employeur';
    return 'activité';
  }

  @override
  Widget build(BuildContext context) {
    //print("🔍 Dans build - isMAM = $isMAM, structureType = $structureType");

    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;

    // Déterminer si on est sur iPad
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'Informations de la structure',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                            "Vos informations",
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
                                    shouldCapitalize: true,
                                    capitalizeWords: true,
                                  ),
                                ],

                                _buildTabletTextField(
                                  firstNameController,
                                  "Prénom",
                                  icon: Icons.person_outline,
                                  color: primaryColor,
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                  shouldCapitalize: true,
                                  capitalizeWords: true,
                                  onChanged: (value) {
                                    if (!isMAM && !isParent) {
                                      structureNameController.text = value;
                                    }
                                  },
                                ),

                                SizedBox(height: maxHeight * 0.025),

                                _buildTabletTextField(
                                  lastNameController,
                                  "Nom",
                                  icon: Icons.person_outline,
                                  color: primaryColor,
                                  maxWidth: maxWidth,
                                  maxHeight: maxHeight,
                                  shouldCapitalize: true,
                                  capitalizeWords: true,
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

                                // Ville avec dropdown
                                _buildTabletCityField(maxWidth, maxHeight),
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

  // Nouvelle méthode pour le champ ville avec dropdown
  Widget _buildTabletCityField(double maxWidth, double maxHeight) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: citySuggestions.length > 1
            ? () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("Choisissez votre ville"),
                    content: Container(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: citySuggestions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(citySuggestions[index]),
                            onTap: () {
                              setState(() {
                                cityController.text = citySuggestions[index];
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: maxHeight * 0.02,
            horizontal: maxWidth * 0.02,
          ),
          child: Row(
            children: [
              Container(
                margin: EdgeInsets.all(maxWidth * 0.015),
                padding: EdgeInsets.all(maxWidth * 0.01),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_city_outlined,
                  color: primaryColor,
                  size: maxWidth * 0.018,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ville",
                      style: TextStyle(
                        color: primaryColor.withOpacity(0.8),
                        fontSize: maxWidth * 0.016,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      cityController.text.isEmpty
                          ? "Entrez d'abord un code postal"
                          : cityController.text,
                      style: TextStyle(
                        fontSize: maxWidth * 0.018,
                        color: cityController.text.isEmpty
                            ? Colors.grey.shade500
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              if (citySuggestions.length > 1)
                Icon(Icons.arrow_drop_down, color: primaryColor),
            ],
          ),
        ),
      ),
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
    bool shouldCapitalize = false, // Nouveau paramètre
    bool capitalizeWords = false, // Pour les prénoms composés
  }) {
    // Construction de la liste des formatters
    List<TextInputFormatter> formatters = [];

    if (isNumeric) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    } else if (shouldCapitalize) {
      if (capitalizeWords) {
        formatters.add(CapitalizeWordsFormatter());
      } else {
        formatters.add(CapitalizeFirstLetterFormatter());
      }
    }

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
        inputFormatters: formatters,
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
            "Ajoutez les informations de votre ${_getEntityLabel()}",
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
              shouldCapitalize: true, // Active la capitalisation
              capitalizeWords: true, // Pour gérer les noms composés
            ),
          ],

          // Champs de formulaire
          _buildTextField(
            firstNameController,
            "Prénom",
            icon: Icons.person_outline,
            color: primaryColor,
            shouldCapitalize: true, // Active la capitalisation
            capitalizeWords:
                true, // Pour gérer les prénoms composés comme "Jean-Pierre"
            onChanged: (value) {
              if (!isMAM && !isParent) {
                structureNameController.text = value;
              }
            },
          ),

          const SizedBox(height: 15),

          _buildTextField(
            lastNameController,
            "Nom",
            icon: Icons.person_outline,
            color: primaryColor,
            shouldCapitalize: true, // Active la capitalisation
            capitalizeWords: true, // Pour gérer les noms composés
          ),

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

          _buildPhoneCityField(),

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

  Widget _buildPhoneCityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          "Ville",
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: citySuggestions.length > 1
              ? () {
                  _showCitySelectionDialog();
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: primaryColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.location_city_outlined, color: primaryColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cityController.text.isEmpty
                        ? "Entrez d'abord un code postal"
                        : cityController.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: cityController.text.isEmpty
                          ? Colors.grey.shade500
                          : Colors.black,
                    ),
                  ),
                ),
                if (citySuggestions.length > 1)
                  Icon(Icons.arrow_drop_down, color: primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

// ET AJOUTER cette méthode pour afficher le dialog de sélection :

  void _showCitySelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_city,
                color: primaryBlue,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Choisissez votre ville",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryBlue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: primaryBlue,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Code postal ${postalCodeController.text}",
                          style: TextStyle(
                            fontSize: 14,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: citySuggestions.length,
                    itemBuilder: (context, index) {
                      final city = citySuggestions[index];
                      final isSelected = cityController.text == city;

                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryBlue.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? primaryBlue.withOpacity(0.5)
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            city,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected ? primaryBlue : Colors.black87,
                            ),
                          ),
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryBlue.withOpacity(0.2)
                                  : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.location_on_outlined,
                              color: isSelected
                                  ? primaryBlue
                                  : Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              cityController.text = city;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          "Ville",
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: citySuggestions.length > 1
              ? () {
                  _showCitySelectionDialog();
                }
              : null,
          child: Container(
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
              controller: cityController,
              enabled: false, // Changé de readOnly à enabled: false
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.location_city, color: primaryColor),
                suffixIcon: citySuggestions.length > 1
                    ? Icon(Icons.arrow_drop_down, color: primaryColor)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                disabledBorder: OutlineInputBorder(
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
                hintText: citySuggestions.isEmpty
                    ? "Entrez d'abord un code postal"
                    : null,
                hintStyle: TextStyle(color: Colors.grey.shade500),
              ),
              style: TextStyle(
                fontSize: 16,
                color: cityController.text.isEmpty
                    ? Colors.grey.shade500
                    : Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCityDropdownTablet(double maxWidth, double maxHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Ville",
          style: TextStyle(
            fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: (maxHeight * 0.015).clamp(8.0, 15.0)),
        InkWell(
          onTap: citySuggestions.length > 1
              ? () {
                  _showCitySelectionDialog();
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
              controller: cityController,
              enabled: false, // Changé de readOnly à enabled: false
              onChanged: (value) => setState(() {}), // Pour rafraîchir l'aperçu
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.location_city, color: primaryBlue),
                suffixIcon: citySuggestions.length > 1
                    ? Icon(Icons.arrow_drop_down, color: primaryBlue)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: (maxWidth * 0.02).clamp(12.0, 20.0),
                  vertical: (maxHeight * 0.02).clamp(12.0, 20.0),
                ),
                hintText: citySuggestions.isEmpty
                    ? "Entrez d'abord un code postal"
                    : null,
                hintStyle: TextStyle(color: Colors.grey.shade500),
              ),
              style: TextStyle(
                fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
                color: cityController.text.isEmpty
                    ? Colors.grey.shade500
                    : Colors.black87,
              ),
            ),
          ),
        ),
      ],
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
    bool shouldCapitalize = false, // Nouveau paramètre
    bool capitalizeWords = false, // Pour les prénoms composés
  }) {
    // Construction de la liste des formatters
    List<TextInputFormatter> formatters = [];

    if (isNumeric) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    } else if (shouldCapitalize) {
      if (capitalizeWords) {
        formatters.add(CapitalizeWordsFormatter());
      } else {
        formatters.add(CapitalizeFirstLetterFormatter());
      }
    }

    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      maxLength: maxLength,
      readOnly: isReadOnly,
      inputFormatters: formatters,
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
        color: isReadOnly ? Colors.grey : Colors.black,
      ),
      cursorColor: color,
    );
  }
}
