import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ChildFinalDetailsScreen extends StatefulWidget {
  final String childId;
  final String structureId;

  const ChildFinalDetailsScreen({
    Key? key,
    required this.childId,
    required this.structureId,
  }) : super(key: key);

  @override
  _ChildFinalDetailsScreenState createState() =>
      _ChildFinalDetailsScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _ChildFinalDetailsScreenState extends State<ChildFinalDetailsScreen> {
  bool? _makeupAllowed;
  bool? _photosAllowed;
  bool? _outingsAllowed;
  XFile? _pickedFile;
  Uint8List? _webImage;
  String? _photoUrl;
  bool _isLoading = false;
  int _selectedIndex = 2; // Pour la barre de navigation du bas
  String structureName = "Chargement...";
  bool isLoadingStructure = true;
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
    initializeDateFormatting('fr_FR', null);
    // AJOUT : Charger les infos de structure
    _loadStructureInfo();
  }

  Future<void> _loadCurrentData() async {
    setState(() => _isLoading = true);
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .get();

      if (childDoc.exists) {
        final data = childDoc.data();
        if (data != null && data['authorizations'] != null) {
          setState(() {
            _makeupAllowed = data['authorizations']['makeup'];
            _photosAllowed = data['authorizations']['photos'];
            _outingsAllowed = data['authorizations']['outings'];
            _photoUrl = data['photoUrl'];
          });
        }
      }
    } catch (e) {
      print("Erreur lors du chargement des données existantes: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStructureInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoadingStructure = false);
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
              "🔄 Child Final Details: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // Récupération des informations de la structure avec l'ID correct
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

  Widget _buildTabletLayout() {
    return LayoutBuilder(builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth;
      final double maxHeight = constraints.maxHeight;
      final double sideMargin = (maxWidth * 0.03).clamp(10.0, 30.0);
      final double columnGap = (maxWidth * 0.025).clamp(10.0, 25.0);

      return Padding(
        padding: EdgeInsets.fromLTRB(
            sideMargin, maxHeight * 0.02, sideMargin, maxHeight * 0.02),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panneau gauche - Aperçu des autorisations et photo
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

                      // Aperçu des autorisations
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                              (maxWidth * 0.02).clamp(12.0, 20.0)),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Titre autorisations
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
                                      Icons.check_circle_outline,
                                      color: primaryBlue,
                                      size: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    ),
                                  ),
                                  SizedBox(
                                      width:
                                          (maxWidth * 0.01).clamp(6.0, 12.0)),
                                  Flexible(
                                    child: Text(
                                      "Autorisations",
                                      style: TextStyle(
                                        fontSize: (maxWidth * 0.018)
                                            .clamp(14.0, 20.0),
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: maxHeight * 0.03),

                              // Autorisations
                              _buildAuthorizationPreviewTablet(
                                  "Maquillage", _makeupAllowed, maxWidth),
                              SizedBox(
                                  height: maxHeight *
                                      0.03), // Augmenté de 0.02 à 0.03
                              _buildAuthorizationPreviewTablet(
                                  "Photos/Vidéos", _photosAllowed, maxWidth),
                              SizedBox(
                                  height: maxHeight *
                                      0.03), // Augmenté de 0.02 à 0.03
                              _buildAuthorizationPreviewTablet(
                                  "Sorties", _outingsAllowed, maxWidth),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.03),

                      // Aperçu de la photo
                      Expanded(
                        flex: 2,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                              (maxWidth * 0.02).clamp(12.0, 20.0)),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Titre photo
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
                                      Icons.photo_camera,
                                      color: primaryBlue,
                                      size: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    ),
                                  ),
                                  SizedBox(
                                      width:
                                          (maxWidth * 0.01).clamp(6.0, 12.0)),
                                  Flexible(
                                    child: Text(
                                      "Photo",
                                      style: TextStyle(
                                        fontSize: (maxWidth * 0.018)
                                            .clamp(14.0, 20.0),
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: maxHeight * 0.02),

                              // Aperçu photo
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey.withOpacity(0.3),
                                        width: 1),
                                  ),
                                  child: _pickedFile != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: kIsWeb && _webImage != null
                                              ? Image.memory(_webImage!,
                                                  fit: BoxFit.cover)
                                              : Image.file(
                                                  File(_pickedFile!.path),
                                                  fit: BoxFit.cover),
                                        )
                                      : _photoUrl != null &&
                                              _photoUrl!.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                _photoUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(Icons.broken_image,
                                                          size: maxWidth * 0.03,
                                                          color: Colors.grey),
                                                      SizedBox(height: 4),
                                                      Text("Erreur image",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontSize:
                                                                  maxWidth *
                                                                      0.012)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.add_a_photo,
                                                      size: maxWidth * 0.03,
                                                      color: Colors.grey),
                                                  SizedBox(height: 4),
                                                  Text("Aucune photo",
                                                      style: TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: maxWidth *
                                                              0.012)),
                                                ],
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

            // Panneau droit - Formulaires
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
                        "Informations supplémentaires",
                        style: TextStyle(
                          fontSize: (maxWidth * 0.025).clamp(18.0, 28.0),
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Formulaires
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Autorisations
                              _buildAuthorizationSectionTablet(
                                  maxWidth, maxHeight),

                              SizedBox(height: maxHeight * 0.04),

                              // Photo
                              _buildPhotoSectionTablet(maxWidth, maxHeight),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.03),

                      // Bouton Continuer
                      Center(
                        child: Container(
                          width: (maxWidth * 0.25).clamp(200.0, 300.0),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      (maxWidth * 0.03).clamp(20.0, 40.0),
                                  vertical:
                                      (maxHeight * 0.02).clamp(12.0, 20.0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 3,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    height: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Continuer",
                                        style: TextStyle(
                                          fontSize: (maxWidth * 0.02)
                                              .clamp(14.0, 20.0),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward,
                                          color: Colors.white,
                                          size: (maxWidth * 0.02)
                                              .clamp(16.0, 24.0)),
                                    ],
                                  ),
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

  Widget _buildAuthorizationPreviewTablet(
      String label, bool? value, double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          "$label:",
          style: TextStyle(
            fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(
            height: (maxWidth * 0.008)
                .clamp(4.0, 8.0)), // Petit espacement entre label et valeur
        // Valeur avec statut
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: (maxWidth * 0.01).clamp(6.0, 12.0),
            vertical: (maxWidth * 0.005).clamp(3.0, 8.0),
          ),
          decoration: BoxDecoration(
            color: value == null
                ? Colors.grey.shade200
                : (value
                    ? primaryBlue.withOpacity(0.1)
                    : primaryRed.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value == null
                  ? Colors.grey.shade300
                  : (value
                      ? primaryBlue.withOpacity(0.3)
                      : primaryRed.withOpacity(0.3)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value == null
                    ? Icons.help_outline
                    : (value ? Icons.check_circle : Icons.cancel),
                size: (maxWidth * 0.015).clamp(12.0, 18.0),
                color: value == null
                    ? Colors.grey
                    : (value ? primaryBlue : primaryRed),
              ),
              SizedBox(width: 4),
              Text(
                value == null ? "Non défini" : (value ? "Oui" : "Non"),
                style: TextStyle(
                  fontSize: (maxWidth * 0.014).clamp(10.0, 16.0),
                  fontWeight: FontWeight.w600,
                  color: value == null
                      ? Colors.grey.shade600
                      : (value ? primaryBlue : primaryRed),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorizationSectionTablet(double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all((maxWidth * 0.01).clamp(6.0, 12.0)),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: (maxWidth * 0.02).clamp(16.0, 24.0),
                ),
              ),
              SizedBox(width: (maxWidth * 0.015).clamp(8.0, 15.0)),
              Text(
                "Autorisations",
                style: TextStyle(
                  fontSize: (maxWidth * 0.02).clamp(16.0, 22.0),
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: maxHeight * 0.02),
          Text(
            "Veuillez spécifier les autorisations pour cet enfant :",
            style: TextStyle(
              fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: maxHeight * 0.03),
          _buildAuthorizationOptionTablet(
            "Maquillage",
            _makeupAllowed,
            (value) => setState(() => _makeupAllowed = value),
            maxWidth,
            maxHeight,
          ),
          SizedBox(height: maxHeight * 0.02),
          _buildAuthorizationOptionTablet(
            "Photos/Vidéos",
            _photosAllowed,
            (value) => setState(() => _photosAllowed = value),
            maxWidth,
            maxHeight,
          ),
          SizedBox(height: maxHeight * 0.02),
          _buildAuthorizationOptionTablet(
            "Sorties",
            _outingsAllowed,
            (value) => setState(() => _outingsAllowed = value),
            maxWidth,
            maxHeight,
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorizationOptionTablet(String title, bool? value,
      Function(bool?) onChanged, double maxWidth, double maxHeight) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 5,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
            child: Text(title,
                style: TextStyle(
                  fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                )),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: (maxHeight * 0.01).clamp(6.0, 12.0),
                horizontal: (maxWidth * 0.02).clamp(12.0, 20.0)),
            child: Row(
              children: [
                // Oui option
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(true),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: (maxHeight * 0.015).clamp(8.0, 15.0),
                          horizontal: (maxWidth * 0.01).clamp(6.0, 12.0)),
                      child: Row(
                        children: [
                          Container(
                            width: (maxWidth * 0.025).clamp(20.0, 30.0),
                            height: (maxWidth * 0.025).clamp(20.0, 30.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: value == true
                                ? Center(
                                    child: Container(
                                      width:
                                          (maxWidth * 0.018).clamp(14.0, 22.0),
                                      height:
                                          (maxWidth * 0.018).clamp(14.0, 22.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(width: (maxWidth * 0.015).clamp(8.0, 15.0)),
                          Text(
                            'Oui',
                            style: TextStyle(
                              fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Non option
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(false),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: (maxHeight * 0.015).clamp(8.0, 15.0),
                          horizontal: (maxWidth * 0.01).clamp(6.0, 12.0)),
                      child: Row(
                        children: [
                          Container(
                            width: (maxWidth * 0.025).clamp(20.0, 30.0),
                            height: (maxWidth * 0.025).clamp(20.0, 30.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: value == false
                                ? Center(
                                    child: Container(
                                      width:
                                          (maxWidth * 0.018).clamp(14.0, 22.0),
                                      height:
                                          (maxWidth * 0.018).clamp(14.0, 22.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(width: (maxWidth * 0.015).clamp(8.0, 15.0)),
                          Text(
                            'Non',
                            style: TextStyle(
                              fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              "Si vous quittez l'ajout de l'enfant maintenant, celui-ci ne sera pas ajouté et toutes les informations saisies seront perdues.\n\nÊtes-vous sûr de vouloir continuer ?",
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

  Widget _buildPhotoSectionTablet(double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all((maxWidth * 0.01).clamp(6.0, 12.0)),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.photo_camera,
                  color: Colors.white,
                  size: (maxWidth * 0.02).clamp(16.0, 24.0),
                ),
              ),
              SizedBox(width: (maxWidth * 0.015).clamp(8.0, 15.0)),
              Text(
                "Photo de l'enfant",
                style: TextStyle(
                  fontSize: (maxWidth * 0.02).clamp(16.0, 22.0),
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: maxHeight * 0.03),

          // Photo container
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: (maxHeight * 0.25).clamp(150.0, 250.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
              ),
              child: _pickedFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb && _webImage != null
                          ? Image.memory(_webImage!, fit: BoxFit.cover)
                          : Image.file(File(_pickedFile!.path),
                              fit: BoxFit.cover),
                    )
                  : _photoUrl != null && _photoUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    size: (maxWidth * 0.04).clamp(30.0, 50.0),
                                    color: Colors.grey),
                                SizedBox(height: 8),
                                Text("Impossible de charger la photo",
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: (maxWidth * 0.016)
                                            .clamp(12.0, 18.0))),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                size: (maxWidth * 0.04).clamp(30.0, 50.0),
                                color: Colors.grey),
                            SizedBox(height: 8),
                            Text("Ajouter photo de l'enfant",
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontSize:
                                        (maxWidth * 0.016).clamp(12.0, 18.0))),
                          ],
                        ),
            ),
          ),

          SizedBox(height: maxHeight * 0.02),

          // Camera button
          ElevatedButton.icon(
            onPressed: _pickCameraImage,
            icon: Icon(Icons.camera_alt,
                size: (maxWidth * 0.02).clamp(16.0, 24.0)),
            label: Text(
              'Prendre une photo',
              style: TextStyle(
                fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  vertical: (maxHeight * 0.02).clamp(12.0, 20.0)),
              minimumSize:
                  Size(double.infinity, (maxHeight * 0.06).clamp(40.0, 60.0)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _pickedFile = image;
        if (kIsWeb) {
          image.readAsBytes().then((value) {
            setState(() => _webImage = value);
            print("Image web chargée: ${value.length} bytes");
          });
        }
      });
    }
  }

  Future<void> _pickCameraImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _pickedFile = image;
        if (kIsWeb) {
          image.readAsBytes().then((value) {
            setState(() => _webImage = value);
            print("Image web chargée: ${value.length} bytes");
          });
        }
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_pickedFile == null) {
      return null;
    }

    print("Début upload image...");

    final ref = FirebaseStorage.instance
        .ref()
        .child('images_temp/${DateTime.now().millisecondsSinceEpoch}.jpg');

    try {
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
      return await ref.getDownloadURL();
    } catch (e) {
      print("Erreur détaillée: $e");

      if (e is FirebaseException) {
        print("Code d'erreur Firebase: ${e.code}");
        print("Message Firebase: ${e.message}");
      }

      rethrow;
    }
  }

  Future<void> _saveDetails() async {
    if (_makeupAllowed == null ||
        _photosAllowed == null ||
        _outingsAllowed == null) {
      _showError("Veuillez répondre à toutes les autorisations");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? photoUrl;
      if (_pickedFile != null) {
        try {
          photoUrl = await _uploadImage();
        } catch (e) {
          print("Erreur lors de l'upload de l'image: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "Impossible d'uploader la photo, mais le reste des informations sera sauvegardé."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      print("Mise à jour Firestore avec structureId: ${widget.structureId}");
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .update({
        'authorizations': {
          'makeup': _makeupAllowed,
          'photos': _photosAllowed,
          'outings': _outingsAllowed,
        },
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      print("Mise à jour réussie");

      if (mounted) {
        context.go('/child-documents', extra: {
          'childId': widget.childId,
          'structureId': widget.structureId
        });
      }
    } catch (e) {
      print("Erreur globale: $e");
      _showError(
          "Une erreur est survenue lors de la sauvegarde. Veuillez réessayer.");
    } finally {
      setState(() => _isLoading = false);
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
    if (index == 0) {
      // Dashboard
      _showExitWarning(context, '/dashboard');
    } else if (index == 1) {
      // Home
      _showExitWarning(context, '/home');
    } else if (index == 2) {
      // Déjà sur cette page d'ajout - ne rien faire
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
                      structureName, // CHANGEMENT : utiliser structureName au lieu de "Poppins"
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
                      Icons.tune,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Infos supp.',
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
    // Déterminer si on est sur iPad
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryBlue))
                : isTabletDevice
                    ? _buildTabletLayout() // Layout spécifique pour iPad
                    : SingleChildScrollView(
                        // Layout original pour iPhone
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Back button - CORRECTION : Utiliser context.go au lieu de Navigator.pop
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                // CHANGEMENT : Utiliser context.go au lieu de Navigator.pop
                                if (widget.childId.isNotEmpty) {
                                  print(
                                      "🔄 Retour vers schedule-info avec childId: ${widget.childId}");
                                  context.go('/schedule-info',
                                      extra: widget.childId);
                                } else {
                                  _showError("Erreur : ID d'enfant manquant !");
                                }
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: lightBlue,
                                foregroundColor: primaryBlue,
                                padding: EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Autorisations card
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
                                            Icons.check_circle_outline,
                                            color: primaryBlue,
                                            size: 24,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          "Autorisations",
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
                                      "Veuillez spécifier les autorisations pour cet enfant :",
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildAuthorizationOption(
                                      "Maquillage",
                                      _makeupAllowed,
                                      (value) => setState(
                                          () => _makeupAllowed = value),
                                    ),
                                    _buildAuthorizationOption(
                                      "Photos/Vidéos",
                                      _photosAllowed,
                                      (value) => setState(
                                          () => _photosAllowed = value),
                                    ),
                                    _buildAuthorizationOption(
                                      "Sorties",
                                      _outingsAllowed,
                                      (value) => setState(
                                          () => _outingsAllowed = value),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Photo card
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
                                            Icons.photo_camera,
                                            color: primaryBlue,
                                            size: 24,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          "Photo de l'enfant",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: primaryBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),

                                    // Photo container
                                    GestureDetector(
                                      onTap: _pickImage,
                                      child: Container(
                                        width: double.infinity,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color:
                                                  Colors.grey.withOpacity(0.3),
                                              width: 2),
                                        ),
                                        child: _pickedFile != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: kIsWeb &&
                                                        _webImage != null
                                                    ? Image.memory(_webImage!,
                                                        fit: BoxFit.cover)
                                                    : Image.file(
                                                        File(_pickedFile!.path),
                                                        fit: BoxFit.cover),
                                              )
                                            : _photoUrl != null &&
                                                    _photoUrl!.isNotEmpty
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Image.network(
                                                      _photoUrl!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: const [
                                                          Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 48,
                                                              color:
                                                                  Colors.grey),
                                                          SizedBox(height: 8),
                                                          Text(
                                                              "Impossible de charger la photo",
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                  fontSize:
                                                                      16)),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: const [
                                                      Icon(Icons.add_a_photo,
                                                          size: 48,
                                                          color: Colors.grey),
                                                      SizedBox(height: 8),
                                                      Text(
                                                          "Ajouter photo de l'enfant",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontSize: 16)),
                                                    ],
                                                  ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Camera button
                                    ElevatedButton.icon(
                                      onPressed: _pickCameraImage,
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Prendre une photo'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        minimumSize:
                                            const Size(double.infinity, 54),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Continue button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _saveDetails,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Continuer",
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward,
                                            color: Colors.white),
                                      ],
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

  Widget _buildAuthorizationOption(
      String title, bool? value, Function(bool?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 5,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                )),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                // Oui option
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(true),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: value == true
                                ? Center(
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Oui',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Non option
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(false),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: value == false
                                ? Center(
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Non',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
