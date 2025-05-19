import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:poppins_app/widgets/custom_bottom_navigation.dart';

class ActivityScreen extends StatefulWidget {
  final BuildContext context;

  const ActivityScreen({Key? key, required this.context}) : super(key: key);

  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  String structureId = "";
  int _selectedIndex = 1;
  TextEditingController _observationsController = TextEditingController();
  TextEditingController newActivityController = TextEditingController();

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Utilisation des couleurs officielles
  Color primaryColor = Color(0xFF3D9DF2); // primaryBlue par défaut
  Color secondaryColor = Color(0xFFDFE9F2); // lightBlue par défaut

  String _activityType = "Musique";
  String _activityDuration = "1 heure";
  String _participationLevel = "Bien participé";
  String _activityTime = "";

  // Types d'activités standards et personnalisées
  List<String> standardActivityTypes = [
    "Musique",
    "Sport",
    "Dessin",
    "Lecture",
    "Jeux",
    "Danse",
    "Autre"
  ];

  List<String> customActivityTypes = [];

  // Combinaison des activités standards et personnalisées
  List<String> get activityTypes =>
      [...standardActivityTypes, ...customActivityTypes];

  // Liste des durées disponibles
  final List<String> durations = [
    "15 minutes",
    "30 minutes",
    "45 minutes",
    "1 heure",
    "1 heure 15",
    "1 heure 30",
    "1 heure 45",
    "2 heures"
  ];

  int _getParticipationLevel(String level) {
    switch (level) {
      case 'Pas participé':
        return 1;
      case 'Peu participé':
        return 2;
      case 'Bien participé':
        return 3;
      case 'Très bien participé':
        return 4;
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    _observationsController.dispose();
    newActivityController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadStructureId();
      _loadCustomActivities();
      _loadEnfantsDuJour();
    });
  }

  // Fonction pour obtenir l'ID de structure
  Future<void> _loadStructureId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String tempStructureId = user.uid;
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          tempStructureId = userData['structureId'];
        }
      }

      setState(() {
        structureId = tempStructureId;
      });
    } catch (e) {
      print("Erreur lors du chargement de l'ID de structure: $e");
    }
  }

  // Fonction pour charger les activités personnalisées
  Future<void> _loadCustomActivities() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Obtenir l'ID de structure
      if (structureId.isEmpty) {
        await _loadStructureId();
      }

      // Charger les activités personnalisées depuis Firestore
      final customActivitiesDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('settings')
          .doc('customActivityTypes')
          .get();

      if (customActivitiesDoc.exists) {
        final items =
            List<String>.from(customActivitiesDoc.data()?['items'] ?? []);

        setState(() {
          customActivityTypes = items;
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des activités personnalisées: $e");
    }
  }

  // Fonction pour ajouter une activité personnalisée
  // Fonction pour ajouter une activité personnalisée
  Future<bool> _addCustomActivity(String newActivity) async {
    if (newActivity.trim().isEmpty) return false; // Retourner false si vide

    try {
      // Vérifier que l'ID de structure est disponible
      if (structureId.isEmpty) {
        await _loadStructureId();
      }

      // Ajouter à la liste locale
      setState(() {
        if (!customActivityTypes.contains(newActivity.trim())) {
          customActivityTypes.add(newActivity.trim());
        }
      });

      // Sauvegarder dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('settings')
          .doc('customActivityTypes')
          .set({
        'items': customActivityTypes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Activité ajoutée avec succès'),
          backgroundColor: primaryColor,
          duration: Duration(seconds: 2),
        ),
      );

      // Retournons true pour indiquer que l'ajout a réussi
      return true;
    } catch (e) {
      print("Erreur lors de l'ajout d'une activité personnalisée: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'ajout de l'activité"),
          backgroundColor: Colors.red,
        ),
      );

      // Retournons false pour indiquer que l'ajout a échoué
      return false;
    }
  }

// Fonction modifiée pour le dialogue d'ajout d'activité personnalisée
  void _showAddCustomActivityDialogFromActivityPopup(String childId) {
    newActivityController.text = '';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Ajouter une activité personnalisée'),
          content: TextField(
            controller: newActivityController,
            decoration: InputDecoration(
              hintText: "Nom de l'activité",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // Réafficher le popup d'ajout d'activité
                _showAddActivityPopup(childId);
              },
              child: Text(
                'ANNULER',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newActivityController.text.trim().isNotEmpty) {
                  await _addCustomActivity(newActivityController.text);
                  Navigator.pop(dialogContext);
                  // Réafficher le popup d'ajout d'activité
                  _showAddActivityPopup(childId);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'AJOUTER',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Fonction pour supprimer une activité personnalisée
  Future<void> _removeCustomActivity(String activity) async {
    try {
      // Vérifier si l'activité est utilisée
      bool isUsed = false;
      // Cette vérification pourrait être plus complexe en vérifiant toutes les activités,
      // mais pour simplifier, nous supposons qu'elle n'est pas utilisée

      // Supprimer de la liste locale
      setState(() {
        customActivityTypes.remove(activity);
      });

      // Mettre à jour dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('settings')
          .doc('customActivityTypes')
          .set({
        'items': customActivityTypes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Activité supprimée avec succès'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      print("Erreur lors de la suppression d'une activité personnalisée: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la suppression de l'activité"),
          backgroundColor: Colors.red,
        ),
      );
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
      if (structureId.isEmpty) {
        structureId = user.uid;
      }

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "🔄 Activités: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
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
        final structureData = structureSnapshot.data() as Map<String, dynamic>?;
        setState(() {
          structureName =
              structureData?['structureName'] ?? 'Structure inconnue';
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
            "👨‍👧‍👦 Activités: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Activités: Assistante Maternelle - affichage de tous les enfants");
      }

      // Diagnostic des enfants filtrés
      print(
          "🔍 DIAGNOSTIC ACTIVITÉS - Type de structure: $structureType, Utilisateur: $currentUserEmail");
      print(
          "🔍 DIAGNOSTIC ACTIVITÉS - Nombre total d'enfants: ${allChildren.length}, Nombre filtrés: ${filteredChildren.length}");

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui
      List<Map<String, dynamic>> tempEnfants = [];
      for (var child in filteredChildren) {
        if (child['schedule'] != null &&
            child['schedule'][capitalizedWeekday] != null) {
          String? photoUrl = child['photoUrl'];
          tempEnfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'structureId':
                structureId, // Ajouter l'ID de structure pour les requêtes futures
          });
        }
      }

      setState(() {
        enfants = tempEnfants;
        isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  IconData _getActivityTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'musique':
        return Icons.music_note;
      case 'sport':
        return Icons.fitness_center;
      case 'dessin':
        return Icons.brush;
      case 'lecture':
        return Icons.book;
      case 'jeux':
        return Icons.games;
      case 'danse':
        return Icons.music_note;
      default:
        return Icons.category;
    }
  }

  Widget _buildActivityIcon(String type) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child:
              Icon(_getActivityTypeIcon(type), color: primaryColor, size: 20),
        ),
        SizedBox(width: 8),
        Text(
          type,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showActivityDetailsPopup(Map<String, dynamic> activityData) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.02,
            vertical: screenHeight * 0.02,
          ),
          child: Container(
            width: screenWidth * 0.96,
            constraints: BoxConstraints(
              maxWidth: 500,
              minWidth: 250,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(screenWidth * 0.04),
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
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryColor.withOpacity(0.8), primaryColor],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(screenWidth * 0.04),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: screenWidth * 0.03,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.02),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.02),
                          ),
                          child: Icon(
                            Icons.directions_run,
                            color: Colors.white,
                            size: screenWidth * 0.06,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Activité de ${activityData['heure']}",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.05,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: screenWidth * 0.01),
                              Text(
                                DateFormat('dd MMMM yyyy', 'fr_FR')
                                    .format(activityData['date'].toDate())
                                    .toLowerCase(),
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenu
                  Padding(
                    padding: EdgeInsets.all(screenWidth * 0.04),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type d'activité
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.04,
                            vertical: screenWidth * 0.03,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.03),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getActivityTypeIcon(activityData['type']),
                                color: primaryColor,
                                size: screenWidth * 0.06,
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Text(
                                activityData['type'],
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w500,
                                  color: primaryColor.withOpacity(0.9),
                                ),
                              ),
                              Spacer(),
                              Text(
                                "Durée: ${activityData['duration']}",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: screenWidth * 0.04),

                        // Participation
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.04,
                            vertical: screenWidth * 0.03,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.03),
                          ),
                          child: Row(
                            children: [
                              Row(
                                children: List.generate(
                                  activityData['participationLevel'] ?? 0,
                                  (index) => Padding(
                                    padding: EdgeInsets.only(
                                      right: index <
                                              (activityData[
                                                          'participationLevel'] ??
                                                      0) -
                                                  1
                                          ? screenWidth * 0.01
                                          : 0,
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: screenWidth * 0.05,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Text(
                                "${activityData['participation']}",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Observations
                        if (activityData['observations']?.isNotEmpty ??
                            false) ...[
                          SizedBox(height: screenWidth * 0.04),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.03),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Observations",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: screenWidth * 0.02),
                                Text(
                                  activityData['observations'],
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Bouton Fermer
                        SizedBox(height: screenWidth * 0.04),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              padding: EdgeInsets.symmetric(
                                vertical: screenWidth * 0.03,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(screenWidth * 0.03),
                              ),
                            ),
                            child: Text(
                              "Fermer",
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
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

  // Dialogue pour ajouter une activité personnalisée
  void _showAddCustomActivityDialog() {
    newActivityController.text = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Ajouter une activité personnalisée'),
          content: TextField(
            controller: newActivityController,
            decoration: InputDecoration(
              hintText: "Nom de l'activité",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ANNULER',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (newActivityController.text.trim().isNotEmpty) {
                  _addCustomActivity(newActivityController.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'AJOUTER',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Dialogue pour gérer les activités personnalisées
  void _showManageCustomActivitiesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text('Gérer les activités personnalisées'),
              content: Container(
                width: double.maxFinite,
                child: customActivityTypes.isEmpty
                    ? Center(
                        child: Text(
                          'Aucune activité personnalisée',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: customActivityTypes.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(customActivityTypes[index]),
                            trailing: IconButton(
                              icon:
                                  Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                _removeCustomActivity(
                                    customActivityTypes[index]);
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'FERMER',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddCustomActivityDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'AJOUTER',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddActivityPopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String localActivityTime = _activityTime;
    String localActivityType = _activityType;
    String localActivityDuration = _activityDuration;
    String localParticipationLevel = _participationLevel;
    String? errorMessage;

    // Réorganiser les types d'activités pour placer les activités personnalisées en haut
    List<String> organizedActivityTypes = [
      ...customActivityTypes,
      // Séparateur si des activités personnalisées existent
      if (customActivityTypes.isNotEmpty) "_separator_",
      ...standardActivityTypes,
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ajouter une activité pour ${enfant['prenom']}",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: Text(
                          "Heure de l'activité",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          DatePicker.showTimePicker(
                            context,
                            showSecondsColumn: false,
                            showTitleActions: true,
                            onConfirm: (date) {
                              setState(() {
                                localActivityTime =
                                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                errorMessage = null;
                              });
                            },
                            currentTime: DateTime.now(),
                            locale: LocaleType.fr,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor.withOpacity(0.2),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          localActivityTime.isEmpty
                              ? 'Choisir l\'heure'
                              : localActivityTime,
                          style: TextStyle(fontSize: 18, color: primaryColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Quelle était l'activité :",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: (organizedActivityTypes
                                      .contains(localActivityType) &&
                                  localActivityType != "_separator_")
                              ? localActivityType
                              : standardActivityTypes.first,
                          isExpanded: true,
                          underline: Container(),
                          items: organizedActivityTypes.map((String value) {
                            if (value == "_separator_") {
                              // Séparateur entre activités personnalisées et standards
                              return DropdownMenuItem<String>(
                                enabled: false,
                                child: Container(
                                  height: 1,
                                  color: Colors.grey.shade300,
                                  margin: EdgeInsets.symmetric(vertical: 4),
                                ),
                              );
                            } else if (customActivityTypes.contains(value)) {
                              // Style spécial pour les activités personnalisées
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: primaryColor,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        value,
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              // Style standard pour les activités standards
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null && newValue != "_separator_") {
                              setState(() {
                                localActivityType = newValue;
                              });
                            }
                          },
                        ),
                      ),

                      // Bouton pour ajouter une activité personnalisée
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // Ferme le popup actuel
                            _showAddCustomActivityDialogFromActivityPopup(
                                childId);
                          },
                          icon: Icon(Icons.add_circle, color: primaryColor),
                          label: Text(
                            "Ajouter une activité personnalisée",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),

                      SizedBox(height: 20),
                      Text(
                        "Combien de temps a duré l'activité :",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: localActivityDuration,
                          isExpanded: true,
                          underline: Container(),
                          items: durations.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              localActivityDuration = newValue!;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Comment était la participation de ${enfant['prenom']} ?",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildParticipationButton(
                                  'Pas participé',
                                  localParticipationLevel,
                                  (value) {
                                    setState(() {
                                      localParticipationLevel = value;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _buildParticipationButton(
                                  'Peu participé',
                                  localParticipationLevel,
                                  (value) {
                                    setState(() {
                                      localParticipationLevel = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildParticipationButton(
                                  'Bien participé',
                                  localParticipationLevel,
                                  (value) {
                                    setState(() {
                                      localParticipationLevel = value;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _buildParticipationButton(
                                  'Très bien participé',
                                  localParticipationLevel,
                                  (value) {
                                    setState(() {
                                      localParticipationLevel = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _observationsController,
                        decoration: InputDecoration(
                          labelText: "Observations",
                          labelStyle:
                              TextStyle(fontSize: 16, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 20),

                      // Message d'erreur
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              "Annuler",
                              style:
                                  TextStyle(fontSize: 18, color: primaryColor),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              if (localActivityTime.isEmpty) {
                                setState(() {
                                  errorMessage =
                                      'Veuillez sélectionner une heure';
                                });
                                return;
                              }

                              // Réinitialiser le message d'erreur si tout est OK
                              setState(() {
                                errorMessage = null;
                              });

                              // Si tout est validé, ajouter l'activité
                              _activityTime = localActivityTime;
                              _activityType = localActivityType;
                              _activityDuration = localActivityDuration;
                              _participationLevel = localParticipationLevel;

                              // Ajouter l'activité dans Firebase
                              _addActivityToFirebase(childId);

                              // Fermer le popup une fois l'activité ajoutée
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Ajouter",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildParticipationButton(
    String level,
    String selectedLevel,
    Function(String) onSelect,
  ) {
    bool isSelected = selectedLevel == level;
    return GestureDetector(
      onTap: () => onSelect(level),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          level,
          style: TextStyle(
            color: isSelected ? primaryColor : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _addActivityToFirebase(String childId) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference activityRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser l'ID de structure correct
          .collection('children')
          .doc(childId)
          .collection('activites')
          .doc();

      final activityData = {
        'heure': _activityTime,
        'date': DateTime.now(),
        'type': _activityType,
        'duration': _activityDuration,
        'participation': _participationLevel,
        'participationLevel': _getParticipationLevel(_participationLevel),
        'observations': _observationsController.text,
      };

      await activityRef.set(activityData);

      // Réinitialisation des champs
      setState(() {
        _activityTime = '';
        _activityType = 'Musique';
        _activityDuration = '1 heure';
        _participationLevel = 'Bien participé';
        _observationsController.clear();
      });

      print("Activité ajoutée avec succès !");
    } catch (e) {
      print("Erreur lors de l'ajout de l'activité : $e");
    }
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

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    String genre = enfant['genre']?.toString() ?? 'Garçon';
    Color cardColor = Colors.white;
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
                  onPressed: () => _showAddActivityPopup(enfant['id']),
                ),
              ],
            ),
          ),
          // Liste des activités
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('activites')
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

              if (snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(12),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        "Aucune activité aujourd'hui",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final activityData =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showActivityDetailsPopup(activityData),
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
                              _getActivityTypeIcon(activityData['type']),
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      activityData['heure'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      activityData['type'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Durée: ${activityData['duration']}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: List.generate(
                              activityData['participationLevel'] ?? 0,
                              (index) => Icon(
                                Icons.star,
                                color: primaryYellow,
                                size: 16,
                              ),
                            ),
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

  @override
  Widget build(BuildContext context) {
    // Détection de l'iPad
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : enfants.isEmpty
                    ? _buildEmptyState()
                    : isTabletDevice
                        ? _buildTabletLayout() // Layout adapté pour iPad
                        : ListView.builder(
                            itemCount: enfants.length,
                            itemBuilder: _buildEnfantCard,
                          ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      // Ajout du bouton flottant pour gérer les activités personnalisées
      floatingActionButton: FloatingActionButton(
        onPressed: _showManageCustomActivitiesDialog,
        backgroundColor: primaryColor,
        child: Icon(Icons.playlist_add, color: Colors.white),
        tooltip: 'Gérer les activités personnalisées',
      ),
    );
  }

// Nouveau layout pour iPad - affiche les enfants dans une grille
  Widget _buildTabletLayout() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 cartes par ligne
        childAspectRatio: 1.2, // Un peu plus large que haut
        crossAxisSpacing: 20, // Espace horizontal entre les cartes
        mainAxisSpacing: 20, // Espace vertical entre les cartes
      ),
      itemCount: enfants.length,
      itemBuilder: (context, index) =>
          _buildEnfantCardForTablet(context, index),
    );
  }

// Carte enfant adaptée pour iPad
  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    String genre = enfant['genre']?.toString() ?? 'Garçon';
    Color cardColor = Colors.white;
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
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar plus grand pour iPad
                Container(
                  width: 70, // Plus grand pour iPad
                  height: 70, // Plus grand pour iPad
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
                              width: 65,
                              height: 65,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 28, // Plus grand pour iPad
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            enfant['prenom'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 28, // Plus grand pour iPad
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
                          fontSize: 22, // Plus grand pour iPad
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(10), // Plus grand pour iPad
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add,
                        color: primaryColor, size: 28), // Plus grand pour iPad
                  ),
                  onPressed: () => _showAddActivityPopup(enfant['id']),
                ),
              ],
            ),
          ),
          // Liste des activités - adaptée pour iPad
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid)
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('activites')
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

                if (snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Container(
                      padding: EdgeInsets.all(14), // Plus grand pour iPad
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          "Aucune activité aujourd'hui",
                          style: TextStyle(
                            fontSize: 16, // Plus grand pour iPad
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics:
                      BouncingScrollPhysics(), // Meilleur défilement pour iPad
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, 16), // Plus d'espace pour iPad
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: 10), // Plus d'espace pour iPad
                  itemBuilder: (context, index) {
                    final activityData = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => _showActivityDetailsPopup(activityData),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14), // Plus grand pour iPad
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: primaryColor.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding:
                                  EdgeInsets.all(10), // Plus grand pour iPad
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getActivityTypeIcon(activityData['type']),
                                color: primaryColor,
                                size: 22, // Plus grand pour iPad
                              ),
                            ),
                            SizedBox(width: 14), // Plus d'espace pour iPad
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        activityData['heure'],
                                        style: TextStyle(
                                          fontSize: 18, // Plus grand pour iPad
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        activityData['type'],
                                        style: TextStyle(
                                          fontSize: 16, // Plus grand pour iPad
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Durée: ${activityData['duration']}",
                                    style: TextStyle(
                                      fontSize: 16, // Plus grand pour iPad
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: List.generate(
                                activityData['participationLevel'] ?? 0,
                                (index) => Icon(
                                  Icons.star,
                                  color: primaryYellow,
                                  size: 18, // Plus grand pour iPad
                                ),
                              ),
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

  // AppBar personnalisé avec gradient comme dans les autres écrans
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
          // Plus de padding vertical pour iPad
          padding: EdgeInsets.fromLTRB(
              16,
              isTabletDevice ? 24 : 16, // Augmenté pour iPad
              16,
              isTabletDevice ? 28 : 20 // Augmenté pour iPad
              ),
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
                        fontSize:
                            isTabletDevice ? 28 : 24, // Plus grand pour iPad
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          isTabletDevice ? 16 : 12, // Plus grand pour iPad
                      vertical: isTabletDevice ? 8 : 6, // Plus grand pour iPad
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize:
                            isTabletDevice ? 16 : 14, // Plus grand pour iPad
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                  height: isTabletDevice ? 22 : 15), // Plus d'espace pour iPad
              // Icône et titre de la page
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTabletDevice ? 22 : 16, // Plus grand pour iPad
                  vertical: isTabletDevice ? 12 : 8, // Plus grand pour iPad
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white,
                      width: isTabletDevice ? 2.5 : 2 // Plus épais pour iPad
                      ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/Icone_Activites.png',
                      width: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      height: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.directions_run,
                        size: isTabletDevice ? 32 : 26, // Plus grand pour iPad
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                        width:
                            isTabletDevice ? 12 : 8), // Plus d'espace pour iPad
                    Text(
                      'Activités',
                      style: TextStyle(
                        fontSize:
                            isTabletDevice ? 24 : 20, // Plus grand pour iPad
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

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Activites.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.directions_run,
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

  // Navigation du bas
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
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
