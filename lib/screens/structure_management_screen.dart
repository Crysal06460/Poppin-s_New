// structure_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  String? _logoUrl;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

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

      // Obtenir le bon ID de structure pour n'importe quel membre
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
          _logoUrl = data['logoUrl'];
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

      // Obtenir le bon ID de structure
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
      // Obtenir le bon ID de structure
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
      });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête avec fond de couleur - Identique à HomeScreen
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
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    // Bouton retour avec meilleur contraste
                    GestureDetector(
                      onTap: () => context.go('/dashboard'),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Titre avec meilleur style
                    Expanded(
                      child: Text(
                        "Gestion de la structure",
                        style: TextStyle(
                          fontSize: 20,
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _updateLogo,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      shape: BoxShape.circle,
                                    ),
                                    child: _logoUrl != null
                                        ? ClipOval(
                                            child: Image.network(
                                              _logoUrl!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Icon(
                                            Icons.add_a_photo,
                                            size: 40,
                                            color: Colors.grey[400],
                                          ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Modifier le logo',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Nom de la structure',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer un nom';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Téléphone',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                              hintText: 'Ex: 0612345678',
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
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
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                              hintText: 'exemple@domaine.com',
                            ),
                            keyboardType: TextInputType.emailAddress,
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
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Adresse',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer une adresse';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 24),
                          Center(
                            child: ElevatedButton(
                              onPressed: _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                'Enregistrer les modifications',
                                style: TextStyle(fontSize: 16),
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
  }
}
