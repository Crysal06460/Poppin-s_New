// structure_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class StructureManagementScreen extends StatefulWidget {
  const StructureManagementScreen({Key? key}) : super(key: key);

  @override
  _StructureManagementScreenState createState() =>
      _StructureManagementScreenState();
}

class _StructureManagementScreenState extends State<StructureManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  String? _logoUrl;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  String _pageTitle = 'Gestion de la structure';
  List<String> _citySuggestions = [];
  String _lastPostalLookup = '';
  bool _isFetchingCities = false;

  // Définition des couleurs de la palette
  static const Color primaryColor = Color(0xFF3D9DF2); // Bleu #3D9DF2
  static const Color secondaryColor = Color(0xFFDFE9F2); // Bleu clair #DFE9F2

  @override
  void initState() {
    super.initState();
    _loadStructureData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<String> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    // Vérifier si l'utilisateur est un membre MAM
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email?.toLowerCase() ?? '')
        .get();

    // Si c'est un membre MAM, obtenir l'ID de la structure associée
    if (userDoc.exists &&
        userDoc.data() != null &&
        userDoc.data()!.containsKey('structureId')) {
      return userDoc.data()!['structureId'];
    }

    // Par défaut, utiliser l'ID de l'utilisateur (cas d'un propriétaire de structure)
    return user.uid;
  }

  Future<void> _loadStructureData() async {
    try {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      final String? userEmail = user?.email?.toLowerCase();
      String? userRole;
      if (userEmail != null && userEmail.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userEmail)
              .get();
          if (userDoc.exists) {
            userRole = (userDoc.data()?['role'] ?? '').toString().toLowerCase();
          }
        } catch (e) {
          print('⚠️ Impossible de récupérer le rôle utilisateur: $e');
        }
      }

      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['structureName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? '';
          _addressController.text = data['address'] ?? '';
          _cityController.text = data['city'] ?? '';
          // FIX: Fallback sur 'zipCode' si 'postalCode' est vide
          _postalCodeController.text = data['postalCode'] ?? data['zipCode'] ?? '';
          _logoUrl = data['logoUrl'];
          if (userRole == 'assistantfromparent') {
            _pageTitle = 'Modifier ses coordonnées';
          } else {
            _pageTitle = 'Gestion de la structure';
          }
          _isLoading = false;
        });
      } else {
        print("Document de structure non trouvé");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLogo() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isLoading = true);

      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Supprimer l'ancien logo s'il existe
      if (_logoUrl != null) {
        try {
          await FirebaseStorage.instance.refFromURL(_logoUrl!).delete();
        } catch (e) {
          print('Erreur lors de la suppression de l\'ancien logo: $e');
        }
      }

      // Upload du nouveau logo
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('structures/${structureId}/logo.jpg');

      await storageRef.putFile(File(image.path));
      final newLogoUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({'logoUrl': newLogoUrl});

      setState(() {
        _logoUrl = newLogoUrl;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo mis à jour avec succès')),
      );
    } catch (e) {
      print('Erreur lors de la mise à jour du logo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du logo')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({
        'structureName': _nameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'postalCode': _postalCodeController.text,
      });

      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email?.toLowerCase();
      if (userEmail != null && userEmail.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userEmail)
            .set({
          'phone': _phoneController.text,
          'address': _addressController.text,
          'city': _cityController.text,
          'postalCode': _postalCodeController.text,
          'structureName': _nameController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Modifications enregistrées avec succès')),
      );
    } catch (e) {
      print('Erreur lors de la sauvegarde: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePostalCodeChange(String value) async {
    final postalCode = value.trim();
    if (postalCode.length == 5 && RegExp(r'^\d{5}$').hasMatch(postalCode)) {
      if (postalCode == _lastPostalLookup) return;
      _lastPostalLookup = postalCode;
      await _fetchCitiesForPostalCode(postalCode);
    } else {
      setState(() {
        if (postalCode.isEmpty) {
          _cityController.clear();
        }
        _citySuggestions = [];
      });
    }
  }

  Future<void> _fetchCitiesForPostalCode(String postalCode) async {
    setState(() {
      _isFetchingCities = true;
      _citySuggestions = [];
    });

    try {
      final url = Uri.parse(
          'https://geo.api.gouv.fr/communes?codePostal=$postalCode&fields=nom');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<String> cities =
            data.map((city) => city['nom'].toString()).toSet().toList()..sort();

        setState(() {
          _citySuggestions = cities;
          if (cities.isNotEmpty) {
            _cityController.text = cities.first;
          } else {
            _cityController.clear();
          }
        });
      } else {
        print('⚠️ Erreur API villes: ${response.statusCode}');
        setState(() {
          _citySuggestions = [];
          _cityController.clear();
        });
      }
    } catch (e) {
      print('⚠️ Erreur récupération villes: $e');
      setState(() {
        _citySuggestions = [];
        _cityController.clear();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingCities = false;
        });
      }
    }
  }

  void _showCitySelectionSheet() {
    if (_citySuggestions.length <= 1) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _citySuggestions.length,
            itemBuilder: (context, index) {
              final city = _citySuggestions[index];
              return ListTile(
                title: Text(city),
                onTap: () {
                  setState(() {
                    _cityController.text = city;
                  });
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        );
      },
    );
  }

  String _getFullAddress() {
    final address = _addressController.text.trim();
    final postalCode = _postalCodeController.text.trim();
    final city = _cityController.text.trim();

    List<String> addressParts = [];

    if (address.isNotEmpty) addressParts.add(address);
    if (postalCode.isNotEmpty && city.isNotEmpty) {
      addressParts.add('$postalCode $city');
    } else {
      if (postalCode.isNotEmpty) addressParts.add(postalCode);
      if (city.isNotEmpty) addressParts.add(city);
    }

    return addressParts.join(', ');
  }

  Widget _buildTabletContent() {
    return LayoutBuilder(builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth;
      final double maxHeight = constraints.maxHeight;
      final double sideMargin = maxWidth * 0.03;
      final double columnGap = maxWidth * 0.025;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          sideMargin,
          maxHeight * 0.02,
          sideMargin,
          maxHeight * 0.02,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panneau latéral gauche (Informations et logo)
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
                  padding: EdgeInsets.all(maxWidth * 0.025),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Titre avec icône
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            color: primaryColor,
                            size: maxWidth * 0.07,
                          ),
                          SizedBox(width: maxWidth * 0.015),
                          Expanded(
                            child: Text(
                              "Informations",
                              style: TextStyle(
                                fontSize: maxWidth * 0.022,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Logo de la structure
                      GestureDetector(
                        onTap: _updateLogo,
                        child: Container(
                          width: maxWidth * 0.25,
                          height: maxWidth * 0.25,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: _logoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    _logoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                      Icons.add_a_photo,
                                      size: maxWidth * 0.08,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.add_a_photo,
                                  size: maxWidth * 0.08,
                                  color: Colors.grey[400],
                                ),
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      // Bouton "Modifier le logo"
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _updateLogo,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: maxWidth * 0.04,
                              vertical: maxHeight * 0.015,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  color: primaryColor,
                                  size: maxWidth * 0.02,
                                ),
                                SizedBox(width: maxWidth * 0.01),
                                Text(
                                  'Modifier le logo',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: maxWidth * 0.018,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Informations actuelles
                      _buildInfoCard(
                        icon: Icons.business,
                        label: "Nom actuel",
                        value: _nameController.text.isNotEmpty
                            ? _nameController.text
                            : "Non défini",
                        maxWidth: maxWidth,
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      _buildInfoCard(
                        icon: Icons.phone,
                        label: "Téléphone actuel",
                        value: _phoneController.text.isNotEmpty
                            ? _phoneController.text
                            : "Non défini",
                        maxWidth: maxWidth,
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      _buildInfoCard(
                        icon: Icons.email,
                        label: "Email actuel",
                        value: _emailController.text.isNotEmpty
                            ? _emailController.text
                            : "Non défini",
                        maxWidth: maxWidth,
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      _buildInfoCard(
                        icon: Icons.location_on,
                        label: "Adresse actuelle",
                        value: _getFullAddress().isNotEmpty
                            ? _getFullAddress()
                            : "Non définie",
                        maxWidth: maxWidth,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Panneau de droite (Formulaire de modification)
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
                  padding: EdgeInsets.all(maxWidth * 0.025),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre
                      Text(
                        "Modifier les informations",
                        style: TextStyle(
                          fontSize: maxWidth * 0.022,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.03),

                      // Formulaire
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            children: [
                              // Nom de la structure
                              _buildTabletFormField(
                                controller: _nameController,
                                label: 'Nom de la structure',
                                icon: Icons.business,
                                maxWidth: maxWidth,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez entrer un nom';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: maxHeight * 0.025),

                              // Téléphone
                              _buildTabletFormField(
                                controller: _phoneController,
                                label: 'Téléphone',
                                icon: Icons.phone,
                                maxWidth: maxWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                maxLength: 10,
                                hintText: 'Ex: 0612345678',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez entrer un numéro de téléphone';
                                  }
                                  if (value.length != 10) {
                                    return 'Le numéro doit contenir 10 chiffres';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: maxHeight * 0.025),

                              // Email
                              _buildTabletFormField(
                                controller: _emailController,
                                label: 'Email',
                                icon: Icons.email,
                                maxWidth: maxWidth,
                                keyboardType: TextInputType.emailAddress,
                                hintText: 'exemple@domaine.com',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez entrer un email';
                                  }
                                  if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Veuillez entrer un email valide (avec @ et .)';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: maxHeight * 0.025),

                              // Adresse (rue, numéro)
                              _buildTabletFormField(
                                controller: _addressController,
                                label: 'Adresse (rue, numéro)',
                                icon: Icons.location_on,
                                maxWidth: maxWidth,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez entrer une adresse';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: maxHeight * 0.025),

                              // Code postal
                              _buildTabletFormField(
                                controller: _postalCodeController,
                                label: 'Code postal',
                                icon: Icons.markunread_mailbox,
                                maxWidth: maxWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                maxLength: 5,
                                hintText: 'Ex: 06600',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez entrer un code postal';
                                  }
                                  if (value.length != 5) {
                                    return 'Le code postal doit contenir 5 chiffres';
                                  }
                                  return null;
                                },
                                onChanged: _handlePostalCodeChange,
                                suffixIcon: _isFetchingCities
                                    ? Padding(
                                        padding:
                                            EdgeInsets.all(maxWidth * 0.015),
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                                primaryColor),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),

                              SizedBox(height: maxHeight * 0.025),

                              // Ville
                              _buildTabletFormField(
                                controller: _cityController,
                                label: 'Ville',
                                icon: Icons.location_city,
                                maxWidth: maxWidth,
                                hintText: 'Ex: Antibes',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez entrer une ville';
                                  }
                                  return null;
                                },
                                onTap: _citySuggestions.length > 1
                                    ? _showCitySelectionSheet
                                    : null,
                                suffixIcon: _citySuggestions.length > 1
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.expand_more,
                                          color: primaryColor,
                                        ),
                                        onPressed: _showCitySelectionSheet,
                                      )
                                    : null,
                              ),

                              SizedBox(height: maxHeight * 0.04),

                              // Bouton Supprimer mon compte
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.2),
                                        offset: const Offset(0, 3),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          context.go('/account-deletion'),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: maxWidth * 0.06,
                                          vertical: maxHeight * 0.018,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.red.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.delete_forever,
                                              color: Colors.red.shade600,
                                              size: maxWidth * 0.022,
                                            ),
                                            SizedBox(width: maxWidth * 0.015),
                                            Text(
                                              'Supprimer mon compte',
                                              style: TextStyle(
                                                fontSize: maxWidth * 0.018,
                                                color: Colors.red.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: maxHeight * 0.03),

                              // Bouton d'enregistrement
                              Center(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _saveChanges,
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: maxWidth * 0.08,
                                        vertical: maxHeight * 0.02,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            primaryColor,
                                            primaryColor.withOpacity(0.8)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                primaryColor.withOpacity(0.3),
                                            offset: const Offset(0, 4),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.save,
                                            color: Colors.white,
                                            size: maxWidth * 0.022,
                                          ),
                                          SizedBox(width: maxWidth * 0.015),
                                          Text(
                                            'Enregistrer les modifications',
                                            style: TextStyle(
                                              fontSize: maxWidth * 0.018,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required double maxWidth,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(maxWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: primaryColor,
                size: maxWidth * 0.02,
              ),
              SizedBox(width: maxWidth * 0.01),
              Text(
                label,
                style: TextStyle(
                  fontSize: maxWidth * 0.014,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: maxWidth * 0.01),
          Text(
            value,
            style: TextStyle(
              fontSize: maxWidth * 0.016,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabletFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double maxWidth,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        maxLines: maxLines,
        validator: validator,
        readOnly: readOnly,
        onChanged: onChanged,
        onTap: onTap,
        style: TextStyle(
          fontSize: maxWidth * 0.018,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Container(
            margin: EdgeInsets.all(maxWidth * 0.015),
            padding: EdgeInsets.all(maxWidth * 0.01),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: maxWidth * 0.022,
            ),
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: maxWidth * 0.016,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: maxWidth * 0.015,
          ),
          filled: true,
          fillColor: Colors.white,
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
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: maxWidth * 0.04,
            vertical: maxWidth * 0.02,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildPhoneContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo section
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onTap: _updateLogo,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: _logoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  _logoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.add_a_photo,
                                    size: 50,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.add_a_photo,
                                size: 50,
                                color: Colors.grey[400],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          color: primaryColor,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Modifier le logo',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // Formulaire
            _buildPhoneFormField(
              controller: _nameController,
              label: 'Nom de la structure',
              icon: Icons.business,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un nom';
                }
                return null;
              },
            ),
            SizedBox(height: 20),

            _buildPhoneFormField(
              controller: _phoneController,
              label: 'Téléphone',
              icon: Icons.phone,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              hintText: 'Ex: 0612345678',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un numéro de téléphone';
                }
                if (value.length != 10) {
                  return 'Le numéro doit contenir 10 chiffres';
                }
                return null;
              },
            ),

            _buildPhoneFormField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              hintText: 'exemple@domaine.com',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Veuillez entrer un email valide (avec @ et .)';
                }
                return null;
              },
            ),
            SizedBox(height: 20),

            _buildPhoneFormField(
              controller: _addressController,
              label: 'Adresse (rue, numéro)',
              icon: Icons.location_on,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer une adresse';
                }
                return null;
              },
            ),
            SizedBox(height: 20),

            _buildPhoneFormField(
              controller: _postalCodeController,
              label: 'Code postal',
              icon: Icons.markunread_mailbox,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 5,
              hintText: 'Ex: 06600',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un code postal';
                }
                if (value.length != 5) {
                  return 'Le code postal doit contenir 5 chiffres';
                }
                return null;
              },
              onChanged: _handlePostalCodeChange,
              suffixIcon: _isFetchingCities
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),

            _buildPhoneFormField(
              controller: _cityController,
              label: 'Ville',
              icon: Icons.location_city,
              hintText: 'Ex: Antibes',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer une ville';
                }
                return null;
              },
              onTap:
                  _citySuggestions.length > 1 ? _showCitySelectionSheet : null,
              suffixIcon: _citySuggestions.length > 1
                  ? IconButton(
                      icon: const Icon(Icons.expand_more),
                      color: primaryColor,
                      onPressed: _showCitySelectionSheet,
                    )
                  : null,
            ),
            SizedBox(height: 32),

            // Bouton Supprimer mon compte
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.go('/account-deletion'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_forever,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Supprimer mon compte',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 24),

            // Bouton d'enregistrement
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _saveChanges,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.save,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Enregistrer les modifications',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        maxLines: maxLines,
        validator: validator,
        readOnly: readOnly,
        onChanged: onChanged,
        onTap: onTap,
        style: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white,
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
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor,
                  primaryColor.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(screenSize.width * 0.06),
                bottomRight: Radius.circular(screenSize.width * 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * 0.02,
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * (isTablet ? 0.02 : 0.025),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/dashboard'),
                      child: Container(
                        padding: EdgeInsets.all(
                            screenSize.width * (isTablet ? 0.015 : 0.02)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: screenSize.width * (isTablet ? 0.025 : 0.06),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: screenSize.width * (isTablet ? 0.02 : 0.04)),
                    Expanded(
                      child: Text(
                        "Gestion de la structure",
                        style: TextStyle(
                          fontSize:
                              screenSize.width * (isTablet ? 0.028 : 0.055),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal
          _isLoading
              ? Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                )
              : Expanded(
                  child:
                      isTablet ? _buildTabletContent() : _buildPhoneContent(),
                ),
        ],
      ),
    );
  }
}
