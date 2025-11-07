import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';
import '../utils/structure_context.dart';
import '../utils/planning_helper.dart';
import '../utils/child_avatar_color_helper.dart';
import '../utils/absence_helper.dart';

class SiesteScreen extends StatefulWidget {
  const SiesteScreen({Key? key}) : super(key: key);

  @override
  _SiesteScreenState createState() => _SiesteScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _SiesteScreenState extends State<SiesteScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  int _selectedIndex = 1;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Utilisation des couleurs officielles de l'application
  Color primaryColor = Color(0xFF3D9DF2); // primaryBlue
  Color secondaryColor = Color(0xFFDFE9F2); // lightBlue

  int _siesteHours = 1;
  int _siesteMinutes = 0;
  TextEditingController _durationController = TextEditingController(text: "");
  String _sleepQuality = "Bien dormi";
  TextEditingController _observationsController = TextEditingController();
  String _siesteTime = ""; // Ancien champ (compat)
  String _siesteStart = "";
  String _siesteEnd = "";

  final List<Map<String, dynamic>> qualityLevels = [
    {"label": "Pas dormi", "stars": 1},
    {"label": "Peu dormi", "stars": 2},
    {"label": "Bien dormi", "stars": 3},
    {"label": "Très bien dormi", "stars": 4},
  ];

  @override
  void dispose() {
    _observationsController.dispose();
    _durationController.dispose(); // Ajouter cette ligne
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadEnfantsDuJour();
    });
  }

  Future<void> _selectSiesteTime(
      StateSetter setState, Function(String) onTimeSelected) async {
    // Obtenir l'heure actuelle ou celle déjà saisie
    TimeOfDay initialTime;
    if (_siesteTime.isNotEmpty) {
      final parts = _siesteTime.split(':');
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

  // Nouveau: picker d'heure avec heure initiale fournie
  Future<void> _pickTimeWithInitial({
    required String current,
    required void Function(String) onPicked,
  }) async {
    TimeOfDay initialTime;
    if (current.isNotEmpty && current.contains(':')) {
      final parts = current.split(':');
      initialTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? TimeOfDay.now().hour,
        minute: int.tryParse(parts[1]) ?? TimeOfDay.now().minute,
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
              hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? primaryColor.withOpacity(0.15)
                      : Colors.transparent),
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
      onPicked(timeString);
    }
  }

  void _showDurationPicker(StateSetter setState) {
    final bool isTabletDevice = isTablet(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        int tempHours = _siesteHours;
        int tempMinutes = _siesteMinutes;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: isTabletDevice ? 400 : 350,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Titre
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "Durée de la sieste",
                      style: TextStyle(
                        fontSize: isTabletDevice ? 22 : 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  // Sélecteurs de durée
                  Expanded(
                    child: Row(
                      children: [
                        // Sélecteur d'heures
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Heures",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 12),
                              Expanded(
                                child: ListWheelScrollView.useDelegate(
                                  itemExtent: isTabletDevice ? 60 : 50,
                                  perspective: 0.005,
                                  diameterRatio: 1.2,
                                  physics: FixedExtentScrollPhysics(),
                                  onSelectedItemChanged: (index) {
                                    setModalState(() {
                                      tempHours = index;
                                    });
                                  },
                                  controller: FixedExtentScrollController(
                                    initialItem: tempHours,
                                  ),
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    builder: (context, index) {
                                      return Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: index == tempHours
                                              ? primaryColor.withOpacity(0.1)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          "$index h",
                                          style: TextStyle(
                                            fontSize: isTabletDevice ? 24 : 20,
                                            fontWeight: index == tempHours
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: index == tempHours
                                                ? primaryColor
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: 5, // 0 à 4 heures
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Séparateur
                        Container(
                          width: 2,
                          height: 100,
                          color: Colors.grey.shade200,
                          margin: EdgeInsets.symmetric(horizontal: 20),
                        ),

                        // Sélecteur de minutes
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Minutes",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 12),
                              Expanded(
                                child: ListWheelScrollView.useDelegate(
                                  itemExtent: isTabletDevice ? 60 : 50,
                                  perspective: 0.005,
                                  diameterRatio: 1.2,
                                  physics: FixedExtentScrollPhysics(),
                                  onSelectedItemChanged: (index) {
                                    setModalState(() {
                                      tempMinutes =
                                          index * 5; // Incréments de 5 minutes
                                    });
                                  },
                                  controller: FixedExtentScrollController(
                                    initialItem: tempMinutes ~/ 5,
                                  ),
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    builder: (context, index) {
                                      int minutes = index * 5;
                                      return Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: minutes == tempMinutes
                                              ? primaryColor.withOpacity(0.1)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          "${minutes.toString().padLeft(2, '0')} min",
                                          style: TextStyle(
                                            fontSize: isTabletDevice ? 24 : 20,
                                            fontWeight: minutes == tempMinutes
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: minutes == tempMinutes
                                                ? primaryColor
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      );
                                    },
                                    childCount:
                                        12, // 0 à 55 minutes par pas de 5
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Boutons d'action
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
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
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _siesteHours = tempHours;
                                _siesteMinutes = tempMinutes;
                                _updateDurationDisplay();
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateDurationDisplay() {
    String duration = "";
    if (_siesteHours > 0) {
      duration += "${_siesteHours}h";
    }
    if (_siesteMinutes > 0) {
      if (duration.isNotEmpty) duration += " ";
      duration += "${_siesteMinutes.toString().padLeft(2, '0')}min";
    }
    if (duration.isEmpty) {
      duration = "0min";
    }
    _durationController.text = duration;
  }

  Future<void> _loadEnfantsDuJour() async {
    setState(() => isLoading = true);
    try {
      final structureContext = await StructureResolver().resolve();
      final String structureId = structureContext.structureId;
      final String currentUserEmail = structureContext.currentUserEmail;
      final String structureType = structureContext.normalizedStructureType;
      final bool allowAllChildren = structureContext.showAllChildren;

      final today = DateTime.now();
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      setState(() {
        structureName = structureContext.structureName;
      });

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

      Set<String> delegatedTodayChildIds = {};
      String? myMemberId;
      final bool useMamColors = structureType == 'mam';
      Map<String, Color> mamColorAssignments = {};
      if (structureType == 'mam') {
        if (allowAllChildren) {
          filteredChildren = List<Map<String, dynamic>>.from(allChildren);
          print(
              "👨‍👧‍👦 Sieste: Membre MAM - affichage de tous les enfants de la structure");
        } else {
          filteredChildren = allChildren.where((child) {
            String assignedEmail =
                child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
            return assignedEmail == currentUserEmail;
          }).toList();

          print(
              "👨‍👧‍👦 Sieste: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
        }
        // ➕ Ajouter enfants délégués aujourd'hui
        try {
          final memSnap = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('members')
              .where('email', isEqualTo: currentUserEmail)
              .limit(1)
              .get();
          if (memSnap.docs.isNotEmpty) {
            myMemberId = memSnap.docs.first.id;
            final now = DateTime.now();
            final start = DateTime(now.year, now.month, now.day);
            final end = start.add(const Duration(days: 1));
            final delSnap = await FirebaseFirestore.instance
                .collection('structures')
                .doc(structureId)
                .collection('delegations')
                .where('status', isEqualTo: 'accepted')
                .where('amDelegateId', isEqualTo: myMemberId)
                .where('date',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('date', isLessThan: Timestamp.fromDate(end))
                .get();
            delegatedTodayChildIds = delSnap.docs
                .map((d) => (d.data()['childId'] ?? '').toString())
                .where((id) => id.isNotEmpty)
                .toSet();
            if (delegatedTodayChildIds.isNotEmpty) {
              final already =
                  filteredChildren.map((c) => c['id'] as String).toSet();
              final toAddIds = delegatedTodayChildIds.difference(already);
              if (toAddIds.isNotEmpty) {
                filteredChildren.addAll(allChildren
                    .where((c) => toAddIds.contains(c['id'] as String)));
                print('➕ Sieste: ajout enfants délégués: ${toAddIds.length}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Sieste: erreur overlay délégation: $e');
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Sieste: Assistante Maternelle - affichage de tous les enfants");
      }

      if (useMamColors) {
        mamColorAssignments =
            ChildAvatarColorHelper.buildMamAssignmentsFromChildren(
          filteredChildren,
        );
      }

      final Set<String> absentChildIds =
          await AbsenceHelper.fetchAbsentChildIds(structureId, date: today);

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui
      List<Map<String, dynamic>> tempEnfants = [];
      for (var child in filteredChildren) {
        if (absentChildIds.contains(child['id'])) {
          continue;
        }
        final isScheduledToday =
            PlanningHelper.isScheduledForDate(child, today);
        final isDelegatedToday = delegatedTodayChildIds.contains(child['id']);
        if (isScheduledToday || isDelegatedToday) {
          final String assignedEmail = ChildAvatarColorHelper.normalizeEmail(
              child['assignedMemberEmail']);
          final Color avatarColor = ChildAvatarColorHelper.resolveAvatarColor(
            isMamStructure: useMamColors,
            mamAssignments: mamColorAssignments,
            assignedMemberEmail: assignedEmail,
            gender: child['gender']?.toString(),
          );
          String? photoUrl = child['photoUrl'];
          tempEnfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'assignedMemberEmail': assignedEmail,
            'avatarColor': avatarColor,
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

  int _getMoonCountFromQuality(String quality) {
    switch (quality) {
      case 'Pas dormi':
        return 1;
      case 'Peu dormi':
        return 2;
      case 'Bien dormi':
        return 3;
      case 'Très bien dormi':
        return 4;
      default:
        return 0;
    }
  }

  Widget _buildMoonIcon() {
    return Icon(
      Icons.nightlight_round,
      color: Colors.indigo,
      size: 20,
    );
  }

  void _showSiesteDetailsPopup(String structureId, String childId,
      String siesteId, Map<String, dynamic> siesteData) {
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
                            Icons.nightlight_round,
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
                                "Sieste de ${siesteData['heure']}",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMMM yyyy', 'fr_FR')
                                    .format(siesteData['date'].toDate())
                                    .toLowerCase(),
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bouton supprimer (même emplacement/UX que Repas & Activités)
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: () {
                            _confirmDeleteSieste(
                                context, structureId, childId, siesteId);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Contenu
                  Padding(
                    padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type d'activité
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.hourglass_bottom,
                                color: primaryColor,
                                size: isTabletDevice ? 24 : 20,
                              ),
                              SizedBox(width: 12),
                              Spacer(),
                              Text(
                                (siesteData['end'] == null ||
                                        (siesteData['end']
                                                ?.toString()
                                                .isEmpty ??
                                            true))
                                    ? 'Durée: en cours'
                                    : "Durée: ${siesteData['duration']}",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Participation (qualité) - affichée seulement si disponible
                        if ((siesteData['qualite'] ?? '').toString().isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: lightBlue, // Fond bleu à la place du jaune
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Row(
                                  children: List.generate(
                                    siesteData['moonCount'] ?? 0,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(
                                        right: index <
                                                (siesteData['moonCount'] ?? 0) -
                                                    1
                                            ? 4
                                            : 0,
                                      ),
                                      child: Icon(
                                        Icons.nightlight_round,
                                        color:
                                            primaryYellow, // Lunes restent jaunes
                                        size: isTabletDevice ? 22 : 20,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "${siesteData['qualite']}",
                                  style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w500,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Observations
                        if (siesteData['observations']?.isNotEmpty ??
                            false) ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Observations",
                                  style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  siesteData['observations'],
                                  style: TextStyle(
                                    fontSize: isTabletDevice ? 16 : 14,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Bouton Fermer
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
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
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showEditSiestePopup(structureId, childId,
                                      siesteId, siesteData);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  // Si pas d'heure de fin, proposer de terminer
                                  ((siesteData['end'] == null) ||
                                          (siesteData['end']
                                                  ?.toString()
                                                  .isEmpty ??
                                              true))
                                      ? 'TERMINER'
                                      : 'MODIFIER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
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
  }

  // Confirmation & suppression d'une sieste
  void _confirmDeleteSieste(BuildContext dialogContext, String structureId,
      String childId, String siesteId) {
    showModalBottomSheet(
      context: dialogContext,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_outline, color: Colors.red),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Supprimer cette sieste ?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Cette action retirera la sieste du journal, du récapitulatif et du fil des parents pour la journée.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.3),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Annuler'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('structures')
                                .doc(structureId)
                                .collection('children')
                                .doc(childId)
                                .collection('siestes')
                                .doc(siesteId)
                                .delete();

                            if (Navigator.of(ctx).canPop())
                              Navigator.of(ctx).pop();
                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Sieste supprimée.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Erreur lors de la suppression de la sieste.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// Nouveau bouton de qualité de sommeil moderne
  Widget _buildSleepQualityButtonModern(
    String quality,
    String selectedQuality,
    Function(String) onSelect,
    bool isTablet,
    int moonCount,
    Color color,
  ) {
    bool isSelected = selectedQuality == quality;

    // Utilisation des couleurs officielles de l'application avec opacité adaptée
    Color backgroundColor;
    Color textColor;
    Color iconColor;

    if (isSelected) {
      // Si le bouton est sélectionné
      backgroundColor = color.withOpacity(0.15);
      textColor = color;
      iconColor = color;
    } else {
      // Si le bouton n'est pas sélectionné
      backgroundColor = Colors.grey.shade100;
      textColor = Colors.grey.shade700;
      iconColor = Colors.grey.shade400;
    }

    return GestureDetector(
      onTap: () => onSelect(quality),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? iconColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: List.generate(
                moonCount,
                (index) => Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Icon(
                    Icons.nightlight_round,
                    color: iconColor,
                    size: isTablet ? 18 : 16,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                quality,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 15 : 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSiestePopup(String structureId, String childId, String siesteId,
      Map<String, dynamic> siesteData) {
    // Pré-remplir début/fin en tentant d'utiliser 'start'/'end' ou parser 'heure'
    final bool wasInProgress = (siesteData['end'] == null) ||
        ((siesteData['end']?.toString().isEmpty) ?? true);
    String localStart = (siesteData['start'] ?? '').toString();
    String localEnd = (siesteData['end'] ?? '').toString();
    if (localStart.isEmpty || localEnd.isEmpty) {
      final heure = (siesteData['heure'] ?? '').toString();
      if (heure.contains('-')) {
        final parts = heure.split('-').map((s) => s.trim()).toList();
        if (parts.length == 2) {
          localStart = parts[0];
          localEnd = parts[1];
        }
      }
    }
    String localQuality = (siesteData['qualite'] ?? 'Bien dormi').toString();
    final int localMoonCount = _getMoonCountFromQuality(localQuality);
    TextEditingController obsCtrl = TextEditingController(
        text: (siesteData['observations'] ?? '').toString());

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
                    children: [
                      // En-tête
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.85)
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
                                Icons.nightlight_round,
                                color: Colors.white,
                                size: isTabletDevice ? 26 : 22,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Modifier une sieste',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isTabletDevice ? 20 : 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Corps
                      Padding(
                        padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Début/Fin
                            Text('Heures de la sieste',
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await _pickTimeWithInitial(
                                          current: localStart,
                                          onPicked: (val) => setState(() {
                                                localStart = val;
                                              }));
                                    },
                                    icon: Icon(Icons.play_arrow,
                                        color: primaryColor),
                                    label: Text(
                                      localStart.isEmpty ? 'Début' : localStart,
                                      style: TextStyle(color: primaryColor),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: primaryColor),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      padding: EdgeInsets.symmetric(
                                          vertical: isTabletDevice ? 16 : 14),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await _pickTimeWithInitial(
                                          current: localEnd,
                                          onPicked: (val) => setState(() {
                                                localEnd = val;
                                              }));
                                    },
                                    icon: Icon(Icons.stop, color: primaryColor),
                                    label: Text(
                                      localEnd.isEmpty ? 'Fin' : localEnd,
                                      style: TextStyle(color: primaryColor),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: primaryColor),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      padding: EdgeInsets.symmetric(
                                          vertical: isTabletDevice ? 16 : 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),
                            // Qualité
                            Text('Qualité du sommeil',
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: isTabletDevice ? 2.5 : 2.3,
                              children: [
                                _buildSleepQualityButtonModern(
                                  'Pas dormi',
                                  localQuality,
                                  (q) => setState(() => localQuality = q),
                                  isTabletDevice,
                                  1,
                                  primaryRed,
                                ),
                                _buildSleepQualityButtonModern(
                                  'Peu dormi',
                                  localQuality,
                                  (q) => setState(() => localQuality = q),
                                  isTabletDevice,
                                  2,
                                  Colors.amber,
                                ),
                                _buildSleepQualityButtonModern(
                                  'Bien dormi',
                                  localQuality,
                                  (q) => setState(() => localQuality = q),
                                  isTabletDevice,
                                  3,
                                  Colors.indigo,
                                ),
                                _buildSleepQualityButtonModern(
                                  'Très bien dormi',
                                  localQuality,
                                  (q) => setState(() => localQuality = q),
                                  isTabletDevice,
                                  4,
                                  Colors.green,
                                ),
                              ],
                            ),

                            SizedBox(height: 16),
                            // Observations
                            Text('Observations',
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 8),
                            TextField(
                              controller: obsCtrl,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Précisions sur la sieste...',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),

                            SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: Text('ANNULER'),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      // Validation
                                      if (localStart.isEmpty ||
                                          localEnd.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(localStart.isEmpty
                                                ? 'Veuillez indiquer l\'heure de début'
                                                : 'Veuillez indiquer l\'heure de fin'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                      int toMinutes(String t) {
                                        final p = t.split(':');
                                        return (int.parse(p[0]) * 60) +
                                            int.parse(p[1]);
                                      }

                                      if (toMinutes(localEnd) <=
                                          toMinutes(localStart)) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'L\'heure de fin doit être après le début'),
                                          backgroundColor: Colors.red,
                                        ));
                                        return;
                                      }

                                      // Calcul durée
                                      final diff = toMinutes(localEnd) -
                                          toMinutes(localStart);
                                      final h = diff ~/ 60;
                                      final m = diff % 60;
                                      String durationLabel = '';
                                      if (h > 0) durationLabel += '${h}h';
                                      if (m > 0) {
                                        if (durationLabel.isNotEmpty)
                                          durationLabel += ' ';
                                        durationLabel +=
                                            '${m.toString().padLeft(2, '0')}min';
                                      }
                                      if (durationLabel.isEmpty)
                                        durationLabel = '0min';

                                      try {
                                        final docRef = FirebaseFirestore
                                            .instance
                                            .collection('structures')
                                            .doc(structureId)
                                            .collection('children')
                                            .doc(childId)
                                            .collection('siestes')
                                            .doc(siesteId);
                                        await docRef.update({
                                          'heure':
                                              '${localStart} - ${localEnd}',
                                          'start': localStart,
                                          'end': localEnd,
                                          'duration': durationLabel,
                                          'qualite': localQuality,
                                          'moonCount': _getMoonCountFromQuality(
                                              localQuality),
                                          'observations': obsCtrl.text,
                                        });

                                        Navigator.of(context).pop();
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'Erreur lors de la mise à jour de la sieste'),
                                          backgroundColor: Colors.red,
                                        ));
                                      }
                                    },
                                    child: Text(wasInProgress
                                        ? 'TERMINER'
                                        : 'ENREGISTRER'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
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

  void _showAddSiestePopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    // Variables locales pour les heures début/fin et la qualité
    String localStart = _siesteStart;
    String localEnd = _siesteEnd;
    String localSleepQuality = _sleepQuality;
    String? errorMessage;

    // Déterminer si nous sommes sur iPad
    final bool isTabletDevice = isTablet(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isTabletDevice
                    ? MediaQuery.of(context).size.width * 0.25
                    : 20,
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
                                Icons.nightlight_round,
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
                                    "Ajouter une sieste - ${enfant['prenom']}",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 22 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMMM yyyy', 'fr_FR')
                                        .format(DateTime.now())
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

                      // Contenu
                      Padding(
                        padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sélecteurs Début / Fin de la sieste (style "horaire")
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Heure de la sieste",
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
                                        child: (localStart.isNotEmpty)
                                            ? GestureDetector(
                                                onLongPress: () async {
                                                  await _pickTimeWithInitial(
                                                    current: localStart,
                                                    onPicked: (val) {
                                                      setState(() {
                                                        localStart = val;
                                                        errorMessage = null;
                                                      });
                                                    },
                                                  );
                                                },
                                                child: ElevatedButton(
                                                  onPressed: null,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        primaryColor,
                                                    disabledBackgroundColor:
                                                        primaryColor,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                    ),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical:
                                                                isTabletDevice
                                                                    ? 16
                                                                    : 14,
                                                            horizontal: 12),
                                                  ),
                                                  child: Text(
                                                    localStart,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: isTabletDevice
                                                          ? 18
                                                          : 16,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : OutlinedButton.icon(
                                                onPressed: () {
                                                  final now = TimeOfDay.now();
                                                  final s =
                                                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                                                  setState(() {
                                                    localStart = s;
                                                    errorMessage = null;
                                                  });
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                      color: primaryColor),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: isTabletDevice
                                                          ? 16
                                                          : 14,
                                                      horizontal: 12),
                                                ),
                                                icon: Icon(Icons.play_arrow,
                                                    color: primaryColor),
                                                label: Text(
                                                  'Début',
                                                  style: TextStyle(
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: isTabletDevice
                                                        ? 18
                                                        : 16,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: (localEnd.isNotEmpty)
                                            ? GestureDetector(
                                                onLongPress: () async {
                                                  await _pickTimeWithInitial(
                                                    current: localEnd,
                                                    onPicked: (val) {
                                                      setState(() {
                                                        localEnd = val;
                                                        errorMessage = null;
                                                      });
                                                    },
                                                  );
                                                },
                                                child: ElevatedButton(
                                                  onPressed: null,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        primaryColor,
                                                    disabledBackgroundColor:
                                                        primaryColor,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                    ),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical:
                                                                isTabletDevice
                                                                    ? 16
                                                                    : 14,
                                                            horizontal: 12),
                                                  ),
                                                  child: Text(
                                                    localEnd,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: isTabletDevice
                                                          ? 18
                                                          : 16,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : OutlinedButton.icon(
                                                onPressed: () {
                                                  final now = TimeOfDay.now();
                                                  final s =
                                                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                                                  setState(() {
                                                    localEnd = s;
                                                    errorMessage = null;
                                                  });
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                      color: primaryColor),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: isTabletDevice
                                                          ? 16
                                                          : 14,
                                                      horizontal: 12),
                                                ),
                                                icon: Icon(Icons.stop,
                                                    color: primaryColor),
                                                label: Text(
                                                  'Fin',
                                                  style: TextStyle(
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: isTabletDevice
                                                        ? 18
                                                        : 16,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                  if (localStart.isNotEmpty ||
                                      localEnd.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Appui long sur une heure pour modifier',
                                        style: TextStyle(
                                          fontSize: isTabletDevice ? 14 : 12,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Section Qualité de sommeil
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Comment a dormi ${enfant['prenom']} ?",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio:
                                        isTabletDevice ? 2.5 : 2.3,
                                    children: [
                                      _buildSleepQualityButtonModern(
                                        'Pas dormi',
                                        localSleepQuality,
                                        (value) {
                                          setState(() {
                                            localSleepQuality = value;
                                          });
                                        },
                                        isTabletDevice,
                                        1,
                                        primaryRed,
                                      ),
                                      _buildSleepQualityButtonModern(
                                        'Peu dormi',
                                        localSleepQuality,
                                        (value) {
                                          setState(() {
                                            localSleepQuality = value;
                                          });
                                        },
                                        isTabletDevice,
                                        2,
                                        Colors.amber,
                                      ),
                                      _buildSleepQualityButtonModern(
                                        'Bien dormi',
                                        localSleepQuality,
                                        (value) {
                                          setState(() {
                                            localSleepQuality = value;
                                          });
                                        },
                                        isTabletDevice,
                                        3,
                                        primaryColor,
                                      ),
                                      _buildSleepQualityButtonModern(
                                        'Très bien dormi',
                                        localSleepQuality,
                                        (value) {
                                          setState(() {
                                            localSleepQuality = value;
                                          });
                                        },
                                        isTabletDevice,
                                        4,
                                        primaryYellow,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // (Durée supprimée: sera calculée automatiquement à partir Début/Fin)

                            // Section Observations
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Observations",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _observationsController,
                                      decoration: InputDecoration(
                                        hintText: "Précisions sur la sieste...",
                                        hintStyle: TextStyle(
                                            color: Colors.grey.shade400),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade200,
                                              width: 1),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                              color: primaryColor, width: 2),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 16),
                                      ),
                                      maxLines: 3,
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 16 : 14,
                                        color: Colors.black87,
                                      ),
                                    ),
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

                                // Bouton Démarrer/Ajouter
                                ElevatedButton(
                                  onPressed: () async {
                                    // Cas 1: aucun début saisi
                                    if (localStart.isEmpty) {
                                      setState(() {
                                        errorMessage =
                                            'Veuillez indiquer l\'heure de début';
                                      });
                                      return;
                                    }

                                    // Cas 2: début saisi mais pas de fin -> démarrer la sieste (en cours)
                                    if (localEnd.isEmpty) {
                                      setState(() => errorMessage = null);
                                      _siesteStart = localStart;
                                      _siesteEnd = '';
                                      // On ne persiste pas la qualité/observations à ce stade
                                      _addSiesteToFirebase(childId);
                                      Navigator.of(context).pop();
                                      return;
                                    }

                                    // Cas 3: début et fin saisis -> vérifier cohérence et ajouter complet
                                    int _toMinutes(String t) {
                                      final p = t.split(':');
                                      return (int.parse(p[0]) * 60) +
                                          int.parse(p[1]);
                                    }

                                    final startMins = _toMinutes(localStart);
                                    final endMins = _toMinutes(localEnd);
                                    if (endMins <= startMins) {
                                      setState(() {
                                        errorMessage =
                                            'L\'heure de fin doit être après le début';
                                      });
                                      return;
                                    }

                                    setState(() => errorMessage = null);
                                    _siesteStart = localStart;
                                    _siesteEnd = localEnd;
                                    _sleepQuality = localSleepQuality;
                                    _addSiesteToFirebase(childId);
                                    Navigator.of(context).pop();
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
                                    // Si seule l'heure de début est renseignée, on démarre
                                    (localStart.isNotEmpty && localEnd.isEmpty)
                                        ? "DÉMARRER"
                                        : "AJOUTER",
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

  // Vérifie si l'enfant a une heure d'arrivée enregistrée aujourd'hui
  Future<bool> _isChildArrivedToday(String structureId, String childId) async {
    try {
      final String dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final doc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('horaires')
          .doc(dateKey)
          .get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey(childId)) return false;
      final ch = data[childId] as Map<String, dynamic>?;
      if (ch == null) return false;
      if (ch['actionType'] == 'absent') return false;
      if (ch['segments'] is List) {
        for (final seg in (ch['segments'] as List)) {
          final arr = seg['arrivee'];
          if (arr != null && arr.toString().isNotEmpty) return true;
        }
      }
      final arr = ch['arrivee'];
      if (arr != null && arr.toString().isNotEmpty) return true;
      return false;
    } catch (e) {
      print('Erreur vérification arrivée (sieste): $e');
      return false;
    }
  }

  Future<void> _guardAddSieste(String structureId, String childId) async {
    final arrived = await _isChildArrivedToday(structureId, childId);
    if (!arrived) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Arrivée requise'),
          content: Text(
              "Attention : vous n'avez pas indiqué l'heure d'arrivée.\n\nVeuillez indiquer l'horaire d'arrivée pour pouvoir ajouter une sieste."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    _showAddSiestePopup(childId);
  }

  Widget _buildSleepQualityButton(
    String quality,
    String selectedQuality,
    Function(String) onSelect,
  ) {
    bool isSelected = selectedQuality == quality;
    return GestureDetector(
      onTap: () => onSelect(quality),
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
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _getMoonCountFromQuality(quality),
                (index) => Padding(
                  padding: EdgeInsets.only(
                      right: index < _getMoonCountFromQuality(quality) - 1
                          ? 2
                          : 0),
                  child: Icon(Icons.nightlight_round,
                      color: isSelected ? primaryColor : Colors.grey.shade600,
                      size: 16),
                ),
              ),
            ),
            SizedBox(height: 4),
            Text(
              quality,
              style: TextStyle(
                color: isSelected ? primaryColor : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSiesteToFirebase(String childId) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference siesteRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('siestes')
          .doc();

      // Construire l'affichage et la durée à partir des heures début/fin
      // Si seule l'heure de début est fournie, on marque visuellement l'état "en cours".
      String heureLabel;
      if (_siesteStart.isNotEmpty && _siesteEnd.isNotEmpty) {
        heureLabel = '${_siesteStart} - ${_siesteEnd}';
      } else if (_siesteStart.isNotEmpty) {
        heureLabel = '${_siesteStart} - …';
      } else {
        heureLabel = _siesteTime; // fallback ancien champ si non saisi
      }

      String durationLabel = '';
      if (_siesteStart.isNotEmpty && _siesteEnd.isNotEmpty) {
        int _toMinutes(String t) {
          final p = t.split(':');
          return (int.parse(p[0]) * 60) + int.parse(p[1]);
        }

        final diff = _toMinutes(_siesteEnd) - _toMinutes(_siesteStart);
        final h = diff ~/ 60;
        final m = diff % 60;
        durationLabel = '';
        if (h > 0) durationLabel += '${h}h';
        if (m > 0) {
          if (durationLabel.isNotEmpty) durationLabel += ' ';
          durationLabel += '${m.toString().padLeft(2, '0')}min';
        }
        if (durationLabel.isEmpty) durationLabel = '0min';
      }

      final Map<String, dynamic> siesteData = {
        'heure': heureLabel,
        'date': DateTime.now(),
        // duration seulement si fin connue
        'duration': (_siesteStart.isNotEmpty && _siesteEnd.isNotEmpty)
            ? durationLabel
            : null,
        // Qualité/observations seulement lors de la fin
        'qualite': (_siesteStart.isNotEmpty && _siesteEnd.isNotEmpty)
            ? _sleepQuality
            : null,
        'moonCount': (_siesteStart.isNotEmpty && _siesteEnd.isNotEmpty)
            ? _getMoonCountFromQuality(_sleepQuality)
            : null,
        'observations': (_siesteStart.isNotEmpty && _siesteEnd.isNotEmpty)
            ? _observationsController.text
            : null,
        // Nouveaux champs normalisés
        'start': _siesteStart.isNotEmpty ? _siesteStart : null,
        'end': _siesteEnd.isNotEmpty ? _siesteEnd : null,
      }..removeWhere((key, value) => value == null);

      await siesteRef.set(siesteData);

      setState(() {
        _siesteTime = '';
        _siesteStart = '';
        _siesteEnd = '';
        _siesteHours = 1;
        _siesteMinutes = 0;
        _updateDurationDisplay();
        _sleepQuality = 'Bien dormi';
        _observationsController.clear();
      });

      print("Sieste ajoutée avec succès !");
    } catch (e) {
      print("Erreur lors de l'ajout de la sieste : $e");
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: lightBlue,
      child: Icon(
        Icons.person_outline,
        size: 60,
        color: primaryColor.withOpacity(0.5),
      ),
    );
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    String genre = enfant['genre']?.toString() ?? '';
    final Color avatarColor = (enfant['avatarColor'] as Color?) ??
        ChildAvatarColorHelper.defaultColorForGender(genre);

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
                // Utilisation de l'avatar avec dégradé comme dans ActivityScreen
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
                          color: Colors.black,
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
                  onPressed: () => _guardAddSieste(
                      enfant['structureId'] ??
                          FirebaseAuth.instance.currentUser?.uid,
                      enfant['id']),
                ),
              ],
            ),
          ),
          // Liste des siestes
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('siestes')
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
                        "Aucune sieste aujourd'hui",
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
                  final doc = snapshot.data!.docs[index];
                  final siesteData = doc.data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showSiesteDetailsPopup(
                        enfant['structureId'] ??
                            FirebaseAuth.instance.currentUser?.uid,
                        enfant['id'],
                        doc.id,
                        siesteData),
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
                              Icons.nightlight_round,
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
                                      ((siesteData['end'] == null) ||
                                              (siesteData['end']
                                                      ?.toString()
                                                      .isEmpty ??
                                                  true))
                                          ? 'En cours • Début ${siesteData['start'] ?? (siesteData['heure'] ?? '')}'
                                          : (siesteData['heure'] ?? ''),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  ((siesteData['end'] == null) ||
                                          (siesteData['end']
                                                  ?.toString()
                                                  .isEmpty ??
                                              true))
                                      ? 'Durée: en cours'
                                      : "Durée: ${siesteData['duration']}",
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
                              siesteData['moonCount'] ?? 0,
                              (index) => Icon(
                                Icons.nightlight_round,
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      context.go('/dashboard');
    } else if (index == 1) {
      context.go('/home');
    } else if (index == 2) {
      context.go('/exchanges');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = isTablet(context);

    // 🎉 NOUVEAU : Entourer avec SwipeNavigationWrapper
    return SwipeNavigationWrapper(
      backRoute: '/home', // Swipe vers la droite = retour Home
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // 🎉 NOUVEAU : CommonAppBar au lieu de _buildAppBar(context)
            CommonAppBar(
              title: 'Sieste',
              structureName: structureName,
              iconPath: 'assets/images/Icone_Siestes.png',
              backRoute: '/home',
              primaryColor: primaryColor,
            ),

            // 🔄 GARDÉ IDENTIQUE : Tout votre contenu existant
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
      ),
    );
  }

// Nouveau layout pour iPad - affiche les enfants dans une grille
  Widget _buildTabletLayout() {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;

    // 🆕 4 colonnes en paysage pour beaucoup d'enfants
    final int crossAxisCount = isLandscape ? 4 : 2;

    // Ratio adapté pour 4 colonnes
    final double childAspectRatio = isLandscape ? 1.0 : 1.2;

    final double spacing = isLandscape ? 12.0 : 20.0;
    final double padding = isLandscape ? 16.0 : 16.0;

    return GridView.builder(
      padding: EdgeInsets.all(padding),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: enfants.length,
      itemBuilder: (context, index) =>
          _buildEnfantCardForTablet(context, index),
    );
  }

// Carte enfant adaptée pour iPad
  // Remplacer la méthode _buildEnfantCardForTablet par celle-ci
  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    String genre = enfant['genre']?.toString() ?? '';
    final Color avatarColor = (enfant['avatarColor'] as Color?) ??
        ChildAvatarColorHelper.defaultColorForGender(genre);

    return Container(
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: Colors.black87, // 🆕 NOIR
                      shadows: [
                        // 🆕 Ombre blanche pour lisibilité
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bouton d'ajout d'activité
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
                      onPressed: () => _guardAddSieste(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id']),
                      tooltip: "Ajouter une sieste",
                      padding: EdgeInsets.all(10),
                      constraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des siestes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid)
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('siestes')
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
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.nightlight_round,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Aucune sieste aujourd'hui",
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
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final siesteData = doc.data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => _showSiesteDetailsPopup(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id'],
                          doc.id,
                          siesteData),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: primaryColor.withOpacity(0.1)),
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
                                Icons.nightlight_round,
                                color: primaryColor,
                                size: 22,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        // Afficher l'état en cours si pas de fin
                                        ((siesteData['end'] == null) ||
                                                (siesteData['end']
                                                        ?.toString()
                                                        .isEmpty ??
                                                    true))
                                            ? 'En cours • Début ${siesteData['start'] ?? (siesteData['heure'] ?? '')}'
                                            : (siesteData['heure'] ?? ''),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    ((siesteData['end'] == null) ||
                                            (siesteData['end']
                                                    ?.toString()
                                                    .isEmpty ??
                                                true))
                                        ? 'Durée: en cours'
                                        : "Durée: ${siesteData['duration']}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: List.generate(
                                siesteData['moonCount'] ?? 0,
                                (index) => Icon(
                                  Icons.nightlight_round,
                                  color: primaryYellow,
                                  size: 18,
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

  // Navigation du bas
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle:
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
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
          label: "Accueil",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Echanges.png',
            width: 60,
            height: 60,
          ),
          label: "Messages",
        ),
      ],
    );
  }

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Siestes.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.nightlight_round,
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
}
