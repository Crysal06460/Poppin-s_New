import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';

class RecapScreen extends StatefulWidget {
  const RecapScreen({Key? key}) : super(key: key);

  @override
  _RecapScreenState createState() => _RecapScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _RecapScreenState extends State<RecapScreen> {
  List<Map<String, dynamic>> enfants = [];
  Map<String, Map<String, List<Map<String, dynamic>>>> recapDataByChild = {};
  Map<String, int> activitesCountByChild =
      {}; // Pour compter le nombre d'activités par enfant
  bool isLoading = true;
  String structureName = "Chargement...";
  int _selectedIndex = 1;
  int _convertHoursToMinutes(String timeStr) {
    if (timeStr == '--:--') return 0;
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        return hours * 60 + minutes;
      }
    } catch (e) {
      print("Erreur lors de la conversion de l'heure: $e");
    }
    return 0;
  }

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadEnfantsDuJour();
    });
  }

  Future<void> _loadEnfantsDuJour() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
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
      bool isMamMember = false;
      bool isStructureAdmin = false;

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};

        // Vérifier si l'utilisateur est un membre MAM
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          isMamMember = true;
          print(
              "🔄 Recap: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }

        // Vérifier si l'utilisateur est un administrateur de la structure
        isStructureAdmin =
            userData['isAdmin'] == true || userData['role'] == 'structureAdmin';
        print("👑 Recap: Statut admin: ${isStructureAdmin ? 'OUI' : 'NON'}");
      }

      final today = DateTime.now();
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      // Récupérer la structure pour déterminer le type
      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureSnapshot.exists) {
        setState(() {
          structureName =
              structureSnapshot['structureName'] ?? 'Structure inconnue';
        });
      }

      final String structureType = structureSnapshot.exists
          ? (structureSnapshot.data()?['structureType'] ??
              "AssistanteMaternelle")
          : "AssistanteMaternelle";

      // Récupérer tous les enfants de la structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      // Appliquer le filtrage selon le type de structure et le rôle de l'utilisateur
      List<Map<String, dynamic>> filteredChildren = [];

      if (structureType == "MAM") {
        // Pour une MAM: filtrer par assignedMemberEmail
        filteredChildren = allChildren.where((child) {
          String assignedEmail =
              child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
          return assignedEmail == currentUserEmail;
        }).toList();

        print(
            "👨‍👧‍👦 Recap: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Recap: Assistante Maternelle - affichage de tous les enfants");
      }

// Diagnostic détaillé pour aider au débogage
      print(
          "🔍 DIAGNOSTIC RECAP - Type de structure: $structureType, Utilisateur: $currentUserEmail, EstMAM: $isMamMember");
      for (var child in allChildren) {
        String assignedEmail =
            child['assignedMemberEmail']?.toString().toLowerCase() ??
                'NON ASSIGNÉ';
        bool isVisible =
            structureType != "MAM" || assignedEmail == currentUserEmail;
        print(
            "  👶 ID: ${child['id']}, Nom: ${child['firstName']}, Assigné à: '$assignedEmail', Visible: ${isVisible ? 'OUI' : 'NON'}");
      }

      // Diagnostic détaillé pour aider au débogage
      print(
          "🔍 DIAGNOSTIC RECAP - Type de structure: $structureType, Utilisateur: $currentUserEmail, EstMAM: $isMamMember, EstAdmin: $isStructureAdmin");
      for (var child in allChildren) {
        String assignedEmail =
            child['assignedMemberEmail']?.toString().toLowerCase() ??
                'NON ASSIGNÉ';
        bool isVisible = isStructureAdmin ||
            structureType != "MAM" ||
            assignedEmail == currentUserEmail;
        print(
            "  👶 ID: ${child['id']}, Nom: ${child['firstName']}, Assigné à: '$assignedEmail', Visible: ${isVisible ? 'OUI' : 'NON'}");
      }

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui
      enfants = [];
      for (var child in filteredChildren) {
        if (child['schedule'] != null &&
            child['schedule'][capitalizedWeekday] != null) {
          enfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'nom': child['lastName'] ?? '',
            'genre': child['gender'],
            'photoUrl': child['photoUrl'],
            'birthdate': child['birthdate'],
            'structureId': structureId,
            'assignedMemberEmail':
                child['assignedMemberEmail']?.toString().toLowerCase() ?? '',
          });
        }
      }

      print("👨‍👧‍👦 Recap: ${enfants.length} enfants prévus aujourd'hui");

      // Charger les données pour tous les enfants
      if (enfants.isNotEmpty) {
        for (var enfant in enfants) {
          print(
              "📋 Recap: Chargement des données pour l'enfant ${enfant['prenom']} (ID: ${enfant['id']})");
          await _loadChildRecapData(enfant['id'], structureId);
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  String _getCategoryDisplayName(String category, int count) {
    switch (category) {
      case 'repas':
        return count <= 1 ? 'Repas' : 'Repas'; // Invariable
      case 'activites':
        return count <= 1 ? 'Activité' : 'Activités';
      case 'siestes':
        return count <= 1 ? 'Sieste' : 'Siestes';
      case 'changes':
        return count <= 1 ? 'Change' : 'Changes';
      case 'sante':
        return count <= 1 ? 'Santé' : 'Santé'; // Invariable
      case 'horaires':
        return count <= 1 ? 'Horaire' : 'Horaires';
      case 'photos':
        return count <= 1 ? 'Photo' : 'Photos';
      case 'transmissions':
        return count <= 1 ? 'Transmission' : 'Transmissions';
      default:
        return category;
    }
  }

  Future<void> _loadChildRecapData(String childId, String structureId) async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
      final todayFormatted = DateFormat('yyyy-MM-dd').format(today);

      Map<String, List<Map<String, dynamic>>> tempRecapData = {
        'repas': [],
        'activites': [],
        'siestes': [],
        'changes': [],
        'sante': [],
        'horaires': [],
        'photos': [],
        'transmissions': [],
      };

      // Récupérer les repas
      final repasSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('repas')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .orderBy('date', descending: true)
          .get();

      for (var doc in repasSnapshot.docs) {
        final data = doc.data();
        String details = '';

        if (data['biberon'] == true) {
          details = 'Biberon ${data['ml']?.toInt() ?? 0} ml';
        } else if (data['allaitement'] == true) {
          details = 'Allaitement';
        } else {
          details = data['qualite'] ?? '';
        }

        tempRecapData['repas']!.add({
          'heure': data['heure'] ?? _formatTimestamp(data['date']),
          'details': details,
          'observations': data['observations'] ?? '',
        });
      }

      // Récupérer les activités
      final activitesSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('activites')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .orderBy('date', descending: true)
          .get();

      for (var doc in activitesSnapshot.docs) {
        final data = doc.data();
        tempRecapData['activites']!.add({
          'heure': data['heure'] ?? _formatTimestamp(data['date']),
          'type': data['type'] ?? 'Activité',
          'duration': data['duration'] ?? '',
          'participation': data['participation'] ?? '',
          'observations': data['observations'] ?? '',
        });
      }

      // Récupérer les siestes
      final siestesSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('siestes')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .orderBy('date', descending: true)
          .get();

      for (var doc in siestesSnapshot.docs) {
        final data = doc.data();
        tempRecapData['siestes']!.add({
          'heure': data['heure'] ?? _formatTimestamp(data['date']),
          'duration': data['duration'] ?? '',
          'qualite': data['qualite'] ?? '',
          'observations': data['observations'] ?? '',
        });
      }

      // Récupérer les changes
      final changesSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('changes')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .orderBy('date', descending: true)
          .get();

      for (var doc in changesSnapshot.docs) {
        final data = doc.data();
        String details = 'Change';
        if (data['pipi'] == true) details += ' - Pipi';
        if (data['selles'] == true) details += ' - Selles';

        tempRecapData['changes']!.add({
          'heure': data['heure'] ?? _formatTimestamp(data['date']),
          'details': details,
          'observations': data['observations'] ?? '',
        });
      }

      // Récupérer les soins de santé
      final santeSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('sante')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .orderBy('date', descending: true)
          .get();

      for (var doc in santeSnapshot.docs) {
        final data = doc.data();
        String details = data['type'] ?? '';

        if (data['type'] == 'Température') {
          details += ' ${data['temperature']}° - ${data['route'] ?? ""}';
        } else if (data['type'] == 'Poids') {
          details += ' ${data['weight']} kg';
        } else if (data['type'] == 'Médicaments') {
          details += ' - ${data['medicationType'] ?? ""}';
        }

        tempRecapData['sante']!.add({
          'heure': data['heure'] ?? _formatTimestamp(data['date']),
          'type': data['type'] ?? 'Soin',
          'details': details,
          'observations': data['observations'] ?? '',
        });
      }

      // PARTIE CORRIGÉE - Récupérer les horaires (arrivée/départ)
      try {
        // Vérifier d'abord si l'enfant est marqué comme absent
        bool isAbsent = false;

        // 1. Vérifier l'absence dans la collection horaires
        final absenceSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('horaires')
            .doc(todayFormatted)
            .get();

        if (absenceSnapshot.exists) {
          final data = absenceSnapshot.data();
          if (data != null && data.containsKey(childId)) {
            final childHoraires = data[childId];
            if (childHoraires['absent'] == true ||
                childHoraires['actionType'] == 'absent') {
              isAbsent = true;
              print(
                  "DEBUG: L'enfant $childId est marqué comme absent dans horaires");
              // Pour les enfants absents, on ne met PAS de données dans horaires
              // tempRecapData['horaires'] reste vide
            }
          }
        }

        // 2. Vérifier également l'absence dans horaires_history
        if (!isAbsent) {
          final absenceHistorySnapshot = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('horaires_history')
              .where('childId', isEqualTo: childId)
              .where('date', isEqualTo: todayFormatted)
              .where('actionType', isEqualTo: 'absent')
              .limit(1)
              .get();

          if (absenceHistorySnapshot.docs.isNotEmpty) {
            isAbsent = true;
            print(
                "DEBUG: L'enfant $childId est marqué comme absent dans horaires_history");
            // Pour les enfants absents, on ne met PAS de données dans horaires
            // tempRecapData['horaires'] reste vide
          }
        }

        // Si l'enfant n'est pas absent, récupérer les horaires normalement
        if (!isAbsent) {
          List<Map<String, dynamic>> allHoraires = [];

          // Récupérer les horaires dans la collection horaires_history
          final horairesSnapshot = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('horaires_history')
              .where('childId', isEqualTo: childId)
              .where('date', isEqualTo: todayFormatted)
              .get();

          print(
              "DEBUG: Horaires trouvés pour l'enfant $childId dans horaires_history: ${horairesSnapshot.docs.length}");

          // Ajouter les horaires trouvés
          for (var doc in horairesSnapshot.docs) {
            final data = doc.data();
            if (data['actionType'] == 'arrivee' ||
                data['actionType'] == 'depart') {
              allHoraires.add(data);
            }
          }

          // Récupérer également les horaires dans la collection horaires (historique journalier)
          if (absenceSnapshot.exists) {
            final data = absenceSnapshot.data();
            if (data != null && data.containsKey(childId)) {
              final childHoraires = data[childId];

              // Vérifier si des segments existent dans ce document
              if (childHoraires['segments'] != null) {
                List<dynamic> segments = childHoraires['segments'];
                for (var segment in segments) {
                  if (segment['arrivee'] != null) {
                    allHoraires.add({
                      'childId': childId,
                      'date': todayFormatted,
                      'actionType': 'arrivee',
                      'heure': segment['arrivee'],
                    });
                  }
                  if (segment['depart'] != null) {
                    allHoraires.add({
                      'childId': childId,
                      'date': todayFormatted,
                      'actionType': 'depart',
                      'heure': segment['depart'],
                    });
                  }
                }
              }
              // Format ancien (sans segments)
              else if (childHoraires['arrivee'] != null ||
                  childHoraires['depart'] != null) {
                if (childHoraires['arrivee'] != null) {
                  allHoraires.add({
                    'childId': childId,
                    'date': todayFormatted,
                    'actionType': 'arrivee',
                    'heure': childHoraires['arrivee'],
                  });
                }
                if (childHoraires['depart'] != null) {
                  allHoraires.add({
                    'childId': childId,
                    'date': todayFormatted,
                    'actionType': 'depart',
                    'heure': childHoraires['depart'],
                  });
                }
              }
            }
          }

          print(
              "DEBUG: Nombre total d'horaires trouvés pour l'enfant $childId: ${allHoraires.length}");

          if (allHoraires.isNotEmpty) {
            // Supprimer les doublons en se basant sur actionType et heure
            Map<String, Map<String, dynamic>> uniqueHoraires = {};
            for (var horaire in allHoraires) {
              String key = "${horaire['actionType']}_${horaire['heure']}";
              uniqueHoraires[key] = horaire;
            }

            for (var horaire in uniqueHoraires.values) {
              print(
                  "DEBUG: Ajout horaire: ${horaire['actionType']} à ${horaire['heure']}");

              if (horaire['actionType'] == 'arrivee') {
                tempRecapData['horaires']!.add({
                  'heure': horaire['heure'] ??
                      _formatTimestamp(horaire['timestamp']),
                  'type': 'arrivee',
                  'details': 'Arrivée',
                });
              } else if (horaire['actionType'] == 'depart') {
                tempRecapData['horaires']!.add({
                  'heure': horaire['heure'] ??
                      _formatTimestamp(horaire['timestamp']),
                  'type': 'depart',
                  'details': 'Départ',
                });
              }
            }

            // Tri des horaires par heure
            tempRecapData['horaires']!.sort((a, b) {
              // Conversion des heures en minutes depuis minuit pour comparaison
              int minutesA = _convertHoursToMinutes(a['heure'] ?? '00:00');
              int minutesB = _convertHoursToMinutes(b['heure'] ?? '00:00');
              return minutesA.compareTo(minutesB);
            });
          } else {
            print("Aucun horaire trouvé pour l'enfant $childId");
            // Pour un enfant sans horaires mais non absent, on ne met rien dans horaires
            // tempRecapData['horaires'] reste vide
          }
        }
      } catch (e) {
        print("Erreur lors de la récupération des horaires: $e");
        // En cas d'erreur, on ne met rien dans horaires
      }

      // Récupérer les photos
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('photos')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .orderBy('date', descending: true)
          .get();

      for (var doc in photosSnapshot.docs) {
        final data = doc.data();
        tempRecapData['photos']!.add({
          'heure': data['heure'] ?? _formatTimestamp(data['date']),
          'type': 'Photo',
          'details': data['title'] ?? 'Photo',
          'observations': data['description'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
        });
      }

      // Récupérer les transmissions
      final transmissionsSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('transmissions')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .orderBy('date', descending: true)
          .get();

      for (var doc in transmissionsSnapshot.docs) {
        final data = doc.data();
        tempRecapData['transmissions']!.add({
          'heure': data['heure'] ?? _formatTimestamp(data['date']),
          'type': data['type'] ?? 'Transmission',
          'details': data['title'] ?? 'Message',
          'observations': data['content'] ?? '',
        });
      }

      // Calculer le nombre total d'activités pour cet enfant
      int totalActivites = 0;
      tempRecapData.forEach((category, items) {
        totalActivites += items.length;
      });

      setState(() {
        recapDataByChild[childId] = tempRecapData;
        activitesCountByChild[childId] = totalActivites;
      });
    } catch (e) {
      print("Erreur lors du chargement des données récapitulatives: $e");
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('HH:mm').format(timestamp.toDate());
    }
    return '';
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
      context.go('/child-info');
    }
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
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  Map<String, IconData> _getCategoryIcon = {
    'repas': Icons.restaurant,
    'activites': Icons.directions_run,
    'siestes': Icons.nightlight_round,
    'changes': Icons.baby_changing_station,
    'sante': Icons.healing,
    'horaires': Icons.schedule,
    'photos': Icons.photo,
    'transmissions': Icons.share_arrival_time,
  };

  Map<String, Color> _getCategoryColor = {
    'repas': Colors.orange,
    'activites': primaryBlue,
    'siestes': Colors.indigo,
    'changes': Colors.brown,
    'sante': primaryRed,
    'horaires': primaryYellow,
    'photos': brightCyan,
    'transmissions': primaryYellow,
  };

  // Cette fonction affiche la popup avec le récapitulatif détaillé
  void _showRecapDetail(BuildContext context, String childId) {
    if (!recapDataByChild.containsKey(childId) ||
        activitesCountByChild[childId] == 0) {
      return; // Pas de données pour cet enfant, ne rien faire
    }

    // Trouver l'enfant correspondant à l'ID
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    final isBoy = enfant['genre'] == 'Garçon';
    final childData = recapDataByChild[childId]!;
    final avatarColor = isBoy ? primaryBlue : primaryRed;

    // Déterminer si nous sommes sur iPad
    final bool isTabletDevice = isTablet(context);

    // Ajuster la taille en fonction de l'appareil
    final double maxWidth = isTabletDevice ? 600 : 500;
    final double maxHeight =
        MediaQuery.of(context).size.height * (isTabletDevice ? 0.85 : 0.8);

    // Liste des catégories à afficher
    final categories = [
      'horaires',
      'repas',
      'activites',
      'siestes',
      'changes',
      'sante',
      'photos',
      'transmissions'
    ];

    // Filtrer les catégories qui ont des données
    final categoriesToShow = categories
        .where(
            (cat) => childData.containsKey(cat) && childData[cat]!.isNotEmpty)
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal:
                isTabletDevice ? MediaQuery.of(context).size.width * 0.15 : 20,
            vertical: isTabletDevice ? 40 : 20,
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: maxWidth,
              minWidth: isTabletDevice ? 500 : 300,
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
                        avatarColor,
                        avatarColor.withOpacity(0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: EdgeInsets.all(isTabletDevice ? 20 : 16),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isTabletDevice ? 12 : 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.summarize_outlined,
                          color: Colors.white,
                          size: isTabletDevice ? 32 : 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Récapitulatif - ${enfant['prenom']}",
                              style: TextStyle(
                                fontSize: isTabletDevice ? 24 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMMM yyyy', 'fr_FR')
                                  .format(DateTime.now()),
                              style: TextStyle(
                                fontSize: isTabletDevice ? 18 : 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenu du récapitulatif avec défilement
                Flexible(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(isTabletDevice ? 24 : 16),
                      child: Column(
                        children: categoriesToShow.map((category) {
                          return _buildRecapSection(category,
                              childData[category] ?? [], isTabletDevice);
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // Bouton Fermer
                Container(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: EdgeInsets.symmetric(
                        vertical: isTabletDevice ? 16 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        ),
                      ),
                    ),
                    child: Text(
                      "FERMER",
                      style: TextStyle(
                        fontSize: isTabletDevice ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color: avatarColor,
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

  String _getHoraireDisplayText(String? type, String? details) {
    if (type == 'arrivee' || details == 'arrivee' || details == 'Arrivee') {
      return 'Arrivée';
    } else if (type == 'depart' || details == 'depart' || details == 'Depart') {
      return 'Départ';
    }
    return details ?? '';
  }

  Widget _buildRecapSection(
      String category, List<Map<String, dynamic>> items, bool isTablet) {
    if (items.isEmpty) return Container();

    return Container(
      margin: EdgeInsets.symmetric(vertical: isTablet ? 12 : 8),
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
          // En-tête de section
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: _getCategoryColor[category]!.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon[category],
                  color: _getCategoryColor[category],
                  size: isTablet ? 28 : 24,
                ),
                SizedBox(width: 12),
                Text(
                  _getCategoryDisplayName(category, items.length),
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 8,
                      vertical: isTablet ? 6 : 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor[category]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${items.length}",
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                )
              ],
            ),
          ),

          // Liste standard pour toutes les catégories
          ListView.separated(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 6 : 4,
                ),
                leading: Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor[category]!.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    item['heure'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: isTablet ? 14 : 12,
                    ),
                  ),
                ),
                title: Text(
                  category == 'photos'
                      ? '1 photo'
                      : category == 'horaires'
                          ? _getHoraireDisplayText(
                              item['type'], item['details'])
                          : (item['type'] ?? item['details'] ?? ''),
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                subtitle: item['observations'] != null &&
                        item['observations'].isNotEmpty
                    ? Text(
                        item['observations'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.black,
                        ),
                      )
                    : null,
                trailing: Icon(Icons.arrow_forward_ios,
                    size: isTablet ? 16 : 14, color: Colors.black),
                dense: !isTablet,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    final childId = enfant['id'];
    final isBoy = enfant['genre'] == 'Garçon';

    // Vérifier si des activités existent pour cet enfant
    final hasActivites = activitesCountByChild.containsKey(childId) &&
        activitesCountByChild[childId]! > 0;

    // Obtenir le nombre d'activités par catégorie s'il y en a
    Map<String, int> categoryCounts = {};
    if (recapDataByChild.containsKey(childId)) {
      recapDataByChild[childId]!.forEach((category, items) {
        if (items.isNotEmpty) {
          categoryCounts[category] = items.length;
        }
      });
    }

    return GestureDetector(
      onTap: hasActivites ? () => _showRecapDetail(context, childId) : null,
      child: Container(
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
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Photo de l'enfant
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
                          color: (isBoy ? primaryBlue : primaryRed)
                              .withOpacity(0.3),
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
                  // Nom de l'enfant
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${enfant['prenom']} ${enfant['nom']}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isBoy ? primaryBlue : primaryRed,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMMM yyyy', 'fr_FR')
                              .format(DateTime.now()),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Indicateur d'activités
                  if (hasActivites)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.summarize, color: primaryBlue, size: 18),
                          SizedBox(width: 4),
                          Text(
                            '${activitesCountByChild[childId]}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Afficher un résumé des activités s'il y en a
            if (hasActivites)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: lightBlue.withOpacity(0.3),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryCounts.entries.map((entry) {
                    final category = entry.key;
                    final count = entry.value;
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCategoryColor[category]!.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getCategoryColor[category]!.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon[category],
                            color: _getCategoryColor[category],
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "${count} ${_getCategoryDisplayName(category, count)}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getCategoryColor[category],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Text(
                  'Aucune activité enregistrée aujourd\'hui',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Version tablette
  // Nouveau layout pour iPad - affiche les enfants dans une grille
  Widget _buildTabletLayout() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 cartes par ligne
        childAspectRatio:
            1.2, // Un peu plus large que haut, comme dans activity_screen
        crossAxisSpacing: 20, // Espace horizontal entre les cartes
        mainAxisSpacing: 20, // Espace vertical entre les cartes
      ),
      itemCount: enfants.length,
      itemBuilder: (context, index) =>
          _buildEnfantCardForTablet(context, index),
    );
  }

  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    final childId = enfant['id'];
    final isBoy = enfant['genre'] == 'Garçon';
    final avatarColor = isBoy ? primaryBlue : primaryRed;

    // Vérifier si des activités existent pour cet enfant
    final hasActivites = activitesCountByChild.containsKey(childId) &&
        activitesCountByChild[childId]! > 0;

    // Obtenir le nombre d'activités par catégorie s'il y en a
    Map<String, int> categoryCounts = {};
    if (recapDataByChild.containsKey(childId)) {
      recapDataByChild[childId]!.forEach((category, items) {
        if (items.isNotEmpty) {
          categoryCounts[category] = items.length;
        }
      });
    }

    return GestureDetector(
      onTap: hasActivites ? () => _showRecapDetail(context, childId) : null,
      child: Container(
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
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
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
                  // Badge indiquant le nombre d'activités
                  if (hasActivites)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.summarize, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text(
                            '${activitesCountByChild[childId]}',
                            style: TextStyle(
                              fontSize: 16,
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

            // Contenu - Liste des activités du jour
            Expanded(
              child: hasActivites
                  ? ListView.separated(
                      physics: BouncingScrollPhysics(),
                      shrinkWrap: true,
                      padding: EdgeInsets.all(16),
                      itemCount: categoryCounts.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final category = categoryCounts.keys.elementAt(index);
                        final count = categoryCounts[category]!;
                        return Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color:
                                _getCategoryColor[category]!.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _getCategoryColor[category]!
                                    .withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor[category]!
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getCategoryIcon[category],
                                  color: _getCategoryColor[category],
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  "${count} ${_getCategoryDisplayName(category, count)}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Center(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    // Détection de l'iPad
    final bool isTabletDevice = isTablet(context);

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
          // Plus de padding vertical pour iPad
          padding: EdgeInsets.fromLTRB(
              16,
              isTabletDevice ? 24 : 16, // Augmenté pour iPad
              16,
              isTabletDevice ? 28 : 20 // Augmenté pour iPad
              ),
          child: Column(
            children: [
              // Première ligne: nom structure et date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      structureName,
                      style: TextStyle(
                        fontSize:
                            isTabletDevice ? 28 : 24, // Plus grand pour iPad
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          isTabletDevice ? 16 : 12, // Plus grand pour iPad
                      vertical: isTabletDevice ? 8 : 6, // Plus grand pour iPad
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize:
                            isTabletDevice ? 16 : 14, // Plus grand pour iPad
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                  height: isTabletDevice ? 22 : 15), // Plus d'espace pour iPad
              // Icône et titre de la page
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTabletDevice ? 22 : 16, // Plus grand pour iPad
                  vertical: isTabletDevice ? 12 : 8, // Plus grand pour iPad
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white,
                      width: isTabletDevice ? 2.5 : 2 // Plus épais pour iPad
                      ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/Icone_Recaptitulatif.png',
                      width: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      height: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.summarize_outlined,
                        size: isTabletDevice ? 32 : 26, // Plus grand pour iPad
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                        width:
                            isTabletDevice ? 12 : 8), // Plus d'espace pour iPad
                    Text(
                      'Récapitulatif',
                      style: TextStyle(
                        fontSize:
                            isTabletDevice ? 24 : 20, // Plus grand pour iPad
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

  @override
  Widget build(BuildContext context) {
    // Détection de l'iPad
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  ))
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
    );
  }

// État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Recaptitulatif.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.summarize_outlined,
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
            'assets/images/Icone_Ajout_Enfant.png',
            width: 60,
            height: 60,
          ),
          label: "Ajouter",
        ),
      ],
    );
  }
}
