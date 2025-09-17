import 'package:flutter/cupertino.dart';
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
import 'package:poppins_app/screens/delegations_screen.dart';
import 'package:poppins_app/screens/admin_screen.dart';
import 'package:poppins_app/screens/freezer_temperature_screen.dart';
import 'package:poppins_app/screens/child_removal_screen.dart';
import 'package:poppins_app/screens/child_history_detail_screen.dart';
import 'package:poppins_app/screens/history_date_selection_screen.dart';
import '../services/photo_cleanup_service.dart';
import '../screens/admin_cleanup_screen.dart';
import 'package:poppins_app/screens/parent_coordonnees_screen.dart';
import '../services/subscription_service.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Couleurs dédiées aux tuiles de la grille (style 2025)
  final Color _tileBlue = const Color(0xFF3D9DF2);
  final Color _tileRed = const Color(0xFFD94350);
  final Color _tileYellow = const Color(0xFFF2B705);
  final Color _tileCyan = const Color(0xFF05C7F2);

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

    // Initialiser avec les valeurs par défaut CORRIGÉES
    isMAMStructure = false;
    maxMemberCount = 1; // Pour AssistanteMaternelle seule
    currentMemberCount = 1;
    needFridgeTemperatureCheck = false;
    needFreezerTemperatureCheck = false;
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
    // Sécurité supplémentaire
    if (!kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fonction disponible uniquement en mode développeur"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCleanupScreen(),
      ),
    );
  }

  // Compteur des délégations à traiter aujourd'hui pour le membre courant
  Future<int> _fetchPendingDelegationsCountToday() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;
      final String currentUserEmail = user.email?.toLowerCase() ?? '';
      // Trouver la structure
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();
      final String structureId = (userDoc.exists &&
              (userDoc.data()?['structureId'] ?? '').toString().isNotEmpty)
          ? userDoc.data()!['structureId']
          : user.uid;

      // Trouver le memberId correspondant à l'email
      final memSnap = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .where('email', isEqualTo: currentUserEmail)
          .limit(1)
          .get();
      if (memSnap.docs.isEmpty) return 0;
      final memberId = memSnap.docs.first.id;

      // Filtrer les délégations proposées pour aujourd'hui
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final snap = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('delegations')
          .where('status', isEqualTo: 'proposed')
          .where('amDelegateId', isEqualTo: memberId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();
      return snap.size;
    } catch (e) {
      print('Erreur compteur délégations: $e');
      return 0;
    }
  }

  Widget _buildDelegationsBadgeFuture() {
    return FutureBuilder<int>(
      future: _fetchPendingDelegationsCountToday(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count <= 0) return SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );
      },
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
          title: Text("Température à relever", textAlign: TextAlign.center),
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
                        "Température réfrigérateur",
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

  // ✅ VERSION AMÉLIORÉE de _showMemberManagement (fusion)
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
              // AJOUTER UN MEMBRE avec logique intelligente
              ListTile(
                leading: Icon(
                  // Icône adaptée selon la situation
                  currentMemberCount >= maxMemberCount
                      ? (maxMemberCount >= 4 ? Icons.block : Icons.upgrade)
                      : Icons.person_add,
                  color: currentMemberCount >= maxMemberCount &&
                          maxMemberCount >= 4
                      ? Colors.grey
                      : primaryColor, // BLEU au lieu de rouge
                ),
                title: Text(
                  _getAddMemberTitle(),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: currentMemberCount >= maxMemberCount &&
                            maxMemberCount >= 4
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                onTap: currentMemberCount >= maxMemberCount &&
                        maxMemberCount >= 4
                    ? null // Désactiver seulement si on est déjà à 4 membres (limite absolue)
                    : () {
                        Navigator.pop(context);
                        _handleAddMember();
                      },
              ),

              // RETIRER UN MEMBRE (toujours disponible)
              ListTile(
                leading: Icon(Icons.person_remove, color: primaryColor), // BLEU
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

// ✅ NOUVELLES MÉTHODES AMÉLIORÉES (fusion)
  String _getAddMemberTitle() {
    if (isMAMStructure) {
      // Pour une MAM, minimum 2 membres
      if (currentMemberCount >= maxMemberCount) {
        if (maxMemberCount >= 4) {
          return "Limite atteinte (4 membres max)";
        } else {
          return "Membres $currentMemberCount/$maxMemberCount - Passer à l'abonnement supérieur";
        }
      } else {
        // Si on a moins de membres que la limite, on peut ajouter
        return "Ajouter un membre (${currentMemberCount}/${maxMemberCount})";
      }
    } else {
      // Pour AssistanteMaternelle seule
      return "Cette fonction est réservée aux MAM";
    }
  }

  void _handleAddMember() {
    // ✅ TOUJOURS aller vers MAMMemberAddScreen
    // Cet écran gère intelligemment tous les cas : ajout normal, limite atteinte, upgrade
    _navigateToAddMember();
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
          // ✅ CORRECTION : MAM minimum 2 membres
          int maxMembers = 2; // MINIMUM 2 pour MAM
          int currentMembers = 1;
          bool? structureHasFreezer;

          if (data.containsKey('maxMemberCount')) {
            maxMembers = data['maxMemberCount'] ?? 2;
            // ✅ S'assurer que c'est au minimum 2 pour une MAM
            if (maxMembers < 2) {
              maxMembers = 2;
              // Mettre à jour en base pour corriger la valeur
              await FirebaseFirestore.instance
                  .collection('structures')
                  .doc(structureId)
                  .update({'maxMemberCount': 2});
            }
          } else if (data.containsKey('subscription') &&
              data['subscription'] != null) {
            maxMembers = data['subscription']['maxMembers'] ?? 2;
            // ✅ S'assurer que c'est au minimum 2 pour une MAM
            if (maxMembers < 2) maxMembers = 2;
          } else {
            maxMembers = 2; // ✅ MINIMUM 2 pour MAM
            // Mettre à jour en base
            await FirebaseFirestore.instance
                .collection('structures')
                .doc(structureId)
                .update({'maxMemberCount': 2});
          }

          final membersSnapshot = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('members')
              .get();

          currentMembers = membersSnapshot.docs.length;
          // ✅ S'assurer qu'on a au minimum 1 membre même si la collection est vide
          if (currentMembers < 1) currentMembers = 1;

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
          // Code existant pour Assistante Maternelle (pas de changement)
          print("AssistanteMaternelle détectée, vérification des équipements");
          // ... reste du code inchangé pour AssistanteMaternelle
          setState(() {
            isMAMStructure = false;
            maxMemberCount = 1; // Pour AssistanteMaternelle seule
            currentMemberCount = 1;
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

  void _showParentCoordonneeSelection() async {
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
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
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
                        builder: (context) => ParentCoordonneesScreen(
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
          "Vérification température réfrigérateur Assistante Maternelle: ${needAssmatFridgeTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du réfrigérateur AssistanteMaternelle: $e");
    }
  }

// Méthode pour ouvrir les liens légaux
  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible d'ouvrir le lien"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de l'ouverture du lien: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'ouverture du lien"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

// Widget moderne pour les liens légaux (Design 2025)
  Widget _buildLegalButtons({required bool isTablet}) {
    final double fontSize = isTablet ? 14 : 16;
    final double buttonHeight = isTablet ? 45 : 52;
    final double spacing = isTablet ? 12 : 16;

    return Column(
      children: [
        // Bouton Politique de Confidentialité
        Container(
          width: double.infinity,
          height: buttonHeight,
          margin: EdgeInsets.only(bottom: spacing),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _launchURL(
                  'https://www.poppin-s.fr/politique-de-confidentialite/'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      brightCyan,
                      brightCyan.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: brightCyan.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.white,
                      size: isTablet ? 18 : 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Politique de Confidentialité",
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bouton Conditions d'Utilisation
        Container(
          width: double.infinity,
          height: buttonHeight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  _launchURL('https://www.poppin-s.fr/condition-dutilisation/'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryBlue,
                      primaryBlue.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: isTablet ? 18 : 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Conditions d'Utilisation",
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
          "Erreur lors de la sauvegarde de la préférence réfrigérateur AssistanteMaternelle: $e");
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
                // Section équipements avec indicateur visuel moderne
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        lightBlue.withOpacity(0.3),
                        lightBlue.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: primaryColor.withOpacity(0.3), width: 2),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.kitchen,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      "Gérer les équipements",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        "Ajouter/retirer réfrigérateur et congélateur",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    trailing: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.settings,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showEquipmentManagement();
                    },
                  ),
                ),

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
                          "Température réfrigérateur",
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

                // Délégations MAM - gestion des délégations à la journée
                ListTile(
                  leading: Icon(Icons.swap_horiz, color: primaryColor),
                  title: Text(
                    "Délégations (MAM)",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: _buildDelegationsBadgeFuture(),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DelegationsScreen(),
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

  // ====== Quick actions (Grille + feuilles) ======
  Widget _sheetAction({
    required String label,
    required VoidCallback onTap,
    Color? bulletColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      horizontalTitleGap: 8,
      minLeadingWidth: 0,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: (bulletColor ?? primaryColor).withOpacity(0.85),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showCategorySheet({
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return SingleChildScrollView(
              controller: controller,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...children,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openMamAdministration() {
    _showCategorySheet(
      title: 'Administration',
      color: _tileBlue,
      children: [
        _sheetAction(
          label: 'Modifier coordonnées de la MAM',
          onTap: () => context.go('/structure-management'),
          bulletColor: _tileBlue,
        ),
        if (isMAMStructure)
          _sheetAction(
            label: 'Gérer membres (Ajouter / Retirer)',
            onTap: _showMemberManagement,
            bulletColor: _tileBlue,
          ),
        if (isMAMStructure)
          _sheetAction(
            label: 'Affichage des enfants',
            onTap: _showChildDisplaySettings,
            bulletColor: _tileBlue,
          ),
        _sheetAction(
          label: 'Politique de confidentialité',
          onTap: () => _launchURL(
              'https://www.poppin-s.fr/politique-de-confidentialite/'),
          bulletColor: _tileBlue,
        ),
        _sheetAction(
          label: "Conditions d'utilisation",
          onTap: () =>
              _launchURL('https://www.poppin-s.fr/condition-dutilisation/'),
          bulletColor: _tileBlue,
        ),
      ],
    );
  }

  void _openDailyOps() {
    if (isMAMStructure) {
      _showCategorySheet(
        title: 'Fonctionnement quotidien',
        color: _tileRed,
        children: [
          _sheetAction(
            label: 'Planning entretien (qui fait quoi)',
            onTap: () => context.go('/cleaning-schedule'),
            bulletColor: _tileRed,
          ),
          _sheetAction(
            label: 'Planning enfants / horaires',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PlanningScreen()),
            ),
            bulletColor: _tileRed,
          ),
          _sheetAction(
            label: 'Délégations / Remplacement',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const DelegationsScreen()),
            ),
            bulletColor: _tileRed,
          ),
          _sheetAction(
            label: 'Température frigo / congélateur + alertes',
            onTap: _showMAMFunctioning,
            bulletColor: _tileRed,
          ),
          _sheetAction(
            label: 'Gestion équipements / matériel',
            onTap: _showEquipmentManagement,
            bulletColor: _tileRed,
          ),
        ],
      );
    } else {
      _showCategorySheet(
        title: 'Fonctionnement quotidien',
        color: _tileRed,
        children: [
          _sheetAction(
            label: 'Planning enfants / horaires',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PlanningScreen()),
            ),
            bulletColor: _tileRed,
          ),
          _sheetAction(
            label: 'Température frigo / congélateur + alertes',
            onTap: _showAssmatDailyFunctioning,
            bulletColor: _tileRed,
          ),
        ],
      );
    }
  }

  void _openChildrenParents() {
    _showCategorySheet(
      title: 'Enfants et Parents',
      color: _tileCyan,
      children: [
        _sheetAction(
          label: 'Profils enfants complets (santé, besoins, alimentation…)',
          onTap: _showChildProfilesSelection,
          bulletColor: _tileCyan,
        ),
        _sheetAction(
          label: 'Modifier horaires enfants',
          onTap: _showScheduleModification,
          bulletColor: _tileCyan,
        ),
        _sheetAction(
          label: 'Coordonnées des parents',
          onTap: _showParentCoordonneeSelection,
          bulletColor: _tileCyan,
        ),
        _sheetAction(
          label: 'Modifier photo profil enfant',
          onTap: _showPhotoManagement,
          bulletColor: _tileCyan,
        ),
        _sheetAction(
          label: 'Retirer un enfant',
          onTap: _showChildRemoval,
          bulletColor: _tileCyan,
        ),
      ],
    );
  }

  void _openReportsHistory() {
    _showCategorySheet(
      title: 'Mémo et Historique',
      color: _tileYellow,
      children: [
        _sheetAction(
          label: 'Mémo mensuel',
          onTap: () => context.go('/monthly-report-selection'),
          bulletColor: _tileYellow,
        ),
        _sheetAction(
          label: 'Historique complet (présences, repas, sieste…)',
          onTap: _showHistorySelection,
          bulletColor: _tileYellow,
        ),
      ],
    );
  }

  Widget _quickTile({
    required List<String> lines,
    required Color color,
    required VoidCallback onTap,
    required double size,
  }) {
    final List<Widget> titleLines = List<Widget>.generate(
      lines.length,
      (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1), // Réduit de 2 à 1
        child: Text(
          lines[i],
          textAlign: TextAlign.center,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16, // Réduit de 18 à 16
            fontWeight: FontWeight.w600,
            height: 1.1, // Réduit de 1.12 à 1.1
            letterSpacing: 0.0,
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        // Ombre moderne multicouche pour effet de profondeur 2025
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          // Ombre de proximité pour l'effet moderne
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            // Bordure subtile moderne
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            // Effet de pression moderne
            highlightColor: Colors.white.withOpacity(0.1),
            splashColor: Colors.white.withOpacity(0.2),
            child: Container(
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                // Reflet subtil sur le dessus pour l'effet glassmorphism
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                  ],
                  stops: [0.0, 0.3, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12), // Augmenté de 10 à 12
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: titleLines,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double tileWidth =
            (constraints.maxWidth - 16) / 2; // Espacement optimisé
        final double tileSize = tileWidth;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12), // Padding ajusté
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16, // Espacement vertical augmenté
            crossAxisSpacing: 16, // Espacement horizontal augmenté
            childAspectRatio: 1,
          ),
          children: [
            _quickTile(
              lines: ['Administration'],
              color: _tileBlue,
              onTap: _openMamAdministration,
              size: tileSize,
            ),
            _quickTile(
              lines: ['Fonctionnement', 'quotidien'],
              color: _tileRed,
              onTap: _openDailyOps,
              size: tileSize,
            ),
            _quickTile(
              lines: ['Enfants', '& parents'],
              color: _tileCyan,
              onTap: _openChildrenParents,
              size: tileSize,
            ),
            _quickTile(
              lines: ['Mémo', '& Historique'],
              color: _tileYellow,
              onTap: _openReportsHistory,
              size: tileSize,
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
          "Vérification température réfrigérateur: ${needFridgeTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du réfrigérateur: $e");
    }
  }

  void _navigateToAddMember() {
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
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
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
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
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
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
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
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
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

        // Vérifier si l'enfant utilise le mémo mensuel
        bool usesMonthlyTable = data.containsKey('financialInfo') &&
            data['financialInfo'] != null &&
            data['financialInfo']['useMonthlyTable'] == true;

        // Si c'est une MAM, vérifier en plus si l'enfant est assigné au membre connecté
        if (structureType == "MAM") {
          String assignedEmail =
              data['assignedMemberEmail']?.toString().toLowerCase() ?? '';

          // L'enfant doit à la fois utiliser le mémo mensuel ET être assigné au membre connecté
          if (usesMonthlyTable && assignedEmail == currentUserEmail) {
            hasMonthlyTableEnabled = true;
            print(
                "✅ Enfant ${data['firstName']} assigné au membre actuel utilise le mémo mensuel");
            break; // Un seul enfant suffit pour activer la section Rapports
          }
        } else {
          // Pour une assistante maternelle, il suffit qu'un enfant utilise le mémo mensuel
          if (usesMonthlyTable) {
            hasMonthlyTableEnabled = true;
            print("✅ Enfant ${data['firstName']} utilise le mémo mensuel");
            break; // Un seul enfant suffit pour activer la section Rapports
          }
        }
      }

      setState(() {
        showMonthlyTableReports = hasMonthlyTableEnabled;
      });

      print("📊 Affichage de la section Rapports: $hasMonthlyTableEnabled");
    } catch (e) {
      print("❌ Erreur lors de la vérification du mémo mensuel: $e");
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
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
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

  Widget _buildTabletContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;

        // Calculs optimisés pour iPad (expérience 2025)
        final double maxGridWidth = screenWidth * 0.75; // Max 75% de l'écran
        final double gridWidth =
            maxGridWidth.clamp(400.0, 600.0); // Entre 400px et 600px
        final double tileSize =
            (gridWidth - 24) / 2; // 2 colonnes avec espacement

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: screenHeight,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Espacement adaptatif en haut
                SizedBox(
                    height: screenHeight * 0.12), // Augmenté pour centrer mieux

                // Grille des tuiles centrée
                Container(
                  width: gridWidth,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing:
                          24, // Espacement vertical augmenté pour iPad
                      crossAxisSpacing: 24, // Espacement horizontal augmenté
                      childAspectRatio: 1,
                    ),
                    children: [
                      _buildTabletTile(
                        lines: ['Administration'],
                        color: _tileBlue,
                        onTap: _openMamAdministration,
                        size: tileSize,
                      ),
                      _buildTabletTile(
                        lines: ['Fonctionnement', 'quotidien'],
                        color: _tileRed,
                        onTap: _openDailyOps,
                        size: tileSize,
                      ),
                      _buildTabletTile(
                        lines: ['Enfants', '& parents'],
                        color: _tileCyan,
                        onTap: _openChildrenParents,
                        size: tileSize,
                      ),
                      _buildTabletTile(
                        lines: ['Mémo', '& Historique'],
                        color: _tileYellow,
                        onTap: _openReportsHistory,
                        size: tileSize,
                      ),
                    ],
                  ),
                ),

                // Espacement adaptatif en bas (sans section légale)
                SizedBox(height: screenHeight * 0.12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletTile({
    required List<String> lines,
    required Color color,
    required VoidCallback onTap,
    required double size,
  }) {
    final List<Widget> titleLines = List<Widget>.generate(
      lines.length,
      (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          lines[i],
          textAlign: TextAlign.center,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22, // Taille optimisée pour iPad
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(32), // Coins plus arrondis pour iPad
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            highlightColor: Colors.white.withOpacity(0.1),
            splashColor: Colors.white.withOpacity(0.2),
            child: Container(
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                  ],
                  stops: [0.0, 0.4, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20), // Plus d'espace pour iPad
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: titleLines,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
        return isMAMStructure ? "Gestion de la MAM" : "Gestion administrative";
      case 1:
        return "Gestion des Enfants";
      case 2:
        return "Gestion des Tableaux mensuels";
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
        // Modifier les coordonnées - TOUJOURS DISPONIBLE
        _buildTabletActionItem(
          icon: Icons.edit_note,
          title: "Modifier les coordonnées",
          description: "Changer les informations de la structure",
          onTap: () => context.go('/structure-management'),
          maxWidth: maxWidth,
        ),

        // Actions spécifiques selon le type de structure
        if (isMAMStructure) ...[
          // ✅ POUR MAM : Membres + Fonctionnement + Équipements
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.people,
            title: "Modifier les membres",
            description:
                "Gérer les membres de la MAM ($currentMemberCount/$maxMemberCount)",
            onTap: _showMemberManagement,
            maxWidth: maxWidth,
          ),

          // ✅ NOUVEAU : Gestion équipements pour MAM aussi
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.kitchen,
            title: "Gestion des équipements",
            description: "Ajouter ou retirer réfrigérateur et congélateur",
            onTap: _showEquipmentManagement,
            maxWidth: maxWidth,
          ),
        ] else ...[
          // ✅ POUR ASSISTANTE MATERNELLE : Fonctionnement + Équipements
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.settings,
            title: "Fonctionnement quotidien",
            description:
                "Température réfrigérateur, congélateur, planning enfant...",
            onTap: _showAssmatDailyFunctioning,
            maxWidth: maxWidth,
            badge: functioningBadge,
          ),

          // ✅ MAINTENU : Gestion équipements pour Assistante Maternelle
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.kitchen,
            title: "Gestion des équipements",
            description: "Ajouter ou retirer réfrigérateur et congélateur",
            onTap: _showEquipmentManagement,
            maxWidth: maxWidth,
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
          description: "Éditer toutes les informations de l'enfant",
          onTap: _showChildProfilesSelection,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.person_remove,
          title: "Retirer un enfant",
          description: "Gérer le départ d'un enfant",
          onTap: _showChildRemoval,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.contact_page,
          title: "Coordonnées des parents",
          description: "Consulter les coordonnées des parents",
          onTap: _showParentCoordonneeSelection,
          maxWidth: maxWidth,
        ),
        if (kDebugMode) ...[
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.admin_panel_settings,
            title: "🔧 Administration des photos (DEBUG)",
            description:
                "Nettoyage et statistiques des photos - Mode développeur",
            onTap: _showPhotoAdministration,
            maxWidth: maxWidth,
          ),
        ],
      ],
    );
  }

// Nouvelle méthode pour afficher la gestion des équipements
  void _showEquipmentManagement() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.kitchen,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Gestion des équipements",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ MESSAGE EXPLICATIF SIMPLIFIÉ
                    Container(
                      padding: EdgeInsets.all(10), // Réduit de 12 à 10
                      margin: EdgeInsets.only(bottom: 12), // Réduit de 16 à 12
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: primaryColor,
                            size: 18, // Réduit de 20 à 18
                          ),
                          SizedBox(width: 10), // Réduit de 12 à 10
                          Expanded(
                            child: Text(
                              // ✅ TEXTE PLUS COURT
                              isMAMStructure
                                  ? "Équipements MAM"
                                  : "Vos équipements",
                              style: TextStyle(
                                fontSize: 13, // Réduit de 14 à 13
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Équipement Réfrigérateur
                    _buildEquipmentCard(
                      icon: Icons.thermostat,
                      title: "Réfrigérateur",
                      description: "", // ✅ DESCRIPTION GÉRÉE DANS LA MÉTHODE
                      isEnabled:
                          isMAMStructure ? true : (hasAssmatFridge == true),
                      onChanged: (value) {
                        setDialogState(() {});
                        if (isMAMStructure) {
                          _updateMAMEquipmentPreference('fridge', value);
                        } else {
                          _updateEquipmentPreference('fridge', value);
                        }
                      },
                    ),

                    SizedBox(height: 12), // Réduit de 16 à 12

                    // Équipement Congélateur
                    _buildEquipmentCard(
                      icon: Icons.kitchen,
                      title: "Congélateur",
                      description: "", // ✅ DESCRIPTION GÉRÉE DANS LA MÉTHODE
                      isEnabled: isMAMStructure
                          ? (hasFreezer == true)
                          : (hasAssmatFreezer == true),
                      onChanged: (value) {
                        setDialogState(() {});
                        if (isMAMStructure) {
                          _updateMAMEquipmentPreference('freezer', value);
                        } else {
                          _updateEquipmentPreference('freezer', value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "FERMER",
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
      },
    );
  }

  Future<void> _showChildDisplaySettings() async {
    final structureId = await _getStructureId();

    if (structureId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Structure introuvable"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    bool showAllChildren = false;
    try {
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      final data = structureDoc.data();
      if (data != null && data['showAllChildrenOnHome'] is bool) {
        showAllChildren = data['showAllChildrenOnHome'] as bool;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de récupérer les préférences d'affichage."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    int selectedValue = showAllChildren ? 1 : 0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Détecter iPad vs iPhone
            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;
            final bool isTablet = screenWidth >= 600;

            // Tailles adaptées selon l'appareil
            final double dialogWidth = isTablet ? 500.0 : screenWidth * 0.9;
            final double horizontalPadding =
                isTablet ? 32.0 : screenWidth * 0.06;
            final double verticalPadding =
                isTablet ? 24.0 : screenHeight * 0.025;
            final double iconSize = isTablet ? 32.0 : screenWidth * 0.08;
            final double titleFontSize = isTablet ? 22.0 : screenWidth * 0.055;
            final double subtitleFontSize =
                isTablet ? 16.0 : screenWidth * 0.035;
            final double bodyFontSize = isTablet ? 16.0 : screenWidth * 0.04;
            final double cardPadding = isTablet ? 20.0 : screenWidth * 0.04;
            final double buttonHeight = isTablet ? 50.0 : screenHeight * 0.06;

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: screenHeight * (isTablet ? 0.7 : 0.84),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      offset: const Offset(0, 10),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // En-tête moderne
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(verticalPadding),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.8)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.visibility_outlined,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Affichage des enfants',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Personnalisez votre page d'accueil",
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Contenu principal
                      Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Column(
                          children: [
                            Text(
                              "Choisissez les enfants à afficher sur votre page d'accueil",
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),

                            // Options de sélection
                            Column(
                              children: [
                                // Option "Seulement mes enfants"
                                _buildTabletOptionCard(
                                  icon: Icons.person_outline,
                                  title: "Mes enfants seulement",
                                  subtitle:
                                      "Afficher uniquement les enfants qui vous sont assignés",
                                  isSelected: selectedValue == 0,
                                  onTap: () {
                                    setState(() {
                                      selectedValue = 0;
                                    });
                                  },
                                  cardPadding: cardPadding,
                                  bodyFontSize: bodyFontSize,
                                  subtitleFontSize: subtitleFontSize,
                                  iconSize: iconSize * 0.7,
                                ),

                                SizedBox(height: 16),

                                // Option "Tous les enfants"
                                _buildTabletOptionCard(
                                  icon: Icons.group_outlined,
                                  title: "Tous les enfants",
                                  subtitle:
                                      "Afficher tous les enfants de la structure",
                                  isSelected: selectedValue == 1,
                                  onTap: () {
                                    setState(() {
                                      selectedValue = 1;
                                    });
                                  },
                                  cardPadding: cardPadding,
                                  bodyFontSize: bodyFontSize,
                                  subtitleFontSize: subtitleFontSize,
                                  iconSize: iconSize * 0.7,
                                ),
                              ],
                            ),

                            SizedBox(height: 32),

                            // Boutons d'action
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: buttonHeight,
                                    child: TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.grey.shade100,
                                        foregroundColor: Colors.grey.shade700,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        'ANNULER',
                                        style: TextStyle(
                                          fontSize: bodyFontSize * 0.9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    height: buttonHeight,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final bool newValue =
                                            selectedValue == 1;
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('structures')
                                              .doc(structureId)
                                              .update({
                                            'showAllChildrenOnHome': newValue
                                          });

                                          if (!mounted) return;
                                          Navigator.of(dialogContext).pop();

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .check_circle_outline,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      newValue
                                                          ? "Tous les enfants seront affichés"
                                                          : "Seuls vos enfants seront affichés",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor:
                                                  Colors.green.shade600,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              margin: EdgeInsets.all(16),
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(Icons.error_outline,
                                                      color: Colors.white),
                                                  SizedBox(width: 12),
                                                  Text(
                                                      'Échec de la mise à jour des préférences.'),
                                                ],
                                              ),
                                              backgroundColor:
                                                  Colors.red.shade600,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              margin: EdgeInsets.all(16),
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        'VALIDER',
                                        style: TextStyle(
                                          fontSize: bodyFontSize * 0.9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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

  Widget _buildTabletOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required double cardPadding,
    required double bodyFontSize,
    required double subtitleFontSize,
    required double iconSize,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(0.08)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primaryColor : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? primaryColor : Colors.grey.shade400,
                    size: iconSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required double screenWidth,
    required bool isSmallScreen,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(screenWidth *
                (isSmallScreen ? 0.04 : 0.05)), // 4-5% padding adaptatif
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(0.08)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.all(screenWidth * 0.03), // 3% padding
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    size: screenWidth *
                        (isSmallScreen
                            ? 0.055
                            : 0.06), // 5.5-6% de largeur écran
                  ),
                ),
                SizedBox(width: screenWidth * 0.04), // 4% de largeur
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: screenWidth *
                              (isSmallScreen
                                  ? 0.04
                                  : 0.045), // 4-4.5% de largeur
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primaryColor : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: screenWidth *
                              (isSmallScreen
                                  ? 0.032
                                  : 0.035), // 3.2-3.5% de largeur
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? primaryColor : Colors.grey.shade400,
                    size: screenWidth *
                        (isSmallScreen
                            ? 0.055
                            : 0.06), // 5.5-6% de largeur écran
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateMAMEquipmentPreference(
      String equipmentType, bool hasEquipment) async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      if (equipmentType == 'fridge') {
        // ✅ CORRECTION: Pour MAM, permettre d'activer/désactiver le frigo
        // On pourrait créer un champ 'hasMAMFridge' si nécessaire
        // Pour l'instant, message informatif mais on pourrait étendre la logique

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  hasEquipment ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasEquipment
                        ? "Réfrigérateur activé pour la MAM"
                        : "Réfrigérateur désactivé pour la MAM",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: hasEquipment ? Colors.green : primaryColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Congélateur MAM - utiliser la logique existante
        String fieldName = 'hasFreezer';

        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .update({fieldName: hasEquipment});

        setState(() {
          hasFreezer = hasEquipment;
          if (hasEquipment) {
            _checkFreezerTemperatureStatus(structureId);
          } else {
            needFreezerTemperatureCheck = false;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  hasEquipment ? Icons.check_circle : Icons.remove_circle,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasEquipment
                        ? "Congélateur ajouté à la MAM avec succès"
                        : "Congélateur retiré de la MAM avec succès",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: hasEquipment ? Colors.green : primaryColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de la mise à jour de l'équipement MAM: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la mise à jour"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

// Widget pour créer une carte d'équipement moderne
  Widget _buildEquipmentCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isEnabled,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16), // Réduit de 20 à 16
      decoration: BoxDecoration(
        color: isEnabled ? primaryColor.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isEnabled ? primaryColor.withOpacity(0.3) : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10), // Réduit de 12 à 10
            decoration: BoxDecoration(
              color: isEnabled
                  ? primaryColor.withOpacity(0.1)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isEnabled ? primaryColor : Colors.grey.shade600,
              size: 22, // Réduit de 24 à 22
            ),
          ),
          SizedBox(width: 12), // Réduit de 16 à 12
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // ✅ AJOUTÉ pour compacter
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15, // Réduit de 16 à 15
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 2), // Réduit de 4 à 2
                Text(
                  // ✅ TEXTE SIMPLIFIÉ selon le type de structure
                  isMAMStructure
                      ? "Température quotidienne"
                      : "Suivi quotidien",
                  style: TextStyle(
                    fontSize: 12, // Réduit de 14 à 12
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1, // ✅ FORCE UNE SEULE LIGNE
                  overflow: TextOverflow.ellipsis, // ✅ COUPE SI TROP LONG
                ),
              ],
            ),
          ),
          SizedBox(width: 12), // Réduit de 16 à 12
          Transform.scale(
            scale: 1.1, // Réduit de 1.2 à 1.1
            child: Switch(
              value: isEnabled,
              onChanged: onChanged,
              activeColor: primaryColor,
              activeTrackColor: primaryColor.withOpacity(0.3),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }

// Méthode pour mettre à jour les préférences d'équipement
  Future<void> _updateEquipmentPreference(
      String equipmentType, bool hasEquipment) async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      String fieldName =
          equipmentType == 'fridge' ? 'hasAssmatFridge' : 'hasAssmatFreezer';

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({fieldName: hasEquipment});

      setState(() {
        if (equipmentType == 'fridge') {
          hasAssmatFridge = hasEquipment;
          if (hasEquipment) {
            _checkAssmatFridgeTemperatureStatus(structureId);
          } else {
            needAssmatFridgeTemperatureCheck = false;
          }
        } else {
          hasAssmatFreezer = hasEquipment;
          if (hasEquipment) {
            _checkAssmatFreezerTemperatureStatus(structureId);
          } else {
            needAssmatFreezerTemperatureCheck = false;
          }
        }
      });

      // Feedback utilisateur avec animation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                hasEquipment ? Icons.check_circle : Icons.remove_circle,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasEquipment
                      ? "${equipmentType == 'fridge' ? 'Réfrigérateur' : 'Congélateur'} ajouté avec succès"
                      : "${equipmentType == 'fridge' ? 'Réfrigérateur' : 'Congélateur'} retiré avec succès",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: hasEquipment ? Colors.green : primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print("Erreur lors de la mise à jour de l'équipement: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la mise à jour"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // Méthode pour les actions rapports
  Widget _buildReportsActions(double maxWidth, double maxHeight) {
    return ListView(
      children: [
        _buildTabletActionItem(
          icon: Icons.calendar_month,
          title: "Mémo mensuel",
          description: "Consulter les tableaux mensuels",
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
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Espace pour décoller la grille du header
            const SizedBox(height: 24),
            // Grille d'accès rapide (nouvelle UI inspirée des maquettes)
            _buildQuickGrid(),
            const SizedBox(height: 16),
            // Masqué: anciennes sections détaillées (remplacées par la grille)
            if (false) // garde-fou pour ne rien afficher
              ...[
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
                                    content: Text(
                                        "Accès administrateur déverrouillé"),
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
                            isMAMStructure
                                ? "Gestion de la MAM"
                                : "Gestion administrative",
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

                    // Modifier les coordonnées - TOUJOURS disponible
                    _buildActionItem(
                      icon: Icons.edit_note,
                      title: "Modifier les coordonnées",
                      onTap: () => context.go('/structure-management'),
                    ),

                    // Sections spécifiques selon le type de structure
                    if (isMAMStructure) ...[
                      // ✅ POUR MAM : Membres + Fonctionnement + Équipements
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

                      // ✅ NOUVEAU : Gestion équipements pour MAM aussi
                      _buildActionItem(
                        icon: Icons.kitchen,
                        title: "Gestion des équipements",
                        onTap: _showEquipmentManagement,
                      ),
                    ] else ...[
                      // ✅ POUR ASSISTANTE MATERNELLE : Fonctionnement + Équipements
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

                      // ✅ MAINTENU : Gestion équipements pour Assistante Maternelle
                      _buildActionItem(
                        icon: Icons.kitchen,
                        title: "Gestion des équipements",
                        onTap: _showEquipmentManagement,
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
                                    content: Text(
                                        "Accès administrateur déverrouillé"),
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
                      icon: Icons.contact_page,
                      title: "Coordonnées des parents",
                      onTap: _showParentCoordonneeSelection,
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
                      title: "Retirer un enfant",
                      onTap: _showChildRemoval,
                    ),
                    if (kDebugMode)
                      _buildActionItem(
                        icon: Icons.admin_panel_settings,
                        title: "🔧 Administration des photos (DEBUG)",
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
                              "Mémo mensuel",
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
                        title: "Mémo mensuel",
                        onTap: () => context.go('/monthly-report-selection'),
                      ),
                    ],
                  ),
                ),

              /*// Section Historique
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
            ),*/
            ],

            // Section légale déplacée dans la tuile Administration
            /*Container(
              margin: EdgeInsets.only(bottom: 24),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade50,
                    Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.policy_outlined,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Informations légales",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  _buildLegalButtons(isTablet: false),
                ],
              ),
            ),*/
          ],
        ),
      ),
    );
  }

  // Version centrée verticalement de la grille pour mobile
  Widget _buildPhoneContentCentered() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridOuterWidth = constraints.maxWidth - 32; // padding latéral 16
        final tileWidth = (gridOuterWidth - 14) / 2; // 2 colonnes, écart 14
        final tileSize = tileWidth;
        final gridHeight =
            12 + tileSize + 14 + tileSize + 8; // padding + espaces
        final available = constraints.maxHeight;
        final topGap = (available > gridHeight)
            ? ((available - gridHeight) / 2).clamp(16.0, 160.0)
            : 16.0;

        return SingleChildScrollView(
          physics: available > gridHeight
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topGap, 16, 16),
            child: _buildQuickGrid(),
          ),
        );
      },
    );
  }

  String _getMAMStatusText() {
    if (currentMemberCount < maxMemberCount) {
      // Exemple: "1 membre sur 2 autorisés" ou "2 membres sur 3 autorisés"
      return "$currentMemberCount membre${currentMemberCount > 1 ? 's' : ''} sur $maxMemberCount autorisé${maxMemberCount > 1 ? 's' : ''}";
    } else {
      // Exemple: "2/2 membres" ou "3/3 membres"
      return "$currentMemberCount/$maxMemberCount membres";
    }
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

    // 🆕 AJOUT : Vérification de l'abonnement
    return FutureBuilder<bool>(
      future: SubscriptionService.isUserSubscribed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }

        final bool isSubscribed = snapshot.data ?? false;

        if (!isSubscribed) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dashboard_outlined,
                    size: 80,
                    color: primaryColor,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Tableau de bord premium",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Accédez à la gestion complète",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => context.go('/pricing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: Text(
                      "DÉBLOQUER LE DASHBOARD",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
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
                      bottomLeft: Radius.circular(
                          MediaQuery.of(context).size.width * 0.06),
                      bottomRight: Radius.circular(
                          MediaQuery.of(context).size.width * 0.06),
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
                        // Date du jour (sans le titre 'Tableau de bord')
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
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
                                fontSize: screenSize.width *
                                    (isTablet ? 0.018 : 0.035),
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        // Nom de la structure
                        Text(
                          structureName,
                          style: TextStyle(
                            fontSize:
                                screenSize.width * (isTablet ? 0.024 : 0.045),
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
                                  // ✅ CORRECTION : Affichage correct selon la situation
                                  _getMAMStatusText(),
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
                child: isTablet
                    ? _buildTabletContent()
                    : _buildPhoneContentCentered(),
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
      },
    );
  }
}
