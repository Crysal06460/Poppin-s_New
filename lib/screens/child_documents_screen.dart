import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ChildDocumentsScreen extends StatefulWidget {
  final String childId;
  final String structureId;

  const ChildDocumentsScreen({
    Key? key,
    required this.childId,
    required this.structureId,
  }) : super(key: key);

  @override
  _ChildDocumentsScreenState createState() => _ChildDocumentsScreenState();
}

class _ChildDocumentsScreenState extends State<ChildDocumentsScreen> {
  // Variables pour les vaccins
  PlatformFile? _vaccinFile;
  Uint8List? _vaccinBytes;
  String? _vaccinFileUrl;
  String? _vaccinFileName;
  bool _isVaccinUploading = false;

  // Variables pour le PAI
  bool? _hasPAI = false;
  PlatformFile? _paiFile;
  Uint8List? _paiBytes;
  String? _paiFileUrl;
  String? _paiFileName;
  bool _isPAIUploading = false;

  // Variables pour les allergies
  bool? _hasAllergies = false;
  final TextEditingController _allergiesController = TextEditingController();

  bool _isSaving = false;
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

  @override
  void dispose() {
    _allergiesController.dispose();
    super.dispose();
  }

  // Méthode pour choisir le fichier de vaccination
  Future<void> _pickVaccinFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _vaccinFile = result.files.first;
          _vaccinFileName = result.files.first.name;

          if (kIsWeb || result.files.first.bytes != null) {
            _vaccinBytes = result.files.first.bytes;
            print(
                "Document de vaccination chargé: ${_vaccinBytes?.length} bytes");
          }
        });
      }
    } catch (e) {
      print("Erreur lors de la sélection du fichier de vaccination: $e");
      _showError("Erreur lors de la sélection du fichier");
    }
  }

  // Méthode pour choisir le fichier PAI
  Future<void> _pickPAIFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _paiFile = result.files.first;
          _paiFileName = result.files.first.name;

          if (kIsWeb || result.files.first.bytes != null) {
            _paiBytes = result.files.first.bytes;
            print("Document PAI chargé: ${_paiBytes?.length} bytes");
          }
        });
      }
    } catch (e) {
      print("Erreur lors de la sélection du fichier PAI: $e");
      _showError("Erreur lors de la sélection du fichier");
    }
  }

  // Méthode pour sauvegarder tous les documents
  Future<void> _saveDocuments() async {
    setState(() => _isSaving = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      // Récupérer l'email de l'utilisateur actuel (crucial pour la traçabilité)
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      // Vérifier d'abord si l'utilisateur est un membre MAM
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
              "🔄 Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // 1. Upload du document de vaccination
      if (_vaccinFile != null) {
        setState(() => _isVaccinUploading = true);

        // Créer un nom de fichier unique avec l'extension originale
        String fileExtension = _vaccinFileName?.split('.').last ?? 'unknown';
        final ref = FirebaseStorage.instance
            .ref()
            .child('children_documents')
            .child(widget.childId)
            .child('vaccin.$fileExtension');

        try {
          // Pour web ou si les bytes sont disponibles
          if ((kIsWeb || _vaccinFile!.bytes != null) && _vaccinBytes != null) {
            await ref.putData(_vaccinBytes!,
                SettableMetadata(contentType: _getContentType(fileExtension)));
          }
          // Pour mobile avec path
          else if (_vaccinFile!.path != null) {
            await ref.putFile(File(_vaccinFile!.path!));
          } else {
            throw Exception("Impossible d'accéder au fichier de vaccination");
          }

          _vaccinFileUrl = await ref.getDownloadURL();
          print("URL du document de vaccination obtenue: $_vaccinFileUrl");
          setState(() => _isVaccinUploading = false);
        } catch (e) {
          print("Erreur d'upload du document de vaccination: $e");
          setState(() => _isVaccinUploading = false);
        }
      }

      // 2. Upload du document PAI si nécessaire
      if (_hasPAI == true && _paiFile != null) {
        setState(() => _isPAIUploading = true);

        // Créer un nom de fichier unique avec l'extension originale
        String fileExtension = _paiFileName?.split('.').last ?? 'unknown';
        final ref = FirebaseStorage.instance
            .ref()
            .child('children_documents')
            .child(widget.childId)
            .child('pai.$fileExtension');

        try {
          // Pour web ou si les bytes sont disponibles
          if ((kIsWeb || _paiFile!.bytes != null) && _paiBytes != null) {
            await ref.putData(_paiBytes!,
                SettableMetadata(contentType: _getContentType(fileExtension)));
          }
          // Pour mobile avec path
          else if (_paiFile!.path != null) {
            await ref.putFile(File(_paiFile!.path!));
          } else {
            throw Exception("Impossible d'accéder au fichier PAI");
          }

          _paiFileUrl = await ref.getDownloadURL();
          print("URL du document PAI obtenue: $_paiFileUrl");
          setState(() => _isPAIUploading = false);
        } catch (e) {
          print("Erreur d'upload du document PAI: $e");
          setState(() => _isPAIUploading = false);
        }
      }

      // 3. Mise à jour dans Firestore avec l'ID de structure approprié
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(widget.childId)
          .update({
        'documents': {
          'vaccinUrl': _vaccinFileUrl,
          'vaccinFileName': _vaccinFileName,
          'hasPAI': _hasPAI,
          'paiUrl': _paiFileUrl,
          'paiFileName': _paiFileName,
          'hasAllergies': _hasAllergies,
          'allergiesDescription':
              _hasAllergies == true ? _allergiesController.text : '',
        },
        'lastUpdatedBy': currentUserEmail,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      print("Documents sauvegardés avec succès par: $currentUserEmail");

      if (mounted) {
        context.go('/child-pickup-auth', extra: widget.childId);
      }
    } catch (e) {
      print("Erreur lors de la sauvegarde des documents: $e");
      _showError("Une erreur est survenue lors de la sauvegarde");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Détermine le content type en fonction de l'extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
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
                      Icons.file_copy_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '07 - Documents importants',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

                  // Documents section
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
                                  Icons.assignment_rounded,
                                  color: primaryBlue,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                "Documents conseillés",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          // Carnet de vaccination
                          Text(
                            "Carnet de vaccination",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _isVaccinUploading ? null : _pickVaccinFile,
                            child: Container(
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryBlue.withOpacity(0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    offset: const Offset(0, 2),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                              child: _isVaccinUploading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                          color: primaryBlue))
                                  : _vaccinFile != null
                                      ? _displaySelectedFile(
                                          _vaccinBytes, _vaccinFileName)
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.upload_file,
                                                size: 48, color: Colors.grey),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Télécharger le carnet de vaccination",
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 16),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // PAI Section
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
                                  Icons.medical_services_rounded,
                                  color: primaryBlue,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Projet d'Accueil Individualisé (PAI)",
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
                            "L'enfant a-t-il un PAI (Projet d'Accueil Individualisé) ?",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildToggleButton(
                                    "Oui", _hasPAI == true, () {
                                  setState(() => _hasPAI = true);
                                }),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildToggleButton(
                                    "Non", _hasPAI == false, () {
                                  setState(() {
                                    _hasPAI = false;
                                    _paiFile = null;
                                    _paiBytes = null;
                                  });
                                }),
                              ),
                            ],
                          ),
                          if (_hasPAI == true) ...[
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: _isPAIUploading ? null : _pickPAIFile,
                              child: Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: primaryBlue.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      offset: const Offset(0, 2),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: _isPAIUploading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                            color: primaryBlue))
                                    : _paiFile != null
                                        ? _displaySelectedFile(
                                            _paiBytes, _paiFileName)
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.upload_file,
                                                  size: 48, color: Colors.grey),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Télécharger le document PAI",
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 16),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Allergies Section
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
                                  Icons.warning_amber_rounded,
                                  color: primaryBlue,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                "Allergies",
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
                            "L'enfant a-t-il des allergies (hors alimentaire) ?",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildToggleButton(
                                    "Oui", _hasAllergies == true, () {
                                  setState(() => _hasAllergies = true);
                                }),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildToggleButton(
                                    "Non", _hasAllergies == false, () {
                                  setState(() {
                                    _hasAllergies = false;
                                    _allergiesController.clear();
                                  });
                                }),
                              ),
                            ],
                          ),
                          if (_hasAllergies == true) ...[
                            const SizedBox(height: 20),
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
                                controller: _allergiesController,
                                decoration: InputDecoration(
                                  labelText: "Précisez les allergies",
                                  labelStyle:
                                      TextStyle(color: Colors.grey.shade600),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primaryBlue, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                maxLines: 3,
                                style: const TextStyle(fontSize: 16),
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
                      onPressed: _isSaving ? null : _saveDocuments,
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
                                Icon(Icons.arrow_forward, color: Colors.white),
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

  // Affiche le fichier sélectionné
  Widget _displaySelectedFile(Uint8List? bytes, String? fileName) {
    // Si c'est une image et que nous avons les bytes
    if (bytes != null &&
        fileName != null &&
        (fileName.toLowerCase().endsWith('.jpg') ||
            fileName.toLowerCase().endsWith('.jpeg') ||
            fileName.toLowerCase().endsWith('.png'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
        ),
      );
    }
    // Sinon on affiche une icône et le nom du fichier
    else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getFileIcon(fileName), size: 42, color: primaryBlue),
          const SizedBox(height: 8),
          Text(
            fileName ?? "Fichier sélectionné",
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
  }

  // Détermine l'icône à afficher selon le type de fichier
  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file;

    if (fileName.toLowerCase().endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    } else if (fileName.toLowerCase().endsWith('.doc') ||
        fileName.toLowerCase().endsWith('.docx')) {
      return Icons.article;
    } else if (fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png')) {
      return Icons.image;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 5,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
