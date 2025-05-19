import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import '../widgets/custom_bottom_navigation.dart';

class ActualitesScreen extends StatefulWidget {
  const ActualitesScreen({Key? key}) : super(key: key);

  @override
  _ActualitesScreenState createState() => _ActualitesScreenState();
}

class _ActualitesScreenState extends State<ActualitesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  String structureName = "Chargement...";
  int _selectedIndex = 1;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Variables pour les différentes sections
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> sorties = [];
  Map<String, List<String>> menuSemaine = {
    'Lundi': [],
    'Mardi': [],
    'Mercredi': [],
    'Jeudi': [],
    'Vendredi': [],
    'Samedi': [],
    'Dimanche': [],
  };

  // Variables pour la semaine actuelle
  DateTime currentWeekStart =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadStructureData();
      _loadActualites();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStructureData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get();

      setState(() {
        structureName =
            structureSnapshot['structureName'] ?? 'Structure inconnue';
      });
    } catch (e) {
      print("Erreur lors du chargement des données de structure: $e");
    }
  }

  Future<void> _checkAndResetWeeklyMenu(String userId) async {
    try {
      // Récupérer les informations de dernière mise à jour du menu
      final menuInfoDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(userId)
          .collection('actualites')
          .doc('menu_info')
          .get();

      bool shouldResetMenu = false;
      DateTime now = DateTime.now();

      // Début de la semaine courante (lundi)
      DateTime currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
      currentWeekStart = DateTime(
          currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);

      if (!menuInfoDoc.exists) {
        // Premier usage - initialiser le document menu_info
        shouldResetMenu = true;
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(userId)
            .collection('actualites')
            .doc('menu_info')
            .set({
          'lastReset': Timestamp.fromDate(currentWeekStart),
        });
      } else {
        // Vérifier si la dernière réinitialisation date de la semaine dernière
        Timestamp lastReset = menuInfoDoc.data()?['lastReset'];
        if (lastReset != null) {
          DateTime lastResetDate = lastReset.toDate();

          // Si la dernière réinitialisation est d'une semaine antérieure
          if (lastResetDate.isBefore(currentWeekStart)) {
            shouldResetMenu = true;
            // Mettre à jour la date de dernière réinitialisation
            await FirebaseFirestore.instance
                .collection('structures')
                .doc(userId)
                .collection('actualites')
                .doc('menu_info')
                .update({
              'lastReset': Timestamp.fromDate(currentWeekStart),
            });
          }
        } else {
          // Si le champ lastReset n'existe pas
          shouldResetMenu = true;
          await FirebaseFirestore.instance
              .collection('structures')
              .doc(userId)
              .collection('actualites')
              .doc('menu_info')
              .update({
            'lastReset': Timestamp.fromDate(currentWeekStart),
          });
        }
      }

      // Réinitialiser le menu si nécessaire
      if (shouldResetMenu) {
        print("Réinitialisation du menu hebdomadaire");
        // Créer un menu vide
        Map<String, List<String>> emptyMenu = {
          'Lundi': [],
          'Mardi': [],
          'Mercredi': [],
          'Jeudi': [],
          'Vendredi': [],
          'Samedi': [],
          'Dimanche': [],
        };

        await FirebaseFirestore.instance
            .collection('structures')
            .doc(userId)
            .collection('actualites')
            .doc('menu')
            .set(emptyMenu);
      }
    } catch (e) {
      print("Erreur lors de la vérification/réinitialisation du menu: $e");
    }
  }

  Future<void> _loadActualites() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Gérer la réinitialisation hebdomadaire du menu
      await _checkAndResetWeeklyMenu(user.uid);

      // Charger les événements
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('actualites')
          .doc('events')
          .collection('items')
          .orderBy('date')
          .get();

      // Charger les sorties
      final sortiesSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('actualites')
          .doc('sorties')
          .collection('items')
          .orderBy('date')
          .get();

      // Charger les menus de la semaine
      final menuSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('actualites')
          .doc('menu')
          .get();

      // Traiter les données
      final List<Map<String, dynamic>> tempEvents = [];
      for (var doc in eventsSnapshot.docs) {
        final data = doc.data();
        tempEvents.add({
          'id': doc.id,
          'titre': data['titre'] ?? 'Sans titre',
          'description': data['description'] ?? '',
          'date': data['date'] as Timestamp,
          'imageUrl': data['imageUrl'],
        });
      }

      final List<Map<String, dynamic>> tempSorties = [];
      for (var doc in sortiesSnapshot.docs) {
        final data = doc.data();
        tempSorties.add({
          'id': doc.id,
          'titre': data['titre'] ?? 'Sans titre',
          'lieu': data['lieu'] ?? '',
          'description': data['description'] ?? '',
          'date': data['date'] as Timestamp,
          'imageUrl': data['imageUrl'],
        });
      }

      // Mise à jour du menu
      Map<String, List<String>> tempMenuSemaine = {
        'Lundi': [],
        'Mardi': [],
        'Mercredi': [],
        'Jeudi': [],
        'Vendredi': [],
        'Samedi': [],
        'Dimanche': [],
      };

      if (menuSnapshot.exists) {
        final data = menuSnapshot.data();
        if (data != null) {
          for (var day in tempMenuSemaine.keys) {
            if (data[day] != null && data[day] is List) {
              tempMenuSemaine[day] = List<String>.from(data[day]);
            }
          }
        }
      }

      setState(() {
        events = tempEvents;
        sorties = tempSorties;
        menuSemaine = tempMenuSemaine;
        isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des actualités: $e");
      setState(() => isLoading = false);
    }
  }

  void _showAddEventDialog(bool isSortie) {
    String titre = '';
    String description = '';
    String lieu = '';
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isSortie ? 'Ajouter une sortie' : 'Ajouter un événement',
            style: TextStyle(
              color: primaryBlue,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Titre',
                        labelStyle: TextStyle(color: primaryBlue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                      onChanged: (value) => titre = value,
                    ),
                    SizedBox(height: 16),
                    if (isSortie) ...[
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Lieu',
                          labelStyle: TextStyle(color: primaryBlue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: primaryBlue, width: 2),
                          ),
                        ),
                        onChanged: (value) => lieu = value,
                      ),
                      SizedBox(height: 16),
                    ],
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: primaryBlue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                      maxLines: 3,
                      onChanged: (value) => description = value,
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: primaryBlue),
                          SizedBox(width: 10),
                          Text(
                            'Date: ${DateFormat('dd/MM/yyyy').format(date)}',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Spacer(),
                          TextButton(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: primaryBlue,
                                        onPrimary: Colors.white,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null && picked != date) {
                                setState(() {
                                  date = picked;
                                });
                              }
                            },
                            child: Text(
                              'Choisir',
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (titre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Veuillez entrer un titre'),
                      backgroundColor: primaryRed,
                    ),
                  );
                  return;
                }
                if (isSortie && lieu.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Veuillez entrer un lieu'),
                      backgroundColor: primaryRed,
                    ),
                  );
                  return;
                }
                _addActualite(titre, description, date, isSortie, lieu);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Ajouter',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditMenuDialog() {
    Map<String, List<String>> tempMenu = Map.from(menuSemaine);
    Map<String, TextEditingController> controllers = {};

    for (var day in tempMenu.keys) {
      controllers[day] = TextEditingController(
        text: tempMenu[day]!.join('\n'),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Text(
                'Menu de la semaine',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Divider(color: lightBlue, thickness: 2),
            ],
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon:
                                Icon(Icons.arrow_back_ios, color: primaryBlue),
                            onPressed: () {
                              setState(() {
                                currentWeekStart = currentWeekStart
                                    .subtract(Duration(days: 7));
                              });
                            },
                          ),
                          Text(
                            'Semaine du ${DateFormat('dd/MM').format(currentWeekStart)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.arrow_forward_ios,
                                color: primaryBlue),
                            onPressed: () {
                              setState(() {
                                currentWeekStart =
                                    currentWeekStart.add(Duration(days: 7));
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    for (var day in [
                      'Lundi',
                      'Mardi',
                      'Mercredi',
                      'Jeudi',
                      'Vendredi'
                    ]) ...[
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          title: Text(
                            day,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                            ),
                          ),
                          leading:
                              Icon(Icons.restaurant_menu, color: primaryBlue),
                          childrenPadding: EdgeInsets.all(16),
                          children: [
                            TextField(
                              controller: controllers[day],
                              decoration: InputDecoration(
                                hintText: 'Saisir le menu pour $day',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: primaryBlue, width: 2),
                                ),
                              ),
                              maxLines: 5,
                              onChanged: (value) {
                                tempMenu[day] = value
                                    .split('\n')
                                    .where((line) => line.trim().isNotEmpty)
                                    .toList();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Samedi et Dimanche en option
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: ExpansionTile(
                        title: Text(
                          'Week-end',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                          ),
                        ),
                        leading: Icon(Icons.weekend, color: primaryBlue),
                        initiallyExpanded: false,
                        childrenPadding: EdgeInsets.all(16),
                        children: [
                          Column(
                            children: [
                              Text(
                                'Samedi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: controllers['Samedi'],
                                decoration: InputDecoration(
                                  hintText: 'Saisir le menu pour Samedi',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primaryBlue, width: 2),
                                  ),
                                ),
                                maxLines: 5,
                                onChanged: (value) {
                                  tempMenu['Samedi'] = value
                                      .split('\n')
                                      .where((line) => line.trim().isNotEmpty)
                                      .toList();
                                },
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Dimanche',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: controllers['Dimanche'],
                                decoration: InputDecoration(
                                  hintText: 'Saisir le menu pour Dimanche',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primaryBlue, width: 2),
                                  ),
                                ),
                                maxLines: 5,
                                onChanged: (value) {
                                  tempMenu['Dimanche'] = value
                                      .split('\n')
                                      .where((line) => line.trim().isNotEmpty)
                                      .toList();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _saveMenu(tempMenu);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Enregistrer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addActualite(
      String titre, String description, DateTime date, bool isSortie,
      [String? lieu]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = isSortie ? 'sorties' : 'events';
      final data = isSortie
          ? {
              'titre': titre,
              'lieu': lieu,
              'description': description,
              'date': Timestamp.fromDate(date),
              'createdAt': FieldValue.serverTimestamp(),
            }
          : {
              'titre': titre,
              'description': description,
              'date': Timestamp.fromDate(date),
              'createdAt': FieldValue.serverTimestamp(),
            };

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('actualites')
          .doc(collection)
          .collection('items')
          .add(data);

      // Recharger les données
      _loadActualites();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSortie
                ? 'Sortie ajoutée avec succès'
                : 'Événement ajouté avec succès',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print("Erreur lors de l'ajout de l'actualité: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur: Impossible d\'ajouter l\'actualité',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: primaryRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _saveMenu(Map<String, List<String>> menu) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Convertir en Map<String, dynamic> pour Firestore
      final Map<String, dynamic> data = {};
      for (var day in menu.keys) {
        data[day] = menu[day];
      }

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('actualites')
          .doc('menu')
          .set(data);

      // Mettre à jour l'état local
      setState(() {
        menuSemaine = menu;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Menu de la semaine enregistré avec succès',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print("Erreur lors de la sauvegarde du menu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur: Impossible d\'enregistrer le menu',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: primaryRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _deleteActualite(String id, bool isSortie) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = isSortie ? 'sorties' : 'events';

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('actualites')
          .doc(collection)
          .collection('items')
          .doc(id)
          .delete();

      // Recharger les données
      _loadActualites();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSortie
                ? 'Sortie supprimée avec succès'
                : 'Événement supprimé avec succès',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print("Erreur lors de la suppression de l'actualité: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur: Impossible de supprimer l\'actualité',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: primaryRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildMenuTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Menu de la semaine',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: lightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.edit, color: primaryBlue),
                          onPressed: _showEditMenuDialog,
                          tooltip: 'Modifier le menu',
                        ),
                      ),
                    ],
                  ),
                  Divider(color: lightBlue, thickness: 2),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note, color: primaryBlue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Semaine du ${DateFormat('dd/MM').format(currentWeekStart)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  for (var day in [
                    'Lundi',
                    'Mardi',
                    'Mercredi',
                    'Jeudi',
                    'Vendredi'
                  ]) ...[
                    if (menuSemaine[day]!.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: lightBlue),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                                fontSize: 16,
                              ),
                            ),
                            Divider(color: lightBlue),
                            ...menuSemaine[day]!.map((item) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.restaurant,
                                          size: 16,
                                          color: primaryBlue.withOpacity(0.7)),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                                fontSize: 16,
                              ),
                            ),
                            Divider(color: Colors.grey.shade200),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(
                                child: Text(
                                  'Aucun menu défini',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    return Stack(
      children: [
        events.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/Icone_Actualites.png',
                        width: 80,
                        height: 80,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Aucun événement prévu',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ajoutez des événements à venir pour les parents',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final date = event['date'].toDate();
                  final bool isPast =
                      date.isBefore(DateTime.now().subtract(Duration(days: 1)));

                  return Card(
                    elevation: 3,
                    margin: EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isPast)
                            Container(
                              width: double.infinity,
                              color: Colors.grey.shade200,
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Center(
                                child: Text(
                                  'Événement passé',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event['titre'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isPast
                                              ? Colors.grey.shade600
                                              : primaryBlue,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: primaryRed,
                                      ),
                                      onPressed: () =>
                                          _showDeleteConfirmationDialog(
                                              event['id'],
                                              event['titre'],
                                              false),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isPast
                                        ? Colors.grey.shade100
                                        : lightBlue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: isPast
                                            ? Colors.grey.shade500
                                            : primaryBlue,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        DateFormat('EEEE dd MMMM yyyy', 'fr_FR')
                                            .format(date),
                                        style: TextStyle(
                                          color: isPast
                                              ? Colors.grey.shade600
                                              : Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (event['description'].isNotEmpty) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                    ),
                                    child: Text(
                                      event['description'],
                                      style: TextStyle(
                                        color: isPast
                                            ? Colors.grey.shade500
                                            : Colors.black87,
                                        height: 1.3,
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
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: primaryBlue,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add, size: 28),
            onPressed: () => _showAddEventDialog(false),
          ),
        ),
      ],
    );
  }

  Widget _buildSortiesTab() {
    return Stack(
      children: [
        sorties.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/Icone_Actualites.png',
                        width: 80,
                        height: 80,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.hiking,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Aucune sortie prévue',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ajoutez des sorties à venir pour les parents',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: sorties.length,
                itemBuilder: (context, index) {
                  final sortie = sorties[index];
                  final date = sortie['date'].toDate();
                  final bool isPast =
                      date.isBefore(DateTime.now().subtract(Duration(days: 1)));

                  return Card(
                    elevation: 3,
                    margin: EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isPast)
                            Container(
                              width: double.infinity,
                              color: Colors.grey.shade200,
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Center(
                                child: Text(
                                  'Sortie passée',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sortie['titre'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isPast
                                              ? Colors.grey.shade600
                                              : primaryBlue,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: primaryRed,
                                      ),
                                      onPressed: () =>
                                          _showDeleteConfirmationDialog(
                                              sortie['id'],
                                              sortie['titre'],
                                              true),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isPast
                                            ? Colors.grey.shade100
                                            : lightBlue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: isPast
                                                ? Colors.grey.shade500
                                                : primaryBlue,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            DateFormat('EEEE dd MMMM yyyy',
                                                    'fr_FR')
                                                .format(date),
                                            style: TextStyle(
                                              color: isPast
                                                  ? Colors.grey.shade600
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isPast
                                        ? Colors.grey.shade100
                                        : lightBlue.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: isPast
                                            ? Colors.grey.shade500
                                            : primaryBlue,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        sortie['lieu'],
                                        style: TextStyle(
                                          color: isPast
                                              ? Colors.grey.shade600
                                              : Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (sortie['description'].isNotEmpty) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                    ),
                                    child: Text(
                                      sortie['description'],
                                      style: TextStyle(
                                        color: isPast
                                            ? Colors.grey.shade500
                                            : Colors.black87,
                                        height: 1.3,
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
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: primaryBlue,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add, size: 28),
            onPressed: () => _showAddEventDialog(true),
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmationDialog(String id, String title, bool isSortie) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isSortie ? 'Supprimer cette sortie?' : 'Supprimer cet événement?',
            style: TextStyle(
              color: primaryRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: primaryRed,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Voulez-vous vraiment supprimer "${title}"? Cette action est irréversible.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _deleteActualite(id, isSortie);
                Navigator.of(context).pop();
              },
              child: Text(
                'Supprimer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
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
      context.go('/child-info');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: primaryBlue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryBlue,
              indicatorWeight: 3,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  icon: Icon(Icons.restaurant_menu),
                  text: 'Menu',
                ),
                Tab(
                  icon: Icon(Icons.event),
                  text: 'Événements',
                ),
                Tab(
                  icon: Icon(Icons.hiking),
                  text: 'Sorties',
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  ))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      SingleChildScrollView(child: _buildMenuTab()),
                      _buildEventsTab(),
                      _buildSortiesTab(),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
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
              // Première ligne: nom structure et date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.location_on, color: Colors.white, size: 24),
                  Expanded(
                    child: Text(
                      structureName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Bell icon removed
                ],
              ),
              SizedBox(height: 15),
              Text(
                DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                    .format(DateTime.now())
                    .toLowerCase(),
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 15),
              // Icône et titre de la page
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/Icone_Actualites.png',
                      width: 26,
                      height: 26,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.event_note,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Actualités',
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
      elevation: 8,
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
