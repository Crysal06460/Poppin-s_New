import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../services/emergency_sheet_service.dart'; // Ajout import


class ChildProfileDetailsScreen extends StatefulWidget {
  final String childId;
  final String structureId; // Ajout du paramètre structureId
  final bool parentMode;
  final bool allowEditing;

  const ChildProfileDetailsScreen({
    Key? key,
    required this.childId,
    required this.structureId, // Le rendre obligatoire
    this.parentMode = false,
    this.allowEditing = true,
  }) : super(key: key);

  @override
  _ChildProfileDetailsScreenState createState() =>
      _ChildProfileDetailsScreenState();
}

class _PrescriptionFormResult {
  final String description;
  final int durationDays;
  final DateTime startDate;

  const _PrescriptionFormResult({
    required this.description,
    required this.durationDays,
    required this.startDate,
  });
}

class _ChildProfileDetailsScreenState extends State<ChildProfileDetailsScreen> {
  bool isLoading = true;
  Map<String, dynamic> childData = {};
  Map<String, dynamic> authorizations = {};
  Map<String, dynamic> documents = {};
  Map<String, dynamic> mealInfo = {};
  Map<String, dynamic> authorizedPickup = {};
  Map<String, dynamic> financialInfo = {};

  // Nouvelles variables pour la gestion des uploads
  final ImagePicker _picker = ImagePicker();
  bool _isPhotoUploading = false;
  bool _isDocumentUploading = false;
  bool _isPrescriptionUploading = false;
  List<Map<String, dynamic>> _activePrescriptions = [];
  List<Map<String, dynamic>> _prescriptionHistory = [];
  List<Map<String, dynamic>> _vaccinationDocuments = [];
  
  String _currentAssMatName = ""; // Nom de l'assmat pour la fiche d'urgence


  // Définition des couleurs de la palette
  static const Color primaryColor = Color(0xFF3D9DF2); // Bleu #3D9DF2
  static const Color secondaryColor = Color(0xFFDFE9F2); // Bleu clair #DFE9F2

  final NumberFormat _weightFormat = NumberFormat("0.##", "fr_FR");
  bool _canEditChild = true;

  bool get _isParentMode => widget.parentMode;
  bool get _isReadOnly => _isParentMode || !_canEditChild;

  @override
  void initState() {
    super.initState();
    _canEditChild = widget.allowEditing && !widget.parentMode;
    _canEditChild = widget.allowEditing && !widget.parentMode;
    _loadChildProfile();
    _loadCurrentAssMatName(); // Chargement du nom
  }

  String _structureName = "";
  bool _isMAM = false; 

  // ... (rest of imports/variables)

  Future<void> _loadCurrentAssMatName() async {
     try {
       // 1. Récupérer le nom de l'AssMat (current user)
       final user = FirebaseAuth.instance.currentUser;
       if (user != null) {
         final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email).get();
         if (userDoc.exists) {
           final data = userDoc.data()!;
           setState(() {
             _currentAssMatName = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
           });
         }
       }
       
       // 2. Récupérer les infos de la structure (MAM ou pas)
       if (widget.structureId.isNotEmpty) {
         final structureDoc = await FirebaseFirestore.instance.collection('structures').doc(widget.structureId).get();
         if (structureDoc.exists) {
           final sData = structureDoc.data()!;
           setState(() {
             _structureName = (sData['structureName'] ?? sData['name'] ?? '').toString();
             
             final type = (sData['structureType'] ?? sData['type'] ?? '').toString();
             // La capture montre "MAM" en majuscule, on gère les deux cas + la recherche dans le nom
             _isMAM = type.toUpperCase() == 'MAM' || _structureName.toUpperCase().contains('MAM');
           });
         }
       }

     } catch (e) {
       print("Erreur chargement infos AssMat/Structure: $e");
     }
  }

  Future<void> _generateEmergencySheet() async {
    if (_currentAssMatName.isEmpty) {
      // Tenter de recharger ou demander
      await _loadCurrentAssMatName();
    }
    
    final parent1 = childData['parent1'] ?? {};
    final parent2 = childData['parent2'] ?? {};
    
    await EmergencySheetService.generateAndPrint(
      assMatName: _currentAssMatName.isNotEmpty ? _currentAssMatName : "Nom - Prénom",
      childFirstName: childData['firstName'] ?? '',
      childLastName: childData['lastName'] ?? '',
      childPhotoUrl: childData['photoUrl'],
      parent1Phone: parent1['phone']?.toString() ?? '',
      parent2Phone: parent2['phone']?.toString() ?? '',
      isMAM: _isMAM,
      mamName: _structureName,
    );
  }


  bool _ensureEditingAllowed({String? customMessage}) {
    if (!_isReadOnly) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          customMessage ??
              "Vous n'avez pas les droits pour modifier ce profil.",
        ),
        backgroundColor: Colors.orange,
      ),
    );
    return false;
  }

  Future<void> _updateChildPhoto() async {
    if (!_ensureEditingAllowed(
      customMessage: "Vous n'avez pas les droits pour modifier la photo.",
    )) {
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) return;

      setState(() => _isPhotoUploading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Convertir l'image en bytes
      final bytes = await File(image.path).readAsBytes();

      // Upload vers Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('children_photos')
          .child(
              '${widget.childId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final newPhotoUrl = await storageRef.getDownloadURL();

      // Mise à jour dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .update({'photoUrl': newPhotoUrl});

      // Mettre à jour l'état local
      setState(() {
        childData['photoUrl'] = newPhotoUrl;
        _isPhotoUploading = false;
      });

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
      print("Erreur lors de la mise à jour de la photo: $e");
      setState(() => _isPhotoUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour de la photo'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _viewDocument(String documentUrl, String documentName) async {
    try {
      // Afficher un dialogue avec les options
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Document: $documentName',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.open_in_browser, color: primaryColor),
                title: Text('Ouvrir dans le navigateur'),
                onTap: () => Navigator.pop(context, 'open'),
              ),
              ListTile(
                leading: Icon(Icons.download, color: primaryColor),
                title: Text('Télécharger'),
                onTap: () => Navigator.pop(context, 'download'),
              ),
              ListTile(
                leading: Icon(Icons.share, color: primaryColor),
                title: Text('Partager le lien'),
                onTap: () => Navigator.pop(context, 'share'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text(
                'Fermer',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );

      if (action == 'cancel' || action == null) return;

      if (action == 'open' || action == 'download') {
        // Ouvrir l'URL dans le navigateur
        final Uri url = Uri.parse(documentUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Impossible d\'ouvrir le document');
        }
      } else if (action == 'share') {
        // Copier le lien dans le presse-papier (nécessite l'import de services)
        await Clipboard.setData(ClipboardData(text: documentUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lien copié dans le presse-papier'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de l'ouverture du document: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ouverture du document'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _loadChildProfile() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget
              .structureId) // <-- Utilisez l'ID de structure passé en paramètre
          .collection('children')
          .doc(widget.childId)
          .get();

      if (!childDoc.exists) {
        throw Exception('Enfant non trouvé');
      }

      final data = childDoc.data()!;

      // Extraction des données principales
      childData = {
        'id': widget.childId,
        'firstName': data['firstName'] ?? 'Inconnu',
        'lastName': data['lastName'] ?? '',
        'photoUrl': data['photoUrl'],
        'gender': data['gender'] ?? 'Non spécifié',
        'birthdate': data['birthdate'],
        'weight': _normalizeWeight(data['weight']),
        // Ajoutez explicitement les données des parents
        'parent1': data['parent1'] ?? {},
        'parent2': data['parent2'] ?? {},
        'assignedMemberEmail':
            data['assignedMemberEmail']?.toString().trim() ?? '',
      };

      // Extraction des autorisations
      authorizations = data['authorizations'] ?? {};

      // Extraction des documents
      documents = Map<String, dynamic>.from(data['documents'] ?? {});
      _vaccinationDocuments = _extractVaccinationDocuments(documents);
      _applyVaccinationDocumentsToCache();
      await _initializePrescriptions();

      // Extraction des infos alimentaires
      mealInfo = data['mealInfo'] ?? {};

      // Extraction des autorisations de récupération
      authorizedPickup = data['authorizedPickup'] ?? {};

      // Extraction des infos financières (mémo mensuel)
      financialInfo = data['financialInfo'] ?? {};

      setState(() => isLoading = false);
    } catch (e) {
      print("Erreur lors du chargement du profil: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement du profil'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() => isLoading = false);
    }
  }

  // Méthode pour sauvegarder les modifications
  Future<void> _saveChanges(String section, String field, dynamic value) async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      final String currentUserEmail = user.email?.toLowerCase() ?? '';
      bool assignedMemberUpdated = false;

      // Créer le chemin pour la mise à jour
      String updatePath = '';
      Map<String, dynamic> updateData = {};

      switch (section) {
        case 'authorizations':
          updatePath = 'authorizations.$field';
          // Mettre à jour la variable locale
          setState(() {
            authorizations[field] = value;
          });
          break;
        case 'documents':
          updatePath = 'documents.$field';
          setState(() {
            documents[field] = value;
          });
          break;
        case 'mealInfo':
          updatePath = 'mealInfo.$field';
          setState(() {
            mealInfo[field] = value;
          });
          break;
        case 'authorizedPickup':
          updatePath = 'authorizedPickup.$field';
          setState(() {
            authorizedPickup[field] = value;
          });
          break;
        case 'financialInfo':
          updatePath = 'financialInfo.$field';
          setState(() {
            financialInfo[field] = value;
          });
          break;
        case 'profile':
          updatePath = field;
          setState(() {
            childData[field] = value;
          });
          break;
      }

      // Création de l'objet de mise à jour
      updateData[updatePath] = value;

      // Cas particulier: activation du mémo mensuel => assurer l'affichage Dashboard (MAM)
      if (section == 'financialInfo' &&
          field == 'useMonthlyTable' &&
          value == true) {
        final currentAssigned =
            (childData['assignedMemberEmail'] ?? '').toString().trim();
        if (currentAssigned.isEmpty) {
          updateData['assignedMemberEmail'] = currentUserEmail;
          assignedMemberUpdated = true;
        }
        updateData['lastUpdatedBy'] = currentUserEmail;
        updateData['lastUpdatedAt'] = FieldValue.serverTimestamp();
      }

      // Mise à jour dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget
              .structureId) // <-- Utilisez l'ID de structure passé en paramètre
          .collection('children')
          .doc(widget.childId)
          .update(updateData);

      if (assignedMemberUpdated) {
        setState(() {
          childData['assignedMemberEmail'] = currentUserEmail;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Modification enregistrée'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print("Erreur lors de la sauvegarde: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde'),
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

  // Edition du mémo mensuel
  Future<void> _editMonthlyTableFields() async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    final TextEditingController salaryCtl = TextEditingController(
        text: (financialInfo['monthlySalary']?.toString() ?? ''));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Configuration du mémo mensuel',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNumberField(salaryCtl, 'Salaire net (€)', true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validation minimale
                if (salaryCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Le salaire net est obligatoire'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Construction des valeurs numériques
                double parseNum(String s) =>
                    double.tryParse(s.replaceAll(',', '.')) ?? 0;

                final Map<String, dynamic> updates = {
                  'financialInfo.useMonthlyTable': true,
                  'financialInfo.monthlySalary': parseNum(salaryCtl.text),
                  // Cleanup des anciens champs devenus obsolètes
                  'financialInfo.careExpenses': FieldValue.delete(),
                  'financialInfo.mealExpenses': FieldValue.delete(),
                  'financialInfo.kmExpenses': FieldValue.delete(),
                };

                // Assurer l'affichage Dashboard pour MAM: marquer le membre assigné et métadonnées
                final currentUser = FirebaseAuth.instance.currentUser;
                bool assignedMemberUpdated = false;
                if (currentUser != null) {
                  final email = currentUser.email?.toLowerCase() ?? '';
                  final currentAssigned =
                      (childData['assignedMemberEmail'] ?? '')
                          .toString()
                          .trim();
                  if (currentAssigned.isEmpty && email.isNotEmpty) {
                    updates['assignedMemberEmail'] = email;
                    assignedMemberUpdated = true;
                  }
                  updates['lastUpdatedBy'] = email;
                  updates['lastUpdatedAt'] = FieldValue.serverTimestamp();
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('structures')
                      .doc(widget.structureId)
                      .collection('children')
                      .doc(widget.childId)
                      .update(updates);

                  setState(() {
                    financialInfo['useMonthlyTable'] = true;
                    financialInfo['monthlySalary'] =
                        updates['financialInfo.monthlySalary'];
                    // Supprimer les anciens champs s'ils existent côté UI
                    financialInfo.remove('careExpenses');
                    financialInfo.remove('mealExpenses');
                    financialInfo.remove('kmExpenses');
                    if (assignedMemberUpdated &&
                        updates['assignedMemberEmail'] is String) {
                      childData['assignedMemberEmail'] =
                          updates['assignedMemberEmail'];
                    }
                  });

                  Navigator.pop(context, true);
                } catch (e) {
                  print('Erreur sauvegarde mémo mensuel: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de l\'enregistrement'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mémo mensuel mis à jour'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

// Toggle "Utiliser le mémo mensuel" avec ouverture auto de la configuration
  Future<void> _editUseMonthlyTableToggle() async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    final bool current = (financialInfo['useMonthlyTable'] == true);
    bool switchValue = current;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            title: Text(
              'Mémo mensuel',
              style:
                  TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SwitchListTile(
              title: Text('Utiliser le mémo mensuel ?'),
              value: switchValue,
              activeColor: primaryColor,
              onChanged: (v) {
                dialogSetState(() => switchValue = v);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child:
                    Text('Annuler', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, switchValue),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || result == current) return;

    await _saveChanges('financialInfo', 'useMonthlyTable', result);
    if (result == true) {
      // Ouvrir immédiatement la configuration des 4 champs
      await _editMonthlyTableFields();
    }
  }

  Widget _buildNumberField(
      TextEditingController ctl, String label, bool required) {
    return TextField(
      controller: ctl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Méthode pour gérer l'édition des données textuelles
  Future<void> _editTextData(
      String section, String field, String currentValue, String label) async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    TextEditingController controller =
        TextEditingController(text: currentValue);

    String? result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Modifier $label',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      await _saveChanges(section, field, result);
    }
  }

  // Méthode pour gérer l'édition des booléens
  Future<void> _editBooleanData(
      String section, String field, bool currentValue, String label) async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    // Utiliser une variable pour suivre l'état actuel du switch
    bool switchValue = currentValue;

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, dialogSetState) {
        return AlertDialog(
          title: Text(
            'Modifier $label',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SwitchListTile(
            title: Text(
              'Autoriser?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            value: switchValue,
            activeColor: primaryColor,
            onChanged: (value) {
              // Mettre à jour le state dans le dialog
              dialogSetState(() {
                switchValue = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Annuler',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, switchValue),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Confirmer'),
            ),
          ],
        );
      }),
    );

    if (result != null && result != currentValue) {
      await _saveChanges(section, field, result);
    }
  }

  Future<void> _editWeight() async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: childData['weight'] != null
          ? (_normalizeWeight(childData['weight'])?.toString() ?? '')
          : '',
    );
    String? errorText;

    final String? sanitized = await showDialog<String?>(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text(
                'Modifier le poids',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Poids (kg)',
                      suffixText: 'kg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      errorText: errorText,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Laissez vide pour supprimer le poids.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(
                    'Annuler',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final raw = controller.text.trim();
                    if (raw.isEmpty) {
                      Navigator.pop(context, '');
                      return;
                    }
                    final sanitizedValue = raw.replaceAll(',', '.');
                    final parsed = double.tryParse(sanitizedValue);
                    if (parsed == null) {
                      dialogSetState(
                        () => errorText = 'Veuillez entrer un poids valide.',
                      );
                      return;
                    }
                    Navigator.pop(context, sanitizedValue);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('Enregistrer'),
                ),
              ],
            );
          });
        });

    if (sanitized == null) {
      return;
    }

    if (sanitized.isEmpty) {
      await _saveChanges('profile', 'weight', null);
    } else {
      final value = double.tryParse(sanitized);
      if (value != null) {
        await _saveChanges('profile', 'weight', value);
      }
    }
  }

  Future<String?> _pickDocumentSource() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Télécharger un document',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: primaryColor),
              title: Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: primaryColor),
              title: Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Icon(Icons.file_present, color: primaryColor),
              title: Text('Sélectionner un fichier'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child:
                Text('Annuler', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _selectAndUploadDocument({
    required String storageKey,
    String? storageFolder,
  }) async {
    final action = await _pickDocumentSource();
    if (action == null) {
      return null;
    }

    setState(() => _isDocumentUploading = true);

    String? fileUrl;
    String? fileName;
    String? storagePath;

    try {
      final String folderName = storageFolder ?? storageKey;
      final baseRef = FirebaseStorage.instance
          .ref()
          .child('children_documents')
          .child(widget.childId);
      final int timestamp = DateTime.now().millisecondsSinceEpoch;

      if (action == 'gallery' || action == 'camera') {
        final XFile? image = await _picker.pickImage(
          source:
              action == 'gallery' ? ImageSource.gallery : ImageSource.camera,
          imageQuality: 70,
          maxWidth: 900,
          maxHeight: 900,
        );

        if (image == null) {
          return null;
        }

        final bytes = await File(image.path).readAsBytes();
        fileName = image.name.isNotEmpty
            ? image.name
            : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageFileName = '${folderName}_$timestamp.jpg';
        final storageRef = baseRef.child(folderName).child(storageFileName);

        await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        fileUrl = await storageRef.getDownloadURL();
        storagePath = storageRef.fullPath;
      } else if (action == 'file') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        );

        if (result == null || result.files.isEmpty) {
          return null;
        }

        final file = result.files.first;
        fileName = file.name;
        final extension = file.extension ?? 'dat';
        final storageFileName = '${folderName}_$timestamp.$extension';
        final storageRef = baseRef.child(folderName).child(storageFileName);

        if (kIsWeb && file.bytes != null) {
          await storageRef.putData(file.bytes!);
        } else if (file.path != null) {
          await storageRef.putFile(File(file.path!));
        } else {
          throw Exception("Impossible d'accéder au fichier sélectionné");
        }

        fileUrl = await storageRef.getDownloadURL();
        storagePath = storageRef.fullPath;
      }

      if (fileUrl == null) {
        return null;
      }

      return {
        'url': fileUrl,
        'name': fileName ?? 'Document',
        'storagePath': storagePath,
        'uploadedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print("Erreur lors de l'upload du document: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'upload du document"),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } finally {
      setState(() => _isDocumentUploading = false);
    }
  }

  List<Map<String, dynamic>> _extractVaccinationDocuments(
      Map<String, dynamic> source) {
    final List<Map<String, dynamic>> files = [];
    final Set<String> seenUrls = {};
    final dynamic rawFiles = source['vaccinFiles'];

    if (rawFiles is List) {
      for (final dynamic entry in rawFiles) {
        if (entry is Map) {
          final url = entry['url'];
          if (url is String && url.isNotEmpty && seenUrls.add(url)) {
            files.add({
              'url': url,
              'name':
                  entry['name'] ?? entry['fileName'] ?? 'Carnet de vaccination',
              if (entry['storagePath'] != null)
                'storagePath': entry['storagePath'],
              if (entry['uploadedAt'] != null)
                'uploadedAt': entry['uploadedAt'],
            });
          }
        }
      }
    }

    final dynamic fallbackUrl = source['vaccinUrl'];
    if (fallbackUrl is String &&
        fallbackUrl.isNotEmpty &&
        seenUrls.add(fallbackUrl)) {
      files.insert(0, {
        'url': fallbackUrl,
        'name': source['vaccinFileName'] ?? 'Carnet de vaccination',
      });
    }

    return files;
  }

  List<Map<String, dynamic>> _serializeVaccinationDocuments() {
    return _vaccinationDocuments.map((doc) {
      final Map<String, dynamic> serialized = {
        'url': doc['url'],
        if (doc['name'] != null) 'name': doc['name'],
      };
      if (doc['storagePath'] != null) {
        serialized['storagePath'] = doc['storagePath'];
      }
      if (doc['uploadedAt'] != null) {
        serialized['uploadedAt'] = doc['uploadedAt'];
      }
      return serialized;
    }).toList();
  }

  void _applyVaccinationDocumentsToCache() {
    documents['vaccinFiles'] = _serializeVaccinationDocuments();
    if (_vaccinationDocuments.isNotEmpty) {
      documents['vaccinUrl'] = _vaccinationDocuments.first['url'];
      documents['vaccinFileName'] =
          _vaccinationDocuments.first['name'] ?? 'Carnet de vaccination';
    } else {
      documents.remove('vaccinUrl');
      documents.remove('vaccinFileName');
    }
  }

  String? _formatVaccinationUploadDate(dynamic rawDate) {
    DateTime? parsed;
    if (rawDate is Timestamp) {
      parsed = rawDate.toDate();
    } else if (rawDate is DateTime) {
      parsed = rawDate;
    } else if (rawDate is String) {
      parsed = DateTime.tryParse(rawDate);
    }

    if (parsed == null) {
      return null;
    }

    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  Widget _buildVaccinationDocumentsRow() {
    final bool hasDocuments = _vaccinationDocuments.isNotEmpty;
    final int count = _vaccinationDocuments.length;
    final String statusText =
        hasDocuments ? 'Fourni${count > 1 ? ' ($count)' : ''}' : 'Non fourni';
    final Color statusColor = hasDocuments ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.medical_information, color: primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Carnet de vaccination',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: _isDocumentUploading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      )
                    : Icon(Icons.add_circle_outline, color: primaryColor),
                tooltip: _isReadOnly
                    ? "Lecture seule"
                    : "Ajouter un document de vaccination",
                onPressed: _isReadOnly || _isDocumentUploading
                    ? null
                    : _addVaccinationDocument,
              ),
            ],
          ),
          SizedBox(height: 8),
          if (hasDocuments)
            ..._vaccinationDocuments.asMap().entries.map(
                  (entry) => _buildVaccinationDocumentTile(
                    entry.value,
                    entry.key,
                  ),
                )
          else
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                'Aucun document téléchargé pour le moment.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVaccinationDocumentTile(
      Map<String, dynamic> document, int index) {
    final String fileName =
        (document['name'] as String?) ?? 'Document ${index + 1}';
    final String? uploadedAt = _formatVaccinationUploadDate(
      document['uploadedAt'],
    );
    final String? url = document['url'] as String?;

    return Container(
      margin: EdgeInsets.only(top: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description, color: primaryColor),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (uploadedAt != null) ...[
                  SizedBox(height: 4),
                  Text(
                    'Ajouté le $uploadedAt',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.visibility_outlined, color: primaryColor),
            tooltip: 'Voir le document',
            onPressed: url == null ? null : () => _viewDocument(url, fileName),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: _isReadOnly ? null : 'Retirer ce fichier',
            onPressed:
                _isReadOnly ? null : () => _removeVaccinationDocument(index),
          ),
        ],
      ),
    );
  }

  Future<bool> _persistVaccinationDocuments() async {
    final List<Map<String, dynamic>> serialized =
        _serializeVaccinationDocuments();
    final Map<String, dynamic> updateData = {
      'documents.vaccinFiles': serialized,
    };

    if (serialized.isNotEmpty) {
      updateData['documents.vaccinUrl'] = serialized.first['url'];
      updateData['documents.vaccinFileName'] =
          serialized.first['name'] ?? 'Carnet de vaccination';
    } else {
      updateData['documents.vaccinUrl'] = FieldValue.delete();
      updateData['documents.vaccinFileName'] = FieldValue.delete();
    }

    try {
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .update(updateData);
      return true;
    } catch (e) {
      print('Erreur lors de la mise à jour des documents vaccination: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Impossible d'enregistrer les documents de vaccination pour le moment"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _addVaccinationDocument() async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    final Map<String, dynamic>? uploaded = await _selectAndUploadDocument(
        storageKey: 'vaccin', storageFolder: 'vaccin');

    if (uploaded == null) {
      return;
    }

    final Map<String, dynamic> newDocument = {
      'url': uploaded['url'],
      'name': uploaded['name'] ?? 'Carnet de vaccination',
      if (uploaded['storagePath'] != null)
        'storagePath': uploaded['storagePath'],
      if (uploaded['uploadedAt'] != null) 'uploadedAt': uploaded['uploadedAt'],
    };

    final List<Map<String, dynamic>> previous =
        List<Map<String, dynamic>>.from(_vaccinationDocuments);

    setState(() {
      _vaccinationDocuments.add(newDocument);
    });

    final bool success = await _persistVaccinationDocuments();

    if (!success) {
      setState(() {
        _vaccinationDocuments = previous;
      });
      return;
    }

    setState(() {
      _applyVaccinationDocumentsToCache();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Page ajoutée au carnet de vaccination'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _removeVaccinationDocument(int index) async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    if (index < 0 || index >= _vaccinationDocuments.length) {
      return;
    }

    final Map<String, dynamic> document = Map<String, dynamic>.from(
      _vaccinationDocuments[index],
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Supprimer ce document ?',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Cette page sera retirée du carnet de vaccination.',
          style: TextStyle(color: Colors.grey.shade800),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final List<Map<String, dynamic>> previous =
        List<Map<String, dynamic>>.from(_vaccinationDocuments);

    setState(() {
      _vaccinationDocuments.removeAt(index);
    });

    final bool success = await _persistVaccinationDocuments();

    if (!success) {
      setState(() {
        _vaccinationDocuments = previous;
      });
      return;
    }

    setState(() {
      _applyVaccinationDocumentsToCache();
    });

    final String? storagePath = document['storagePath'] as String?;
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(storagePath).delete();
      } catch (e) {
        print('Erreur lors de la suppression du fichier de vaccination: $e');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document supprimé du carnet de vaccination'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Méthode pour uploader un document
  Future<void> _uploadDocument(String section, String field) async {
    if (!_ensureEditingAllowed(
      customMessage: "Vous n'avez pas les droits pour ajouter un document.",
    )) {
      return;
    }

    final Map<String, dynamic>? uploaded =
        await _selectAndUploadDocument(storageKey: field);

    if (uploaded == null) {
      return;
    }

    final String url = uploaded['url'] as String? ?? '';
    final String fileName = (uploaded['name'] as String?) ?? 'Document';

    await _saveChanges(section, field, url);
    await _saveChanges(section, '${field}FileName', fileName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document téléchargé avec succès'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _initializePrescriptions() async {
    final dynamic prescriptionsRaw = documents['prescriptions'];
    final Map<String, dynamic> prescriptionsData =
        prescriptionsRaw is Map<String, dynamic>
            ? Map<String, dynamic>.from(prescriptionsRaw)
            : {};

    final List<Map<String, dynamic>> activeList =
        _convertToMapList(prescriptionsData['active']);
    final List<Map<String, dynamic>> historyList =
        _convertToMapList(prescriptionsData['history']);

    final DateTime now = DateTime.now();
    final List<Map<String, dynamic>> stillActive = [];
    final List<Map<String, dynamic>> updatedHistory =
        historyList.map((item) => Map<String, dynamic>.from(item)).toList();

    bool hasExpiredChanges = false;

    for (final Map<String, dynamic> entry in activeList) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(entry);
      final DateTime? expiresAt = _asDateTime(item['expiresAt']);

      if (expiresAt != null && !expiresAt.isAfter(now)) {
        item['archivedAt'] = item['archivedAt'] ?? Timestamp.fromDate(now);
        updatedHistory.add(item);
        hasExpiredChanges = true;
      } else {
        stillActive.add(item);
      }
    }

    _sortPrescriptionCollections(
      active: stillActive,
      history: updatedHistory,
    );

    if (hasExpiredChanges) {
      await _savePrescriptionsData(
        stillActive,
        updatedHistory,
        successMessage: null,
      );
    } else {
      if (!mounted) return;
      setState(() {
        _activePrescriptions = stillActive;
        _prescriptionHistory = updatedHistory;
        documents['prescriptions'] = {
          'active': stillActive,
          'history': updatedHistory,
        };
      });
    }
  }

  List<Map<String, dynamic>> _convertToMapList(dynamic source) {
    if (source is Iterable) {
      return source
          .whereType<Map>()
          .map((item) =>
              item.map((key, value) => MapEntry(key.toString(), value)))
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      // Supposer que la valeur est en millisecondes
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Non défini';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatDurationText(int? days) {
    if (days == null || days <= 0) return 'Durée non précisée';
    return days == 1 ? '1 jour' : '$days jours';
  }

  void _sortPrescriptionCollections({
    required List<Map<String, dynamic>> active,
    required List<Map<String, dynamic>> history,
  }) {
    int activeComparator(Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime aDate =
          _asDateTime(a['expiresAt']) ?? DateTime(9999, 12, 31);
      final DateTime bDate =
          _asDateTime(b['expiresAt']) ?? DateTime(9999, 12, 31);
      return aDate.compareTo(bDate);
    }

    int historyComparator(Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime aDate = _asDateTime(a['archivedAt']) ??
          _asDateTime(a['expiresAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = _asDateTime(b['archivedAt']) ??
          _asDateTime(b['expiresAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    }

    active.sort(activeComparator);
    history.sort(historyComparator);
  }

  Future<void> _savePrescriptionsData(
    List<Map<String, dynamic>> active,
    List<Map<String, dynamic>> history, {
    String? successMessage,
  }) async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    final List<Map<String, dynamic>> activeToSave =
        active.map((item) => Map<String, dynamic>.from(item)).toList();
    final List<Map<String, dynamic>> historyToSave =
        history.map((item) => Map<String, dynamic>.from(item)).toList();

    _sortPrescriptionCollections(
      active: activeToSave,
      history: historyToSave,
    );

    try {
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .update({
        'documents.prescriptions': {
          'active': activeToSave,
          'history': historyToSave,
        },
      });

      if (!mounted) return;

      setState(() {
        _activePrescriptions = activeToSave;
        _prescriptionHistory = historyToSave;
        documents['prescriptions'] = {
          'active': activeToSave,
          'history': historyToSave,
        };
      });

      if (successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde des ordonnances: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'enregistrement des ordonnances'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _archivePrescription(String id) async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    final List<Map<String, dynamic>> activeCopy = _activePrescriptions
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final int index = activeCopy.indexWhere((element) => element['id'] == id);

    if (index == -1) return;

    final Map<String, dynamic> prescription =
        Map<String, dynamic>.from(activeCopy.removeAt(index));
    prescription['archivedAt'] = Timestamp.fromDate(DateTime.now());

    final List<Map<String, dynamic>> historyCopy = _prescriptionHistory
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    historyCopy.add(prescription);

    await _savePrescriptionsData(
      activeCopy,
      historyCopy,
      successMessage: 'Ordonnance archivée',
    );
  }

  Future<_PrescriptionFormResult?> _promptPrescriptionDetails() async {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController durationController = TextEditingController();
    DateTime startDate = DateTime.now();

    String? descriptionError;
    String? durationError;

    return showDialog<_PrescriptionFormResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Nouvelle ordonnance',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Médicament / consignes',
                        hintText:
                            'Ex: Doliprane 500 mg - 1/2 comprimé si fièvre',
                        errorText: descriptionError,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      decoration: InputDecoration(
                        labelText: 'Durée (en jours)',
                        hintText: 'Ex: 8',
                        errorText: durationError,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Date de début',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate:
                              DateTime.now().subtract(Duration(days: 365)),
                          lastDate: DateTime.now().add(Duration(days: 365 * 2)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: primaryColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedDate != null) {
                          setDialogState(() {
                            startDate = pickedDate;
                          });
                        }
                      },
                      icon: Icon(Icons.calendar_today, size: 18),
                      label: Text(_formatDate(startDate)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
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
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String description =
                        descriptionController.text.trim();
                    final int? duration =
                        int.tryParse(durationController.text.trim());

                    bool hasError = false;

                    if (description.isEmpty) {
                      hasError = true;
                      setDialogState(() {
                        descriptionError = 'Merci de préciser la consigne';
                      });
                    } else if (descriptionError != null) {
                      setDialogState(() {
                        descriptionError = null;
                      });
                    }

                    if (duration == null || duration <= 0) {
                      hasError = true;
                      setDialogState(() {
                        durationError =
                            'Indiquez une durée en jours (minimum 1)';
                      });
                    } else if (durationError != null) {
                      setDialogState(() {
                        durationError = null;
                      });
                    }

                    if (hasError) return;

                    Navigator.pop(
                      context,
                      _PrescriptionFormResult(
                        description: description,
                        durationDays: duration!,
                        startDate: startDate,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('Continuer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>?> _pickAndUploadPrescriptionFile(
      String fileId) async {
    try {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Joindre l\'ordonnance',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: primaryColor),
                title: Text('Choisir depuis la galerie'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: primaryColor),
                title: Text('Prendre une photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: Icon(Icons.file_present, color: primaryColor),
                title: Text('Sélectionner un fichier'),
                onTap: () => Navigator.pop(context, 'file'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text(
                'Annuler',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );

      if (action == null || action == 'cancel') {
        return null;
      }

      String? fileUrl;
      String? fileName;

      final Reference storageBase = FirebaseStorage.instance
          .ref()
          .child('children_documents')
          .child(widget.childId)
          .child('prescriptions');

      if (action == 'gallery' || action == 'camera') {
        final XFile? image = await _picker.pickImage(
          source:
              action == 'gallery' ? ImageSource.gallery : ImageSource.camera,
          imageQuality: 75,
          maxWidth: 1600,
        );

        if (image == null) {
          return null;
        }

        final bytes = await File(image.path).readAsBytes();
        fileName = image.name;

        final Reference storageRef = storageBase
            .child('${fileId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        fileUrl = await storageRef.getDownloadURL();
      } else if (action == 'file') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
        );

        if (result == null || result.files.isEmpty) {
          return null;
        }

        final PlatformFile pickedFile = result.files.first;
        fileName = pickedFile.name;

        final String extension = pickedFile.extension ?? 'pdf';
        final Reference storageRef = storageBase.child(
            '${fileId}_${DateTime.now().millisecondsSinceEpoch}.$extension');

        if (kIsWeb && pickedFile.bytes != null) {
          await storageRef.putData(pickedFile.bytes!);
        } else if (pickedFile.path != null) {
          await storageRef.putFile(File(pickedFile.path!));
        } else {
          throw Exception('Fichier invalide ou non supporté');
        }

        fileUrl = await storageRef.getDownloadURL();
      }

      if (fileUrl == null) {
        throw Exception('Impossible de récupérer l\'URL du fichier');
      }

      return {
        'url': fileUrl,
        'name': fileName ?? 'Ordonnance',
      };
    } catch (e) {
      print('Erreur lors de l\'upload de l\'ordonnance: $e');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du téléchargement de l\'ordonnance'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return null;
    }
  }

  Future<void> _addPrescription({VoidCallback? onStateChanged}) async {
    if (!_ensureEditingAllowed()) {
      return;
    }

    final _PrescriptionFormResult? details = await _promptPrescriptionDetails();
    if (details == null) return;

    if (mounted) {
      setState(() => _isPrescriptionUploading = true);
    } else {
      _isPrescriptionUploading = true;
    }
    onStateChanged?.call();

    try {
      final String id = DateTime.now().millisecondsSinceEpoch.toString();
      final Map<String, String>? uploadResult =
          await _pickAndUploadPrescriptionFile(id);

      if (uploadResult == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import d\'ordonnance annulé'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final DateTime startDate = details.startDate;
      final DateTime expiresAt =
          startDate.add(Duration(days: details.durationDays));

      final Map<String, dynamic> newPrescription = {
        'id': id,
        'description': details.description,
        'durationDays': details.durationDays,
        'startDate': Timestamp.fromDate(startDate),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'fileUrl': uploadResult['url'],
        'fileName': uploadResult['name'],
        'uploadedAt': Timestamp.now(),
        'uploadedBy': user?.email?.toLowerCase() ?? '',
      };

      final List<Map<String, dynamic>> activeCopy = _activePrescriptions
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final List<Map<String, dynamic>> historyCopy = _prescriptionHistory
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      activeCopy.add(newPrescription);

      await _savePrescriptionsData(
        activeCopy,
        historyCopy,
        successMessage: 'Ordonnance ajoutée avec succès',
      );
    } finally {
      if (mounted) {
        setState(() => _isPrescriptionUploading = false);
      } else {
        _isPrescriptionUploading = false;
      }
      onStateChanged?.call();
    }
  }

  Future<void> _openPrescriptionManager() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List<Map<String, dynamic>> active = _activePrescriptions;
            final bool hasHistory = _prescriptionHistory.isNotEmpty;
            final double sheetHeight =
                MediaQuery.of(context).size.height * 0.65;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Ordonnances en cours',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: 16),
                    if (active.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: secondaryColor.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: secondaryColor),
                        ),
                        child: Text(
                          _isReadOnly
                              ? 'Aucune ordonnance en cours.'
                              : 'Aucune ordonnance en cours. Utilisez le bouton ci-dessous pour en ajouter une.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: sheetHeight * 0.55,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: active.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final Map<String, dynamic> prescription =
                                active[index];
                            final String? documentUrl =
                                prescription['fileUrl'] as String?;
                            final String? documentName =
                                prescription['fileName'] as String?;

                            return _buildActivePrescriptionCard(
                              prescription,
                              documentUrl: documentUrl,
                              documentName: documentName,
                              onArchive: _isReadOnly
                                  ? null
                                  : () async {
                                      await _archivePrescription(
                                        prescription['id'] ?? '',
                                      );
                                      setModalState(() {});
                                    },
                            );
                          },
                        ),
                      ),
                    SizedBox(height: 20),
                    if (!_isReadOnly)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isPrescriptionUploading
                              ? null
                              : () async {
                                  await _addPrescription(
                                    onStateChanged: () => setModalState(() {}),
                                  );
                                  setModalState(() {});
                                },
                          icon: _isPrescriptionUploading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(Icons.add_task_outlined),
                          label: Text(_isPrescriptionUploading
                              ? 'Import en cours…'
                              : 'Ajouter une ordonnance'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showPrescriptionHistory();
                      },
                      child: Text(
                        hasHistory
                            ? 'Voir l\'historique (${_prescriptionHistory.length})'
                            : 'Historique (vide)',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActivePrescriptionCard(
    Map<String, dynamic> prescription, {
    String? documentUrl,
    String? documentName,
    VoidCallback? onArchive,
  }) {
    final String description =
        (prescription['description'] ?? 'Ordonnance') as String;
    final int? durationDays = (prescription['durationDays'] is num)
        ? (prescription['durationDays'] as num).toInt()
        : null;
    final DateTime? startDate = _asDateTime(prescription['startDate']);
    final DateTime? expiresAt = _asDateTime(prescription['expiresAt']);
    final DateTime? uploadedAt = _asDateTime(prescription['uploadedAt']);
    final String uploadedBy = (prescription['uploadedBy'] ?? '') as String;

    final DateTime now = DateTime.now();
    final bool isExpiringSoon =
        expiresAt != null && expiresAt.isBefore(now.add(Duration(days: 2)));
    final Color badgeColor = isExpiringSoon ? Colors.orange : Colors.green;

    final VoidCallback? onView = (documentUrl != null && documentUrl.isNotEmpty)
        ? () => _viewDocument(documentUrl, documentName ?? 'Ordonnance')
        : null;

    final List<String> metaParts = [];
    if (uploadedAt != null) {
      metaParts.add('le ${_formatDate(uploadedAt)}');
    }
    if (uploadedBy.isNotEmpty) {
      metaParts.add('par $uploadedBy');
    }
    final String metaText =
        metaParts.isEmpty ? '' : 'Ajoutée ${metaParts.join(' ')}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: secondaryColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expiresAt != null
                      ? 'Expire le ${_formatDate(expiresAt)}'
                      : 'Date inconnue',
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.today, size: 18, color: primaryColor),
              SizedBox(width: 6),
              Text(
                'Début: ${_formatDate(startDate)}',
                style: TextStyle(color: Colors.black87),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: primaryColor),
              SizedBox(width: 6),
              Text(
                'Durée: ${_formatDurationText(durationDays)}',
                style: TextStyle(color: Colors.black87),
              ),
            ],
          ),
          if (metaText.isNotEmpty) ...[
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_pin, size: 18, color: Colors.grey.shade600),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    metaText,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onView,
                icon: Icon(Icons.visibility),
                label: Text('Voir'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withOpacity(0.6)),
                ),
              ),
              if (onArchive != null)
                OutlinedButton.icon(
                  onPressed: onArchive,
                  icon: Icon(Icons.archive_outlined),
                  label: Text('Archiver'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange,
                    side: BorderSide(color: Colors.deepOrangeAccent),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPrescriptionHistory() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final List<Map<String, dynamic>> history = _prescriptionHistory;
        final double dialogHeight =
            MediaQuery.of(dialogContext).size.height * 0.6;

        return AlertDialog(
          title: Text(
            'Historique des ordonnances',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: history.isEmpty
              ? Text('Aucune ordonnance archivée pour le moment.')
              : SizedBox(
                  width: double.maxFinite,
                  height: dialogHeight,
                  child: ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final prescription = history[index];
                      return _buildPrescriptionHistoryTile(prescription);
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Fermer',
                style: TextStyle(color: primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrescriptionHistoryTile(Map<String, dynamic> prescription) {
    final String description =
        (prescription['description'] ?? 'Ordonnance') as String;
    final int? durationDays = (prescription['durationDays'] is num)
        ? (prescription['durationDays'] as num).toInt()
        : null;
    final DateTime? startDate = _asDateTime(prescription['startDate']);
    final DateTime? expiresAt = _asDateTime(prescription['expiresAt']);
    final DateTime? archivedAt = _asDateTime(prescription['archivedAt']);
    final String uploadedBy = (prescription['uploadedBy'] ?? '') as String;
    final String? documentUrl = prescription['fileUrl'] as String?;
    final String documentName =
        (prescription['fileName'] ?? 'Ordonnance') as String;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: secondaryColor.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: secondaryColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Début: ${_formatDate(startDate)}',
            style: TextStyle(color: Colors.black87),
          ),
          Text(
            'Fin: ${_formatDate(expiresAt)}',
            style: TextStyle(color: Colors.black87),
          ),
          Text(
            'Durée: ${_formatDurationText(durationDays)}',
            style: TextStyle(color: Colors.black87),
          ),
          SizedBox(height: 6),
          Text(
            archivedAt != null
                ? 'Archivée le ${_formatDate(archivedAt)}'
                : 'Expirée le ${_formatDate(expiresAt)}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (uploadedBy.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              'Ajoutée par $uploadedBy',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: (documentUrl != null && documentUrl.isNotEmpty)
                  ? () => _viewDocument(documentUrl, documentName)
                  : null,
              icon: Icon(Icons.visibility_outlined),
              label: Text('Voir le document'),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _resolveBirthdate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatBirthdate(dynamic rawBirthdate) {
    final birthdate = _resolveBirthdate(rawBirthdate);
    if (birthdate == null) {
      return 'Non renseignée';
    }
    return DateFormat('dd/MM/yyyy').format(birthdate);
  }

  int _calculateAge(dynamic rawBirthdate) {
    final birthdate = _resolveBirthdate(rawBirthdate);
    if (birthdate == null) {
      return 0;
    }

    try {
      DateTime today = DateTime.now();
      int age = today.year - birthdate.year;
      if (today.month < birthdate.month ||
          (today.month == birthdate.month && today.day < birthdate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  String _calculateAgeDisplay(dynamic rawBirthdate) {
    final birthdate = _resolveBirthdate(rawBirthdate);
    if (birthdate == null) {
      return 'Âge inconnu';
    }

    try {
      DateTime now = DateTime.now();

      // Calcul de la différence en mois et années
      int months = (now.difference(birthdate).inDays / 30.44).floor();

      if (months < 12) {
        return '$months mois';
      } else {
        int years = (months / 12).floor();
        int remainingMonths = months % 12;

        if (years == 1) {
          return '1 an';
        } else {
          return '$years ans';
        }
      }
    } catch (e) {
      return 'Âge inconnu';
    }
  }

  double? _normalizeWeight(dynamic rawWeight) {
    if (rawWeight == null) {
      return null;
    }
    if (rawWeight is num) {
      return rawWeight.toDouble();
    }
    if (rawWeight is String) {
      final sanitized = rawWeight.trim().replaceAll(',', '.');
      if (sanitized.isEmpty) {
        return null;
      }
      return double.tryParse(sanitized);
    }
    return null;
  }

  Widget _buildWeightChip() {
    final double? weightValue = _normalizeWeight(childData['weight']);
    final bool hasWeight = weightValue != null;

    final String label = hasWeight
        ? 'Poids : ${_weightFormat.format(weightValue)} kg'
        : 'Poids : non renseigné';

    return InkWell(
      onTap: _isReadOnly ? () => _ensureEditingAllowed() : _editWeight,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: hasWeight ? primaryColor : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.edit,
              size: 16,
              color: _isReadOnly ? Colors.grey : primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(String title, List<Widget> children) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonthlySummary(Map<String, dynamic> fin) {
    final salary = fin['monthlySalary'];
    if (salary != null && (salary is num) && salary > 0) {
      return 'Salaire net: ${salary.toString()}€';
    }
    return 'À compléter';
  }

  Widget _buildInfoRow(String label, String value,
      {IconData? icon,
      Color? valueColor,
      VoidCallback? onEdit,
      bool showEditIcon = true,
      String? documentUrl,
      String? documentName}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey.shade600),
            SizedBox(width: 8),
          ],
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
          // Bouton pour voir le document si disponible
          if (documentUrl != null && documentUrl.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(Icons.visibility,
                    color: Colors.blue.shade700, size: 18),
                onPressed: () =>
                    _viewDocument(documentUrl, documentName ?? 'Document'),
                constraints: BoxConstraints(),
                padding: EdgeInsets.all(8),
                visualDensity: VisualDensity.compact,
                tooltip: 'Voir le document',
              ),
            ),
            SizedBox(width: 4),
          ],
          // Bouton d'édition
          if (showEditIcon && onEdit != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(Icons.edit, color: Colors.amber.shade700, size: 18),
                onPressed: onEdit,
                constraints: BoxConstraints(),
                padding: EdgeInsets.all(8),
                visualDensity: VisualDensity.compact,
                tooltip: 'Modifier',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthorizationRow(String label, bool? value,
      {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: value == true
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: value == true
                    ? Colors.green.withOpacity(0.5)
                    : Colors.red.withOpacity(0.5),
                width: 1,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  value == true ? Icons.check_circle : Icons.cancel,
                  color: value == true ? Colors.green : Colors.red,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  value == true ? 'OUI' : 'NON',
                  style: TextStyle(
                    color: value == true ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          if (onEdit != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(Icons.edit, color: Colors.amber.shade700, size: 18),
                onPressed: onEdit,
                constraints: BoxConstraints(),
                padding: EdgeInsets.all(8),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackgroundColor,
      body: Column(
        children: [
          // En-tête avec fond de couleur - Identique aux autres écrans
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
                        if (_isParentMode) {
                          Navigator.of(context).maybePop();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
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
                        "Profil complet",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Bouton fiche urgence
                    Container(
                      margin: EdgeInsets.only(left: 8),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _generateEmergencySheet(),
                        child: Icon(
                          Icons.assignment_ind_outlined,
                          color: Colors.white,
                          size: 24,
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
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isReadOnly)
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock_outline,
                                    color: Colors.orange.shade700),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Lecture seule : ce profil est lié à une autre assistante.",
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // En-tête avec photo et nom
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: secondaryColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: secondaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: primaryColor.withOpacity(0.3),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: childData['photoUrl'] != null
                                        ? ClipOval(
                                            child: Image.network(
                                              childData['photoUrl'],
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null)
                                                  return child;
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
                                        : Icon(Icons.person,
                                            size: 40,
                                            color:
                                                primaryColor.withOpacity(0.5)),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: _isPhotoUploading
                                          ? Container(
                                              padding: EdgeInsets.all(6),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            )
                                          : IconButton(
                                              icon: Icon(Icons.camera_alt,
                                                  color: Colors.white,
                                                  size: 16),
                                              onPressed: _isReadOnly
                                                  ? () => _ensureEditingAllowed(
                                                        customMessage:
                                                            "Vous n'avez pas les droits pour modifier la photo.",
                                                      )
                                                  : () => _updateChildPhoto(),
                                              constraints: BoxConstraints(),
                                              padding: EdgeInsets.all(6),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${childData['firstName']} ${childData['lastName']}',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                primaryColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.edit,
                                                color: primaryColor, size: 18),
                                            onPressed: _isReadOnly
                                                ? () => _ensureEditingAllowed()
                                                : () async {
                                                    // Éditer le nom
                                                    await _editTextData(
                                                        'profile',
                                                        'firstName',
                                                        childData['firstName'],
                                                        'Prénom');
                                                  },
                                            constraints: BoxConstraints(),
                                            padding: EdgeInsets.all(8),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Date de naissance: ${_formatBirthdate(childData['birthdate'])}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                primaryColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.edit,
                                                color: primaryColor, size: 18),
                                            onPressed: _isReadOnly
                                                ? () => _ensureEditingAllowed()
                                                : () async {
                                                    await _editBirthdate();
                                                  },
                                            constraints: BoxConstraints(),
                                            padding: EdgeInsets.all(8),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                primaryColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color:
                                                  primaryColor.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            _calculateAgeDisplay(
                                                childData['birthdate']),
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        _buildWeightChip(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Section Autorisations
                        _buildProfileSection(
                          '📋 Autorisations',
                          [
                            _buildAuthorizationRow(
                              'Photos/Vidéos',
                              authorizations['photos'],
                              onEdit: () async {
                                await _editBooleanData(
                                    'authorizations',
                                    'photos',
                                    authorizations['photos'] ?? false,
                                    'Autorisation Photos/Vidéos');
                              },
                            ),
                            _buildAuthorizationRow(
                              'Sorties',
                              authorizations['outings'],
                              onEdit: () async {
                                await _editBooleanData(
                                    'authorizations',
                                    'outings',
                                    authorizations['outings'] ?? false,
                                    'Autorisation Sorties');
                              },
                            ),
                            _buildAuthorizationRow(
                              'Maquillage',
                              authorizations['makeup'],
                              onEdit: () async {
                                await _editBooleanData(
                                    'authorizations',
                                    'makeup',
                                    authorizations['makeup'] ?? false,
                                    'Autorisation Maquillage');
                              },
                            ),
                          ],
                        ),

                        // Section Documents
                        // Section Documents
                        _buildProfileSection(
                          '📑 Documents',
                          [
                            _buildVaccinationDocumentsRow(),
                            _buildAuthorizationRow(
                              'PAI (Projet d\'Accueil Individualisé)',
                              documents['hasPAI'],
                              onEdit: () async {
                                await _editBooleanData('documents', 'hasPAI',
                                    documents['hasPAI'] ?? false, 'PAI');
                              },
                            ),
                            if (documents['hasPAI'] == true)
                              _buildInfoRow(
                                'Document PAI',
                                _isDocumentUploading
                                    ? 'Téléchargement...'
                                    : (documents['paiUrl'] != null
                                        ? 'Fourni'
                                        : 'Non fourni'),
                                valueColor: _isDocumentUploading
                                    ? Colors.orange
                                    : (documents['paiUrl'] != null
                                        ? Colors.green
                                        : Colors.red),
                                documentUrl: documents['paiUrl'],
                                documentName:
                                    documents['paiFileName'] ?? 'Document PAI',
                                onEdit: _isDocumentUploading
                                    ? null
                                    : () async {
                                        await _uploadDocument(
                                            'documents', 'paiUrl');
                                      },
                                showEditIcon: !_isDocumentUploading,
                              ),
                            _buildAuthorizationRow(
                              'Allergies (hors alimentaire)',
                              documents['hasAllergies'],
                              onEdit: () async {
                                await _editBooleanData(
                                    'documents',
                                    'hasAllergies',
                                    documents['hasAllergies'] ?? false,
                                    'Allergies');
                              },
                            ),
                            if (documents['hasAllergies'] == true)
                              _buildInfoRow(
                                'Description des allergies',
                                documents['allergiesDescription'] ??
                                    'Non précisé',
                                onEdit: () async {
                                  await _editTextData(
                                      'documents',
                                      'allergiesDescription',
                                      documents['allergiesDescription'] ?? '',
                                      'Description des allergies');
                                },
                              ),
                            _buildInfoRow(
                              'Ordonnances',
                              _activePrescriptions.isEmpty
                                  ? 'Aucune ordonnance en cours'
                                  : (_activePrescriptions.length == 1
                                      ? '1 ordonnance en cours'
                                      : '${_activePrescriptions.length} ordonnances en cours'),
                              icon: Icons.receipt_long,
                              valueColor: _activePrescriptions.isEmpty
                                  ? Colors.red
                                  : Colors.green,
                              onEdit: _openPrescriptionManager,
                            ),
                          ],
                        ),

                        // Section Alimentation
                        _buildProfileSection(
                          '🍽 Alimentation',
                          [
                            _buildAuthorizationRow(
                              'Allergies alimentaires',
                              mealInfo['hasFoodAllergies'],
                              onEdit: () async {
                                await _editBooleanData(
                                    'mealInfo',
                                    'hasFoodAllergies',
                                    mealInfo['hasFoodAllergies'] ?? false,
                                    'Allergies alimentaires');
                              },
                            ),
                            if (mealInfo['hasFoodAllergies'] == true)
                              _buildInfoRow(
                                'Description',
                                mealInfo['foodAllergiesDescription'] ??
                                    'Non précisé',
                                onEdit: () async {
                                  await _editTextData(
                                      'mealInfo',
                                      'foodAllergiesDescription',
                                      mealInfo['foodAllergiesDescription'] ??
                                          '',
                                      'Description des allergies alimentaires');
                                },
                              ),
                            _buildAuthorizationRow(
                              'Régime alimentaire spécifique',
                              mealInfo['hasSpecialDiet'],
                              onEdit: () async {
                                await _editBooleanData(
                                    'mealInfo',
                                    'hasSpecialDiet',
                                    mealInfo['hasSpecialDiet'] ?? false,
                                    'Régime alimentaire spécifique');
                              },
                            ),
                            if (mealInfo['hasSpecialDiet'] == true)
                              _buildInfoRow(
                                'Description',
                                mealInfo['specialDietDescription'] ??
                                    'Non précisé',
                                onEdit: () async {
                                  await _editTextData(
                                      'mealInfo',
                                      'specialDietDescription',
                                      mealInfo['specialDietDescription'] ?? '',
                                      'Description du régime alimentaire');
                                },
                              ),
                          ],
                        ),

                        // Section Mémo mensuel (financier)
                        _buildProfileSection(
                          '💶 Mémo mensuel',
                          [
                            // Sélecteur Oui/Non comme les autres
                            _buildAuthorizationRow(
                              'Utiliser le mémo mensuel',
                              (financialInfo['useMonthlyTable'] == true),
                              onEdit: _editUseMonthlyTableToggle,
                            ),
                            if (financialInfo['useMonthlyTable'] == true) ...[
                              _buildInfoRow(
                                'Configuration',
                                _formatMonthlySummary(financialInfo),
                                icon: Icons.edit_note,
                                onEdit: _editMonthlyTableFields,
                              ),
                            ],
                          ],
                        ),

                        // Section Personnes autorisées à récupérer l'enfant
                        _buildProfileSection(
                          '👨‍👩‍👧 Personnes autorisées',
                          [
                            _buildAuthorizationRow(
                              'Parent 1 : ${childData['parent1']['firstName'] ?? ''} ${childData['parent1']['lastName'] ?? ''}',
                              authorizedPickup['parent1'] ?? true,
                              onEdit: () async {
                                await _editBooleanData(
                                    'authorizedPickup',
                                    'parent1',
                                    authorizedPickup['parent1'] ?? true,
                                    'Autorisation Parent 1');
                              },
                            ),
                            _buildAuthorizationRow(
                              'Parent 2 : ${childData['parent2']['firstName'] ?? ''} ${childData['parent2']['lastName'] ?? ''}',
                              authorizedPickup['parent2'] ?? false,
                              onEdit: () async {
                                await _editBooleanData(
                                    'authorizedPickup',
                                    'parent2',
                                    authorizedPickup['parent2'] ?? false,
                                    'Autorisation Parent 2');
                              },
                            ),
                            if (authorizedPickup['extraPersons'] != null) ...[
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Autres personnes autorisées:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.person_add,
                                          color: primaryColor, size: 18),
                                      onPressed: () {
                                        // Implémenter l'ajout d'une personne autorisée
                                      },
                                      constraints: BoxConstraints(),
                                      padding: EdgeInsets.all(8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              ...((authorizedPickup['extraPersons']
                                          as Map<String, dynamic>?)
                                      ?.entries
                                      .map((entry) {
                                    final person =
                                        entry.value as Map<String, dynamic>;
                                    return Container(
                                      margin:
                                          EdgeInsets.only(left: 8, bottom: 12),
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: secondaryColor.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(10),
                                        border:
                                            Border.all(color: secondaryColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  primaryColor.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.person_outline,
                                              color: primaryColor,
                                              size: 18,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${person['firstName']} ${person['lastName']}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  '${person['phone']}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: primaryColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(Icons.edit,
                                                      color: primaryColor,
                                                      size: 16),
                                                  onPressed: () {
                                                    // Implémenter l'édition d'une personne autorisée
                                                  },
                                                  constraints: BoxConstraints(),
                                                  padding: EdgeInsets.all(6),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.red
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(Icons.delete,
                                                      color: Colors.red,
                                                      size: 16),
                                                  onPressed: () {
                                                    // Implémenter la suppression d'une personne autorisée
                                                  },
                                                  constraints: BoxConstraints(),
                                                  padding: EdgeInsets.all(6),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList() ??
                                  []),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          // Bouton de fermeture en bas
        ],
      ),
      bottomNavigationBar:
          _isParentMode ? _buildParentBottomNavigationBar(context) : null,
    );
  }

  Future<void> _editBirthdate() async {
    if (_isReadOnly) {
      _ensureEditingAllowed();
      return;
    }

    DateTime initialDate = DateTime.now();
    final rawBirthdate = childData['birthdate'];
    if (rawBirthdate is Timestamp) {
      initialDate = rawBirthdate.toDate();
    } else if (rawBirthdate is String) {
      try {
        initialDate = DateTime.parse(rawBirthdate);
      } catch (_) {}
    }

    final DateTime firstDate =
        DateTime.now().subtract(const Duration(days: 365 * 30));
    final DateTime lastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('fr'),
      helpText: "Modifier la date de naissance",
      cancelText: "ANNULER",
      confirmText: "VALIDER",
    );

    if (picked == null || !mounted) {
      return;
    }

    if (picked.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "La date de naissance ne peut pas être dans le futur.",
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    try {
      final timestamp = Timestamp.fromDate(picked);
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .set({
        'birthdate': timestamp,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      }, SetOptions(merge: true));

      setState(() {
        childData['birthdate'] = timestamp;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Date de naissance mise à jour."),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la mise à jour : $e"),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  BottomNavigationBar _buildParentBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.black87,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      unselectedLabelStyle:
          const TextStyle(fontSize: 12, color: Colors.black87),
      items: [
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/noel/Icone_home_noel.png',
            width: 60,
            height: 60,
          ),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/noel/Icone_message_noel.png',
            width: 60,
            height: 60,
          ),
          activeIcon: Image.asset(
            'assets/images/noel/Icone_message_noel.png',
            width: 60,
            height: 60,
            color: primaryColor,
          ),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/noel/Icone_stock_noel.png',
            width: 60,
            height: 60,
          ),
          activeIcon: Image.asset(
            'assets/images/noel/Icone_stock_noel.png',
            width: 60,
            height: 60,
            color: primaryColor,
          ),
          label: 'Stocks',
        ),
      ],
      onTap: (index) {
        if (index == 0) {
          context.go('/parent/home');
        } else if (index == 1) {
          context.go('/parent/messages');
        } else if (index == 2) {
          context.go('/parent/stocks');
        }
      },
    );
  }
}
