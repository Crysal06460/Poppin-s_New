import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class ChildProfileDetailsScreen extends StatefulWidget {
  final String childId;
  final String structureId; // Ajout du paramètre structureId

  const ChildProfileDetailsScreen({
    Key? key,
    required this.childId,
    required this.structureId, // Le rendre obligatoire
  }) : super(key: key);

  @override
  _ChildProfileDetailsScreenState createState() =>
      _ChildProfileDetailsScreenState();
}

class _ChildProfileDetailsScreenState extends State<ChildProfileDetailsScreen> {
  bool isLoading = true;
  Map<String, dynamic> childData = {};
  Map<String, dynamic> authorizations = {};
  Map<String, dynamic> documents = {};
  Map<String, dynamic> mealInfo = {};
  Map<String, dynamic> authorizedPickup = {};

  // Nouvelles variables pour la gestion des uploads
  final ImagePicker _picker = ImagePicker();
  bool _isPhotoUploading = false;
  bool _isDocumentUploading = false;

  // Définition des couleurs de la palette
  static const Color primaryColor = Color(0xFF3D9DF2); // Bleu #3D9DF2
  static const Color secondaryColor = Color(0xFFDFE9F2); // Bleu clair #DFE9F2

  @override
  void initState() {
    super.initState();
    _loadChildProfile();
  }

  Future<void> _updateChildPhoto() async {
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
        // Ajoutez explicitement les données des parents
        'parent1': data['parent1'] ?? {},
        'parent2': data['parent2'] ?? {},
      };

      // Extraction des autorisations
      authorizations = data['authorizations'] ?? {};

      // Extraction des documents
      documents = data['documents'] ?? {};

      // Extraction des infos alimentaires
      mealInfo = data['mealInfo'] ?? {};

      // Extraction des autorisations de récupération
      authorizedPickup = data['authorizedPickup'] ?? {};

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
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

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
        case 'profile':
          updatePath = field;
          setState(() {
            childData[field] = value;
          });
          break;
      }

      // Création de l'objet de mise à jour
      updateData[updatePath] = value;

      // Mise à jour dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget
              .structureId) // <-- Utilisez l'ID de structure passé en paramètre
          .collection('children')
          .doc(widget.childId)
          .update(updateData);

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

  // Méthode pour gérer l'édition des données textuelles
  Future<void> _editTextData(
      String section, String field, String currentValue, String label) async {
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

  // Méthode pour uploader un document
  Future<void> _uploadDocument(String section, String field) async {
    try {
      // Afficher un dialogue avec des options
      final action = await showDialog<String>(
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
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text(
                'Annuler',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );

      if (action == 'cancel' || action == null) return;

      setState(() => _isDocumentUploading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      String? fileUrl;
      String? fileName;

      if (action == 'gallery' || action == 'camera') {
        // Utiliser image picker
        final XFile? image = await _picker.pickImage(
          source:
              action == 'gallery' ? ImageSource.gallery : ImageSource.camera,
          imageQuality: 70,
        );

        if (image == null) {
          setState(() => _isDocumentUploading = false);
          return;
        }

        final bytes = await File(image.path).readAsBytes();
        fileName = image.name;

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('children_documents')
            .child(widget.childId)
            .child('${field}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
        fileUrl = await storageRef.getDownloadURL();
      } else if (action == 'file') {
        // Utiliser file picker
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        );

        if (result == null || result.files.isEmpty) {
          setState(() => _isDocumentUploading = false);
          return;
        }

        final file = result.files.first;
        fileName = file.name;

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('children_documents')
            .child(widget.childId)
            .child(
                '${field}_${DateTime.now().millisecondsSinceEpoch}.${file.extension}');

        if (kIsWeb && file.bytes != null) {
          await storageRef.putData(file.bytes!);
        } else if (file.path != null) {
          await storageRef.putFile(File(file.path!));
        }

        fileUrl = await storageRef.getDownloadURL();
      }

      if (fileUrl != null) {
        // Sauvegarder dans Firestore
        await _saveChanges(section, field, fileUrl);
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
    } catch (e) {
      print("Erreur lors de l'upload du document: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du téléchargement du document'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isDocumentUploading = false);
    }
  }

  String _formatBirthdate(String? birthdateString) {
    if (birthdateString == null || birthdateString.isEmpty) {
      return 'Non renseignée';
    }

    try {
      DateTime birthdate = DateTime.parse(birthdateString);
      return DateFormat('dd/MM/yyyy').format(birthdate);
    } catch (e) {
      return 'Format invalide';
    }
  }

  int _calculateAge(String? birthdateString) {
    if (birthdateString == null || birthdateString.isEmpty) {
      return 0;
    }

    try {
      DateTime birthdate = DateTime.parse(birthdateString);
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

  String _calculateAgeDisplay(String? birthdateString) {
    if (birthdateString == null || birthdateString.isEmpty) {
      return 'Âge inconnu';
    }

    try {
      DateTime birthdate = DateTime.parse(birthdateString);
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
      backgroundColor: Colors.grey[50],
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
                        if (Navigator.of(context).canPop()) {
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
                                              onPressed: _updateChildPhoto,
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
                                            onPressed: () async {
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
                                            onPressed: () async {
                                              // Implémenter l'édition de la date de naissance
                                              // Nécessite un DatePicker
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
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: primaryColor.withOpacity(0.3),
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
                            _buildInfoRow(
                              'Carnet de vaccination',
                              documents['vaccinUrl'] != null
                                  ? 'Fourni'
                                  : 'Non fourni',
                              icon: Icons.medical_information,
                              valueColor: documents['vaccinUrl'] != null
                                  ? Colors.green
                                  : Colors.red,
                              documentUrl: documents['vaccinUrl'],
                              documentName: documents['vaccinFileName'] ??
                                  'Carnet de vaccination',
                              onEdit: () async {
                                await _uploadDocument('documents', 'vaccinUrl');
                              },
                            ),
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

                        // Section Personnes autorisées à récupérer l'enfant
                        _buildProfileSection(
                          '👨‍👩‍👧 Autorisations de récupération',
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
    );
  }
}
