import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poppins_app/screens/edit_schedule_screen.dart';
import 'package:poppins_app/screens/child_profile_details_screen.dart';
import 'package:poppins_app/screens/photo_management_screen.dart';
import 'package:poppins_app/screens/child_removal_screen.dart';
import 'package:poppins_app/screens/mam_member_add_screen.dart';
import 'package:poppins_app/screens/mam_member_removal_screen.dart';
import 'package:poppins_app/screens/fridge_temperature_screen.dart';
import 'package:poppins_app/screens/planning_screen.dart';
import 'package:poppins_app/screens/admin_screen.dart';
import 'package:poppins_app/screens/freezer_temperature_screen.dart';
import 'package:poppins_app/screens/child_removal_screen.dart';
import 'package:poppins_app/screens/child_history_detail_screen.dart';
import 'package:poppins_app/screens/history_date_selection_screen.dart';
import '../services/photo_cleanup_service.dart';
import '../screens/admin_cleanup_screen.dart';

// Dans la classe _DashboardScreenState
int _abacusClickCount = 0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  bool showMonthlyTableReports = false;
  bool isMAMStructure = false;
  int maxMemberCount = 0;
  int currentMemberCount = 0;
  bool needFridgeTemperatureCheck = false;
  bool needFreezerTemperatureCheck = false; // NOUVEAU
  bool? hasFreezer;
  int _abacusClickCount = 0;
  int _selectedSection = 0;
  bool? hasAssmatFridge; // null = pas encore défini, true = oui, false = non
  bool? hasAssmatFreezer; // null = pas encore défini, true = oui, false = non
  bool showAssmatFridgeChoice = false;
  bool showAssmatFreezerChoice = false;
  bool needAssmatFridgeTemperatureCheck = false;
  bool needAssmatFreezerTemperatureCheck = false;

  // Définition des couleurs de la palette
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Couleurs du thème actuel
  late Color primaryColor;
  late Color secondaryColor;

  @override
  void initState() {
    super.initState();
    // Définir les couleurs par défaut
    primaryColor = primaryBlue;
    secondaryColor = lightBlue;

    // Initialiser avec les valeurs par défaut
    isMAMStructure = false;
    maxMemberCount = 1;
    currentMemberCount = 1;
    needFridgeTemperatureCheck = false;
    needFreezerTemperatureCheck = false; // NOUVEAU
    hasAssmatFridge = null;
    hasAssmatFreezer = null;
    needAssmatFridgeTemperatureCheck = false;
    needAssmatFreezerTemperatureCheck = false;

    initializeDateFormatting('fr_FR', null).then((_) {
      _loadData();
      _checkMonthlyTableEnabled();
      _checkIfMAMStructure();
    });
  }

  void _showPhotoAdministration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCleanupScreen(),
      ),
    );
  }

  // Ajout de la méthode pour gérer le fonctionnement de la MAM
  void _showMAMFunctioning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Fonctionnement de la MAM", textAlign: TextAlign.center),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Frigo - TOUJOURS en premier
                ListTile(
                  leading: Icon(Icons.thermostat,
                      color: needFridgeTemperatureCheck
                          ? Colors.red
                          : primaryColor),
                  title: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Température frigo",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: needFridgeTemperatureCheck
                              ? Colors.red
                              : Colors.black87,
                        ),
                      ),
                      if (needFridgeTemperatureCheck)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "À relever aujourd'hui",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToFridgeTemperature();
                  },
                ),

                // Congélateur - Affiché seulement si pas encore configuré OU si la MAM en a un
                // hasFreezer == null = pas encore configuré (première fois)
                // hasFreezer == true = la MAM a un congélateur
                // hasFreezer == false = la MAM n'a PAS de congélateur (ne pas afficher)
                if (hasFreezer == null || hasFreezer == true)
                  ListTile(
                    leading: Icon(Icons.kitchen,
                        color: needFreezerTemperatureCheck
                            ? Colors.red
                            : primaryColor),
                    title: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Température congélateur",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: needFreezerTemperatureCheck
                                ? Colors.red
                                : Colors.black87,
                          ),
                        ),
                        if (needFreezerTemperatureCheck && hasFreezer == true)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "À relever aujourd'hui",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToFreezerTemperature();
                    },
                  ),

                ListTile(
                  leading: Icon(Icons.cleaning_services, color: primaryColor),
                  title: Text(
                    "Planning Ménage",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/cleaning-schedule');
                  },
                ),

                ListTile(
                  leading: Icon(Icons.calendar_month, color: primaryColor),
                  title: Text(
                    "Planning enfant",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlanningScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToFreezerTemperature() {
    context.go('/freezer-temperature');
  }

  // Méthode pour naviguer vers l'écran de température du frigo
  void _navigateToFridgeTemperature() {
    // Utiliser context.go pour naviguer avec GoRouter
    context.go('/fridge-temperature');
  }

  void _showMemberManagement() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Gestion des membres", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.person_add, color: primaryColor),
                title: Text(
                  "Ajouter un membre${currentMemberCount >= maxMemberCount ? ' (limite atteinte)' : ''}",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToAddMember();
                },
              ),
              ListTile(
                leading: Icon(Icons.person_remove, color: primaryColor),
                title: Text(
                  "Retirer un membre",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToRemoveMember();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Méthode _checkIfMAMStructure modifiée pour vérifier aussi la température du frigo
  Future<void> _checkIfMAMStructure() async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      print("Vérification MAM pour la structure: $structureId");

      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureDoc.exists) {
        final data = structureDoc.data() ?? {};
        print("Structure data: $data");

        // Vérifier le type de structure
        String structureType = data['structureType'] ?? 'AssistanteMaternelle';
        bool isMam = structureType == 'MAM';

        print("Type de structure trouvé: $structureType, isMAM = $isMam");

        if (isMam) {
          // Code existant pour MAM
          int maxMembers = 1;
          int currentMembers = 1;
          bool? structureHasFreezer;

          if (data.containsKey('maxMemberCount')) {
            maxMembers = data['maxMemberCount'] ?? 3;
          } else if (data.containsKey('subscription') &&
              data['subscription'] != null) {
            maxMembers = data['subscription']['maxMembers'] ?? 3;
          } else {
            maxMembers = 3;
          }

          final membersSnapshot = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('members')
              .get();

          currentMembers = membersSnapshot.docs.length;

          if (data.containsKey('hasFreezer')) {
            structureHasFreezer = data['hasFreezer'] as bool;
          } else {
            structureHasFreezer = null;
          }

          print(
              "MAM détectée: $currentMembers/$maxMembers membres, congélateur: $structureHasFreezer");

          _checkFridgeTemperatureStatus(structureId);
          if (structureHasFreezer == true) {
            _checkFreezerTemperatureStatus(structureId);
          }

          setState(() {
            isMAMStructure = isMam;
            maxMemberCount = maxMembers;
            currentMemberCount = currentMembers;
            hasFreezer = structureHasFreezer;
          });
        } else {
          // NOUVEAU CODE pour Assistante Maternelle
          print("AssistanteMaternelle détectée, vérification des équipements");

          bool? assmatFridge;
          bool? assmatFreezer;

          // Vérifier si l'assistante maternelle a un frigo
          if (data.containsKey('hasAssmatFridge')) {
            assmatFridge = data['hasAssmatFridge'] as bool;
          } else {
            assmatFridge = null; // Première fois, pas encore configuré
          }

          // Vérifier si l'assistante maternelle a un congélateur
          if (data.containsKey('hasAssmatFreezer')) {
            assmatFreezer = data['hasAssmatFreezer'] as bool;
          } else {
            assmatFreezer = null; // Première fois, pas encore configuré
          }

          print(
              "Assistante Maternelle - Frigo: $assmatFridge, Congélateur: $assmatFreezer");

          // Vérifier les températures si les équipements sont configurés
          if (assmatFridge == true) {
            _checkAssmatFridgeTemperatureStatus(structureId);
          }
          if (assmatFreezer == true) {
            _checkAssmatFreezerTemperatureStatus(structureId);
          }

          setState(() {
            isMAMStructure = isMam;
            hasAssmatFridge = assmatFridge;
            hasAssmatFreezer = assmatFreezer;
            showAssmatFridgeChoice = assmatFridge == null;
            showAssmatFreezerChoice = assmatFreezer == null;
          });
        }
      }
    } catch (e) {
      print("Erreur lors de la vérification si MAM: $e");
      setState(() {
        isMAMStructure = false;
      });
    }
  }

  Future<void> _checkAssmatFridgeTemperatureStatus(String structureId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('fridgeTemperatures')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      setState(() {
        needAssmatFridgeTemperatureCheck = snapshot.docs.isEmpty;
      });

      print(
          "Vérification température frigo Assistante Maternelle: ${needAssmatFridgeTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du frigo AssistanteMaternelle: $e");
    }
  }

  Future<void> _checkAssmatFreezerTemperatureStatus(String structureId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('freezerTemperatures')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      setState(() {
        needAssmatFreezerTemperatureCheck = snapshot.docs.isEmpty;
      });

      print(
          "Vérification température congélateur Assistante Maternelle: ${needAssmatFreezerTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du congélateur AssistanteMaternelle: $e");
    }
  }

  // NOUVELLES MÉTHODES pour sauvegarder les préférences Assistante Maternelle
  Future<void> _saveAssmatFridgePreference(bool hasFridgeChoice) async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({'hasAssmatFridge': hasFridgeChoice});

      setState(() {
        hasAssmatFridge = hasFridgeChoice;
        showAssmatFridgeChoice = false;
      });

      if (hasFridgeChoice) {
        await _checkAssmatFridgeTemperatureStatus(structureId);
      }
    } catch (e) {
      print(
          "Erreur lors de la sauvegarde de la préférence frigo AssistanteMaternelle: $e");
    }
  }

  Future<void> _saveAssmatFreezerPreference(bool hasFreezerChoice) async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({'hasAssmatFreezer': hasFreezerChoice});

      setState(() {
        hasAssmatFreezer = hasFreezerChoice;
        showAssmatFreezerChoice = false;
      });

      if (hasFreezerChoice) {
        await _checkAssmatFreezerTemperatureStatus(structureId);
      }
    } catch (e) {
      print(
          "Erreur lors de la sauvegarde de la préférence congélateur AssistanteMaternelle: $e");
    }
  }

  // NOUVEAU WIDGET pour le choix des équipements Assistante Maternelle
  Widget _buildAssmatEquipmentChoiceDialog() {
    if (!showAssmatFridgeChoice && !showAssmatFreezerChoice) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.kitchen,
                  size: 64,
                  color: primaryColor,
                ),
                SizedBox(height: 20),
                Text(
                  "Configuration des équipements",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),

                // Choix du frigo si nécessaire
                if (showAssmatFridgeChoice) ...[
                  Text(
                    "Avez-vous un réfrigérateur dans votre structure ?",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _saveAssmatFridgePreference(false),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                "NON",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _saveAssmatFridgePreference(true),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withOpacity(0.8)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                "OUI",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Choix du congélateur si nécessaire
                if (showAssmatFreezerChoice) ...[
                  if (showAssmatFridgeChoice) SizedBox(height: 32),
                  Text(
                    "Avez-vous un congélateur dans votre structure ?",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _saveAssmatFreezerPreference(false),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                "NON",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _saveAssmatFreezerPreference(true),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withOpacity(0.8)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                "OUI",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NOUVELLE MÉTHODE pour le fonctionnement quotidien Assistante Maternelle
  void _showAssmatDailyFunctioning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Fonctionnement quotidien", textAlign: TextAlign.center),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Frigo - Affiché seulement si configuré ET la structure en a un
                if (hasAssmatFridge == true)
                  ListTile(
                    leading: Icon(Icons.thermostat,
                        color: needAssmatFridgeTemperatureCheck
                            ? Colors.red
                            : primaryColor),
                    title: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Température frigo",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: needAssmatFridgeTemperatureCheck
                                ? Colors.red
                                : Colors.black87,
                          ),
                        ),
                        if (needAssmatFridgeTemperatureCheck)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "À relever aujourd'hui",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToFridgeTemperature();
                    },
                  ),

                // Congélateur - Affiché seulement si configuré ET la structure en a un
                if (hasAssmatFreezer == true)
                  ListTile(
                    leading: Icon(Icons.kitchen,
                        color: needAssmatFreezerTemperatureCheck
                            ? Colors.red
                            : primaryColor),
                    title: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Température congélateur",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: needAssmatFreezerTemperatureCheck
                                ? Colors.red
                                : Colors.black87,
                          ),
                        ),
                        if (needAssmatFreezerTemperatureCheck)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "À relever aujourd'hui",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToFreezerTemperature();
                    },
                  ),

                // Planning enfant - TOUJOURS affiché pour Assistante Maternelle
                ListTile(
                  leading: Icon(Icons.calendar_month, color: primaryColor),
                  title: Text(
                    "Planning enfant",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlanningScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkFreezerTemperatureStatus(String structureId) async {
    try {
      // Obtenir la date d'aujourd'hui à minuit pour la comparaison
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Rechercher s'il y a un relevé de température du congélateur pour aujourd'hui
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('freezerTemperatures')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      setState(() {
        // S'il n'y a pas de relevé aujourd'hui, indiquer qu'un relevé est nécessaire
        needFreezerTemperatureCheck = snapshot.docs.isEmpty;
      });

      print(
          "Vérification température congélateur: ${needFreezerTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du congélateur: $e");
    }
  }

  // Nouvelle méthode pour vérifier si la température du frigo a été relevée aujourd'hui
  Future<void> _checkFridgeTemperatureStatus(String structureId) async {
    try {
      // Obtenir la date d'aujourd'hui à minuit pour la comparaison
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Rechercher s'il y a un relevé de température pour aujourd'hui
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('fridgeTemperatures')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      setState(() {
        // S'il n'y a pas de relevé aujourd'hui, indiquer qu'un relevé est nécessaire
        needFridgeTemperatureCheck = snapshot.docs.isEmpty;
      });

      print(
          "Vérification température frigo: ${needFridgeTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du frigo: $e");
    }
  }

  // Méthode pour naviguer vers l'écran d'ajout de membre
  void _navigateToAddMember() {
    if (currentMemberCount >= maxMemberCount) {
      // Montrer une alerte pour proposer une mise à niveau
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text("Limite d'abonnement atteinte",
                textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Vous avez atteint le nombre maximum de membres ($maxMemberCount) autorisé par votre abonnement actuel.",
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  "Souhaitez-vous passer à un abonnement supérieur?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "NON",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Naviguer vers la page de mise à niveau d'abonnement
                  context.go('/subscription-upgrade');
                },
                child: Text(
                  "OUI",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      // Naviguer vers l'écran d'ajout de membre
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MAMMemberAddScreen(),
        ),
      ).then((_) {
        // Rafraîchir les données après ajout
        _checkIfMAMStructure();
      });
    }
  }

  // Méthode pour naviguer vers l'écran de suppression de membre
  void _navigateToRemoveMember() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MAMMemberRemovalScreen(),
      ),
    ).then((_) {
      // Rafraîchir les données après suppression
      _checkIfMAMStructure();
    });
  }

  // Modifiez la méthode _showChildProfilesSelection pour la rendre async
  void _showChildProfilesSelection() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionner un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    // Obtenir l'ID de structure avant de naviguer
                    String structId = await _getStructureId();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChildProfileDetailsScreen(
                          childId: child['id'],
                          structureId: structId,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

// Ajouter cette méthode pour naviguer vers l'historique
  void _showHistorySelection() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionner un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    // Obtenir l'ID de structure avant de naviguer
                    String structId = await _getStructureId();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HistoryDateSelectionScreen(
                          childId: child['id'],
                          childName: child['firstName'],
                          structureId: structId,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPhotoManagement() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionner un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // Naviguer directement vers PhotoManagementScreen avec l'ID de l'enfant
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoManagementScreen(
                          childId: child['id'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showChildRemoval() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionner un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    // CORRECTION: Récupérer l'ID de structure avant de naviguer
                    String structId = await _getStructureId();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChildRemovalScreen(
                          childId: child['id'],
                          structureId:
                              structId, // ← AJOUT DU PARAMÈTRE MANQUANT
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkMonthlyTableEnabled() async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      // Récupérer l'email de l'utilisateur actuel
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
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
      final childrenSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Aucun enfant trouvé
      if (childrenSnapshot.docs.isEmpty) {
        setState(() {
          showMonthlyTableReports = false;
        });
        return;
      }

      bool hasMonthlyTableEnabled = false;

      // Pour chaque enfant dans la structure
      for (var doc in childrenSnapshot.docs) {
        final data = doc.data();

        // Vérifier si l'enfant utilise le tableau mensuel
        bool usesMonthlyTable = data.containsKey('financialInfo') &&
            data['financialInfo'] != null &&
            data['financialInfo']['useMonthlyTable'] == true;

        // Si c'est une MAM, vérifier en plus si l'enfant est assigné au membre connecté
        if (structureType == "MAM") {
          String assignedEmail =
              data['assignedMemberEmail']?.toString().toLowerCase() ?? '';

          // L'enfant doit à la fois utiliser le tableau mensuel ET être assigné au membre connecté
          if (usesMonthlyTable && assignedEmail == currentUserEmail) {
            hasMonthlyTableEnabled = true;
            print(
                "✅ Enfant ${data['firstName']} assigné au membre actuel utilise le tableau mensuel");
            break; // Un seul enfant suffit pour activer la section Rapports
          }
        } else {
          // Pour une assistante maternelle, il suffit qu'un enfant utilise le tableau mensuel
          if (usesMonthlyTable) {
            hasMonthlyTableEnabled = true;
            print("✅ Enfant ${data['firstName']} utilise le tableau mensuel");
            break; // Un seul enfant suffit pour activer la section Rapports
          }
        }
      }

      setState(() {
        showMonthlyTableReports = hasMonthlyTableEnabled;
      });

      print("📊 Affichage de la section Rapports: $hasMonthlyTableEnabled");
    } catch (e) {
      print("❌ Erreur lors de la vérification du tableau mensuel: $e");
      // En cas d'erreur, par précaution, ne pas afficher la section
      setState(() {
        showMonthlyTableReports = false;
      });
    }
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

    // Par défaut, utiliser l'ID de l'utilisateur
    return user.uid;
  }

  Future<List<Map<String, dynamic>>> _loadChildren() async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return [];

      // Récupérer l'email de l'utilisateur actuel
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
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
          'firstName': data['firstName'] ?? 'Sans nom',
          'photoUrl': data['photoUrl'],
          'schedule': data['schedule'],
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
            "👨‍👧‍👦 Dashboard: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Dashboard: Assistante Maternelle - affichage de tous les enfants");
      }

      return filteredChildren;
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      return [];
    }
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
        });
        context.go('/login');
        return;
      }

      // D'abord, vérifier si l'utilisateur est un membre MAM
      final userEmail = user.email?.toLowerCase() ?? '';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      // Si c'est un membre MAM, obtenir l'ID de la structure associée
      String structureId =
          user.uid; // Par défaut, utiliser l'ID de l'utilisateur

      if (userDoc.exists &&
          userDoc.data() != null &&
          userDoc.data()!.containsKey('structureId')) {
        structureId = userDoc.data()!['structureId'];
      }

      // Utiliser le bon ID de structure
      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (!structureSnapshot.exists) {
        print("Le document de structure n'existe pas pour l'ID: $structureId");
        setState(() {
          structureName = 'Structure introuvable';
          isLoading = false;
        });

        // Rediriger vers la création de structure
        context.go('/create-structure');
        return;
      }

      final childrenSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      List<Map<String, dynamic>> tempEnfants = [];
      for (var doc in childrenSnapshot.docs) {
        final data = doc.data();
        tempEnfants.add({
          'id': doc.id,
          'firstName': data['firstName'],
          'photoUrl': data['photoUrl'],
          'schedule': data['schedule'],
        });
      }

      setState(() {
        structureName =
            structureSnapshot.data()?['structureName'] ?? 'Ma Structure';
        enfants = tempEnfants;
        isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement: $e");
      setState(() => isLoading = false);
    }
  }

  void _showScheduleModification() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionner un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _editChildSchedule(child);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editChildSchedule(Map<String, dynamic> child) {
    try {
      // Sécuriser la conversion du schedule
      Map<String, dynamic> safeSchedule = {};

      // Vérifier si schedule existe et est du bon type
      if (child['schedule'] != null) {
        try {
          // Si c'est déjà un Map
          if (child['schedule'] is Map) {
            safeSchedule = Map<String, dynamic>.from(child['schedule'] as Map);
          }
        } catch (e) {
          print("Erreur lors de la conversion du schedule: $e");
          // En cas d'erreur, utiliser un Map vide
          safeSchedule = {};
        }
      }

      // Utiliser NavigatorState.push pour avoir plus de contrôle
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditScheduleScreen(
            childId: child['id'],
            childName: child['firstName'],
            currentSchedule: safeSchedule,
          ),
        ),
      ).then((_) {
        // Rafraîchir les données après modification des horaires
        _loadData();
      });
    } catch (e) {
      print("Erreur lors de la navigation vers EditScheduleScreen: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'édition des horaires: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Méthode de construction des éléments d'action avec support pour les badges
  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? badge, // Ajout du paramètre badge optionnel
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: primaryColor, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (badge != null) badge, // Afficher le badge s'il est fourni
                SizedBox(
                    width: badge != null
                        ? 8
                        : 0), // Ajouter un espace si un badge est présent
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      context.go('/dashboard');
    } else if (index == 1) {
      context.go('/home');
    } else if (index == 2) {
      context.go('/child-info');
    }
  }

  // Nouvelle méthode pour le contenu tablette
  // Modifier la méthode _buildTabletContent pour inclure la section Historique
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
            // Panneau latéral gauche (Sections principales)
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre avec icône
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/Icone_Dashboard.png',
                            width: maxWidth * 0.07,
                            height: maxWidth * 0.07,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.dashboard,
                              color: primaryColor,
                              size: maxWidth * 0.07,
                            ),
                          ),
                          SizedBox(width: maxWidth * 0.015),
                          Expanded(
                            child: Text(
                              "Paramètres",
                              style: TextStyle(
                                fontSize: maxWidth * 0.022,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.025),

                      // Liste des sections principales
                      Expanded(
                        child: ListView(
                          children: [
                            _buildSectionItem(
                              title: "Gestion de la structure",
                              icon: Icons.business,
                              imagePath: 'assets/images/Icone_Structure.png',
                              index: 0,
                              maxWidth: maxWidth,
                              badge:
                                  (isMAMStructure && needFridgeTemperatureCheck)
                                      ? "1"
                                      : null,
                            ),
                            SizedBox(height: maxHeight * 0.02),
                            _buildSectionItem(
                              title: "Gestion des enfants",
                              icon: Icons.child_care,
                              imagePath:
                                  'assets/images/Icone_Enfant_Present.png',
                              index: 1,
                              maxWidth: maxWidth,
                            ),
                            if (showMonthlyTableReports) ...[
                              SizedBox(height: maxHeight * 0.02),
                              _buildSectionItem(
                                title: "Rapports",
                                icon: Icons.assessment,
                                imagePath:
                                    'assets/images/Icone_Recaptitulatif.png',
                                index: 2,
                                maxWidth: maxWidth,
                              ),
                            ],
                            SizedBox(height: maxHeight * 0.02),
                            _buildSectionItem(
                              title: "Historique",
                              icon: Icons.history,
                              imagePath:
                                  'assets/images/Icone_historique.png', // Vous pouvez créer une icône spécifique
                              index: 3,
                              maxWidth: maxWidth,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Panneau de droite (Actions détaillées)
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
                  padding: EdgeInsets.all(maxWidth * 0.02),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre de la section détaillée
                      Text(
                        _getSectionTitle(_selectedSection),
                        style: TextStyle(
                          fontSize: maxWidth * 0.022,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.01),

                      // Actions détaillées selon la section sélectionnée
                      Expanded(
                        child: _buildSectionDetails(
                            _selectedSection, maxWidth, maxHeight),
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

  // Nouvelle méthode pour construire un élément de section
  Widget _buildSectionItem({
    required String title,
    required IconData icon,
    required String imagePath,
    required int index,
    required double maxWidth,
    String? badge,
  }) {
    final bool isSelected = _selectedSection == index;

    // Calculer le nombre de notifications pour la section Structure
    String? sectionBadge = badge;
    if (index == 0 && isMAMStructure) {
      int notificationCount = 0;
      if (needFridgeTemperatureCheck) notificationCount++;
      // Afficher badge congélateur seulement si configuré ET nécessaire
      if (needFreezerTemperatureCheck && hasFreezer == true)
        notificationCount++;

      if (notificationCount > 0) {
        sectionBadge = notificationCount.toString();
      }
    }

    return Material(
      color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSection = index;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(maxWidth * 0.02),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                isSelected ? Border.all(color: primaryColor, width: 2) : null,
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Image.asset(
                    imagePath,
                    width: maxWidth * 0.06,
                    height: maxWidth * 0.06,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      icon,
                      color: isSelected ? primaryColor : Colors.grey.shade600,
                      size: maxWidth * 0.06,
                    ),
                  ),
                  if (sectionBadge != null)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: EdgeInsets.all(maxWidth * 0.008),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          sectionBadge,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: maxWidth * 0.012,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: maxWidth * 0.018,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? primaryColor : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.chevron_right,
                  color: primaryColor,
                  size: maxWidth * 0.025,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Modifier la méthode _getSectionTitle pour inclure Historique
  String _getSectionTitle(int sectionIndex) {
    switch (sectionIndex) {
      case 0:
        return "Structure";
      case 1:
        return "Enfants";
      case 2:
        return "Rapports";
      case 3:
        return "Historique";
      default:
        return "Actions";
    }
  }

  // Modifier la méthode _buildSectionDetails pour inclure Historique
  Widget _buildSectionDetails(
      int sectionIndex, double maxWidth, double maxHeight) {
    switch (sectionIndex) {
      case 0:
        return _buildStructureActions(maxWidth, maxHeight);
      case 1:
        return _buildChildrenActions(maxWidth, maxHeight);
      case 2:
        return _buildReportsActions(maxWidth, maxHeight);
      case 3:
        return _buildHistoryActions(maxWidth, maxHeight);
      default:
        return Container();
    }
  }

// Ajouter cette nouvelle méthode pour les actions d'historique
  Widget _buildHistoryActions(double maxWidth, double maxHeight) {
    return ListView(
      children: [
        _buildTabletActionItem(
          icon: Icons.history,
          title: "Consulter l'historique",
          description: "Voir l'historique complet par enfant et par date",
          onTap: _showHistorySelection,
          maxWidth: maxWidth,
        ),
      ],
    );
  }

  // Méthode pour les actions de structure
  Widget _buildStructureActions(double maxWidth, double maxHeight) {
    // Calculer le nombre de notifications
    int notificationCount = 0;

    if (isMAMStructure) {
      // Code existant pour MAM
      if (needFridgeTemperatureCheck) notificationCount++;
      if (needFreezerTemperatureCheck && hasFreezer == true)
        notificationCount++;
    } else {
      // NOUVEAU pour Assistante Maternelle
      if (needAssmatFridgeTemperatureCheck && hasAssmatFridge == true)
        notificationCount++;
      if (needAssmatFreezerTemperatureCheck && hasAssmatFreezer == true)
        notificationCount++;
    }

    String? functioningBadge;
    if (notificationCount > 0) {
      functioningBadge = notificationCount.toString();
    }

    return ListView(
      children: [
        _buildTabletActionItem(
          icon: Icons.edit_note,
          title: "Modifier les coordonnées",
          description: "Changer les informations de la structure",
          onTap: () => context.go('/structure-management'),
          maxWidth: maxWidth,
        ),
        if (isMAMStructure) ...[
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.people,
            title: "Modifier les membres",
            description: "Gérer les membres de la MAM",
            onTap: _showMemberManagement,
            maxWidth: maxWidth,
          ),
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.settings,
            title: "Fonctionnement de la MAM",
            description: "Température frigo, congélateur, planning ménage...",
            onTap: _showMAMFunctioning,
            maxWidth: maxWidth,
            badge: functioningBadge,
          ),
        ] else ...[
          // NOUVEAU pour Assistante Maternelle
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.settings,
            title: "Fonctionnement quotidien",
            description: "Température frigo, congélateur, planning enfant...",
            onTap: _showAssmatDailyFunctioning,
            maxWidth: maxWidth,
            badge: functioningBadge,
          ),
        ],
      ],
    );
  }

  // Méthode pour les actions enfants
  Widget _buildChildrenActions(double maxWidth, double maxHeight) {
    return ListView(
      children: [
        _buildTabletActionItem(
          icon: Icons.access_time,
          title: "Modifier les horaires",
          description: "Ajuster les horaires de garde",
          onTap: _showScheduleModification,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.photo_library,
          title: "Gestion des photos",
          description: "Ajouter ou supprimer des photos",
          onTap: _showPhotoManagement,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.edit_note,
          title: "Modifier les profils complets",
          description: "Éditer toutes les informations enfant",
          onTap: _showChildProfilesSelection,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.person_remove,
          title: "Retrait d'enfant",
          description: "Gérer le départ d'un enfant",
          onTap: _showChildRemoval,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.admin_panel_settings,
          title: "Administration des photos",
          description: "Nettoyage et statistiques des photos",
          onTap: _showPhotoAdministration,
          maxWidth: maxWidth,
        ),
      ],
    );
  }

  // Méthode pour les actions rapports
  Widget _buildReportsActions(double maxWidth, double maxHeight) {
    return ListView(
      children: [
        _buildTabletActionItem(
          icon: Icons.calendar_month,
          title: "Tableau mensuel",
          description: "Consulter les rapports mensuels",
          onTap: () => context.go('/monthly-report-selection'),
          maxWidth: maxWidth,
        ),
      ],
    );
  }

  // Méthode pour construire un élément d'action pour tablette
  Widget _buildTabletActionItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required double maxWidth,
    String? badge,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(maxWidth * 0.025),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(maxWidth * 0.015),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: primaryColor,
                      size: maxWidth * 0.025,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(maxWidth * 0.008),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: maxWidth * 0.012,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: maxWidth * 0.018,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: maxWidth * 0.005),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: maxWidth * 0.014,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: maxWidth * 0.025,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Gestion de la Structure
            Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _abacusClickCount++;
                            print(
                                "🧮 Image structure cliquée: $_abacusClickCount fois");
                            if (_abacusClickCount >= 5) {
                              _abacusClickCount = 0;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Accès administrateur déverrouillé"),
                                  duration: Duration(seconds: 1),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AdminScreen()),
                              );
                            }
                          });
                        },
                        child: Image.asset(
                          'assets/images/Icone_Structure.png',
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.business,
                            color: primaryColor,
                            size: 60,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Gestion de la structure",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildActionItem(
                    icon: Icons.edit_note,
                    title: "Modifier les coordonnées",
                    onTap: () => context.go('/structure-management'),
                  ),
                  if (isMAMStructure) ...[
                    _buildActionItem(
                      icon: Icons.people,
                      title: "Modifier les membres",
                      onTap: _showMemberManagement,
                    ),
                    _buildActionItem(
                      icon: Icons.settings,
                      title: "Fonctionnement de la MAM",
                      onTap: _showMAMFunctioning,
                      badge: (needFridgeTemperatureCheck ||
                              (needFreezerTemperatureCheck &&
                                  hasFreezer == true))
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                ((needFridgeTemperatureCheck ? 1 : 0) +
                                        (needFreezerTemperatureCheck &&
                                                hasFreezer == true
                                            ? 1
                                            : 0))
                                    .toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ] else ...[
                    // NOUVEAU pour Assistante Maternelle
                    _buildActionItem(
                      icon: Icons.settings,
                      title: "Fonctionnement quotidien",
                      onTap: _showAssmatDailyFunctioning,
                      badge: ((needAssmatFridgeTemperatureCheck &&
                                  hasAssmatFridge == true) ||
                              (needAssmatFreezerTemperatureCheck &&
                                  hasAssmatFreezer == true))
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                ((needAssmatFridgeTemperatureCheck &&
                                                hasAssmatFridge == true
                                            ? 1
                                            : 0) +
                                        (needAssmatFreezerTemperatureCheck &&
                                                hasAssmatFreezer == true
                                            ? 1
                                            : 0))
                                    .toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),

            // Section Gestion des Enfants
            Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _abacusClickCount++;
                            print(
                                "🧮 Image enfant cliquée: $_abacusClickCount fois");
                            if (_abacusClickCount >= 5) {
                              _abacusClickCount = 0;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Accès administrateur déverrouillé"),
                                  duration: Duration(seconds: 1),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AdminScreen()),
                              );
                            }
                          });
                        },
                        child: Image.asset(
                          'assets/images/Icone_Enfant_Present.png',
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.child_care,
                            color: primaryColor,
                            size: 60,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Gestion des enfants",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildActionItem(
                    icon: Icons.access_time,
                    title: "Modifier les horaires",
                    onTap: _showScheduleModification,
                  ),
                  _buildActionItem(
                    icon: Icons.photo_library,
                    title: "Gestion des photos",
                    onTap: _showPhotoManagement,
                  ),
                  _buildActionItem(
                    icon: Icons.edit_note,
                    title: "Modifier les profils complets",
                    onTap: _showChildProfilesSelection,
                  ),
                  _buildActionItem(
                    icon: Icons.person_remove,
                    title: "Retrait d'enfant",
                    onTap: _showChildRemoval,
                  ),
                  _buildActionItem(
                    icon: Icons.admin_panel_settings,
                    title: "Administration des photos",
                    onTap: _showPhotoAdministration,
                  ),
                ],
              ),
            ),

            // Section Rapports - Affichée conditionnellement
            if (showMonthlyTableReports)
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/Icone_Recaptitulatif.png',
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.assessment,
                            color: primaryColor,
                            size: 60,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Rapports",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildActionItem(
                      icon: Icons.calendar_month,
                      title: "Tableau mensuel",
                      onTap: () => context.go('/monthly-report-selection'),
                    ),
                  ],
                ),
              ),

            // Section Historique
            Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/Icone_historique.png',
                        width: 60,
                        height: 60,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.history,
                          color: primaryColor,
                          size: 60,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Historique",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildActionItem(
                    icon: Icons.history,
                    title: "Consulter l'historique",
                    onTap: _showHistorySelection,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    // NOUVEAU: Vérifier s'il faut afficher les dialogues de choix pour Assistante Maternelle
    if (!isMAMStructure &&
        (showAssmatFridgeChoice || showAssmatFreezerChoice)) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // En-tête identique
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primaryColor, primaryColor.withOpacity(0.85)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft:
                      Radius.circular(MediaQuery.of(context).size.width * 0.06),
                  bottomRight:
                      Radius.circular(MediaQuery.of(context).size.width * 0.06),
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
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Configuration",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        structureName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Contenu avec dialogue de choix
            Expanded(
              child: _buildAssmatEquipmentChoiceDialog(),
            ),
          ],
        ),
      );
    }

    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête avec fond de couleur - identique pour phone et tablet
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre et date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Tableau de bord",
                          style: TextStyle(
                            fontSize:
                                screenSize.width * (isTablet ? 0.032 : 0.06),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                screenSize.width * (isTablet ? 0.018 : 0.03),
                            vertical:
                                screenSize.height * (isTablet ? 0.01 : 0.006),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(
                              screenSize.width * (isTablet ? 0.025 : 0.05),
                            ),
                          ),
                          child: Text(
                            DateFormat('EEEE d MMMM', 'fr_FR')
                                .format(DateTime.now()),
                            style: TextStyle(
                              fontSize:
                                  screenSize.width * (isTablet ? 0.018 : 0.035),
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Nom de la structure
                    Text(
                      structureName,
                      style: TextStyle(
                        fontSize: screenSize.width * (isTablet ? 0.024 : 0.045),
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Afficher le type de structure si c'est une MAM
                    if (isMAMStructure)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "MAM",
                                style: TextStyle(
                                  fontSize: screenSize.width *
                                      (isTablet ? 0.016 : 0.03),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "$currentMemberCount/$maxMemberCount membres",
                              style: TextStyle(
                                fontSize: screenSize.width *
                                    (isTablet ? 0.016 : 0.03),
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal avec adaptation pour iPad
          Expanded(
            child: isTablet ? _buildTabletContent() : _buildPhoneContent(),
          ),
        ],
      ),

      // BottomNavigationBar identique
      bottomNavigationBar: BottomNavigationBar(
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: 0, // Dashboard est sélectionné
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_Dashboard.png',
              width: screenSize.width * (isTablet ? 0.07 : 0.14),
              height: screenSize.width * (isTablet ? 0.07 : 0.14),
            ),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/maison_icon.png',
              width: screenSize.width * (isTablet ? 0.07 : 0.14),
              height: screenSize.width * (isTablet ? 0.07 : 0.14),
            ),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_Ajout_Enfant.png',
              width: screenSize.width * (isTablet ? 0.07 : 0.14),
              height: screenSize.width * (isTablet ? 0.07 : 0.14),
            ),
            label: "Ajouter",
          ),
        ],
      ),
    );
  }
}
