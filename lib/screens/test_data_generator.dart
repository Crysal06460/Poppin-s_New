import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';

class TestDataGeneratorScreen extends StatefulWidget {
  const TestDataGeneratorScreen({Key? key}) : super(key: key);

  @override
  _TestDataGeneratorScreenState createState() => _TestDataGeneratorScreenState();
}

class _TestDataGeneratorScreenState extends State<TestDataGeneratorScreen> {
  bool isLoading = false;
  List<Map<String, dynamic>> children = [];
  String? selectedChildId;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  int numberOfDays = 10;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('children')
          .get();

      List<Map<String, dynamic>> loadedChildren = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedChildren.add({
          'id': doc.id,
          'fullName': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
          'photoUrl': data['photoUrl'],
          'firstName': data['firstName'],
          'lastName': data['lastName'],
        });
      }

      setState(() {
        children = loadedChildren;
        if (children.isNotEmpty) {
          selectedChildId = children[0]['id'];
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _generateTestData() async {
    if (selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un enfant')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Trouver l'enfant sélectionné
      String? childName;
      String? firstName;
      for (var child in children) {
        if (child['id'] == selectedChildId) {
          childName = child['fullName'];
          firstName = child['firstName'];
          break;
        }
      }

      if (childName == null) {
        throw Exception('Informations de l\'enfant introuvables');
      }

      // Générer des jours aléatoires dans le mois
      final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
      List<int> randomDays = [];
      
      // S'assurer qu'on ne demande pas plus de jours qu'il n'y en a dans le mois
      final daysToGenerate = min(numberOfDays, daysInMonth);
      
      // Générer des jours uniques aléatoires
      while (randomDays.length < daysToGenerate) {
        int day = random.nextInt(daysInMonth) + 1;
        if (!randomDays.contains(day)) {
          randomDays.add(day);
        }
      }
      
      // Trier les jours
      randomDays.sort();

      // D'abord, supprimer les données existantes pour ce mois
      // pour éviter les conflits avec les données précédentes
      await _clearExistingData(user.uid, selectedYear, selectedMonth);

      // Pour chaque jour, générer des données aléatoires
      for (int day in randomDays) {
        final DateTime date = DateTime(selectedYear, selectedMonth, day);
        final String dateString = DateFormat('yyyy-MM-dd').format(date);
        
        // Générer heure d'arrivée (entre 7h et 9h)
        final int arrivalHour = 7 + random.nextInt(3);
        final int arrivalMinute = random.nextInt(60);
        final String arrivalTime = 
            '${arrivalHour.toString().padLeft(2, '0')}:${arrivalMinute.toString().padLeft(2, '0')}';
        
        // Générer heure de départ (entre 16h et 18h)
        final int departureHour = 16 + random.nextInt(3);
        final int departureMinute = random.nextInt(60);
        final String departureTime = 
            '${departureHour.toString().padLeft(2, '0')}:${departureMinute.toString().padLeft(2, '0')}';
        
        // Générer des kilomètres (entre 0 et 20)
        final int km = random.nextInt(21);
        
        // Créer la map pour Firestore
        Map<String, dynamic> horaireData = {};
        horaireData[selectedChildId!] = {
          'arrivee': arrivalTime,
          'depart': departureTime,
          'km': km,
          'actionType': 'present',
          'prenom': firstName,
          'exactTime': Timestamp.now(),
        };
        
        // Enregistrer dans Firestore
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(user.uid)
            .collection('horaires')
            .doc(dateString)
            .set(horaireData, SetOptions(merge: true));
      }

      // Ajouter des informations de salaire si elles n'existent pas
      await _ensureChildHasSalaryInfo(user.uid, selectedChildId!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Données de test générées avec succès pour $daysToGenerate jours')),
      );
    } catch (e) {
      print('Erreur: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Méthode pour effacer les données existantes du mois
  Future<void> _clearExistingData(String uid, int year, int month) async {
    try {
      final DateTime startOfMonth = DateTime(year, month, 1);
      final DateTime endOfMonth = DateTime(year, month + 1, 0);
      
      for (int day = 1; day <= endOfMonth.day; day++) {
        final String dateString = DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
        
        // Vérifier si le document existe
        final docRef = FirebaseFirestore.instance
            .collection('structures')
            .doc(uid)
            .collection('horaires')
            .doc(dateString);
            
        final docSnapshot = await docRef.get();
        
        if (docSnapshot.exists) {
          // Si le document contient des données pour d'autres enfants,
          // supprimer uniquement les données de l'enfant sélectionné
          if (docSnapshot.data()!.containsKey(selectedChildId!)) {
            Map<String, dynamic> updatedData = Map.from(docSnapshot.data()!);
            updatedData.remove(selectedChildId!);
            
            if (updatedData.isEmpty) {
              await docRef.delete();
            } else {
              await docRef.set(updatedData);
            }
          }
        }
      }
      
      print('Données existantes effacées avec succès');
    } catch (e) {
      print('Erreur lors de la suppression des données existantes: $e');
      throw e;
    }
  }

  // Méthode pour s'assurer que l'enfant a des informations de salaire
  Future<void> _ensureChildHasSalaryInfo(String uid, String childId) async {
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(uid)
          .collection('children')
          .doc(childId)
          .get();
      
      if (!childDoc.exists) return;
      
      final data = childDoc.data() ?? {};
      final salaryInfo = data['salaryInfo'] as Map<String, dynamic>?;
      
      if (salaryInfo == null || 
          salaryInfo['netSalary'] == null || 
          salaryInfo['maintenanceRate'] == null ||
          salaryInfo['mealRate'] == null ||
          salaryInfo['kmRate'] == null) {
        
        // Créer des informations de salaire par défaut
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(uid)
            .collection('children')
            .doc(childId)
            .update({
          'salaryInfo': {
            'netSalary': 500.0, // Salaire net mensuel par défaut
            'maintenanceRate': 3.5, // Indemnité d'entretien journalière
            'mealRate': 4.0, // Indemnité de repas
            'kmRate': 0.35, // Indemnité kilométrique
          }
        });
        
        print('Informations de salaire par défaut ajoutées');
      }
    } catch (e) {
      print('Erreur lors de la vérification des infos de salaire: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Générateur de données test'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sélectionnez un enfant',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (children.isEmpty)
                    Text('Aucun enfant trouvé')
                  else
                    DropdownButton<String>(
                      value: selectedChildId,
                      isExpanded: true,
                      hint: Text('Sélectionner un enfant'),
                      onChanged: (value) {
                        setState(() {
                          selectedChildId = value;
                        });
                      },
                      items: children.map((child) {
                        return DropdownMenuItem<String>(
                          value: child['id'],
                          child: Text(child['fullName']),
                        );
                      }).toList(),
                    ),
                  
                  SizedBox(height: 20),
                  
                  Text(
                    'Mois et année',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedMonth,
                          isExpanded: true,
                          onChanged: (value) {
                            setState(() {
                              selectedMonth = value!;
                            });
                          },
                          items: List.generate(12, (index) {
                            return DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text(DateFormat('MMMM', 'fr_FR').format(DateTime(2023, index + 1))),
                            );
                          }),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedYear,
                          isExpanded: true,
                          onChanged: (value) {
                            setState(() {
                              selectedYear = value!;
                            });
                          },
                          items: List.generate(3, (index) {
                            final year = DateTime.now().year - index;
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  Text(
                    'Nombre de jours à générer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  Slider(
                    value: numberOfDays.toDouble(),
                    min: 1,
                    max: 31,
                    divisions: 30,
                    label: numberOfDays.toString(),
                    onChanged: (value) {
                      setState(() {
                        numberOfDays = value.toInt();
                      });
                    },
                  ),
                  Text('$numberOfDays jours'),
                  
                  SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _generateTestData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Générer des données',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/monthly-report-selection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Aller au Tableau Mensuel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}