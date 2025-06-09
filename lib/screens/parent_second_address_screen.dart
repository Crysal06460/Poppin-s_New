import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ParentSecondAddressScreen extends StatefulWidget {
  final String childId;

  const ParentSecondAddressScreen({Key? key, required this.childId})
      : super(key: key);

  @override
  _ParentSecondAddressScreenState createState() =>
      _ParentSecondAddressScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

String structureName = "Chargement...";
bool isLoadingStructure = true;

class _ParentSecondAddressScreenState extends State<ParentSecondAddressScreen> {
  final TextEditingController addressController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  List<String> citySuggestions = [];
  bool _isLoading = false;
  bool _showAddressForm = false;
  bool _hasAskedAddressQuestion = false;
  int _selectedIndex = 2;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _loadStructureInfo();
  }

  Future<void> _loadStructureInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoadingStructure = false);
        return;
      }

      final String currentUserEmail = user.email?.toLowerCase() ?? '';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      String structureId = user.uid;

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          structureId = userData['structureId'];
          print(
              "🔄 Parent Second Address: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

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

  Future<void> _fetchCities(String postalCode) async {
    if (postalCode.length == 5 && RegExp(r'^[0-9]{5}$').hasMatch(postalCode)) {
      setState(() {
        _isLoading = true;
      });

      final url = Uri.parse(
          'https://geo.api.gouv.fr/communes?codePostal=$postalCode&fields=nom');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          List<dynamic> cities = json.decode(response.body);
          List<String> newCities =
              cities.map((city) => city['nom'].toString()).toList();

          setState(() {
            citySuggestions = newCities;
            _isLoading = false;

            if (newCities.isNotEmpty) {
              cityController.text = newCities.first;
              print("Ville trouvée: ${newCities.first}");
            } else {
              cityController.text = "";
              print("Aucune ville trouvée pour ce code postal");
            }
          });
        } else {
          setState(() {
            citySuggestions = [];
            cityController.text = "";
            _isLoading = false;
          });
        }
      } catch (e) {
        print("Erreur API: $e");
        setState(() {
          citySuggestions = [];
          cityController.text = "";
          _isLoading = false;
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

  Future<void> _saveAddressInfo() async {
    if (_showAddressForm) {
      // Validation des champs si on affiche le formulaire
      if (addressController.text.isEmpty ||
          postalCodeController.text.isEmpty ||
          cityController.text.isEmpty) {
        _showError("Merci de remplir tous les champs.");
        return;
      }

      if (postalCodeController.text.length != 5 ||
          !RegExp(r'^[0-9]{5}$').hasMatch(postalCodeController.text)) {
        _showError("Le code postal doit contenir exactement 5 chiffres.");
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("Erreur : Utilisateur non authentifié !");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final userEmail = user.email?.toLowerCase() ?? '';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      String structureId = user.uid;

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          structureId = userData['structureId'];
          print(
              "🔄 Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      Map<String, dynamic> updateData = {};

      if (_showAddressForm) {
        // Adresse différente - sauvegarder les nouvelles données
        updateData['parent2Address'] = {
          'address': addressController.text,
          'postalCode': postalCodeController.text,
          'city': cityController.text,
        };
      } else {
        // Même adresse - copier l'adresse du parent 1
        final childDoc = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .doc(widget.childId)
            .get();

        if (childDoc.exists) {
          final childData = childDoc.data() ?? {};
          final parent1Address = childData['parentAddress'];

          if (parent1Address != null) {
            updateData['parent2Address'] = parent1Address;
          } else {
            _showError("Impossible de récupérer l'adresse du parent 1.");
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .update(updateData);

      setState(() {
        _isLoading = false;
      });

      context.go('/schedule-info', extra: widget.childId);
    } catch (e) {
      print("❌ Erreur Firestore: $e");
      setState(() {
        _isLoading = false;
      });
      _showError("Une erreur est survenue. Veuillez réessayer.");
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      _showExitWarning(context, '/dashboard');
    } else if (index == 1) {
      _showExitWarning(context, '/home');
    } else if (index == 2) {
      // Déjà sur cette page d'ajout - ne rien faire
    }
  }

  Widget _buildTabletLayout() {
    return LayoutBuilder(builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth;
      final double maxHeight = constraints.maxHeight;
      final double contentWidth = (maxWidth * 0.6).clamp(400.0, 600.0);

      if (!_hasAskedAddressQuestion) {
        // Interface de choix de l'adresse
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: (maxWidth * 0.05).clamp(20.0, 50.0),
              vertical: (maxHeight * 0.02).clamp(10.0, 30.0),
            ),
            child: Container(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Card principale avec question
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    padding:
                        EdgeInsets.all((maxWidth * 0.04).clamp(24.0, 40.0)),
                    child: Column(
                      children: [
                        // En-tête avec icône
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(
                                  (maxWidth * 0.015).clamp(12.0, 20.0)),
                              decoration: BoxDecoration(
                                color: lightBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.home_outlined,
                                color: primaryBlue,
                                size: (maxWidth * 0.03).clamp(28.0, 40.0),
                              ),
                            ),
                            SizedBox(
                                width: (maxWidth * 0.02).clamp(16.0, 24.0)),
                            Flexible(
                              child: Text(
                                "Adresse Parent 2",
                                style: TextStyle(
                                  fontSize:
                                      (maxWidth * 0.024).clamp(20.0, 28.0),
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: (maxHeight * 0.03).clamp(20.0, 30.0)),

                        // Question
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                              (maxWidth * 0.025).clamp(20.0, 30.0)),
                          decoration: BoxDecoration(
                            color: lightBlue.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            "L'adresse du parent 2 est-elle différente de celle du parent 1 ?",
                            style: TextStyle(
                              fontSize: (maxWidth * 0.018).clamp(15.0, 20.0),
                              color: Colors.grey[700],
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: (maxHeight * 0.05).clamp(30.0, 50.0)),

                  // Icône illustration centrale
                  Container(
                    padding:
                        EdgeInsets.all((maxWidth * 0.035).clamp(30.0, 50.0)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          lightBlue.withOpacity(0.7),
                          lightBlue,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.2),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.location_on,
                      size: (maxWidth * 0.08).clamp(80.0, 120.0),
                      color: primaryBlue,
                    ),
                  ),

                  SizedBox(height: (maxHeight * 0.06).clamp(40.0, 60.0)),

                  // Boutons de choix
                  Column(
                    children: [
                      // Bouton adresse différente
                      _buildChoiceButtonTablet(
                        text: "Oui, adresse différente",
                        icon: Icons.add_location_alt,
                        onPressed: () {
                          setState(() {
                            _showAddressForm = true;
                            _hasAskedAddressQuestion = true;
                          });
                        },
                        color: primaryBlue,
                        isPrimary: true,
                        maxWidth: maxWidth,
                        maxHeight: maxHeight,
                      ),

                      SizedBox(height: (maxHeight * 0.02).clamp(16.0, 24.0)),

                      // Bouton même adresse
                      _buildChoiceButtonTablet(
                        text: "Non, même adresse",
                        icon: Icons.home,
                        onPressed: () {
                          setState(() {
                            _showAddressForm = false;
                            _hasAskedAddressQuestion = true;
                          });
                        },
                        color: Colors.grey.shade400,
                        isPrimary: false,
                        maxWidth: maxWidth,
                        maxHeight: maxHeight,
                      ),
                    ],
                  ),

                  SizedBox(height: (maxHeight * 0.04).clamp(30.0, 50.0)),
                ],
              ),
            ),
          ),
        );
      } else {
        // Interface du formulaire ou confirmation
        if (_showAddressForm) {
          return _buildAddressFormTablet(maxWidth, maxHeight);
        } else {
          return _buildConfirmationTablet(maxWidth, maxHeight);
        }
      }
    });
  }

  Widget _buildChoiceButtonTablet({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required bool isPrimary,
    required double maxWidth,
    required double maxHeight,
  }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: (maxWidth * 0.4).clamp(300.0, 450.0),
      ),
      child: ElevatedButton.icon(
        icon: Icon(
          icon,
          color: Colors.white,
          size: (maxWidth * 0.022).clamp(20.0, 28.0),
        ),
        label: Text(
          text,
          style: TextStyle(
            fontSize: (maxWidth * 0.02).clamp(16.0, 22.0),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: (maxWidth * 0.03).clamp(25.0, 40.0),
            vertical: (maxHeight * 0.025).clamp(18.0, 25.0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isPrimary ? 4 : 2,
          shadowColor:
              isPrimary ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildAddressFormTablet(double maxWidth, double maxHeight) {
    final double sideMargin = (maxWidth * 0.03).clamp(10.0, 30.0);
    final double columnGap = (maxWidth * 0.025).clamp(10.0, 25.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          sideMargin, maxHeight * 0.02, sideMargin, maxHeight * 0.02),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panneau gauche - Aperçu de l'adresse
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

                    // Aperçu de l'adresse
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
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
                                    Icons.home_outlined,
                                    color: primaryBlue,
                                    size: (maxWidth * 0.02).clamp(16.0, 24.0),
                                  ),
                                ),
                                SizedBox(
                                    width: (maxWidth * 0.01).clamp(6.0, 12.0)),
                                Flexible(
                                  child: Text(
                                    "Adresse parent 2",
                                    style: TextStyle(
                                      fontSize:
                                          (maxWidth * 0.018).clamp(14.0, 20.0),
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: maxHeight * 0.03),

                            // Adresse
                            _buildInfoRowTablet(
                                "Adresse",
                                addressController.text.isEmpty
                                    ? "Non renseignée"
                                    : addressController.text,
                                maxWidth),
                            SizedBox(height: maxHeight * 0.03),

                            // Code postal
                            _buildInfoRowTablet(
                                "Code postal",
                                postalCodeController.text.isEmpty
                                    ? "Non renseigné"
                                    : postalCodeController.text,
                                maxWidth),
                            SizedBox(height: maxHeight * 0.03),

                            // Ville
                            _buildInfoRowTablet(
                                "Ville",
                                cityController.text.isEmpty
                                    ? "Non renseignée"
                                    : cityController.text,
                                maxWidth),

                            SizedBox(height: maxHeight * 0.03),

                            // Aperçu complet de l'adresse
                            if (addressController.text.isNotEmpty &&
                                postalCodeController.text.isNotEmpty &&
                                cityController.text.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(
                                    (maxWidth * 0.015).clamp(10.0, 15.0)),
                                decoration: BoxDecoration(
                                  color: lightBlue.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: primaryBlue.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: primaryBlue,
                                          size: (maxWidth * 0.018)
                                              .clamp(14.0, 20.0),
                                        ),
                                        SizedBox(width: maxWidth * 0.01),
                                        Text(
                                          "Adresse complète",
                                          style: TextStyle(
                                            fontSize: (maxWidth * 0.016)
                                                .clamp(12.0, 18.0),
                                            fontWeight: FontWeight.w600,
                                            color: primaryBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: maxHeight * 0.01),
                                    Text(
                                      "${addressController.text}\n${postalCodeController.text} ${cityController.text}",
                                      style: TextStyle(
                                        fontSize: (maxWidth * 0.015)
                                            .clamp(11.0, 16.0),
                                        color: Colors.black87,
                                        height: 1.3,
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
                      "Adresse parent 2",
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
                          SizedBox(width: (maxWidth * 0.015).clamp(8.0, 15.0)),
                          Expanded(
                            child: Text(
                              "Veuillez renseigner l'adresse du parent 2",
                              style: TextStyle(
                                fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
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
                            _buildAddressFieldTablet(
                                "Adresse",
                                addressController,
                                Icons.location_on,
                                maxWidth,
                                maxHeight),
                            SizedBox(height: maxHeight * 0.03),
                            _buildPostalCodeFieldTablet(maxWidth, maxHeight),
                            SizedBox(height: maxHeight * 0.03),
                            _buildCityDropdownTablet(maxWidth, maxHeight),
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
                                fontSize: (maxWidth * 0.018).clamp(14.0, 18.0),
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _hasAskedAddressQuestion = false;
                                      _showAddressForm = false;
                                      addressController.clear();
                                      postalCodeController.clear();
                                      cityController.clear();
                                      citySuggestions.clear();
                                    });
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
                                    width: (maxWidth * 0.018).clamp(16.0, 22.0),
                                    height:
                                        (maxWidth * 0.018).clamp(16.0, 22.0),
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Icon(Icons.arrow_forward,
                                    color: Colors.white,
                                    size: (maxWidth * 0.018).clamp(16.0, 22.0)),
                            label: Text(
                              "Suivant",
                              style: TextStyle(
                                fontSize: (maxWidth * 0.018).clamp(14.0, 18.0),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: _isLoading ? null : _saveAddressInfo,
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
  }

  Widget _buildConfirmationTablet(double maxWidth, double maxHeight) {
    final double contentWidth = (maxWidth * 0.6).clamp(400.0, 600.0);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: (maxWidth * 0.05).clamp(20.0, 50.0),
          vertical: (maxHeight * 0.02).clamp(10.0, 30.0),
        ),
        child: Container(
          width: contentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Card de confirmation
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                padding: EdgeInsets.all((maxWidth * 0.04).clamp(24.0, 40.0)),
                child: Column(
                  children: [
                    // En-tête avec icône
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                              (maxWidth * 0.015).clamp(12.0, 20.0)),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade600,
                            size: (maxWidth * 0.03).clamp(28.0, 40.0),
                          ),
                        ),
                        SizedBox(width: (maxWidth * 0.02).clamp(16.0, 24.0)),
                        Flexible(
                          child: Text(
                            "Confirmation",
                            style: TextStyle(
                              fontSize: (maxWidth * 0.024).clamp(20.0, 28.0),
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: (maxHeight * 0.03).clamp(20.0, 30.0)),

                    // Message de confirmation
                    Container(
                      width: double.infinity,
                      padding:
                          EdgeInsets.all((maxWidth * 0.025).clamp(20.0, 30.0)),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.home,
                            color: Colors.green.shade600,
                            size: (maxWidth * 0.025).clamp(24.0, 32.0),
                          ),
                          SizedBox(
                              height: (maxHeight * 0.02).clamp(12.0, 20.0)),
                          Text(
                            "Le parent 2 utilisera la même adresse que le parent 1",
                            style: TextStyle(
                              fontSize: (maxWidth * 0.018).clamp(15.0, 20.0),
                              color: Colors.grey[700],
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: (maxHeight * 0.06).clamp(40.0, 60.0)),

              // Boutons d'action
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bouton Modifier
                  Container(
                    width: (maxWidth * 0.15).clamp(180.0, 220.0),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.edit,
                          color: primaryBlue,
                          size: (maxWidth * 0.018).clamp(16.0, 22.0)),
                      label: Text(
                        "Modifier",
                        style: TextStyle(
                          fontSize: (maxWidth * 0.018).clamp(14.0, 18.0),
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _hasAskedAddressQuestion = false;
                          _showAddressForm = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightBlue,
                        foregroundColor: primaryBlue,
                        padding: EdgeInsets.symmetric(
                            horizontal: (maxWidth * 0.02).clamp(15.0, 25.0),
                            vertical: (maxHeight * 0.02).clamp(12.0, 18.0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),

                  SizedBox(width: (maxWidth * 0.03).clamp(20.0, 30.0)),

                  // Bouton Confirmer
                  Container(
                    width: (maxWidth * 0.18).clamp(220.0, 280.0),
                    child: ElevatedButton.icon(
                      icon: _isLoading
                          ? SizedBox(
                              width: (maxWidth * 0.018).clamp(16.0, 22.0),
                              height: (maxWidth * 0.018).clamp(16.0, 22.0),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Icon(Icons.check,
                              color: Colors.white,
                              size: (maxWidth * 0.018).clamp(16.0, 22.0)),
                      label: Text(
                        "Confirmer",
                        style: TextStyle(
                          fontSize: (maxWidth * 0.018).clamp(14.0, 18.0),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveAddressInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            horizontal: (maxWidth * 0.025).clamp(20.0, 35.0),
                            vertical: (maxHeight * 0.02).clamp(12.0, 18.0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: (maxHeight * 0.04).clamp(30.0, 50.0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRowTablet(String label, String value, double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label:",
          style: TextStyle(
            fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: (maxWidth * 0.008).clamp(4.0, 8.0)),
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

  Widget _buildAddressFieldTablet(
      String label,
      TextEditingController controller,
      IconData icon,
      double maxWidth,
      double maxHeight) {
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
            autofillHints: const [AutofillHints.streetAddressLine1],
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
            ),
            style: TextStyle(fontSize: (maxWidth * 0.018).clamp(14.0, 20.0)),
          ),
        ),
      ],
    );
  }

  Widget _buildPostalCodeFieldTablet(double maxWidth, double maxHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Code postal",
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
            controller: postalCodeController,
            keyboardType: TextInputType.number,
            maxLength: 5,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              _fetchCities(value);
              setState(() {});
            },
            autocorrect: true,
            enableSuggestions: true,
            autofillHints: const [AutofillHints.postalCode],
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.map, color: primaryBlue),
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
              suffixIcon: _isLoading
                  ? Container(
                      padding: EdgeInsets.all(12),
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: primaryBlue,
                        strokeWidth: 2,
                      ),
                    )
                  : null,
            ),
            style: TextStyle(fontSize: (maxWidth * 0.018).clamp(14.0, 20.0)),
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
            controller: cityController,
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.location_city, color: primaryBlue),
              suffixIcon: citySuggestions.isNotEmpty
                  ? PopupMenuButton<String>(
                      icon: Icon(Icons.arrow_drop_down, color: primaryBlue),
                      onSelected: (String value) {
                        setState(() {
                          cityController.text = value;
                        });
                      },
                      itemBuilder: (BuildContext context) {
                        return citySuggestions
                            .map<PopupMenuItem<String>>((String value) {
                          return PopupMenuItem(
                              value: value, child: Text(value));
                        }).toList();
                      },
                    )
                  : null,
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
              hintText: citySuggestions.isEmpty
                  ? "Entrez d'abord un code postal"
                  : null,
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
            readOnly: true,
            style: TextStyle(fontSize: (maxWidth * 0.018).clamp(14.0, 20.0)),
          ),
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

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: isTabletDevice
                ? _buildTabletLayout()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.go('/parent-second-info',
                              extra: widget.childId),
                          style: IconButton.styleFrom(
                            backgroundColor: lightBlue,
                            foregroundColor: primaryBlue,
                            padding: EdgeInsets.all(12),
                          ),
                        ),
                        SizedBox(height: 20),
                        if (!_hasAskedAddressQuestion) ...[
                          // Question sur l'adresse
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
                                          Icons.home_outlined,
                                          color: primaryBlue,
                                          size: 24,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "Adresse parent 2",
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
                                    "L'adresse du parent 2 est-elle différente de celle du parent 1 ?",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 30),

                          Center(
                            child: Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: lightBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_on,
                                size: 80,
                                color: primaryBlue,
                              ),
                            ),
                          ),

                          SizedBox(height: 40),

                          _buildButton(
                            text: "Oui, adresse différente",
                            icon: Icons.add_location_alt,
                            onPressed: () {
                              setState(() {
                                _showAddressForm = true;
                                _hasAskedAddressQuestion = true;
                              });
                            },
                            color: primaryBlue,
                            isLoading: false,
                          ),

                          SizedBox(height: 20),

                          _buildButton(
                            text: "Non, même adresse",
                            icon: Icons.home,
                            onPressed: () {
                              setState(() {
                                _showAddressForm = false;
                                _hasAskedAddressQuestion = true;
                              });
                            },
                            color: Colors.grey.shade400,
                            isLoading: false,
                          ),
                        ] else if (_showAddressForm) ...[
                          // Formulaire d'adresse
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
                                          Icons.home_outlined,
                                          color: primaryBlue,
                                          size: 24,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        "Adresse parent 2",
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
                                    "Veuillez renseigner l'adresse du parent 2 :",
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
                          _buildAddressField(
                              "Adresse", addressController, Icons.location_on),
                          _buildPostalCodeField(),
                          _buildCityDropdown(),
                          SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 1,
                                child: _buildSecondaryButton(
                                  text: "Retour",
                                  icon: Icons.arrow_back,
                                  onPressed: () {
                                    setState(() {
                                      _hasAskedAddressQuestion = false;
                                      _showAddressForm = false;
                                      addressController.clear();
                                      postalCodeController.clear();
                                      cityController.clear();
                                      citySuggestions.clear();
                                    });
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
                                      _isLoading ? null : _saveAddressInfo,
                                  color: primaryBlue,
                                  isLoading: _isLoading,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Confirmation même adresse
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green.shade600,
                                      size: 30,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "Confirmation",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.green.shade300),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.home,
                                          color: Colors.green.shade600,
                                          size: 24,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Le parent 2 utilisera la même adresse que le parent 1",
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 40),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 1,
                                child: _buildSecondaryButton(
                                  text: "Modifier",
                                  icon: Icons.edit,
                                  onPressed: () {
                                    setState(() {
                                      _hasAskedAddressQuestion = false;
                                      _showAddressForm = false;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  icon: _isLoading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : Icon(Icons.check,
                                          color: Colors.white, size: 22),
                                  label: Text(
                                    "Confirmer",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onPressed:
                                      _isLoading ? null : _saveAddressInfo,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 15),
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

  Widget _buildAddressField(
      String label, TextEditingController controller, IconData icon) {
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
            autofillHints: const [AutofillHints.streetAddressLine1],
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
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPostalCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          "Code postal",
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
            controller: postalCodeController,
            keyboardType: TextInputType.number,
            maxLength: 5,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: _fetchCities,
            autocorrect: true,
            enableSuggestions: true,
            autofillHints: const [AutofillHints.postalCode],
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.map, color: primaryBlue),
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
              suffixIcon: _isLoading
                  ? Container(
                      padding: EdgeInsets.all(12),
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: primaryBlue,
                        strokeWidth: 2,
                      ),
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
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
            controller: cityController,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.location_city, color: primaryBlue),
              suffixIcon: citySuggestions.isNotEmpty
                  ? PopupMenuButton<String>(
                      icon: Icon(Icons.arrow_drop_down, color: primaryBlue),
                      onSelected: (String value) {
                        setState(() {
                          cityController.text = value;
                        });
                      },
                      itemBuilder: (BuildContext context) {
                        return citySuggestions
                            .map<PopupMenuItem<String>>((String value) {
                          return PopupMenuItem(
                              value: value, child: Text(value));
                        }).toList();
                      },
                    )
                  : null,
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
              hintText: citySuggestions.isEmpty
                  ? "Entrez d'abord un code postal"
                  : null,
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
            readOnly: true,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      structureName,
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
                      Icons.home,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Adresse Parent 2',
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
}
