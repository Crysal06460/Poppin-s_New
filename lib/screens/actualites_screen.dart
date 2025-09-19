import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';

class ActualitesScreen extends StatefulWidget {
  const ActualitesScreen({Key? key}) : super(key: key);

  @override
  _ActualitesScreenState createState() => _ActualitesScreenState();
}

// Fonction pour détecter si on est sur iPad
bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _ActualitesScreenState extends State<ActualitesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  String structureName = "Chargement...";
  int _selectedIndex = 1;

  // AJOUT: Variables pour gérer l'ID de structure
  String structureId = "";
  String currentUserEmail = "";

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
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // MODIFIÉ: Fonction pour déterminer le bon structureId selon le type (assmat ou MAM)
  Future<void> _loadStructureData() async {
    print("🔧 Actualités: Début du chargement des données de structure");
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Actualités: Utilisateur non connecté");
        setState(() {
          structureName = 'Utilisateur non connecté';
          isLoading = false;
        });
        return;
      }

      print("✅ Actualités: Utilisateur connecté - ${user.email}");

      // Récupérer l'email de l'utilisateur actuel
      currentUserEmail = user.email?.toLowerCase() ?? '';

      // Vérifier si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      // ID de structure à utiliser (par défaut, utiliser l'ID de l'utilisateur)
      structureId = user.uid;

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Pour une MAM: utiliser l'ID de la structure MAM pour que tous les membres voient la même chose
          structureId = userData['structureId'];
          print(
              "🔄 Actualités: Membre MAM détecté - Utilisation de l'ID de structure: $structureId");
        } else {
          print(
              "🔄 Actualités: Assistante Maternelle - Utilisation de l'ID utilisateur: $structureId");
        }
      }

      // Validation que structureId n'est pas vide
      if (structureId.isEmpty) {
        print("❌ Actualités: Structure ID vide");
        setState(() {
          structureName = 'Erreur de structure';
          isLoading = false;
        });
        return;
      }

      // Récupération des informations de la structure avec l'ID correct
      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureSnapshot.exists) {
        final data = structureSnapshot.data() as Map<String, dynamic>;
        setState(() {
          structureName = data['structureName'] ?? 'Structure inconnue';
        });
        print("✅ Actualités: Structure trouvée - ${structureName}");
      } else {
        print("❌ Actualités: Structure non trouvée pour ID: $structureId");
        setState(() {
          structureName = 'Structure introuvable';
          isLoading = false;
        });
        return;
      }

      // Charger les actualités avec le bon structureId
      await _loadActualites();
    } catch (e) {
      print(
          "❌ Actualités: Erreur lors du chargement des données de structure: $e");
      setState(() {
        structureName = 'Erreur de chargement';
        isLoading = false;
      });

      // Afficher une notification d'erreur à l'utilisateur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de chargement des actualités: $e"),
            backgroundColor: primaryRed,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // MODIFIÉ: Utiliser structureId au lieu de user.uid
  Future<void> _checkAndResetWeeklyMenu(String targetStructureId) async {
    try {
      // Récupérer les informations de dernière mise à jour du menu
      final menuInfoDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(targetStructureId) // Utiliser le structureId passé en paramètre
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
            .doc(targetStructureId)
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
                .doc(targetStructureId)
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
              .doc(targetStructureId)
              .collection('actualites')
              .doc('menu_info')
              .update({
            'lastReset': Timestamp.fromDate(currentWeekStart),
          });
        }
      }

      // Réinitialiser le menu si nécessaire
      if (shouldResetMenu) {
        print(
            "Réinitialisation du menu hebdomadaire pour la structure: $targetStructureId");
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
            .doc(targetStructureId)
            .collection('actualites')
            .doc('menu')
            .set(emptyMenu);
      }
    } catch (e) {
      print("Erreur lors de la vérification/réinitialisation du menu: $e");
    }
  }

  // MODIFIÉ: Utiliser structureId au lieu de user.uid
  Future<void> _loadActualites() async {
    setState(() => isLoading = true);
    try {
      // Vérifier que structureId est défini
      if (structureId.isEmpty) {
        print("Erreur: structureId vide");
        setState(() => isLoading = false);
        return;
      }

      // Gérer la réinitialisation hebdomadaire du menu
      await _checkAndResetWeeklyMenu(structureId);

      // Charger les événements
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId
          .collection('actualites')
          .doc('events')
          .collection('items')
          .orderBy('date')
          .get();

      // Charger les sorties
      final sortiesSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId
          .collection('actualites')
          .doc('sorties')
          .collection('items')
          .orderBy('date')
          .get();

      // Charger les menus de la semaine
      final menuSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId
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

  // MODIFIÉ: Utiliser structureId au lieu de user.uid
  Future<void> _addActualite(
      String titre, String description, DateTime date, bool isSortie,
      [String? lieu]) async {
    try {
      // Vérifier que structureId est défini
      if (structureId.isEmpty) {
        print("❌ Actualités: structureId vide lors de l'ajout d'actualité");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: Structure non définie'),
            backgroundColor: primaryRed,
          ),
        );
        return;
      }

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
          .doc(structureId) // Utiliser structureId
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

  // MODIFIÉ: Utiliser structureId au lieu de user.uid
  Future<void> _saveMenu(Map<String, List<String>> menu) async {
    try {
      // Vérifier que structureId est défini
      if (structureId.isEmpty) {
        print("❌ Actualités: structureId vide lors de la sauvegarde du menu");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erreur: Structure non définie - Impossible de sauvegarder le menu'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      // Convertir en Map<String, dynamic> pour Firestore
      final Map<String, dynamic> data = {};
      for (var day in menu.keys) {
        data[day] = menu[day];
      }

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId
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

  // MODIFIÉ: Utiliser structureId au lieu de user.uid
  Future<void> _deleteActualite(String id, bool isSortie) async {
    try {
      // Vérifier que structureId est défini
      if (structureId.isEmpty) {
        print(
            "❌ Actualités: structureId vide lors de la suppression d'actualité");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur: Structure non définie - Impossible de supprimer'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      final collection = isSortie ? 'sorties' : 'events';

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId
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

  // VERSION MOBILE (EXISTANTE) - Menu Tab
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

  // VERSION IPAD - Menu Tab
  Widget _buildMenuTabForTablet() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // En-tête avec gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primaryBlue, primaryBlue.withOpacity(0.85)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.restaurant_menu,
                        color: Colors.white, size: 32),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menu de la semaine',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_note,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Semaine du ${DateFormat('dd/MM').format(currentWeekStart)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.95),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.edit, color: Colors.white, size: 28),
                      onPressed: _showEditMenuDialog,
                      tooltip: 'Modifier le menu',
                      padding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),

            // Contenu en grille
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: 5, // Lundi à Vendredi
                  itemBuilder: (context, index) {
                    final days = [
                      'Lundi',
                      'Mardi',
                      'Mercredi',
                      'Jeudi',
                      'Vendredi'
                    ];
                    final day = days[index];
                    final hasMenu = menuSemaine[day]!.isNotEmpty;

                    return Container(
                      decoration: BoxDecoration(
                        color: hasMenu
                            ? lightBlue.withOpacity(0.3)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasMenu
                              ? primaryBlue.withOpacity(0.3)
                              : Colors.grey.shade200,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: hasMenu
                                        ? primaryBlue.withOpacity(0.1)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today,
                                    color: hasMenu
                                        ? primaryBlue
                                        : Colors.grey.shade500,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: hasMenu
                                        ? primaryBlue
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Expanded(
                              child: hasMenu
                                  ? SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: menuSemaine[day]!
                                            .map((item) => Padding(
                                                  padding: EdgeInsets.only(
                                                      bottom: 8),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Icon(
                                                        Icons.restaurant,
                                                        size: 16,
                                                        color: primaryBlue
                                                            .withOpacity(0.7),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          item,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            height: 1.3,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.restaurant_menu,
                                            size: 32,
                                            color: Colors.grey.shade400,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Aucun menu défini',
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade500,
                                              fontSize: 14,
                                            ),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // VERSION MOBILE (EXISTANTE) - Events Tab
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
                        'Ajoutez des événements à venir',
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

  // VERSION IPAD - Events Tab
  Widget _buildEventsTabForTablet() {
    return Stack(
      children: [
        events.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: lightBlue.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_busy,
                        size: 80,
                        color: primaryBlue.withOpacity(0.6),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Aucun événement prévu',
                      style: TextStyle(
                        fontSize: 24,
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Ajoutez des événements à venir',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Padding(
                padding: EdgeInsets.all(24),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final date = event['date'].toDate();
                    final bool isPast = date
                        .isBefore(DateTime.now().subtract(Duration(days: 1)));

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // En-tête avec statut
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isPast
                                    ? [
                                        Colors.grey.shade400,
                                        Colors.grey.shade500
                                      ]
                                    : [
                                        primaryBlue,
                                        primaryBlue.withOpacity(0.85)
                                      ],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            padding: EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isPast ? Icons.event_busy : Icons.event,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    isPast ? 'Événement passé' : 'Événement',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.white, size: 20),
                                    onPressed: () =>
                                        _showDeleteConfirmationDialog(
                                            event['id'], event['titre'], false),
                                    padding: EdgeInsets.all(8),
                                    constraints: BoxConstraints(
                                        minWidth: 0, minHeight: 0),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Contenu
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['titre'],
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isPast
                                          ? Colors.grey.shade600
                                          : primaryBlue,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 12),
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
                                        Flexible(
                                          child: Text(
                                            DateFormat('dd/MM/yyyy')
                                                .format(date),
                                            style: TextStyle(
                                              color: isPast
                                                  ? Colors.grey.shade600
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (event['description'].isNotEmpty) ...[
                                    SizedBox(height: 12),
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey.shade200),
                                        ),
                                        child: SingleChildScrollView(
                                          child: Text(
                                            event['description'],
                                            style: TextStyle(
                                              color: isPast
                                                  ? Colors.grey.shade500
                                                  : Colors.black87,
                                              height: 1.3,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            backgroundColor: primaryBlue,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: () => _showAddEventDialog(false),
            icon: Icon(Icons.add, size: 24),
            label: Text(
              'Ajouter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // VERSION MOBILE (EXISTANTE) - Sorties Tab
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
                        'Ajoutez des sorties à venir',
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

  // VERSION IPAD - Sorties Tab
  Widget _buildSortiesTabForTablet() {
    return Stack(
      children: [
        sorties.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: lightBlue.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hiking,
                        size: 80,
                        color: primaryBlue.withOpacity(0.6),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Aucune sortie prévue',
                      style: TextStyle(
                        fontSize: 24,
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Ajoutez des sorties à venir',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Padding(
                padding: EdgeInsets.all(24),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: sorties.length,
                  itemBuilder: (context, index) {
                    final sortie = sorties[index];
                    final date = sortie['date'].toDate();
                    final bool isPast = date
                        .isBefore(DateTime.now().subtract(Duration(days: 1)));

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // En-tête avec statut
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isPast
                                    ? [
                                        Colors.grey.shade400,
                                        Colors.grey.shade500
                                      ]
                                    : [
                                        brightCyan,
                                        brightCyan.withOpacity(0.85)
                                      ],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            padding: EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isPast
                                        ? Icons.hiking_outlined
                                        : Icons.hiking,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    isPast ? 'Sortie passée' : 'Sortie',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.white, size: 20),
                                    onPressed: () =>
                                        _showDeleteConfirmationDialog(
                                            sortie['id'],
                                            sortie['titre'],
                                            true),
                                    padding: EdgeInsets.all(8),
                                    constraints: BoxConstraints(
                                        minWidth: 0, minHeight: 0),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Contenu
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sortie['titre'],
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isPast
                                          ? Colors.grey.shade600
                                          : primaryBlue,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isPast
                                              ? Colors.grey.shade100
                                              : lightBlue,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 14,
                                              color: isPast
                                                  ? Colors.grey.shade500
                                                  : primaryBlue,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              DateFormat('dd/MM/yyyy')
                                                  .format(date),
                                              style: TextStyle(
                                                color: isPast
                                                    ? Colors.grey.shade600
                                                    : Colors.black87,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
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
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isPast
                                          ? Colors.grey.shade100
                                          : brightCyan.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: isPast
                                              ? Colors.grey.shade500
                                              : primaryBlue,
                                        ),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            sortie['lieu'],
                                            style: TextStyle(
                                              color: isPast
                                                  ? Colors.grey.shade600
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (sortie['description'].isNotEmpty) ...[
                                    SizedBox(height: 12),
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey.shade200),
                                        ),
                                        child: SingleChildScrollView(
                                          child: Text(
                                            sortie['description'],
                                            style: TextStyle(
                                              color: isPast
                                                  ? Colors.grey.shade500
                                                  : Colors.black87,
                                              height: 1.3,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            backgroundColor: brightCyan,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: () => _showAddEventDialog(true),
            icon: Icon(Icons.add, size: 24, color: Colors.white),
            label: Text(
              'Ajouter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
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
                'Voulez-vous vraiment supprimer "${title}"?',
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
    // Ne pas changer _selectedIndex car nous sommes sur la page actualités
    // qui n'est pas dans la bottom nav standard

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
      backRoute: '/home', // Route de retour en swipe
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ✨ NOUVEAU : CommonAppBar remplace _buildAppBar(context, isTabletDevice)
            CommonAppBar(
              title: 'Actualités',
              structureName: structureName,
              iconPath: 'assets/images/Icone_Actualites.png',
              backRoute: '/home',
              primaryColor: primaryBlue,
            ),

            // 🔄 GARDÉ IDENTIQUE : TabBar et contenu existant
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
                  fontSize: isTabletDevice ? 16 : 14,
                ),
                tabs: [
                  Tab(
                    icon: Icon(Icons.restaurant_menu,
                        size: isTabletDevice ? 26 : 22),
                    text: 'Menu',
                  ),
                  Tab(
                    icon: Icon(Icons.event, size: isTabletDevice ? 26 : 22),
                    text: 'Événements',
                  ),
                  Tab(
                    icon: Icon(Icons.hiking, size: isTabletDevice ? 26 : 22),
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
                        // Utilisation conditionnelle des widgets selon le device
                        isTabletDevice
                            ? _buildMenuTabForTablet()
                            : SingleChildScrollView(child: _buildMenuTab()),
                        isTabletDevice
                            ? _buildEventsTabForTablet()
                            : _buildEventsTab(),
                        isTabletDevice
                            ? _buildSortiesTabForTablet()
                            : _buildSortiesTab(),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
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
      currentIndex: 1,
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
