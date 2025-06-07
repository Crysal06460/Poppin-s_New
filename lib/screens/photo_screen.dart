import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import '../services/photo_cleanup_service.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({Key? key}) : super(key: key);

  @override
  _PhotosScreenState createState() => _PhotosScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

DateTime _selectedDate = DateTime.now();
bool _showingPastPhotos = false;
List<Map<String, dynamic>> _pastPhotos = [];
bool _loadingPastPhotos = false;

class _PhotosScreenState extends State<PhotosScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  int _selectedIndex = 1;
  bool _isUploadingFile = false;
  Uint8List? _webImage;
  XFile? _pickedFile;
  String _mediaTime = '';

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  Color primaryColor =
      primaryBlue; // Utiliser directement la variable déjà définie
  Color secondaryColor = lightBlue;

  @override
  void initState() {
    super.initState();

    // Initialisation de l'animation pour le message d'avertissement

    initializeDateFormatting('fr_FR', null).then((_) {
      _loadEnfantsDuJour();
      _performPhotoCleanup();
    });
  }

  Future<void> _performPhotoCleanup() async {
    try {
      await PhotoCleanupService.checkAndCleanupPhotos();
    } catch (e) {
      print("Erreur lors du nettoyage automatique des photos: $e");
      // Ne pas montrer d'erreur à l'utilisateur car c'est un processus en arrière-plan
    }
  }

  Future<void> _selectMediaTime(
      StateSetter setState, Function(String) onTimeSelected) async {
    // Obtenir l'heure actuelle ou celle déjà saisie
    TimeOfDay initialTime;
    if (_mediaTime.isNotEmpty) {
      final parts = _mediaTime.split(':');
      initialTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } else {
      initialTime = TimeOfDay.now();
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: primaryColor,
              dayPeriodTextColor: primaryColor,
              dialHandColor: primaryColor,
              dialBackgroundColor: lightBlue.withOpacity(0.2),
              // Fix pour le rectangle bleu
              hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? primaryColor.withOpacity(0.15)
                      : Colors.transparent),
              // Forme pour les conteneurs heure/minute
              hourMinuteShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        onTimeSelected(timeString);
      });
    }
  }

  Future<void> _loadEnfantsDuJour() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
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
              "🔄 Photos: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      final today = DateTime.now();
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      // Récupérer la structure pour déterminer le type
      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureSnapshot.exists) {
        setState(() {
          structureName =
              structureSnapshot['structureName'] ?? 'Structure inconnue';
        });
      }

      final String structureType = structureSnapshot.exists
          ? (structureSnapshot.data()?['structureType'] ??
              "AssistanteMaternelle")
          : "AssistanteMaternelle";

      // Récupérer tous les enfants de la structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      // Appliquer le filtrage selon le type de structure (MAM ou AssistanteMaternelle)
      List<Map<String, dynamic>> filteredChildren = [];

      if (structureType == "MAM") {
        // Pour une MAM: filtrer par assignedMemberEmail
        filteredChildren = allChildren.where((child) {
          String assignedEmail =
              child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
          return assignedEmail == currentUserEmail;
        }).toList();

        print(
            "👨‍👧‍👦 Photos: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Photos: Assistante Maternelle - affichage de tous les enfants");
      }

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui
      enfants = [];
      for (var child in filteredChildren) {
        if (child['schedule'] != null &&
            child['schedule'][capitalizedWeekday] != null) {
          String? photoUrl = child['photoUrl'];
          // Récupérer l'autorisation photos
          bool? photosAllowed = child['authorizations']?['photos'] ?? true;
          enfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'photosAllowed': photosAllowed,
            'structureId':
                structureId, // Ajouter l'ID de structure pour les requêtes futures
          });
        }
      }
      setState(() => isLoading = false);
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickImage(String childId, StateSetter setStateDialog) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setStateDialog(() {
          _pickedFile = image;
          if (kIsWeb) {
            image.readAsBytes().then((value) {
              setStateDialog(() => _webImage = value);
              print("Image web chargée: ${value.length} bytes");
            });
          }
        });
      }
    } catch (e) {
      print("Erreur lors de la sélection: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la sélection: $e")));
    }
  }

  Future<void> _pickCameraImage(
      String childId, StateSetter setStateDialog) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setStateDialog(() {
          _pickedFile = image;
          if (kIsWeb) {
            image.readAsBytes().then((value) {
              setStateDialog(() => _webImage = value);
              print("Image web chargée: ${value.length} bytes");
            });
          }
        });
      }
    } catch (e) {
      print("Erreur lors de la prise de photo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la prise de photo: $e")));
    }
  }

  Future<void> _uploadAndSaveImage(String childId) async {
    if (_pickedFile == null) return;

    setState(() => _isUploadingFile = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      final ref = FirebaseStorage.instance
          .ref()
          .child('medias')
          .child(user.uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      String? downloadUrl;

      try {
        print("Début upload image...");

        if (kIsWeb && _webImage != null) {
          await ref
              .putData(
                _webImage!,
                SettableMetadata(contentType: 'image/jpeg'),
              )
              .timeout(Duration(minutes: 2));
        } else {
          final file = File(_pickedFile!.path);
          final bytes = await file.readAsBytes();
          await ref
              .putData(
                bytes,
                SettableMetadata(contentType: 'image/jpeg'),
              )
              .timeout(Duration(minutes: 2));
        }

        print("Image uploadée avec succès");
        downloadUrl = await ref.getDownloadURL();

        // Mise à jour Firestore
        if (downloadUrl != null) {
          await _addMediaToFirebase(childId, downloadUrl);
        }
      } catch (e) {
        print("Erreur détaillée: $e");

        if (e is FirebaseException) {
          print("Code d'erreur Firebase: ${e.code}");
          print("Message Firebase: ${e.message}");
        }

        rethrow;
      }
    } catch (e) {
      print("Erreur globale: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingFile = false);
    }
  }

  void _showAddMediaPopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String? errorMessage;
    String localMediaTime = _mediaTime;
    bool showPhotoWarning = enfant['photosAllowed'] == false;
    bool showPreview = false;
    Uint8List? localWebImage;
    XFile? localPickedFile;

    // Reset des valeurs globales
    _pickedFile = null;
    _webImage = null;

    // Déterminer si nous sommes sur iPad
    final bool isTabletDevice = isTablet(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              // Largeur adaptée pour iPad
              insetPadding: isTabletDevice
                  ? EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.25)
                  : EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête avec dégradé
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
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isTabletDevice ? 20 : 16,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTabletDevice ? 12 : 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.photo_camera,
                                color: Colors.white,
                                size: isTabletDevice ? 30 : 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Ajouter une photo - ${enfant['prenom']}",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 22 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (isTabletDevice) SizedBox(height: 4),
                                  if (isTabletDevice)
                                    Text(
                                      "Le ${DateFormat('d MMMM yyyy', 'fr_FR').format(DateTime.now())}",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Contenu du formulaire avec padding
                      Padding(
                        padding: EdgeInsets.all(isTabletDevice ? 24 : 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avertissement si autorisation refusée
                            if (showPhotoWarning)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.orange.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange.shade800,
                                          size: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Attention",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Lors de l'inscription de ${enfant['prenom']}, l'autorisation pour les photos n'a pas été donnée.",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Affichage de l'aperçu de la photo si disponible
                            if (_pickedFile != null) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Aperçu de la photo",
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Container(
                                      height: 200,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: kIsWeb
                                          ? _webImage != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.memory(
                                                    _webImage!,
                                                    fit: BoxFit.contain,
                                                  ),
                                                )
                                              : Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            primaryColor),
                                                  ),
                                                )
                                          : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.file(
                                                File(_pickedFile!.path),
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Heure de la photo
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Heure de la photo",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  InkWell(
                                    onTap: () =>
                                        _selectMediaTime(setState, (time) {
                                      localMediaTime = time;
                                      errorMessage = null;
                                    }),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: lightBlue,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: localMediaTime.isEmpty
                                              ? Colors.transparent
                                              : primaryColor.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            localMediaTime.isEmpty
                                                ? 'Choisir l\'heure'
                                                : localMediaTime,
                                            style: TextStyle(
                                              fontSize:
                                                  isTabletDevice ? 18 : 16,
                                              color: localMediaTime.isEmpty
                                                  ? Colors.grey.shade600
                                                  : primaryColor,
                                              fontWeight: localMediaTime.isEmpty
                                                  ? FontWeight.normal
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          Icon(
                                            Icons.access_time_rounded,
                                            color:
                                                primaryColor.withOpacity(0.7),
                                            size: isTabletDevice ? 24 : 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Options de choix (Appareil photo ou Galerie) - seulement si pas d'aperçu
                            if (_pickedFile == null)
                              Container(
                                margin: EdgeInsets.only(
                                    bottom: isTabletDevice ? 24 : 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Source de la photo",
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              if (localMediaTime.isEmpty) {
                                                setState(() {
                                                  errorMessage =
                                                      'Veuillez sélectionner une heure';
                                                });
                                                return;
                                              }
                                              _pickCameraImage(
                                                  enfant['id'], setState);
                                            },
                                            icon: Icon(Icons.camera_alt),
                                            label: Text('Appareil photo'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                vertical:
                                                    isTabletDevice ? 16 : 12,
                                                horizontal: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              if (localMediaTime.isEmpty) {
                                                setState(() {
                                                  errorMessage =
                                                      'Veuillez sélectionner une heure';
                                                });
                                                return;
                                              }
                                              _pickImage(
                                                  enfant['id'], setState);
                                            },
                                            icon: Icon(Icons.photo_library),
                                            label: Text('Galerie'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  primaryColor.withOpacity(0.8),
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                vertical:
                                                    isTabletDevice ? 16 : 12,
                                                horizontal: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                            // Message d'erreur si présent
                            if (errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: isTabletDevice ? 15 : 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                            // Boutons d'action
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Bouton Annuler
                                OutlinedButton(
                                  onPressed: () {
                                    _pickedFile = null;
                                    _webImage = null;
                                    Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isTabletDevice ? 24 : 16,
                                        vertical: isTabletDevice ? 16 : 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    "ANNULER",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 16 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),

                                // Bouton Confirmer - visible seulement quand une photo est sélectionnée
                                if (_pickedFile != null)
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (localMediaTime.isEmpty) {
                                        setState(() {
                                          errorMessage =
                                              'Veuillez sélectionner une heure';
                                        });
                                        return;
                                      }

                                      _mediaTime = localMediaTime;
                                      Navigator.of(context).pop();

                                      try {
                                        print(
                                            "Début de l'upload après confirmation");
                                        // Faire l'upload seulement après confirmation
                                        await _uploadAndSaveImage(childId);
                                        print("Upload terminé avec succès");
                                      } catch (e) {
                                        print(
                                            "Erreur capturée lors de l'upload: $e");
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      elevation: 2,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: isTabletDevice ? 32 : 24,
                                          vertical: isTabletDevice ? 16 : 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      "CONFIRMER",
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 16 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addMediaToFirebase(String childId, String mediaUrl) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference mediaRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('medias')
          .doc();

      final mediaData = {
        'heure': _mediaTime.isEmpty
            ? DateFormat('HH:mm').format(DateTime.now())
            : _mediaTime,
        'date': DateTime.now(),
        'type': 'Photo',
        'url': mediaUrl,
      };

      await mediaRef.set(mediaData);
      print("Photo ajoutée avec succès !");
    } catch (e) {
      print("Erreur lors de l'ajout de la photo : $e");
      throw e;
    }
  }

  void _showMediaDetailsPopup(Map<String, dynamic> mediaData) {
    // Déterminer si nous sommes sur iPad
    final bool isTabletDevice = isTablet(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal:
                isTabletDevice ? MediaQuery.of(context).size.width * 0.25 : 20,
            vertical: 20,
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 500,
              minWidth: 250,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête avec dégradé
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
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.photo,
                            color: Colors.white,
                            size: isTabletDevice ? 30 : 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Photo de ${mediaData['heure']}",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMMM yyyy', 'fr_FR')
                                    .format(mediaData['date'].toDate())
                                    .toLowerCase(),
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenu - Image
                  Padding(
                    padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              mediaData['url'],
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryColor),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image,
                                        size: 64, color: primaryRed),
                                    SizedBox(height: 8),
                                    Text('Erreur de chargement de l\'image'),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        // Bouton Fermer
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              "FERMER",
                              style: TextStyle(
                                fontSize: isTabletDevice ? 16 : 14,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
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
        );
      },
    );
  }

  // Avatar par défaut avec l'initiale du prénom
  Widget _buildFallbackAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    String genre = enfant['genre']?.toString() ?? 'Garçon';
    Color avatarColor = (genre == 'Fille') ? primaryRed : primaryBlue;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // Utilisation de l'avatar avec dégradé comme dans HomeScreen
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [avatarColor.withOpacity(0.7), avatarColor],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              enfant['photoUrl'],
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            enfant['prenom'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enfant['prenom'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: primaryColor, size: 24),
                  ),
                  onPressed: () => _showAddMediaPopup(enfant['id']),
                ),
              ],
            ),
          ),
          // Liste des photos
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('medias')
                .where('date',
                    isGreaterThanOrEqualTo: DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ))
                .where('date',
                    isLessThan: DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ).add(Duration(days: 1)))
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Container();

              final medias = snapshot.data!.docs;

              if (medias.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Aucune photo enregistrée aujourd'hui",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: medias.length,
                separatorBuilder: (context, index) => SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final mediaData = medias[idx].data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showMediaDetailsPopup(mediaData),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: primaryColor.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.photo,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mediaData['heure'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  mediaData['type'] ?? "Photo",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Photos.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.photo_camera,
              size: 80,
              color: primaryColor.withOpacity(0.4),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Aucun enfant prévu aujourd\'hui',
            style: TextStyle(
              fontSize: 18,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
      context.go('/child-info');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(context),
          // Ajouter le sélecteur de date
          _buildDateSelector(),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                  )
                : _showingPastPhotos
                    ? _buildPastPhotosView(isTabletDevice)
                    : enfants.isEmpty
                        ? _buildEmptyState()
                        : Stack(
                            children: [
                              isTabletDevice
                                  ? _buildTabletLayout()
                                  : ListView.builder(
                                      itemCount: enfants.length,
                                      itemBuilder: _buildEnfantCard,
                                    ),
                              if (_isUploadingFile)
                                Container(
                                  color: Colors.black.withOpacity(0.5),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          "Téléchargement en cours...",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize:
                                                  isTabletDevice ? 20 : 18),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
          )
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Message d'avertissement à gauche
          Expanded(
            flex: 2,
            child: _buildDataRetentionWarning(),
          ),

          // Bouton pour revenir aux photos du jour
          if (_showingPastPhotos)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showingPastPhotos = false;
                  _selectedDate = DateTime.now();
                });
              },
              icon: Icon(Icons.today, color: primaryBlue),
              label: Text(
                "Aujourd'hui",
                style:
                    TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
              ),
            ),

          Spacer(),

          // Sélecteur de date
          TextButton.icon(
            onPressed: () => _showDatePicker(),
            icon: Icon(
              Icons.calendar_today,
              color: _showingPastPhotos ? primaryBlue : Colors.grey.shade600,
            ),
            label: Text(
              _showingPastPhotos
                  ? DateFormat('dd MMM yyyy', 'fr_FR').format(_selectedDate)
                  : "Historique des photos",
              style: TextStyle(
                color: _showingPastPhotos ? primaryBlue : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: _showingPastPhotos
                  ? primaryBlue.withOpacity(0.1)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRetentionWarning() {
    final bool isTabletDevice = isTablet(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTabletDevice ? 12 : 10,
        vertical: isTabletDevice ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: isTabletDevice ? 16 : 14,
            color: Colors.grey.shade600,
          ),
          SizedBox(width: isTabletDevice ? 8 : 6),
          Flexible(
            child: Text(
              "Photos conservées 10 jours",
              style: TextStyle(
                fontSize: isTabletDevice ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = now.subtract(
        Duration(days: 9)); // 9 jours en arrière (+ aujourd'hui = 10 jours)

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _showingPastPhotos ? _selectedDate : now.subtract(Duration(days: 1)),
      firstDate: firstDate,
      lastDate: now.subtract(Duration(days: 1)), // Exclure aujourd'hui
      locale: Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _showingPastPhotos = true;
      });
      await _loadPastPhotos(picked);
    }
  }

  Future<void> _loadPastPhotos(DateTime date) async {
    setState(() => _loadingPastPhotos = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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
        }
      }

      // Définir la plage de dates pour le jour sélectionné
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // MODIFICATION: Récupérer d'abord tous les enfants et appliquer le même filtre que _loadEnfantsDuJour
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      final String structureType = structureSnapshot.exists
          ? (structureSnapshot.data()?['structureType'] ??
              "AssistanteMaternelle")
          : "AssistanteMaternelle";

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      // Appliquer le même filtrage que dans _loadEnfantsDuJour
      List<Map<String, dynamic>> filteredChildren = [];

      if (structureType == "MAM") {
        // Pour une MAM: filtrer par assignedMemberEmail
        filteredChildren = allChildren.where((child) {
          String assignedEmail =
              child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
          return assignedEmail == currentUserEmail;
        }).toList();

        print(
            "📸 Photos passées: Membre MAM - chargement des photos pour ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants
        filteredChildren = allChildren;
        print(
            "📸 Photos passées: Assistante Maternelle - chargement des photos pour tous les enfants");
      }

      List<Map<String, dynamic>> allPhotos = [];

      // Charger les photos SEULEMENT pour les enfants filtrés
      for (var enfant in filteredChildren) {
        final photosSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .doc(enfant['id'])
            .collection('medias')
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where('date', isLessThan: endOfDay.add(Duration(days: 1)))
            .orderBy('date', descending: true)
            .get();

        for (var doc in photosSnapshot.docs) {
          final data = doc.data();
          allPhotos.add({
            ...data,
            'id': doc.id,
            'childId': enfant['id'],
            'childName': enfant[
                'firstName'], // Utiliser firstName comme dans les autres endroits
            'childGender': enfant['gender'],
          });
        }
      }

      // Trier par heure
      allPhotos.sort((a, b) {
        final timeA = a['heure'] ?? '00:00';
        final timeB = b['heure'] ?? '00:00';
        return timeB.compareTo(timeA); // Ordre décroissant
      });

      setState(() {
        _pastPhotos = allPhotos;
        _loadingPastPhotos = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des photos passées: $e");
      setState(() => _loadingPastPhotos = false);
    }
  }

  Widget _buildPastPhotosView(bool isTabletDevice) {
    if (_loadingPastPhotos) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
        ),
      );
    }

    if (_pastPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 16),
            Text(
              'Aucune photo trouvée',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'pour le ${DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedDate)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return isTabletDevice ? _buildPastPhotosGrid() : _buildPastPhotosList();
  }

// Grille pour tablette
  Widget _buildPastPhotosGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _pastPhotos.length,
      itemBuilder: (context, index) =>
          _buildPastPhotoCard(_pastPhotos[index], true),
    );
  }

// Liste pour mobile
  Widget _buildPastPhotosList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _pastPhotos.length,
      itemBuilder: (context, index) =>
          _buildPastPhotoCard(_pastPhotos[index], false),
    );
  }

// Carte pour une photo passée
  Widget _buildPastPhotoCard(Map<String, dynamic> photo, bool isGrid) {
    final Color childColor =
        (photo['childGender'] == 'Fille') ? primaryRed : primaryBlue;

    return Container(
      margin: EdgeInsets.only(bottom: isGrid ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec info enfant
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [childColor.withOpacity(0.8), childColor],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: isGrid ? 30 : 40,
                  height: isGrid ? 30 : 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      photo['childName'][0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isGrid ? 14 : 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photo['childName'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isGrid ? 12 : 14,
                        ),
                      ),
                      if (!isGrid)
                        Text(
                          photo['heure'] ?? 'Heure inconnue',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Photo
          Expanded(
            child: GestureDetector(
              onTap: () => _showMediaDetailsPopup(photo),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photo['url'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryBlue),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.grey.shade400),
                          if (!isGrid)
                            Text('Erreur de chargement',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Heure pour la grille
          if (isGrid)
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                photo['heure'] ?? 'Heure inconnue',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

// Nouvelle méthode pour construire la mise en page en grille pour iPad
  Widget _buildTabletLayout() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: enfants.length,
      itemBuilder: (context, index) =>
          _buildEnfantCardForTablet(context, index),
    );
  }

// Nouvelle carte enfant optimisée pour iPad
  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    final String genre = enfant['genre']?.toString() ?? 'Garçon';
    Color avatarColor = (genre == 'Fille') ? primaryRed : primaryBlue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête avec gradient et infos enfant
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [avatarColor, avatarColor.withOpacity(0.85)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar avec photo de l'enfant
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? Image.network(
                            enfant['photoUrl'],
                            width: 65,
                            height: 65,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Text(
                              enfant['prenom'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            enfant['prenom'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Bouton d'ajout de photo
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: avatarColor, size: 24),
                      onPressed: () => _showAddMediaPopup(enfant['id']),
                      tooltip: "Ajouter une photo",
                      padding: EdgeInsets.all(10),
                      constraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des photos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid)
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('medias')
                  .where('date',
                      isGreaterThanOrEqualTo: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      ))
                  .where('date',
                      isLessThan: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      ).add(Duration(days: 1)))
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Container();

                final medias = snapshot.data!.docs;

                if (medias.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Aucune photo enregistrée aujourd'hui",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics: BouncingScrollPhysics(),
                  shrinkWrap: true,
                  padding: EdgeInsets.all(16),
                  itemCount: medias.length,
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final doc = medias[idx];
                    final mediaData = doc.data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => _showMediaDetailsPopup(mediaData),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: lightBlue),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.photo,
                                color: primaryColor,
                                size: 22,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mediaData['heure'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    mediaData['type'] ?? "Photo",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

// Avatar par défaut plus grand pour iPad
  Widget _buildFallbackAvatarForTablet(String name) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  // AppBar personnalisé avec gradient
  Widget _buildAppBar(BuildContext context) {
    // Détection de l'iPad
    final bool isTabletDevice = isTablet(context);

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
          // Plus de padding vertical pour iPad
          padding: EdgeInsets.fromLTRB(
              16, isTabletDevice ? 24 : 16, 16, isTabletDevice ? 28 : 20),
          child: Column(
            children: [
              // Première ligne: nom structure et date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      structureName,
                      style: TextStyle(
                        fontSize: isTabletDevice ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTabletDevice ? 16 : 12,
                      vertical: isTabletDevice ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: isTabletDevice ? 16 : 14,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTabletDevice ? 22 : 15),
              // Icône et titre de la page
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTabletDevice ? 22 : 16,
                  vertical: isTabletDevice ? 12 : 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white, width: isTabletDevice ? 2.5 : 2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/Icone_Photos.png',
                      width: isTabletDevice ? 36 : 30,
                      height: isTabletDevice ? 36 : 30,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.photo_camera,
                        size: isTabletDevice ? 32 : 26,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: isTabletDevice ? 12 : 8),
                    Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: isTabletDevice ? 24 : 20,
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

  // Navigation du bas
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
}
