import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';

class ChildHistoryDetailScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final DateTime selectedDate;
  final String structureId;

  const ChildHistoryDetailScreen({
    Key? key,
    required this.childId,
    required this.childName,
    required this.selectedDate,
    required this.structureId,
  }) : super(key: key);

  @override
  _ChildHistoryDetailScreenState createState() =>
      _ChildHistoryDetailScreenState();
}

class _ChildHistoryDetailScreenState extends State<ChildHistoryDetailScreen> {
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _recapData = {
    'repas': [],
    'activites': [],
    'siestes': [],
    'changes': [],
    'sante': [],
    'horaires': [],
    'photos': [],
    'transmissions': [],
  };
  int _totalActivites = 0;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  late Color primaryColor = primaryBlue;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadChildHistoryData();
    });
  }

  Future<void> _loadChildHistoryData() async {
    setState(() => _isLoading = true);

    try {
      final selectedDateStart = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
      );
      final selectedDateEnd = selectedDateStart.add(Duration(days: 1));
      final selectedDateFormatted =
          DateFormat('yyyy-MM-dd').format(selectedDateStart);

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
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .collection('repas')
          .where('date', isGreaterThanOrEqualTo: selectedDateStart)
          .where('date', isLessThanOrEqualTo: selectedDateEnd)
          .orderBy('date', descending: false)
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
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .collection('activites')
          .where('date', isGreaterThanOrEqualTo: selectedDateStart)
          .where('date', isLessThanOrEqualTo: selectedDateEnd)
          .orderBy('date', descending: false)
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
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .collection('siestes')
          .where('date', isGreaterThanOrEqualTo: selectedDateStart)
          .where('date', isLessThanOrEqualTo: selectedDateEnd)
          .orderBy('date', descending: false)
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
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .collection('changes')
          .where('date', isGreaterThanOrEqualTo: selectedDateStart)
          .where('date', isLessThanOrEqualTo: selectedDateEnd)
          .orderBy('date', descending: false)
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
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .collection('sante')
          .where('date', isGreaterThanOrEqualTo: selectedDateStart)
          .where('date', isLessThanOrEqualTo: selectedDateEnd)
          .orderBy('date', descending: false)
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
      try {
        List<Map<String, dynamic>> allHoraires = [];

        // Récupérer les horaires dans la collection horaires_history
        final horairesSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(widget.structureId)
            .collection('horaires_history')
            .where('childId', isEqualTo: widget.childId)
            .where('date', isEqualTo: selectedDateFormatted)
            .get();

        for (var doc in horairesSnapshot.docs) {
          final data = doc.data();
          if (data['actionType'] == 'arrivee' ||
              data['actionType'] == 'depart') {
            allHoraires.add(data);
          }
        }

        // Récupérer également les horaires dans la collection horaires (document du jour)
        final horairesDaySnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(widget.structureId)
            .collection('horaires')
            .doc(selectedDateFormatted)
            .get();

        if (horairesDaySnapshot.exists) {
          final data = horairesDaySnapshot.data();
          if (data != null && data.containsKey(widget.childId)) {
            final childHoraires = data[widget.childId];

            // Vérifier si l'enfant était absent
            if (childHoraires['absent'] == true ||
                childHoraires['actionType'] == 'absent') {
              // Ne pas ajouter d'horaires pour les enfants absents
            } else {
              // Vérifier si des segments existent
              if (childHoraires['segments'] != null) {
                List<dynamic> segments = childHoraires['segments'];
                for (var segment in segments) {
                  if (segment['arrivee'] != null) {
                    allHoraires.add({
                      'childId': widget.childId,
                      'date': selectedDateFormatted,
                      'actionType': 'arrivee',
                      'heure': segment['arrivee'],
                    });
                  }
                  if (segment['depart'] != null) {
                    allHoraires.add({
                      'childId': widget.childId,
                      'date': selectedDateFormatted,
                      'actionType': 'depart',
                      'heure': segment['depart'],
                    });
                  }
                }
              }
              // Format ancien (sans segments)
              else if (childHoraires['arrivee'] != null ||
                  childHoraires['depart'] != null) {
                if (childHoraires['arrivee'] != null) {
                  allHoraires.add({
                    'childId': widget.childId,
                    'date': selectedDateFormatted,
                    'actionType': 'arrivee',
                    'heure': childHoraires['arrivee'],
                  });
                }
                if (childHoraires['depart'] != null) {
                  allHoraires.add({
                    'childId': widget.childId,
                    'date': selectedDateFormatted,
                    'actionType': 'depart',
                    'heure': childHoraires['depart'],
                  });
                }
              }
            }
          }
        }

        // Supprimer les doublons et traiter les horaires
        Map<String, Map<String, dynamic>> uniqueHoraires = {};
        for (var horaire in allHoraires) {
          String key = "${horaire['actionType']}_${horaire['heure']}";
          uniqueHoraires[key] = horaire;
        }

        for (var horaire in uniqueHoraires.values) {
          if (horaire['actionType'] == 'arrivee') {
            tempRecapData['horaires']!.add({
              'heure':
                  horaire['heure'] ?? _formatTimestamp(horaire['timestamp']),
              'type': 'arrivee',
              'details': 'Arrivée',
            });
          } else if (horaire['actionType'] == 'depart') {
            tempRecapData['horaires']!.add({
              'heure':
                  horaire['heure'] ?? _formatTimestamp(horaire['timestamp']),
              'type': 'depart',
              'details': 'Départ',
            });
          }
        }

        // Tri des horaires par heure
        tempRecapData['horaires']!.sort((a, b) {
          int minutesA = _convertHoursToMinutes(a['heure'] ?? '00:00');
          int minutesB = _convertHoursToMinutes(b['heure'] ?? '00:00');
          return minutesA.compareTo(minutesB);
        });
      } catch (e) {
        print("Erreur lors de la récupération des horaires: $e");
      }

      // Récupérer les photos
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .collection('photos')
          .where('date', isGreaterThanOrEqualTo: selectedDateStart)
          .where('date', isLessThanOrEqualTo: selectedDateEnd)
          .orderBy('date', descending: false)
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
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .collection('transmissions')
          .where('date', isGreaterThanOrEqualTo: selectedDateStart)
          .where('date', isLessThanOrEqualTo: selectedDateEnd)
          .orderBy('date', descending: false)
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

      // Calculer le nombre total d'activités
      int totalActivites = 0;
      tempRecapData.forEach((category, items) {
        totalActivites += items.length;
      });

      setState(() {
        _recapData = tempRecapData;
        _totalActivites = totalActivites;
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des données historiques: $e");
      setState(() => _isLoading = false);
    }
  }

  int _convertHoursToMinutes(String timeStr) {
    if (timeStr == '--:--') return 0;
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        return hours * 60 + minutes;
      }
    } catch (e) {
      print("Erreur lors de la conversion de l'heure: $e");
    }
    return 0;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('HH:mm').format(timestamp.toDate());
    }
    return '';
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

  Widget _buildRecapSection(
      String category, List<Map<String, dynamic>> items, bool isTablet) {
    if (items.isEmpty) return Container();

    return Container(
      margin: EdgeInsets.symmetric(vertical: isTablet ? 12 : 8),
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
            padding: EdgeInsets.all(isTablet ? 16 : 12),
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
                  size: isTablet ? 28 : 24,
                ),
                SizedBox(width: 12),
                Text(
                  category.substring(0, 1).toUpperCase() +
                      category.substring(1),
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 8,
                      vertical: isTablet ? 6 : 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor[category]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${items.length}",
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                )
              ],
            ),
          ),

          // Liste des éléments
          ListView.separated(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 6 : 4,
                ),
                leading: Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor[category]!.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    item['heure'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: isTablet ? 14 : 12,
                    ),
                  ),
                ),
                title: Text(
                  category == 'photos'
                      ? '1 photo'
                      : (item['type'] ?? item['details'] ?? ''),
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
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
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.black,
                        ),
                      )
                    : null,
                trailing: category == 'photos' && item['photoUrl'] != null
                    ? Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['photoUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.image,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    : Icon(Icons.arrow_forward_ios,
                        size: isTablet ? 16 : 14, color: Colors.black),
                dense: !isTablet,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = MediaQuery.of(context).size.shortestSide >= 600;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "Historique de ${widget.childName}",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: primaryColor,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: 20),
              Text(
                "Chargement de l'historique...",
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
            (cat) => _recapData.containsKey(cat) && _recapData[cat]!.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Historique de ${widget.childName}",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // En-tête avec informations
          Container(
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.summarize_outlined,
                        color: Colors.white,
                        size: isTabletDevice ? 32 : 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Historique pour ${widget.childName}",
                            style: TextStyle(
                              fontSize: isTabletDevice ? 24 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                                .format(widget.selectedDate),
                            style: TextStyle(
                              fontSize: isTabletDevice ? 18 : 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.summarize, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            '$_totalActivites',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenu avec données ou message vide
          Expanded(
            child: _totalActivites == 0
                ? Center(
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
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          "Aucune donnée pour cette date",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Aucune activité enregistrée pour ${widget.childName} le ${DateFormat('d MMMM yyyy', 'fr_FR').format(widget.selectedDate)}",
                            style: TextStyle(
                              fontSize: 16,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(isTabletDevice ? 24 : 16),
                      child: Column(
                        children: categoriesToShow.map((category) {
                          return _buildRecapSection(category,
                              _recapData[category] ?? [], isTabletDevice);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
