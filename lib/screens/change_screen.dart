import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:poppins_app/widgets/custom_bottom_navigation.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';
import '../utils/structure_context.dart';

class ChangeScreen extends StatefulWidget {
  const ChangeScreen({Key? key}) : super(key: key);

  @override
  _ChangeScreenState createState() => _ChangeScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _ChangeScreenState extends State<ChangeScreen> {
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

  // Utiliser les couleurs officielles
  Color primaryColor = primaryBlue;

  String _changeType = "Couche";
  TextEditingController _observationsController = TextEditingController();
  bool _pipi = false;
  bool _selles = false;
  String _careTime = "";

  final List<String> changeTypes = [
    "Couche",
    "Pot",
    "Toilette",
  ];

  List<String> soins = [];

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  IconData _getChangeTypeIcon(String type) {
    switch (type) {
      case 'Couche':
        return Icons.child_care;
      case 'Pot':
        return Icons.event_seat;
      case 'Toilette':
        return Icons.wc;
      default:
        return Icons.child_care;
    }
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadEnfantsDuJour();
    });
  }

  Future<void> _selectChangeTime(
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
            "👨‍👧‍👦 Change: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
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
                print('➕ Change: ajout enfants délégués: ${toAddIds.length}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Change: erreur overlay délégation: $e');
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Change: Assistante Maternelle - affichage de tous les enfants");
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

  void _showChangeDetailsPopup(String structureId, String childId, String changeId,
      Map<String, dynamic> changeData) {
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
                            _getChangeTypeIcon(changeData['type']),
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
                                "Change de ${changeData['heure']}",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMMM yyyy', 'fr_FR')
                                    .format(changeData['date'].toDate())
                                    .toLowerCase(),
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bouton supprimer (même UX que les autres écrans)
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: Icon(Icons.delete_outline, color: Colors.white),
                          onPressed: () {
                            _confirmDeleteChange(
                                context, structureId, childId, changeId);
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
                        // Type de change
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
                                _getChangeTypeIcon(changeData['type']),
                                color: primaryColor,
                                size: isTabletDevice ? 24 : 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                changeData['type'],
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 18 : 16,
                                  fontWeight: FontWeight.w500,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Pipi/Selles
                        if (changeData['pipi'] || changeData['selles']) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: lightBlue,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                if (changeData['pipi']) ...[
                                  Icon(
                                    Icons.water_drop,
                                    color: primaryColor,
                                    size: isTabletDevice ? 22 : 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Pipi",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                                if (changeData['pipi'] && changeData['selles'])
                                  SizedBox(width: 24),
                                if (changeData['selles']) ...[
                                  Icon(
                                    Icons.eco,
                                    color: primaryYellow,
                                    size: isTabletDevice ? 22 : 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Selles",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w500,
                                      color: primaryYellow.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],

                        // Soins
                        if ((changeData['soins'] as List?)?.isNotEmpty ??
                            false) ...[
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
                                  "Soins complémentaires",
                                  style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: (changeData['soins'] as List)
                                      .map<Widget>((soin) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        soin.toString(),
                                        style: TextStyle(
                                          fontSize: isTabletDevice ? 15 : 14,
                                          color: primaryColor,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],

                        // Observations
                        if (changeData['observations']?.isNotEmpty ??
                            false) ...[
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
                                  changeData['observations'],
                                  style: TextStyle(
                                    fontSize: isTabletDevice ? 16 : 14,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],

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
                                  _showEditChangePopup(
                                      structureId, childId, changeId, changeData);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding:
                                      EdgeInsets.symmetric(vertical: 12),
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

  // Confirmation & suppression d'un change
  void _confirmDeleteChange(BuildContext dialogContext, String structureId,
      String childId, String changeId) {
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
                        'Supprimer ce change ?',
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
                  'Cette action retirera le change du journal, du récapitulatif et du fil des parents pour la journée.',
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
                                .collection('changes')
                                .doc(changeId)
                                .delete();

                            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Change supprimé.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Erreur lors de la suppression du change.'),
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

  void _showAddChangePopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String? errorMessage;
    String localChangeType = _changeType;
    String localCareTime = _careTime;

    _observationsController.clear();
    _pipi = false;
    _selles = false;
    soins = [];

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
                              padding: EdgeInsets.all(isTabletDevice ? 12 : 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.baby_changing_station,
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
                                    "Ajouter un change - ${enfant['prenom']}",
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
                        padding: EdgeInsets.all(isTabletDevice ? 24 : 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Heure du change
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Heure du change",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  InkWell(
                                    onTap: () =>
                                        _selectChangeTime(setState, (time) {
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

                            // Type de change
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Propreté",
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
                                      value: localChangeType,
                                      isExpanded: true,
                                      underline: Container(),
                                      iconSize: isTabletDevice ? 28 : 24,
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: primaryColor,
                                      ),
                                      items: changeTypes.map((String value) {
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
                                          localChangeType = newValue!;
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

                            // Pipi/Selles
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _pipi = !_pipi;
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _pipi
                                                  ? primaryColor
                                                      .withOpacity(0.15)
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _pipi
                                                    ? primaryColor
                                                    : Colors.grey.shade300,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _pipi
                                                      ? Icons.check_circle
                                                      : Icons.circle_outlined,
                                                  color: _pipi
                                                      ? primaryColor
                                                      : Colors.grey.shade400,
                                                  size:
                                                      isTabletDevice ? 22 : 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  "Pipi",
                                                  style: TextStyle(
                                                    fontSize: isTabletDevice
                                                        ? 16
                                                        : 14,
                                                    fontWeight: _pipi
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: _pipi
                                                        ? primaryColor
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selles = !_selles;
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _selles
                                                  ? primaryYellow
                                                      .withOpacity(0.15)
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _selles
                                                    ? primaryYellow
                                                    : Colors.grey.shade300,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _selles
                                                      ? Icons.check_circle
                                                      : Icons.circle_outlined,
                                                  color: _selles
                                                      ? primaryYellow
                                                      : Colors.grey.shade400,
                                                  size:
                                                      isTabletDevice ? 22 : 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  "Selles",
                                                  style: TextStyle(
                                                    fontSize: isTabletDevice
                                                        ? 16
                                                        : 14,
                                                    fontWeight: _selles
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: _selles
                                                        ? primaryYellow
                                                            .withOpacity(0.8)
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Soins complémentaires
                            Container(
                              margin: EdgeInsets.only(
                                  bottom: isTabletDevice ? 24 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Soins complémentaires",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 18 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      'Nez',
                                      'Yeux',
                                      'Oreilles',
                                      'Crème'
                                    ]
                                        .map(
                                          (soin) => InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (soins.contains(soin)) {
                                                  soins.remove(soin);
                                                } else {
                                                  soins.add(soin);
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: soins.contains(soin)
                                                    ? primaryColor
                                                        .withOpacity(0.15)
                                                    : Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: soins.contains(soin)
                                                      ? primaryColor
                                                      : Colors.grey.shade300,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Text(
                                                soin,
                                                style: TextStyle(
                                                  fontSize:
                                                      isTabletDevice ? 15 : 14,
                                                  fontWeight:
                                                      soins.contains(soin)
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                  color: soins.contains(soin)
                                                      ? primaryColor
                                                      : Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),

                            // Observations
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
                                        hintText: "Précisions sur le change...",
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
                                    setState(() => errorMessage = null);

                                    // Mise à jour des variables
                                    _careTime = localCareTime;
                                    _changeType = localChangeType;
                                    _addChangeToFirebase(childId);
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
      print('Erreur vérification arrivée (change): $e');
      return false;
    }
  }

  Future<void> _guardAddChange(String structureId, String childId) async {
    final arrived = await _isChildArrivedToday(structureId, childId);
    if (!arrived) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Arrivée requise'),
          content: Text(
              "Attention : vous n'avez pas indiqué l'heure d'arrivée.\n\nVeuillez indiquer l'horaire d'arrivée pour pouvoir ajouter un change."),
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
    _showAddChangePopup(childId);
  }

  void _showEditChangePopup(String structureId, String childId, String changeId,
      Map<String, dynamic> changeData) {
    String localChangeType = (changeData['type'] ?? 'Couche').toString();
    String localCareTime = (changeData['heure'] ?? '').toString();
    bool localPipi = changeData['pipi'] == true;
    bool localSelles = changeData['selles'] == true;
    List<String> localSoins = List<String>.from(changeData['soins'] ?? []);
    TextEditingController obsCtrl = TextEditingController(
        text: (changeData['observations'] ?? '').toString());

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
                  padding: EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
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
                            colors: [primaryColor, primaryColor.withOpacity(0.85)],
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
                              padding: EdgeInsets.all(isTabletDevice ? 12 : 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.baby_changing_station,
                                color: Colors.white,
                                size: isTabletDevice ? 30 : 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                "Modifier un change - ${enfant['prenom']}",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Formulaire
                      Padding(
                        padding: EdgeInsets.all(isTabletDevice ? 24 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Heure du change
                            Text("Heure du change",
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 12),
                            InkWell(
                              onTap: () =>
                                  _selectChangeTime(setState, (time) {
                                localCareTime = time;
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
                                      color: primaryColor.withOpacity(0.7),
                                      size: isTabletDevice ? 24 : 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 24),
                            // Type de change
                            Text("Quel type de change ?",
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 12),
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
                                value: changeTypes.contains(localChangeType)
                                    ? localChangeType
                                    : 'Couche',
                                isExpanded: true,
                                underline: Container(),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: primaryColor,
                                ),
                                items: changeTypes.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8),
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
                                    localChangeType = newValue!;
                                  });
                                },
                              ),
                            ),

                            SizedBox(height: 24),
                            // Statut Pipi / Selles
                            Text("Statut",
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: CheckboxListTile(
                                    title: Text('Pipi'),
                                    value: localPipi,
                                    onChanged: (v) =>
                                        setState(() => localPipi = v ?? false),
                                  ),
                                ),
                                Expanded(
                                  child: CheckboxListTile(
                                    title: Text('Selles'),
                                    value: localSelles,
                                    onChanged: (v) => setState(
                                        () => localSelles = v ?? false),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),
                            // Soins complémentaires
                            Text("Soins complémentaires",
                                style: TextStyle(
                                    fontSize: isTabletDevice ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800)),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                'Crème',
                                'Gel',
                                'Lait',
                              ].map((soin) {
                                final selected = localSoins.contains(soin);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (selected) {
                                        localSoins.remove(soin);
                                      } else {
                                        localSoins.add(soin);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? primaryColor.withOpacity(0.1)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? primaryColor
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      soin,
                                      style: TextStyle(
                                        fontSize: isTabletDevice ? 15 : 14,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: selected
                                            ? primaryColor
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
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
                                hintText: 'Précisions sur le change...',
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
                                            .collection('changes')
                                            .doc(changeId);
                                        await docRef.update({
                                          'heure': localCareTime.isNotEmpty
                                              ? localCareTime
                                              : (changeData['heure'] ?? ''),
                                          'type': localChangeType,
                                          'pipi': localPipi,
                                          'selles': localSelles,
                                          'soins': localSoins,
                                          'observations': obsCtrl.text,
                                        });
                                        Navigator.of(context).pop();
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'Erreur lors de la mise à jour du change'),
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

  Future<void> _addChangeToFirebase(String childId) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference changeRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser l'ID de structure correct
          .collection('children')
          .doc(childId)
          .collection('changes')
          .doc();

      final changeData = {
        'heure': _careTime,
        'date': DateTime.now(),
        'type': _changeType,
        'pipi': _pipi,
        'selles': _selles,
        'soins': soins,
        'observations': _observationsController.text,
      };

      await changeRef.set(changeData);

      setState(() {
        _careTime = '';
        _pipi = false;
        _selles = false;
        soins = [];
        _observationsController.clear();
      });

      print("Change ajouté avec succès !");
    } catch (e) {
      print("Erreur lors de l'ajout du change : $e");
    }
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    String genre = enfant['genre']?.toString() ?? 'Garçon';
    Color avatarColor = (genre == 'Fille') ? primaryRed : primaryBlue;

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
                // Utilisation de l'avatar avec dégradé comme dans HomeScreen
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
                          color: Colors.black87,
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
                  onPressed: () => _guardAddChange(
                      enfant['structureId'] ??
                          FirebaseAuth.instance.currentUser?.uid,
                      enfant['id']),
                ),
              ],
            ),
          ),
          // Liste des changes
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('changes')
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

              final changes = snapshot.data!.docs;

              if (changes.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Aucun change enregistré aujourd'hui",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: changes.length,
                separatorBuilder: (context, index) => SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final doc = changes[idx];
                  final changeData = doc.data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showChangeDetailsPopup(
                        enfant['structureId'] ??
                            FirebaseAuth.instance.currentUser?.uid,
                        enfant['id'],
                        doc.id,
                        changeData),
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
                              _getChangeTypeIcon(changeData['type']),
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  changeData['heure'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  changeData['type'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (changeData['pipi'])
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Pipi",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              if (changeData['selles'])
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryYellow.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Selles",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primaryYellow.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
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
    // Détection de l'iPad
    final bool isTabletDevice = isTablet(context);

    return SwipeNavigationWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ✨ NOUVEAU : CommonAppBar remplace _buildAppBar(context)
            CommonAppBar(
              title: 'Change',
              structureName: structureName,
              iconPath: 'assets/images/Icone_Changes.png',
              primaryColor: primaryBlue,
            ),

            // 🔄 GARDÉ IDENTIQUE : tout votre contenu existant
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
    String genre = enfant['genre']?.toString() ?? 'Garçon';
    Color avatarColor = (genre == 'Fille') ? primaryRed : primaryBlue;

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
          // En-tête avec gradient et infos enfant
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
                      color: Colors.white,
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
                      onPressed: () => _guardAddChange(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id']),
                      tooltip: "Ajouter un change",
                      padding: EdgeInsets.all(10),
                      constraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des changes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid)
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('changes')
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

                final changes = snapshot.data!.docs;

                if (changes.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.baby_changing_station,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Aucun change enregistré aujourd'hui",
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
                  itemCount: changes.length,
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final doc = changes[idx];
                    final changeData = doc.data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => _showChangeDetailsPopup(
                          enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                          enfant['id'],
                          doc.id,
                          changeData),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: lightBlue),
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
                                _getChangeTypeIcon(changeData['type']),
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
                                    changeData['heure'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    changeData['type'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 10,
                              children: [
                                if (changeData['pipi'])
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Pipi",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                if (changeData['selles'])
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryYellow.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Selles",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: primaryYellow.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                              size: 24,
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

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Changes.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.baby_changing_station,
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

  // Navigation du bas
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
            'assets/images/Icone_Echanges.png',
            width: 60,
            height: 60,
          ),
          label: "Echanges",
        ),
      ],
    );
  }
}
