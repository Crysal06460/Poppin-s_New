import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';
import '../utils/structure_context.dart';

class SanteScreen extends StatefulWidget {
  const SanteScreen({Key? key}) : super(key: key);

  @override
  _SanteScreenState createState() => _SanteScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _SanteScreenState extends State<SanteScreen> {
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

  Color primaryColor =
      Color(0xFF3D9DF2); // Utiliser la couleur bleue par défaut
  Color secondaryColor =
      Color(0xFFDFE9F2); // Utiliser la couleur bleu clair par défaut

  String _careType = "Température";
  String _medicationType = "Suppositoire";
  TextEditingController _observationsController = TextEditingController();
  TextEditingController _temperatureController = TextEditingController();
  TextEditingController _weightController = TextEditingController();
  String _route = "Auriculaire";
  String _careTime = "";

  final List<String> careTypes = [
    "Température",
    "Poids",
    "Médicaments",
  ];

  final List<String> medicationTypes = ["Suppositoire", "Suspension", "Autre"];

  final List<String> routes = [
    "Auriculaire",
    "Orale",
    "Frontale",
    "Rectale",
    "Temporale"
  ];

  @override
  void dispose() {
    _observationsController.dispose();
    _temperatureController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  IconData _getCareTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'température':
        return Icons.thermostat;
      case 'poids':
        return Icons.monitor_weight;
      case 'médicaments':
        return Icons.medication;
      default:
        return Icons.healing;
    }
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadEnfantsDuJour();
    });
  }

  Future<void> _selectCareTime(
      StateSetter setState, Function(String) onTimeSelected) async {
    // Obtenir l'heure actuelle ou celle déjà saisie
    TimeOfDay initialTime;
    if (_careTime.isNotEmpty) {
      final parts = _careTime.split(':');
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

  Future<void> _loadEnfantsDuJour() async {
    setState(() => isLoading = true);
    try {
      final structureContext = await StructureResolver().resolve();
      final String structureId = structureContext.structureId;
      final String currentUserEmail = structureContext.currentUserEmail;
      final String structureType = structureContext.normalizedStructureType;

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

      if (structureType == 'mam') {
        // Pour une MAM: filtrer par assignedMemberEmail
        filteredChildren = allChildren.where((child) {
          String assignedEmail =
              child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
          return assignedEmail == currentUserEmail;
        }).toList();

        print(
            "👨‍👧‍👦 Santé: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
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
                .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                .where('date', isLessThan: Timestamp.fromDate(end))
                .get();
            delegatedTodayChildIds = delSnap.docs
                .map((d) => (d.data()['childId'] ?? '').toString())
                .where((id) => id.isNotEmpty)
                .toSet();
            if (delegatedTodayChildIds.isNotEmpty) {
              final already = filteredChildren.map((c) => c['id'] as String).toSet();
              final toAddIds = delegatedTodayChildIds.difference(already);
              if (toAddIds.isNotEmpty) {
                filteredChildren.addAll(
                    allChildren.where((c) => toAddIds.contains(c['id'] as String)));
                print('➕ Santé: ajout enfants délégués: ${toAddIds.length}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Santé: erreur overlay délégation: $e');
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Santé: Assistante Maternelle - affichage de tous les enfants");
      }

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui
      enfants = [];
      for (var child in filteredChildren) {
        final isScheduledToday = child['schedule'] != null &&
            child['schedule'][capitalizedWeekday] != null;
        final isDelegatedToday = delegatedTodayChildIds.contains(child['id']);
        if (isScheduledToday || isDelegatedToday) {
          String? photoUrl = child['photoUrl'];
          enfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'structureId':
                structureId, // Ajouter l'ID de structure pour les requêtes futures
          });
        }
      }
      setState(() => isLoading = false);
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  void _showCareDetailsPopup(String structureId, String childId, String careId,
      Map<String, dynamic> careData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête avec dégradé
                Container(
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
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        _getCareTypeIcon(careData['type']),
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Soin de ${careData['heure']}",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMMM yyyy', 'fr_FR')
                                  .format(careData['date'].toDate()),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bouton supprimer (même UX que Repas/Activités/Siestes)
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: Icon(Icons.delete_outline, color: Colors.white),
                        onPressed: () {
                          _confirmDeleteCare(context, structureId, childId, careId);
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getCareTypeIcon(careData['type']),
                              color: primaryColor, size: 24),
                          SizedBox(width: 8),
                          Text(
                            careData['type'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      if (careData['type'] == 'Température') ...[
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            "${careData['temperature']}°",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor.withOpacity(0.8),
                            ),
                          ),
                        ),
                        if (careData['route'] != null) ...[
                          SizedBox(height: 8),
                          Text(
                            "Voie: ${careData['route']}",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ] else if (careData['type'] == 'Poids') ...[
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            "${careData['weight']} Kg",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ] else if (careData['type'] == 'Médicaments') ...[
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            careData['medicationType'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                      if (careData['observations']?.isNotEmpty ?? false) ...[
                        SizedBox(height: 24),
                        Text(
                          "Observations",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            careData['observations'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
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
                            'FERMER',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showEditCarePopup(structureId, childId, careId, careData);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('MODIFIER'),
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
  }

  // Confirmation & suppression d'un soin santé
  void _confirmDeleteCare(BuildContext dialogContext, String structureId,
      String childId, String careId) {
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
                        'Supprimer ce soin ?',
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
                  'Cette action retirera ce soin du journal, du récapitulatif et du fil des parents pour la journée.',
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
                                .collection('sante')
                                .doc(careId)
                                .delete();

                            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Soin supprimé.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Erreur lors de la suppression du soin.'),
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

  void _showAddCarePopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String localCareTime = _careTime;
    String localCareType = _careType;
    String localMedicationType = _medicationType;
    String localRoute = _route;
    String? errorMessage;

    _temperatureController.clear();
    _weightController.clear();
    _observationsController.clear();

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
                      horizontal: MediaQuery.of(context).size.width * 0.25,
                      vertical: 40) // Ajouter un padding vertical
                  : EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 40), // Ajouter un padding vertical
              child: Container(
                // Limiter la hauteur maximale
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height *
                      0.85, // 85% de la hauteur de l'écran
                ),
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
                  mainAxisSize:
                      MainAxisSize.min, // Important pour éviter l'overflow
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
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.healing,
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
                                  "Ajouter un soin - ${enfant['prenom']}",
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

                    // Contenu du formulaire avec SingleChildScrollView pour éviter l'overflow
                    Flexible(
                      // Remplacer Padding par Flexible
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isTabletDevice ? 24 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Heure du soin
                            Container(
                              margin: EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Heure du soin",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  InkWell(
                                    onTap: () =>
                                        _selectCareTime(setState, (time) {
                                      localCareTime = time;
                                      errorMessage = null;
                                    }),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: lightBlue,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: localCareTime.isEmpty
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
                                            localCareTime.isEmpty
                                                ? 'Choisir l\'heure'
                                                : localCareTime,
                                            style: TextStyle(
                                              fontSize:
                                                  isTabletDevice ? 18 : 16,
                                              color: localCareTime.isEmpty
                                                  ? Colors.grey.shade600
                                                  : primaryColor,
                                              fontWeight: localCareTime.isEmpty
                                                  ? FontWeight.normal
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          Icon(
                                            Icons.access_time_rounded,
                                            color:
                                                primaryColor.withOpacity(0.7),
                                            size: isTabletDevice ? 24 : 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Section Type de soin
                            Container(
                              margin: EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Quel était le soin ?",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Container(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: lightBlue.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: DropdownButton<String>(
                                      value: localCareType,
                                      isExpanded: true,
                                      underline: Container(),
                                      iconSize: isTabletDevice ? 28 : 24,
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: primaryColor,
                                      ),
                                      items: careTypes.map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8),
                                            child: Text(
                                              value,
                                              style: TextStyle(
                                                fontSize:
                                                    isTabletDevice ? 16 : 14,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        setState(() {
                                          localCareType = newValue!;
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

                            // Champs spécifiques selon le type de soin
                            if (localCareType == 'Température') ...[
                              Container(
                                margin: EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Température",
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
                                            color:
                                                Colors.black.withOpacity(0.04),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _temperatureController,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                        decoration: InputDecoration(
                                          hintText: "Ex: 37.2",
                                          hintStyle: TextStyle(
                                              color: Colors.grey.shade400),
                                          suffixText: "°",
                                          suffixStyle: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*[,.]?\d*')),
                                        ],
                                        onChanged: (value) {
                                          if (value.contains(',')) {
                                            _temperatureController.text =
                                                value.replaceAll(',', '.');
                                            _temperatureController.selection =
                                                TextSelection.fromPosition(
                                              TextPosition(
                                                  offset: _temperatureController
                                                      .text.length),
                                            );
                                          }
                                        },
                                        style: TextStyle(
                                          fontSize: isTabletDevice ? 16 : 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Voie :",
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Container(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: lightBlue.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: localRoute,
                                        isExpanded: true,
                                        underline: Container(),
                                        iconSize: isTabletDevice ? 28 : 24,
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                          color: primaryColor,
                                        ),
                                        items: routes.map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 8),
                                              child: Text(
                                                value,
                                                style: TextStyle(
                                                  fontSize:
                                                      isTabletDevice ? 16 : 14,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newValue) {
                                          setState(() {
                                            localRoute = newValue!;
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
                            ] else if (localCareType == 'Poids') ...[
                              Container(
                                margin: EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Poids",
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
                                            color:
                                                Colors.black.withOpacity(0.04),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _weightController,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                        decoration: InputDecoration(
                                          hintText: "Ex: 12.5",
                                          hintStyle: TextStyle(
                                              color: Colors.grey.shade400),
                                          suffixText: "Kg",
                                          suffixStyle: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*[,.]?\d*')),
                                        ],
                                        onChanged: (value) {
                                          if (value.contains(',')) {
                                            _weightController.text =
                                                value.replaceAll(',', '.');
                                            _weightController.selection =
                                                TextSelection.fromPosition(
                                              TextPosition(
                                                  offset: _weightController
                                                      .text.length),
                                            );
                                          }
                                        },
                                        style: TextStyle(
                                          fontSize: isTabletDevice ? 16 : 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (localCareType == 'Médicaments') ...[
                              Container(
                                margin: EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Type de médicament",
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Container(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: lightBlue.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: localMedicationType,
                                        isExpanded: true,
                                        underline: Container(),
                                        iconSize: isTabletDevice ? 28 : 24,
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                          color: primaryColor,
                                        ),
                                        items:
                                            medicationTypes.map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 8),
                                              child: Text(
                                                value,
                                                style: TextStyle(
                                                  fontSize:
                                                      isTabletDevice ? 16 : 14,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newValue) {
                                          setState(() {
                                            localMedicationType = newValue!;
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
                            ],

                            // Section Observations
                            Container(
                              margin: EdgeInsets.only(bottom: 24),
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
                                        hintText: "Précisions sur le soin...",
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

                                // Bouton Ajouter
                                ElevatedButton(
                                  onPressed: () {
                                    if (localCareTime.isEmpty) {
                                      setState(() {
                                        errorMessage =
                                            'Veuillez sélectionner une heure';
                                      });
                                      return;
                                    }

                                    if (localCareType == 'Température' &&
                                        _temperatureController.text.isEmpty) {
                                      setState(() {
                                        errorMessage =
                                            'Veuillez indiquer la température';
                                      });
                                      return;
                                    }

                                    if (localCareType == 'Poids' &&
                                        _weightController.text.isEmpty) {
                                      setState(() {
                                        errorMessage =
                                            'Veuillez indiquer le poids';
                                      });
                                      return;
                                    }

                                    setState(() {
                                      errorMessage = null;
                                    });

                                    _careTime = localCareTime;
                                    _careType = localCareType;
                                    _medicationType = localMedicationType;
                                    _route = localRoute;

                                    _addCareToFirebase(childId);
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
      print('Erreur vérification arrivée (santé): $e');
      return false;
    }
  }

  Future<void> _guardAddCare(String structureId, String childId) async {
    final arrived = await _isChildArrivedToday(structureId, childId);
    if (!arrived) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Arrivée requise'),
          content: Text(
              "Attention : vous n'avez pas indiqué l'heure d'arrivée.\n\nVeuillez indiquer l'horaire d'arrivée pour pouvoir ajouter un soin."),
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
    _showAddCarePopup(childId);
  }

  void _showEditCarePopup(String structureId, String childId, String careId,
      Map<String, dynamic> careData) {
    String localTime = (careData['heure'] ?? '').toString();
    String localType = (careData['type'] ?? 'Température').toString();
    String localMedicationType = (careData['medicationType'] ?? 'Suppositoire').toString();
    String localRoute = (careData['route'] ?? 'Auriculaire').toString();
    TextEditingController tempCtrl = TextEditingController(
        text: careData['temperature'] != null
            ? (careData['temperature'].toString())
            : '');
    TextEditingController weightCtrl = TextEditingController(
        text:
            careData['weight'] != null ? (careData['weight'].toString()) : '');
    TextEditingController obsCtrl = TextEditingController(
        text: (careData['observations'] ?? '').toString());

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
                            colors: [primaryColor, primaryColor.withOpacity(0.85)],
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
                              child: Icon(Icons.healing,
                                  color: Colors.white,
                                  size: isTabletDevice ? 26 : 22),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Modifier un soin',
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

                      // Formulaire
                      Padding(
                        padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Heure
                            Text('Heure du soin',
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 10),
                            InkWell(
                              onTap: () => _selectCareTime(setState, (t) {
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
                                      localTime.isEmpty ? 'Choisir l\'heure' : localTime,
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
                            // Type de soin
                            Text('Quel était le soin ?',
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
                                value: careTypes.contains(localType)
                                    ? localType
                                    : 'Température',
                                isExpanded: true,
                                underline: Container(),
                                icon: Icon(Icons.arrow_drop_down,
                                    color: primaryColor),
                                items: careTypes
                                    .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => localType = val);
                                },
                              ),
                            ),

                            SizedBox(height: 16),
                            if (localType == 'Température') ...[
                              Text('Température',
                                  style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800)),
                              SizedBox(height: 8),
                              TextField(
                                controller: tempCtrl,
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9\.]')),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Ex: 37.2',
                                  suffixText: '°',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text('Voie de mesure',
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
                                  value: routes.contains(localRoute)
                                      ? localRoute
                                      : routes.first,
                                  isExpanded: true,
                                  underline: Container(),
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: primaryColor),
                                  items: routes
                                      .map((r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(r),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => localRoute = val);
                                  },
                                ),
                              ),
                            ] else if (localType == 'Poids') ...[
                              Text('Poids',
                                  style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800)),
                              SizedBox(height: 8),
                              TextField(
                                controller: weightCtrl,
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9\.]')),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Ex: 9.3',
                                  suffixText: 'kg',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ] else if (localType == 'Médicaments') ...[
                              Text('Type de médicament',
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
                                  value: medicationTypes.contains(localMedicationType)
                                      ? localMedicationType
                                      : medicationTypes.first,
                                  isExpanded: true,
                                  underline: Container(),
                                  icon: Icon(Icons.arrow_drop_down,
                                      color: primaryColor),
                                  items: medicationTypes
                                      .map((m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(m),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => localMedicationType = val);
                                  },
                                ),
                              ),
                            ],

                            SizedBox(height: 16),
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
                                hintText: 'Précisions...',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),

                            SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text('ANNULER'),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        final docRef = FirebaseFirestore.instance
                                            .collection('structures')
                                            .doc(structureId)
                                            .collection('children')
                                            .doc(childId)
                                            .collection('sante')
                                            .doc(careId);
                                        Map<String, dynamic> update = {
                                          'heure': localTime.isNotEmpty
                                              ? localTime
                                              : (careData['heure'] ?? ''),
                                          'type': localType,
                                          'observations': obsCtrl.text,
                                        };
                                        // Nettoyage/ajout des champs spécifiques
                                        if (localType == 'Température') {
                                          update['temperature'] =
                                              double.tryParse(tempCtrl.text) ?? 0;
                                          update['route'] = localRoute;
                                          update.remove('weight');
                                          update.remove('medicationType');
                                        } else if (localType == 'Poids') {
                                          update['weight'] =
                                              double.tryParse(weightCtrl.text) ?? 0;
                                          update.remove('temperature');
                                          update.remove('route');
                                          update.remove('medicationType');
                                        } else if (localType == 'Médicaments') {
                                          update['medicationType'] =
                                              localMedicationType;
                                          update.remove('temperature');
                                          update.remove('route');
                                          update.remove('weight');
                                        }

                                        await docRef.update(update);
                                        Navigator.of(context).pop();
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'Erreur lors de la mise à jour du soin'),
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

  Future<void> _addCareToFirebase(String childId) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference careRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser l'ID de structure correct
          .collection('children')
          .doc(childId)
          .collection('sante')
          .doc();

      final careData = {
        'heure': _careTime,
        'date': DateTime.now(),
        'type': _careType,
        'observations': _observationsController.text,
      };

      if (_careType == 'Température') {
        careData['temperature'] =
            double.tryParse(_temperatureController.text) ?? 0;
        careData['route'] = _route;
      } else if (_careType == 'Poids') {
        careData['weight'] = double.tryParse(_weightController.text) ?? 0;
      } else if (_careType == 'Médicaments') {
        careData['medicationType'] = _medicationType;
      }

      await careRef.set(careData);

      setState(() {
        _careTime = '';
        _temperatureController.clear();
        _weightController.clear();
        _observationsController.clear();
        _careType = 'Température';
        _medicationType = 'Suppositoire';
        _route = 'Auriculaire';
      });

      print("Soin ajouté avec succès !");
    } catch (e) {
      print("Erreur lors de l'ajout du soin : $e");
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
    final isBoy = enfant['genre'] == 'Garçon';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête avec photo et nom
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // Photo de l'enfant avec dégradé selon le genre
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
                  child: Center(
                    child: enfant['photoUrl'] != null
                        ? ClipOval(
                            child: Image.network(
                              enfant['photoUrl'],
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackAvatar(enfant['prenom']),
                            ),
                          )
                        : _buildFallbackAvatar(enfant['prenom']),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isBoy ? primaryBlue : primaryRed,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: primaryColor, size: 24),
                    onPressed: () => _guardAddCare(
                        enfant['structureId'] ??
                            FirebaseAuth.instance.currentUser?.uid,
                        enfant['id']),
                    tooltip: "Ajouter un soin",
                  ),
                ),
              ],
            ),
          ),
          // Liste des soins
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('sante')
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
                return Container(
                  padding: EdgeInsets.all(12),
                  alignment: Alignment.center,
                  child: Text(
                    "Aucun soin enregistré aujourd'hui",
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: lightBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 8, top: 4, bottom: 8),
                      child: Text(
                        "Soins d'aujourd'hui",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Column(
                      children: snapshot.data!.docs.map((doc) {
                        final careData = doc.data() as Map<String, dynamic>;
                        return GestureDetector(
                          onTap: () => _showCareDetailsPopup(
                              enfant['structureId'] ??
                                  FirebaseAuth.instance.currentUser?.uid,
                              enfant['id'],
                              doc.id,
                              careData),
                          child: Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getCareTypeIcon(careData['type']),
                                    color: primaryColor,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${careData['heure']} - ${careData['type']}",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (careData['type'] == 'Température')
                                        Text(
                                          "${careData['temperature']}° (${careData['route']})",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        )
                                      else if (careData['type'] == 'Poids')
                                        Text(
                                          "${careData['weight']} Kg",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        )
                                      else if (careData['type'] ==
                                          'Médicaments')
                                        Text(
                                          careData['medicationType'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Avatar par défaut avec l'initiale du prénom
  Widget _buildFallbackAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor,
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
            'assets/images/Icone_Sante.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.healing,
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
              title: 'Santé',
              structureName: structureName,
              iconPath: 'assets/images/Icone_Sante.png',
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
  // Carte enfant adaptée pour iPad
  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    final isBoy = enfant['genre'] == 'Garçon';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête avec photo et nom
          Container(
            decoration: BoxDecoration(
              color: isBoy ? primaryBlue : primaryRed,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Photo de l'enfant avec dégradé selon le genre - plus grande pour iPad
                Container(
                  width: 70, // Plus grand pour iPad
                  height: 70, // Plus grand pour iPad
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
                  child: Center(
                    child: enfant['photoUrl'] != null
                        ? ClipOval(
                            child: Image.network(
                              enfant['photoUrl'],
                              width: 66, // Plus grand pour iPad
                              height: 66, // Plus grand pour iPad
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackAvatarForTablet(
                                      enfant['prenom']),
                            ),
                          )
                        : _buildFallbackAvatarForTablet(enfant['prenom']),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 22, // Plus grand pour iPad
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                      icon: Icon(Icons.add,
                          color: isBoy ? primaryBlue : primaryRed, size: 24),
                      onPressed: () => _guardAddCare(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id']),
                      tooltip: "Ajouter un soin",
                      padding: EdgeInsets.all(10),
                      constraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des soins - adaptée pour iPad
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid)
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('sante')
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
                  return Container(
                    padding: EdgeInsets.all(16), // Plus grand pour iPad
                    alignment: Alignment.center,
                    child: Text(
                      "Aucun soin enregistré aujourd'hui",
                      style: TextStyle(
                        fontSize: 16, // Plus grand pour iPad
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: lightBlue.withOpacity(0.3),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  padding: EdgeInsets.all(16), // Plus grand pour iPad
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                            left: 8,
                            top: 4,
                            bottom: 12), // Plus d'espace pour iPad
                        child: Text(
                          "Soins d'aujourd'hui",
                          style: TextStyle(
                            fontSize: 16, // Plus grand pour iPad
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, idx) {
                            final doc = snapshot.data!.docs[idx];
                            final careData = doc.data() as Map<String, dynamic>;
                            return GestureDetector(
                              onTap: () => _showCareDetailsPopup(
                                  enfant['structureId'] ??
                                      FirebaseAuth.instance.currentUser?.uid,
                                  enfant['id'],
                                  doc.id,
                                  careData),
                              child: Container(
                                margin: EdgeInsets.only(
                                    bottom: 12), // Plus d'espace pour iPad
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12), // Plus grand pour iPad
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(12), // Plus arrondi
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                          8), // Plus grand pour iPad
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getCareTypeIcon(careData['type']),
                                        color: primaryColor,
                                        size: 22, // Plus grand pour iPad
                                      ),
                                    ),
                                    SizedBox(
                                        width: 16), // Plus d'espace pour iPad
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${careData['heure']} - ${careData['type']}",
                                            style: TextStyle(
                                              fontSize:
                                                  17, // Plus grand pour iPad
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          if (careData['type'] == 'Température')
                                            Text(
                                              "${careData['temperature']}° (${careData['route']})",
                                              style: TextStyle(
                                                fontSize:
                                                    16, // Plus grand pour iPad
                                                color: Colors.grey[600],
                                              ),
                                            )
                                          else if (careData['type'] == 'Poids')
                                            Text(
                                              "${careData['weight']} Kg",
                                              style: TextStyle(
                                                fontSize:
                                                    16, // Plus grand pour iPad
                                                color: Colors.grey[600],
                                              ),
                                            )
                                          else if (careData['type'] ==
                                              'Médicaments')
                                            Text(
                                              careData['medicationType'],
                                              style: TextStyle(
                                                fontSize:
                                                    16, // Plus grand pour iPad
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade400,
                                      size: 24, // Plus grand pour iPad
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Avatar par défaut avec l'initiale du prénom - adapté pour iPad
  Widget _buildFallbackAvatarForTablet(String name) {
    return Container(
      width: 66, // Plus grand pour iPad
      height: 66, // Plus grand pour iPad
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 28, // Plus grand pour iPad
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
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
      selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
}
