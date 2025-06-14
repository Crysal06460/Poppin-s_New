import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poppins_app/models/garde_model.dart';
import 'package:poppins_app/models/enfant_model.dart';
import 'package:poppins_app/models/membre_model.dart';
import 'package:poppins_app/services/planning_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/animation.dart';

class PlanningHistoryScreen extends StatefulWidget {
  const PlanningHistoryScreen({Key? key}) : super(key: key);

  @override
  _PlanningHistoryScreenState createState() => _PlanningHistoryScreenState();
}

class _PlanningHistoryScreenState extends State<PlanningHistoryScreen> {
  // Services
  final PlanningService _planningService = PlanningService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // État et données
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  List<Enfant> _enfants = [];
  List<Membre> _membres = [];
  List<Garde> _gardesForSelectedDate = [];
  String _structureName = "Chargement...";
  String _structureId = "";
  bool _isMAMStructure = false;

  // Définition des couleurs de la palette
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  // Couleur primaire
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
      final structureId = await _planningService.getCurrentStructureId();
      if (structureId.isEmpty) {
        setState(() {
          _isLoading = false;
          _structureName = "Structure non trouvée";
        });
        return;
      }

      _structureId = structureId;

      // 2. Récupérer les informations de la structure
      final structureDoc =
          await _firestore.collection('structures').doc(structureId).get();

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

      await _loadGardesForSelectedDate();

      // 4. Purger les anciennes données
      _purgeOldData();

      setState(() => _isLoading = false);
    } catch (e) {
      print("Erreur lors de l'initialisation des données: $e");
      setState(() {
        _isLoading = false;
        _structureName = "Erreur de chargement";
      });
    }
  }

  Future<void> _loadEnfants() async {
    try {
      final snapshot = await _firestore
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
          couleur: data['planningColor'] ?? '',
        );
      }).toList();

      setState(() => _enfants = enfants);
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
    }
  }

  Future<void> _loadMembres() async {
    try {
      // Pour une structure MAM, charger tous les membres
      if (_isMAMStructure) {
        final snapshot = await _firestore
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
            email: data['email'] ?? '',
          );
        }).toList();

        setState(() => _membres = membres);
      } else {
        // Pour une assistante maternelle, créer un seul membre
        final user = _auth.currentUser;
        if (user != null) {
          final userDoc = await _firestore
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
                  email: user.email ?? '',
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

  Future<void> _loadGardesForSelectedDate() async {
    try {
      setState(() => _gardesForSelectedDate = []);

      // Check if weekend - no gardes
      final jourSemaine = _selectedDate.weekday;
      if (jourSemaine > 5) {
        return; // No need to query the database for weekends
      }

      // Create the start and end of the selected day in local timezone
      final selectedDateStart =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

      final selectedDateEnd = selectedDateStart.add(Duration(days: 1));

      // Convert to Timestamps for Firestore query
      final startTimestamp = Timestamp.fromDate(selectedDateStart);
      final endTimestamp = Timestamp.fromDate(selectedDateEnd);

      print(
          "Searching for gardes between: ${selectedDateStart.toIso8601String()} and ${selectedDateEnd.toIso8601String()}");

      // 1. First get all EXCEPTIONAL gardes for this specific date
      final exceptionsSnapshot = await _firestore
          .collection('structures')
          .doc(_structureId)
          .collection('gardes')
          .where('recurrent', isEqualTo: false)
          .where('dateException', isGreaterThanOrEqualTo: startTimestamp)
          .where('dateException', isLessThan: endTimestamp)
          .get();

      print("Found ${exceptionsSnapshot.docs.length} exceptional gardes");

      // 2. Then get all RECURRENT gardes for this day of week
      final recurrentSnapshot = await _firestore
          .collection('structures')
          .doc(_structureId)
          .collection('gardes')
          .where('recurrent', isEqualTo: true)
          .where('jourSemaine', isEqualTo: jourSemaine)
          .get();

      print("Found ${recurrentSnapshot.docs.length} recurrent gardes");

      // Combine both types of gardes
      List<Garde> allGardes = [];

      // Process exceptional gardes
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

      // Process recurrent gardes
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

      // 3. Check the horaires_history collection for this date
      try {
        final historySnapshot = await _firestore
            .collection('structures')
            .doc(_structureId)
            .collection('horaires_history')
            .where('date',
                isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDateStart))
            .get();

        print("Found ${historySnapshot.docs.length} history records");

        // Regrouper les données par enfant
        Map<String, Map<String, dynamic>> enfantsData = {};

        // Process history records
        for (var doc in historySnapshot.docs) {
          final data = doc.data();
          print("Processing history record: $data");

          final childId = data['childId'] ?? '';
          final actionType = data['actionType'] ?? '';
          final userEmail =
              data['userEmail'] ?? ''; // EMAIL du membre qui a fait l'action

          if (childId.isNotEmpty) {
            // Initialiser les données pour cet enfant si pas encore fait
            if (!enfantsData.containsKey(childId)) {
              enfantsData[childId] = {
                'childId': childId,
                'prenom': data['prenom'] ?? '',
                'heureDebut': data['heureDebut'] ?? '08:00', // Heure planifiée
                'heureFin': data['heureFin'] ?? '17:00', // Heure planifiée
                'arriveeReelle': null,
                'departReel': null,
                'userEmail':
                    userEmail, // Stocker l'email pour la correspondance
              };
            }

            // Récupérer les heures réelles depuis les segments si disponibles
            if (data['segments'] != null && data['segments'] is List) {
              final segments = data['segments'] as List;
              if (segments.isNotEmpty && segments[0] is Map) {
                final segment = segments[0] as Map<String, dynamic>;

                if (segment['arrivee'] != null) {
                  enfantsData[childId]!['arriveeReelle'] = segment['arrivee'];
                }
                if (segment['depart'] != null) {
                  enfantsData[childId]!['departReel'] = segment['depart'];
                }
              }
            }

            // Sinon, utiliser les heures de l'exactTime selon le type d'action
            if (enfantsData[childId]!['arriveeReelle'] == null &&
                actionType == 'arrivee') {
              enfantsData[childId]!['arriveeReelle'] = data['heure'] ??
                  data['exactTime']?.toString().split(' ').last ??
                  null;
            }
            if (enfantsData[childId]!['departReel'] == null &&
                actionType == 'depart') {
              enfantsData[childId]!['departReel'] = data['heure'] ??
                  data['exactTime']?.toString().split(' ').last ??
                  null;
            }

            // Mettre à jour l'email si pas encore défini
            if (enfantsData[childId]!['userEmail'].isEmpty &&
                userEmail.isNotEmpty) {
              enfantsData[childId]!['userEmail'] = userEmail;
            }
          }
        }

        // Créer les gardes à partir des données regroupées
        for (var enfantData in enfantsData.values) {
          final childId = enfantData['childId'];
          final userEmail = enfantData['userEmail'];

          // Trouver le membre correspondant à l'email
          String membreId = '';

          if (userEmail.isNotEmpty) {
            // Chercher le membre par email
            final membre = _membres.firstWhere(
              (m) => m.email.toLowerCase() == userEmail.toLowerCase(),
              orElse: () => Membre(
                id: '',
                nom: '',
                prenom: '',
                mamId: '',
                role: '',
                email: '',
              ),
            );

            if (membre.id.isNotEmpty) {
              membreId = membre.id;
              print(
                  "Found member ${membre.prenom} ${membre.nom} (${membre.id}) for email $userEmail");
            }
          }

          // Si pas trouvé par email, essayer avec assignedTo de l'enfant
          if (membreId.isEmpty) {
            final enfant = _enfants.firstWhere(
              (e) => e.id == childId,
              orElse: () => Enfant(
                id: '',
                nom: '',
                prenom: '',
                dateNaissance: DateTime.now(),
                membresIds: [],
              ),
            );

            if (enfant.membresIds.isNotEmpty) {
              // Les membresIds peuvent contenir des emails, essayons de faire la correspondance
              for (String assignedId in enfant.membresIds) {
                final membre = _membres.firstWhere(
                  (m) =>
                      m.id == assignedId ||
                      m.email.toLowerCase() == assignedId.toLowerCase(),
                  orElse: () => Membre(
                      id: '',
                      nom: '',
                      prenom: '',
                      mamId: '',
                      role: '',
                      email: ''),
                );
                if (membre.id.isNotEmpty) {
                  membreId = membre.id;
                  print(
                      "Found member via assignedTo: ${membre.prenom} ${membre.nom} (${membre.id})");
                  break;
                }
              }
            }
          }

          // Fallback au premier membre si toujours pas trouvé
          if (membreId.isEmpty && _membres.isNotEmpty) {
            membreId = _membres.first.id;
            print("Fallback to first member: ${_membres.first.id}");
          }

          // Utiliser les heures réelles si disponibles, sinon les heures planifiées
          final heureDebut = enfantsData[childId]!['arriveeReelle'] ??
              enfantsData[childId]!['heureDebut'];
          final heureFin = enfantsData[childId]!['departReel'] ??
              enfantsData[childId]!['heureFin'];

          allGardes.add(Garde(
            id: 'history_${childId}',
            enfantId: childId,
            membreId: membreId,
            mamId: _structureId,
            jourSemaine: jourSemaine,
            heureDebut: heureDebut,
            heureFin: heureFin,
            recurrent: false,
            dateException: selectedDateStart,
          ));

          print(
              "Added history garde for child: $childId assigned to member: $membreId (email: $userEmail) from $heureDebut to $heureFin (${enfantData['prenom']})");
        }
      } catch (e) {
        print("No history collection or error: $e");
      }

      // Check if we found any gardes
      if (allGardes.isEmpty) {
        print(
            "No gardes found for ${DateFormat('yyyy-MM-dd').format(selectedDateStart)}");
      }

      // Merge gardes (prioritize history over recurrent and exceptional)
      List<Garde> mergedGardes = [];

      // First add all recurrent gardes
      mergedGardes.addAll(allGardes.where((g) => g.recurrent));

      // Then for each non-recurrent garde (exceptional and history)
      for (var nonRecurrentGarde in allGardes.where((g) => !g.recurrent)) {
        // Check if there's already a recurrent garde for this child
        final index = mergedGardes.indexWhere(
            (g) => g.recurrent && g.enfantId == nonRecurrentGarde.enfantId);

        if (index >= 0) {
          // Replace the recurrent garde with the non-recurrent one
          mergedGardes[index] = nonRecurrentGarde;
        } else {
          // Add the non-recurrent garde
          mergedGardes.add(nonRecurrentGarde);
        }
      }

      print("Final merged gardes count: ${mergedGardes.length}");
      for (var garde in mergedGardes) {
        final membre = _membres.firstWhere((m) => m.id == garde.membreId,
            orElse: () => Membre(
                id: '',
                nom: 'Inconnu',
                prenom: 'Inconnu',
                mamId: '',
                role: '',
                email: ''));
        print(
            "Final garde: ${garde.enfantId} assigned to member ${garde.membreId} (${membre.prenom} ${membre.nom}) from ${garde.heureDebut} to ${garde.heureFin}");
      }

      setState(() => _gardesForSelectedDate = mergedGardes);
    } catch (e) {
      print("Error in _loadGardesForSelectedDate: $e");
      setState(() => _gardesForSelectedDate = []);
    }
  }

  // Purger les gardes de plus de 6 mois
  Future<void> _purgeOldData() async {
    try {
      // Date limite : 6 mois en arrière
      final sixMonthsAgo = DateTime.now().subtract(Duration(days: 180));
      final timestamp = Timestamp.fromDate(sixMonthsAgo);

      // Récupérer toutes les gardes exceptionnelles plus anciennes que 6 mois
      final oldGardesSnapshot = await _firestore
          .collection('structures')
          .doc(_structureId)
          .collection('gardes')
          .where('recurrent', isEqualTo: false)
          .where('dateException', isLessThan: timestamp)
          .get();

      // Supprimer ces gardes
      final batch = _firestore.batch();
      for (var doc in oldGardesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print(
          'Purge de ${oldGardesSnapshot.docs.length} anciennes gardes effectuée');
    } catch (e) {
      print('Erreur lors de la purge des données anciennes: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    // Date minimale : 6 mois en arrière
    final sixMonthsAgo = DateTime.now().subtract(Duration(days: 180));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: sixMonthsAgo,
      lastDate: DateTime.now(),
      locale: Locale('fr', 'FR'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadGardesForSelectedDate();
    }
  }

  // Générer un affichage textuel des gardes par membre
  Widget _buildGardeView() {
    // Regrouper les gardes par membre
    Map<String, List<Garde>> gardesByMembre = {};

    for (var membre in _membres) {
      gardesByMembre[membre.id] = _gardesForSelectedDate
          .where((garde) => garde.membreId == membre.id)
          .toList();
    }

    if (_gardesForSelectedDate.isEmpty || _selectedDate.weekday > 5) {
      // Afficher un message si pas de gardes ce jour ou si c'est le week-end
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                _selectedDate.weekday > 5 ? Icons.weekend : Icons.event_busy,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              _selectedDate.weekday > 5
                  ? "Pas de garde le week-end"
                  : "Pas de garde enregistrée pour cette date",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Sélectionnez une autre date",
                style: TextStyle(
                  fontSize: 16,
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...gardesByMembre.entries.map((entry) {
            final membreId = entry.key;
            final membreGardes = entry.value;

            // Si pas de gardes pour ce membre, ne pas l'afficher
            if (membreGardes.isEmpty) {
              return SizedBox.shrink();
            }

            final membre = _membres.firstWhere(
              (m) => m.id == membreId,
              orElse: () => Membre(
                id: '',
                nom: 'Inconnu',
                prenom: 'Inconnu',
                mamId: '',
                role: '',
                email: '',
              ),
            );

            return Container(
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte pour le membre
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '${membre.prenom} ${membre.nom}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cartes pour les enfants
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ...membreGardes.map((garde) {
                          final enfant = _enfants.firstWhere(
                            (e) => e.id == garde.enfantId,
                            orElse: () => Enfant(
                              id: '',
                              nom: 'Inconnu',
                              prenom: 'Inconnu',
                              dateNaissance: DateTime.now(),
                              membresIds: [],
                            ),
                          );

                          // Déterminer la couleur de l'enfant ou utiliser une par défaut
                          Color enfantColor = Colors.blueGrey;
                          if (enfant.couleur?.isNotEmpty ?? false) {
                            try {
                              enfantColor =
                                  Color(int.parse('0xFF${enfant.couleur}'));
                            } catch (e) {
                              // Utiliser la couleur par défaut
                            }
                          }

                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: enfantColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: enfantColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: enfantColor.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      enfant.prenom.isNotEmpty
                                          ? enfant.prenom[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${enfant.prenom} ${enfant.nom}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.schedule,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'de ${garde.heureDebut} à ${garde.heureFin}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "Historique des plannings",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: primaryColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: 20),
              Text(
                "Chargement des données...",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Historique des plannings",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0, // Enlever l'ombre
        iconTheme: IconThemeData(color: Colors.white),
        // Bouton de retour explicite
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // En-tête avec le nom de la structure et la date
          Container(
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 0),
            child: Column(
              children: [
                // Nom de la structure
                Text(
                  'Structure: $_structureName',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 16),

                // Date avec format amélioré
                Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),

                // Bouton de changement de date
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    'Changer de date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          // Vue principale des gardes avec design amélioré
          Expanded(
            child: _buildGardeView(),
          ),

          // Pied de page avec info sur la rétention des données
          Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Colors.grey.shade100,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.grey.shade700,
                ),
                SizedBox(width: 8),
                Text(
                  'Les données de planning sont conservées pendant 6 mois.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
