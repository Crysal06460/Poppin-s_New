// photo_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

class PhotoManagementScreen extends StatefulWidget {
  final String? childId;
  const PhotoManagementScreen({Key? key, this.childId}) : super(key: key);

  @override
  _PhotoManagementScreenState createState() => _PhotoManagementScreenState();
}

class _PhotoManagementScreenState extends State<PhotoManagementScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();
  String structureId = ''; // Ajouter cette variable

  // Définition des couleurs de la palette
  static const Color primaryColor = Color(0xFF3D9DF2); // Bleu #3D9DF2
  static const Color secondaryColor = Color(0xFFDFE9F2); // Bleu clair #DFE9F2

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Nouvelle méthode pour initialiser les données
  Future<void> _initializeData() async {
    await _getStructureId();
    await _loadChildren();

    // Si un childId spécifique est fourni, ouvrir directement le dialogue pour cet enfant
    if (widget.childId != null && widget.childId!.isNotEmpty) {
      // Attendre que les enfants soient chargés avant d'ouvrir le dialogue
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSpecificChild(widget.childId!);
      });
    }
  }

  // Nouvelle méthode pour récupérer l'ID de structure (similaire à EditScheduleScreen)
  Future<void> _getStructureId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Par défaut, l'ID de structure est l'ID de l'utilisateur
      structureId = user.uid;

      // Vérifier si l'utilisateur est un membre MAM
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "🔄 PhotoManagement: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération de l'ID de structure: $e");
      // En cas d'erreur, utiliser l'ID utilisateur par défaut
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        structureId = user.uid;
      }
    }
  }

  Future<void> _loadSpecificChild(String childId) async {
    try {
      // Attendre que les enfants soient chargés
      if (isLoading) {
        await Future.delayed(Duration(milliseconds: 500));
        return _loadSpecificChild(childId);
      }

      // Trouver l'enfant dans la liste
      final enfant = enfants.firstWhere(
        (e) => e['id'] == childId,
        orElse: () => {'id': '', 'prenom': '', 'photoUrl': ''},
      );

      // Si l'enfant est trouvé, ouvrir le dialogue
      if (enfant['id'].isNotEmpty) {
        _showPhotoDialog(
          enfant['prenom'],
          enfant['photoUrl'],
          enfant['id'],
        );
      }
    } catch (e) {
      print("Erreur lors du chargement de l'enfant spécifique: $e");
    }
  }

  // Méthode _loadChildren modifiée pour supporter le système MAM
  Future<void> _loadChildren() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      // Si l'ID de structure n'est pas encore récupéré, attendre un peu et réessayer
      if (structureId.isEmpty) {
        await _getStructureId();
        // Si toujours vide, utiliser l'ID utilisateur par défaut
        if (structureId.isEmpty) {
          structureId = user.uid;
        }
      }

      // Récupérer l'email de l'utilisateur actuel
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      // Récupérer le type de structure (MAM ou AssistanteMaternelle)
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      final String structureType = structureDoc.exists
          ? (structureDoc.data()?['structureType'] ?? "AssistanteMaternelle")
          : "AssistanteMaternelle";

      // Récupérer tous les enfants de la structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'prenom': data['firstName'] ?? 'Sans nom',
          'photoUrl': data['photoUrl'],
          'assignedMemberEmail':
              data['assignedMemberEmail']?.toString().toLowerCase() ?? '',
        };
      }).toList();

      // Appliquer le filtrage selon le type de structure
      List<Map<String, dynamic>> filteredChildren = [];

      if (structureType == "MAM") {
        // Pour une MAM: filtrer par assignedMemberEmail
        filteredChildren = allChildren.where((child) {
          return child['assignedMemberEmail'] == currentUserEmail;
        }).toList();

        print(
            "👨‍👧‍👦 PhotoManagement: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 PhotoManagement: Assistante Maternelle - affichage de tous les enfants");
      }

      enfants = filteredChildren;
      setState(() => isLoading = false);
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _updatePhoto(String childId, String currentPhotoUrl) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        // Réduire la qualité/taille de l'image
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image == null) return;

      setState(() => isLoading = true);

      // Convertir l'image en bytes
      final bytes = await File(image.path).readAsBytes();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Utiliser une méthode d'upload alternative (putData au lieu de putFile)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('images_temp/${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Upload avec bytes et timeout plus long
      await storageRef
          .putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          )
          .timeout(Duration(minutes: 2));

      final newPhotoUrl = await storageRef.getDownloadURL();

      // Utiliser le bon structureId pour la mise à jour
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId au lieu de user.uid
          .collection('children')
          .doc(childId)
          .update({'photoUrl': newPhotoUrl});

      await _loadChildren();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo mise à jour avec succès'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print("Erreur détaillée: $e");

      // Afficher un message d'erreur plus informatif
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString().substring(0, 100)}...'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showPhotoDialog(String name, String? photoUrl, String childId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 24),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: secondaryColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.error_outline,
                              size: 50,
                              color: Colors.red,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 100,
                        color: primaryColor.withOpacity(0.7),
                      ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updatePhoto(childId, photoUrl ?? '');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_camera, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Changer la photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête avec fond de couleur - Identique à StructureManagementScreen
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
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/dashboard');
                        }
                      },
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
                        "Gestion des photos",
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
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : enfants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_alt_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Aucun enfant enregistré',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: secondaryColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Appuyez sur un enfant pour visualiser ou modifier sa photo',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: enfants.length,
                                itemBuilder: (context, index) {
                                  final enfant = enfants[index];
                                  return InkWell(
                                    onTap: () => _showPhotoDialog(
                                      enfant['prenom'],
                                      enfant['photoUrl'],
                                      enfant['id'],
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: secondaryColor,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              color: secondaryColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: primaryColor
                                                    .withOpacity(0.3),
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: enfant['photoUrl'] != null &&
                                                    enfant['photoUrl']
                                                        .isNotEmpty
                                                ? ClipOval(
                                                    child: Image.network(
                                                      enfant['photoUrl'],
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (context,
                                                          child,
                                                          loadingProgress) {
                                                        if (loadingProgress ==
                                                            null) return child;
                                                        return Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                            color: primaryColor,
                                                            value: loadingProgress
                                                                        .expectedTotalBytes !=
                                                                    null
                                                                ? loadingProgress
                                                                        .cumulativeBytesLoaded /
                                                                    loadingProgress
                                                                        .expectedTotalBytes!
                                                                : null,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.person,
                                                    size: 60,
                                                    color: primaryColor
                                                        .withOpacity(0.5),
                                                  ),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            enfant['prenom'],
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  primaryColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Modifier',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: primaryColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
