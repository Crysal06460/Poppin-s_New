import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class MonthlyReportSelectionScreen extends StatefulWidget {
  const MonthlyReportSelectionScreen({Key? key}) : super(key: key);

  @override
  _MonthlyReportSelectionScreenState createState() =>
      _MonthlyReportSelectionScreenState();
}

class _MonthlyReportSelectionScreenState
    extends State<MonthlyReportSelectionScreen> {
  bool isLoading = true;
  late String selectedChildId = '';
  late String selectedChildName = '';
  late String structureName = '';
  late String structureId = '';
  List<Map<String, dynamic>> children = [];
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  late List<int> availableYears;
  bool isMAMStructure = false;
  String currentUserEmail = "";

  final List<String> frenchMonths = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre'
  ];

  @override
  void initState() {
    super.initState();
    availableYears =
        List.generate(5, (index) => DateTime.now().year - 2 + index);
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadData();
    });
  }

  // Méthode pour obtenir l'ID de structure
  Future<String> _getStructureId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "";

      // Obtenir l'email de l'utilisateur actuel
      currentUserEmail = user.email?.toLowerCase() ?? '';
      print("👤 Email de l'utilisateur connecté: $currentUserEmail");

      // Vérifier si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      print(
          "👤 Vérification du document utilisateur: ${userDoc.exists ? 'existe' : 'n\'existe pas'}");
      if (userDoc.exists) {
        final userData = userDoc.data();
        print("👤 Données utilisateur: $userData");
      }

      // Si c'est un membre MAM, obtenir l'ID de la structure associée
      if (userDoc.exists &&
          userDoc.data() != null &&
          userDoc.data()!.containsKey('structureId')) {
        String structId = userDoc.data()!['structureId'];
        print("👤 Utilisateur MAM détecté avec structureId: $structId");
        return structId;
      }

      // Par défaut, utiliser l'ID de l'utilisateur
      print("👤 Utilisateur standard avec uid: ${user.uid}");
      return user.uid;
    } catch (e) {
      print("🚨 Erreur dans _getStructureId: $e");
      return "";
    }
  }

  // Ajoutez cette méthode pour déboguer le problème de structure
  // Ajoutez cette méthode pour déboguer le problème de structure
  Future<void> _debugStructureIssue() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String userEmail = user.email?.toLowerCase() ?? '';
      print("🔍 DEBUG - Email utilisateur: $userEmail");
      print("🔍 DEBUG - UID utilisateur: ${user.uid}");

      // Vérifier le document utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      print("🔍 DEBUG - Document utilisateur existe: ${userDoc.exists}");
      if (userDoc.exists) {
        final userData = userDoc.data();
        print("🔍 DEBUG - Données utilisateur: $userData");

        if (userData != null && userData.containsKey('structureId')) {
          String structId = userData['structureId'];
          print("🔍 DEBUG - Structure ID depuis userData: $structId");

          // Vérifier si ce document de structure existe
          final structDoc = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structId)
              .get();

          print("🔍 DEBUG - Document structure existe: ${structDoc.exists}");
          if (structDoc.exists) {
            print("🔍 DEBUG - Données structure: ${structDoc.data()}");
          }

          // Vérifier si la sous-collection children existe
          final childrenSnapshot = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structId)
              .collection('children')
              .limit(1)
              .get();

          print(
              "🔍 DEBUG - Sous-collection children existe: ${childrenSnapshot.docs.isNotEmpty}");
          print(
              "🔍 DEBUG - Nombre d'enfants dans la sous-collection: ${childrenSnapshot.docs.length}");
        }
      }

      // Vérifier aussi avec l'UID comme fallback
      final structWithUidDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get();

      print(
          "🔍 DEBUG - Document structure avec UID existe: ${structWithUidDoc.exists}");
      if (structWithUidDoc.exists) {
        print("🔍 DEBUG - Données structure (UID): ${structWithUidDoc.data()}");
      }
    } catch (e) {
      print("🚨 DEBUG - Erreur: $e");
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);

      // Obtenir l'email de l'utilisateur actuel d'abord
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      currentUserEmail = user.email?.toLowerCase() ?? '';
      print("👤 Email de l'utilisateur connecté: $currentUserEmail");

      // Obtenir l'ID de structure correct (pour MAM ou Assistante Maternelle)
      structureId = await _getStructureId();
      if (structureId.isEmpty) {
        throw Exception('ID de structure non trouvé');
      }

      print("🔍 Chargement des données pour la structure: $structureId");

      // D'abord, déterminer le type de structure pour le filtrage
      bool isMAMStructureTemp = false;
      try {
        // Vérifier si c'est un utilisateur MAM
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserEmail)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          isMAMStructureTemp =
              userData.containsKey('role') && userData['role'] == 'mamMember';
        }
      } catch (e) {
        print("⚠️ Erreur lors de la vérification du type d'utilisateur: $e");
      }

      // Obtenir la liste des enfants avec le bon filtrage
      print("👶 Chargement des enfants...");
      List<Map<String, dynamic>> allChildren =
          await _loadChildren(structureId, isMAMStructureTemp);

      if (allChildren.isEmpty) {
        print("⚠️ Aucun enfant trouvé dans la structure!");
      } else {
        print("✅ ${allChildren.length} enfant(s) trouvé(s) dans la structure");
        for (var child in allChildren) {
          print(
              "  👶 ID: ${child['id']}, Nom: ${child['firstName']} ${child['lastName'] ?? ''}, ${child.containsKey('assignedMemberEmail') ? 'assignedTo: ${child['assignedMemberEmail']}' : 'pas d\'assignation'}");
        }
      }

      // Obtenir les données de la structure avec gestion d'erreur améliorée
      String structureNameLocal = 'Ma Structure'; // Valeur par défaut
      bool isMAMStructureLocal = false;

      try {
        final structureDoc = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .get();

        if (structureDoc.exists) {
          final structureData = structureDoc.data();
          structureNameLocal =
              structureData?['structureName'] ?? 'Ma Structure';
          isMAMStructureLocal = structureData?['structureType'] == 'MAM';
          print(
              "🏢 Structure trouvée: $structureNameLocal, Type: ${structureData?['structureType']}, Est MAM: $isMAMStructureLocal");
        } else {
          print(
              "⚠️ Document de structure non trouvé, utilisation de valeurs par défaut");
          // Si nous sommes ici et que des enfants ont été trouvés, c'est probablement une MAM
          // Essayons de déterminer si c'est une MAM basé sur la présence d'assignedMemberEmail
          isMAMStructureLocal = allChildren.any((child) =>
              child.containsKey('assignedMemberEmail') &&
              child['assignedMemberEmail'] != null &&
              child['assignedMemberEmail'].toString().isNotEmpty);

          // Si c'est une MAM, essayons de récupérer le nom depuis les données utilisateur
          if (isMAMStructureLocal) {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserEmail)
                  .get();

              if (userDoc.exists && userDoc.data() != null) {
                structureNameLocal = userDoc.data()!['structureName'] ?? 'MAM';
              }
            } catch (e) {
              print(
                  "⚠️ Impossible de récupérer le nom de structure depuis les données utilisateur: $e");
            }
          }
        }
      } catch (e) {
        print("⚠️ Erreur lors de la récupération des données de structure: $e");
        // Continuons avec les valeurs par défaut
        print("🔄 Utilisation des valeurs par défaut pour continuer");
      }

      setState(() {
        children = allChildren;
        structureName = structureNameLocal;
        isMAMStructure = isMAMStructureLocal;
        isLoading = false;

        if (children.isNotEmpty) {
          selectedChildId = children[0]['id'];
          selectedChildName = children[0]['firstName'];
        }
      });

      print("🎉 Chargement terminé avec succès!");
    } catch (e) {
      print("🚨 Erreur lors du chargement des données: $e");
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadChildren(
      String structId, bool isMAMStructureTemp) async {
    try {
      final childrenSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structId)
          .collection('children')
          .get();

      print(
          "🔍 Nombre d'enfants trouvés dans Firestore: ${childrenSnapshot.docs.length}");

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren = childrenSnapshot.docs.map((doc) {
        final data = doc.data();
        // Créer une copie sécurisée des informations financières
        Map<String, dynamic> safeFinancialInfo = {};

        // Vérifier si financialInfo existe et le convertir en Map<String, dynamic>
        if (data.containsKey('financialInfo') &&
            data['financialInfo'] != null) {
          // Cast sécurisé de financialInfo
          try {
            if (data['financialInfo'] is Map) {
              // Convertir explicitement en Map<String, dynamic>
              final originalMap = data['financialInfo'] as Map;
              originalMap.forEach((key, value) {
                safeFinancialInfo[key.toString()] = value;
              });
            }
          } catch (e) {
            print(
                "⚠️ Erreur lors de la conversion de financialInfo pour ${data['firstName']}: $e");
          }
        }

        return {
          'id': doc.id,
          'firstName': data['firstName'] ?? 'Sans nom',
          'lastName': data['lastName'] ?? '',
          'photoUrl': data['photoUrl'],
          'assignedMemberEmail':
              data['assignedMemberEmail']?.toString().toLowerCase() ?? '',
          'financialInfo': safeFinancialInfo, // Utiliser la copie sécurisée
        };
      }).toList();

      // Liste filtrée selon le type de structure
      List<Map<String, dynamic>> filteredChildren = [];

      if (isMAMStructureTemp) {
        print(
            "👨‍👧‍👦 Filtrage des enfants pour le membre MAM: $currentUserEmail");
        // Pour une MAM: filtrer par assignedMemberEmail
        filteredChildren = allChildren.where((child) {
          String assignedEmail = child['assignedMemberEmail'];
          bool isAssigned = assignedEmail == currentUserEmail;
          print(
              "  🔍 Enfant: ${child['firstName']}, assigné à: '$assignedEmail', est assigné à l'utilisateur: $isAssigned");
          return isAssigned;
        }).toList();
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants
        filteredChildren = allChildren;
        print("👩‍👧‍👦 Assistante Maternelle - affichage de tous les enfants");
      }

      // Filtrer uniquement les enfants avec useMonthlyTable activé
      List<Map<String, dynamic>> monthlyTableChildren =
          filteredChildren.where((child) {
        final financialInfo = child['financialInfo'] as Map<String, dynamic>;
        bool useMonthlyTable = financialInfo.containsKey('useMonthlyTable') &&
            financialInfo['useMonthlyTable'] == true;
        print(
            "  📊 Enfant: ${child['firstName']}, utilise le tableau mensuel: $useMonthlyTable");
        return useMonthlyTable;
      }).toList();

      if (monthlyTableChildren.isEmpty) {
        print("⚠️ Aucun enfant avec useMonthlyTable activé!");
        return []; // Retourner une liste vide si aucun enfant n'utilise le tableau mensuel
      }

      return monthlyTableChildren;
    } catch (e) {
      print("🚨 Erreur dans _loadChildren: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau Mensuel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : children.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning, size: 48, color: Colors.orange),
                      SizedBox(height: 16),
                      Text(
                        'Aucun enfant trouvé',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Veuillez d\'abord ajouter des enfants ou activer\nle tableau mensuel dans leurs profils.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/dashboard'),
                        child: Text('Retour au tableau de bord'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre
                      Text(
                        'Générer un tableau mensuel',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),

                      // Structure
                      Text(
                        'Structure: $structureName',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 24),

                      // Sélection de l'enfant
                      Text(
                        'Sélectionner un enfant:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedChildId.isNotEmpty
                                ? selectedChildId
                                : null,
                            isExpanded: true,
                            hint: Text('Sélectionner un enfant'),
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            items: children.map((child) {
                              return DropdownMenuItem<String>(
                                value: child['id'],
                                child: Text(
                                    '${child['firstName']} ${child['lastName'] ?? ''}'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedChildId = value;
                                  selectedChildName = children.firstWhere(
                                      (child) =>
                                          child['id'] == value)['firstName'];
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 24),

                      // Sélection de l'année
                      Text(
                        'Année:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedYear,
                            isExpanded: true,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            items: availableYears.map((year) {
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedYear = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 24),

                      // Sélection du mois
                      Text(
                        'Mois:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedMonth,
                            isExpanded: true,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            items: List.generate(12, (index) {
                              return DropdownMenuItem<int>(
                                value: index + 1,
                                child: Text(frenchMonths[index]),
                              );
                            }),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedMonth = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      Spacer(),

                      // Bouton de génération
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedChildId.isNotEmpty
                              ? () {
                                  final reportParams = {
                                    'childId': selectedChildId,
                                    'year': selectedYear,
                                    'month': selectedMonth,
                                  };

                                  context.go('/monthly-report-generate',
                                      extra: reportParams);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Générer le tableau',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
