import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoading = false;
  String _statusMessage = "";
  int _totalProcessed = 0;
  int _totalFixed = 0;

  // Couleurs
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color primaryRed = Color(0xFFD94350);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Administration"),
        backgroundColor: primaryBlue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Maintenance base de données",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Cet outil permet de corriger les relations parent-enfant manquantes dans la base de données.",
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 20),
                    _isLoading
                        ? Column(
                            children: [
                              LinearProgressIndicator(),
                              SizedBox(height: 10),
                              Text("Traitement en cours... $_statusMessage"),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _fixAllChildrenParentIds,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            child: Text("Corriger les relations parent-enfant"),
                          ),
                    SizedBox(height: 10),
                    if (_totalProcessed > 0)
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Résultats de la dernière exécution:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text("- Enfants traités: $_totalProcessed"),
                            Text("- Relations corrigées: $_totalFixed"),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fixAllChildrenParentIds() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Initialisation...";
      _totalProcessed = 0;
      _totalFixed = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar("Vous devez être connecté");
        setState(() => _isLoading = false);
        return;
      }

      // Récupérer toutes les structures
      setState(() => _statusMessage = "Récupération des structures...");
      final structures =
          await FirebaseFirestore.instance.collection('structures').get();

      // Pour chaque structure
      for (var structure in structures.docs) {
        final structureId = structure.id;

        setState(() => _statusMessage = "Structure: $structureId");

        // Récupérer tous les enfants
        final children = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .get();

        setState(() => _statusMessage =
            "Structure: $structureId, Traitement de ${children.docs.length} enfants");

        // Pour chaque enfant
        for (var child in children.docs) {
          final childId = child.id;
          final childData = child.data();

          setState(() {
            _totalProcessed++;
            _statusMessage =
                "Traitement enfant $childId (${_totalProcessed}/${children.docs.length})";
          });

          // Si l'enfant n'a pas de parentId
          if (childData['parentId'] == null ||
              childData['parentId'].toString().isEmpty) {
            // Rechercher un utilisateur qui a cet enfant dans sa liste
            final parentUsers = await FirebaseFirestore.instance
                .collection('users')
                .where('children', arrayContains: childId)
                .limit(1)
                .get();

            if (parentUsers.docs.isNotEmpty) {
              final parentUser = parentUsers.docs.first;
              final parentId = parentUser.data()['uid'];

              // Mettre à jour l'enfant
              await FirebaseFirestore.instance
                  .collection('structures')
                  .doc(structureId)
                  .collection('children')
                  .doc(childId)
                  .update({'parentId': parentId});

              setState(() => _totalFixed++);
              print("✅ Enfant $childId mis à jour avec parentId: $parentId");
            } else {
              print("⚠️ Pas de parent trouvé pour l'enfant: $childId");
            }
          }
        }
      }

      setState(() => _isLoading = false);
      _showSuccessSnackBar(
          "Correction terminée! $_totalFixed relations corrigées sur $_totalProcessed enfants");
    } catch (e) {
      print("❌ Erreur lors de la correction: $e");
      setState(() => _isLoading = false);
      _showErrorSnackBar("Erreur: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
