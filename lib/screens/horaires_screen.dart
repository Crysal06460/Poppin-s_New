import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

class HorairesScreen extends StatefulWidget {
  @override
  _HorairesScreenState createState() => _HorairesScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _HorairesScreenState extends State<HorairesScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Utiliser les couleurs officielles partout
  Color primaryColor = Color(0xFF3D9DF2); // primaryBlue par défaut
  Color secondaryColor = Color(0xFFDFE9F2); // lightBlue par défaut

  String structureName = "Chargement...";
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR').then((_) => _loadStructureData());
  }
// Ajoute cette méthode à ta classe _HorairesScreenState

  @override
  Widget build(BuildContext context) {
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
                        ? _buildChildrenGridForTablet() // Grille adaptée pour iPad
                        : _buildChildrenGrid(), // Garder la version iPhone
          )
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

// Nouvelle méthode pour la grille adaptée à l'iPad
  Widget _buildChildrenGridForTablet() {
    return GridView.builder(
      padding: EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85, // Ratio plus carré pour iPad
        crossAxisSpacing: 24, // Plus d'espace horizontal
        mainAxisSpacing: 24, // Plus d'espace vertical
      ),
      itemCount: enfants.length,
      itemBuilder: (context, index) =>
          _buildEnfantCardForTablet(context, index),
    );
  }

// Nouvelle méthode pour la carte enfant adaptée à l'iPad
  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    bool isAbsent = enfant['absent'] == true;
    String genre = enfant['genre']?.toString() ?? 'Garçon';
    bool hasMultipleSegments = enfant['segments'].length > 1;

    Color getCardColor() {
      if (isAbsent) return Colors.grey.shade200;
      return Colors.white;
    }

    Color getTextColor() {
      if (isAbsent) return Colors.grey;
      return (genre == 'Fille') ? primaryRed : primaryBlue;
    }

    return Container(
      decoration: BoxDecoration(
        color: getCardColor(),
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
          // Photo de l'enfant (40% de la hauteur)
          Expanded(
            flex: 40,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  child: enfant['photoUrl'] != null
                      ? Image.network(
                          enfant['photoUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                if (isAbsent)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Center(
                      child: Text(
                        'ABSENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22, // Plus grand pour iPad
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Contenu de la carte (60% de la hauteur)
          Expanded(
            flex: 60,
            child: Padding(
              padding: EdgeInsets.all(16), // Padding plus important pour iPad
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly, // Répartition uniforme
                children: [
                  Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 24, // Plus grand pour iPad
                      fontWeight: FontWeight.bold,
                      color: getTextColor(),
                    ),
                  ),
                  SizedBox(height: 10),
                  if (isAbsent)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Absent aujourd\'hui',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                          fontSize: 18, // Plus grand pour iPad
                        ),
                      ),
                    )
                  else if (hasMultipleSegments)
                    Expanded(
                      child: _buildSegmentsListForTablet(enfant),
                    )
                  else
                    _buildSimpleSegmentForTablet(
                        enfant, enfant['segments'][0], 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// Widget pour un seul segment adapté à l'iPad
  Widget _buildSimpleSegmentForTablet(Map<String, dynamic> enfant,
      Map<String, dynamic> segment, int segmentIndex) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (segment['heureDebut'] != null && segment['heureFin'] != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                vertical: 10, horizontal: 16), // Plus grand pour iPad
            margin: EdgeInsets.only(bottom: 16), // Plus d'espace
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16), // Plus arrondi
            ),
            child: Text(
              '${segment['heureDebut']} - ${segment['heureFin']}',
              style: TextStyle(
                fontSize: 20, // Plus grand pour iPad
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTimeButtonForTablet(
              'Arrivée',
              segment['arrivee'],
              () => _enregistrerHeure('arrivee', enfant, segmentIndex),
              segment['arrivee'] != null || enfant['absent'],
            ),
            _buildTimeButtonForTablet(
              'Départ',
              segment['depart'],
              () => _enregistrerHeure('depart', enfant, segmentIndex),
              segment['depart'] != null ||
                  enfant['absent'] ||
                  segment['arrivee'] == null,
            ),
          ],
        ),
        SizedBox(height: 16), // Plus d'espace
        _buildAbsentButtonForTablet(enfant),
      ],
    );
  }

// Liste des segments pour iPad
  Widget _buildSegmentsListForTablet(Map<String, dynamic> enfant) {
    List<dynamic> segments = enfant['segments'];

    if (segments.isEmpty) {
      return Center(
        child: Text('Aucun horaire défini',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18, // Plus grand pour iPad
            )),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 0),
      shrinkWrap: true,
      itemCount: segments.length + 1, // +1 pour le bouton absent en bas
      itemBuilder: (context, index) {
        if (index == segments.length) {
          return Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(child: _buildAbsentButtonForTablet(enfant)),
          );
        }

        Map<String, dynamic> segment = segments[index];
        bool isLastSegment = index == segments.length - 1;
        return _buildSegmentItemForTablet(
            enfant, segment, index, isLastSegment);
      },
    );
  }

// Élément de segment adapté pour iPad
  Widget _buildSegmentItemForTablet(Map<String, dynamic> enfant,
      Map<String, dynamic> segment, int segmentIndex, bool isLastSegment) {
    String heureDebut = segment['heureDebut'] ?? '--:--';
    String heureFin = segment['heureFin'] ?? '--:--';

    return Padding(
      padding: EdgeInsets.only(bottom: isLastSegment ? 8 : 12), // Plus d'espace
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding:
                EdgeInsets.symmetric(vertical: 8, horizontal: 12), // Plus grand
            margin: EdgeInsets.only(bottom: 8), // Plus d'espace
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Créneau ${segmentIndex + 1}: $heureDebut - $heureFin',
              style: TextStyle(
                fontSize: 16, // Plus grand pour iPad
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 8), // Plus d'espace
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeButtonForTablet(
                'Arrivée',
                segment['arrivee'],
                () => _enregistrerHeure('arrivee', enfant, segmentIndex),
                segment['arrivee'] != null || enfant['absent'],
              ),
              _buildTimeButtonForTablet(
                'Départ',
                segment['depart'],
                () => _enregistrerHeure('depart', enfant, segmentIndex),
                segment['depart'] != null ||
                    enfant['absent'] ||
                    segment['arrivee'] == null,
              ),
            ],
          ),
        ],
      ),
    );
  }

// Bouton de temps (arrivée/départ) adapté pour iPad
  Widget _buildTimeButtonForTablet(
      String label, String? time, VoidCallback onPressed, bool isDisabled) {
    return SizedBox(
      width: 100, // Plus large pour iPad
      height: 44, // Plus haut pour iPad
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey[300] : primaryColor,
          disabledBackgroundColor: Colors.grey[300],
          elevation: isDisabled ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22), // Plus arrondi
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          time ?? label,
          style: TextStyle(
            fontSize: 16, // Plus grand pour iPad
            fontWeight: FontWeight.w600,
            color: isDisabled ? Colors.grey[500] : Colors.white,
          ),
        ),
      ),
    );
  }

// Bouton absent adapté pour iPad
  Widget _buildAbsentButtonForTablet(Map<String, dynamic> enfant) {
    bool aucunHoraireEnregistre = true;
    for (var segment in enfant['segments']) {
      if (segment['arrivee'] != null || segment['depart'] != null) {
        aucunHoraireEnregistre = false;
        break;
      }
    }

    return (aucunHoraireEnregistre && !enfant['absent'])
        ? SizedBox(
            width: 120, // Plus large pour iPad
            height: 44, // Plus haut pour iPad
            child: ElevatedButton(
              onPressed: () => _marquerAbsent(enfant),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22), // Plus arrondi
                ),
                padding: EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                'Absent',
                style: TextStyle(
                  fontSize: 16, // Plus grand pour iPad
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          )
        : Container();
  }

  Future<void> _loadStructureData() async {
    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        context.go('/login');
        return;
      }

      // CORRECTION: Récupérer l'ID de structure en tenant compte des membres MAM
      // Vérifier d'abord si l'utilisateur est un membre MAM
      final userEmail = user.email?.toLowerCase() ?? '';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
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
              "🔄 Horaires: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // Récupérer les informations de la structure avec l'ID correct
      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(
              structureId) // IMPORTANT: Utiliser structureId au lieu de user.uid
          .get();

      setState(() {
        structureName =
            structureSnapshot['structureName'] ?? 'Structure inconnue';
      });

      // Continuer avec le chargement des enfants
      await _loadEnfantsDuJour();
    } catch (e) {
      print("Erreur de chargement des données de structure: $e");
      setState(() => isLoading = false);
    }
  }

// Également dans la méthode _loadEnfantsDuJour(), assurez-vous d'utiliser le même ID de structure

  Future<void> _loadEnfantsDuJour() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final currentUserEmail = user?.email?.toLowerCase() ?? '';
      final today = DateTime.now();
      final todayWeekday = DateFormat('EEEE', 'fr_FR').format(today);
      final capitalizedWeekday = todayWeekday[0].toUpperCase() +
          todayWeekday.substring(1).toLowerCase();

      // CORRECTION: Récupérer l'ID de structure en tenant compte des membres MAM
      // Vérifier d'abord si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      // ID de structure à utiliser (par défaut, utiliser l'ID de l'utilisateur)
      String structureId = user?.uid ?? '';

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "🔄 Horaires: Utilisateur MAM détecté - Utilisation de l'ID de structure: $structureId");
        }
      }

      // Récupérer la structure pour déterminer le type (MAM ou AssistanteMaternelle)
      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(
              structureId) // IMPORTANT: Utiliser structureId au lieu de user.uid
          .get();

      final String structureType = structureSnapshot.exists
          ? (structureSnapshot.data()?['structureType'] ??
              "AssistanteMaternelle")
          : "AssistanteMaternelle";

      // Récupérer tous les enfants de la structure avec le bon ID de structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(
              structureId) // IMPORTANT: Utiliser structureId au lieu de user.uid
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
            "👨‍👧‍👦 Membre MAM: affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Assistante Maternelle individuelle: affichage de tous les enfants");
      }

      // Diagnostic des enfants filtrés
      print(
          "🔍 DIAGNOSTIC HORAIRES - Type de structure: $structureType, Utilisateur: $currentUserEmail");
      print(
          "🔍 DIAGNOSTIC HORAIRES - Nombre total d'enfants: ${allChildren.length}, Nombre filtrés: ${filteredChildren.length}");

      // Diagnostic détaillé de chaque enfant
      for (var child in allChildren) {
        String assignedEmail =
            child['assignedMemberEmail']?.toString().toLowerCase() ??
                'NON ASSIGNÉ';
        bool isVisible =
            structureType != "MAM" || assignedEmail == currentUserEmail;
        print(
            "  👶 ID: ${child['id']}, Nom: ${child['firstName']}, Assigné à: '$assignedEmail', Visible: ${isVisible ? 'OUI' : 'NON'}");
      }

      // Récupérer les horaires enregistrés pour aujourd'hui
      final dateActuelle = DateFormat('yyyy-MM-dd').format(today);
      final horairesSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(
              structureId) // CORRECTION: Utiliser structureId au lieu de user?.uid
          .collection('horaires')
          .doc(dateActuelle)
          .get();

      Map<String, dynamic> horairesDuJour = {};
      if (horairesSnapshot.exists) {
        horairesDuJour = horairesSnapshot.data() ?? {};
      }

      // Maintenant, traiter uniquement les enfants filtrés pour aujourd'hui
      List<Map<String, dynamic>> tempEnfants = [];
      for (var child in filteredChildren) {
        // Vérifier si l'enfant a un programme pour aujourd'hui
        if (child['schedule'] != null &&
            child['schedule'][capitalizedWeekday] != null) {
          String? photoUrl = child['photoUrl'];

          // Pour chaque enfant prévu aujourd'hui, créer une entrée dans la liste
          Map<String, dynamic> horaireEnfant = {
            'id': child['id'],
            'prenom': child['firstName'],
            'genre': child['gender'],
            'photoUrl': photoUrl,
            'segments':
                [], // Stockera les statuts des différents segments horaires
            'absent': false,
          };

          // Récupérer les horaires planifiés pour aujourd'hui
          List<dynamic> segmentsDuJour = [];
          if (child['schedule'][capitalizedWeekday] is List) {
            segmentsDuJour = child['schedule'][capitalizedWeekday];
          } else if (child['schedule'][capitalizedWeekday] is Map) {
            // Prise en charge de l'ancien format avec un seul segment
            segmentsDuJour = [
              {
                'start': child['schedule'][capitalizedWeekday]['start'] ??
                    child['schedule'][capitalizedWeekday]['arrival'],
                'end': child['schedule'][capitalizedWeekday]['end'] ??
                    child['schedule'][capitalizedWeekday]['departure']
              }
            ];
          }

          // Créer une entrée pour chaque segment horaire
          List<Map<String, dynamic>> segmentsInfo = [];
          for (int i = 0; i < segmentsDuJour.length; i++) {
            var segment = segmentsDuJour[i];
            Map<String, dynamic> segmentInfo = {
              'index': i,
              'start': segment['start'],
              'end': segment['end'],
              'arrivee': null,
              'depart': null,
              // On ajoute les heures planifiées pour l'affichage
              'heureDebut': segment['start'],
              'heureFin': segment['end'],
            };
            segmentsInfo.add(segmentInfo);
          }

          // Récupérer les horaires déjà enregistrés aujourd'hui
          if (horairesDuJour.containsKey(child['id'])) {
            final horaire = horairesDuJour[child['id']];

            // Si l'enfant est marqué absent, on met à jour le statut
            if (horaire['actionType'] == 'absent') {
              horaireEnfant['absent'] = true;
            }
            // Sinon, on récupère les heures d'arrivée/départ pour chaque segment
            else if (horaire['segments'] != null) {
              List<dynamic> segmentsEnregistres = horaire['segments'];
              for (var segmentEnregistre in segmentsEnregistres) {
                int index = segmentEnregistre['index'];
                if (index < segmentsInfo.length) {
                  if (segmentEnregistre['arrivee'] != null) {
                    segmentsInfo[index]['arrivee'] =
                        segmentEnregistre['arrivee'];
                  }
                  if (segmentEnregistre['depart'] != null) {
                    segmentsInfo[index]['depart'] = segmentEnregistre['depart'];
                  }
                }
              }
            }
            // Compatibilité avec l'ancien format (un seul segment)
            else if (horaire['arrivee'] != null || horaire['depart'] != null) {
              if (segmentsInfo.isNotEmpty) {
                segmentsInfo[0]['arrivee'] = horaire['arrivee'];
                segmentsInfo[0]['depart'] = horaire['depart'];
              }
            }
          }

          horaireEnfant['segments'] = segmentsInfo;
          tempEnfants.add(horaireEnfant);
        }
      }

      setState(() {
        enfants = tempEnfants;
        isLoading = false;
      });
    } catch (e) {
      print("Erreur de chargement des enfants: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateHoraires(
      String childId, Map<String, dynamic> horaires) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final currentUserEmail = user?.email?.toLowerCase() ?? '';
      final now = DateTime.now();
      final dateActuelle = DateFormat('yyyy-MM-dd').format(now);

      // CORRECTION: Récupérer le bon ID de structure comme dans _loadStructureData
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      // ID de structure à utiliser (par défaut, utiliser l'ID de l'utilisateur)
      String structureId = user?.uid ?? '';

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        if (userData['role'] == 'mamMember' &&
            userData['structureId'] != null) {
          // Utiliser l'ID de la structure MAM au lieu de l'ID utilisateur
          structureId = userData['structureId'];
          print(
              "🔄 Horaires: Enregistrement pour la structure MAM: $structureId");
        }
      }

      horaires['timestamp'] = now;
      horaires['childId'] = childId;
      horaires['date'] = dateActuelle;
      horaires['userEmail'] = currentUserEmail; // Ajouté pour traçabilité

      // CORRECTION: Utiliser structureId au lieu de user?.uid
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // IMPORTANT: Utiliser structureId!
          .collection('horaires')
          .doc(dateActuelle)
          .set({childId: horaires}, SetOptions(merge: true));

      // Ajout de l'historique des km (uniquement si km est présent)
      if (horaires.containsKey('km') && horaires['km'] != null) {
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId) // IMPORTANT: Utiliser structureId!
            .collection('km_history')
            .add({
          'childId': childId,
          'date': dateActuelle,
          'km': horaires['km'],
          'timestamp': now,
          'userEmail': currentUserEmail, // Ajouté pour traçabilité
        });
      }

      // CORRECTION: Utiliser structureId au lieu de user?.uid
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // IMPORTANT: Utiliser structureId!
          .collection('horaires_history')
          .add({
        'childId': childId,
        'date': dateActuelle,
        'timestamp': now,
        'userEmail': currentUserEmail, // Ajouté pour traçabilité
        ...horaires,
      });

      print(
          "Horaires enregistrés avec succès dans la structure ID: $structureId !");
    } catch (e) {
      print("Erreur mise à jour horaires: $e");
      throw e;
    }
  }

  void _enregistrerHeure(
      String type, Map<String, dynamic> enfant, int segmentIndex) {
    // Récupérer le segment spécifique
    List<dynamic> segments = enfant['segments'];
    if (segmentIndex >= segments.length) return;

    Map<String, dynamic> segment = segments[segmentIndex];

    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);

    setState(() {
      // Mettre à jour le segment spécifique
      segment[type] = currentTime;

      // Si on enregistre une arrivée, l'enfant n'est pas absent
      if (type == 'arrivee') {
        enfant['absent'] = false;
      }
    });

    Map<String, dynamic> horairesData = {
      'prenom': enfant['prenom'],
      'actionType': type,
      'exactTime': now,
      'heure': currentTime,
      'segments': List<Map<String, dynamic>>.from(segments),
    };

    // Pour l'arrivée, on enregistre directement sans demander les km
    if (type == 'arrivee') {
      _updateHoraires(enfant['id'], horairesData);
    }
    // Pour le départ, on demande les km
    else if (type == 'depart') {
      _showKilometersDialog(enfant, horairesData, segmentIndex);
    }
  }

  void _showKilometersDialog(Map<String, dynamic> enfant,
      Map<String, dynamic> horairesData, int segmentIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        TextEditingController kmController = TextEditingController();
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kilomètres parcourus aujourd\'hui',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: primaryColor),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Uniquement si vous avez effectué un trajet avec ${enfant['prenom']} aujourd\'hui',
                          style: TextStyle(
                              fontSize: 14,
                              color: primaryColor.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                TextField(
                  controller: kmController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Laisser vide si aucun trajet',
                    filled: true,
                    fillColor: secondaryColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: Icon(Icons.directions_car, color: primaryColor),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      child: Text(
                        'Aucun trajet',
                        style: TextStyle(
                          fontSize: 16,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _updateHoraires(enfant['id'], horairesData);
                      },
                    ),
                    ElevatedButton(
                      child: Text(
                        'Enregistrer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 2,
                      ),
                      onPressed: () {
                        if (kmController.text.isNotEmpty) {
                          horairesData['km'] = int.parse(kmController.text);
                          // Enregistrer les km pour le segment spécifique
                          List<dynamic> segments = horairesData['segments'];
                          if (segmentIndex < segments.length) {
                            segments[segmentIndex]['km'] =
                                int.parse(kmController.text);
                          }
                        }
                        Navigator.of(context).pop();
                        _updateHoraires(enfant['id'], horairesData);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _marquerAbsent(Map<String, dynamic> enfant) {
    final now = DateTime.now();

    setState(() {
      enfant['absent'] = true;
      // Réinitialiser tous les segments
      for (var segment in enfant['segments']) {
        segment['arrivee'] = null;
        segment['depart'] = null;
      }
    });

    Map<String, dynamic> horairesData = {
      'prenom': enfant['prenom'],
      'actionType': 'absent',
      'exactTime': now,
      'absent': true,
      'segments': enfant['segments'],
    };

    _updateHoraires(enfant['id'], horairesData);
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

  // AppBar personnalisé avec gradient
  // Modification du header pour iPad dans la méthode _buildAppBar

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
                      'assets/images/Icone_Horaires.png',
                      width: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      height: isTabletDevice ? 36 : 30, // Plus grand pour iPad
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.schedule,
                        size: isTabletDevice ? 32 : 26, // Plus grand pour iPad
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                        width:
                            isTabletDevice ? 12 : 8), // Plus d'espace pour iPad
                    Text(
                      'Horaires',
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
            'assets/images/Icone_Horaires.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.child_care,
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

  // Grille des enfants
  Widget _buildChildrenGrid() {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
      ),
      itemCount: enfants.length,
      itemBuilder: (context, index) => _buildEnfantCard(context, index),
    );
  }

  // Widget pour afficher une carte enfant
  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    bool isAbsent = enfant['absent'] == true;
    String genre = enfant['genre']?.toString() ?? 'Garçon';
    bool hasMultipleSegments = enfant['segments'].length > 1;

    // Couleurs dynamiques selon le genre (en utilisant les couleurs officielles)
    Color getCardColor() {
      if (isAbsent) return Colors.grey.shade200;
      return Colors.white;
    }

    Color getTextColor() {
      if (isAbsent) return Colors.grey;
      return (genre == 'Fille') ? primaryRed : primaryBlue;
    }

    return Container(
      decoration: BoxDecoration(
        color: getCardColor(),
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
          // Photo de l'enfant
          Expanded(
            flex: hasMultipleSegments ? 35 : 45,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  child: enfant['photoUrl'] != null
                      ? Image.network(
                          enfant['photoUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                if (isAbsent)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Center(
                      child: Text(
                        'ABSENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Contenu de la carte
          Expanded(
            flex: hasMultipleSegments ? 65 : 55,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: hasMultipleSegments
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: getTextColor(),
                    ),
                  ),
                  SizedBox(height: 10),
                  if (isAbsent)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Absent aujourd\'hui',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else if (hasMultipleSegments)
                    Expanded(
                      child: _buildSegmentsList(enfant),
                    )
                  else
                    _buildSimpleSegment(enfant, enfant['segments'][0], 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  // Widget pour un seul segment
  Widget _buildSimpleSegment(Map<String, dynamic> enfant,
      Map<String, dynamic> segment, int segmentIndex) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (segment['heureDebut'] != null && segment['heureFin'] != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${segment['heureDebut']} - ${segment['heureFin']}',
              style: TextStyle(
                fontSize: 14,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTimeButton(
              'Arrivée',
              segment['arrivee'],
              () => _enregistrerHeure('arrivee', enfant, segmentIndex),
              segment['arrivee'] != null || enfant['absent'],
            ),
            _buildTimeButton(
              'Départ',
              segment['depart'],
              () => _enregistrerHeure('depart', enfant, segmentIndex),
              segment['depart'] != null ||
                  enfant['absent'] ||
                  segment['arrivee'] == null,
            ),
          ],
        ),
        SizedBox(height: 10),
        _buildAbsentButton(enfant),
      ],
    );
  }

  // Liste des segments pour les enfants avec plusieurs créneaux
  Widget _buildSegmentsList(Map<String, dynamic> enfant) {
    List<dynamic> segments = enfant['segments'];

    if (segments.isEmpty) {
      return Center(
        child:
            Text('Aucun horaire défini', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 0),
      shrinkWrap: true,
      itemCount: segments.length + 1, // +1 pour le bouton absent en bas
      itemBuilder: (context, index) {
        // Le dernier élément est pour le bouton "Absent"
        if (index == segments.length) {
          return Padding(
            padding: EdgeInsets.only(top: 4),
            child: Center(child: _buildAbsentButton(enfant)),
          );
        }

        Map<String, dynamic> segment = segments[index];
        bool isLastSegment = index == segments.length - 1;
        return _buildSegmentItem(enfant, segment, index, isLastSegment);
      },
    );
  }

  Widget _buildSegmentItem(Map<String, dynamic> enfant,
      Map<String, dynamic> segment, int segmentIndex, bool isLastSegment) {
    String heureDebut = segment['heureDebut'] ?? '--:--';
    String heureFin = segment['heureFin'] ?? '--:--';

    return Padding(
      padding: EdgeInsets.only(bottom: isLastSegment ? 4 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            margin: EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Créneau ${segmentIndex + 1}: $heureDebut - $heureFin',
              style: TextStyle(
                fontSize: 12,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeButton(
                'Arrivée',
                segment['arrivee'],
                () => _enregistrerHeure('arrivee', enfant, segmentIndex),
                segment['arrivee'] != null || enfant['absent'],
              ),
              _buildTimeButton(
                'Départ',
                segment['depart'],
                () => _enregistrerHeure('depart', enfant, segmentIndex),
                segment['depart'] != null ||
                    enfant['absent'] ||
                    segment['arrivee'] == null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bouton de temps (arrivée/départ)
  Widget _buildTimeButton(
      String label, String? time, VoidCallback onPressed, bool isDisabled) {
    return SizedBox(
      width: 70,
      height: 32,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey[300] : primaryColor,
          disabledBackgroundColor: Colors.grey[300],
          elevation: isDisabled ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(horizontal: 8),
        ),
        child: FittedBox(
          child: Text(
            time ?? label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDisabled ? Colors.grey[500] : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // Bouton pour marquer l'enfant absent
  Widget _buildAbsentButton(Map<String, dynamic> enfant) {
    // Ne montrer le bouton Absent que si aucun horaire n'a été enregistré
    bool aucunHoraireEnregistre = true;
    for (var segment in enfant['segments']) {
      if (segment['arrivee'] != null || segment['depart'] != null) {
        aucunHoraireEnregistre = false;
        break;
      }
    }

    return (aucunHoraireEnregistre && !enfant['absent'])
        ? SizedBox(
            width: 80,
            height: 32,
            child: ElevatedButton(
              onPressed: () => _marquerAbsent(enfant),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    primaryRed, // Utiliser la couleur rouge primaire
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              child: FittedBox(
                child: Text(
                  'Absent',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          )
        : Container(); // Retourne un conteneur vide si un horaire est déjà enregistré
  }
}
