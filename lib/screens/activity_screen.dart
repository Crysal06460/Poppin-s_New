import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import '../widgets/date_selector.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';
import '../utils/structure_context.dart';
import '../utils/planning_helper.dart';
import '../utils/child_avatar_color_helper.dart';
import '../utils/absence_helper.dart';

class ActivityScreen extends StatefulWidget {
  final BuildContext context;

  const ActivityScreen({Key? key, required this.context}) : super(key: key);

  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _MaxWordInputFormatter extends TextInputFormatter {
  _MaxWordInputFormatter(this.maxWords);

  final int maxWords;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final trimmed = newValue.text.trim();
    final words = trimmed.isEmpty
        ? <String>[]
        : trimmed
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();

    if (words.length <= maxWords) {
      return newValue;
    }
    return oldValue;
  }
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  String structureId = "";
  DateTime _selectedDate = DateTime.now();
  int _selectedIndex = 1;
  TextEditingController _observationsController = TextEditingController();
  TextEditingController newActivityController = TextEditingController();

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  Color primaryColor = Color(0xFF3D9DF2);
  Color secondaryColor = Color(0xFFDFE9F2);

  String _activityType = "Musique";
  String _activityAttitude =
      "Curieux"; // ✅ CORRIGÉ : Plus de référence à _activityDuration
  String _participationLevel = "";
  String _activityTime = "";

  // Types d'activités standards et personnalisées
  List<String> standardActivityTypes = [
    "Musique",
    "Sport",
    "Dessin",
    "Lecture",
    "Jeux",
    "Danse",
    "Autre",
  ];

  List<String> customActivityTypes = [];

  // Combinaison des activités standards et personnalisées
  List<String> get activityTypes => [
        ...standardActivityTypes,
        ...customActivityTypes,
      ];

  // Liste des attitudes disponibles
  final List<String> attitudes = [
    "Curieux",
    "Attentif",
    "Hésitant",
    "Enjoué",
    "Autre",
  ];

  IconData _getAttitudeIcon(String attitude) {
    switch (attitude.toLowerCase()) {
      case 'curieux':
        return Icons.search;
      case 'attentif':
        return Icons.visibility;
      case 'hésitant':
        return Icons.help_outline;
      case 'enjoué':
        return Icons.sentiment_very_satisfied;
      case 'autre':
        return Icons.more_horiz;
      default:
        return Icons.sentiment_neutral;
    }
  }

  String _formatActivityLabel(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final words =
        trimmed.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.length <= 3) {
      return words.join(' ');
    }
    return '${words.take(3).join(' ')}...';
  }

  // Confirmation & suppression d'une activité
  void _confirmDeleteActivity(BuildContext dialogContext, String structureId,
      String childId, String activityId) {
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
                        'Supprimer cette activité ?',
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
                  'Cette action retirera l\'activité du journal, du récapitulatif et du fil des parents pour la journée.',
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
                                .collection('activites')
                                .doc(activityId)
                                .delete();

                            // Fermer la bottom sheet puis le dialog de détails
                            if (Navigator.of(ctx).canPop())
                              Navigator.of(ctx).pop();
                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Activité supprimée.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Erreur lors de la suppression de l\'activité.'),
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

  Future<void> _selectActivityTime(
    StateSetter setState,
    Function(String) onTimeSelected,
  ) async {
    // Obtenir l'heure actuelle ou celle déjà saisie
    TimeOfDay initialTime;
    if (_activityTime.isNotEmpty) {
      final parts = _activityTime.split(':');
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
              hourMinuteColor: MaterialStateColor.resolveWith(
                (states) => states.contains(MaterialState.selected)
                    ? primaryColor.withOpacity(0.15)
                    : Colors.transparent,
              ),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
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

  // Fonction pour charger les activités personnalisées
  Future<void> _loadCustomActivities() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (structureId.isEmpty) {
        await _loadStructureId();
      }

      final customActivitiesDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('settings')
          .doc('customActivityTypes')
          .get();

      if (customActivitiesDoc.exists) {
        final items = List<String>.from(
          customActivitiesDoc.data()?['items'] ?? [],
        );

        setState(() {
          customActivityTypes = items;
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des activités personnalisées: $e");
    }
  }

  // Fonction pour ajouter une activité personnalisée
  Future<bool> _addCustomActivity(String newActivity) async {
    final trimmed = newActivity.trim();
    if (trimmed.isEmpty) return false;

    final words =
        trimmed.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

    if (words.length > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum 3 mots pour une activité personnalisée.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final normalized = words.join(' ');

    try {
      if (structureId.isEmpty) {
        await _loadStructureId();
      }

      setState(() {
        if (!customActivityTypes.contains(normalized)) {
          customActivityTypes.add(normalized);
        }
      });

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('settings')
          .doc('customActivityTypes')
          .set({
        'items': customActivityTypes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activité ajoutée avec succès'),
            backgroundColor: primaryColor,
            duration: Duration(seconds: 2),
          ),
        );
      }

      return true;
    } catch (e) {
      print("Erreur lors de l'ajout d'une activité personnalisée: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'ajout de l'activité"),
          backgroundColor: Colors.red,
        ),
      );
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
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
                inputFormatters: [
                  _MaxWordInputFormatter(3),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '3 activités maximum',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showAddActivityPopup(childId);
              },
              child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newActivityController.text.trim().isNotEmpty) {
                  final added =
                      await _addCustomActivity(newActivityController.text);
                  if (added) {
                    Navigator.pop(dialogContext);
                    _showAddActivityPopup(childId);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('AJOUTER', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Fonction pour supprimer une activité personnalisée
  Future<void> _removeCustomActivity(String activity) async {
    try {
      setState(() {
        customActivityTypes.remove(activity);
      });

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
      final structureContext = await StructureResolver().resolve();
      structureId = structureContext.structureId;
      final String currentUserEmail = structureContext.currentUserEmail;
      final String structureType = structureContext.normalizedStructureType;
      final bool allowAllChildren = structureContext.showAllChildren;

      final today = _selectedDate;
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      setState(() {
        structureName = structureContext.structureName;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      List<Map<String, dynamic>> allChildren =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      List<Map<String, dynamic>> filteredChildren = [];

      Set<String> delegatedTodayChildIds = {};
      String? myMemberId;
      final bool useMamColors = structureType == 'mam';
      Map<String, Color> mamColorAssignments = {};
      if (structureType == 'mam') {
        if (allowAllChildren) {
          filteredChildren = List<Map<String, dynamic>>.from(allChildren);
          print(
            "👨‍👧‍👦 Activités: Membre MAM - affichage de tous les enfants de la structure",
          );
        } else {
          filteredChildren = allChildren.where((child) {
            String assignedEmail =
                child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
            return assignedEmail == currentUserEmail;
          }).toList();

          print(
            "👨‍👧‍👦 Activités: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)",
          );
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
            final now = _selectedDate;
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
                print(
                    '➕ Activités: ajout enfants délégués: ${toAddIds.length}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Activités: erreur overlay délégation: $e');
        }
      } else {
        filteredChildren = allChildren;
        print(
          "👩‍👧‍👦 Activités: Assistante Maternelle - affichage de tous les enfants",
        );
      }

      if (useMamColors) {
        mamColorAssignments =
            ChildAvatarColorHelper.buildMamAssignmentsFromChildren(
          filteredChildren,
        );
      }

      print(
        "🔍 DIAGNOSTIC ACTIVITÉS - Type de structure: $structureType, Utilisateur: $currentUserEmail",
      );
      print(
        "🔍 DIAGNOSTIC ACTIVITÉS - Nombre total d'enfants: ${allChildren.length}, Nombre filtrés: ${filteredChildren.length}",
      );

      final Set<String> absentChildIds =
          await AbsenceHelper.fetchAbsentChildIds(structureId, date: today);

      List<Map<String, dynamic>> tempEnfants = [];
      for (var child in filteredChildren) {
        if (absentChildIds.contains(child['id'])) {
          continue;
        }
        final isScheduledToday =
            PlanningHelper.isScheduledForDate(child, today);
        final isDelegatedToday = delegatedTodayChildIds.contains(child['id']);
        if (isScheduledToday || isDelegatedToday) {
          String? photoUrl = child['photoUrl'];
          final String assignedEmail = ChildAvatarColorHelper.normalizeEmail(
              child['assignedMemberEmail']);
          final Color avatarColor = ChildAvatarColorHelper.resolveAvatarColor(
            isMamStructure: useMamColors,
            mamAssignments: mamColorAssignments,
            assignedMemberEmail: assignedEmail,
            gender: child['gender']?.toString(),
          );
          tempEnfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'assignedMemberEmail': assignedEmail,
            'avatarColor': avatarColor,
            'structureId': structureId,
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
          child: Icon(
            _getActivityTypeIcon(type),
            color: primaryColor,
            size: 20,
          ),
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

  void _showActivityDetailsPopup(String structureId, String childId,
      String activityId, Map<String, dynamic> activityData) {
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
            constraints: BoxConstraints(maxWidth: 500, minWidth: 250),
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
                        colors: [primaryColor, primaryColor.withOpacity(0.85)],
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
                            _getActivityTypeIcon(activityData['type']),
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
                                "Activité de ${activityData['heure']}",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMMM yyyy', 'fr_FR')
                                    .format(activityData['date'].toDate())
                                    .toLowerCase(),
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bouton supprimer (même UX que repas)
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: () {
                            _confirmDeleteActivity(
                                context, structureId, childId, activityId);
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
                        // Type d'activité avec attitude
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _getActivityTypeIcon(activityData['type']),
                                color: primaryColor,
                                size: isTabletDevice ? 24 : 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _formatActivityLabel(
                                    activityData['type'],
                                  ),
                                  style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w500,
                                    color: primaryColor,
                                  ),
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                  textAlign: TextAlign.start,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(
                                _getAttitudeIcon(
                                    activityData['attitude'] ?? 'Curieux'),
                                color: primaryColor,
                                size: isTabletDevice ? 22 : 18,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Attitude: ${activityData['attitude'] ?? 'Non renseigné'}",
                                  style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Participation
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: lightBlue,
                            borderRadius: BorderRadius.circular(16),
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
                                          ? 4
                                          : 0,
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      color: primaryYellow,
                                      size: isTabletDevice ? 22 : 20,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                "${activityData['participation']}",
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
                        if (activityData['observations']?.isNotEmpty ??
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
                                  activityData['observations'],
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
                                  _showEditActivityPopup(structureId, childId,
                                      activityId, activityData);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  "MODIFIER",
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
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
                inputFormatters: [
                  _MaxWordInputFormatter(3),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '3 activités maximum',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newActivityController.text.trim().isNotEmpty) {
                  final added =
                      await _addCustomActivity(newActivityController.text);
                  if (added) {
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('AJOUTER', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

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
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: customActivityTypes.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              _formatActivityLabel(customActivityTypes[index]),
                              softWrap: true,
                              textAlign: TextAlign.start,
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _removeCustomActivity(
                                  customActivityTypes[index],
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('FERMER', style: TextStyle(color: Colors.grey)),
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
                  child: Text('AJOUTER', style: TextStyle(color: Colors.white)),
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
    String localActivityAttitude =
        _activityAttitude; // ✅ CORRIGÉ : Plus de confusion
    String localParticipationLevel = _participationLevel;
    String? errorMessage;

    List<String> organizedActivityTypes = [
      ...customActivityTypes,
      if (customActivityTypes.isNotEmpty) "_separator_",
      ...standardActivityTypes,
    ];

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
                      horizontal: MediaQuery.of(context).size.width * 0.25,
                    )
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
                              padding: EdgeInsets.all(
                                isTabletDevice ? 12 : 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.directions_run,
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
                                    "Ajouter une activité - ${enfant['prenom']}",
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
                        padding: EdgeInsets.all(
                          isTabletDevice ? 24 : 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Heure de l'activité
                            Container(
                              margin: EdgeInsets.only(
                                bottom: isTabletDevice ? 24 : 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Heure de l'activité",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  InkWell(
                                    onTap: () => _selectActivityTime(setState, (
                                      time,
                                    ) {
                                      localActivityTime = time;
                                      errorMessage = null;
                                    }),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: lightBlue,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: localActivityTime.isEmpty
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
                                            localActivityTime.isEmpty
                                                ? 'Choisir l\'heure'
                                                : localActivityTime,
                                            style: TextStyle(
                                              fontSize:
                                                  isTabletDevice ? 18 : 16,
                                              color: localActivityTime.isEmpty
                                                  ? Colors.grey.shade600
                                                  : primaryColor,
                                              fontWeight:
                                                  localActivityTime.isEmpty
                                                      ? FontWeight.normal
                                                      : FontWeight.w600,
                                            ),
                                          ),
                                          Icon(
                                            Icons.access_time_rounded,
                                            color: primaryColor.withOpacity(
                                              0.7,
                                            ),
                                            size: isTabletDevice ? 24 : 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Section Type d'activité
                            Container(
                              margin: EdgeInsets.only(
                                bottom: isTabletDevice ? 24 : 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Qu'elle était l'activité",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: lightBlue.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: DropdownButton<String>(
                                      value: (organizedActivityTypes.contains(
                                                localActivityType,
                                              ) &&
                                              localActivityType !=
                                                  "_separator_")
                                          ? localActivityType
                                          : standardActivityTypes.first,
                                      isExpanded: true,
                                      underline: Container(),
                                      iconSize: isTabletDevice ? 28 : 24,
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: primaryColor,
                                      ),
                                      items: organizedActivityTypes.map((
                                        String value,
                                      ) {
                                        if (value == "_separator_") {
                                          return DropdownMenuItem<String>(
                                            enabled: false,
                                            child: Container(
                                              height: 1,
                                              color: Colors.grey.shade300,
                                              margin: EdgeInsets.symmetric(
                                                vertical: 4,
                                              ),
                                            ),
                                          );
                                        } else if (customActivityTypes.contains(
                                          value,
                                        )) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: primaryColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.star,
                                                    color: primaryColor,
                                                    size: isTabletDevice
                                                        ? 20
                                                        : 16,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _formatActivityLabel(
                                                        value,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: isTabletDevice
                                                            ? 16
                                                            : 14,
                                                        color: primaryColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.visible,
                                                      textAlign:
                                                          TextAlign.start,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        } else {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                              child: Text(
                                                _formatActivityLabel(value),
                                                style: TextStyle(
                                                  fontSize:
                                                      isTabletDevice ? 16 : 14,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }).toList(),
                                      onChanged: (newValue) {
                                        if (newValue != null &&
                                            newValue != "_separator_") {
                                          setState(() {
                                            localActivityType = newValue;
                                          });
                                        }
                                      },
                                      dropdownColor: Colors.white,
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 16 : 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),

                                  // Bouton pour ajouter une activité personnalisée
                                  Padding(
                                    padding: EdgeInsets.only(top: 8, left: 8),
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showAddCustomActivityDialogFromActivityPopup(
                                          childId,
                                        );
                                      },
                                      icon: Icon(
                                        Icons.add_circle,
                                        color: primaryColor,
                                      ),
                                      label: Text(
                                        "Ajouter une activité personnalisée",
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w500,
                                          fontSize: isTabletDevice ? 15 : 14,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        alignment: Alignment.centerLeft,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Section Attitude de l'enfant
                            Container(
                              margin: EdgeInsets.only(
                                bottom: isTabletDevice ? 24 : 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Qu'elle était l'attitude ?",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: lightBlue.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: DropdownButton<String>(
                                      value: localActivityAttitude,
                                      isExpanded: true,
                                      underline: Container(),
                                      iconSize: isTabletDevice ? 28 : 24,
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: primaryColor,
                                      ),
                                      items: attitudes.map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _getAttitudeIcon(value),
                                                  color: primaryColor,
                                                  size:
                                                      isTabletDevice ? 20 : 18,
                                                ),
                                                SizedBox(width: 12),
                                                Text(
                                                  value,
                                                  style: TextStyle(
                                                    fontSize: isTabletDevice
                                                        ? 16
                                                        : 14,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        setState(() {
                                          localActivityAttitude = newValue!;
                                        });
                                      },
                                      dropdownColor: Colors.white,
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 16 : 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Section Participation
                            Container(
                              margin: EdgeInsets.only(
                                bottom: isTabletDevice ? 24 : 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Comment a participé ${enfant['prenom']} ?",
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
                                      _buildParticipationButtonModern(
                                        'Pas participé',
                                        localParticipationLevel,
                                        (value) {
                                          setState(() {
                                            localParticipationLevel = localParticipationLevel == value ? '' : value;
                                          });
                                        },
                                        isTabletDevice,
                                        Icons.sentiment_very_dissatisfied,
                                        primaryRed,
                                      ),
                                      _buildParticipationButtonModern(
                                        'Peu participé',
                                        localParticipationLevel,
                                        (value) {
                                          setState(() {
                                            localParticipationLevel = localParticipationLevel == value ? '' : value;
                                          });
                                        },
                                        isTabletDevice,
                                        Icons.sentiment_dissatisfied,
                                        Colors.amber,
                                      ),
                                      _buildParticipationButtonModern(
                                        'Bien participé',
                                        localParticipationLevel,
                                        (value) {
                                          setState(() {
                                            localParticipationLevel = localParticipationLevel == value ? '' : value;
                                          });
                                        },
                                        isTabletDevice,
                                        Icons.sentiment_satisfied,
                                        Colors.lime,
                                      ),
                                      _buildParticipationButtonModern(
                                        'Très bien participé',
                                        localParticipationLevel,
                                        (value) {
                                          setState(() {
                                            localParticipationLevel = localParticipationLevel == value ? '' : value;
                                          });
                                        },
                                        isTabletDevice,
                                        Icons.sentiment_very_satisfied,
                                        Colors.green,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Section Observations
                            Container(
                              margin: EdgeInsets.only(
                                bottom: isTabletDevice ? 24 : 16,
                              ),
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
                                        hintText:
                                            "Précisions sur l'activité...",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: primaryColor,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
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
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
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
                                      vertical: isTabletDevice ? 16 : 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
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

                                // Bouton Ajouter
                                ElevatedButton(
                                  onPressed: () async {
                                    if (localActivityTime.isEmpty) {
                                      setState(() {
                                        errorMessage =
                                            'Veuillez sélectionner une heure';
                                      });
                                      return;
                                    }

                                    setState(() {
                                      errorMessage = null;
                                    });

                                    _activityTime = localActivityTime;
                                    _activityType = localActivityType;
                                    _activityAttitude =
                                        localActivityAttitude; // ✅ CORRIGÉ
                                    _participationLevel =
                                        localParticipationLevel;

                                    _addActivityToFirebase(childId);

                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    elevation: 2,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTabletDevice ? 32 : 24,
                                      vertical: isTabletDevice ? 16 : 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    "AJOUTER",
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
      final String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
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
      print('Erreur vérification arrivée (activités): $e');
      return false;
    }
  }

  Future<void> _guardAddActivity(String structureId, String childId) async {
    final arrived = await _isChildArrivedToday(structureId, childId);
    if (!arrived) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Arrivée requise'),
          content: Text(
              "Attention : vous n\'avez pas indiqué l\'heure d\'arrivée.\n\nVeuillez indiquer l\'horaire d\'arrivée pour pouvoir ajouter une activité."),
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
    _showAddActivityPopup(childId);
  }

  void _showEditActivityPopup(String structureId, String childId,
      String activityId, Map<String, dynamic> activityData) {
    String localTime = (activityData['heure'] ?? '').toString();
    String localType = (activityData['type'] ?? 'Musique').toString();
    String localAttitude = (activityData['attitude'] ?? 'Curieux').toString();
    String localParticipation =
        (activityData['participation'] ?? '').toString();
    TextEditingController obsCtrl = TextEditingController(
        text: (activityData['observations'] ?? '').toString());

    // Liste organisée des types (perso + standard)
    List<String> organizedActivityTypes = [
      ...customActivityTypes,
      if (customActivityTypes.isNotEmpty) "_separator_",
      ...standardActivityTypes,
    ];

    final enfant = enfants.firstWhere((e) => e['id'] == childId,
        orElse: () => {'prenom': ''});
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
                      horizontal: MediaQuery.of(context).size.width * 0.25,
                    )
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
                      // En-tête
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
                              padding: EdgeInsets.all(
                                isTabletDevice ? 12 : 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getActivityTypeIcon(localType),
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
                                    "Modifier une activité - ${enfant['prenom']}",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 22 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Formulaire
                      Padding(
                        padding: EdgeInsets.all(
                          isTabletDevice ? 24 : 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Heure
                            Text("Heure de l'activité",
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 10),
                            InkWell(
                              onTap: () => _selectActivityTime(setState, (t) {
                                localTime = t;
                              }),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: lightBlue.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.grey.shade300, width: 1),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      localTime.isEmpty
                                          ? 'Choisir l\'heure'
                                          : localTime,
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 18 : 16,
                                        color: localTime.isEmpty
                                            ? Colors.grey.shade600
                                            : primaryColor,
                                        fontWeight: localTime.isEmpty
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    Icon(Icons.access_time_rounded,
                                        color: primaryColor),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 16),
                            // Type
                            Text("Qu'elle était l'activité",
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: lightBlue.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: (organizedActivityTypes
                                            .contains(localType) &&
                                        localType != "_separator_")
                                    ? localType
                                    : standardActivityTypes.first,
                                isExpanded: true,
                                underline: Container(),
                                icon: Icon(Icons.arrow_drop_down,
                                    color: primaryColor),
                                items:
                                    organizedActivityTypes.map((String value) {
                                  if (value == "_separator_") {
                                    return DropdownMenuItem<String>(
                                      enabled: false,
                                      value: value,
                                      child: Divider(),
                                    );
                                  }
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      _formatActivityLabel(value),
                                      softWrap: true,
                                      textAlign: TextAlign.start,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null && val != "_separator_") {
                                    setState(() => localType = val);
                                  }
                                },
                              ),
                            ),

                            SizedBox(height: 16),
                            // Attitude
                            Text("Quelle attitude ?",
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: lightBlue.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: attitudes.contains(localAttitude)
                                    ? localAttitude
                                    : attitudes.first,
                                isExpanded: true,
                                underline: Container(),
                                icon: Icon(Icons.arrow_drop_down,
                                    color: primaryColor),
                                items: attitudes
                                    .map((a) => DropdownMenuItem(
                                          value: a,
                                          child: Text(a),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => localAttitude = val);
                                },
                              ),
                            ),

                            SizedBox(height: 16),
                            // Participation
                            Text("Niveau de participation",
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildParticipationButtonModern(
                                  'Pas participé',
                                  localParticipation,
                                  (value) => setState(
                                      () => localParticipation = localParticipation == value ? '' : value),
                                  isTabletDevice,
                                  Icons.sentiment_very_dissatisfied,
                                  primaryRed,
                                ),
                                _buildParticipationButtonModern(
                                  'Peu participé',
                                  localParticipation,
                                  (value) => setState(
                                      () => localParticipation = localParticipation == value ? '' : value),
                                  isTabletDevice,
                                  Icons.sentiment_dissatisfied,
                                  Colors.amber,
                                ),
                                _buildParticipationButtonModern(
                                  'Bien participé',
                                  localParticipation,
                                  (value) => setState(
                                      () => localParticipation = localParticipation == value ? '' : value),
                                  isTabletDevice,
                                  Icons.sentiment_satisfied,
                                  Colors.lime,
                                ),
                                _buildParticipationButtonModern(
                                  'Très bien participé',
                                  localParticipation,
                                  (value) => setState(
                                      () => localParticipation = localParticipation == value ? '' : value),
                                  isTabletDevice,
                                  Icons.sentiment_very_satisfied,
                                  Colors.green,
                                ),
                              ],
                            ),

                            // Hint UX: participation optionnelle
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16, color: Colors.grey[500]),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "Optionnel — laissez vide si non évalué aujourd'hui.",
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 13 : 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 16),
                            // Observations
                            Text("Observations",
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 8),
                            TextField(
                              controller: obsCtrl,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Précisions sur l\'activité...',
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
                                      try {
                                        final docRef = FirebaseFirestore
                                            .instance
                                            .collection('structures')
                                            .doc(structureId)
                                            .collection('children')
                                            .doc(childId)
                                            .collection('activites')
                                            .doc(activityId);

                                        await docRef.update({
                                          'heure': localTime.isNotEmpty
                                              ? localTime
                                              : (activityData['heure'] ?? ''),
                                          'type': localType,
                                          'attitude': localAttitude,
                                          'participation': localParticipation,
                                          'participationLevel':
                                              _getParticipationLevel(
                                                  localParticipation),
                                          'observations': obsCtrl.text,
                                        });

                                        Navigator.of(context).pop();
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'Erreur lors de la mise à jour de l\'activité'),
                                          backgroundColor: Colors.red,
                                        ));
                                      }
                                    },
                                    child: Text('ENREGISTRER'),
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

  Widget _buildParticipationButtonModern(
    String level,
    String selectedLevel,
    Function(String) onSelect,
    bool isTablet,
    IconData icon,
    Color color,
  ) {
    bool isSelected = selectedLevel == level;

    Color backgroundColor;
    Color textColor;
    Color iconColor;

    if (isSelected) {
      if (level == "Bien participé") {
        backgroundColor = primaryColor.withOpacity(0.15);
        textColor = primaryColor;
        iconColor = primaryColor;
      } else if (level == "Très bien participé") {
        backgroundColor = primaryYellow.withOpacity(0.15);
        textColor = Colors.brown.shade700;
        iconColor = primaryYellow;
      } else if (level == "Pas participé") {
        backgroundColor = primaryRed.withOpacity(0.15);
        textColor = primaryRed;
        iconColor = primaryRed;
      } else {
        backgroundColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange.shade800;
        iconColor = Colors.orange;
      }
    } else {
      backgroundColor = Colors.grey.shade100;
      textColor = Colors.grey.shade700;
      iconColor = Colors.grey.shade400;
    }

    return GestureDetector(
      onTap: () => onSelect(level),
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
            Icon(icon, color: iconColor, size: isTablet ? 20 : 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                level,
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
        ), // Close Row
      ), // Close Container
    ); // Close GestureDetector
  }

  Future<void> _addActivityToFirebase(String childId) async {
    try {
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference activityRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('activites')
          .doc();

      int hour = DateTime.now().hour;
      int minute = DateTime.now().minute;
      if (_activityTime.contains(':')) {
        final list = _activityTime.split(':');
        if (list.length >= 2) {
          hour = int.tryParse(list[0]) ?? hour;
          minute = int.tryParse(list[1]) ?? minute;
        }
      }

      final activityData = {
        'heure': _activityTime,
        'date': DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          hour,
          minute,
        ),
        'type': _activityType,
        'attitude': _activityAttitude, // ✅ CORRIGÉ : Sauvegarde de l'attitude
        'participation': _participationLevel,
        'participationLevel': _getParticipationLevel(_participationLevel),
        'observations': _observationsController.text,
      };

      await activityRef.set(activityData);

      setState(() {
        _activityTime = '';
        _activityType = 'Musique';
        _activityAttitude = 'Curieux'; // ✅ CORRIGÉ : Réinitialisation attitude
        _participationLevel = '';
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
      context.go('/exchanges');
    }
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
                  onPressed: () => _guardAddActivity(
                      enfant['structureId'] ??
                          FirebaseAuth.instance.currentUser?.uid,
                      enfant['id']),
                ),
              ],
            ),
          ),
          // Liste des activités
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(
                  enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid,
                )
                .collection('children')
                .doc(enfant['id'])
                .collection('activites')
                .where(
                  'date',
                  isGreaterThanOrEqualTo: DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                  ),
                )
                .where(
                  'date',
                  isLessThan: DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                  ).add(Duration(days: 1)),
                )
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
                  final doc = snapshot.data!.docs[index];
                  final activityData = doc.data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showActivityDetailsPopup(
                        enfant['structureId'] ??
                            FirebaseAuth.instance.currentUser?.uid,
                        enfant['id'],
                        doc.id,
                        activityData),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.1),
                        ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Expanded(
                                      child: Text(
                                        _formatActivityLabel(
                                          activityData['type'],
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                        textAlign: TextAlign.start,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      _getAttitudeIcon(
                                          activityData['attitude'] ??
                                              'Curieux'),
                                      color: primaryColor,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "Attitude: ${activityData['attitude'] ?? 'Non renseigné'}", // ✅ CORRIGÉ
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
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
    final bool isTabletDevice = isTablet(context);

    return SwipeNavigationWrapper(
      backRoute: '/home',
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // 🎉 NOUVEAU : CommonAppBar au lieu de _buildAppBar(context)
            CommonAppBar(
              title: 'Activités',
              structureName: structureName,
              iconPath: 'assets/images/Icone_activite.png',
              backRoute: '/home',
              primaryColor: primaryColor,
            ),
            DateSelector(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                  isLoading = true;
                });
                _loadEnfantsDuJour();
              },
              primaryColor: primaryColor,
            ),
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
                          ? _buildTabletLayout()
                          : ListView.builder(
                              itemCount: enfants.length,
                              itemBuilder: _buildEnfantCard,
                            ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
        floatingActionButton: FloatingActionButton(
          onPressed: _showManageCustomActivitiesDialog,
          backgroundColor: primaryColor,
          child: Icon(Icons.playlist_add, color: Colors.white),
          tooltip: 'Gérer les activités personnalisées',
        ),
      ),
    );
  }

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

  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    String genre = enfant['genre']?.toString() ?? '';
    final Color avatarColor = (enfant['avatarColor'] as Color?) ??
        ChildAvatarColorHelper.defaultColorForGender(genre);

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
                      color: Colors.black87, // 🆕 NOIR au lieu de blanc
                      shadows: [
                        // 🆕 Ombre pour lisibilité sur fond coloré
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ),
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
                      onPressed: () => _guardAddActivity(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id']),
                      tooltip: "Ajouter une activité",
                      padding: EdgeInsets.all(10),
                      constraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(
                    enfant['structureId'] ??
                        FirebaseAuth.instance.currentUser?.uid,
                  )
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('activites')
                  .where(
                    'date',
                    isGreaterThanOrEqualTo: DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                    ),
                  )
                  .where(
                    'date',
                    isLessThan: DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                    ).add(Duration(days: 1)),
                  )
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
                            Icons.directions_run,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Aucune activité aujourd'hui",
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
                    final activityData = doc.data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => _showActivityDetailsPopup(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id'],
                          doc.id,
                          activityData),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.1),
                          ),
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
                                _getActivityTypeIcon(activityData['type']),
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
                                    _formatActivityLabel(activityData['type']),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    activityData['heure'] ?? 'Non renseignée',
                                    style: TextStyle(
                                      fontSize: 13,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_activité.png',
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
            'assets/images/Icone_dashboard.png',
            width: 60,
            height: 60,
          ),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_home.png',
            width: 60,
            height: 60,
          ),
          label: "Accueil",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_message.png',
            width: 60,
            height: 60,
          ),
          label: "Messages",
        ),
      ],
    );
  }
}
