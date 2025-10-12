// edit_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class EditScheduleScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final Map<String, dynamic> currentSchedule;

  const EditScheduleScreen({
    Key? key,
    required this.childId,
    required this.childName,
    required this.currentSchedule,
  }) : super(key: key);

  @override
  _EditScheduleScreenState createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  final List<String> allWeekDays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche'
  ];

  // Structure de données pour stocker les jours sélectionnés et leurs segments horaires
  Map<String, List<TimeSegment>> scheduleByDay = {};
  bool isLoading = false;

  // Ajouter cette variable pour stocker l'ID de structure
  String structureId = '';

  // Définition des couleurs de la palette
  static const Color primaryColor = Color(0xFF3D9DF2); // Bleu #3D9DF2
  static const Color secondaryColor = Color(0xFFDFE9F2); // Bleu clair #DFE9F2

  @override
  void initState() {
    super.initState();
    _getUserStructureId(); // Récupérer l'ID de structure
    _initializeSchedule();
  }

  // Nouvelle méthode pour récupérer l'ID de structure de l'utilisateur connecté
  Future<void> _getUserStructureId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Par défaut, l'ID de structure est l'ID de l'utilisateur
      structureId = user.uid;

      // Vérifier si l'utilisateur est un membre MAM
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "🔄 EditSchedule: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération de l'ID de structure: $e");
    }
  }

  void _initializeSchedule() {
    print("=============== INITIALIZING SCHEDULE ===============");
    print("Current Schedule Type: ${widget.currentSchedule.runtimeType}");
    print("Current Schedule from Firestore: ${widget.currentSchedule}");

    // Initialiser scheduleByDay avec des listes vides pour chaque jour
    scheduleByDay = {};
    for (var day in allWeekDays) {
      scheduleByDay[day] = [];
    }

    // Remplir scheduleByDay avec les données existantes
    widget.currentSchedule.forEach((day, value) {
      print("Processing day: $day, value type: ${value.runtimeType}");

      if (allWeekDays.contains(day)) {
        // Cas 1: Le format est déjà une liste de segments
        if (value is List) {
          print("Value is a List. Length: ${value.length}");
          List<TimeSegment> segments = [];

          for (var segmentData in value) {
            if (segmentData is Map<String, dynamic>) {
              TimeSegment segment = TimeSegment();

              // Obtenir les valeurs start/end ou arrival/departure
              String? startTime =
                  segmentData['start'] ?? segmentData['arrival'];
              String? endTime = segmentData['end'] ?? segmentData['departure'];

              if (startTime != null && endTime != null) {
                segment.startController.text = startTime;
                segment.endController.text = endTime;
                segments.add(segment);
                print("Added segment: $startTime - $endTime");
              }
            }
          }

          if (segments.isNotEmpty) {
            scheduleByDay[day] = segments;
          }
        }
        // Cas 2: Ancien format avec un seul segment
        else if (value is Map<String, dynamic>) {
          print("Value is a Map: $value");
          String? startTime;
          String? endTime;

          // Extraire l'horaire avec différents formats possibles
          if (value.containsKey('start') && value.containsKey('end')) {
            startTime = value['start'];
            endTime = value['end'];
          } else if (value.containsKey('arrival') &&
              value.containsKey('departure')) {
            startTime = value['arrival'];
            endTime = value['departure'];
          }

          if (startTime != null && endTime != null) {
            TimeSegment segment = TimeSegment();
            segment.startController.text = startTime;
            segment.endController.text = endTime;
            scheduleByDay[day] = [segment];
            print("Added single segment for $day: $startTime - $endTime");
          }
        }
      }
    });

    print("Final initialized schedule:");
    scheduleByDay.forEach((day, segments) {
      print("$day: ${segments.length} segments");
    });
    print("=============== END OF INITIALIZATION ===============");
  }

  void _addSegmentToDay(String day) {
    setState(() {
      scheduleByDay[day]!.add(TimeSegment());
    });
  }

  void _removeSegment(String day, int index) {
    setState(() {
      final segments = scheduleByDay[day]!;
      if (index < segments.length) {
        final segment = segments[index];
        segment.startController.dispose();
        segment.endController.dispose();
        segments.removeAt(index);
      }
    });
  }

  void _showAddDayDialog() {
    // Déterminer les jours qui n'ont pas encore de segments
    final availableDays = allWeekDays.where((day) {
      return scheduleByDay[day]!.isEmpty;
    }).toList();

    if (availableDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tous les jours sont déjà ajoutés'),
          backgroundColor: primaryColor,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Ajouter un jour',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Container(
          width: double.minPositive,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableDays
                .map((day) => ListTile(
                      title: Text(day),
                      onTap: () {
                        setState(() {
                          _addSegmentToDay(day);
                        });
                        Navigator.pop(context);
                      },
                      trailing:
                          Icon(Icons.add_circle_outline, color: primaryColor),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(String day, int segmentIndex, bool isStart) async {
    if (scheduleByDay[day] == null ||
        segmentIndex >= scheduleByDay[day]!.length) {
      return;
    }

    final segment = scheduleByDay[day]![segmentIndex];
    final controller =
        isStart ? segment.startController : segment.endController;

    // Obtenir l'heure actuelle ou celle déjà saisie
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
              hourMinuteTextColor: primaryColor,
              dayPeriodTextColor: primaryColor,
              dialHandColor: primaryColor,
              dialBackgroundColor: secondaryColor.withOpacity(0.2),
              // Fix for the blue rectangle
              hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? primaryColor.withOpacity(0.15)
                      : Colors.transparent),
              // Add shape for hour/minute containers
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
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  // Méthode modifiée pour utiliser l'ID de structure correct
  Future<void> _saveSchedule() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Si l'ID de structure n'est pas encore récupéré, attendre un peu et réessayer
      if (structureId.isEmpty) {
        await _getUserStructureId();
        // Si toujours vide, utiliser l'ID utilisateur par défaut
        if (structureId.isEmpty) {
          structureId = user.uid;
        }
      }

      // Convertir les données pour Firestore
      Map<String, List<Map<String, String>>> formattedSchedule = {};

      // Pour chaque jour qui a des segments
      for (String day in allWeekDays) {
        final segments = scheduleByDay[day]!;
        if (segments.isNotEmpty) {
          List<Map<String, String>> daySegments = [];

          for (var segment in segments) {
            final startTime = segment.startController.text;
            final endTime = segment.endController.text;

            if (startTime.isEmpty || endTime.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Veuillez compléter tous les horaires pour $day'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() => isLoading = false);
              return;
            }

            daySegments.add({
              'start': startTime,
              'end': endTime,
            });
          }

          formattedSchedule[day] = daySegments;
        }
      }

      // Utiliser l'ID de structure récupéré au lieu de user.uid
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Ici, utiliser structureId au lieu de user.uid
          .collection('children')
          .doc(widget.childId)
          .update({'schedule': formattedSchedule});

      print(
          "✅ Horaires enregistrés avec succès pour l'enfant ${widget.childId} de la structure $structureId");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Horaires enregistrés avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error saving schedule: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde des horaires'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête avec fond de couleur - Identique à StructureManagementScreen
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    // Bouton retour avec meilleur contraste
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Titre avec meilleur style
                    Expanded(
                      child: Text(
                        "Horaires de ${widget.childName}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Bouton d'ajout de jour
                    GestureDetector(
                      onTap: _showAddDayDialog,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal
          isLoading
              ? Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                )
              : Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modification des horaires',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: secondaryColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: primaryColor,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Vous pouvez ajouter plusieurs créneaux pour chaque jour (horaires coupés)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        // Afficher uniquement les jours qui ont des segments
                        ...allWeekDays
                            .where((day) => scheduleByDay[day]!.isNotEmpty)
                            .map((day) => _buildDaySchedule(day))
                            .toList(),
                        SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: _saveSchedule,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                            ),
                            child: Text(
                              'Enregistrer les modifications',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildDaySchedule(String day) {
    final segments = scheduleByDay[day]!;
    if (segments.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Row(
                children: [
                  if (segments.length > 1)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${segments.length} créneaux",
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: primaryColor),
                    onPressed: () => _addSegmentToDay(day),
                    tooltip: 'Ajouter un créneau',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        for (var segment in segments) {
                          segment.startController.dispose();
                          segment.endController.dispose();
                        }
                        scheduleByDay[day] = [];
                      });
                    },
                    tooltip: 'Supprimer tous les créneaux',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          Divider(
            color: secondaryColor,
            thickness: 1,
            height: 24,
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: segments.length,
            separatorBuilder: (context, index) => Divider(
              color: secondaryColor.withOpacity(0.5),
              height: 24,
            ),
            itemBuilder: (context, index) {
              return _buildTimeSegment(day, index, segments[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSegment(String day, int index, TimeSegment segment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scheduleByDay[day]!.length > 1)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Créneau ${index + 1}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () => _removeSegment(day, index),
                  tooltip: 'Supprimer ce créneau',
                ),
              ],
            ),
          ),
        Row(
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
                    onTap: () => _selectTime(day, index, true),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: primaryColor.withOpacity(0.5)),
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
                                  : Colors.black87,
                            ),
                          ),
                          Icon(Icons.access_time,
                              color: primaryColor, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
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
                    onTap: () => _selectTime(day, index, false),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: primaryColor.withOpacity(0.5)),
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
                                  : Colors.black87,
                            ),
                          ),
                          Icon(Icons.access_time,
                              color: primaryColor, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Libérer tous les contrôleurs
    scheduleByDay.forEach((day, segments) {
      for (var segment in segments) {
        segment.startController.dispose();
        segment.endController.dispose();
      }
    });
    super.dispose();
  }
}

class TimeSegment {
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
}
