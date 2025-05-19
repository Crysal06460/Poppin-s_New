import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart'; // Ajouter cette import pour GoRouter

class FridgeTemperatureScreen extends StatefulWidget {
  const FridgeTemperatureScreen({Key? key}) : super(key: key);

  @override
  _FridgeTemperatureScreenState createState() =>
      _FridgeTemperatureScreenState();
}

class _FridgeTemperatureScreenState extends State<FridgeTemperatureScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> temperatureRecords = [];
  bool temperatureRecordedToday =
      false; // Indicateur si la température a été relevée aujourd'hui

  // Contrôleurs pour le formulaire
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();

  // Définition des couleurs de la palette (identiques à celles du DashboardScreen)
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Couleur principale de l'écran
  late Color primaryColor;

  @override
  void initState() {
    super.initState();
    // Utiliser la même couleur primaire que le dashboard
    primaryColor = primaryBlue;

    // Charger les données
    _loadTemperatureData();
  }

  @override
  void dispose() {
    // Libérer les contrôleurs
    _temperatureController.dispose();
    _memberNameController.dispose();
    super.dispose();
  }

  Future<String> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
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

      // Récupérer les 10 derniers enregistrements de température
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('fridgeTemperatures')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> records = [];
      bool foundTodayRecord = false;

      // Obtenir la date d'aujourd'hui à minuit pour la comparaison
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp;
        final recordDate = timestamp.toDate();

        // Vérifier si ce relevé a été fait aujourd'hui
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

      // Supprimer les enregistrements plus anciens que 10 jours
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
      // Calculer la date limite (10 jours en arrière)
      final cutoffDate = DateTime.now().subtract(Duration(days: 10));

      // Récupérer les enregistrements plus anciens que 10 jours
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
          "${oldRecordsSnapshot.docs.length} anciens enregistrements supprimés");
    } catch (e) {
      print("Erreur lors du nettoyage des anciens enregistrements: $e");
    }
  }

  Future<void> _addTemperatureRecord() async {
    // Valider les entrées
    if (_temperatureController.text.trim().isEmpty ||
        _memberNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Veuillez remplir tous les champs")));
      return;
    }

    // Vérifier que la température est un nombre valide
    double? temperature;
    try {
      // Remplacer la virgule par un point pour gérer les deux formats
      String normalizedInput = _temperatureController.text.replaceAll(',', '.');
      temperature = double.parse(normalizedInput);

      // Valider la plage de température (exemple: entre 0 et 8 degrés pour un frigo)
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

      // Créer le nouvel enregistrement
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('fridgeTemperatures')
          .add({
        'temperature': temperature,
        'memberName': _memberNameController.text.trim(),
        'timestamp': Timestamp.now(),
      });

      // Rafraîchir les données
      _loadTemperatureData();

      // Mettre à jour l'indicateur de relevé quotidien
      setState(() {
        temperatureRecordedToday = true;
      });

      // Réinitialiser les champs du formulaire
      _temperatureController.clear();

      // Afficher une confirmation
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

  // Formater la date/heure pour l'affichage
  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Température du frigo",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 2,
        iconTheme: IconThemeData(color: Colors.white),
        // Ajouter un bouton de retour explicite qui utilise GoRouter
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                // Alerte si la température n'a pas été relevée aujourd'hui
                if (!temperatureRecordedToday)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    color: Colors.red.shade100,
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade700),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "La température du frigo n'a pas été relevée aujourd'hui",
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Formulaire d'ajout
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nouvelle mesure de température",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Champ pour le nom du membre
                      TextField(
                        controller: _memberNameController,
                        decoration: InputDecoration(
                          labelText: "Qui a relevé la température ?",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: Icon(Icons.person, color: primaryColor),
                        ),
                      ),
                      SizedBox(height: 12),

                      // Champ pour la température
                      TextField(
                        controller: _temperatureController,
                        decoration: InputDecoration(
                          labelText: "Température (°C)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon:
                              Icon(Icons.thermostat, color: primaryColor),
                          suffixText: "°C",
                        ),
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                      ),
                      SizedBox(height: 16),

                      // Bouton d'ajout
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _addTemperatureRecord,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            "AJOUTER",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Titre de la liste
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
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
                      // Indicateur du nombre d'enregistrements
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                ),

                // Liste des enregistrements
                Expanded(
                  child: temperatureRecords.isEmpty
                      ? Center(
                          child: Text(
                            "Aucun relevé de température enregistré",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: temperatureRecords.length,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final record = temperatureRecords[index];

                            // Déterminer la couleur en fonction de la température
                            Color tempColor = Colors.green;
                            double temp = record['temperature'];
                            if (temp > 8) {
                              tempColor = Colors.red; // Trop élevée
                            } else if (temp > 5) {
                              tempColor = Colors.orange; // Limite haute
                            } else if (temp < 2) {
                              tempColor = Colors.blue; // Trop basse
                            }

                            return Card(
                              margin: EdgeInsets.only(bottom: 10),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Row(
                                  children: [
                                    // Température avec couleur indicative
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tempColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
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
                                    SizedBox(width: 12),
                                    // Nom du membre
                                    Expanded(
                                      child: Text(
                                        record['memberName'],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    _formatDateTime(record['timestamp']),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
