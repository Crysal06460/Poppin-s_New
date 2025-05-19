import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CongratulationsScreen extends StatelessWidget {
  // Ajout d'un paramètre pour stocker le type de structure
  final String structureType;
  
  const CongratulationsScreen({
    Key? key, 
    required this.structureType
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ajout de logs pour déboguer
    print("🎉 CongratulationsScreen reçoit structureType: '$structureType'");
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Félicitations !"),
        backgroundColor: const Color(0xFF8B8FE5),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Color(0xFF8B8FE5)),
            const SizedBox(height: 20),
            const Text(
              "Votre compte a été créé avec succès !",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              "Nous allons maintenant configurer votre structure.",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Bouton modifié pour passer à la confirmation de structure
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Correction: Passer le type de structure à l'écran de confirmation
                  print("🚀 Naviguer vers /structure-confirmation avec structureType: '$structureType'");
                  context.go('/structure-confirmation', extra: structureType);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B8FE5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Continuer",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}