import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';
import '../utils/structure_context.dart';
import '../utils/planning_helper.dart';

class RepasScreen extends StatefulWidget {
  const RepasScreen({Key? key}) : super(key: key);

  @override
  _RepasScreenState createState() => _RepasScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _RepasScreenState extends State<RepasScreen> {
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

  // Utiliser les couleurs officielles partout
  Color primaryColor = Color(0xFF3D9DF2); // primaryBlue par défaut
  Color secondaryColor = Color(0xFFDFE9F2); // lightBlue par défaut

  bool _isBiberon = false;
  bool _isAllaitement = false;
  String _mealQuality = "Bien mangé";
  TextEditingController _observationsController = TextEditingController();
  TextEditingController _mlController = TextEditingController();
  String _mealTime = "";

  @override
  void dispose() {
    _observationsController.dispose();
    _mlController.dispose();
    super.dispose();
  }

  // Confirmation & suppression d'un repas
  void _confirmDeleteMeal(BuildContext dialogContext, String structureId,
      String childId, String mealId) {
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
                        'Supprimer ce repas ?',
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
                  'Cette action retirera le repas du journal, du récapitulatif et du fil des parents pour la journée.',
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
                                .collection('repas')
                                .doc(mealId)
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
                                  content: Text('Repas supprimé.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Erreur lors de la suppression du repas.'),
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

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadStructureInfo();
    });
  }

  Future<void> _loadStructureInfo() async {
    try {
      final structureContext = await StructureResolver().resolve();

      setState(() {
        structureName = structureContext.structureName;
      });

      await _loadEnfantsDuJour(structureContext);
    } catch (e) {
      print("Erreur lors du chargement des infos de structure: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadEnfantsDuJour(StructureContext contextInfo) async {
    setState(() => isLoading = true);
    try {
      final today = DateTime.now();
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      // Récupérer la structure pour déterminer le type (MAM ou AssistanteMaternelle)
      final String structureId = contextInfo.structureId;
      final String currentUserEmail = contextInfo.currentUserEmail;
      final String structureType = contextInfo.normalizedStructureType;
      final bool allowAllChildren = contextInfo.showAllChildren;

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
      if (structureType == 'mam') {
        if (allowAllChildren) {
          filteredChildren = List<Map<String, dynamic>>.from(allChildren);
          print(
              "👨‍👧‍👦 Repas: Membre MAM - affichage de tous les enfants de la structure");
        } else {
          filteredChildren = allChildren.where((child) {
            String assignedEmail =
                child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
            return assignedEmail == currentUserEmail;
          }).toList();

          print(
              "👨‍👧‍👦 Repas: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
        }
        // ➕ Ajouter les enfants délégués aujourd'hui pour ce membre
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
                print('➕ Repas: ajout enfants délégués: ${toAddIds.length}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Repas: erreur overlay délégation: $e');
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Repas: Assistante Maternelle - affichage de tous les enfants");
      }

      // Diagnostic des enfants filtrés
      print(
          "🔍 DIAGNOSTIC REPAS - Type de structure: $structureType, Utilisateur: $currentUserEmail");
      print(
          "🔍 DIAGNOSTIC REPAS - Nombre total d'enfants: ${allChildren.length}, Nombre filtrés: ${filteredChildren.length}");

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui,
      // et inclure ceux délégués aujourd'hui même si le planning n'est pas présent
      List<Map<String, dynamic>> tempEnfants = [];
      for (var child in filteredChildren) {
        final isScheduledToday =
            PlanningHelper.isScheduledForDate(child, today);
        final isDelegatedToday = delegatedTodayChildIds.contains(child['id']);
        if (isScheduledToday || isDelegatedToday) {
          String? photoUrl = child['photoUrl'];
          // Récupérer la date de naissance pour calculer l'âge
          String ageText = "Âge inconnu";
          if (child['birthdate'] != null) {
            try {
              // Convertir le timestamp en DateTime
              DateTime birthDate;
              if (child['birthdate'] is Timestamp) {
                birthDate = (child['birthdate'] as Timestamp).toDate();
              } else if (child['birthdate'] is String) {
                birthDate = DateTime.parse(child['birthdate']);
              } else {
                throw FormatException("Format de date inconnu");
              }

              // Calculer l'âge
              DateTime now = DateTime.now();
              int years = now.year - birthDate.year;
              int months = now.month - birthDate.month;

              if (now.day < birthDate.day) {
                months--;
              }

              if (months < 0) {
                years--;
                months += 12;
              }

              // Formater l'âge
              if (years > 0) {
                ageText = "$years an${years > 1 ? 's' : ''}";
                if (months > 0) {
                  ageText += " et $months mois";
                }
              } else {
                ageText = "$months mois";
              }
            } catch (e) {
              print("Erreur lors du calcul de l'âge: $e");
              ageText = "Âge inconnu";
            }
          }

          tempEnfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'age': ageText,
            'structureId':
                structureId, // Ajouter l'ID de structure pour les requêtes futures
            'birthdate': child['birthdate'],
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

  Widget _buildBiberonIcon(double ml) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.local_drink_outlined, color: primaryBlue, size: 20),
        ),
        SizedBox(width: 8),
        Text(
          '${ml.toInt()} ML',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAllaitementIcon() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.child_care_outlined,
        color: primaryBlue,
        size: 20,
      ),
    );
  }

  void _showMealDetailsPopup(String structureId, String childId, String mealId,
      Map<String, dynamic> mealData) {
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
                          primaryBlue,
                          primaryBlue.withOpacity(0.85),
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
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Repas de ${mealData['heure']}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMMM yyyy', 'fr_FR')
                                    .format(mealData['date'].toDate())
                                    .toLowerCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bouton supprimer (UX 2025: action claire et accessible)
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: () {
                            _confirmDeleteMeal(
                                context, structureId, childId, mealId);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Contenu
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mealData['biberon']) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: lightBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.local_drink_outlined,
                                    color: primaryBlue, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Biberon',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: primaryBlue,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  "${mealData['ml']?.toInt() ?? 0} ML",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (mealData['allaitement']) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: lightBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.child_care_outlined,
                                    color: primaryBlue, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Allaitement',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Row(
                                  children: List.generate(
                                    mealData['starCount'] ?? 0,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(
                                        right: index <
                                                (mealData['starCount'] ?? 0) - 1
                                            ? 4
                                            : 0,
                                      ),
                                      child: Icon(
                                        Icons.star,
                                        color: primaryYellow,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "${mealData['qualite']}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Observations
                        if (mealData['observations']?.isNotEmpty ?? false) ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Observations",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "${mealData['observations']}",
                                  style: TextStyle(
                                    fontSize: 14,
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  "FERMER",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showEditMealPopup(
                                      structureId, childId, mealId, mealData);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  "MODIFIER",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
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

  Future<void> _selectMealTime(
      StateSetter setState, Function(String) onTimeSelected) async {
    // Obtenir l'heure actuelle ou celle déjà saisie
    TimeOfDay initialTime;
    if (_mealTime.isNotEmpty) {
      final parts = _mealTime.split(':');
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
              hourMinuteTextColor: primaryBlue,
              dayPeriodTextColor: primaryBlue,
              dialHandColor: primaryBlue,
              dialBackgroundColor: lightBlue.withOpacity(0.2),
              // Fix pour le rectangle bleu
              hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? primaryBlue.withOpacity(0.15)
                      : Colors.transparent),
              // Forme pour les conteneurs heure/minute
              hourMinuteShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
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

  // Popup d'édition d'un repas existant
  void _showEditMealPopup(String structureId, String childId, String mealId,
      Map<String, dynamic> mealData) {
    String localMealTime = (mealData['heure'] ?? '').toString();
    bool localIsBiberon = mealData['biberon'] == true;
    bool localIsAllaitement = mealData['allaitement'] == true;
    String localMealQuality = (mealData['qualite'] ?? 'Bien mangé').toString();
    String localMlText = (mealData['ml'] != null)
        ? (mealData['ml'] is num
            ? (mealData['ml'] as num).toInt().toString()
            : mealData['ml'].toString())
        : '';
    TextEditingController obsCtrl = TextEditingController(
        text: (mealData['observations'] ?? '').toString());
    TextEditingController mlCtrl = TextEditingController(text: localMlText);

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
                      horizontal: MediaQuery.of(context).size.width * 0.25)
                  : EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
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
                              primaryBlue,
                              primaryBlue.withOpacity(0.85)
                            ],
                          ),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24)),
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
                              child: Icon(Icons.restaurant,
                                  color: Colors.white,
                                  size: isTabletDevice ? 26 : 22),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Modifier un repas - ${enfant['prenom']}",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 20 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => _selectMealTime(setState, (t) {
                                      localMealTime = t;
                                    }),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.white24, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.access_time,
                                              size: 16, color: Colors.white),
                                          SizedBox(width: 6),
                                          Text(
                                            localMealTime.isEmpty
                                                ? (mealData['heure'] ?? '')
                                                : localMealTime,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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
                            // Type repas
                            Text(
                              "Type de repas",
                              style: TextStyle(
                                fontSize: isTabletDevice ? 18 : 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                ChoiceChip(
                                  selected: localIsBiberon,
                                  label: Text('Biberon'),
                                  onSelected: (sel) => setState(() {
                                    localIsBiberon = true;
                                    localIsAllaitement = false;
                                  }),
                                ),
                                SizedBox(width: 8),
                                ChoiceChip(
                                  selected: localIsAllaitement,
                                  label: Text('Allaitement'),
                                  onSelected: (sel) => setState(() {
                                    localIsAllaitement = true;
                                    localIsBiberon = false;
                                  }),
                                ),
                                SizedBox(width: 8),
                                ChoiceChip(
                                  selected:
                                      !localIsBiberon && !localIsAllaitement,
                                  label: Text('Repas'),
                                  onSelected: (sel) => setState(() {
                                    localIsBiberon = false;
                                    localIsAllaitement = false;
                                  }),
                                ),
                              ],
                            ),

                            // Quantité ML
                            if (localIsBiberon) ...[
                              SizedBox(height: 16),
                              Text(
                                "Quantité (ml)",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  fontWeight: FontWeight.w500,
                                  color: primaryBlue,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: mlCtrl,
                                decoration: InputDecoration(
                                  hintText: "Exemple: 150",
                                  suffixText: 'ml',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ],

                            // Qualité
                            if (!localIsBiberon && !localIsAllaitement) ...[
                              SizedBox(height: 16),
                              Text(
                                "Comment a mangé ${enfant['prenom']} ?",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildMealQualityButton(
                                      'Pas mangé',
                                      localMealQuality,
                                      (q) =>
                                          setState(() => localMealQuality = q)),
                                  _buildMealQualityButton(
                                      'Peu mangé',
                                      localMealQuality,
                                      (q) =>
                                          setState(() => localMealQuality = q)),
                                  _buildMealQualityButton(
                                      'Bien mangé',
                                      localMealQuality,
                                      (q) =>
                                          setState(() => localMealQuality = q)),
                                  _buildMealQualityButton(
                                      'Très bien mangé',
                                      localMealQuality,
                                      (q) =>
                                          setState(() => localMealQuality = q)),
                                ],
                              ),
                            ],

                            // Observations
                            SizedBox(height: 16),
                            Text(
                              "Observations",
                              style: TextStyle(
                                fontSize: isTabletDevice ? 18 : 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: obsCtrl,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Ajouter une note...',
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
                                            .collection('repas')
                                            .doc(mealId);

                                        Map<String, dynamic> update = {
                                          'heure': localMealTime.isNotEmpty
                                              ? localMealTime
                                              : (mealData['heure'] ?? ''),
                                          'observations': obsCtrl.text,
                                          'biberon': localIsBiberon,
                                          'allaitement': localIsAllaitement,
                                        };

                                        if (localIsBiberon) {
                                          update['ml'] =
                                              double.tryParse(mlCtrl.text) ?? 0;
                                          update.remove('qualite');
                                          update.remove('starCount');
                                        } else if (localIsAllaitement) {
                                          update.remove('qualite');
                                          update.remove('starCount');
                                          update.remove('ml');
                                        } else {
                                          update['qualite'] = localMealQuality;
                                          update['starCount'] =
                                              _getStarCountFromQuality(
                                                  localMealQuality);
                                          update.remove('ml');
                                        }

                                        await docRef.update(update);
                                        Navigator.of(context).pop();
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'Erreur lors de la mise à jour du repas'),
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

  void _showAddMealPopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String localMealTime = _mealTime;
    bool localIsBiberon = _isBiberon;
    bool localIsAllaitement = _isAllaitement;
    String localMealQuality = _mealQuality;
    _mlController.clear();

    // Déterminer si nous sommes sur iPad
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
              // Largeur adaptée pour iPad
              insetPadding: isTabletDevice
                  ? EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.25)
                  : EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                // Ajout d'un SingleChildScrollView englobant pour éviter le débordement
                child: Container(
                  padding: EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.15),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min, // Assure une taille minimale
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
                              primaryBlue,
                              primaryBlue.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isTabletDevice
                              ? 20
                              : 16, // Moins d'espace vertical sur les petits écrans
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTabletDevice
                                  ? 12
                                  : 10), // Plus petit sur les petits écrans
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.restaurant,
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
                                    "Ajouter un repas - ${enfant['prenom']}",
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
                        padding: EdgeInsets.all(isTabletDevice
                            ? 24
                            : 16), // Réduit sur les petits écrans
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min, // Assure une taille minimale
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Heure du repas
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice
                                      ? 24
                                      : 16), // Moins d'espace vertical
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Heure du repas",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  InkWell(
                                    onTap: () =>
                                        _selectMealTime(setState, (time) {
                                      localMealTime = time;
                                    }),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: lightBlue,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: localMealTime.isEmpty
                                              ? Colors.transparent
                                              : primaryBlue.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            localMealTime.isEmpty
                                                ? 'Choisir l\'heure'
                                                : localMealTime,
                                            style: TextStyle(
                                              fontSize:
                                                  isTabletDevice ? 18 : 16,
                                              color: localMealTime.isEmpty
                                                  ? Colors.grey.shade600
                                                  : primaryBlue,
                                              fontWeight: localMealTime.isEmpty
                                                  ? FontWeight.normal
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          Icon(
                                            Icons.access_time_rounded,
                                            color: primaryBlue.withOpacity(0.7),
                                            size: isTabletDevice ? 24 : 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Section Type de repas
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice
                                      ? 24
                                      : 16), // Moins d'espace vertical
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Type de repas",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),

                                  // Option Biberon
                                  Container(
                                    margin: EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: localIsBiberon
                                          ? primaryBlue.withOpacity(0.1)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: localIsBiberon
                                            ? primaryBlue
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      title: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: localIsBiberon
                                                  ? primaryBlue.withOpacity(0.2)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              Icons.local_drink_outlined,
                                              color: localIsBiberon
                                                  ? primaryBlue
                                                  : Colors.grey.shade500,
                                              size: isTabletDevice ? 24 : 20,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            "Biberon",
                                            style: TextStyle(
                                              fontSize:
                                                  isTabletDevice ? 18 : 16,
                                              fontWeight: FontWeight.w500,
                                              color: localIsBiberon
                                                  ? primaryBlue
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      value: localIsBiberon,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          localIsBiberon = value!;
                                          if (value) {
                                            localIsAllaitement = false;
                                          }
                                        });
                                      },
                                      activeColor: primaryBlue,
                                      checkColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.trailing,
                                    ),
                                  ),

                                  // Champ ML pour biberon
                                  if (localIsBiberon) ...[
                                    Container(
                                      margin: EdgeInsets.only(
                                          bottom: 16, left: 16, right: 16),
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: lightBlue.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Quantité (ml)",
                                            style: TextStyle(
                                              fontSize:
                                                  isTabletDevice ? 16 : 14,
                                              fontWeight: FontWeight.w500,
                                              color: primaryBlue,
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: TextField(
                                              controller: _mlController,
                                              decoration: InputDecoration(
                                                hintText: "Exemple: 150",
                                                hintStyle: TextStyle(
                                                    color:
                                                        Colors.grey.shade400),
                                                suffixText: "ml",
                                                suffixStyle: TextStyle(
                                                  color: primaryBlue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 16),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              style: TextStyle(
                                                fontSize:
                                                    isTabletDevice ? 18 : 16,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Option Allaitement (seulement si pas biberon)
                                  if (!localIsBiberon)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: localIsAllaitement
                                            ? primaryBlue.withOpacity(0.1)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: localIsAllaitement
                                              ? primaryBlue
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: CheckboxListTile(
                                        title: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: localIsAllaitement
                                                    ? primaryBlue
                                                        .withOpacity(0.2)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.child_care_outlined,
                                                color: localIsAllaitement
                                                    ? primaryBlue
                                                    : Colors.grey.shade500,
                                                size: isTabletDevice ? 24 : 20,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              "Allaitement",
                                              style: TextStyle(
                                                fontSize:
                                                    isTabletDevice ? 18 : 16,
                                                fontWeight: FontWeight.w500,
                                                color: localIsAllaitement
                                                    ? primaryBlue
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        value: localIsAllaitement,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            localIsAllaitement = value!;
                                            if (value) {
                                              localIsBiberon = false;
                                            }
                                          });
                                        },
                                        activeColor: primaryBlue,
                                        checkColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.trailing,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Section Qualité du repas (ni biberon ni allaitement)
                            if (!localIsBiberon && !localIsAllaitement) ...[
                              Container(
                                margin: EdgeInsets.only(
                                    bottom: isTabletDevice
                                        ? 24
                                        : 16), // Moins d'espace vertical
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Comment a mangé ${enfant['prenom']} ?",
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
                                      childAspectRatio: isTabletDevice
                                          ? 2.5
                                          : 2.3, // Ajustement pour les petits écrans
                                      children: [
                                        _buildMealQualityButtonModern(
                                          'Pas mangé',
                                          localMealQuality,
                                          (value) {
                                            setState(() {
                                              localMealQuality = value;
                                            });
                                          },
                                          isTabletDevice,
                                          Icons.sentiment_very_dissatisfied,
                                          primaryRed,
                                        ),
                                        _buildMealQualityButtonModern(
                                          'Peu mangé',
                                          localMealQuality,
                                          (value) {
                                            setState(() {
                                              localMealQuality = value;
                                            });
                                          },
                                          isTabletDevice,
                                          Icons.sentiment_dissatisfied,
                                          Colors.amber,
                                        ),
                                        _buildMealQualityButtonModern(
                                          'Bien mangé',
                                          localMealQuality,
                                          (value) {
                                            setState(() {
                                              localMealQuality = value;
                                            });
                                          },
                                          isTabletDevice,
                                          Icons.sentiment_satisfied,
                                          Colors.lime,
                                        ),
                                        _buildMealQualityButtonModern(
                                          'Très bien mangé',
                                          localMealQuality,
                                          (value) {
                                            setState(() {
                                              localMealQuality = value;
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
                            ],

                            // Section Observations
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice
                                      ? 24
                                      : 16), // Moins d'espace vertical
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
                                        hintText: "Précisions sur le repas...",
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
                                              color: primaryBlue, width: 2),
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

                                // Bouton Ajouter
                                ElevatedButton(
                                  onPressed: () {
                                    if (localIsBiberon &&
                                        _mlController.text.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Veuillez indiquer la quantité en ml'),
                                          backgroundColor: primaryRed,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    if (localMealTime.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Veuillez sélectionner l\'heure du repas'),
                                          backgroundColor: primaryRed,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    _mealQuality = localMealQuality;
                                    _isBiberon = localIsBiberon;
                                    _isAllaitement = localIsAllaitement;
                                    _mealTime = localMealTime;
                                    _addMealToFirebase(childId);
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryBlue,
                                    elevation: 2,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isTabletDevice ? 32 : 24,
                                        vertical: isTabletDevice ? 16 : 12),
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
      // Nouveau format avec segments
      if (ch['segments'] is List) {
        for (final seg in (ch['segments'] as List)) {
          final arr = seg['arrivee'];
          if (arr != null && arr.toString().isNotEmpty) return true;
        }
      }
      // Ancien format
      final arr = ch['arrivee'];
      if (arr != null && arr.toString().isNotEmpty) return true;
      return false;
    } catch (e) {
      print('Erreur vérification arrivée: $e');
      return false;
    }
  }

  Future<void> _guardAddMeal(String structureId, String childId) async {
    final arrived = await _isChildArrivedToday(structureId, childId);
    if (!arrived) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Arrivée requise'),
          content: Text(
              "Attention: vous n'avez pas indiqué l'heure d'arrivée pour cet enfant.\n\nVeuillez enregistrer l'heure d'arrivée pour pouvoir ajouter un repas."),
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
    _showAddMealPopup(childId);
  }

// Nouveau bouton de qualité du repas - version moderne
  Widget _buildMealQualityButtonModern(
    String quality,
    String selectedQuality,
    Function(String) onSelect,
    bool isTablet,
    IconData icon,
    Color color,
  ) {
    bool isSelected = selectedQuality == quality;

    // Utilisation des couleurs officielles de l'application avec opacité adaptée
    Color backgroundColor;
    Color textColor;
    Color iconColor;

    if (isSelected) {
      // Si le bouton est sélectionné
      if (quality == "Bien mangé") {
        // Pour "Bien mangé", utiliser primaryBlue avec opacité
        backgroundColor = primaryBlue.withOpacity(0.15);
        textColor = primaryBlue;
        iconColor = primaryBlue;
      } else if (quality == "Très bien mangé") {
        // Pour "Très bien mangé", utiliser primaryYellow avec opacité
        backgroundColor = primaryYellow.withOpacity(0.15);
        textColor = Colors.brown.shade700;
        iconColor = primaryYellow;
      } else if (quality == "Pas mangé") {
        // Pour "Pas mangé", utiliser primaryRed avec opacité
        backgroundColor = primaryRed.withOpacity(0.15);
        textColor = primaryRed;
        iconColor = primaryRed;
      } else {
        // Pour "Peu mangé", utiliser orange avec opacité
        backgroundColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange.shade800;
        iconColor = Colors.orange;
      }
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
            Icon(
              icon,
              color: iconColor,
              size: isTablet ? 20 : 18,
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

  Widget _buildMealQualityButton(
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
              isSelected ? primaryBlue.withOpacity(0.1) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          quality,
          style: TextStyle(
            color: isSelected ? primaryBlue : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  int _getStarCountFromQuality(String quality) {
    switch (quality) {
      case 'Pas mangé':
        return 1;
      case 'Peu mangé':
        return 2;
      case 'Bien mangé':
        return 3;
      case 'Très bien mangé':
        return 4;
      default:
        return 0;
    }
  }

  Future<void> _addMealToFirebase(String childId) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference mealRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser l'ID de structure correct
          .collection('children')
          .doc(childId)
          .collection('repas')
          .doc();

      final mealData = {
        'heure': _mealTime,
        'date': DateTime.now(),
        'observations': _observationsController.text,
        'biberon': _isBiberon,
        'allaitement': _isAllaitement,
      };

      if (_isBiberon) {
        mealData['ml'] = double.tryParse(_mlController.text) ?? 0;
      } else if (!_isAllaitement) {
        mealData['qualite'] = _mealQuality;
        mealData['starCount'] = _getStarCountFromQuality(_mealQuality);
      }

      await mealRef.set(mealData);

      // Réinitialisation des champs
      setState(() {
        _mealTime = '';
        _isBiberon = false;
        _isAllaitement = false;
        _mealQuality = "Bien mangé";
        _observationsController.clear();
        _mlController.clear();
      });

      print("Repas ajouté avec succès !");
    } catch (e) {
      print("Erreur lors de l'ajout du repas : $e");
    }
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    bool isBoy = enfant['genre'] == 'Garçon';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête de la carte
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar de l'enfant
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isBoy
                          ? [primaryBlue.withOpacity(0.7), primaryBlue]
                          : [primaryRed.withOpacity(0.7), primaryRed],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isBoy ? primaryBlue : primaryRed).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? Image.network(
                            enfant['photoUrl'],
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              enfant['prenom'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16),
                // Nom de l'enfant
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enfant['prenom'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isBoy ? primaryBlue : primaryRed,
                        ),
                      ),
                      SizedBox(height: 4),
                    ],
                  ),
                ),
                // Bouton d'ajout
                Container(
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: primaryBlue, size: 24),
                    onPressed: () => _guardAddMeal(
                        enfant['structureId'] ??
                            FirebaseAuth.instance.currentUser?.uid,
                        enfant['id']),
                    tooltip: "Ajouter un repas",
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant, size: 16, color: primaryBlue),
                      SizedBox(width: 4),
                      Text(
                        "Repas: ",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryBlue,
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('structures')
                            .doc(enfant['structureId'] ??
                                FirebaseAuth.instance.currentUser?.uid)
                            .collection('children')
                            .doc(enfant['id'])
                            .collection('repas')
                            .where('date',
                                isGreaterThanOrEqualTo: DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day))
                            .where('date',
                                isLessThan: DateTime(
                                        DateTime.now().year,
                                        DateTime.now().month,
                                        DateTime.now().day)
                                    .add(Duration(days: 1)))
                            .snapshots(),
                        builder: (context, snapshot) {
                          int repasCount =
                              snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return Text(
                            "$repasCount",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Liste des repas
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('repas')
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
              if (!snapshot.hasData) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      "Chargement des repas...",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      "Aucun repas aujourd'hui",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: snapshot.data!.docs.map((doc) {
                    final mealData = doc.data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => _showMealDetailsPopup(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id'],
                          doc.id,
                          mealData),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                mealData['heure'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            if (mealData['biberon'])
                              _buildBiberonIcon(mealData['ml']?.toDouble() ?? 0)
                            else if (mealData['allaitement'])
                              _buildAllaitementIcon()
                            else
                              Row(
                                children: List.generate(
                                  mealData['starCount'] ?? 0,
                                  (index) => Padding(
                                    padding: EdgeInsets.only(right: 2),
                                    child: Icon(
                                      Icons.star,
                                      color: primaryYellow,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(width: 8),
                            if (mealData['qualite'] != null)
                              Text(
                                mealData['qualite'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            Spacer(),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
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

    // 🆕 AJOUT : Entourer avec SwipeNavigationWrapper
    return SwipeNavigationWrapper(
      backRoute: '/home', // Swipe vers la droite = retour Home
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // 🆕 REMPLACEMENT : CommonAppBar au lieu de _buildAppBar(context)
            CommonAppBar(
              title: 'Repas',
              structureName: structureName,
              iconPath: 'assets/images/Icone_Repas.png',
              backRoute: '/home',
              primaryColor: primaryBlue,
            ),

            // 🔄 GARDÉ IDENTIQUE : Tout votre contenu existant
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
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
    bool isBoy = enfant['genre'] == 'Garçon';
    Color cardColor = isBoy ? primaryBlue : primaryRed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 3),
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
                colors: [cardColor, cardColor.withOpacity(0.85)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar avec badge
                Stack(
                  children: [
                    // Photo de l'enfant
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: enfant['photoUrl'] != null &&
                                enfant['photoUrl'].isNotEmpty
                            ? Image.network(
                                enfant['photoUrl'],
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                  child: Text(
                                    enfant['prenom'][0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  enfant['prenom'][0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                // Informations de l'enfant
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enfant['prenom'],
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bouton d'ajout
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
                      icon: Icon(Icons.add, color: cardColor, size: 24),
                      onPressed: () => _guardAddMeal(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id']),
                      tooltip: "Ajouter un repas",
                      padding: EdgeInsets.all(10),
                      constraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenu de la carte
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // La section "Stats du jour" a été supprimée

                  // Liste des repas (directement, sans SizedBox)
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('structures')
                          .doc(enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid)
                          .collection('children')
                          .doc(enfant['id'])
                          .collection('repas')
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
                        if (!snapshot.hasData) {
                          return Center(
                            child: Text(
                              "Chargement des repas...",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          );
                        }

                        if (snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "Aucun repas aujourd'hui",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, idx) {
                            final doc = snapshot.data!.docs[idx];
                            final mealData = doc.data() as Map<String, dynamic>;

                            // Repas avec biberon
                            if (mealData['biberon'] == true) {
                              return GestureDetector(
                                onTap: () => _showMealDetailsPopup(
                                    enfant['structureId'] ??
                                        FirebaseAuth.instance.currentUser?.uid,
                                    enfant['id'],
                                    doc.id,
                                    mealData),
                                child: Container(
                                  margin: EdgeInsets.only(bottom: 10),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          mealData['heure'] ?? "08:30",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primaryBlue,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Row(
                                        children: [
                                          Icon(Icons.local_drink_outlined,
                                              color: primaryBlue, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            "${mealData['ml']?.toInt() ?? 0} ML",
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey.shade400,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            // Repas normal (avec qualité)
                            else {
                              return GestureDetector(
                                onTap: () => _showMealDetailsPopup(
                                    enfant['structureId'] ??
                                        FirebaseAuth.instance.currentUser?.uid,
                                    enfant['id'],
                                    doc.id,
                                    mealData),
                                child: Container(
                                  margin: EdgeInsets.only(bottom: 10),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          mealData['heure'] ?? "12:15",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primaryBlue,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Row(
                                        children: [
                                          Row(
                                            children: List.generate(
                                              mealData['starCount'] ?? 3,
                                              (index) => Icon(
                                                Icons.star,
                                                color: primaryYellow,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            mealData['qualite'] ?? "Bien mangé",
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey.shade400,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
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
      selectedItemColor: primaryBlue,
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
            'assets/images/Icone_Repas.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.restaurant,
              size: 80,
              color: primaryBlue.withOpacity(0.4),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Aucun enfant prévu aujourd\'hui',
            style: TextStyle(
              fontSize: 18,
              color: primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
