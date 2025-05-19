import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ChildPickupAuthScreen extends StatefulWidget {
  final String childId;

  const ChildPickupAuthScreen({Key? key, required this.childId})
      : super(key: key);

  @override
  _ChildPickupAuthScreenState createState() => _ChildPickupAuthScreenState();
}

class _ChildPickupAuthScreenState extends State<ChildPickupAuthScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  int _selectedIndex = 2; // Pour la barre de navigation du bas

  // Variables pour les parents
  String? _parent1Name;
  bool _parent1Authorized = true; // Toujours autorisé

  String? _parent2Name;
  bool? _parent2Authorized;
  bool _hasParent2 = false;

  // Variables pour les personnes autorisées supplémentaires
  bool _addExtraPerson = false;
  List<AuthorizedPerson> _authorizedPersons = [];

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
    _loadParentsInfo();
  }

  // Méthode pour charger les informations des parents
  Future<void> _loadParentsInfo() async {
    setState(() => _isLoading = true);

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

      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId au lieu de user.uid
          .collection('children')
          .doc(widget.childId)
          .get();

      if (childDoc.exists) {
        final data = childDoc.data();

        // Récupérer les infos du parent 1
        if (data != null && data['parent1'] != null) {
          final parent1 = data['parent1'];
          setState(() {
            _parent1Name = "${parent1['firstName']} ${parent1['lastName']}";
          });
        }

        // Récupérer les infos du parent 2 s'il existe
        if (data != null && data['parent2'] != null) {
          final parent2 = data['parent2'];
          setState(() {
            _parent2Name = "${parent2['firstName']} ${parent2['lastName']}";
            _hasParent2 = true;
            _parent2Authorized = null; // Initialement pas défini
          });
        }
      }
    } catch (e) {
      print("Erreur lors du chargement des informations: $e");
      _showError("Erreur lors du chargement des informations");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Méthode pour ajouter une personne autorisée
  void _addAuthorizedPerson() {
    setState(() {
      _authorizedPersons.add(AuthorizedPerson());
    });
  }

  // Méthode pour supprimer une personne autorisée
  void _removeAuthorizedPerson(int index) {
    setState(() {
      _authorizedPersons.removeAt(index);
    });
  }

  // Méthode pour sauvegarder toutes les informations
  Future<void> _savePickupAuthorizations() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String currentUserEmail = user?.email?.toLowerCase() ?? '';
    // Vérification du parent 2 si présent
    if (_hasParent2 && _parent2Authorized == null) {
      _showError(
          "Veuillez indiquer si le second parent est autorisé à récupérer l'enfant");
      return;
    }

    // Vérification des personnes autorisées
    for (var i = 0; i < _authorizedPersons.length; i++) {
      final person = _authorizedPersons[i];
      if (person.firstName.isEmpty ||
          person.lastName.isEmpty ||
          person.phone.isEmpty) {
        _showError(
            "Veuillez compléter toutes les informations pour la personne ${i + 1}");
        return;
      }

      // Vérification du format du téléphone
      if (person.phone.length != 10 ||
          !RegExp(r'^\d{10}$').hasMatch(person.phone)) {
        _showError(
            "Le numéro de téléphone doit contenir 10 chiffres pour la personne ${i + 1}");
        return;
      }
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

      // Préparation des données pour Firestore
      final Map<String, dynamic> authorizedPersonsList = {};
      for (var i = 0; i < _authorizedPersons.length; i++) {
        final person = _authorizedPersons[i];
        authorizedPersonsList['person${i + 1}'] = {
          'firstName': person.firstName,
          'lastName': person.lastName,
          'phone': person.phone,
        };
      }

      // Mise à jour de Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .update({
        'authorizedPickup': {
          'parent1': true,
          'parent2': _hasParent2 ? _parent2Authorized : false,
          'extraPersons': authorizedPersonsList,
        },
        'lastUpdatedBy': currentUserEmail,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      print("Autorisations de récupération sauvegardées avec succès");

      if (mounted) {
        context.go('/child-meal-info', extra: widget.childId);
      }
    } catch (e) {
      print("Erreur lors de la sauvegarde des autorisations: $e");
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
                      Icons.people_alt_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      // Ajout de Flexible pour gérer l'overflow
                      child: Text(
                        '08 - Autorisé à récupérer',
                        style: TextStyle(
                          fontSize: 18, // Taille réduite pour éviter l'overflow
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow
                            .ellipsis, // Gestion explicite de l'overflow
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
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryBlue))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
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

                        // Main card
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
                                        Icons.person_pin_circle_rounded,
                                        color: primaryBlue,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Personnes autorisées à récupérer l'enfant",
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
                                  "Sélectionnez les personnes autorisées à récupérer l'enfant à la structure d'accueil.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Parent 1 (toujours autorisé)
                                if (_parent1Name != null)
                                  _buildParentRow(
                                    _parent1Name!,
                                    true,
                                    (value) {}, // Ne pas changer, toujours autorisé
                                    enabled: false,
                                  ),

                                const SizedBox(height: 12),

                                // Parent 2 s'il existe
                                if (_hasParent2 && _parent2Name != null)
                                  Column(
                                    children: [
                                      _buildParentRow(_parent2Name!,
                                          _parent2Authorized ?? false, (value) {
                                        setState(
                                            () => _parent2Authorized = value);
                                      }),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Extra people section
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
                                        Icons.person_pin_circle_rounded,
                                        color: primaryBlue,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Personnes autorisées à récupérer l'enfant",
                                        style: TextStyle(
                                          fontSize: 16, // Taille réduite
                                          fontWeight: FontWeight.bold,
                                          color: primaryBlue,
                                        ),
                                        maxLines:
                                            2, // Permet d'utiliser deux lignes si nécessaire
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Ajouter une autre personne ?",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Switch(
                                      value: _addExtraPerson,
                                      onChanged: (value) {
                                        setState(() {
                                          _addExtraPerson = value;
                                          if (!value) {
                                            _authorizedPersons.clear();
                                          }
                                        });
                                      },
                                      activeColor: primaryBlue,
                                    ),
                                  ],
                                ),
                                if (_addExtraPerson) ...[
                                  const SizedBox(height: 16),
                                  ..._authorizedPersons
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final person = entry.value;
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 16),
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Personne ${index + 1}",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: primaryBlue,
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete,
                                                    color: primaryRed),
                                                onPressed: () =>
                                                    _removeAuthorizedPerson(
                                                        index),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _buildPersonField(
                                            "Prénom",
                                            person.firstNameController,
                                          ),
                                          const SizedBox(height: 12),
                                          _buildPersonField(
                                            "Nom",
                                            person.lastNameController,
                                          ),
                                          const SizedBox(height: 12),
                                          _buildPersonField(
                                            "Téléphone",
                                            person.phoneController,
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                  10),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),

                                  // Bouton pour ajouter une personne
                                  Center(
                                    child: OutlinedButton.icon(
                                      onPressed: _addAuthorizedPerson,
                                      icon: Icon(Icons.add, color: primaryBlue),
                                      label: Text(
                                        "Ajouter une personne",
                                        style: TextStyle(color: primaryBlue),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: primaryBlue),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
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
                            onPressed:
                                _isSaving ? null : _savePickupAuthorizations,
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

  Widget _buildParentRow(
      String name, bool isAuthorized, Function(bool) onChanged,
      {bool enabled = true}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 2),
            blurRadius: 5,
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            children: [
              Text(
                "Autorisé",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Switch(
                value: isAuthorized,
                onChanged: enabled ? onChanged : null,
                activeColor: primaryBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? inputFormatters}) {
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
          labelText: label,
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
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

// Classe pour les personnes autorisées additionnelles
class AuthorizedPerson {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String get firstName => firstNameController.text.trim();
  String get lastName => lastNameController.text.trim();
  String get phone => phoneController.text.trim();

  AuthorizedPerson();

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
  }
}
