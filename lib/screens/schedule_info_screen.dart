import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ScheduleInfoScreen extends StatefulWidget {
  final String childId;

  const ScheduleInfoScreen({Key? key, required this.childId}) : super(key: key);

  @override
  _ScheduleInfoScreenState createState() => _ScheduleInfoScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

String structureName = "Chargement...";
bool isLoadingStructure = true;

class _ScheduleInfoScreenState extends State<ScheduleInfoScreen> {
  final List<String> weekDays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche'
  ];

  // Map pour stocker les segments horaires par jour
  final Map<String, List<TimeSegment>> daySegments = {};
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
    // Initialiser la structure avec des listes vides pour chaque jour
    for (var day in weekDays) {
      daySegments[day] = [];
    }
    initializeDateFormatting('fr_FR', null);
    // AJOUT : Charger les infos de structure
    _loadStructureInfo();
  }

  Future<void> _showTimePicker(
      BuildContext context, TimeSegment segment, bool isStart) async {
    // Obtenir l'heure actuelle ou celle déjà saisie
    final controller =
        isStart ? segment.startController : segment.endController;
    TimeOfDay initialTime;

    if (controller.text.isNotEmpty) {
      final parts = controller.text.split(':');
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
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _addTimeSegment(String day) {
    setState(() {
      daySegments[day]!.add(TimeSegment());
    });
  }

  void _removeTimeSegment(String day, int index) {
    setState(() {
      final segment = daySegments[day]![index];
      segment.startController.dispose();
      segment.endController.dispose();
      daySegments[day]!.removeAt(index);
    });
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
              "🔄 Schedule Info: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
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
      final double sideMargin = maxWidth * 0.03;
      final double columnGap = maxWidth * 0.025;

      return Padding(
        padding: EdgeInsets.fromLTRB(
            sideMargin, maxHeight * 0.02, sideMargin, maxHeight * 0.02),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panneau gauche - Aperçu des horaires
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
                              size: maxWidth * 0.025,
                            ),
                          ),
                          SizedBox(width: maxWidth * 0.015),
                          Expanded(
                            child: Text(
                              "Aperçu",
                              style: TextStyle(
                                fontSize: maxWidth * 0.022,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Aperçu des horaires sélectionnés
                      Expanded(
                        child: _buildSchedulePreviewTablet(maxWidth, maxHeight),
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
                  padding: EdgeInsets.all(maxWidth * 0.025),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre du formulaire
                      Text(
                        "Horaires de l'accueil",
                        style: TextStyle(
                          fontSize: maxWidth * 0.025,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      // Description
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(maxWidth * 0.02),
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
                              padding: EdgeInsets.all(maxWidth * 0.01),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: primaryBlue,
                                size: maxWidth * 0.02,
                              ),
                            ),
                            SizedBox(width: maxWidth * 0.015),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Veuillez renseigner les horaires",
                                    style: TextStyle(
                                      fontSize: maxWidth * 0.016,
                                      color: primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Pour les horaires coupés, ajoutez plusieurs créneaux par jour",
                                    style: TextStyle(
                                      fontSize: maxWidth * 0.014,
                                      color: primaryBlue.withOpacity(0.8),
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Liste des jours
                      Expanded(
                        child: ListView.builder(
                          itemCount: weekDays.length,
                          itemBuilder: (context, index) {
                            final day = weekDays[index];
                            return _buildDayCardTablet(
                                day, maxWidth, maxHeight);
                          },
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.03),

                      // Bouton Suivant
                      Center(
                        child: Container(
                          width: maxWidth * 0.25,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.arrow_forward,
                                color: Colors.white, size: maxWidth * 0.02),
                            label: Text(
                              "Suivant",
                              style: TextStyle(
                                fontSize: maxWidth * 0.02,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: _saveSchedule,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: maxWidth * 0.03,
                                  vertical: maxHeight * 0.02),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
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
              "Si vous quittez l'ajout de l'enfant maintenant, celui-ci ne sera pas ajouté et toutes les informations saisies seront perdues.\n\nÊtes-vous sûr de vouloir quitter ?",
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

  Widget _buildSchedulePreviewTablet(double maxWidth, double maxHeight) {
    // Compter le nombre total de créneaux
    int totalSlots = 0;
    List<String> activeDays = [];

    for (var day in weekDays) {
      final segments = daySegments[day] ?? [];
      if (segments.isNotEmpty) {
        totalSlots += segments.length;
        activeDays.add(day);
      }
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(maxWidth * 0.02),
      decoration: BoxDecoration(
        color:
            totalSlots > 0 ? lightBlue.withOpacity(0.3) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: totalSlots > 0
              ? primaryBlue.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec statistiques
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(maxWidth * 0.01),
                decoration: BoxDecoration(
                  color: totalSlots > 0 ? primaryBlue : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: maxWidth * 0.02,
                ),
              ),
              SizedBox(width: maxWidth * 0.015),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalSlots > 0 ? "Horaires configurés" : "Aucun horaire",
                      style: TextStyle(
                        fontSize: maxWidth * 0.016,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (totalSlots > 0)
                      Text(
                        "$totalSlots ${totalSlots == 1 ? 'créneau' : 'créneaux'} sur ${activeDays.length} jours",
                        style: TextStyle(
                          fontSize: maxWidth * 0.014,
                          color: primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: maxHeight * 0.03),

          // Liste des jours avec horaires
          Expanded(
            child: totalSlots > 0
                ? ListView.separated(
                    itemCount: activeDays.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: maxHeight * 0.015),
                    itemBuilder: (context, index) {
                      final day = activeDays[index];
                      final segments = daySegments[day] ?? [];

                      return Container(
                        padding: EdgeInsets.all(maxWidth * 0.015),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryBlue.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: maxWidth * 0.015,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                                Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: maxWidth * 0.008,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${segments.length}",
                                    style: TextStyle(
                                      fontSize: maxWidth * 0.012,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: maxHeight * 0.01),
                            ...segments.map((segment) {
                              final start = segment.startController.text;
                              final end = segment.endController.text;
                              if (start.isNotEmpty && end.isNotEmpty) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    "$start - $end",
                                    style: TextStyle(
                                      fontSize: maxWidth * 0.013,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              }
                              return SizedBox.shrink();
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(maxWidth * 0.02),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.schedule_outlined,
                            size: maxWidth * 0.04,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: maxHeight * 0.02),
                        Text(
                          "Aucun horaire configuré",
                          style: TextStyle(
                            fontSize: maxWidth * 0.016,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
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

  Widget _buildDayCardTablet(String day, double maxWidth, double maxHeight) {
    final segments = daySegments[day] ?? [];
    final bool hasSegments = segments.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: maxHeight * 0.02),
      decoration: BoxDecoration(
        color: hasSegments ? lightBlue.withOpacity(0.3) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSegments
              ? primaryBlue.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(maxWidth * 0.02),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: maxWidth * 0.018,
                        fontWeight:
                            hasSegments ? FontWeight.bold : FontWeight.w500,
                        color: hasSegments ? primaryBlue : Colors.black87,
                      ),
                    ),
                    if (hasSegments) ...[
                      SizedBox(width: maxWidth * 0.01),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: maxWidth * 0.008, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${segments.length} ${segments.length == 1 ? 'créneau' : 'créneaux'}",
                          style: TextStyle(
                            fontSize: maxWidth * 0.014,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton.icon(
                  icon: Icon(Icons.add, size: maxWidth * 0.02),
                  label: Text(
                    "Ajouter",
                    style: TextStyle(fontSize: maxWidth * 0.016),
                  ),
                  onPressed: () {
                    _addTimeSegment(day);
                    setState(() {}); // Rafraîchir l'aperçu
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: primaryBlue,
                    padding: EdgeInsets.symmetric(
                        horizontal: maxWidth * 0.015, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            if (hasSegments) ...[
              SizedBox(height: maxHeight * 0.02),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: segments.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: maxHeight * 0.015),
                itemBuilder: (context, segmentIndex) {
                  return _buildTimeSegmentRowTablet(day, segmentIndex,
                      segments[segmentIndex], maxWidth, maxHeight);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSegmentRowTablet(String day, int index, TimeSegment segment,
      double maxWidth, double maxHeight) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Arrivée",
                style: TextStyle(
                  color: primaryBlue,
                  fontSize: maxWidth * 0.014,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              InkWell(
                onTap: () {
                  _showTimePicker(context, segment, true);
                  // Delay pour permettre la mise à jour avant le rafraîchissement
                  Future.delayed(Duration(milliseconds: 100), () {
                    setState(() {});
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: maxWidth * 0.015,
                    vertical: maxHeight * 0.015,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        segment.startController.text.isEmpty
                            ? '--:--'
                            : segment.startController.text,
                        style: TextStyle(
                          fontSize: maxWidth * 0.016,
                          color: segment.startController.text.isEmpty
                              ? Colors.grey
                              : primaryBlue,
                          fontWeight: segment.startController.text.isEmpty
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.access_time,
                        color: primaryBlue,
                        size: maxWidth * 0.02,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: maxWidth * 0.015),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Départ",
                style: TextStyle(
                  color: primaryBlue,
                  fontSize: maxWidth * 0.014,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              InkWell(
                onTap: () {
                  _showTimePicker(context, segment, false);
                  // Delay pour permettre la mise à jour avant le rafraîchissement
                  Future.delayed(Duration(milliseconds: 100), () {
                    setState(() {});
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: maxWidth * 0.015,
                    vertical: maxHeight * 0.015,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        segment.endController.text.isEmpty
                            ? '--:--'
                            : segment.endController.text,
                        style: TextStyle(
                          fontSize: maxWidth * 0.016,
                          color: segment.endController.text.isEmpty
                              ? Colors.grey
                              : primaryBlue,
                          fontWeight: segment.endController.text.isEmpty
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.access_time,
                        color: primaryBlue,
                        size: maxWidth * 0.02,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: maxWidth * 0.01),
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: primaryRed,
            size: maxWidth * 0.02,
          ),
          onPressed: () {
            _removeTimeSegment(day, index);
            setState(() {}); // Rafraîchir l'aperçu
          },
        ),
      ],
    );
  }

  Widget _buildTimeSegmentRow(String day, int index, TimeSegment segment) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Heure d'arrivée",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              InkWell(
                onTap: () => _showTimePicker(context, segment, true),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        segment.startController.text.isEmpty
                            ? '--:--'
                            : segment.startController.text,
                        style: TextStyle(
                          fontSize: 16,
                          color: segment.startController.text.isEmpty
                              ? Colors.grey
                              : primaryBlue,
                          fontWeight: segment.startController.text.isEmpty
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.access_time, color: primaryBlue, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Heure de départ",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              InkWell(
                onTap: () => _showTimePicker(context, segment, false),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        segment.endController.text.isEmpty
                            ? '--:--'
                            : segment.endController.text,
                        style: TextStyle(
                          fontSize: 16,
                          color: segment.endController.text.isEmpty
                              ? Colors.grey
                              : primaryBlue,
                          fontWeight: segment.endController.text.isEmpty
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.access_time, color: primaryBlue, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: primaryRed),
          onPressed: () => _removeTimeSegment(day, index),
        ),
      ],
    );
  }

  Future<void> _saveSchedule() async {
    final schedule = {};

    // Parcourir tous les jours
    for (var day in weekDays) {
      final segments = daySegments[day];
      if (segments != null && segments.isNotEmpty) {
        List<Map<String, String>> timeSlots = [];

        // Vérifier chaque segment du jour
        for (var segment in segments) {
          final startTime = segment.startController.text;
          final endTime = segment.endController.text;

          if (startTime.isEmpty || endTime.isEmpty) {
            _showError("Veuillez renseigner tous les horaires pour $day");
            return;
          }

          timeSlots.add({'start': startTime, 'end': endTime});
        }

        if (timeSlots.isNotEmpty) {
          schedule[day] = timeSlots;
        }
      }
    }

    if (schedule.isEmpty) {
      _showError(
          "Veuillez sélectionner au moins un jour et définir des horaires");
      return;
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("Erreur : Utilisateur non connecté");
        return;
      }

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

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId au lieu de user.uid
          .collection('children')
          .doc(widget.childId)
          .update({'schedule': schedule});

      if (mounted) {
        context.go('/child-final-details',
            extra: {'childId': widget.childId, 'structureId': structureId});
      }
    } catch (e) {
      print("❌ Erreur Firestore: $e"); // Ajout de log pour le débogage
      _showError("Une erreur est survenue lors de la sauvegarde");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.all(16),
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

  // CORRECTION : Remplacer le bouton retour qui utilise Navigator.pop() dans le build()

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
            child: isTabletDevice
                ? _buildTabletLayout() // Layout spécifique pour iPad
                : Padding(
                    // Layout original pour iPhone
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            // CHANGEMENT : Utiliser context.go au lieu de Navigator.pop
                            if (widget.childId.isNotEmpty) {
                              print(
                                  "🔄 Retour vers add-second-parent avec childId: ${widget.childId}");
                              context.go('/add-second-parent',
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
                        const Text(
                          "Veuillez renseigner les horaires :",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Pour les horaires coupés, ajoutez plusieurs créneaux par jour",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: ListView.builder(
                            itemCount: weekDays.length,
                            itemBuilder: (context, index) {
                              final day = weekDays[index];
                              return _buildDayCard(day);
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildButton(
                          text: "Suivant",
                          icon: Icons.arrow_forward,
                          onPressed: _saveSchedule,
                          color: primaryBlue,
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

  Widget _buildDayCard(String day) {
    final segments = daySegments[day] ?? [];
    final bool hasSegments = segments.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: hasSegments ? lightBlue : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSegments
              ? primaryBlue.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: hasSegments
            ? [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            hasSegments ? FontWeight.bold : FontWeight.w500,
                        color: hasSegments ? primaryBlue : Colors.black87,
                      ),
                    ),
                    if (hasSegments) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${segments.length} ${segments.length == 1 ? 'créneau' : 'créneaux'}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text("Ajouter"),
                  onPressed: () => _addTimeSegment(day),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryBlue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            if (hasSegments) ...[
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: segments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, segmentIndex) {
                  return _buildTimeSegmentRow(
                      day, segmentIndex, segments[segmentIndex]);
                },
              ),
            ],
          ],
        ),
      ),
    );
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
                      Icons.schedule,
                      size: 26,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Horaires de l'accueil",
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
    return BottomNavigationBar(
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: primaryBlue,
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

  Widget _buildButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Libérer les contrôleurs
    for (var day in weekDays) {
      for (var segment in daySegments[day] ?? []) {
        segment.startController.dispose();
        segment.endController.dispose();
      }
    }
    super.dispose();
  }
}

class TimeSegment {
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
}
