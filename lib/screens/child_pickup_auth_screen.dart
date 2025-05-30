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

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
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
  String structureName = "Chargement...";
  bool isLoadingStructure = true;
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
    _loadStructureInfo(); // AJOUT : Charger les infos de structure
    _loadParentsInfo();
  }

  Future<void> _loadStructureInfo() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Utilisateur non connecté");
        return;
      }

      final userEmail = user.email?.toLowerCase() ?? '';
      print("📧 Email utilisateur: $userEmail");

      // Vérifier d'abord si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        print("👤 Données utilisateur trouvées: $userData");

        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM
          final structureId = userData['structureId'];
          print("🏢 Utilisateur MAM détecté - ID structure: $structureId");

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
            print("🏢 Nom de structure MAM récupéré: $structureName");
          } else {
            print("❌ Document structure MAM non trouvé");
            setState(() {
              structureName = 'Structure inconnue';
              isLoadingStructure = false;
            });
          }
        } else {
          // Utilisateur normal (assistante maternelle individuelle)
          print("👩‍🍼 Utilisateur assistante maternelle individuelle");
          final structureDoc = await FirebaseFirestore.instance
              .collection('structures')
              .doc(user.uid)
              .get();

          if (structureDoc.exists) {
            final data = structureDoc.data() as Map<String, dynamic>;
            setState(() {
              structureName = data['structureName'] ?? 'Structure inconnue';
              isLoadingStructure = false;
            });
            print("🏢 Nom de structure individuelle récupéré: $structureName");
          } else {
            print("❌ Document structure individuelle non trouvé");
            setState(() {
              structureName = 'Structure inconnue';
              isLoadingStructure = false;
            });
          }
        }
      } else {
        print(
            "❌ Document utilisateur non trouvé, utilisation de l'ID utilisateur par défaut");
        // Fallback : utiliser l'ID utilisateur comme ID de structure
        final structureDoc = await FirebaseFirestore.instance
            .collection('structures')
            .doc(user.uid)
            .get();

        if (structureDoc.exists) {
          final data = structureDoc.data() as Map<String, dynamic>;
          setState(() {
            structureName = data['structureName'] ?? 'Structure inconnue';
            isLoadingStructure = false;
          });
          print("🏢 Nom de structure fallback récupéré: $structureName");
        } else {
          print("❌ Aucun document structure trouvé");
          setState(() {
            structureName = 'Structure inconnue';
            isLoadingStructure = false;
          });
        }
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des infos de structure: $e");
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
            // Panneau gauche - Aperçu des autorisations
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
                              maxLines:
                                  2, // AJOUT : Permet l'affichage sur 2 lignes
                              overflow: TextOverflow
                                  .visible, // MODIFICATION : Permet l'affichage complet
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Aperçu des parents
                      Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    Icons.family_restroom,
                                    color: primaryBlue,
                                    size: (maxWidth * 0.02).clamp(16.0, 24.0),
                                  ),
                                ),
                                SizedBox(
                                    width: (maxWidth * 0.01).clamp(6.0, 12.0)),
                                Flexible(
                                  child: Text(
                                    "Parents",
                                    style: TextStyle(
                                      fontSize:
                                          (maxWidth * 0.018).clamp(14.0, 20.0),
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: maxHeight * 0.02),

                            // Parent 1
                            if (_parent1Name != null)
                              _buildParentPreviewTablet(
                                  "Parent 1", _parent1Name!, true, maxWidth),

// Parent 2
                            if (_hasParent2 && _parent2Name != null) ...[
                              SizedBox(
                                  height: maxHeight *
                                      0.025), // Augmenté de 0.015 à 0.025
                              _buildParentPreviewTablet(
                                  "Parent 2",
                                  _parent2Name!,
                                  _parent2Authorized ?? false,
                                  maxWidth),
                            ],
                          ],
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.03),

                      // Aperçu des personnes supplémentaires
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(
                              (maxWidth * 0.02).clamp(12.0, 20.0)),
                          decoration: BoxDecoration(
                            color:
                                _addExtraPerson && _authorizedPersons.isNotEmpty
                                    ? lightBlue.withOpacity(0.2)
                                    : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _addExtraPerson &&
                                      _authorizedPersons.isNotEmpty
                                  ? primaryBlue.withOpacity(0.3)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                        (maxWidth * 0.01).clamp(6.0, 12.0)),
                                    decoration: BoxDecoration(
                                      color: _addExtraPerson &&
                                              _authorizedPersons.isNotEmpty
                                          ? primaryBlue.withOpacity(0.1)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.person_add,
                                      color: _addExtraPerson &&
                                              _authorizedPersons.isNotEmpty
                                          ? primaryBlue
                                          : Colors.grey,
                                      size: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    ),
                                  ),
                                  SizedBox(
                                      width:
                                          (maxWidth * 0.01).clamp(6.0, 12.0)),
                                  Flexible(
                                    child: Text(
                                      "Personnes supplémentaires",
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
                              if (_addExtraPerson &&
                                  _authorizedPersons.isNotEmpty) ...[
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _authorizedPersons.length,
                                    itemBuilder: (context, index) {
                                      final person = _authorizedPersons[index];
                                      return Container(
                                        margin: EdgeInsets.only(
                                            bottom: maxHeight * 0.015),
                                        padding: EdgeInsets.all(
                                            (maxWidth * 0.015)
                                                .clamp(8.0, 15.0)),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color:
                                                  primaryBlue.withOpacity(0.2)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Personne ${index + 1}",
                                              style: TextStyle(
                                                fontSize: (maxWidth * 0.016)
                                                    .clamp(12.0, 18.0),
                                                fontWeight: FontWeight.w600,
                                                color: primaryBlue,
                                              ),
                                            ),
                                            SizedBox(height: maxHeight * 0.01),
                                            Text(
                                              person.firstName.isEmpty &&
                                                      person.lastName.isEmpty
                                                  ? "Informations non renseignées"
                                                  : "${person.firstName} ${person.lastName}"
                                                      .trim(),
                                              style: TextStyle(
                                                fontSize: (maxWidth * 0.014)
                                                    .clamp(10.0, 16.0),
                                                color: person.firstName
                                                            .isEmpty &&
                                                        person.lastName.isEmpty
                                                    ? Colors.grey.shade500
                                                    : Colors.black87,
                                                fontStyle: person.firstName
                                                            .isEmpty &&
                                                        person.lastName.isEmpty
                                                    ? FontStyle.italic
                                                    : FontStyle.normal,
                                              ),
                                            ),
                                            if (person.phone.isNotEmpty) ...[
                                              SizedBox(
                                                  height: maxHeight * 0.005),
                                              Text(
                                                person.phone,
                                                style: TextStyle(
                                                  fontSize: (maxWidth * 0.014)
                                                      .clamp(10.0, 16.0),
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ] else ...[
                                Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(
                                            (maxWidth * 0.015)
                                                .clamp(8.0, 15.0)),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.person_off,
                                          size: (maxWidth * 0.03)
                                              .clamp(20.0, 35.0),
                                          color: Colors.grey,
                                        ),
                                      ),
                                      SizedBox(height: maxHeight * 0.015),
                                      Text(
                                        _addExtraPerson
                                            ? "Aucune personne ajoutée"
                                            : "Aucune personne supplémentaire",
                                        style: TextStyle(
                                          fontSize: (maxWidth * 0.014)
                                              .clamp(10.0, 16.0),
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Panneau droit - Formulaire
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
                        "Personnes autorisées à récuperer",
                        style: TextStyle(
                          fontSize: (maxWidth * 0.025).clamp(18.0, 28.0),
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      // Description
                      Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryBlue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(
                                  (maxWidth * 0.01).clamp(6.0, 12.0)),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: primaryBlue,
                                size: (maxWidth * 0.02).clamp(16.0, 24.0),
                              ),
                            ),
                            SizedBox(
                                width: (maxWidth * 0.015).clamp(8.0, 15.0)),
                            Expanded(
                              child: Text(
                                "Sélectionnez les personnes autorisées à récupérer l'enfant",
                                style: TextStyle(
                                  fontSize:
                                      (maxWidth * 0.016).clamp(12.0, 18.0),
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Contenu du formulaire
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Parents
                              _buildParentsSectionTablet(maxWidth, maxHeight),

                              SizedBox(height: maxHeight * 0.04),

                              // Section Personnes supplémentaires
                              _buildExtraPersonsSectionTablet(
                                  maxWidth, maxHeight),
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
                            onPressed:
                                _isSaving ? null : _savePickupAuthorizations,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      (maxWidth * 0.03).clamp(20.0, 40.0),
                                  vertical:
                                      (maxHeight * 0.02).clamp(12.0, 20.0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                            ),
                            child: _isSaving
                                ? SizedBox(
                                    width: (maxWidth * 0.02).clamp(16.0, 24.0),
                                    height: (maxWidth * 0.02).clamp(16.0, 24.0),
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
                                          fontSize: (maxWidth * 0.02)
                                              .clamp(14.0, 20.0),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(
                                          width: (maxWidth * 0.01)
                                              .clamp(6.0, 12.0)),
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

  Widget _buildParentPreviewTablet(
      String label, String name, bool isAuthorized, double maxWidth) {
    return Container(
      padding: EdgeInsets.all((maxWidth * 0.015).clamp(8.0, 15.0)),
      decoration: BoxDecoration(
        color: isAuthorized ? lightBlue.withOpacity(0.3) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAuthorized
              ? primaryBlue.withOpacity(0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Première ligne : Label et statut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: (maxWidth * 0.014).clamp(10.0, 16.0),
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: (maxWidth * 0.008).clamp(4.0, 8.0),
                  vertical: (maxWidth * 0.004).clamp(2.0, 6.0),
                ),
                decoration: BoxDecoration(
                  color: isAuthorized ? primaryBlue : Colors.grey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAuthorized ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: (maxWidth * 0.012).clamp(10.0, 16.0),
                    ),
                    SizedBox(width: 4),
                    Text(
                      isAuthorized ? "Autorisé" : "Non autorisé",
                      style: TextStyle(
                        fontSize: (maxWidth * 0.012).clamp(8.0, 14.0),
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: (maxWidth * 0.008).clamp(4.0, 8.0)),
          // Deuxième ligne : Nom complet
          Text(
            name,
            style: TextStyle(
              fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines:
                2, // Permet au nom de s'afficher sur 2 lignes si nécessaire
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildParentsSectionTablet(double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all((maxWidth * 0.01).clamp(6.0, 12.0)),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.family_restroom,
                  color: primaryBlue,
                  size: (maxWidth * 0.02).clamp(16.0, 24.0),
                ),
              ),
              SizedBox(width: (maxWidth * 0.015).clamp(8.0, 15.0)),
              Text(
                "Parents",
                style: TextStyle(
                  fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: maxHeight * 0.02),

          // Parent 1 (toujours autorisé)
          if (_parent1Name != null)
            _buildParentRowTablet(
              _parent1Name!,
              true,
              (value) {}, // Ne pas changer, toujours autorisé
              enabled: false,
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),

          SizedBox(height: maxHeight * 0.015),

          // Parent 2 s'il existe
          if (_hasParent2 && _parent2Name != null)
            _buildParentRowTablet(
              _parent2Name!,
              _parent2Authorized ?? false,
              (value) {
                setState(() => _parent2Authorized = value);
              },
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
        ],
      ),
    );
  }

  Widget _buildParentRowTablet(
      String name, bool isAuthorized, Function(bool) onChanged,
      {bool enabled = true,
      required double maxWidth,
      required double maxHeight}) {
    return Container(
      padding: EdgeInsets.all((maxWidth * 0.015).clamp(8.0, 15.0)),
      decoration: BoxDecoration(
        color: Colors.white,
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
                fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            children: [
              Text(
                "Autorisé",
                style: TextStyle(
                  fontSize: (maxWidth * 0.014).clamp(10.0, 16.0),
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(width: (maxWidth * 0.01).clamp(6.0, 12.0)),
              Transform.scale(
                scale: (maxWidth * 0.001).clamp(0.8, 1.2),
                child: Switch(
                  value: isAuthorized,
                  onChanged: enabled ? onChanged : null,
                  activeColor: primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtraPersonsSectionTablet(double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all((maxWidth * 0.02).clamp(12.0, 20.0)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all((maxWidth * 0.01).clamp(6.0, 12.0)),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_add,
                  color: primaryBlue,
                  size: (maxWidth * 0.02).clamp(16.0, 24.0),
                ),
              ),
              SizedBox(width: (maxWidth * 0.015).clamp(8.0, 15.0)),
              Expanded(
                child: Text(
                  "Personnes autorisées supplémentaires",
                  style: TextStyle(
                    fontSize: (maxWidth * 0.018).clamp(14.0, 20.0),
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: maxHeight * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Ajouter une autre personne ?",
                  style: TextStyle(
                    fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Transform.scale(
                scale: (maxWidth * 0.001).clamp(0.8, 1.2),
                child: Switch(
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
              ),
            ],
          ),
          if (_addExtraPerson) ...[
            SizedBox(height: maxHeight * 0.02),
            ..._authorizedPersons.asMap().entries.map((entry) {
              final index = entry.key;
              final person = entry.value;
              return Container(
                margin: EdgeInsets.only(bottom: maxHeight * 0.02),
                padding: EdgeInsets.all((maxWidth * 0.015).clamp(8.0, 15.0)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Personne ${index + 1}",
                          style: TextStyle(
                            fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: primaryRed),
                          onPressed: () => _removeAuthorizedPerson(index),
                          iconSize: (maxWidth * 0.02).clamp(16.0, 24.0),
                        ),
                      ],
                    ),
                    SizedBox(height: maxHeight * 0.015),
                    _buildPersonFieldTablet(
                      "Prénom",
                      person.firstNameController,
                      maxWidth,
                      maxHeight,
                    ),
                    SizedBox(height: maxHeight * 0.015),
                    _buildPersonFieldTablet(
                      "Nom",
                      person.lastNameController,
                      maxWidth,
                      maxHeight,
                    ),
                    SizedBox(height: maxHeight * 0.015),
                    _buildPersonFieldTablet(
                      "Téléphone",
                      person.phoneController,
                      maxWidth,
                      maxHeight,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),

            // Bouton pour ajouter une personne
            SizedBox(height: maxHeight * 0.02),
            Center(
              child: OutlinedButton.icon(
                onPressed: _addAuthorizedPerson,
                icon: Icon(Icons.add,
                    color: primaryBlue,
                    size: (maxWidth * 0.02).clamp(16.0, 24.0)),
                label: Text(
                  "Ajouter une personne",
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: (maxWidth * 0.016).clamp(12.0, 18.0),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryBlue),
                  padding: EdgeInsets.symmetric(
                    horizontal: (maxWidth * 0.02).clamp(12.0, 20.0),
                    vertical: (maxHeight * 0.015).clamp(8.0, 15.0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonFieldTablet(String label, TextEditingController controller,
      double maxWidth, double maxHeight,
      {TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? inputFormatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: (maxWidth * 0.014).clamp(10.0, 16.0),
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: (maxHeight * 0.01).clamp(4.0, 8.0)),
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
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: (value) => setState(() {}), // Pour rafraîchir l'aperçu
            decoration: InputDecoration(
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: (maxWidth * 0.015).clamp(8.0, 15.0),
                vertical: (maxHeight * 0.015).clamp(8.0, 15.0),
              ),
            ),
            style: TextStyle(fontSize: (maxWidth * 0.014).clamp(10.0, 16.0)),
          ),
        ),
      ],
    );
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
                      structureName, // MODIFICATION : Utiliser structureName au lieu de "Poppins"
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
                        'Autorisé à récupérer',
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

  // 5. CORRECTION : Bouton retour dans build() pour utiliser context.go au lieu de Navigator.pop

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
                            // Back button (seulement sur iPhone) - CORRECTION ICI
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                // CORRECTION : Utiliser context.go au lieu de Navigator.pop
                                if (widget.childId.isNotEmpty) {
                                  print(
                                      "🔄 Retour vers child-documents avec childId: ${widget.childId}");
                                  context.go('/child-documents',
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
                                              _parent2Authorized ?? false,
                                              (value) {
                                            setState(() =>
                                                _parent2Authorized = value);
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.grey.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    "Personne ${index + 1}",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                                keyboardType:
                                                    TextInputType.phone,
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
                                          icon: Icon(Icons.add,
                                              color: primaryBlue),
                                          label: Text(
                                            "Ajouter une personne",
                                            style:
                                                TextStyle(color: primaryBlue),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side:
                                                BorderSide(color: primaryBlue),
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
                                onPressed: _isSaving
                                    ? null
                                    : _savePickupAuthorizations,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
