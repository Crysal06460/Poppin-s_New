import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:poppins_app/widgets/custom_bottom_navigation.dart';

class ChangeScreen extends StatefulWidget {
  const ChangeScreen({Key? key}) : super(key: key);

  @override
  _ChangeScreenState createState() => _ChangeScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _ChangeScreenState extends State<ChangeScreen> {
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

  // Utiliser les couleurs officielles
  Color primaryColor = Color(0xFF3D9DF2); // primaryBlue par défaut

  String _changeType = "Couche";
  TextEditingController _observationsController = TextEditingController();
  bool _pipi = false;
  bool _selles = false;
  String _careTime = "";

  final List<String> changeTypes = [
    "Couche",
    "Pot",
    "Toilette",
  ];

  List<String> soins = [];

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  IconData _getChangeTypeIcon(String type) {
    switch (type) {
      case 'Couche':
        return Icons.child_care;
      case 'Pot':
        return Icons.event_seat;
      case 'Toilette':
        return Icons.wc;
      default:
        return Icons.child_care;
    }
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
              "🔄 Change: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
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
            "👨‍👧‍👦 Change: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Change: Assistante Maternelle - affichage de tous les enfants");
      }

      // Maintenant, filtrer les enfants qui ont un programme pour aujourd'hui
      enfants = [];
      for (var child in filteredChildren) {
        if (child['schedule'] != null &&
            child['schedule'][capitalizedWeekday] != null) {
          String? photoUrl = child['photoUrl'];
          enfants.add({
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'structureId':
                structureId, // Ajouter l'ID de structure pour les requêtes futures
          });
        }
      }
      setState(() => isLoading = false);
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  void _showChangeDetailsPopup(Map<String, dynamic> changeData) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.03,
            vertical: screenHeight * 0.02,
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: screenWidth * 0.94,
              maxHeight: screenHeight * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryBlue.withOpacity(0.85), primaryBlue],
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getChangeTypeIcon(changeData['type']),
                            color: Colors.white,
                            size: screenWidth * 0.08,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Change de ${changeData['heure']}",
                                style: TextStyle(
                                  fontSize: screenWidth * 0.06,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                DateFormat('dd MMMM yyyy', 'fr_FR')
                                    .format(changeData['date'].toDate())
                                    .toLowerCase(),
                                style: TextStyle(
                                  fontSize: screenWidth * 0.045,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenu
                  Padding(
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type de change
                        Row(
                          children: [
                            Icon(_getChangeTypeIcon(changeData['type']),
                                color: primaryBlue, size: screenWidth * 0.06),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              changeData['type'],
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: screenWidth * 0.04),

                        // Pipi/Selles
                        Row(
                          children: [
                            if (changeData['pipi'])
                              Container(
                                margin:
                                    EdgeInsets.only(right: screenWidth * 0.03),
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenWidth * 0.02,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Pipi",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                            if (changeData['selles'])
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.04,
                                  vertical: screenWidth * 0.02,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryYellow.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Selles",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                    color: primaryYellow.withOpacity(0.8),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Soins
                        if (changeData['soins']?.isNotEmpty ?? false) ...[
                          SizedBox(height: screenWidth * 0.05),
                          Text(
                            "Soins",
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Wrap(
                            spacing: screenWidth * 0.02,
                            runSpacing: screenWidth * 0.02,
                            children: changeData['soins']
                                .map<Widget>(
                                  (soin) => Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.03,
                                      vertical: screenWidth * 0.02,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: primaryBlue.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      soin,
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],

                        // Observations
                        if (changeData['observations']?.isNotEmpty ??
                            false) ...[
                          SizedBox(height: screenWidth * 0.05),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            decoration: BoxDecoration(
                              color: lightBlue.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: lightBlue),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Observations",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.045,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: screenWidth * 0.02),
                                Text(
                                  changeData['observations'],
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Bouton Fermer
                        SizedBox(height: screenWidth * 0.05),
                        Container(
                          width: double.infinity,
                          height: 56,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Fermer",
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
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

  void _showAddChangePopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String? errorMessage;

    _observationsController.clear();
    _pipi = false;
    _selles = false;
    soins = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ajouter un change pour ${enfant['prenom']}",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: Text(
                          "Heure du change",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
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
                                _careTime =
                                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                errorMessage = null;
                              });
                            },
                            currentTime: DateTime.now(),
                            locale: LocaleType.fr,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lightBlue,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          _careTime.isEmpty ? 'Choisir l\'heure' : _careTime,
                          style: TextStyle(fontSize: 18, color: primaryBlue),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Type de change",
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
                          value: _changeType,
                          isExpanded: true,
                          underline: Container(),
                          items: changeTypes.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _changeType = newValue!;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Checkbox(
                            value: _pipi,
                            activeColor: primaryBlue,
                            onChanged: (value) {
                              setState(() {
                                _pipi = value!;
                              });
                            },
                          ),
                          Text(
                            "Pipi",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 20),
                          Checkbox(
                            value: _selles,
                            activeColor: primaryBlue,
                            onChanged: (value) {
                              setState(() {
                                _selles = value!;
                              });
                            },
                          ),
                          Text(
                            "Selles",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Soins complémentaires",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Nez', 'Yeux', 'Oreilles', 'Crème']
                            .map(
                              (soin) => FilterChip(
                                label: Text(soin),
                                selected: soins.contains(soin),
                                selectedColor: primaryBlue.withOpacity(0.15),
                                checkmarkColor: primaryBlue,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      soins.add(soin);
                                    } else {
                                      soins.remove(soin);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryBlue),
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
                              color: primaryRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: primaryRed.withOpacity(0.3)),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: primaryRed,
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
                              "Annuler",
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey.shade700),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (_careTime.isEmpty) {
                                setState(() {
                                  errorMessage =
                                      'Veuillez sélectionner une heure';
                                });
                                return;
                              }
                              setState(() => errorMessage = null);
                              _addChangeToFirebase(childId);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Ajouter",
                              style: TextStyle(
                                fontSize: 18,
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

  Future<void> _addChangeToFirebase(String childId) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference changeRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser l'ID de structure correct
          .collection('children')
          .doc(childId)
          .collection('changes')
          .doc();

      final changeData = {
        'heure': _careTime,
        'date': DateTime.now(),
        'type': _changeType,
        'pipi': _pipi,
        'selles': _selles,
        'soins': soins,
        'observations': _observationsController.text,
      };

      await changeRef.set(changeData);

      setState(() {
        _careTime = '';
        _pipi = false;
        _selles = false;
        soins = [];
        _observationsController.clear();
      });

      print("Change ajouté avec succès !");
    } catch (e) {
      print("Erreur lors de l'ajout du change : $e");
    }
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    final genre = enfant['genre'] ?? 'Garçon';
    final isBoy = genre == 'Garçon';
    final cardColor = Colors.white;
    final accentColor = isBoy ? primaryBlue : primaryRed;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
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
          // En-tête avec photo et nom
          Row(
            children: [
              // Photo de l'enfant
              Container(
                margin: EdgeInsets.all(12),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: accentColor.withOpacity(0.2),
                  backgroundImage: enfant['photoUrl'] != null
                      ? NetworkImage(enfant['photoUrl'])
                      : null,
                  child: enfant['photoUrl'] == null
                      ? Text(
                          enfant['prenom'][0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        )
                      : null,
                ),
              ),
              // Nom de l'enfant
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enfant['prenom'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton d'ajout
              Container(
                margin: EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: primaryBlue,
                    size: 36,
                  ),
                  onPressed: () => _showAddChangePopup(enfant['id']),
                ),
              ),
            ],
          ),

          // Liste des changes
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('changes')
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
              if (!snapshot.hasData) return Container();

              final changes = snapshot.data!.docs;

              if (changes.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Aucun change enregistré aujourd'hui",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: changes.map((doc) {
                    final changeData = doc.data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => _showChangeDetailsPopup(changeData),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: lightBlue),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getChangeTypeIcon(changeData['type']),
                                color: primaryBlue,
                                size: 22,
                              ),
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  changeData['heure'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  changeData['type'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (changeData['pipi'])
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Pipi",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ),
                                if (changeData['selles'])
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryYellow.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Selles",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: primaryYellow.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
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
    final genre = enfant['genre'] ?? 'Garçon';
    final isBoy = genre == 'Garçon';
    final cardColor = Colors.white;
    final accentColor = isBoy ? primaryBlue : primaryRed;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
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
          // En-tête avec photo et nom
          Row(
            children: [
              // Photo de l'enfant - plus grande pour iPad
              Container(
                margin: EdgeInsets.all(16), // Plus grand pour iPad
                child: CircleAvatar(
                  radius: 45, // Plus grand pour iPad
                  backgroundColor: accentColor.withOpacity(0.2),
                  backgroundImage: enfant['photoUrl'] != null
                      ? NetworkImage(enfant['photoUrl'])
                      : null,
                  child: enfant['photoUrl'] == null
                      ? Text(
                          enfant['prenom'][0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 36, // Plus grand pour iPad
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        )
                      : null,
                ),
              ),
              // Nom de l'enfant
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enfant['prenom'],
                      style: TextStyle(
                        fontSize: 24, // Plus grand pour iPad
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton d'ajout
              Container(
                margin: EdgeInsets.only(right: 16), // Plus grand pour iPad
                child: IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: primaryBlue,
                    size: 42, // Plus grand pour iPad
                  ),
                  onPressed: () => _showAddChangePopup(enfant['id']),
                ),
              ),
            ],
          ),

          // Liste des changes - adaptée pour iPad
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid)
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('changes')
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
                if (!snapshot.hasData) return Container();

                final changes = snapshot.data!.docs;

                if (changes.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(20), // Plus grand pour iPad
                    child: Text(
                      "Aucun change enregistré aujourd'hui",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                        fontSize: 16, // Plus grand pour iPad
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListView.builder(
                    padding:
                        EdgeInsets.only(bottom: 16), // Plus d'espace pour iPad
                    itemCount: changes.length,
                    itemBuilder: (context, idx) {
                      final doc = changes[idx];
                      final changeData = doc.data() as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => _showChangeDetailsPopup(changeData),
                        child: Container(
                          margin: EdgeInsets.only(
                              bottom: 12), // Plus d'espace pour iPad
                          padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14), // Plus grand pour iPad
                          decoration: BoxDecoration(
                            color: lightBlue.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(
                                16), // Plus arrondi pour iPad
                            border: Border.all(color: lightBlue),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding:
                                    EdgeInsets.all(10), // Plus grand pour iPad
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                      10), // Plus arrondi pour iPad
                                ),
                                child: Icon(
                                  _getChangeTypeIcon(changeData['type']),
                                  color: primaryBlue,
                                  size: 24, // Plus grand pour iPad
                                ),
                              ),
                              SizedBox(width: 16), // Plus d'espace pour iPad
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    changeData['heure'],
                                    style: TextStyle(
                                      fontSize: 20, // Plus grand pour iPad
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    changeData['type'],
                                    style: TextStyle(
                                      fontSize: 16, // Plus grand pour iPad
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(),
                              Wrap(
                                spacing: 10, // Plus d'espace pour iPad
                                children: [
                                  if (changeData['pipi'])
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10, // Plus grand pour iPad
                                        vertical: 6, // Plus grand pour iPad
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "Pipi",
                                        style: TextStyle(
                                          fontSize: 14, // Plus grand pour iPad
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ),
                                  if (changeData['selles'])
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10, // Plus grand pour iPad
                                        vertical: 6, // Plus grand pour iPad
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryYellow.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "Selles",
                                        style: TextStyle(
                                          fontSize: 14, // Plus grand pour iPad
                                          color: primaryYellow.withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(width: 10), // Espace avant l'icône
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                                size: 24, // Plus grand pour iPad
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
                      'assets/images/Icone_Changes.png',
                      width: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      height: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.baby_changing_station,
                        size: isTabletDevice ? 32 : 26, // Plus grand pour iPad
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                        width:
                            isTabletDevice ? 12 : 8), // Plus d'espace pour iPad
                    Text(
                      'Change',
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

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Changes.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.baby_changing_station,
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
