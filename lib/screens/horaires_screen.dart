import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../planning/planning_models.dart';
import '../utils/planning_helper.dart';
import '../utils/child_avatar_color_helper.dart';
import '../utils/structure_context.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/date_selector.dart';

class HorairesScreen extends StatefulWidget {
  @override
  _HorairesScreenState createState() => _HorairesScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _HorairesScreenState extends State<HorairesScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String _rebuildKey =
      DateTime.now().millisecondsSinceEpoch.toString(); // NOUVELLE LIGNE
  StructureContext? _structureContext;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Utiliser les couleurs officielles partout
  Color primaryColor = Color(0xFF3D9DF2); // primaryBlue par défaut
  Color secondaryColor = Color(0xFFDFE9F2); // lightBlue par défaut

  String structureName = "Chargement...";
  int _selectedIndex = 1;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR').then((_) => _loadStructureData());
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = isTablet(context);

    return SwipeNavigationWrapper(
      backRoute: '/home',
      child: Scaffold(
        key: Key(_rebuildKey), // FORCE LE REBUILD COMPLET
        backgroundColor: Colors.white,
        body: Column(
          children: [
            CommonAppBar(
              title: 'Horaires',
              structureName: structureName,
              iconPath: 'assets/images/Icone_horaire.png',
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
                  : _buildChildrenContent(isTabletDevice),
            )
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildChildrenContent(bool isTabletDevice) {
    final List<Map<String, dynamic>> presentChildren =
        enfants.where((child) => child['absent'] != true).toList();
    final List<Map<String, dynamic>> absentChildren =
        enfants.where((child) => child['absent'] == true).toList();

    if (presentChildren.isEmpty && absentChildren.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (presentChildren.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              isTabletDevice ? 22 : 18,
              'Enfants présents',
            ),
          ),
        if (presentChildren.isNotEmpty)
          SliverToBoxAdapter(
            child: isTabletDevice
                ? _buildChildrenGridForTablet(
                    presentChildren,
                    embedded: true,
                  )
                : _buildChildrenGrid(
                    presentChildren,
                    embedded: true,
                  ),
          ),
        if (absentChildren.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              isTabletDevice ? 22 : 18,
              'Absents du jour',
            ),
          ),
        if (absentChildren.isNotEmpty)
          SliverToBoxAdapter(
            child: isTabletDevice
                ? _buildChildrenGridForTablet(
                    absentChildren,
                    embedded: true,
                  )
                : _buildChildrenGrid(
                    absentChildren,
                    embedded: true,
                  ),
          ),
        SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _buildSectionHeader(double fontSize, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  // === MÉTHODES DE LOGIQUE MÉTIER ===

  // NOUVELLE MÉTHODE : Annuler l'absence
  void _annulerAbsent(Map<String, dynamic> enfant) {
    print("🟠 DEBUG: Annulation absence pour ${enfant['prenom']}");
    final now = DateTime.now();
    // Utiliser la date sélectionnée pour l'action mais garder l'heure précise pour l'audit
    final actionTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    setState(() {
      enfant['absent'] = false;
      // Garder les segments tels qu'ils étaient avant l'absence
    });

    // Mettre à jour en base de données en supprimant l'absence
    Map<String, dynamic> horairesData = {
      'prenom': enfant['prenom'],
      'actionType': 'annuler_absent',
      'actionType': 'annuler_absent',
      'exactTime': actionTime,
      'absent': false,
      'segments': enfant['segments'],
    };

    _updateHoraires(enfant['id'], horairesData).then((_) {
      // Force un rechargement complet des données et un rebuild total
      print(
          "✅ Annulation absence enregistrée, rechargement complet des données pour ${enfant['prenom']}");
      print("🔄 État avant rechargement: absent=${enfant['absent']}");
      _rebuildKey =
          DateTime.now().millisecondsSinceEpoch.toString(); // Nouvelle clé
      _loadEnfantsDuJour(); // Recharge complètement les données depuis Firebase
    });
  }

  // NOUVELLE MÉTHODE : Dialog pour modifier un horaire manuellement
  void _showEditTimeDialog(
      String type, Map<String, dynamic> enfant, int segmentIndex) {
    List<dynamic> segments = enfant['segments'];
    if (segmentIndex >= segments.length) return;

    Map<String, dynamic> segment = segments[segmentIndex];
    String currentTime = segment[type] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController timeController =
            TextEditingController(text: currentTime);

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Modifier l\'heure ${type == 'arrivee' ? 'd\'arrivée' : 'de départ'}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  '${enfant['prenom']}',
                  style: TextStyle(
                      fontSize: 16,
                      color: primaryColor,
                      fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 24),
                TextField(
                  controller: timeController,
                  decoration: InputDecoration(
                    hintText: 'HH:MM (ex: 08:30)',
                    filled: true,
                    fillColor: secondaryColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: Icon(Icons.access_time, color: primaryColor),
                  ),
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                  ],
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    ElevatedButton(
                      child: Text(
                        'Enregistrer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 2,
                      ),
                      onPressed: () {
                        String newTime = timeController.text.trim();

                        // Validation du format HH:MM
                        RegExp timeRegex =
                            RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
                        if (newTime.isEmpty || !timeRegex.hasMatch(newTime)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Format d\'heure invalide. Utilisez HH:MM (ex: 08:30)'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.of(context).pop();
                        _modifierHeure(type, enfant, segmentIndex, newTime);
                      },
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

  // NOUVELLE MÉTHODE : Modifier un horaire existant
  void _modifierHeure(String type, Map<String, dynamic> enfant,
      int segmentIndex, String newTime) {
    List<dynamic> segments = enfant['segments'];
    if (segmentIndex >= segments.length) return;

    Map<String, dynamic> segment = segments[segmentIndex];

    setState(() {
      segment[type] = newTime;

      // Si on modifie une arrivée, l'enfant n'est pas absent
      if (type == 'arrivee') {
        enfant['absent'] = false;
      }
    });

    Map<String, dynamic> horairesData = {
      'prenom': enfant['prenom'],
      'actionType': '${type}_modifiee',
      'exactTime': DateTime.now(), // Garde l'heure de modification réelle
      'heure': newTime,
      'segments': List<Map<String, dynamic>>.from(segments),
    };

    // Pour l'arrivée modifiée, on enregistre directement
    if (type == 'arrivee') {
      _updateHoraires(enfant['id'], horairesData);
    }
    // Pour le départ modifié, on demande les km si pas encore renseignés
    else if (type == 'depart') {
      // Vérifier si les km sont déjà enregistrés pour ce segment
      bool kmDejaEnregistres = segment['km'] != null;

      if (kmDejaEnregistres) {
        _updateHoraires(enfant['id'], horairesData);
      } else {
        _showKilometersDialog(enfant, horairesData, segmentIndex);
      }
    }
  }

  Future<void> _loadStructureData() async {
    try {
      setState(() => isLoading = true);

      final structureContext = await StructureResolver().resolve();
      _structureContext = structureContext;
      String resolvedName = structureContext.structureName;
      if (resolvedName.trim().isEmpty) {
        resolvedName = 'Structure inconnue';
      }

      setState(() {
        structureName = resolvedName;
      });

      // Continuer avec le chargement des enfants
      await _loadEnfantsDuJour();
    } catch (e) {
      print("Erreur de chargement des données de structure: $e");
      setState(() {
        structureName = 'Structure introuvable';
        isLoading = false;
      });
    }
  }

  Future<void> _loadEnfantsDuJour() async {
    try {
      final structureContext =
          _structureContext ?? await StructureResolver().resolve();
      _structureContext = structureContext;

      final String structureId = structureContext.structureId;
      final String currentUserEmail = structureContext.currentUserEmail;
      final today = _selectedDate; // Utiliser la date sélectionnée
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      final String structureType = structureContext.normalizedStructureType;
      final bool allowAllChildren = structureContext.showAllChildren;

      // Récupérer tous les enfants de la structure avec le bon ID de structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(
              structureId) // IMPORTANT: Utiliser structureId au lieu de user.uid
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
              "👨‍👧‍👦 Membre MAM: affichage de tous les enfants de la structure");
        } else {
          filteredChildren = allChildren.where((child) {
            String assignedEmail =
                child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
            return assignedEmail == currentUserEmail;
          }).toList();

          print(
              "👨‍👧‍👦 Membre MAM: affichage de ${filteredChildren.length} enfant(s) assigné(s)");
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
                print('➕ Horaires: ajout enfants délégués: ${toAddIds.length}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Horaires: erreur overlay délégation: $e');
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Assistante Maternelle individuelle: affichage de tous les enfants");
      }

      final bool useMamColors = structureType == 'mam';
      Map<String, Color> mamColorAssignments = {};
      if (useMamColors) {
        mamColorAssignments =
            ChildAvatarColorHelper.buildMamAssignmentsFromChildren(
                filteredChildren);
      }

      // Diagnostic des enfants filtrés
      print(
          "🔍 DIAGNOSTIC HORAIRES - Type de structure: $structureType, Utilisateur: $currentUserEmail");
      print(
          "🔍 DIAGNOSTIC HORAIRES - Nombre total d'enfants: ${allChildren.length}, Nombre filtrés: ${filteredChildren.length}");

      // Diagnostic détaillé de chaque enfant
      for (var child in allChildren) {
        String assignedEmail =
            child['assignedMemberEmail']?.toString().toLowerCase() ??
                'NON ASSIGNÉ';
        bool isVisible =
            structureType != 'mam' || assignedEmail == currentUserEmail;
        print(
            "  👶 ID: ${child['id']}, Nom: ${child['firstName']}, Assigné à : '$assignedEmail', Visible: ${isVisible ? 'OUI' : 'NON'}");
      }

      // Récupérer les horaires enregistrés pour la date sélectionnée
      final dateActuelle = DateFormat('yyyy-MM-dd').format(today);
      final horairesSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(
              structureId) // CORRECTION: Utiliser structureId au lieu de user?.uid
          .collection('horaires')
          .doc(dateActuelle)
          .get();

      Map<String, dynamic> horairesDuJour = {};
      if (horairesSnapshot.exists) {
        horairesDuJour = horairesSnapshot.data() ?? {};
      }

      // Maintenant, traiter uniquement les enfants filtrés pour aujourd'hui
      List<Map<String, dynamic>> tempEnfants = [];
      for (var child in filteredChildren) {
        // Enfant en congé ce jour-là : ne pas l'afficher du tout
        final Map<String, dynamic>? horaireDuJourEnfant =
            horairesDuJour[child['id']] as Map<String, dynamic>?;
        if (horaireDuJourEnfant != null &&
            horaireDuJourEnfant['actionType'] == 'conge') {
          continue;
        }
        // Vérifier si l'enfant a un programme pour aujourd'hui
        final List<TimeSlot> plannedSlots =
            PlanningHelper.resolveSlotsForDate(child, today);
        final isScheduledToday = plannedSlots.isNotEmpty;
        final isDelegatedToday = delegatedTodayChildIds.contains(child['id']);
        if (isScheduledToday || isDelegatedToday) {
          final String assignedEmail =
              ChildAvatarColorHelper.normalizeEmail(
                  child['assignedMemberEmail']);
          final Color avatarColor = ChildAvatarColorHelper.resolveAvatarColor(
            isMamStructure: useMamColors,
            mamAssignments: mamColorAssignments,
            assignedMemberEmail: assignedEmail,
            gender: child['gender']?.toString(),
          );
          String? photoUrl = child['photoUrl'];

          // Pour chaque enfant prévu aujourd'hui, créer une entrée dans la liste
          Map<String, dynamic> horaireEnfant = {
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'assignedMemberEmail': assignedEmail,
            'avatarColor': avatarColor,
            'segments':
                [], // Stockera les statuts des différents segments horaires
            'absent': false,
          };

          // Récupérer les horaires planifiés pour aujourd'hui
          // Créer une entrée pour chaque segment horaire
          List<Map<String, dynamic>> segmentsInfo = [];
          for (var i = 0; i < plannedSlots.length; i++) {
            final slot = plannedSlots[i];
            Map<String, dynamic> segmentInfo = {
              'index': i,
              'start': slot.start,
              'end': slot.end,
              'arrivee': null,
              'depart': null,
              // On ajoute les heures planifiées pour l'affichage
              'heureDebut': slot.start,
              'heureFin': slot.end,
            };
            segmentsInfo.add(segmentInfo);
          }

          // Récupérer les horaires déjà enregistrés aujourd'hui
          if (horairesDuJour.containsKey(child['id'])) {
            final horaire = horairesDuJour[child['id']];
            print(
                "🔍 DEBUG: Données Firebase pour ${child['firstName']}: actionType='${horaire['actionType']}', absent=${horaire['absent']}");

            // Si l'enfant est marqué absent, on met à jour le statut
            if (horaire['actionType'] == 'absent') {
              horaireEnfant['absent'] = true;
              print(
                  "✅ Enfant ${child['firstName']} marqué absent depuis Firebase");
            }
            // Si l'action est 'annuler_absent', l'enfant n'est pas absent
            else if (horaire['actionType'] == 'annuler_absent') {
              horaireEnfant['absent'] = false;
              print(
                  "✅ Enfant ${child['firstName']} marqué présent depuis Firebase");
            }
            // Sinon, on récupère les heures d'arrivée/départ pour chaque segment
            else if (horaire['segments'] != null) {
              List<dynamic> segmentsEnregistres = horaire['segments'];
              for (var segmentEnregistre in segmentsEnregistres) {
                int index = segmentEnregistre['index'];
                if (index < segmentsInfo.length) {
                  if (segmentEnregistre['arrivee'] != null) {
                    segmentsInfo[index]['arrivee'] =
                        segmentEnregistre['arrivee'];
                  }
                  if (segmentEnregistre['depart'] != null) {
                    segmentsInfo[index]['depart'] = segmentEnregistre['depart'];
                  }
                }
              }
            }
            // Compatibilité avec l'ancien format (un seul segment)
            else if (horaire['arrivee'] != null || horaire['depart'] != null) {
              if (segmentsInfo.isNotEmpty) {
                segmentsInfo[0]['arrivee'] = horaire['arrivee'];
                segmentsInfo[0]['depart'] = horaire['depart'];
              }
            }
          }

          horaireEnfant['segments'] = segmentsInfo;
          tempEnfants.add(horaireEnfant);
        }
      }

      setState(() {
        enfants = tempEnfants;
        isLoading = false;
      });

      // Debug final pour vérifier l'état des enfants chargés
      for (var enfant in enfants) {
        print(
            "🏁 FINAL: Enfant ${enfant['prenom']} - absent=${enfant['absent']}");
      }

      // Force un rebuild avec un délai minimal
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
        if (mounted) {
          print("🔄 FORCE REBUILD après délai");
          _rebuildKey = DateTime.now().millisecondsSinceEpoch.toString();
          if (mounted) setState(() {});
        }
        }
      });
    } catch (e) {
      print("Erreur de chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateHoraires(
      String childId, Map<String, dynamic> horaires) async {
    try {
      final structureContext =
          _structureContext ?? await StructureResolver().resolve();
      _structureContext = structureContext;
      final String structureId = structureContext.structureId;
      final String currentUserEmail = structureContext.currentUserEmail;
      final now = DateTime.now();
      // Utiliser la date sélectionnée pour le document
      final dateActuelle = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final String actionType = (horaires['actionType'] ?? '').toString();
      if (!horaires.containsKey('absent')) {
        horaires['absent'] = actionType == 'absent' ? true : false;
      } else if (actionType != 'absent' && horaires['absent'] == null) {
        horaires['absent'] = false;
      }

      horaires['timestamp'] = now;
      horaires['childId'] = childId;
      horaires['date'] = dateActuelle;
      horaires['userEmail'] = currentUserEmail; // Ajouté pour traçabilité

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // IMPORTANT: Utiliser structureId!
          .collection('horaires')
          .doc(dateActuelle)
          .set({childId: horaires}, SetOptions(merge: true));

      // Ajout de l'historique des km (uniquement si km est présent)
      if (horaires.containsKey('km') && horaires['km'] != null) {
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId) // IMPORTANT: Utiliser structureId!
            .collection('km_history')
            .add({
          'childId': childId,
          'date': dateActuelle,
          'km': horaires['km'],
          'timestamp': now,
          'userEmail': currentUserEmail, // Ajouté pour traçabilité
        });
      }

      // CORRECTION: Utiliser structureId au lieu de user?.uid
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // IMPORTANT: Utiliser structureId!
          .collection('horaires_history')
          .add({
        'childId': childId,
        'date': dateActuelle,
        'timestamp': now,
        'userEmail': currentUserEmail, // Ajouté pour traçabilité
        ...horaires,
      });

      print(
          "Horaires enregistrés avec succès dans la structure ID: $structureId !");
    } catch (e) {
      print("Erreur mise à jour horaires: $e");
      throw e;
    }
  }

  void _enregistrerHeure(
      String type, Map<String, dynamic> enfant, int segmentIndex) {
    // Récupérer le segment spécifique
    List<dynamic> segments = enfant['segments'];
    if (segmentIndex >= segments.length) return;

    Map<String, dynamic> segment = segments[segmentIndex];

    final now = DateTime.now();
    // Si c'est pour une date passée, on garde l'heure actuelle de saisie comme valeur par défaut
    // mais on pourrait vouloir forcer une heure cohérente.
    // Pour l'instant on prend l'heure actuelle système comme heure de l'événement
    final currentTime = DateFormat('HH:mm').format(now);

    setState(() {
      // Mettre à jour le segment spécifique
      segment[type] = currentTime;

      // Si on enregistre une arrivée, l'enfant n'est pas absent
      if (type == 'arrivee') {
        enfant['absent'] = false;
      }
    });

    Map<String, dynamic> horairesData = {
      'prenom': enfant['prenom'],
      'actionType': type,
      'exactTime': now, // Timestamp de l'action réelle
      'heure': currentTime,
      'segments': List<Map<String, dynamic>>.from(segments),
    };

    // Pour l'arrivée, on enregistre directement sans demander les km
    if (type == 'arrivee') {
      _updateHoraires(enfant['id'], horairesData);
    }
    // Pour le départ, on demande les km
    else if (type == 'depart') {
      _showKilometersDialog(enfant, horairesData, segmentIndex);
    }
  }

  void _showKilometersDialog(Map<String, dynamic> enfant,
      Map<String, dynamic> horairesData, int segmentIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        TextEditingController kmController = TextEditingController();
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kilomètres parcourus aujourd\'hui',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: primaryColor),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Uniquement si vous avez effectué un trajet avec ${enfant['prenom']} aujourd\'hui',
                          style: TextStyle(
                              fontSize: 14,
                              color: primaryColor.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                TextField(
                  controller: kmController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Laisser vide si pas de trajet',
                    filled: true,
                    fillColor: secondaryColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: Icon(Icons.directions_car, color: primaryColor),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      child: Text(
                        'Enregistrer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 2,
                      ),
                      onPressed: () {
                        if (kmController.text.isNotEmpty) {
                          horairesData['km'] = int.parse(kmController.text);
                          // Enregistrer les km pour le segment spécifique
                          List<dynamic> segments = horairesData['segments'];
                          if (segmentIndex < segments.length) {
                            segments[segmentIndex]['km'] =
                                int.parse(kmController.text);
                          }
                        }
                        Navigator.of(context).pop();
                        _updateHoraires(enfant['id'], horairesData);
                      },
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

  void _marquerAbsent(Map<String, dynamic> enfant) {
    print("🔴 DEBUG: Marquage absent pour ${enfant['prenom']}");
    final now = DateTime.now();

    setState(() {
      enfant['absent'] = true;
      // Réinitialiser tous les segments
      for (var segment in enfant['segments']) {
        segment['arrivee'] = null;
        segment['depart'] = null;
      }
    });

    Map<String, dynamic> horairesData = {
      'prenom': enfant['prenom'],
      'actionType': 'absent',
      'exactTime': now,
      'absent': true,
      'segments': enfant['segments'],
    };

    _updateHoraires(enfant['id'], horairesData).then((_) {
      // Force un rechargement complet des données et un rebuild total
      print(
          "✅ Firebase enregistré, rechargement complet des données pour ${enfant['prenom']}");
      print("🔄 État avant rechargement: absent=${enfant['absent']}");
      _rebuildKey =
          DateTime.now().millisecondsSinceEpoch.toString(); // Nouvelle clé
      _loadEnfantsDuJour(); // Recharge complètement les données depuis Firebase
    });
  }

  void _openExistingTimeOptions(
      String type, Map<String, dynamic> enfant, int segmentIndex) {
    final bool isTabletDevice = isTablet(context);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: isTabletDevice ? 24 : 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.edit, color: primaryColor),
                  title: Text(
                    'Modifier l\'heure',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showEditTimeDialog(type, enfant, segmentIndex);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: primaryRed),
                  title: Text(
                    'Supprimer l\'horaire',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryRed,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDeleteTime(type, enfant, segmentIndex);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteTime(
      String type, Map<String, dynamic> enfant, int segmentIndex) async {
    final String label =
        type == 'arrivee' ? 'l\'heure d\'arrivée' : 'l\'heure de départ';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Supprimer $label ?'),
          content: Text(
            'Cette action effacera l\'horaire enregistré pour ${enfant['prenom']}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _supprimerHeure(type, enfant, segmentIndex);
    }
  }

  Future<void> _supprimerHeure(
      String type, Map<String, dynamic> enfant, int segmentIndex) async {
    List<dynamic> segments = enfant['segments'];
    if (segmentIndex >= segments.length) return;

    final Map<String, dynamic> segment =
        Map<String, dynamic>.from(segments[segmentIndex]);

    if (!segment.containsKey(type) || segment[type] == null) {
      return;
    }

    final now = DateTime.now();

    setState(() {
      segments[segmentIndex][type] = null;

      if (type == 'arrivee') {
        // Si plus aucune heure enregistrée, on laisse la possibilité de marquer absent
        bool hasAnyTimeRecorded = false;
        for (final seg in segments) {
          final segMap = seg as Map<String, dynamic>;
          if ((segMap['arrivee'] ?? '').toString().isNotEmpty ||
              (segMap['depart'] ?? '').toString().isNotEmpty) {
            hasAnyTimeRecorded = true;
            break;
          }
        }
        if (!hasAnyTimeRecorded) {
          enfant['absent'] = false;
        }
      }
    });

    final List<Map<String, dynamic>> segmentsCopy =
        segments.map<Map<String, dynamic>>((segment) {
      return Map<String, dynamic>.from(segment as Map<String, dynamic>);
    }).toList();

    final Map<String, dynamic> horairesData = {
      'prenom': enfant['prenom'],
      'actionType': 'supprimer_$type',
      'exactTime': now,
      'heure': null,
      'segments': segmentsCopy,
    };

    await _updateHoraires(enfant['id'], horairesData);
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

  // === MÉTHODES POUR IPAD ===

  // Nouvelle méthode pour la grille adaptée à l'iPad
  // Nouvelle méthode pour la grille adaptée à l'iPad
  Widget _buildChildrenGridForTablet(List<Map<String, dynamic>> data,
      {bool embedded = false}) {
    // Détecter l'orientation
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return GridView.builder(
      padding: EdgeInsets.all(20),
      shrinkWrap: embedded,
      physics: embedded ? NeverScrollableScrollPhysics() : null,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            isLandscape ? 3 : 2, // 3 colonnes en paysage, 2 en portrait
        childAspectRatio: isLandscape ? 0.75 : 0.85, // Plus compact en paysage
        crossAxisSpacing: isLandscape ? 16 : 24, // Espacement adapté
        mainAxisSpacing: isLandscape ? 16 : 24,
      ),
      itemCount: data.length,
      itemBuilder: (context, index) =>
          _buildEnfantCardForTablet(context, index, source: data),
    );
  }

  // Nouvelle méthode pour la carte enfant adaptée à l'iPad
  Widget _buildEnfantCardForTablet(BuildContext context, int index,
      {List<Map<String, dynamic>>? source}) {
    final list = source ?? enfants;
    final enfant = list[index];
    final isAbsent = enfant['absent'] == true;
    final genre = enfant['genre']?.toString() ?? 'Garçon';
    final hasMultipleSegments = enfant['segments'].length > 1;

    // ✅ Détecter l'orientation AVANT les fonctions locales
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // ✅ Calculer les couleurs directement (pas de fonctions locales)
    final cardColor = isAbsent ? Colors.grey.shade200 : Colors.white;
    final Color avatarColor = (enfant['avatarColor'] as Color?) ??
        ChildAvatarColorHelper.defaultColorForGender(genre);
    final textColor = isAbsent ? Colors.grey : avatarColor;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
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
          Padding(
            padding: EdgeInsets.only(
              top: isLandscape ? 16 : 24,
              bottom: isLandscape ? 6 : 12,
            ),
            child: _buildChildAvatar(
              enfant,
              size: isLandscape ? 110 : 120,
            ),
          ),

          // Contenu de la carte - ADAPTÉ selon orientation
          Expanded(
            flex: isLandscape ? 65 : 60,
            child: Padding(
              padding: EdgeInsets.all(isLandscape ? 12.0 : 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: isLandscape ? 20.0 : 24.0,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isLandscape ? 6.0 : 10.0),
                  if (isAbsent)
                    Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: isLandscape ? 6.0 : 12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Absent aujourd\'hui',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                              fontSize: isLandscape ? 14.0 : 18.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isLandscape ? 10.0 : 16.0),
                          Center(child: _buildAbsentButtonForTablet(enfant)),
                        ],
                      ),
                    )
                  else if (hasMultipleSegments) ...[
                    Expanded(
                      child: _buildSegmentsListForTablet(enfant),
                    ),
                  ] else ...[
                    _buildSimpleSegmentForTablet(
                        enfant, enfant['segments'][0], 0),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour un seul segment adapté à l'iPad
  Widget _buildSimpleSegmentForTablet(Map<String, dynamic> enfant,
      Map<String, dynamic> segment, int segmentIndex) {
    // ✅ AJOUTER : Détecter l'orientation dans CETTE méthode
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (segment['heureDebut'] != null && segment['heureFin'] != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                vertical: isLandscape ? 6.0 : 10.0,
                horizontal: isLandscape ? 12.0 : 16.0),
            margin: EdgeInsets.only(bottom: isLandscape ? 10.0 : 16.0),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${segment['heureDebut']} - ${segment['heureFin']}',
              style: TextStyle(
                fontSize: isLandscape ? 16.0 : 20.0,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(height: isLandscape ? 6.0 : 10.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTimeButtonForTablet(
              'Arrivée',
              segment['arrivee'],
              () => _enregistrerHeure('arrivee', enfant, segmentIndex),
              enfant,
              segmentIndex,
              'arrivee',
            ),
            _buildTimeButtonForTablet(
              'Départ',
              segment['depart'],
              () => _enregistrerHeure('depart', enfant, segmentIndex),
              enfant,
              segmentIndex,
              'depart',
            ),
          ],
        ),
        if (segment['arrivee'] != null || segment['depart'] != null)
          Padding(
            padding: EdgeInsets.only(top: isLandscape ? 4.0 : 8.0),
            child: Text(
              'Appuyez sur l\'heure pour modifier ou supprimer',
              style: TextStyle(
                fontSize: isLandscape ? 11.0 : 14.0,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(height: isLandscape ? 10.0 : 16.0),
        _buildAbsentButtonForTablet(enfant),
      ],
    );
  }

  // Liste des segments pour iPad
  Widget _buildSegmentsListForTablet(Map<String, dynamic> enfant) {
    List<dynamic> segments = enfant['segments'];

    if (segments.isEmpty) {
      return Center(
        child: Text('Aucun horaire défini',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18, // Plus grand pour iPad
            )),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 0),
      shrinkWrap: true,
      itemCount: segments.length + 1, // +1 pour le bouton absent en bas
      itemBuilder: (context, index) {
        if (index == segments.length) {
          return Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(child: _buildAbsentButtonForTablet(enfant)),
          );
        }

        Map<String, dynamic> segment = segments[index];
        bool isLastSegment = index == segments.length - 1;
        return _buildSegmentItemForTablet(
            enfant, segment, index, isLastSegment);
      },
    );
  }

  // Élément de segment adapté pour iPad
  // Élément de segment adapté pour iPad
  Widget _buildSegmentItemForTablet(Map<String, dynamic> enfant,
      Map<String, dynamic> segment, int segmentIndex, bool isLastSegment) {
    // ✅ AJOUTER : Détecter l'orientation dans CETTE méthode
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    String heureDebut = segment['heureDebut'] ?? '--:--';
    String heureFin = segment['heureFin'] ?? '--:--';

    return Padding(
      padding: EdgeInsets.only(bottom: isLastSegment ? 8.0 : 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                vertical: isLandscape ? 6.0 : 8.0,
                horizontal: isLandscape ? 10.0 : 12.0),
            margin: EdgeInsets.only(bottom: isLandscape ? 6.0 : 8.0),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Créneau ${segmentIndex + 1}: $heureDebut - $heureFin',
              style: TextStyle(
                fontSize: isLandscape ? 14.0 : 16.0,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isLandscape ? 6.0 : 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeButtonForTablet(
                'Arrivée',
                segment['arrivee'],
                () => _enregistrerHeure('arrivee', enfant, segmentIndex),
                enfant,
                segmentIndex,
                'arrivee',
              ),
              _buildTimeButtonForTablet(
                'Départ',
                segment['depart'],
                () => _enregistrerHeure('depart', enfant, segmentIndex),
                enfant,
                segmentIndex,
                'depart',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bouton horaire iPad avec menu d'options (modifier/supprimer)
  Widget _buildTimeButtonForTablet(
      String label,
      String? time,
      VoidCallback onPressed,
      Map<String, dynamic> enfant,
      int segmentIndex,
      String type) {
    // ✅ AJOUTER : Détecter l'orientation dans CETTE méthode
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    bool isDisabled = (type == 'depart' &&
        time == null &&
        enfant['segments'][segmentIndex]['arrivee'] == null &&
        !enfant['absent']);

    return SizedBox(
      width: isLandscape ? 85.0 : 100.0,
      height: isLandscape ? 38.0 : 44.0,
      child: time != null
          ? ElevatedButton(
              onPressed: () =>
                  _openExistingTimeOptions(type, enfant, segmentIndex),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor.withOpacity(0.85),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding:
                    EdgeInsets.symmetric(horizontal: isLandscape ? 8.0 : 12.0),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: isLandscape ? 14.0 : 16.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: isDisabled ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDisabled ? Colors.grey[300] : primaryColor,
                disabledBackgroundColor: Colors.grey[300],
                elevation: isDisabled ? 0 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding:
                    EdgeInsets.symmetric(horizontal: isLandscape ? 8.0 : 12.0),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isLandscape ? 14.0 : 16.0,
                  fontWeight: FontWeight.w600,
                  color: isDisabled ? Colors.grey[500] : Colors.white,
                ),
              ),
            ),
    );
  }

  // BOUTON ABSENT pour iPad avec possibilité d'annulation
  // BOUTON ABSENT pour iPad avec possibilité d'annulation
  Widget _buildAbsentButtonForTablet(Map<String, dynamic> enfant) {
    bool aucunHoraireEnregistre = true;
    for (var segment in enfant['segments']) {
      if (segment['arrivee'] != null || segment['depart'] != null) {
        aucunHoraireEnregistre = false;
        break;
      }
    }

    print(
        "🔍 DEBUG _buildAbsentButtonForTablet() appelée - Enfant ${enfant['prenom']}: absent=${enfant['absent']}, aucunHoraire=$aucunHoraireEnregistre");

    // Si l'enfant est déjà marqué absent, montrer le bouton pour annuler
    if (enfant['absent'] == true) {
      print(
          "🟠 CRÉATION du bouton Annuler Absent TABLET pour ${enfant['prenom']}");
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 200),
        height: 44,
        child: ElevatedButton(
          onPressed: () {
            print(
                "🟠 Bouton Annuler Absent (iPad) pressé pour ${enfant['prenom']}");
            _annulerAbsent(enfant);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(
            'Annuler Absent',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (aucunHoraireEnregistre) {
      // Bouton pour marquer absent
      print("🔴 CRÉATION du bouton Absent TABLET pour ${enfant['prenom']}");
      return SizedBox(
        width: 120,
        height: 44,
        child: ElevatedButton(
          onPressed: () {
            print("🔴 Bouton Absent (iPad) pressé pour ${enfant['prenom']}");
            _marquerAbsent(enfant);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(
            'Absent',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    print(
        "🚫 Aucun bouton TABLET créé pour ${enfant['prenom']} (horaire déjà enregistré)");
    return Container();
  }

  // === MÉTHODES POUR IPHONE ===

  // AppBar personnalisé avec gradient
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

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_horaire.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.child_care,
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

  // Grille des enfants
  Widget _buildChildrenGrid(List<Map<String, dynamic>> data,
      {bool embedded = false}) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shrinkWrap: embedded,
      physics: embedded ? NeverScrollableScrollPhysics() : null,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
      ),
      itemCount: data.length,
      itemBuilder: (context, index) =>
          _buildEnfantCard(context, index, source: data),
    );
  }

  // Widget pour afficher une carte enfant
  Widget _buildEnfantCard(BuildContext context, int index,
      {List<Map<String, dynamic>>? source}) {
    final list = source ?? enfants;
    final enfant = list[index];
    bool isAbsent = enfant['absent'] == true;
    String genre = enfant['genre']?.toString() ?? 'Garçon';
    bool hasMultipleSegments = enfant['segments'].length > 1;
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    print(
        "🏗️ DEBUG _buildEnfantCard() pour ${enfant['prenom']}: absent=$isAbsent, multipleSegments=$hasMultipleSegments");

    final Color avatarColor = (enfant['avatarColor'] as Color?) ??
        ChildAvatarColorHelper.defaultColorForGender(genre);

    Color getCardColor() {
      if (isAbsent) return Colors.grey.shade200;
      return Colors.white;
    }

    Color getTextColor() {
      if (isAbsent) return Colors.grey;
      return avatarColor;
    }

    return Container(
      decoration: BoxDecoration(
        color: getCardColor(),
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
          Padding(
            padding: EdgeInsets.only(
              top: isLandscape ? 16 : 20,
              bottom: isLandscape ? 6 : 12,
            ),
            child: _buildChildAvatar(
              enfant,
              size: isLandscape ? 88 : 98,
            ),
          ),

          Expanded(
            flex: hasMultipleSegments ? 65 : 55,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: hasMultipleSegments
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: getTextColor(),
                    ),
                  ),
                  SizedBox(height: 10),
                  if (isAbsent)
                    Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Absent aujourd\'hui',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        _buildAbsentButton(
                            enfant), // AJOUT DU BOUTON MÊME QUAND ABSENT
                      ],
                    )
                  else if (hasMultipleSegments)
                    Expanded(
                      child: _buildSegmentsList(enfant),
                    )
                  else
                    _buildSimpleSegment(enfant, enfant['segments'][0], 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildAvatar(Map<String, dynamic> enfant,
      {double size = 96.0}) {
    final Color ringColor = (enfant['avatarColor'] as Color?) ??
        ChildAvatarColorHelper.defaultColorForGender(
            enfant['genre']?.toString());
    final String prenom = (enfant['prenom'] ?? '').toString();
    final dynamic rawPhoto = enfant['photoUrl'];
    final String photoUrl = rawPhoto is String ? rawPhoto.trim() : '';

    Widget imageWidget;
    if (photoUrl.isNotEmpty) {
      imageWidget = Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _buildAvatarInitials(prenom, ringColor),
      );
    } else {
      imageWidget = _buildAvatarInitials(prenom, ringColor);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            ringColor.withOpacity(0.85),
            ringColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ringColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: imageWidget,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarInitials(String prenom, Color color) {
    final String initial =
        (prenom.isNotEmpty ? prenom[0] : '?').toUpperCase();
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // Widget pour un seul segment
  Widget _buildSimpleSegment(Map<String, dynamic> enfant,
      Map<String, dynamic> segment, int segmentIndex) {
    print(
        "🔧 DEBUG _buildSimpleSegment() pour ${enfant['prenom']}: absent=${enfant['absent']}");

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (segment['heureDebut'] != null && segment['heureFin'] != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${segment['heureDebut']} - ${segment['heureFin']}',
              style: TextStyle(
                fontSize: 14,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTimeButton(
              'Arrivée',
              segment['arrivee'],
              () => _enregistrerHeure('arrivee', enfant, segmentIndex),
              enfant,
              segmentIndex,
              'arrivee',
            ),
            _buildTimeButton(
              'Départ',
              segment['depart'],
              () => _enregistrerHeure('depart', enfant, segmentIndex),
              enfant,
              segmentIndex,
              'depart',
            ),
          ],
        ),
        // AJOUT : Indication pour la modification
        if (segment['arrivee'] != null || segment['depart'] != null)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Appuyez sur l\'heure pour modifier ou supprimer',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(height: 10),
        _buildAbsentButton(enfant),
      ],
    );
  }

  // Liste des segments pour les enfants avec plusieurs créneaux
  Widget _buildSegmentsList(Map<String, dynamic> enfant) {
    List<dynamic> segments = enfant['segments'];

    if (segments.isEmpty) {
      return Center(
        child:
            Text('Aucun horaire défini', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 0),
      shrinkWrap: true,
      itemCount: segments.length + 1, // +1 pour le bouton absent en bas
      itemBuilder: (context, index) {
        // Le dernier élément est pour le bouton "Absent"
        if (index == segments.length) {
          return Padding(
            padding: EdgeInsets.only(top: 4),
            child: Center(child: _buildAbsentButton(enfant)),
          );
        }

        Map<String, dynamic> segment = segments[index];
        bool isLastSegment = index == segments.length - 1;
        return _buildSegmentItem(enfant, segment, index, isLastSegment);
      },
    );
  }

  Widget _buildSegmentItem(Map<String, dynamic> enfant,
      Map<String, dynamic> segment, int segmentIndex, bool isLastSegment) {
    String heureDebut = segment['heureDebut'] ?? '--:--';
    String heureFin = segment['heureFin'] ?? '--:--';

    return Padding(
      padding: EdgeInsets.only(bottom: isLastSegment ? 4 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            margin: EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Créneau ${segmentIndex + 1}: $heureDebut - $heureFin',
              style: TextStyle(
                fontSize: 12,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeButton(
                'Arrivée',
                segment['arrivee'],
                () => _enregistrerHeure('arrivee', enfant, segmentIndex),
                enfant,
                segmentIndex,
                'arrivee',
              ),
              _buildTimeButton(
                'Départ',
                segment['depart'],
                () => _enregistrerHeure('depart', enfant, segmentIndex),
                enfant,
                segmentIndex,
                'depart',
              ),
            ],
          ),
          // AJOUT : Indication pour la modification sur segments multiples
          if (segment['arrivee'] != null || segment['depart'] != null)
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Appuyez sur l\'heure pour modifier ou supprimer',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // Bouton horaire mobile avec menu d'options (modifier/supprimer)
  Widget _buildTimeButton(String label, String? time, VoidCallback onPressed,
      Map<String, dynamic> enfant, int segmentIndex, String type) {
    // CORRECTION: Ne plus désactiver les boutons quand l'enfant est absent
    // Permettre la modification même si absent
    bool isDisabled = (type == 'depart' &&
        time == null &&
        enfant['segments'][segmentIndex]['arrivee'] == null &&
        !enfant['absent']); // Seule condition de désactivation réelle

    return Expanded(
      // CHANGEMENT: Utiliser Expanded au lieu de SizedBox fixe
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 2), // Petit espacement entre les boutons
        child: SizedBox(
          height: 32,
          child: time != null
              ? ElevatedButton(
                  onPressed: () =>
                      _openExistingTimeOptions(type, enfant, segmentIndex),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor.withOpacity(0.85),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: isDisabled ? null : onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDisabled ? Colors.grey[300] : primaryColor,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: isDisabled ? 0 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(
                        horizontal: 4), // Réduire le padding horizontal
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown, // S'assurer que le texte s'adapte
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12, // Réduire légèrement la taille de police
                        fontWeight: FontWeight.w600,
                        color: isDisabled ? Colors.grey[500] : Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAbsentButton(Map<String, dynamic> enfant) {
    // Vérifier si aucun horaire n'a été enregistré
    bool aucunHoraireEnregistre = true;
    for (var segment in enfant['segments']) {
      if (segment['arrivee'] != null || segment['depart'] != null) {
        aucunHoraireEnregistre = false;
        break;
      }
    }

    print(
        "🔍 DEBUG _buildAbsentButton() appelée - Enfant ${enfant['prenom']}: absent=${enfant['absent']}, aucunHoraire=$aucunHoraireEnregistre");

    // Si l'enfant est déjà marqué absent, montrer le bouton pour annuler
    if (enfant['absent'] == true) {
      print("🟠 CRÉATION du bouton Annuler Absent pour ${enfant['prenom']}");
      return Container(
        width:
            double.infinity, // CHANGEMENT: Prendre toute la largeur disponible
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: 8), // Padding interne
        child: ElevatedButton(
          onPressed: () {
            print("🟠 Bouton Annuler Absent pressé pour ${enfant['prenom']}");
            _annulerAbsent(enfant);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange, // Couleur différente pour "Annuler"
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.symmetric(horizontal: 4), // Réduire le padding
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Annuler Absent',
              maxLines: 1,
              softWrap:
                  false, // ← AJOUTER CETTE LIGNE pour empêcher le retour à la ligne
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    // Sinon, montrer le bouton Absent classique uniquement si aucun horaire enregistré
    if (aucunHoraireEnregistre) {
      print("🔴 CRÉATION du bouton Absent pour ${enfant['prenom']}");
      return Container(
        width:
            double.infinity, // CHANGEMENT: Prendre toute la largeur disponible
        height: 32,
        padding: EdgeInsets.symmetric(
            horizontal: 20), // Plus de padding pour centrer
        child: ElevatedButton(
          onPressed: () {
            print("🔴 Bouton Absent pressé pour ${enfant['prenom']}");
            _marquerAbsent(enfant);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed, // Utiliser la couleur rouge primaire
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.symmetric(horizontal: 4), // Réduire le padding
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown, // S'assurer que le texte s'adapte
            child: Text(
              'Absent',
              style: TextStyle(
                fontSize: 12, // Légèrement plus grand que "Annuler Absent"
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    } else {
      print(
          "🚫 Aucun bouton créé pour ${enfant['prenom']} (horaire déjà enregistré)");
      return Container(); // Retourne un conteneur vide si un horaire est déjà enregistré
    }
  }
}
