import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:poppins_app/widgets/custom_bottom_navigation.dart';
import '../widgets/date_selector.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';
import '../utils/structure_context.dart';
import '../utils/planning_helper.dart';
import '../utils/child_avatar_color_helper.dart';
import '../utils/absence_helper.dart';

class TransmissionsScreen extends StatefulWidget {
  const TransmissionsScreen({Key? key}) : super(key: key);

  @override
  _TransmissionsScreenState createState() => _TransmissionsScreenState();
}

class _TransmissionsScreenState extends State<TransmissionsScreen> {
  List<Map<String, dynamic>> enfants = [];
  List<Map<String, dynamic>> _allChildren = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  String _structureId = '';
  int _selectedIndex = 1;
  bool _isMamStructure = false;
  String _currentUserEmail = '';
  Set<String> _delegatedChildIds = {};
  bool _allowAllChildren = false;

  bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  Color primaryColor = Color(0xFF3D9DF2); // Bleu par défaut
  Color secondaryColor = Color(0xFFDFE9F2); // Bleu clair par défaut

  final TextEditingController _transmissionController = TextEditingController();
  final List<String> _transmissionCategories = [
    'Santé',
    'Autre',
  ];
  String _selectedCategory = 'Santé';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadEnfantsDuJour();
    });
  }

  @override
  void dispose() {
    _transmissionController.dispose();
    super.dispose();
  }

  Future<void> _loadEnfantsDuJour() async {
    setState(() => isLoading = true);
    try {
      final structureContext = await StructureResolver().resolve();
      final String structureId = structureContext.structureId;
      final String currentUserEmail =
          (structureContext.currentUserEmail ?? '').toLowerCase();
      final String structureType = structureContext.normalizedStructureType;
      final bool allowAllChildren = structureContext.showAllChildren;

      final today = _selectedDate;
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      setState(() {
        structureName = structureContext.structureName;
        _isMamStructure = structureType == 'mam';
        _currentUserEmail = currentUserEmail;
        _structureId = structureId;
        _allowAllChildren = allowAllChildren;
      });

      // Récupérer tous les enfants de la structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren = snapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
                'structureId': structureId,
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
              "👨‍👧‍👦 Transmissions: Membre MAM - affichage de tous les enfants de la structure");
        } else {
          filteredChildren = allChildren.where((child) {
            String assignedEmail =
                child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
            return assignedEmail == currentUserEmail;
          }).toList();

          print(
              "👨‍👧‍👦 Transmissions: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
        }
        // ➕ Ajouter enfants délégués aujourd'hui et hier
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
            myMemberId = memSnap.docs.first.id;
            final now = _selectedDate;
            final todayInfos = DateTime(now.year, now.month, now.day);
            final yesterdayInfos = todayInfos.subtract(Duration(days: 1));
            
            // On cherche les délégations couvrant hier et aujourd'hui
            final start = yesterdayInfos;
            final end = todayInfos.add(const Duration(days: 1));
            
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
                    '➕ Transmissions: ajout enfants délégués: ${toAddIds.length}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Transmissions: erreur overlay délégation: $e');
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Transmissions: Assistante Maternelle - affichage de tous les enfants");
      }

      if (useMamColors) {
        mamColorAssignments =
            ChildAvatarColorHelper.buildMamAssignmentsFromChildren(
          filteredChildren,
        );
      }

      final Set<String> absentChildIds =
          await AbsenceHelper.fetchAbsentChildIds(structureId, date: today);

      // Tous les enfants liés apparaissent, présents ou non
      enfants = [];

      for (var child in filteredChildren) {
        final bool isAbsent = absentChildIds.contains(child['id']);
        final bool isScheduled = PlanningHelper.isScheduledForDate(child, today);
        final bool isDelegated = delegatedTodayChildIds.contains(child['id']);

        String presenceStatus;
        if (isAbsent) {
          presenceStatus = 'absent';
        } else if (isScheduled || isDelegated) {
          presenceStatus = 'present';
        } else {
          presenceStatus = 'not_scheduled';
        }

        final String assignedEmail = ChildAvatarColorHelper.normalizeEmail(
            child['assignedMemberEmail']);
        final Color avatarColor = ChildAvatarColorHelper.resolveAvatarColor(
          isMamStructure: useMamColors,
          mamAssignments: mamColorAssignments,
          assignedMemberEmail: assignedEmail,
          gender: child['gender']?.toString(),
        );
        String? photoUrl = child['photoUrl'];
        enfants.add({
          'id': child['id'],
          'prenom': child['firstName'],
          'genre': child['gender'],
          'photoUrl': photoUrl,
          'assignedMemberEmail': assignedEmail,
          'avatarColor': avatarColor,
          'structureId': structureId,
          'presenceStatus': presenceStatus,
        });
      }

      // Présents en premier, puis non prévus, puis absents
      enfants.sort((a, b) {
        const order = {'present': 0, 'not_scheduled': 1, 'absent': 2};
        return (order[a['presenceStatus']] ?? 1)
            .compareTo(order[b['presenceStatus']] ?? 1);
      });
      setState(() {
        isLoading = false;
        _delegatedChildIds = delegatedTodayChildIds;
        _allChildren = allChildren;
      });
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  // Transmission groupée : TOUS les enfants de l'assmat, présents ou non.
  // Ne pas filtrer par présence du jour — un message "Je serai absente lundi"
  // doit partir à tous les parents, même si leur enfant n'était pas là.
  List<Map<String, dynamic>> _resolveBulkTransmissionTargets() {
    if (_allChildren.isEmpty) return [];

    if (!_isMamStructure || _allowAllChildren) {
      return List<Map<String, dynamic>>.from(_allChildren);
    }

    // MAM : enfants assignés à ce membre (indépendamment de leur présence)
    return _allChildren.where((child) {
      final assignedEmail =
          (child['assignedMemberEmail'] ?? '').toString().toLowerCase();
      return assignedEmail == _currentUserEmail;
    }).toList();
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Santé':
        return Icons.medical_services_outlined;
      case 'Autre':
        return Icons.category_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  void _showTransmissionDetailsPopup(Map<String, dynamic> transmissionData) {
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
                        _getCategoryIcon(transmissionData['category']),
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Transmission de ${transmissionData['heure']}",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              DateFormat('dd MMMM yyyy', 'fr_FR')
                                  .format(transmissionData['date'].toDate()),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenu
                Container(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getCategoryIcon(transmissionData['category']),
                              color: primaryColor, size: 24),
                          SizedBox(width: 8),
                          Text(
                            transmissionData['category'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          transmissionData['content'],
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showEditTransmissionPopup(transmissionData);
                        },
                        icon: Icon(Icons.edit, color: primaryColor),
                        label: Text(
                          'Modifier',
                          style: TextStyle(color: primaryColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryColor),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _confirmDeleteTransmission(transmissionData);
                        },
                        icon: Icon(Icons.delete, color: Colors.red),
                        label: Text(
                          'Supprimer',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bouton fermer
                Container(
                  width: double.infinity,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: Text(
                          "FERMER",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddTransmissionPopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    _transmissionController.clear();
    String localCategory = _selectedCategory;
    DateTime localSelectedDate = _selectedDate;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ajouter une transmission - ${enfant['prenom']}",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      // Selecteur de date (Aujourd'hui / Hier)
                      Text(
                        "Date : ${DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedDate)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Catégorie",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: localCategory,
                          isExpanded: true,
                          underline: Container(),
                          items: _transmissionCategories.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              localCategory = newValue!;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _transmissionController,
                        decoration: InputDecoration(
                          labelText: "Contenu",
                          labelStyle:
                              TextStyle(fontSize: 16, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 20),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              "ANNULER",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (_transmissionController.text.trim().isEmpty) {
                                setState(() {
                                  errorMessage = 'Veuillez saisir un contenu';
                                });
                                return;
                              }

                                _selectedCategory = localCategory;
                                _addTransmissionToFirebase(
                                  childId,
                                  localCategory,
                                  _transmissionController.text.trim(),
                                  _selectedDate,
                                );
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "AJOUTER",
                              style: TextStyle(
                                fontSize: 16,
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
            );
          },
        );
      },
    );
  }

  void _showEditTransmissionPopup(Map<String, dynamic> transmissionData) {
    final TextEditingController controller = TextEditingController(
      text: transmissionData['content'] ?? '',
    );
    String localCategory =
        (transmissionData['category'] ?? _selectedCategory).toString();
    String? errorMessage;
    final String childId = (transmissionData['childId'] ?? '').toString();
    final String transmissionId = (transmissionData['id'] ?? '').toString();
    final String structureId = (transmissionData['structureId'] ??
            FirebaseAuth.instance.currentUser?.uid)
        .toString();

    if (childId.isEmpty ||
        transmissionId.isEmpty ||
        structureId.isEmpty ||
        structureId == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de retrouver la transmission'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Modifier la transmission",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Catégorie",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: localCategory,
                          isExpanded: true,
                          underline: Container(),
                          items: _transmissionCategories.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              localCategory = newValue!;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: "Contenu",
                          labelStyle:
                              TextStyle(fontSize: 16, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 20),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              "ANNULER",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (controller.text.trim().isEmpty) {
                                setState(() {
                                  errorMessage = 'Veuillez saisir un contenu';
                                });
                                return;
                              }
                              Navigator.of(context).pop();
                              _updateTransmission(
                                structureId,
                                childId,
                                transmissionId,
                                localCategory,
                                controller.text.trim(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "ENREGISTRER",
                              style: TextStyle(
                                fontSize: 16,
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
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTransmission(Map<String, dynamic> transmissionData) {
    final String childId = (transmissionData['childId'] ?? '').toString();
    final String transmissionId = (transmissionData['id'] ?? '').toString();
    final String structureId = (transmissionData['structureId'] ??
            FirebaseAuth.instance.currentUser?.uid)
        .toString();

    if (childId.isEmpty ||
        transmissionId.isEmpty ||
        structureId.isEmpty ||
        structureId == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de retrouver la transmission'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer la transmission ?'),
        content: Text(
            'Cette action supprimera définitivement la transmission sélectionnée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTransmission(structureId, childId, transmissionId);
            },
            child: Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTransmissionToFirebase(String childId, String category,
      String content, DateTime date) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser l'ID de structure correct
          .collection('children')
          .doc(childId)
          .collection('transmissions')
          .add({
        'category': category,
        'content': content,
        'date': date,
        'heure': DateFormat('HH:mm').format(DateTime.now()), // Keep current time for sorting/display or update if needed? Usually 'heure' is display time.
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transmission ajoutée avec succès'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      print("Erreur lors de l'ajout de la transmission : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ajout de la transmission'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTransmission(
    String structureId,
    String childId,
    String transmissionId,
    String category,
    String content,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('transmissions')
          .doc(transmissionId)
          .update({
        'category': category,
        'content': content,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transmission mise à jour'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      print("Erreur lors de la mise à jour de la transmission : $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTransmission(
    String structureId,
    String childId,
    String transmissionId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('transmissions')
          .doc(transmissionId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transmission supprimée'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      print("Erreur lors de la suppression de la transmission : $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleBulkTransmission() async {
    final targets = _resolveBulkTransmissionTargets();
    if (targets.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Aucun enfant disponible'),
          content: Text(
            "Aucun enfant ne vous est associé.\nImpossible d'envoyer une transmission groupée.",
          ),
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
    _showBulkTransmissionPopup(targets);
  }

  void _showBulkTransmissionPopup(List<Map<String, dynamic>> targets) {
    _transmissionController.clear();
    String localCategory = _selectedCategory;
    String? errorMessage;
    final Set<String> selectedIds =
        targets.map((e) => e['id'].toString()).toSet();
    final sortedTargets = List<Map<String, dynamic>>.from(targets)
      ..sort((a, b) => (a['firstName'] ?? a['prenom'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo(
              (b['firstName'] ?? b['prenom'] ?? '').toString().toLowerCase()));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Transmission groupée (${selectedIds.length}/${sortedTargets.length})",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _isMamStructure && !_allowAllChildren
                            ? "Sélectionnez les enfants qui vous sont assignés/délégués."
                            : "Sélectionnez les enfants de la structure pour cette transmission.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 240,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          itemCount: sortedTargets.length,
                          itemBuilder: (context, index) {
                            final child = sortedTargets[index];
                            final String id = child['id'].toString();
                            final String name = (child['firstName'] ??
                                    child['prenom'] ??
                                    'Enfant')
                                .toString();
                            return CheckboxListTile(
                              value: selectedIds.contains(id),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedIds.add(id);
                                  } else {
                                    selectedIds.remove(id);
                                  }
                                });
                              },
                              title: Text(name),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Catégorie",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: localCategory,
                          isExpanded: true,
                          underline: Container(),
                          items: _transmissionCategories.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              localCategory = newValue!;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _transmissionController,
                        decoration: InputDecoration(
                          labelText: "Contenu",
                          labelStyle:
                              TextStyle(fontSize: 16, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 20),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              "ANNULER",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (_transmissionController.text.trim().isEmpty) {
                                setState(() {
                                  errorMessage = 'Veuillez saisir un contenu';
                                });
                                return;
                              }

                              if (selectedIds.isEmpty) {
                                setState(() {
                                  errorMessage =
                                      'Veuillez sélectionner au moins un enfant';
                                });
                                return;
                              }

                              _selectedCategory = localCategory;
                              Navigator.of(context).pop();
                              _addBulkTransmissionToFirebase(
                                sortedTargets
                                    .where((c) => selectedIds
                                        .contains(c['id'].toString()))
                                    .toList(),
                                localCategory,
                                _transmissionController.text.trim(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "ENVOYER",
                              style: TextStyle(
                                fontSize: 16,
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
            );
          },
        );
      },
    );
  }

  Future<void> _addBulkTransmissionToFirebase(
    List<Map<String, dynamic>> targets,
    String category,
    String content,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final DateTime now = DateTime.now();
      final String heure = DateFormat('HH:mm').format(now);

      for (final child in targets) {
        final String childId = child['id'];
        final String structureId =
            child['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;
        final docRef = FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .doc(childId)
            .collection('transmissions')
            .doc();
        batch.set(docRef, {
          'category': category,
          'content': content,
          'date': now,
          'heure': heure,
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Transmission envoyée à ${targets.length} enfant(s)'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      print("Erreur transmission groupée: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi groupé'),
          backgroundColor: Colors.red,
        ),
      );
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

  // Avatar par défaut avec l'initiale du prénom
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
            fontSize: 28, // Augmenté pour iPad
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPresenceBadge(String? status) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'present':
        color = Colors.green;
        label = 'Présent';
        icon = Icons.check_circle_outline;
        break;
      case 'absent':
        color = Colors.orange;
        label = 'Absent';
        icon = Icons.cancel_outlined;
        break;
      default:
        color = Colors.grey;
        label = 'Non prévu';
        icon = Icons.schedule;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    final String genre = enfant['genre']?.toString() ?? '';
    final Color avatarColor = (enfant['avatarColor'] as Color?) ??
        ChildAvatarColorHelper.defaultColorForGender(genre);
    final bool isBoy = genre == 'Garçon';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enfant['prenom'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 4),
                      _buildPresenceBadge(enfant['presenceStatus']),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: primaryColor, size: 30),
                  onPressed: () => _showAddTransmissionPopup(enfant['id']),
                  tooltip: 'Ajouter une transmission',
                ),
              ],
            ),
          ),
          // Liste des transmissions
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('transmissions')
                .where('date',
                    isGreaterThanOrEqualTo: DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                    ))
                .where('date',
                    isLessThan: DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
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
                    "Aucune transmission récente",
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
                        "Transmissions récentes",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Column(
                      children: snapshot.data!.docs.map((doc) {
                        final transmissionData = {
                          ...doc.data() as Map<String, dynamic>,
                          'id': doc.id,
                          'childId': enfant['id'],
                          'structureId': enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid,
                        };
                        return GestureDetector(
                          onTap: () =>
                              _showTransmissionDetailsPopup(transmissionData),
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
                                    _getCategoryIcon(
                                        transmissionData['category']),
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
                                        "${transmissionData['heure']} - ${transmissionData['category']}",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        transmissionData['content'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
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

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_transmissions.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.share_arrival_time,
              size: 80,
              color: primaryColor.withOpacity(0.4),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Aucun enfant associé',
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

  Widget _buildBulkTransmissionBanner() {
    final String title = _isMamStructure
        ? "Transmission à mes parents"
        : "Transmission à tous les parents";
    final String subtitle = _isMamStructure
        ? "Envoyer rapidement une information aux parents des enfants qui vous sont confiés."
        : "Envoyer en un clic une information aux parents de tous vos enfants.";

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lightBlue.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleBulkTransmission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(Icons.campaign, color: Colors.white),
                label: Text(
                  "Nouvelle transmission groupée",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Détection de l'iPad/tablette
    final bool isTabletDevice = isTablet(context);
    // Le bouton s'affiche dès que des enfants existent (présents ou non)
    final bool showBulkButton = !isLoading &&
        _resolveBulkTransmissionTargets().isNotEmpty;

    return SwipeNavigationWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ✨ NOUVEAU : CommonAppBar remplace _buildAppBar(context)
            CommonAppBar(
              title: 'Transmissions',
              structureName: structureName,
              iconPath: 'assets/images/Icone_transmissions.png',
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

            if (showBulkButton) _buildBulkTransmissionBanner(),

            // 🔄 GARDÉ IDENTIQUE : tout votre contenu existant
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
    final Color avatarColor = (enfant['avatarColor'] as Color?) ??
        ChildAvatarColorHelper.defaultColorForGender(genre);
    final bool isBoy = genre == 'Garçon';
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
                      child: ClipOval(
                        child: enfant['photoUrl'] != null &&
                                enfant['photoUrl'].isNotEmpty
                            ? Image.network(
                                enfant['photoUrl'],
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildFallbackAvatar(enfant['prenom']),
                              )
                            : _buildFallbackAvatar(enfant['prenom']),
                      ),
                    ),
                  ],
                ),

                SizedBox(width: 16), // Informations de l'enfant
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enfant['prenom'],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4),
                      _buildPresenceBadge(enfant['presenceStatus']),
                    ],
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
                      onPressed: () => _showAddTransmissionPopup(enfant['id']),
                      tooltip: "Ajouter une transmission",
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
                  // Liste des transmissions (directement, sans SizedBox)
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('structures')
                          .doc(enfant['structureId'] ??
                              FirebaseAuth.instance.currentUser?.uid)
                          .collection('children')
                          .doc(enfant['id'])
                          .collection('transmissions')
                          .where('date',
                              isGreaterThanOrEqualTo: DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                              ))
                          .where('date',
                              isLessThan: DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                              ).add(Duration(days: 1)))
                          .orderBy('date', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: Text(
                              "Chargement des transmissions...",
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
                                  Icons.share_arrival_time,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "Aucune transmission récente",
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
                            final transmissionData = {
                              ...doc.data() as Map<String, dynamic>,
                              'id': doc.id,
                              'childId': enfant['id'],
                              'structureId': enfant['structureId'] ??
                                  FirebaseAuth.instance.currentUser?.uid,
                            };

                            return GestureDetector(
                              onTap: () => _showTransmissionDetailsPopup(
                                  transmissionData),
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
                                        transmissionData['heure'] ?? "08:30",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Row(
                                      children: [
                                        Icon(
                                            _getCategoryIcon(
                                                transmissionData['category']),
                                            color: primaryBlue,
                                            size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          transmissionData['category'] ??
                                              "Général",
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
