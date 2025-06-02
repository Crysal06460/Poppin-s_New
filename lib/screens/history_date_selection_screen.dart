import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:poppins_app/screens/child_history_detail_screen.dart';

class HistoryDateSelectionScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String structureId;

  const HistoryDateSelectionScreen({
    Key? key,
    required this.childId,
    required this.childName,
    required this.structureId,
  }) : super(key: key);

  @override
  _HistoryDateSelectionScreenState createState() =>
      _HistoryDateSelectionScreenState();
}

class _HistoryDateSelectionScreenState
    extends State<HistoryDateSelectionScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Map<String, bool> _availableDates = {}; // Date -> hasData

  // Couleurs de l'application
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
      _loadAvailableDates();
    });
  }

  Future<void> _loadAvailableDates() async {
    setState(() => _isLoading = true);

    try {
      Map<String, bool> dates = {};

      // Définir la plage de dates à vérifier (6 mois en arrière)
      final now = DateTime.now();
      final sixMonthsAgo = now.subtract(Duration(days: 180));

      // Collections à vérifier pour trouver des données
      final collections = [
        'repas',
        'activites',
        'siestes',
        'changes',
        'sante',
        'photos',
        'transmissions'
      ];

      // Vérifier chaque collection
      for (String collection in collections) {
        final snapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(widget.structureId)
            .collection('children')
            .doc(widget.childId)
            .collection(collection)
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(sixMonthsAgo))
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          if (data['date'] != null) {
            final date = (data['date'] as Timestamp).toDate();
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            dates[dateKey] = true;
          }
        }
      }

      // Vérifier aussi les horaires
      final horairesSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('horaires_history')
          .where('childId', isEqualTo: widget.childId)
          .get();

      for (var doc in horairesSnapshot.docs) {
        final data = doc.data();
        if (data['date'] != null) {
          final dateStr = data['date'] as String;
          final date = DateTime.tryParse(dateStr);
          if (date != null && date.isAfter(sixMonthsAgo)) {
            dates[dateStr] = true;
          }
        }
      }

      setState(() {
        _availableDates = dates;
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des dates disponibles: $e");
      setState(() => _isLoading = false);
    }
  }

  bool _hasDataForDate(DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    return _availableDates[dateKey] ?? false;
  }

  void _navigateToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 1));
    });
  }

  void _navigateToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(Duration(days: 1));
    });
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _viewHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildHistoryDetailScreen(
          childId: widget.childId,
          childName: widget.childName,
          selectedDate: _selectedDate,
          structureId: widget.structureId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletDevice = MediaQuery.of(context).size.shortestSide >= 600;
    final bool hasDataForSelectedDate = _hasDataForDate(_selectedDate);

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
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  SizedBox(height: 20),
                  Text(
                    "Chargement des dates disponibles...",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // En-tête avec informations de l'enfant
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
                              Icons.history,
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
                                  widget.childName,
                                  style: TextStyle(
                                    fontSize: isTabletDevice ? 24 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  "Sélectionnez une date",
                                  style: TextStyle(
                                    fontSize: isTabletDevice ? 16 : 14,
                                    color: Colors.white.withOpacity(0.9),
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

                // Navigation entre jours
                Container(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _navigateToPreviousDay,
                        icon: Icon(Icons.arrow_back_ios),
                        color: primaryColor,
                        tooltip: 'Jour précédent',
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: primaryColor,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                                      .format(_selectedDate),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isTabletDevice ? 18 : 16,
                                    color: primaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
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

                // Contenu principal
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Indicateur de disponibilité des données
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: hasDataForSelectedDate
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: hasDataForSelectedDate
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.orange.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                hasDataForSelectedDate
                                    ? Icons.check_circle_outline
                                    : Icons.info_outline,
                                size: isTabletDevice ? 80 : 60,
                                color: hasDataForSelectedDate
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              SizedBox(height: 16),
                              Text(
                                hasDataForSelectedDate
                                    ? "Données disponibles"
                                    : "Aucune donnée pour cette date",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 24 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: hasDataForSelectedDate
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                hasDataForSelectedDate
                                    ? "Cliquez sur le bouton ci-dessous pour voir l'historique complet de cette journée"
                                    : "Aucune activité enregistrée pour ${widget.childName} à cette date",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 16 : 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 40),

                        // Bouton pour voir l'historique
                        if (hasDataForSelectedDate)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _viewHistory,
                              icon: Icon(
                                Icons.visibility,
                                color: Colors.white,
                              ),
                              label: Text(
                                "Voir l'historique détaillé",
                                style: TextStyle(
                                  fontSize: isTabletDevice ? 18 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: EdgeInsets.symmetric(
                                  vertical: isTabletDevice ? 16 : 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Pied de page avec info sur la rétention des données
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: Colors.grey.shade100,
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Les données sont conservées et disponibles pour consultation.',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
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
