import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:go_router/go_router.dart';

class SiesteScreen extends StatefulWidget {
  const SiesteScreen({Key? key}) : super(key: key);

  @override
  _SiesteScreenState createState() => _SiesteScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _SiesteScreenState extends State<SiesteScreen> {
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

  // Utilisation des couleurs officielles de l'application
  Color primaryColor = Color(0xFF3D9DF2); // primaryBlue
  Color secondaryColor = Color(0xFFDFE9F2); // lightBlue

  String _siesteDuration = "1 heure";
  String _sleepQuality = "Bien dormi";
  TextEditingController _observationsController = TextEditingController();
  String _siesteTime = "";

  final List<String> durations = [
    "15 minutes",
    "30 minutes",
    "45 minutes",
    "1 heure",
    "1 heure 15",
    "1 heure 30",
    "1 heure 45",
    "2 heures",
    "2 heures 15",
    "2 heures 30"
  ];

  final List<Map<String, dynamic>> qualityLevels = [
    {"label": "Pas dormi", "stars": 1},
    {"label": "Peu dormi", "stars": 2},
    {"label": "Bien dormi", "stars": 3},
    {"label": "Très bien dormi", "stars": 4},
  ];

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

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
              "🔄 Sieste: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
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
            "👨‍👧‍👦 Sieste: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Sieste: Assistante Maternelle - affichage de tous les enfants");
      }

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui
      List<Map<String, dynamic>> tempEnfants = [];
      for (var child in filteredChildren) {
        if (child['schedule'] != null &&
            child['schedule'][capitalizedWeekday] != null) {
          String? photoUrl = child['photoUrl'];
          tempEnfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'structureId':
                structureId, // Ajouter l'ID de structure pour les requêtes futures
          });
        }
      }

      setState(() {
        enfants = tempEnfants;
        isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  int _getMoonCountFromQuality(String quality) {
    switch (quality) {
      case 'Pas dormi':
        return 1;
      case 'Peu dormi':
        return 2;
      case 'Bien dormi':
        return 3;
      case 'Très bien dormi':
        return 4;
      default:
        return 0;
    }
  }

  Widget _buildMoonIcon() {
    return Icon(
      Icons.nightlight_round,
      color: Colors.indigo,
      size: 20,
    );
  }

  void _showSiesteDetailsPopup(Map<String, dynamic> siesteData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête avec gradient
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
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.nightlight_round,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Sieste de ${siesteData['heure']}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          DateFormat('dd MMMM yyyy', 'fr_FR')
                              .format(siesteData['date'].toDate())
                              .toLowerCase(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenu
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Qualité de sommeil
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Row(
                                children: List.generate(
                                  siesteData['moonCount'] ?? 0,
                                  (index) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.nightlight_round,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "${siesteData['qualite']}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Durée
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Durée: ${siesteData['duration']}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),

                        // Observations
                        if (siesteData['observations']?.isNotEmpty ??
                            false) ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Observations",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  siesteData['observations'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Bouton Fermer
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "FERMER",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
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
      },
    );
  }

  void _showAddSiestePopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String localSiesteTime = _siesteTime;
    String localSiesteDuration = _siesteDuration;
    String localSleepQuality = _sleepQuality;
    String? errorMessage;

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
                        "Ajouter une sieste pour ${enfant['prenom']}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: Text(
                          "Heure de la sieste",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          DatePicker.showTimePicker(
                            context,
                            showSecondsColumn: false,
                            showTitleActions: true,
                            onConfirm: (date) {
                              setState(() {
                                localSiesteTime =
                                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                errorMessage = null;
                              });
                            },
                            currentTime: DateTime.now(),
                            locale: LocaleType.fr,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          localSiesteTime.isEmpty
                              ? 'Choisir l\'heure'
                              : localSiesteTime,
                          style: TextStyle(fontSize: 16, color: primaryColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Comment était la sieste de ${enfant['prenom']} ?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 10),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildSleepQualityButton(
                                  'Pas dormi',
                                  localSleepQuality,
                                  (value) {
                                    setState(() {
                                      localSleepQuality = value;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _buildSleepQualityButton(
                                  'Peu dormi',
                                  localSleepQuality,
                                  (value) {
                                    setState(() {
                                      localSleepQuality = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildSleepQualityButton(
                                  'Bien dormi',
                                  localSleepQuality,
                                  (value) {
                                    setState(() {
                                      localSleepQuality = value;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _buildSleepQualityButton(
                                  'Très bien dormi',
                                  localSleepQuality,
                                  (value) {
                                    setState(() {
                                      localSleepQuality = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Durée de la sieste :",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: localSiesteDuration,
                          isExpanded: true,
                          underline: Container(),
                          items: durations.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              localSiesteDuration = newValue!;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _observationsController,
                        decoration: InputDecoration(
                          labelText: "Observations",
                          labelStyle:
                              TextStyle(fontSize: 16, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
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
                                  fontSize: 16, color: Colors.grey.shade700),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (localSiesteTime.isEmpty) {
                                setState(() {
                                  errorMessage =
                                      'Veuillez sélectionner une heure';
                                });
                                return;
                              }

                              setState(() {
                                errorMessage = null;
                              });

                              _siesteTime = localSiesteTime;
                              _siesteDuration = localSiesteDuration;
                              _sleepQuality = localSleepQuality;

                              _addSiesteToFirebase(childId);
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

  Widget _buildSleepQualityButton(
    String quality,
    String selectedQuality,
    Function(String) onSelect,
  ) {
    bool isSelected = selectedQuality == quality;
    return GestureDetector(
      onTap: () => onSelect(quality),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _getMoonCountFromQuality(quality),
                (index) => Padding(
                  padding: EdgeInsets.only(
                      right: index < _getMoonCountFromQuality(quality) - 1
                          ? 2
                          : 0),
                  child: Icon(Icons.nightlight_round,
                      color: isSelected ? primaryColor : Colors.grey.shade600,
                      size: 16),
                ),
              ),
            ),
            SizedBox(height: 4),
            Text(
              quality,
              style: TextStyle(
                color: isSelected ? primaryColor : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSiesteToFirebase(String childId) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference siesteRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser l'ID de structure correct
          .collection('children')
          .doc(childId)
          .collection('siestes')
          .doc();

      final siesteData = {
        'heure': _siesteTime,
        'date': DateTime.now(),
        'duration': _siesteDuration,
        'qualite': _sleepQuality,
        'moonCount': _getMoonCountFromQuality(_sleepQuality),
        'observations': _observationsController.text,
      };

      await siesteRef.set(siesteData);

      setState(() {
        _siesteTime = '';
        _siesteDuration = '1 heure';
        _sleepQuality = 'Bien dormi';
        _observationsController.clear();
      });

      print("Sieste ajoutée avec succès !");
    } catch (e) {
      print("Erreur lors de l'ajout de la sieste : $e");
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: lightBlue,
      child: Icon(
        Icons.person_outline,
        size: 60,
        color: primaryColor.withOpacity(0.5),
      ),
    );
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    final genre = enfant['genre']?.toString() ?? 'Garçon';
    final isBoy = genre == 'Garçon';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
          // Entête avec photo et nom
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar avec style cohérent
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
                        color:
                            (isBoy ? primaryBlue : primaryRed).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              enfant['photoUrl'],
                              width: 56,
                              height: 56,
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
                          color: isBoy ? primaryBlue : primaryRed,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: primaryColor,
                    size: 32,
                  ),
                  onPressed: () => _showAddSiestePopup(enfant['id']),
                ),
              ],
            ),
          ),

          // Liste des siestes du jour
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('siestes')
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Center(
                    child: Text(
                      "Aucune sieste enregistrée aujourd'hui",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final siesteData = doc.data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showSiesteDetailsPopup(siesteData),
                    child: Container(
                      margin: EdgeInsets.fromLTRB(12, 0, 12, 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: secondaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              siesteData['heure'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Row(
                            children: List.generate(
                              siesteData['moonCount'] ?? 0,
                              (index) => Icon(
                                Icons.nightlight_round,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                          Spacer(),
                          Text(
                            "Durée: ${siesteData['duration']}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
      context.go('/child-info');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Détection de l'iPad
    final bool isTabletDevice = isTablet(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(context),
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
    final genre = enfant['genre']?.toString() ?? 'Garçon';
    final isBoy = genre == 'Garçon';

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
          // Entête avec photo et nom
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar plus grand pour iPad
                Container(
                  width: 70, // Plus grand pour iPad
                  height: 70, // Plus grand pour iPad
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
                        color:
                            (isBoy ? primaryBlue : primaryRed).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              enfant['photoUrl'],
                              width: 66,
                              height: 66,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 28, // Plus grand pour iPad
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            enfant['prenom'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 28, // Plus grand pour iPad
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
                      fontSize: 22, // Plus grand pour iPad
                      fontWeight: FontWeight.bold,
                      color: isBoy ? primaryBlue : primaryRed,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: primaryColor,
                    size: 36, // Plus grand pour iPad
                  ),
                  onPressed: () => _showAddSiestePopup(enfant['id']),
                ),
              ],
            ),
          ),

          // Liste des siestes du jour - adaptée pour iPad
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid)
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('siestes')
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        "Aucune sieste enregistrée aujourd'hui",
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                          fontSize: 16, // Plus grand pour iPad
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    shrinkWrap: true,
                    itemBuilder: (context, idx) {
                      final doc = snapshot.data!.docs[idx];
                      final siesteData = doc.data() as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => _showSiesteDetailsPopup(siesteData),
                        child: Container(
                          margin: EdgeInsets.only(
                              bottom: 12), // Plus d'espace pour iPad
                          padding:
                              EdgeInsets.all(16), // Plus d'espace pour iPad
                          decoration: BoxDecoration(
                            color: secondaryColor,
                            borderRadius: BorderRadius.circular(
                                16), // Plus arrondi pour iPad
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding:
                                    EdgeInsets.all(10), // Plus grand pour iPad
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  siesteData['heure'],
                                  style: TextStyle(
                                    fontSize: 18, // Plus grand pour iPad
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16), // Plus d'espace pour iPad
                              Row(
                                children: List.generate(
                                  siesteData['moonCount'] ?? 0,
                                  (index) => Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.nightlight_round,
                                      color: primaryColor,
                                      size: 22, // Plus grand pour iPad
                                    ),
                                  ),
                                ),
                              ),
                              Spacer(),
                              Text(
                                "Durée: ${siesteData['duration']}",
                                style: TextStyle(
                                  fontSize: 16, // Plus grand pour iPad
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // AppBar personnalisé avec gradient
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
            primaryColor,
            primaryColor.withOpacity(0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
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
                      'assets/images/Icone_Siestes.png',
                      width: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      height: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.nightlight_round,
                        size: isTabletDevice ? 32 : 26, // Plus grand pour iPad
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                        width:
                            isTabletDevice ? 12 : 8), // Plus d'espace pour iPad
                    Text(
                      'Sieste',
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

  // Navigation du bas
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
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

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Siestes.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.nightlight_round,
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
}
