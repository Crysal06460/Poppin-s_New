import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StructureConfirmationScreen extends StatelessWidget {
  final String structureType;

  const StructureConfirmationScreen({Key? key, required this.structureType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Afficher la valeur reçue pour débogage
    print("🔍 Valeur structureType reçue: '$structureType'");
    
    // Convertir le type de structure pour le stockage
    final String formattedType;
    final String typeDisplay;
    
    // CORRECTION: Vérifier correctement la valeur reçue
    if (structureType == "assistante_maternelle") {
      formattedType = "AssistanteMaternelle";
      typeDisplay = "Assistante Maternelle";
    } else if (structureType == "maison_assistante_maternelle") {
      formattedType = "MAM";
      typeDisplay = "Maison Assistante Maternelle";
    } else {
      // Afficher explicitement la valeur problématique pour déboguer
      print("⚠️ Type de structure non reconnu: '$structureType' (type: ${structureType.runtimeType})");
      
      // Valeur par défaut en cas d'erreur
      formattedType = "AssistanteMaternelle";
      typeDisplay = "Assistante Maternelle (par défaut)";
    }
    
    print("🏢 Type formatté pour enregistrement: '$formattedType'");
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Confirmation de la structure',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B8FE5),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.check_circle_outline, 
                size: 80, 
                color: Color(0xFF8B8FE5)),
            const SizedBox(height: 20),
            const Text(
              "Votre choix",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Type: $typeDisplay",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Valeur brute reçue: $structureType",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Retour à la sélection de type
                    context.go('/structure-details');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Modifier", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                
                ElevatedButton(
                  onPressed: () async {
                    // Afficher un indicateur de chargement
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    );
                    
                    // Enregistrer le type de structure dans Firestore
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      print("👤 Utilisateur actuel: ${user?.uid}");
                      
                      if (user != null) {
                        print("📝 Tentative de mise à jour du document structure...");
                        
                        try {
                          // D'abord, vérifier si le document existe
                          DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
                              .collection('structures')
                              .doc(user.uid)
                              .get();
                              
                          print("📄 Document existe: ${docSnapshot.exists}");
                          
                          if (docSnapshot.exists) {
                            // Si le document existe, mise à jour
                            await FirebaseFirestore.instance
                                .collection('structures')
                                .doc(user.uid)
                                .update({
                                  'structureType': formattedType,
                                  'lastUpdated': FieldValue.serverTimestamp(),
                                });
                            print("✅ Document mis à jour avec le type: $formattedType");
                          } else {
                            // Si le document n'existe pas, création
                            await FirebaseFirestore.instance
                                .collection('structures')
                                .doc(user.uid)
                                .set({
                                  'structureType': formattedType,
                                  'email': user.email,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'structureName': 'Nouvelle Structure', // Valeur par défaut
                                });
                            print("✅ Nouveau document créé avec le type: $formattedType");
                          }
                          
                          // Fermer l'indicateur de chargement
                          Navigator.of(context).pop();
                          
                          // Ajouter SnackBar de confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Type de structure enregistré : $typeDisplay"),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          
                          // Rediriger vers la page suivante
                          Future.delayed(const Duration(seconds: 1), () {
                            context.go('/structure-info');
                          });
                        } catch (e) {
                          print("❌ Erreur Firestore détaillée: $e");
                          // Fermer l'indicateur de chargement
                          Navigator.of(context).pop();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Erreur: ${e.toString()}")),
                          );
                        }
                      } else {
                        print("❌ Utilisateur non connecté");
                        // Fermer l'indicateur de chargement
                        Navigator.of(context).pop();
                        
                        // Gérer l'erreur: utilisateur non connecté
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Erreur d'authentification. Veuillez vous reconnecter.")),
                        );
                      }
                    } catch (e) {
                      print("❌❌ Erreur critique: $e");
                      // Fermer l'indicateur de chargement
                      Navigator.of(context).pop();
                      
                      // Afficher un message d'erreur à l'utilisateur
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Une erreur est survenue: ${e.toString()}")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B8FE5),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Confirmer", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}