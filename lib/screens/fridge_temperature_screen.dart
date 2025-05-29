import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class FridgeTemperatureScreen extends StatefulWidget {
  const FridgeTemperatureScreen({Key? key}) : super(key: key);

  @override
  _FridgeTemperatureScreenState createState() =>
      _FridgeTemperatureScreenState();
}

class _FridgeTemperatureScreenState extends State<FridgeTemperatureScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> temperatureRecords = [];
  bool temperatureRecordedToday = false;

  // Contrôleurs pour le formulaire
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();

  // Définition des couleurs de la palette
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  // Couleur principale de l'écran
  late Color primaryColor;

  @override
  void initState() {
    super.initState();
    primaryColor = primaryBlue;
    _loadTemperatureData();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _memberNameController.dispose();
    super.dispose();
  }

  Future<String> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email?.toLowerCase() ?? '')
        .get();

    if (userDoc.exists &&
        userDoc.data() != null &&
        userDoc.data()!.containsKey('structureId')) {
      return userDoc.data()!['structureId'];
    }

    return user.uid;
  }

  Future<void> _loadTemperatureData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Récupérer les 50 derniers enregistrements pour afficher plus d'historique
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('fridgeTemperatures')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      List<Map<String, dynamic>> records = [];
      bool foundTodayRecord = false;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp;
        final recordDate = timestamp.toDate();

        if (recordDate.isAfter(startOfDay)) {
          foundTodayRecord = true;
        }

        records.add({
          'id': doc.id,
          'temperature': data['temperature'],
          'memberName': data['memberName'],
          'timestamp': data['timestamp'],
        });
      }

      // Nettoyer les enregistrements de plus de 30 jours
      _cleanupOldRecords(structureId);

      setState(() {
        temperatureRecords = records;
        temperatureRecordedToday = foundTodayRecord;
        isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des données de température: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _cleanupOldRecords(String structureId) async {
    try {
      // Calculer la date limite (30 jours en arrière)
      final cutoffDate = DateTime.now().subtract(Duration(days: 30));

      // Récupérer les enregistrements plus anciens que 30 jours
      final oldRecordsSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('fridgeTemperatures')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      // Supprimer les anciens enregistrements
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in oldRecordsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print(
          "${oldRecordsSnapshot.docs.length} anciens enregistrements supprimés (+ de 30 jours)");
    } catch (e) {
      print("Erreur lors du nettoyage des anciens enregistrements: $e");
    }
  }

  Future<void> _addTemperatureRecord() async {
    if (_temperatureController.text.trim().isEmpty ||
        _memberNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Veuillez remplir tous les champs")));
      return;
    }

    double? temperature;
    try {
      String normalizedInput = _temperatureController.text.replaceAll(',', '.');
      temperature = double.parse(normalizedInput);

      if (temperature < 0 || temperature > 10) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("La température doit être entre 0°C et 10°C")));
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Veuillez entrer une température valide")));
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('fridgeTemperatures')
          .add({
        'temperature': temperature,
        'memberName': _memberNameController.text.trim(),
        'timestamp': Timestamp.now(),
      });

      _loadTemperatureData();

      setState(() {
        temperatureRecordedToday = true;
      });

      _temperatureController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Température ajoutée avec succès")));
    } catch (e) {
      print("Erreur lors de l'ajout de la température: $e");
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur lors de l'ajout: $e")));
    }
  }

  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  Color _getTemperatureColor(double temp) {
    if (temp > 8) {
      return Colors.red; // Trop élevée
    } else if (temp > 5) {
      return Colors.orange; // Limite haute
    } else if (temp < 2) {
      return Colors.blue; // Trop basse
    }
    return Colors.green; // Normale
  }

  // Nouvelle méthode pour le contenu tablette
  Widget _buildTabletContent() {
    return LayoutBuilder(builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth;
      final double maxHeight = constraints.maxHeight;
      final double sideMargin = maxWidth * 0.03;
      final double columnGap = maxWidth * 0.025;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          sideMargin,
          maxHeight * 0.02,
          sideMargin,
          maxHeight * 0.02,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panneau latéral gauche (Formulaire d'ajout)
            Expanded(
              flex: 4,
              child: Container(
                margin: EdgeInsets.only(right: columnGap),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(maxWidth * 0.025),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre avec icône
                      Row(
                        children: [
                          Icon(
                            Icons.thermostat,
                            color: primaryColor,
                            size: maxWidth * 0.07,
                          ),
                          SizedBox(width: maxWidth * 0.015),
                          Expanded(
                            child: Text(
                              "Nouvelle mesure",
                              style: TextStyle(
                                fontSize: maxWidth * 0.022,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.025),

                      // Alerte si pas de relevé aujourd'hui
                      if (!temperatureRecordedToday)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(maxWidth * 0.02),
                          margin: EdgeInsets.only(bottom: maxHeight * 0.025),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red.shade700,
                                size: maxWidth * 0.025,
                              ),
                              SizedBox(width: maxWidth * 0.015),
                              Expanded(
                                child: Text(
                                  "Température non relevée aujourd'hui",
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w500,
                                    fontSize: maxWidth * 0.016,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Formulaire
                      Expanded(
                        child: Column(
                          children: [
                            _buildTabletFormField(
                              controller: _memberNameController,
                              label: "Qui a relevé la température ?",
                              icon: Icons.person,
                              maxWidth: maxWidth,
                            ),

                            SizedBox(height: maxHeight * 0.025),

                            _buildTabletFormField(
                              controller: _temperatureController,
                              label: "Température (°C)",
                              icon: Icons.thermostat,
                              maxWidth: maxWidth,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              suffixText: "°C",
                            ),

                            SizedBox(height: maxHeight * 0.04),

                            // Bouton d'ajout stylé pour iPad
                            Center(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _addTemperatureRecord,
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: maxWidth * 0.08,
                                      vertical: maxHeight * 0.02,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          primaryColor,
                                          primaryColor.withOpacity(0.8)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.3),
                                          offset: const Offset(0, 4),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: maxWidth * 0.022,
                                        ),
                                        SizedBox(width: maxWidth * 0.015),
                                        Text(
                                          'AJOUTER',
                                          style: TextStyle(
                                            fontSize: maxWidth * 0.018,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
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
            ),

            // Panneau de droite (Historique)
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(maxWidth * 0.025),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête de la section historique
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              "Historique des températures",
                              style: TextStyle(
                                fontSize: 16, // Taille réduite
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: lightBlue,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${temperatureRecords.length} relevés",
                                style: TextStyle(
                                  fontSize: 12, // Taille réduite
                                  fontWeight: FontWeight.w500,
                                  color: primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      // Liste des enregistrements
                      Expanded(
                        child: temperatureRecords.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.thermostat_outlined,
                                      size: maxWidth * 0.08,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: maxHeight * 0.02),
                                    Text(
                                      "Aucun relevé enregistré",
                                      style: TextStyle(
                                        fontSize: maxWidth * 0.018,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: temperatureRecords.length,
                                itemBuilder: (context, index) {
                                  final record = temperatureRecords[index];
                                  final double temp = record['temperature'];
                                  final Color tempColor =
                                      _getTemperatureColor(temp);

                                  return Container(
                                    margin: EdgeInsets.only(
                                        bottom: maxHeight * 0.015),
                                    padding: EdgeInsets.all(maxWidth * 0.02),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Température avec couleur indicative
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: maxWidth * 0.015,
                                            vertical: maxHeight * 0.008,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tempColor.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "${temp.toStringAsFixed(1)}°C",
                                            style: TextStyle(
                                              fontSize: maxWidth * 0.018,
                                              fontWeight: FontWeight.bold,
                                              color: tempColor,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: maxWidth * 0.02),
                                        // Informations
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                record['memberName'],
                                                style: TextStyle(
                                                  fontSize: maxWidth * 0.016,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              SizedBox(
                                                  height: maxHeight * 0.005),
                                              Text(
                                                _formatDateTime(
                                                    record['timestamp']),
                                                style: TextStyle(
                                                  fontSize: maxWidth * 0.014,
                                                  color: Colors.grey.shade600,
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Nouvelle méthode pour créer un champ de formulaire stylé pour iPad
  Widget _buildTabletFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double maxWidth,
    TextInputType? keyboardType,
    String? suffixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: maxWidth * 0.018,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          prefixIcon: Container(
            margin: EdgeInsets.all(maxWidth * 0.015),
            padding: EdgeInsets.all(maxWidth * 0.01),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: maxWidth * 0.022,
            ),
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: maxWidth * 0.016,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: maxWidth * 0.04,
            vertical: maxWidth * 0.02,
          ),
        ),
      ),
    );
  }

  // Méthode pour le contenu iPhone (améliorée)
  Widget _buildPhoneContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alerte si pas de relevé aujourd'hui
          if (!temperatureRecordedToday)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.red.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "La température du frigo n'a pas été relevée aujourd'hui",
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Formulaire d'ajout dans une carte moderne
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(0, 3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.thermostat,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Nouvelle mesure de température",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                _buildPhoneFormField(
                  controller: _memberNameController,
                  label: "Qui a relevé la température ?",
                  icon: Icons.person,
                ),
                SizedBox(height: 16),

                _buildPhoneFormField(
                  controller: _temperatureController,
                  label: "Température (°C)",
                  icon: Icons.thermostat,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  suffixText: "°C",
                ),
                SizedBox(height: 24),

                // Bouton d'ajout modernisé
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _addTemperatureRecord,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor,
                                primaryColor.withOpacity(0.8)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'AJOUTER',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Section Historique
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(0, 3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                // En-tête de la section historique
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Historique des températures",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${temperatureRecords.length} relevés",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Liste des enregistrements ou message vide
                temperatureRecords.isEmpty
                    ? Container(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.thermostat_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Aucun relevé de température enregistré",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        constraints: BoxConstraints(
                            maxHeight: 400), // Limiter la hauteur
                        child: ListView.builder(
                          itemCount: temperatureRecords.length,
                          itemBuilder: (context, index) {
                            final record = temperatureRecords[index];
                            final double temp = record['temperature'];
                            final Color tempColor = _getTemperatureColor(temp);

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Température avec couleur indicative
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tempColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "${temp.toStringAsFixed(1)}°C",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: tempColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  // Informations
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          record['memberName'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _formatDateTime(record['timestamp']),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
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
                      ),
              ],
            ),
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  // Nouvelle méthode pour créer un champ de formulaire stylé pour iPhone
  Widget _buildPhoneFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? suffixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête avec fond de couleur - Identique aux autres pages
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
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(screenSize.width * 0.06),
                bottomRight: Radius.circular(screenSize.width * 0.06),
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
                padding: EdgeInsets.fromLTRB(
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * 0.02,
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * (isTablet ? 0.02 : 0.025),
                ),
                child: Row(
                  children: [
                    // Bouton retour avec meilleur contraste
                    GestureDetector(
                      onTap: () => context.go('/dashboard'),
                      child: Container(
                        padding: EdgeInsets.all(
                            screenSize.width * (isTablet ? 0.015 : 0.02)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: screenSize.width * (isTablet ? 0.025 : 0.06),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: screenSize.width * (isTablet ? 0.02 : 0.04)),
                    // Titre avec meilleur style
                    Expanded(
                      child: Text(
                        "Température du frigo",
                        style: TextStyle(
                          fontSize:
                              screenSize.width * (isTablet ? 0.028 : 0.055),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal avec adaptation pour iPad
          isLoading
              ? Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                )
              : Expanded(
                  child:
                      isTablet ? _buildTabletContent() : _buildPhoneContent(),
                ),
        ],
      ),
    );
  }
}
