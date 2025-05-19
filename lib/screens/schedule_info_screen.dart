import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
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
  }

  void _showTimePicker(
      BuildContext context, TimeSegment segment, bool isStart) {
    DatePicker.showTimePicker(
      context,
      showSecondsColumn: false,
      showTitleActions: true,
      onConfirm: (date) {
        setState(() {
          if (isStart) {
            segment.startController.text =
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          } else {
            segment.endController.text =
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          }
        });
      },
      currentTime: DateTime.now(),
      locale: LocaleType.fr,
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: lightBlue,
                      foregroundColor: primaryBlue,
                      padding: EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Veuillez renseigner les horaires de garde :",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                          "${segments.length} créneaux",
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

  Widget _buildTimeSegmentRow(String day, int index, TimeSegment segment) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: segment.startController,
            decoration: InputDecoration(
              labelText: "Heure d'arrivée",
              labelStyle: TextStyle(color: primaryBlue),
              prefixIcon: Icon(Icons.access_time, color: primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primaryBlue.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primaryBlue,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            readOnly: true,
            onTap: () => _showTimePicker(context, segment, true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: segment.endController,
            decoration: InputDecoration(
              labelText: "Heure de départ",
              labelStyle: TextStyle(color: primaryBlue),
              prefixIcon: Icon(Icons.access_time, color: primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primaryBlue.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primaryBlue,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            readOnly: true,
            onTap: () => _showTimePicker(context, segment, false),
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: primaryRed),
          onPressed: () => _removeTimeSegment(day, index),
        ),
      ],
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
                      "Poppins",
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
                      'Horaires de garde',
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
