import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';

class CleaningScheduleScreen extends StatefulWidget {
  const CleaningScheduleScreen({Key? key}) : super(key: key);

  @override
  _CleaningScheduleScreenState createState() => _CleaningScheduleScreenState();
}

class _CleaningScheduleScreenState extends State<CleaningScheduleScreen> {
  // Définition des couleurs de la palette
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  // Couleur principale
  late Color primaryColor = primaryBlue;

  // Semaine actuelle (par défaut la semaine en cours)
  DateTime currentWeekStart = DateTime.now().subtract(
    Duration(days: DateTime.now().weekday - 1),
  );

  bool isLoading = true;
  String structureId = "";
  List<Map<String, dynamic>> members = [];
  Map<String, Color> memberColors = {};
  Map<String, Map<String, List<String>>> schedule = {};

  // Liste des jours de la semaine - Modification pour affichage plus court
  final List<String> weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      structureId = await _getStructureId();
      if (structureId.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      // Charger les membres de la MAM
      await _loadMembers();

      // Charger le planning de ménage pour la semaine actuelle
      await _loadSchedule();

      setState(() => isLoading = false);
    } catch (e) {
      print("Erreur lors du chargement des données: $e");
      setState(() => isLoading = false);
    }
  }

  Future<String> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    // Vérifier si l'utilisateur est un membre MAM
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email?.toLowerCase() ?? '')
        .get();

    // Si c'est un membre MAM, obtenir l'ID de la structure associée
    if (userDoc.exists &&
        userDoc.data() != null &&
        userDoc.data()!.containsKey('structureId')) {
      return userDoc.data()!['structureId'];
    }

    // Par défaut, utiliser l'ID de l'utilisateur
    return user.uid;
  }

  Future<void> _loadMembers() async {
    try {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .get();

      List<Map<String, dynamic>> tempMembers = [];
      Map<String, Color> tempColors = {};

      // Couleurs prédéfinies pour les membres
      List<Color> colors = [
        primaryBlue.withOpacity(0.7), // Variante de bleu
        primaryYellow.withOpacity(0.7), // Variante de jaune
        brightCyan.withOpacity(0.7), // Variante de cyan
        primaryRed.withOpacity(0.7), // Variante de rouge
        lightBlue, // Bleu clair
        primaryBlue.withOpacity(0.5), // Autre variante de bleu
        primaryYellow.withOpacity(0.5), // Autre variante de jaune
      ];

      int colorIndex = 0;

      // Récupérer les informations des utilisateurs de la MAM
      for (var doc in membersSnapshot.docs) {
        final data = doc.data();

        // Récupérer l'email et vérifier qu'il existe
        final String email = data['email'] ?? '';

        if (email.isNotEmpty) {
          // Récupérer le document utilisateur
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(email.toLowerCase())
              .get();

          String displayName = '';

          if (userDoc.exists && userDoc.data() != null) {
            // Essayer différents champs pour trouver un nom
            final userData = userDoc.data()!;

            // Chercher le prénom de façon prioritaire
            if (userData.containsKey('firstName') &&
                userData['firstName'] != '') {
              displayName = userData['firstName'];
            }
            // Sinon essayer le nom complet
            else if (userData.containsKey('displayName') &&
                userData['displayName'] != '') {
              displayName = userData['displayName'];

              // Extraire le prénom du nom complet
              if (displayName.contains(' ')) {
                displayName = displayName.split(' ')[0];
              }
            }
            // Vérifier s'il y a un champ username
            else if (userData.containsKey('username') &&
                userData['username'] != '') {
              displayName = userData['username'];
            }
            // Vérifier s'il y a un champ name
            else if (userData.containsKey('name') && userData['name'] != '') {
              displayName = userData['name'];

              // Extraire le prénom du nom complet
              if (displayName.contains(' ')) {
                displayName = displayName.split(' ')[0];
              }
            }
          }

          // Si toujours vide, essayer d'autres options dans les données du membre
          if (displayName.isEmpty) {
            if (data.containsKey('displayName') && data['displayName'] != '') {
              displayName = data['displayName'];

              // Extraire le prénom
              if (displayName.contains(' ')) {
                displayName = displayName.split(' ')[0];
              }
            } else if (data.containsKey('name') && data['name'] != '') {
              displayName = data['name'];

              // Extraire le prénom
              if (displayName.contains(' ')) {
                displayName = displayName.split(' ')[0];
              }
            } else if (data.containsKey('firstName') &&
                data['firstName'] != '') {
              displayName = data['firstName'];
            } else {
              // Utiliser une partie de l'email comme dernier recours (avant le @)
              displayName = email.split('@')[0];

              // Mettre la première lettre en majuscule
              if (displayName.isNotEmpty) {
                displayName =
                    displayName[0].toUpperCase() + displayName.substring(1);
              } else {
                displayName = "Qui"; // Fallback final
              }
            }
          }

          tempMembers.add({
            'id': doc.id,
            'displayName': displayName,
            'firstName': displayName, // Utiliser directement le prénom
            'email': email,
          });

          // Attribuer une couleur à ce membre
          tempColors[doc.id] = colors[colorIndex % colors.length];
          colorIndex++;
        }
      }

      setState(() {
        members = tempMembers;
        memberColors = tempColors;
      });
    } catch (e) {
      print("Erreur lors du chargement des membres: $e");
    }
  }

  Future<void> _loadSchedule() async {
    try {
      // Formater la date du début de semaine pour l'utiliser comme ID
      String weekId = DateFormat('yyyy-MM-dd').format(currentWeekStart);

      // Récupérer le planning de la semaine actuelle
      final scheduleDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('cleaningSchedules')
          .doc(weekId)
          .get();

      Map<String, Map<String, List<String>>> tempSchedule = {};

      if (scheduleDoc.exists && scheduleDoc.data() != null) {
        // Convertir les données Firestore en structure utilisable
        Map<String, dynamic> data = scheduleDoc.data()!;

        for (var day in weekDays) {
          tempSchedule[day] = {};

          if (data.containsKey(day)) {
            Map<String, dynamic> dayData = data[day];

            for (var memberId in dayData.keys) {
              if (dayData[memberId] is List) {
                tempSchedule[day]![memberId] =
                    List<String>.from(dayData[memberId]);
              }
            }
          }
        }
      } else {
        // Si aucun planning n'existe pour cette semaine, initialiser un planning vide
        for (var day in weekDays) {
          tempSchedule[day] = {};
        }
      }

      setState(() {
        schedule = tempSchedule;
      });
    } catch (e) {
      print("Erreur lors du chargement du planning: $e");
    }
  }

  Future<void> _saveSchedule() async {
    try {
      // Formater la date pour l'ID du document
      String weekId = DateFormat('yyyy-MM-dd').format(currentWeekStart);

      // Convertir la structure en Map pour Firestore
      Map<String, dynamic> scheduleData = {};

      for (var day in schedule.keys) {
        scheduleData[day] = {};

        for (var memberId in schedule[day]!.keys) {
          scheduleData[day][memberId] = schedule[day]![memberId];
        }
      }

      // Sauvegarder dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('cleaningSchedules')
          .doc(weekId)
          .set(scheduleData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Planning sauvegardé avec succès"),
          backgroundColor:
              primaryBlue, // Remplacer Colors.green par primaryBlue
        ),
      );
    } catch (e) {
      print("Erreur lors de la sauvegarde du planning: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sauvegarde: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _duplicateSchedule() async {
    try {
      // Obtenir la date de début de la semaine suivante
      DateTime nextWeekStart = currentWeekStart.add(Duration(days: 7));
      String nextWeekId = DateFormat('yyyy-MM-dd').format(nextWeekStart);

      // Formater la date actuelle pour l'ID du document
      String currentWeekId = DateFormat('yyyy-MM-dd').format(currentWeekStart);

      // Récupérer le planning actuel
      final currentScheduleDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('cleaningSchedules')
          .doc(currentWeekId)
          .get();

      if (currentScheduleDoc.exists && currentScheduleDoc.data() != null) {
        // Dupliquer les données pour la semaine suivante
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('cleaningSchedules')
            .doc(nextWeekId)
            .set(currentScheduleDoc.data()!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Planning dupliqué pour la semaine du ${DateFormat('dd/MM/yyyy').format(nextWeekStart)}",
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Impossible de dupliquer: aucun planning existant pour cette semaine"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de la duplication du planning: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la duplication: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _changeWeek(int offset) {
    setState(() {
      currentWeekStart = currentWeekStart.add(Duration(days: 7 * offset));
      isLoading = true;
    });
    _loadSchedule().then((_) {
      setState(() => isLoading = false);
    });
  }

  void _addTask(String day, String memberId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newTask = '';

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Ajouter une tâche", textAlign: TextAlign.center),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Description de la tâche",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (value) {
              newTask = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (newTask.trim().isNotEmpty) {
                  setState(() {
                    // Initialiser la liste des tâches pour ce membre si elle n'existe pas
                    schedule[day]![memberId] ??= [];
                    // Ajouter la nouvelle tâche
                    schedule[day]![memberId]!.add(newTask.trim());
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(
                "AJOUTER",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editTask(String day, String memberId, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String editedTask = schedule[day]![memberId]![index];

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Modifier la tâche", textAlign: TextAlign.center),
          content: TextField(
            autofocus: true,
            controller: TextEditingController(text: editedTask),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (value) {
              editedTask = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (editedTask.trim().isNotEmpty) {
                  setState(() {
                    schedule[day]![memberId]![index] = editedTask.trim();
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(
                "ENREGISTRER",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  schedule[day]![memberId]!.removeAt(index);
                });
                Navigator.pop(context);
              },
              child: Text(
                "SUPPRIMER",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculer la plage de dates
    final weekEnd =
        currentWeekStart.add(Duration(days: 4)); // 5 jours (Lun-Ven)
    final dateRange =
        "${DateFormat('d MMM', 'fr_FR').format(currentWeekStart)} - ${DateFormat('d MMM yyyy', 'fr_FR').format(weekEnd)}";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Planning Ménage",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 2,
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: Column(
                children: [
                  // En-tête avec navigation de semaine et design amélioré
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primaryColor.withOpacity(0.15),
                          primaryColor.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Container(
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.arrow_back_ios,
                              color: primaryColor,
                              size: 18,
                            ),
                          ),
                          onPressed: () => _changeWeek(-1),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Semaine du",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                dateRange,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              color: primaryColor,
                              size: 18,
                            ),
                          ),
                          onPressed: () => _changeWeek(1),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Légende des membres avec leurs couleurs
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.people_alt_rounded,
                              color: primaryColor,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Membres de l'équipe",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: members.map((member) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    memberColors[member['id']] ?? Colors.grey,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                member['firstName'] ?? member['displayName'],
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Tableau du planning
                  Expanded(
                    child: members.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cleaning_services_outlined,
                                  size: 70,
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Aucun membre disponible pour le planning",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            margin: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  offset: Offset(0, 3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Column(
                                    children: [
                                      // En-tête du tableau
                                      Container(
                                        decoration: BoxDecoration(
                                          color: lightBlue,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 120,
                                              padding: EdgeInsets.all(12),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(
                                                      color:
                                                          Colors.grey.shade300),
                                                  bottom: BorderSide(
                                                      color:
                                                          Colors.grey.shade300),
                                                ),
                                              ),
                                              child: Text(
                                                "Membres",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ),
                                            ...weekDays
                                                .map((day) => Container(
                                                      width: 120,
                                                      padding:
                                                          EdgeInsets.all(12),
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        border: Border(
                                                          right: BorderSide(
                                                              color: Colors.grey
                                                                  .shade300),
                                                          bottom: BorderSide(
                                                              color: Colors.grey
                                                                  .shade300),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        day,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: primaryColor,
                                                        ),
                                                      ),
                                                    ))
                                                .toList(),
                                          ],
                                        ),
                                      ),

                                      // Lignes du tableau (un membre par ligne)
                                      ...members.map((member) {
                                        return Row(
                                          children: [
                                            // Nom du membre
                                            Container(
                                              width: 120,
                                              height: 100,
                                              padding: EdgeInsets.all(8),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color:
                                                    memberColors[member['id']]
                                                            ?.withOpacity(
                                                                0.7) ??
                                                        Colors.grey.shade200,
                                                border: Border(
                                                  right: BorderSide(
                                                      color:
                                                          Colors.grey.shade300),
                                                  bottom: BorderSide(
                                                      color:
                                                          Colors.grey.shade300),
                                                ),
                                              ),
                                              child: Text(
                                                member['firstName'] ??
                                                    member['displayName'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),

                                            // Cellules pour chaque jour
                                            ...weekDays.map((day) {
                                              return Container(
                                                width: 120,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                  color:
                                                      memberColors[member['id']]
                                                              ?.withOpacity(
                                                                  0.1) ??
                                                          Colors.grey.shade50,
                                                  border: Border(
                                                    right: BorderSide(
                                                        color: Colors
                                                            .grey.shade300),
                                                    bottom: BorderSide(
                                                        color: Colors
                                                            .grey.shade300),
                                                  ),
                                                ),
                                                child: InkWell(
                                                  onTap: () => _addTask(
                                                      day, member['id']),
                                                  child: schedule[day]
                                                              ?.containsKey(
                                                                  member[
                                                                      'id']) ??
                                                          false
                                                      ? ListView(
                                                          padding:
                                                              EdgeInsets.all(6),
                                                          shrinkWrap: true,
                                                          children:
                                                              List.generate(
                                                            schedule[day]![
                                                                    member[
                                                                        'id']]!
                                                                .length,
                                                            (index) =>
                                                                GestureDetector(
                                                              onTap: () =>
                                                                  _editTask(
                                                                      day,
                                                                      member[
                                                                          'id'],
                                                                      index),
                                                              child: Container(
                                                                margin: EdgeInsets
                                                                    .only(
                                                                        bottom:
                                                                            6),
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        vertical:
                                                                            6,
                                                                        horizontal:
                                                                            8),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: memberColors[member[
                                                                              'id']]
                                                                          ?.withOpacity(
                                                                              0.5) ??
                                                                      Colors
                                                                          .grey
                                                                          .shade200,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: Colors
                                                                          .black
                                                                          .withOpacity(
                                                                              0.05),
                                                                      offset:
                                                                          Offset(
                                                                              0,
                                                                              1),
                                                                      blurRadius:
                                                                          2,
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: Text(
                                                                  schedule[day]![
                                                                          member[
                                                                              'id']]![
                                                                      index],
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                      : Center(
                                                          child: Icon(
                                                            Icons
                                                                .add_circle_outline,
                                                            color: primaryColor
                                                                .withOpacity(
                                                                    0.5),
                                                            size: 30,
                                                          ),
                                                        ),
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),

                  // Barre du bas avec boutons
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          offset: Offset(0, -2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.save_outlined),
                            label: Text("Enregistrer"),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: primaryColor,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _saveSchedule,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.copy_outlined),
                            label: Text("Dupliquer"),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  primaryYellow, // Remplacer Colors.green par primaryYellow
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _duplicateSchedule,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      // Ajout du bottom navigation bar similaire à home_screen.dart
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) {
          if (index == 0) {
            context.go('/dashboard');
          } else if (index == 1) {
            context.go('/home');
          } else if (index == 2) {
            context.go('/child-info');
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: 0, // Dashboard est sélectionné
        items: [
          // Premier item - Dashboard
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_Dashboard.png',
              width: 60,
              height: 60,
            ),
            label: "Dashboard",
          ),

          // Deuxième item - Home (Maison)
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/maison_icon.png',
              width: 60,
              height: 60,
            ),
            label: "Home",
          ),

          // Troisième item - Ajouter enfant
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_Ajout_Enfant.png',
              width: 60,
              height: 60,
            ),
            label: "Ajouter",
          ),
        ],
      ),
    );
  }
}
