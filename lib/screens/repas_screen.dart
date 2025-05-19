import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';

class RepasScreen extends StatefulWidget {
  const RepasScreen({Key? key}) : super(key: key);

  @override
  _RepasScreenState createState() => _RepasScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _RepasScreenState extends State<RepasScreen> {
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

  // Utiliser les couleurs officielles partout
  Color primaryColor = Color(0xFF3D9DF2); // primaryBlue par défaut
  Color secondaryColor = Color(0xFFDFE9F2); // lightBlue par défaut

  bool _isBiberon = false;
  bool _isAllaitement = false;
  String _mealQuality = "Bien mangé";
  TextEditingController _observationsController = TextEditingController();
  TextEditingController _mlController = TextEditingController();
  String _mealTime = "";

  @override
  void dispose() {
    _observationsController.dispose();
    _mlController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadStructureInfo();
    });
  }

  Future<void> _loadStructureInfo() async {
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
              "🔄 Repas: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // Récupération des informations de la structure avec l'ID correct
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser structureId au lieu de user.uid
          .get();

      if (structureDoc.exists) {
        final data = structureDoc.data() as Map<String, dynamic>;
        setState(() {
          structureName = data['structureName'] ?? 'Structure inconnue';
        });
      }

      // Charger les enfants en passant l'ID de structure et l'email
      _loadEnfantsDuJour(structureId, currentUserEmail);
    } catch (e) {
      print("Erreur lors du chargement des infos de structure: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadEnfantsDuJour(
      String structureId, String currentUserEmail) async {
    setState(() => isLoading = true);
    try {
      final today = DateTime.now();
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      // Récupérer la structure pour déterminer le type (MAM ou AssistanteMaternelle)
      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

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
            "👨‍👧‍👦 Repas: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Repas: Assistante Maternelle - affichage de tous les enfants");
      }

      // Diagnostic des enfants filtrés
      print(
          "🔍 DIAGNOSTIC REPAS - Type de structure: $structureType, Utilisateur: $currentUserEmail");
      print(
          "🔍 DIAGNOSTIC REPAS - Nombre total d'enfants: ${allChildren.length}, Nombre filtrés: ${filteredChildren.length}");

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

  Widget _buildBiberonIcon(double ml) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.local_drink_outlined, color: primaryBlue, size: 20),
        ),
        SizedBox(width: 8),
        Text(
          '${ml.toInt()} ML',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAllaitementIcon() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.child_care_outlined,
        color: primaryBlue,
        size: 20,
      ),
    );
  }

  void _showMealDetailsPopup(Map<String, dynamic> mealData) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.02,
            vertical: screenHeight * 0.02,
          ),
          child: Container(
            width: screenWidth * 0.96,
            constraints: BoxConstraints(
              maxWidth: 500,
              minWidth: 250,
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
            child: SingleChildScrollView(
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
                          primaryBlue,
                          primaryBlue.withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Repas de ${mealData['heure']}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMMM yyyy', 'fr_FR')
                                    .format(mealData['date'].toDate())
                                    .toLowerCase(),
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

                  // Contenu
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mealData['biberon']) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: lightBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.local_drink_outlined,
                                    color: primaryBlue, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Biberon',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: primaryBlue,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  "${mealData['ml']?.toInt() ?? 0} ML",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (mealData['allaitement']) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: lightBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.child_care_outlined,
                                    color: primaryBlue, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Allaitement',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Row(
                                  children: List.generate(
                                    mealData['starCount'] ?? 0,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(
                                        right: index <
                                                (mealData['starCount'] ?? 0) - 1
                                            ? 4
                                            : 0,
                                      ),
                                      child: Icon(
                                        Icons.star,
                                        color: primaryYellow,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "${mealData['qualite']}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Observations
                        if (mealData['observations']?.isNotEmpty ?? false) ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
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
                                  "${mealData['observations']}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.3,
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
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "FERMER",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryBlue,
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

  void _showAddMealPopup(String childId) {
    final enfant = enfants.firstWhere((e) => e['id'] == childId);
    String localMealTime = _mealTime;
    bool localIsBiberon = _isBiberon;
    bool localIsAllaitement = _isAllaitement;
    String localMealQuality = _mealQuality;
    _mlController.clear();

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
                        "Ajouter un repas pour ${enfant['prenom']}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: Text(
                          "Heure du repas",
                          style: TextStyle(
                            fontSize: 16,
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
                                localMealTime =
                                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
                          localMealTime.isEmpty
                              ? 'Choisir l\'heure'
                              : localMealTime,
                          style: TextStyle(fontSize: 16, color: primaryBlue),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Biberon ?
                      CheckboxListTile(
                        title: Text("Biberon ?"),
                        value: localIsBiberon,
                        onChanged: (bool? value) {
                          setState(() {
                            localIsBiberon = value!;
                            if (value) {
                              localIsAllaitement = false;
                            }
                          });
                        },
                        activeColor: primaryBlue,
                      ),

                      if (localIsBiberon) ...[
                        SizedBox(height: 10),
                        TextField(
                          controller: _mlController,
                          decoration: InputDecoration(
                            labelText: "Combien de ml ?",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: primaryBlue, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],

                      if (!localIsBiberon) ...[
                        SizedBox(height: 10),
                        // Allaitement ?
                        CheckboxListTile(
                          title: Text("Allaitement ?"),
                          value: localIsAllaitement,
                          onChanged: (bool? value) {
                            setState(() {
                              localIsAllaitement = value!;
                              if (value) {
                                localIsBiberon = false;
                              }
                            });
                          },
                          activeColor: primaryBlue,
                        ),
                      ],

                      if (!localIsBiberon && !localIsAllaitement) ...[
                        SizedBox(height: 20),
                        Text(
                          "Comment était le repas de ${enfant['prenom']} ?",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 10),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildMealQualityButton(
                                    'Pas mangé',
                                    localMealQuality,
                                    (value) {
                                      setState(() {
                                        localMealQuality = value;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _buildMealQualityButton(
                                    'Peu mangé',
                                    localMealQuality,
                                    (value) {
                                      setState(() {
                                        localMealQuality = value;
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
                                  child: _buildMealQualityButton(
                                    'Bien mangé',
                                    localMealQuality,
                                    (value) {
                                      setState(() {
                                        localMealQuality = value;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: _buildMealQualityButton(
                                    'Très bien mangé',
                                    localMealQuality,
                                    (value) {
                                      setState(() {
                                        localMealQuality = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],

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
                            borderSide:
                                BorderSide(color: primaryBlue, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 20),

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
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (localIsBiberon &&
                                  _mlController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Veuillez indiquer la quantité en ml')),
                                );
                                return;
                              }
                              _mealQuality = localMealQuality;
                              _isBiberon = localIsBiberon;
                              _isAllaitement = localIsAllaitement;
                              _mealTime = localMealTime;
                              _addMealToFirebase(childId);
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
                              "AJOUTER",
                              style: TextStyle(
                                fontSize: 16,
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

  Widget _buildMealQualityButton(
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
              isSelected ? primaryBlue.withOpacity(0.1) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          quality,
          style: TextStyle(
            color: isSelected ? primaryBlue : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  int _getStarCountFromQuality(String quality) {
    switch (quality) {
      case 'Pas mangé':
        return 1;
      case 'Peu mangé':
        return 2;
      case 'Bien mangé':
        return 3;
      case 'Très bien mangé':
        return 4;
      default:
        return 0;
    }
  }

  Future<void> _addMealToFirebase(String childId) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      DocumentReference mealRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // Utiliser l'ID de structure correct
          .collection('children')
          .doc(childId)
          .collection('repas')
          .doc();

      final mealData = {
        'heure': _mealTime,
        'date': DateTime.now(),
        'observations': _observationsController.text,
        'biberon': _isBiberon,
        'allaitement': _isAllaitement,
      };

      if (_isBiberon) {
        mealData['ml'] = double.tryParse(_mlController.text) ?? 0;
      } else if (!_isAllaitement) {
        mealData['qualite'] = _mealQuality;
        mealData['starCount'] = _getStarCountFromQuality(_mealQuality);
      }

      await mealRef.set(mealData);

      // Réinitialisation des champs
      setState(() {
        _mealTime = '';
        _isBiberon = false;
        _isAllaitement = false;
        _mealQuality = "Bien mangé";
        _observationsController.clear();
        _mlController.clear();
      });

      print("Repas ajouté avec succès !");
    } catch (e) {
      print("Erreur lors de l'ajout du repas : $e");
    }
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    bool isBoy = enfant['genre'] == 'Garçon';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
          // En-tête de la carte
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar de l'enfant
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
                  child: ClipOval(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? Image.network(
                            enfant['photoUrl'],
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              enfant['prenom'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16),
                // Nom de l'enfant
                Expanded(
                  child: Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isBoy ? primaryBlue : primaryRed,
                    ),
                  ),
                ),
                // Bouton d'ajout
                Container(
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: primaryBlue, size: 24),
                    onPressed: () => _showAddMealPopup(enfant['id']),
                    tooltip: "Ajouter un repas",
                  ),
                ),
              ],
            ),
          ),

          // Liste des repas
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('structures')
                .doc(enfant['structureId'] ??
                    FirebaseAuth.instance.currentUser?.uid)
                .collection('children')
                .doc(enfant['id'])
                .collection('repas')
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
              if (!snapshot.hasData) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      "Chargement des repas...",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      "Aucun repas aujourd'hui",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: snapshot.data!.docs.map((doc) {
                    final mealData = doc.data() as Map<String, dynamic>;
                    return GestureDetector(
                      onTap: () => _showMealDetailsPopup(mealData),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: lightBlue,
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
                                mealData['heure'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            if (mealData['biberon'])
                              _buildBiberonIcon(mealData['ml']?.toDouble() ?? 0)
                            else if (mealData['allaitement'])
                              _buildAllaitementIcon()
                            else
                              Row(
                                children: List.generate(
                                  mealData['starCount'] ?? 0,
                                  (index) => Padding(
                                    padding: EdgeInsets.only(right: 2),
                                    child: Icon(
                                      Icons.star,
                                      color: primaryYellow,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(width: 8),
                            if (mealData['qualite'] != null)
                              Text(
                                mealData['qualite'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            Spacer(),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade600,
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
    bool isBoy = enfant['genre'] == 'Garçon';

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
          // En-tête de la carte
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                // Avatar de l'enfant - plus grand pour iPad
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
                  child: ClipOval(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? Image.network(
                            enfant['photoUrl'],
                            width: 66,
                            height: 66,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Text(
                                enfant['prenom'][0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 28, // Plus grand pour iPad
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              enfant['prenom'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 28, // Plus grand pour iPad
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16),
                // Nom de l'enfant
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
                // Bouton d'ajout
                Container(
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add,
                        color: primaryBlue, size: 28), // Plus grand pour iPad
                    onPressed: () => _showAddMealPopup(enfant['id']),
                    tooltip: "Ajouter un repas",
                  ),
                ),
              ],
            ),
          ),

          // Liste des repas
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('structures')
                  .doc(enfant['structureId'] ??
                      FirebaseAuth.instance.currentUser?.uid)
                  .collection('children')
                  .doc(enfant['id'])
                  .collection('repas')
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
                if (!snapshot.hasData) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        "Chargement des repas...",
                        style: TextStyle(
                          fontSize: 16, // Plus grand pour iPad
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        "Aucun repas aujourd'hui",
                        style: TextStyle(
                          fontSize: 16, // Plus grand pour iPad
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, idx) {
                      final doc = snapshot.data!.docs[idx];
                      final mealData = doc.data() as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => _showMealDetailsPopup(mealData),
                        child: Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: lightBlue,
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
                                  mealData['heure'],
                                  style: TextStyle(
                                    fontSize: 15, // Plus grand pour iPad
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              if (mealData['biberon'])
                                _buildBiberonIcon(
                                    mealData['ml']?.toDouble() ?? 0)
                              else if (mealData['allaitement'])
                                _buildAllaitementIcon()
                              else
                                Row(
                                  children: List.generate(
                                    mealData['starCount'] ?? 0,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(right: 2),
                                      child: Icon(
                                        Icons.star,
                                        color: primaryYellow,
                                        size: 18, // Plus grand pour iPad
                                      ),
                                    ),
                                  ),
                                ),
                              SizedBox(width: 8),
                              if (mealData['qualite'] != null)
                                Text(
                                  mealData['qualite'],
                                  style: TextStyle(
                                    fontSize: 15, // Plus grand pour iPad
                                    color: Colors.black87,
                                  ),
                                ),
                              Spacer(),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey.shade600,
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
                      'assets/images/Icone_Repas.png',
                      width: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      height: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.restaurant,
                        size: isTabletDevice ? 32 : 26, // Plus grand pour iPad
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                        width:
                            isTabletDevice ? 12 : 8), // Plus d'espace pour iPad
                    Text(
                      'Repas',
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

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Repas.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.restaurant,
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
}
