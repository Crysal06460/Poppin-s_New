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

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "🔄 Recap: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
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

      // Appliquer le filtrage selon le type de structure (MAM ou AssistanteMaternelle)
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
          });
        }
      }

      // Charger les données pour tous les enfants
      if (enfants.isNotEmpty) {
        for (var enfant in enfants) {
          await _loadChildRecapData(enfant['id'], structureId);
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadChildRecapData(String childId, String structureId) async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

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

      // Récupérer les horaires (arrivée/départ)
      final horairesSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('horaires_history')
          .where('childId', isEqualTo: childId)
          .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(today))
          .get();

      for (var doc in horairesSnapshot.docs) {
        final data = doc.data();
        if (data['actionType'] == 'arrivee') {
          tempRecapData['horaires']!.add({
            'heure': data['heure'] ?? _formatTimestamp(data['timestamp']),
            'type': 'arrivee',
            'details': 'Arrivée',
          });
        } else if (data['actionType'] == 'depart') {
          tempRecapData['horaires']!.add({
            'heure': data['heure'] ?? _formatTimestamp(data['timestamp']),
            'type': 'depart',
            'details': 'Départ',
          });
        }
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête avec dégradé de couleur et nom de l'enfant
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isBoy
                          ? [primaryBlue, primaryBlue.withOpacity(0.8)]
                          : [primaryRed, primaryRed.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isBoy
                                ? [
                                    primaryBlue.withOpacity(0.2),
                                    primaryBlue.withOpacity(0.5)
                                  ]
                                : [
                                    primaryRed.withOpacity(0.2),
                                    primaryRed.withOpacity(0.5)
                                  ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: enfant['photoUrl'] != null
                              ? ClipOval(
                                  child: Image.network(
                                    enfant['photoUrl'],
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error,
                                            stackTrace) =>
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
                              '${enfant['prenom']} ${enfant['nom']}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Récapitulatif du ${DateFormat('dd MMMM yyyy', 'fr_FR').format(DateTime.now())}',
                              style: TextStyle(
                                fontSize: 14,
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
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: categoriesToShow.map((category) {
                          return _buildRecapSection(
                              category, childData[category] ?? []);
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // Bouton Fermer
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      backgroundColor: Colors.grey.shade200,
                    ),
                    child: Text(
                      'FERMER',
                      style: TextStyle(
                        color: isBoy ? primaryBlue : primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

  Widget _buildRecapSection(String category, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return Container();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
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
            padding: EdgeInsets.all(12),
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
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  category.substring(0, 1).toUpperCase() +
                      category.substring(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor[category]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${items.length}",
                    style: TextStyle(
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
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor[category]!.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    item['heure'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  category == 'photos'
                      ? '1 photo' // We'll keep this as "1 photo" since each entry represents a single photo
                      : (item['type'] ?? item['details'] ?? ''),
                  style: TextStyle(
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
                          color: Colors.black,
                        ),
                      )
                    : null,
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.black),
                dense: true,
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
                            "${count} ${category.substring(0, 1).toUpperCase() + category.substring(1)}",
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
  Widget _buildTabletLayout() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 cartes par ligne
        childAspectRatio: 1.5, // Rapport hauteur/largeur adapté
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
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
                  // Photo de l'enfant - plus grande pour iPad
                  Container(
                    width: 70,
                    height: 70,
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
                                width: 66,
                                height: 66,
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
                            fontSize: 22, // Plus grand pour iPad
                            fontWeight: FontWeight.bold,
                            color: isBoy ? primaryBlue : primaryRed,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMMM yyyy', 'fr_FR')
                              .format(DateTime.now()),
                          style: TextStyle(
                            fontSize: 16, // Plus grand pour iPad
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
                          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.summarize, color: primaryBlue, size: 22),
                          SizedBox(width: 6),
                          Text(
                            '${activitesCountByChild[childId]}',
                            style: TextStyle(
                              fontSize: 16,
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
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: hasActivites
                      ? lightBlue.withOpacity(0.3)
                      : Colors.grey.shade100,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: hasActivites
                    ? Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: categoryCounts.entries.map((entry) {
                          final category = entry.key;
                          final count = entry.value;
                          return Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  _getCategoryColor[category]!.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getCategoryColor[category]!
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon[category],
                                  color: _getCategoryColor[category],
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "${count} ${category.substring(0, 1).toUpperCase() + category.substring(1)}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _getCategoryColor[category],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    : Center(
                        child: Text(
                          'Aucune activité enregistrée aujourd\'hui',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
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
    // Détection de l'iPad
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // En-tête avec dégradé bleu
          Container(
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
                              fontSize: isTabletDevice
                                  ? 28
                                  : 24, // Plus grand pour iPad
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTabletDevice
                                ? 16
                                : 12, // Plus grand pour iPad
                            vertical:
                                isTabletDevice ? 8 : 6, // Plus grand pour iPad
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            DateFormat('EEEE d MMMM', 'fr_FR')
                                .format(DateTime.now()),
                            style: TextStyle(
                              fontSize: isTabletDevice
                                  ? 16
                                  : 14, // Plus grand pour iPad
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                        height: isTabletDevice
                            ? 22
                            : 15), // Plus d'espace pour iPad
                    // Icône et titre de la page
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            isTabletDevice ? 22 : 16, // Plus grand pour iPad
                        vertical:
                            isTabletDevice ? 12 : 8, // Plus grand pour iPad
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white,
                            width:
                                isTabletDevice ? 2.5 : 2 // Plus épais pour iPad
                            ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/Icone_Recaptitulatif.png',
                            width: isTabletDevice
                                ? 36
                                : 30, // Plus grand pour iPad
                            height: isTabletDevice
                                ? 36
                                : 30, // Plus grand pour iPad
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.summarize_outlined,
                              size: isTabletDevice
                                  ? 32
                                  : 26, // Plus grand pour iPad
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(
                              width: isTabletDevice
                                  ? 12
                                  : 8), // Plus d'espace pour iPad
                          Text(
                            'Récapitulatif',
                            style: TextStyle(
                              fontSize: isTabletDevice
                                  ? 24
                                  : 20, // Plus grand pour iPad
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
          ),
          // Contenu principal
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  ))
                : enfants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/Icone_Recaptitulatif.png',
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
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
                      )
                    : isTabletDevice
                        ? _buildTabletLayout() // Layout adapté pour iPad
                        : ListView.builder(
                            itemCount: enfants.length,
                            itemBuilder: _buildEnfantCard,
                          ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
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
