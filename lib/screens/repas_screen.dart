import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';
import '../utils/structure_context.dart';
import '../utils/planning_helper.dart';
import '../utils/child_avatar_color_helper.dart';
import '../utils/absence_helper.dart';

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
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  // 🆕 AJOUTER CES CONSTANTES ICI
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double spacing = 16.0;
  static const double spacingLarge = 24.0;
  static const Color surfaceColor = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);

  String _selectedMoment = '';
  String _selectedAlimentationType = '';
  String _mealQuality = "Bien mangé";
  TextEditingController _observationsController = TextEditingController();
  TextEditingController _mlController = TextEditingController();
  TextEditingController _solideController = TextEditingController();
  TextEditingController _mixteController = TextEditingController();
  String _mealTime = "";
  Map<String, Color> _mamColorAssignments = {};
  bool _useMamColors = false;

  @override
  void dispose() {
    _observationsController.dispose();
    _mlController.dispose();
    _solideController.dispose();
    _mixteController.dispose();
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

      // Récupérer la structure pour déterminer le type (MAM ou AssistanteMaternelle)
      final String structureId = contextInfo.structureId;
      final String currentUserEmail = contextInfo.currentUserEmail;
      final String structureType = contextInfo.normalizedStructureType;
      final bool allowAllChildren = contextInfo.showAllChildren;
      final String normalizedCurrentEmail =
          ChildAvatarColorHelper.normalizeEmail(currentUserEmail);

      // Récupérer tous les enfants de la structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      allChildren = allChildren
          .map((child) => {
                ...child,
                'assignedMemberEmail': ChildAvatarColorHelper.normalizeEmail(
                    child['assignedMemberEmail']),
              })
          .toList();

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
              "👨‍👧‍👦 Repas: Membre MAM - affichage de tous les enfants de la structure");
        } else {
          filteredChildren = allChildren.where((child) {
            final String assignedEmail =
                child['assignedMemberEmail']?.toString() ?? '';
            return assignedEmail == normalizedCurrentEmail;
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

      final Set<String> absentChildIds =
          await AbsenceHelper.fetchAbsentChildIds(structureId, date: today);

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui,
      // et inclure ceux délégués aujourd'hui même si le planning n'est pas présent
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
            'assignedMemberEmail': assignedEmail,
            'age': ageText,
            'structureId':
                structureId, // Ajouter l'ID de structure pour les requêtes futures
            'birthdate': child['birthdate'],
          });
        }
      }

      if (useMamColors) {
        mamColorAssignments =
            ChildAvatarColorHelper.buildMamAssignmentsFromChildren(
          tempEnfants,
        );
      }

      setState(() {
        enfants = tempEnfants;
        _useMamColors = useMamColors && mamColorAssignments.isNotEmpty;
        _mamColorAssignments = mamColorAssignments;
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
        final String momentLabel =
            (mealData['moment'] ?? '').toString().trim().isEmpty
                ? (mealData['gouter'] == true ? 'Goûter' : '')
                : (mealData['moment'] ?? '').toString();
        final String rawType = (mealData['typeAlimentation'] ?? '').toString();
        final bool isBiberon =
            rawType == 'Biberon' || mealData['biberon'] == true;
        final bool isAllaitement =
            rawType == 'Allaitement' || mealData['allaitement'] == true;
        final bool isSolide = rawType == 'Solide';
        final bool isMixte = rawType == 'Mixte';
        final bool isGouterLegacy =
            mealData['gouter'] == true && rawType.isEmpty;
        final String typeLabel = rawType.isNotEmpty
            ? rawType
            : isBiberon
                ? 'Biberon'
                : isAllaitement
                    ? 'Allaitement'
                    : (isGouterLegacy ? 'Goûter' : 'Repas');
        final String description =
            (mealData['alimentationDescription'] ?? '').toString().trim();
        final String qualite = (mealData['qualite'] ?? '').toString();
        final int starCount = mealData['starCount'] is num
            ? (mealData['starCount'] as num).toInt()
            : 0;
        final IconData typeIcon = isBiberon
            ? Icons.local_drink_outlined
            : isAllaitement
                ? Icons.child_care_outlined
                : (isSolide || isMixte)
                    ? Icons.restaurant
                    : Icons.restaurant_menu;

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
                        if (momentLabel.isNotEmpty) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule,
                                    color: primaryBlue, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  momentLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                        ],
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isBiberon || isAllaitement
                                ? lightBlue
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                typeIcon,
                                color: primaryBlue,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      typeLabel,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: primaryBlue,
                                      ),
                                    ),
                                    if (isBiberon) ...[
                                      SizedBox(height: 6),
                                      Text(
                                        "${mealData['ml']?.toInt() ?? 0} ml",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ] else if (isAllaitement) ...[
                                      SizedBox(height: 6),
                                      Text(
                                        "Allaitement direct",
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ] else ...[
                                      if (starCount > 0)
                                        Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: Row(
                                            children: List.generate(
                                              starCount,
                                              (index) => Padding(
                                                padding: EdgeInsets.only(
                                                    right: index < starCount - 1
                                                        ? 4
                                                        : 0),
                                                child: Icon(
                                                  Icons.star,
                                                  color: primaryYellow,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (qualite.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: Text(
                                            qualite,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ),
                                      if (description.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: Text(
                                            description,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

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

  void _showAddMealPopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String localMealTime = _mealTime;
    String localMoment = _selectedMoment;
    String localType = _selectedAlimentationType;
    String localMealQuality = _mealQuality;

    _mlController.clear();
    _solideController.clear();
    _mixteController.clear();
    _observationsController.clear();

    final bool isTabletDevice = isTablet(context);

    final List<String> mealMoments = [
      'Petit déjeuner',
      'Repas du midi',
      'Goûter',
      'Repas du soir',
    ];

    final List<Map<String, dynamic>> alimentationOptions = [
      {'label': 'Biberon', 'icon': Icons.local_drink_outlined},
      {'label': 'Allaitement', 'icon': Icons.child_care_outlined},
      {'label': 'Solide', 'icon': Icons.restaurant},
      {'label': 'Mixte', 'icon': Icons.fastfood},
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            final bool isBiberon = localType == 'Biberon';
            final bool isAllaitement = localType == 'Allaitement';
            final bool isSolide = localType == 'Solide';
            final bool isMixte = localType == 'Mixte';
            final bool requiresQuality =
                localType.isNotEmpty && !isBiberon && !isAllaitement;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isTabletDevice
                    ? MediaQuery.of(context).size.width * 0.25
                    : 16,
                vertical: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(radiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🎨 HEADER MODERNE AVEC GRADIENT
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primaryBlue, primaryBlue.withOpacity(0.85)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(radiusLarge),
                          topRight: Radius.circular(radiusLarge),
                        ),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(radiusMedium),
                            ),
                            child: Icon(Icons.restaurant_rounded,
                                color: Colors.white, size: 28),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ajouter un repas',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  enfant['prenom'],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 📜 CONTENU SCROLLABLE
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(spacingLarge),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ⏰ SÉLECTEUR D'HEURE MODERNE
                            _buildSectionLabel('Heure du repas'),
                            SizedBox(height: 12),
                            InkWell(
                              onTap: () =>
                                  _selectMealTime(modalSetState, (time) {
                                localMealTime = time;
                              }),
                              borderRadius: BorderRadius.circular(radiusMedium),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(radiusMedium),
                                  border: Border.all(
                                    color: localMealTime.isEmpty
                                        ? Color(0xFFE5E7EB)
                                        : primaryBlue.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.access_time_rounded,
                                        color: primaryBlue,
                                        size: 22,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Text(
                                      localMealTime.isEmpty
                                          ? "Choisir l'heure"
                                          : localMealTime,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: localMealTime.isEmpty
                                            ? textSecondary
                                            : textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Spacer(),
                                    Icon(Icons.chevron_right_rounded,
                                        color: textSecondary),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: spacingLarge),

                            // 🍽️ MOMENT DU REPAS
                            _buildSectionLabel('Moment du repas'),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: mealMoments.map((moment) {
                                final bool selected = localMoment == moment;
                                return _buildModernChip(
                                  label: moment,
                                  isSelected: selected,
                                  icon: _getMomentIcon(moment),
                                  onTap: () {
                                    modalSetState(() {
                                      localMoment = moment;
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            SizedBox(height: spacingLarge),

                            // 🍼 TYPE D'ALIMENTATION
                            _buildSectionLabel("Type d'alimentation"),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: alimentationOptions.map((option) {
                                final String label = option['label'] as String;
                                final bool selected = localType == label;
                                return _buildModernChip(
                                  label: label,
                                  isSelected: selected,
                                  icon: option['icon'] as IconData,
                                  onTap: () {
                                    modalSetState(() {
                                      localType = label;
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            // 📊 CHAMPS CONDITIONNELS
                            if (isBiberon) ...[
                              SizedBox(height: spacingLarge),
                              _buildSectionLabel('Quantité (ml)'),
                              SizedBox(height: 8),
                              _buildModernTextField(
                                controller: _mlController,
                                hintText: 'Exemple: 150',
                                suffixText: 'ml',
                                keyboardType: TextInputType.number,
                              ),
                            ],

                            if (isSolide) ...[
                              SizedBox(height: spacingLarge),
                              _buildSectionLabel('Description du repas'),
                              SizedBox(height: 8),
                              _buildModernTextField(
                                controller: _solideController,
                                hintText: 'Décrivez le repas solide',
                              ),
                            ],

                            if (isMixte) ...[
                              SizedBox(height: spacingLarge),
                              _buildSectionLabel('Description du repas'),
                              SizedBox(height: 8),
                              _buildModernTextField(
                                controller: _mixteController,
                                hintText: 'Décrivez le repas mixte',
                              ),
                            ],

                            // 😊 QUALITÉ DU REPAS
                            if (requiresQuality) ...[
                              SizedBox(height: spacingLarge),
                              _buildSectionLabel(
                                  'Comment a mangé ${enfant['prenom']} ?'),
                              SizedBox(height: 16),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: isTabletDevice ? 2.5 : 2.3,
                                children: [
                                  _buildMealQualityButtonModern(
                                    'Pas mangé',
                                    localMealQuality,
                                    (value) {
                                      modalSetState(() {
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
                                      modalSetState(() {
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
                                      modalSetState(() {
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
                                      modalSetState(() {
                                        localMealQuality = value;
                                      });
                                    },
                                    isTabletDevice,
                                    Icons.sentiment_satisfied_alt,
                                    Colors.green,
                                  ),
                                ],
                              ),
                            ],

                            // 📝 OBSERVATIONS
                            SizedBox(height: spacingLarge),
                            _buildSectionLabel('Observations'),
                            SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(radiusMedium),
                                border: Border.all(
                                    color: Color(0xFFE5E7EB), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _observationsController,
                                maxLines: 4,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: textPrimary,
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ajouter un commentaire...',
                                  hintStyle: TextStyle(
                                    color: textSecondary,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 🎯 BOUTONS D'ACTION
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(radiusMedium),
                                  side: BorderSide(
                                      color: Color(0xFFE5E7EB), width: 1.5),
                                ),
                              ),
                              child: Text(
                                'ANNULER',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                // VALIDATION (garde ton code existant)
                                if (localMealTime.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          "Veuillez sélectionner l'heure du repas"),
                                      backgroundColor: primaryRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (localMoment.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          "Veuillez sélectionner le moment du repas"),
                                      backgroundColor: primaryRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (localType.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          "Veuillez sélectionner le type d'alimentation"),
                                      backgroundColor: primaryRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (isBiberon &&
                                    _mlController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          "Veuillez indiquer la quantité en ml"),
                                      backgroundColor: primaryRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  _mealTime = localMealTime;
                                  _selectedMoment = localMoment;
                                  _selectedAlimentationType = localType;
                                  _mealQuality = localMealQuality;
                                });

                                _addMealToFirebase(childId);
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shadowColor: primaryBlue.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(radiusMedium),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'AJOUTER',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
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
            );
          },
        );
      },
    );
  }
// 🎨 FONCTIONS HELPER POUR LE DESIGN MODERNE

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildModernChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusMedium),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: icon != null ? 12 : 16, // ✅ RÉDUIT de 16→12 et 20→16
              vertical: 12, // ✅ RÉDUIT de 14→12
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [primaryBlue, primaryBlue.withOpacity(0.85)],
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(radiusMedium),
              border: Border.all(
                color: isSelected ? Colors.transparent : Color(0xFFE5E7EB),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18, // ✅ RÉDUIT de 20→18
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                  SizedBox(width: 6), // ✅ RÉDUIT de 8→6
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14, // ✅ RÉDUIT de 15→14
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hintText,
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radiusMedium),
        border: Border.all(color: Color(0xFFE5E7EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: TextStyle(
          fontSize: 15,
          color: textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: textSecondary,
            fontSize: 15,
          ),
          suffixText: suffixText,
          suffixStyle: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }

  IconData _getMomentIcon(String moment) {
    switch (moment) {
      case 'Petit déjeuner':
        return Icons.wb_sunny_rounded;
      case 'Repas du midi':
        return Icons.light_mode_rounded;
      case 'Goûter':
        return Icons.cookie_rounded;
      case 'Repas du soir':
        return Icons.nightlight_round;
      default:
        return Icons.restaurant_rounded;
    }
  }

  // Popup d'édition d'un repas existant
  void _showEditMealPopup(String structureId, String childId, String mealId,
      Map<String, dynamic> mealData) {
    String localMealTime = (mealData['heure'] ?? '').toString();
    String localMoment = (mealData['moment'] ?? '').toString();
    if (localMoment.isEmpty && mealData['gouter'] == true) {
      localMoment = 'Goûter';
    }
    String localType = (mealData['typeAlimentation'] ?? '').toString();
    if (localType.isEmpty) {
      if (mealData['biberon'] == true) {
        localType = 'Biberon';
      } else if (mealData['allaitement'] == true) {
        localType = 'Allaitement';
      } else if (((mealData['alimentationDescription'] ?? '') as String)
          .toString()
          .isNotEmpty) {
        localType = 'Solide';
      } else if (mealData['gouter'] == true) {
        localType = 'Solide';
      }
    }
    String localMealQuality = (mealData['qualite'] ?? 'Bien mangé').toString();

    final TextEditingController obsCtrl = TextEditingController(
        text: (mealData['observations'] ?? '').toString());
    final TextEditingController mlCtrl = TextEditingController(
        text: (mealData['ml'] is num)
            ? (mealData['ml'] as num).toInt().toString()
            : (mealData['ml'] ?? '').toString());
    final TextEditingController solideCtrl = TextEditingController(
        text: localType == 'Solide'
            ? (mealData['alimentationDescription'] ?? '').toString()
            : '');
    final TextEditingController mixteCtrl = TextEditingController(
        text: localType == 'Mixte'
            ? (mealData['alimentationDescription'] ?? '').toString()
            : '');

    final bool isTabletDevice = isTablet(context);
    final enfant = enfants.firstWhere((e) => e['id'] == childId,
        orElse: () => {'prenom': ''});

    final List<String> mealMoments = [
      'Petit déjeuner',
      'Repas du midi',
      'Goûter',
      'Repas du soir',
    ];

    final List<Map<String, dynamic>> alimentationOptions = [
      {
        'label': 'Biberon',
        'icon': Icons.local_drink_outlined,
      },
      {
        'label': 'Allaitement',
        'icon': Icons.child_care_outlined,
      },
      {
        'label': 'Solide',
        'icon': Icons.restaurant,
      },
      {
        'label': 'Mixte',
        'icon': Icons.fastfood,
      },
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            final bool isBiberon = localType == 'Biberon';
            final bool isAllaitement = localType == 'Allaitement';
            final bool isSolide = localType == 'Solide';
            final bool isMixte = localType == 'Mixte';
            final bool requiresQuality =
                localType.isNotEmpty && !isBiberon && !isAllaitement;

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
                                    onTap: () => _selectMealTime(
                                      modalSetState,
                                      (t) => localMealTime = t,
                                    ),
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
                      Padding(
                        padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Moment du repas",
                              style: TextStyle(
                                fontSize: isTabletDevice ? 18 : 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: mealMoments.map((moment) {
                                final bool selected = localMoment == moment;
                                return ChoiceChip(
                                  label: Text(moment),
                                  selected: selected,
                                  onSelected: (_) {
                                    modalSetState(() {
                                      localMoment = moment;
                                    });
                                  },
                                  selectedColor: primaryBlue.withOpacity(0.15),
                                  backgroundColor: Colors.grey.shade200,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? primaryBlue
                                        : Colors.grey.shade700,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: selected
                                          ? primaryBlue
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            SizedBox(height: isTabletDevice ? 24 : 16),
                            Text(
                              "Type d'alimentation",
                              style: TextStyle(
                                fontSize: isTabletDevice ? 18 : 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: alimentationOptions.map((option) {
                                final String label = option['label'] as String;
                                final bool selected = localType == label;
                                return ChoiceChip(
                                  avatar: Icon(
                                    option['icon'] as IconData,
                                    size: isTabletDevice ? 20 : 18,
                                    color: selected
                                        ? primaryBlue
                                        : Colors.grey.shade600,
                                  ),
                                  label: Text(label),
                                  selected: selected,
                                  onSelected: (_) {
                                    modalSetState(() {
                                      localType = label;
                                    });
                                  },
                                  selectedColor: primaryBlue.withOpacity(0.15),
                                  backgroundColor: Colors.grey.shade200,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? primaryBlue
                                        : Colors.grey.shade700,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: selected
                                          ? primaryBlue
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (isBiberon) ...[
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ],
                            if (isSolide) ...[
                              SizedBox(height: 16),
                              Text(
                                "Repas solide",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  fontWeight: FontWeight.w500,
                                  color: primaryBlue,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: solideCtrl,
                                decoration: InputDecoration(
                                  hintText: "Décrivez le repas solide",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                            if (isMixte) ...[
                              SizedBox(height: 16),
                              Text(
                                "Repas mixte",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  fontWeight: FontWeight.w500,
                                  color: primaryBlue,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: mixteCtrl,
                                decoration: InputDecoration(
                                  hintText:
                                      "Décrivez le repas mixte (solide + liquide)",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                            if (requiresQuality) ...[
                              SizedBox(height: isTabletDevice ? 24 : 16),
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
                                childAspectRatio: isTabletDevice ? 2.5 : 2.3,
                                children: [
                                  _buildMealQualityButtonModern(
                                    'Pas mangé',
                                    localMealQuality,
                                    (value) {
                                      modalSetState(() {
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
                                      modalSetState(() {
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
                                      modalSetState(() {
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
                                      modalSetState(() {
                                        localMealQuality = value;
                                      });
                                    },
                                    isTabletDevice,
                                    Icons.sentiment_satisfied_alt,
                                    Colors.green,
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: isTabletDevice ? 24 : 16),
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
                                hintText: "Ajouter un commentaire...",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade200, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      BorderSide(color: primaryBlue, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isTabletDevice ? 24 : 16,
                                    vertical: isTabletDevice ? 16 : 12),
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
                            ElevatedButton(
                              onPressed: () async {
                                if (localMealTime.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "Veuillez sélectionner l'heure du repas",
                                      ),
                                      backgroundColor: primaryRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (localMoment.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "Veuillez sélectionner le moment du repas",
                                      ),
                                      backgroundColor: primaryRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (localType.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "Veuillez sélectionner le type d'alimentation",
                                      ),
                                      backgroundColor: primaryRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (isBiberon && mlCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "Veuillez indiquer la quantité en ml",
                                      ),
                                      backgroundColor: primaryRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  final docRef = FirebaseFirestore.instance
                                      .collection('structures')
                                      .doc(structureId)
                                      .collection('children')
                                      .doc(childId)
                                      .collection('repas')
                                      .doc(mealId);

                                  final Map<String, dynamic> update = {
                                    'heure': localMealTime,
                                    'moment': localMoment,
                                    'typeAlimentation': localType,
                                    'observations': obsCtrl.text.trim(),
                                    'biberon': isBiberon,
                                    'allaitement': isAllaitement,
                                    'gouter': localMoment == 'Goûter',
                                  };

                                  if (isBiberon) {
                                    update['ml'] =
                                        double.tryParse(mlCtrl.text.trim()) ??
                                            0;
                                    update['qualite'] = FieldValue.delete();
                                    update['starCount'] = FieldValue.delete();
                                    update['alimentationDescription'] =
                                        FieldValue.delete();
                                  } else if (isAllaitement) {
                                    update['ml'] = FieldValue.delete();
                                    update['qualite'] = FieldValue.delete();
                                    update['starCount'] = FieldValue.delete();
                                    update['alimentationDescription'] =
                                        FieldValue.delete();
                                  } else {
                                    update['ml'] = FieldValue.delete();
                                    if (isSolide) {
                                      final description =
                                          solideCtrl.text.trim();
                                      update['alimentationDescription'] =
                                          description.isNotEmpty
                                              ? description
                                              : FieldValue.delete();
                                    } else if (isMixte) {
                                      final description = mixteCtrl.text.trim();
                                      update['alimentationDescription'] =
                                          description.isNotEmpty
                                              ? description
                                              : FieldValue.delete();
                                    } else {
                                      update['alimentationDescription'] =
                                          FieldValue.delete();
                                    }

                                    update['qualite'] = localMealQuality;
                                    update['starCount'] =
                                        _getStarCountFromQuality(
                                            localMealQuality);
                                  }

                                  await docRef.update(update);
                                  Navigator.of(context).pop();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Erreur lors de la mise à jour du repas',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                padding: EdgeInsets.symmetric(
                                    horizontal: isTabletDevice ? 32 : 24,
                                    vertical: isTabletDevice ? 16 : 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                "ENREGISTRER",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      final DocumentReference mealRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('repas')
          .doc();

      final String mealType = _selectedAlimentationType;
      final bool isBiberon = mealType == 'Biberon';
      final bool isAllaitement = mealType == 'Allaitement';
      final bool isSolide = mealType == 'Solide';
      final bool isMixte = mealType == 'Mixte';

      final Map<String, dynamic> mealData = {
        'heure': _mealTime,
        'date': DateTime.now(),
        'moment': _selectedMoment,
        'typeAlimentation': mealType,
        'observations': _observationsController.text.trim(),
        'biberon': isBiberon,
        'allaitement': isAllaitement,
        'gouter': _selectedMoment == 'Goûter',
      };

      if (isBiberon) {
        mealData['ml'] = double.tryParse(_mlController.text.trim()) ?? 0;
      }

      if (isSolide) {
        final description = _solideController.text.trim();
        if (description.isNotEmpty) {
          mealData['alimentationDescription'] = description;
        }
      } else if (isMixte) {
        final description = _mixteController.text.trim();
        if (description.isNotEmpty) {
          mealData['alimentationDescription'] = description;
        }
      }

      if (!isBiberon && !isAllaitement) {
        mealData['qualite'] = _mealQuality;
        mealData['starCount'] = _getStarCountFromQuality(_mealQuality);
      }

      await mealRef.set(mealData);

      setState(() {
        _mealTime = '';
        _selectedMoment = '';
        _selectedAlimentationType = '';
        _mealQuality = "Bien mangé";
        _observationsController.clear();
        _mlController.clear();
        _solideController.clear();
        _mixteController.clear();
      });
    } catch (e) {
      print("Erreur lors de l'ajout du repas : $e");
    }
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    final String genre = enfant['genre']?.toString() ?? '';
    final String assignedEmail =
        ChildAvatarColorHelper.normalizeEmail(enfant['assignedMemberEmail']);
    final Color avatarColor = ChildAvatarColorHelper.resolveAvatarColor(
      isMamStructure: _useMamColors,
      mamAssignments: _mamColorAssignments,
      assignedMemberEmail: assignedEmail,
      gender: genre,
    );

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
                      colors: [
                        avatarColor.withOpacity(0.7),
                        avatarColor,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              enfant['photoUrl'],
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildInitialsFallback(
                                enfant['prenom'],
                                avatarColor,
                              ),
                            ),
                          )
                        : _buildInitialsFallback(
                            enfant['prenom'],
                            avatarColor,
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
                          color: Colors.black,
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
  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    final String genre = enfant['genre']?.toString() ?? '';
    final String assignedEmail =
        ChildAvatarColorHelper.normalizeEmail(enfant['assignedMemberEmail']);
    final Color avatarColor = ChildAvatarColorHelper.resolveAvatarColor(
      isMamStructure: _useMamColors,
      mamAssignments: _mamColorAssignments,
      assignedMemberEmail: assignedEmail,
      gender: genre,
    );
    final Color cardColor = avatarColor;

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
                      child: Center(
                        child: enfant['photoUrl'] != null &&
                                enfant['photoUrl'].isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  enfant['photoUrl'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildInitialsFallback(
                                    enfant['prenom'],
                                    cardColor,
                                  ),
                                ),
                              )
                            : _buildInitialsFallback(
                                enfant['prenom'],
                                cardColor,
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

                            final String momentLabel =
                                (mealData['moment'] ?? '').toString().trim();
                            final String rawType =
                                (mealData['typeAlimentation'] ?? '').toString();
                            final bool isBiberon = rawType == 'Biberon' ||
                                mealData['biberon'] == true;
                            final bool isAllaitement =
                                rawType == 'Allaitement' ||
                                    mealData['allaitement'] == true;
                            final bool isSolide = rawType == 'Solide';
                            final bool isMixte = rawType == 'Mixte';
                            final bool isGouterLegacy =
                                mealData['gouter'] == true && rawType.isEmpty;
                            final String typeLabel = rawType.isNotEmpty
                                ? rawType
                                : isBiberon
                                    ? 'Biberon'
                                    : isAllaitement
                                        ? 'Allaitement'
                                        : (isGouterLegacy ? 'Goûter' : 'Repas');
                            final String description =
                                (mealData['alimentationDescription'] ?? '')
                                    .toString()
                                    .trim();
                            final String qualite =
                                (mealData['qualite'] ?? '').toString();
                            final int starCount = mealData['starCount'] is num
                                ? (mealData['starCount'] as num).toInt()
                                : 0;

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
                                        borderRadius: BorderRadius.circular(8),
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                isBiberon
                                                    ? Icons.local_drink_outlined
                                                    : isAllaitement
                                                        ? Icons
                                                            .child_care_outlined
                                                        : (isSolide || isMixte)
                                                            ? Icons.restaurant
                                                            : Icons
                                                                .restaurant_menu,
                                                color: primaryBlue,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                typeLabel,
                                                style: TextStyle(
                                                  color: primaryBlue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (momentLabel.isNotEmpty) ...[
                                                SizedBox(width: 8),
                                                Text(
                                                  "• $momentLabel",
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          SizedBox(height: 6),
                                          Row(
                                            children: [
                                              if (isBiberon)
                                                Text(
                                                  "${mealData['ml']?.toInt() ?? 0} ml",
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                )
                                              else if (starCount > 0)
                                                Row(
                                                  children: List.generate(
                                                    starCount,
                                                    (index) => Icon(
                                                      Icons.star,
                                                      color: primaryYellow,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              if ((isSolide || isMixte) &&
                                                  description.isNotEmpty) ...[
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    description,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade700,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ] else if (!isBiberon &&
                                                  !isAllaitement &&
                                                  qualite.isNotEmpty) ...[
                                                if (starCount > 0)
                                                  SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    qualite,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade400,
                                      size: 16,
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

  Widget _buildInitialsFallback(String name, Color avatarColor) {
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      initial,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
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
