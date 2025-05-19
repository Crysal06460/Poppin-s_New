import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StructureDetailsScreen extends StatelessWidget {
  const StructureDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Fond gris clair moderne
      appBar: AppBar(
        title: const Text(
          'Choix de la structure',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B8FE5), // Violet moderne
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.domain,
                size: 80,
                color: Color(0xFF8B8FE5)), // Icône pour symboliser le choix
            const SizedBox(height: 20),
            const Text(
              "Sélectionnez votre type de structure",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            _buildStructureCard(context, "Assistante Maternelle",
                Icons.child_friendly, "assistante_maternelle"),
            _buildStructureCard(context, "Maison Assistante Maternelle",
                Icons.home, "maison_assistante_maternelle"),
        
            const Spacer(),

            ElevatedButton(
              onPressed: () {
                context.go('/'); // Retour à la page d'accueil (SignupScreen)
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade400,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Retour",
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStructureCard(
    BuildContext context, String title, IconData icon, String structureType) {
  return GestureDetector(
    onTap: () {
      // Correction: ajoutez des logs de débogage
      print("💬 Type de structure sélectionné: $structureType");
      
      // Redirection vers la page d'abonnement en passant le type de structure
      context.go('/subscription', extra: structureType);
    },
    child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF8B8FE5)),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}