import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poppins_app/widgets/planning_table_view.dart'; // Nouveau widget
import 'package:poppins_app/widgets/planning_garde_form.dart';
import 'package:poppins_app/models/garde_model.dart';
import 'package:poppins_app/models/enfant_model.dart';
import 'package:poppins_app/models/membre_model.dart';
import 'package:poppins_app/services/planning_service.dart';
import 'package:poppins_app/screens/planning_history_screen.dart';
import 'package:go_router/go_router.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({Key? key}) : super(key: key);

  @override
  _PlanningScreenState createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  // Services
  final PlanningService _planningService = PlanningService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // État et données
  DateTime _selectedDate = DateTime.now(); // Jour actuel
  bool _isLoading = true;
  List<Enfant> _enfants = [];
  List<Membre> _membres = [];
  List<Garde> _gardes = [];
  String _structureName = "Chargement...";
  String _structureId = "";
  bool _isMAMStructure = false;

  // Définition des couleurs de la palette (cohérence avec dashboard)
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  // Couleur primaire (cohérence avec votre app)
  late Color primaryColor = primaryBlue;

  @override
  void initState() {
    super.initState();
    // Initialiser la localisation française pour les dates
    initializeDateFormatting('fr_FR', null).then((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Récupérer l'ID de structure
      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        setState(() {
          _isLoading = false;
          _structureName = "Structure non trouvée";
        });
        return;
      }

      _structureId = structureId;

      // 2. Récupérer les informations de la structure
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureDoc.exists) {
        final data = structureDoc.data() ?? {};
        _structureName = data['structureName'] ?? 'Ma Structure';

        // Vérifier si c'est une MAM
        String structureType = data['structureType'] ?? 'AssistanteMaternelle';
        _isMAMStructure = structureType == 'MAM';
      }

      // 3. Charger les enfants, membres et gardes
      await Future.wait([
        _loadEnfants(),
        _loadMembres(),
      ]);

      await _loadGardes();

      setState(() => _isLoading = false);
    } catch (e) {
      print("Erreur lors de l'initialisation des données: $e");
      setState(() {
        _isLoading = false;
        _structureName = "Erreur de chargement";
      });
    }
  }

  Future<String> _getStructureId() async {
    try {
      final user = _auth.currentUser;
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
    } catch (e) {
      print("Erreur lors de la récupération de l'ID de structure: $e");
      return "";
    }
  }

  Future<void> _loadEnfants() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(_structureId)
          .collection('children')
          .get();

      final List<Enfant> enfants = snapshot.docs.map((doc) {
        final data = doc.data();
        return Enfant(
          id: doc.id,
          nom: data['lastName'] ?? '',
          prenom: data['firstName'] ?? 'Sans nom',
          dateNaissance: data['birthDate'] != null
              ? (data['birthDate'] as Timestamp).toDate()
              : DateTime.now(),
          membresIds: data['assignedTo'] != null
              ? List<String>.from(data['assignedTo'])
              : [],
          photoUrl: data['photoUrl'],
          // Assigner une couleur aléatoire si non définie
          couleur: data['planningColor'] ?? _getRandomColor(),
        );
      }).toList();

      setState(() => _enfants = enfants);
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
    }
  }

  String _getRandomColor() {
    // Liste de couleurs pastel pour le planning
    final colors = [
      'FF9AA2',
      'FFB7B2',
      'FFDAC1',
      'E2F0CB',
      'B5EAD7',
      'C7CEEA',
      'B5B9FF',
      'A0E7E5',
      'FDFFB6',
      'FFC6FF'
    ];
    // Sélectionner une couleur aléatoire
    final colorIndex = DateTime.now().millisecondsSinceEpoch % colors.length;
    return colors[colorIndex];
  }

  Future<void> _loadMembres() async {
    try {
      // Pour une structure MAM, charger tous les membres
      if (_isMAMStructure) {
        final snapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(_structureId)
            .collection('members')
            .get();

        final List<Membre> membres = snapshot.docs.map((doc) {
          final data = doc.data();
          return Membre(
            id: doc.id,
            nom: data['lastName'] ?? '',
            prenom: data['firstName'] ?? '',
            mamId: _structureId,
            role: data['role'] ?? 'membre',
            email: data['email'] ?? '', // Récupérer l'email du membre
          );
        }).toList();

        setState(() => _membres = membres);
      } else {
        // Pour une assistante maternelle, créer un seul membre (l'utilisateur)
        final user = _auth.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.email?.toLowerCase() ?? '')
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() ?? {};
            setState(() {
              _membres = [
                Membre(
                  id: user.uid,
                  nom: data['lastName'] ?? '',
                  prenom: data['firstName'] ?? 'Utilisateur',
                  mamId: _structureId,
                  role: 'admin',
                ),
              ];
            });
          }
        }
      }
    } catch (e) {
      print("Erreur lors du chargement des membres: $e");
    }
  }

  Future<void> _loadGardes() async {
    try {
      // Créer la collection gardes si elle n'existe pas
      await _ensureGardesCollectionExists();

      // Initialiser la liste des gardes
      List<Garde> allGardes = [];

      // Récupérer les gardes récurrentes pour le jour sélectionné
      final jourSemaine = _selectedDate.weekday; // 1=lundi, 7=dimanche

      if (jourSemaine > 5) {
        // Weekend - pas de gardes
        setState(() => _gardes = []);
        return;
      }

      // Récupérer les gardes récurrentes pour ce jour de la semaine
      final recurrentSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(_structureId)
          .collection('gardes')
          .where('recurrent', isEqualTo: true)
          .where('jourSemaine', isEqualTo: jourSemaine)
          .get();

      // Période de 24h pour récupérer les gardes exceptionnelles
      final dayStart =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final dayEnd = dayStart.add(Duration(days: 1));

      // Récupérer les gardes exceptionnelles pour cette date spécifique
      final exceptionsSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(_structureId)
          .collection('gardes')
          .where('recurrent', isEqualTo: false)
          .where('dateException',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('dateException', isLessThan: Timestamp.fromDate(dayEnd))
          .get();

      // Traiter les gardes récurrentes
      for (var doc in recurrentSnapshot.docs) {
        final data = doc.data();
        allGardes.add(Garde(
          id: doc.id,
          enfantId: data['enfantId'] ?? '',
          membreId: data['membreId'] ?? '',
          mamId: _structureId,
          jourSemaine: data['jourSemaine'] ?? 1,
          heureDebut: data['heureDebut'] ?? '08:00',
          heureFin: data['heureFin'] ?? '17:00',
          recurrent: true,
        ));
      }

      // Traiter les gardes exceptionnelles
      for (var doc in exceptionsSnapshot.docs) {
        final data = doc.data();
        allGardes.add(Garde(
          id: doc.id,
          enfantId: data['enfantId'] ?? '',
          membreId: data['membreId'] ?? '',
          mamId: _structureId,
          jourSemaine: data['jourSemaine'] ?? jourSemaine,
          heureDebut: data['heureDebut'] ?? '08:00',
          heureFin: data['heureFin'] ?? '17:00',
          recurrent: false,
          dateException: data['dateException'] != null
              ? (data['dateException'] as Timestamp).toDate()
              : null,
        ));
      }

      // Fusion des gardes (priorité aux gardes exceptionnelles)
      List<Garde> mergedGardes = [];

      // D'abord, ajouter toutes les gardes récurrentes
      mergedGardes.addAll(allGardes.where((g) => g.recurrent));

      // Ensuite, pour chaque garde exceptionnelle
      for (var exceptGarde in allGardes.where((g) => !g.recurrent)) {
        // Chercher si une garde récurrente existe pour le même enfant et membre
        final index = mergedGardes.indexWhere((g) =>
            g.recurrent &&
            g.enfantId == exceptGarde.enfantId &&
            g.membreId == exceptGarde.membreId);

        if (index >= 0) {
          // Remplacer la garde récurrente par l'exceptionnelle
          mergedGardes[index] = exceptGarde;
        } else {
          // Ajouter la garde exceptionnelle
          mergedGardes.add(exceptGarde);
        }
      }

      // Mettre à jour allGardes avec les gardes fusionnées
      allGardes = mergedGardes;

      // Récupérer tous les enfants pour leur planning schedule
      final childrenSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(_structureId)
          .collection('children')
          .get();

      for (var childDoc in childrenSnapshot.docs) {
        final childData = childDoc.data();
        final childId = childDoc.id;

        // Trouver l'enfant dans notre liste chargée
        final enfant = _enfants.firstWhere(
          (e) => e.id == childId,
          orElse: () => Enfant(
            id: childId,
            nom: childData['lastName'] ?? '',
            prenom: childData['firstName'] ?? 'Sans nom',
            dateNaissance: DateTime.now(),
            membresIds: childData['assignedTo'] != null
                ? List<String>.from(childData['assignedTo'])
                : [],
          ),
        );

        // Déterminer l'assistante maternelle responsable de cet enfant
        // CORRECTION ICI: Chercher le membre correct basé sur assignedMemberEmail
        String membreResponsableId = '';

        // Priorité 1: Vérifier le champ assignedMemberEmail pour trouver le membre correspondant
        if (childData.containsKey('assignedMemberEmail') &&
            childData['assignedMemberEmail'] != null) {
          final assignedEmail = childData['assignedMemberEmail'];
          // Trouver le membre avec cet email
          for (var membre in _membres) {
            // Chercher dans la collection membres
            if (_membres.isNotEmpty) {
              final membreDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(assignedEmail)
                  .get();

              if (membreDoc.exists && membreDoc.data() != null) {
                final membreId = membreDoc.id;
                // Trouver si ce membre existe dans notre liste
                final membreCorrespondant = _membres.firstWhere(
                  (m) => m.id == membreId || m.email == assignedEmail,
                  orElse: () => Membre(
                    id: '',
                    nom: '',
                    prenom: '',
                    mamId: '',
                    role: '',
                  ),
                );

                if (membreCorrespondant.id.isNotEmpty) {
                  membreResponsableId = membreCorrespondant.id;
                  break;
                }
              }
            }
          }
        }

        // Priorité 2: Vérifier le champ assignedToMembre si on n'a pas trouvé avec l'email
        if (membreResponsableId.isEmpty &&
            childData.containsKey('assignedToMembre') &&
            childData['assignedToMembre'] != null) {
          membreResponsableId = childData['assignedToMembre'];
        }
        // Priorité 3: Prendre la première assistante dans membresIds
        else if (membreResponsableId.isEmpty && enfant.membresIds.isNotEmpty) {
          membreResponsableId = enfant.membresIds.first;
        }
        // Priorité 4: En dernier recours, utiliser l'utilisateur connecté ou le premier membre
        else if (membreResponsableId.isEmpty && _membres.isNotEmpty) {
          final currentUserUid = _auth.currentUser?.uid ?? '';
          final currentMembre = _membres.firstWhere(
            (m) => m.id == currentUserUid,
            orElse: () => _membres.first,
          );
          membreResponsableId = currentMembre.id;
        }

        // Vérifier si l'enfant a un planning
        if (childData.containsKey('schedule')) {
          final schedule = childData['schedule'];

          // Pour chaque jour dans l'horaire
          if (schedule is Map<String, dynamic>) {
            schedule.forEach((day, segments) {
              // Convertir le nom du jour en numéro de jour (1=Lundi, etc.)
              int jourSchedule;
              switch (day.toLowerCase()) {
                case 'lundi':
                  jourSchedule = 1;
                  break;
                case 'mardi':
                  jourSchedule = 2;
                  break;
                case 'mercredi':
                  jourSchedule = 3;
                  break;
                case 'jeudi':
                  jourSchedule = 4;
                  break;
                case 'vendredi':
                  jourSchedule = 5;
                  break;
                default:
                  jourSchedule = 0;
                  break;
              }

              // Vérifier si c'est le jour que nous sommes en train d'afficher
              if (jourSchedule == jourSemaine) {
                // Traiter les segments selon leur type
                List<Map<String, dynamic>> segmentsList = [];

                if (segments is List) {
                  for (var segment in segments) {
                    if (segment is Map &&
                        segment.containsKey('start') &&
                        segment.containsKey('end')) {
                      segmentsList.add(
                          {'start': segment['start'], 'end': segment['end']});
                    }
                  }
                } else if (segments is Map) {
                  if (segments.containsKey('0')) {
                    segments.forEach((key, value) {
                      if (value is Map &&
                          value.containsKey('start') &&
                          value.containsKey('end')) {
                        segmentsList.add(
                            {'start': value['start'], 'end': value['end']});
                      }
                    });
                  } else if (segments.containsKey('start') &&
                      segments.containsKey('end')) {
                    segmentsList.add(
                        {'start': segments['start'], 'end': segments['end']});
                  }
                }

                // Créer une garde pour chaque segment
                for (var segment in segmentsList) {
                  // Vérifier que nous avons bien trouvé un membre responsable
                  if (membreResponsableId.isNotEmpty) {
                    allGardes.add(Garde(
                      id: 'schedule_${childId}_${day}_${segment['start']}',
                      enfantId: childId,
                      membreId: membreResponsableId,
                      mamId: _structureId,
                      jourSemaine: jourSchedule,
                      heureDebut: segment['start'],
                      heureFin: segment['end'],
                      recurrent: true,
                    ));
                  } else {
                    print(
                        "Impossible de créer une garde pour l'enfant $childId: pas de membre responsable trouvé");
                  }
                }
              }
            });
          }
        }
      }

      setState(() => _gardes = allGardes);
    } catch (e) {
      print("Erreur lors du chargement des gardes: $e");
      setState(() => _gardes = []);
    }
  }

  // Créer la collection gardes si elle n'existe pas encore
  Future<void> _ensureGardesCollectionExists() async {
    try {
      // Vérifier si la collection existe en essayant de récupérer un document
      final testQuery = await FirebaseFirestore.instance
          .collection('structures')
          .doc(_structureId)
          .collection('gardes')
          .limit(1)
          .get();

      // Si la collection n'existe pas, créer un document fictif puis le supprimer
      if (testQuery.docs.isEmpty) {
        print("Initialisation de la collection gardes");

        // Créer un document temporaire pour initialiser la collection
        final tempDocRef = await FirebaseFirestore.instance
            .collection('structures')
            .doc(_structureId)
            .collection('gardes')
            .add({
          'temp': true,
          'createdAt': Timestamp.now(),
        });

        // Supprimer le document temporaire
        await tempDocRef.delete();
      }
    } catch (e) {
      print("Erreur lors de l'initialisation de la collection gardes: $e");
    }
  }

  void _navigateToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 1));
      _loadGardes(); // Recharger les gardes pour le jour suivant
    });
  }

  void _navigateToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(Duration(days: 1));
      _loadGardes(); // Recharger les gardes pour le jour précédent
    });
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanningHistoryScreen(),
      ),
    );
  }

  void _showAddGardeModal() {
    // Vérifier si nous avons des enfants et des membres
    if (_enfants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Vous devez d'abord ajouter des enfants"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Récupérer le jour de la semaine du jour sélectionné
    final jourSemaine = _selectedDate.weekday;
    if (jourSemaine > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pas de garde le week-end"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUserUid = _auth.currentUser?.uid ?? '';
    Membre? currentMembre;

    // Trouver le membre correspondant à l'utilisateur connecté
    if (_isMAMStructure) {
      currentMembre = _membres.firstWhere(
        (m) => m.id == currentUserUid,
        orElse: () => _membres.first,
      );
    } else {
      // Si ce n'est pas une MAM, utiliser le seul membre (l'assistante maternelle)
      currentMembre = _membres.isNotEmpty ? _membres.first : null;
    }

    if (currentMembre == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur d'identification du membre"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Filtrer les enfants assignés à ce membre
    final assignedEnfants = _enfants
        .where(
            (e) => e.membresIds.contains(currentMembre!.id) || !_isMAMStructure)
        .toList();

    if (assignedEnfants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant assigné à ce membre"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Pré-remplir le formulaire avec le jour sélectionné
    Garde preFillGarde = Garde(
      id: '',
      enfantId: assignedEnfants.first.id,
      membreId: currentMembre.id,
      mamId: currentMembre.mamId,
      jourSemaine: jourSemaine,
      heureDebut: '08:00',
      heureFin: '17:00',
      recurrent: true,
    );

    // Afficher le formulaire d'ajout de garde
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permet au modal d'occuper plus d'espace
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(16),
          child: PlanningGardeForm(
            garde: preFillGarde,
            enfants: assignedEnfants,
            membre: currentMembre!,
            onSave: _handleSaveGarde,
          ),
        ),
      ),
    );
  }

  void _handleGardeEdit(Garde garde) {
    // Vérifier si l'utilisateur a le droit de modifier cette garde
    final currentUserUid = _auth.currentUser?.uid ?? '';

    // Un admin peut toujours modifier, un membre ne peut modifier que ses propres gardes
    final currentMembre = _membres.firstWhere(
      (m) => m.id == currentUserUid,
      orElse: () => Membre(
        id: '',
        nom: '',
        prenom: '',
        mamId: '',
        role: '',
      ),
    );

    // Vérifier les droits d'accès
    final bool canEdit =
        currentMembre.role == 'admin' || garde.membreId == currentUserUid;

    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Vous ne pouvez pas modifier les gardes d'un autre membre"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Trouver l'enfant et le membre concernés
    final enfant = _enfants.firstWhere(
      (e) => e.id == garde.enfantId,
      orElse: () => Enfant(
        id: '',
        nom: '',
        prenom: '',
        dateNaissance: DateTime.now(),
        membresIds: [],
      ),
    );

    final membre = _membres.firstWhere(
      (m) => m.id == garde.membreId,
      orElse: () => Membre(
        id: '',
        nom: '',
        prenom: '',
        mamId: '',
        role: '',
      ),
    );

    // Afficher options de modification/suppression
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Garde de ${enfant.prenom}",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Par ${membre.prenom} ${membre.nom}",
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _getJourSemaineText(garde.jourSemaine),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              "${garde.heureDebut} - ${garde.heureFin}",
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditGardeModal(garde);
                  },
                  icon: Icon(Icons.edit),
                  label: Text("Modifier"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteGardeConfirmation(garde);
                  },
                  icon: Icon(Icons.delete),
                  label: Text("Supprimer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getJourSemaineText(int jour) {
    switch (jour) {
      case 1:
        return "Lundi";
      case 2:
        return "Mardi";
      case 3:
        return "Mercredi";
      case 4:
        return "Jeudi";
      case 5:
        return "Vendredi";
      default:
        return "Jour inconnu";
    }
  }

  void _showEditGardeModal(Garde garde) {
    // Trouver l'enfant concerné
    final enfant = _enfants.firstWhere(
      (e) => e.id == garde.enfantId,
      orElse: () => Enfant(
        id: '',
        nom: '',
        prenom: '',
        dateNaissance: DateTime.now(),
        membresIds: [],
      ),
    );

    // Trouver le membre concerné
    final membre = _membres.firstWhere(
      (m) => m.id == garde.membreId,
      orElse: () => Membre(
        id: '',
        nom: '',
        prenom: '',
        mamId: '',
        role: '',
      ),
    );

    // Filtrer les enfants assignés à ce membre
    final assignedEnfants = _enfants
        .where((e) => e.membresIds.contains(membre.id) || !_isMAMStructure)
        .toList();

    // Afficher le formulaire d'édition
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(16),
          child: PlanningGardeForm(
            garde: garde,
            enfants: assignedEnfants,
            membre: membre,
            onSave: _handleSaveGarde,
          ),
        ),
      ),
    );
  }

  void _showDeleteGardeConfirmation(Garde garde) {
    // Trouver l'enfant concerné pour l'affichage
    final enfant = _enfants.firstWhere(
      (e) => e.id == garde.enfantId,
      orElse: () => Enfant(
        id: '',
        nom: '',
        prenom: 'cet enfant',
        dateNaissance: DateTime.now(),
        membresIds: [],
      ),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Supprimer cette garde"),
          content: Text(
              "Voulez-vous vraiment supprimer la garde de ${enfant.prenom} "
              "le ${_getJourSemaineText(garde.jourSemaine)} "
              "de ${garde.heureDebut} à ${garde.heureFin} ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("ANNULER"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleDeleteGarde(garde);
              },
              child: Text(
                "SUPPRIMER",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSaveGarde(Garde garde) async {
    try {
      final result = await _planningService.saveGarde(garde);

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Garde enregistrée avec succès"),
            backgroundColor: Colors.green,
          ),
        );

        // Rafraîchir les données
        _loadGardes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'enregistrement de la garde"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de l'enregistrement de la garde: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleDeleteGarde(Garde garde) async {
    try {
      final result =
          await _planningService.deleteGarde(garde.id, garde.membreId);

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Garde supprimée avec succès"),
            backgroundColor: Colors.green,
          ),
        );

        // Rafraîchir les données
        _loadGardes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la suppression de la garde"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de la suppression de la garde: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Planning"),
          backgroundColor: primaryColor,
        ),
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Planning de $_structureName"),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
        // Ajouter un bouton de retour explicite
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Seulement garder le bouton d'historique
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () => _navigateToHistory(),
            tooltip: 'Historique',
          ),
        ],
      ),
      body: Column(
        children: [
          // Navigation entre jours
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _navigateToPreviousDay,
                  icon: Icon(Icons.arrow_back_ios),
                  color: primaryColor,
                  tooltip: 'Jour précédent',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                        .format(_selectedDate),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _navigateToNextDay,
                  icon: Icon(Icons.arrow_forward_ios),
                  color: primaryColor,
                  tooltip: 'Jour suivant',
                ),
              ],
            ),
          ),

          // Vue principale du planning - Remplacer par notre nouvelle vue tableau
          Expanded(
            child: PlanningTableView(
              selectedDate: _selectedDate,
              membres: _membres,
              enfants: _enfants,
              gardes: _gardes,
              onGardeEdit: _handleGardeEdit,
              primaryColor: primaryColor,
            ),
          ),
        ],
      ),
      // Bouton flottant pour ajouter une garde
    );
  }
}
