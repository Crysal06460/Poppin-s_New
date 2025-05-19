import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ParentAddressScreen extends StatefulWidget {
  final String childId;

  const ParentAddressScreen({Key? key, required this.childId})
      : super(key: key);

  @override
  _ParentAddressScreenState createState() => _ParentAddressScreenState();
}

class _ParentAddressScreenState extends State<ParentAddressScreen> {
  final TextEditingController addressController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  List<String> citySuggestions = [];
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

          // Important: vider et mettre à jour les suggestions
          List<String> newCities =
              cities.map((city) => city['nom'].toString()).toList();

          setState(() {
            citySuggestions = newCities;
            _isLoading = false;

            // Mettre à jour le champ de ville avec la première suggestion
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

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId au lieu de user.uid
          .collection('children')
          .doc(widget.childId)
          .update({
        'parentAddress': {
          'address': addressController.text,
          'postalCode': postalCodeController.text,
          'city': cityController.text,
        }
      });

      setState(() {
        _isLoading = false;
      });

      context.go('/add-second-parent', extra: widget.childId);
    } catch (e) {
      print("❌ Erreur Firestore: $e");
      setState(() {
        _isLoading = false;
      });
      _showError("Une erreur est survenue. Veuillez réessayer.");
    }
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
      // Déjà sur cette page - ne pas naviguer
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () =>
                        context.go('/parent-info', extra: widget.childId),
                    style: IconButton.styleFrom(
                      backgroundColor: lightBlue,
                      foregroundColor: primaryBlue,
                      padding: EdgeInsets.all(12),
                    ),
                  ),
                  SizedBox(height: 20),
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
                                "Adresse du parent",
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
                            "Veuillez renseigner l'adresse du parent :",
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
                  Center(
                    child: _buildButton(
                      text: "Suivant",
                      icon: Icons.arrow_forward,
                      onPressed: _isLoading ? null : _saveAddressInfo,
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
                      Icons.home,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Adresse Parent',
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
}
