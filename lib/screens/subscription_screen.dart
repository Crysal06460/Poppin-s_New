import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SubscriptionScreen extends StatelessWidget {
  final String structureType;

  const SubscriptionScreen({Key? key, required this.structureType})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ajout de logs pour déboguer
    print("📋 SubscriptionScreen reçoit structureType: '$structureType'");
    
    // Définition des tarifs avec noms bien formatés
    Map<String, String> pricing = {
      'Assistante Maternelle': '10 € / mois',
      'Maison Assistante Maternelle': '20 € / mois',
      'Crèche': '50 € / mois',
    };

    // Correspondance entre les noms envoyés et ceux attendus
    Map<String, String> structureMapping = {
      'assistante_maternelle': 'Assistante Maternelle',
      'maison_assistante_maternelle': 'Maison Assistante Maternelle',
      'creche': 'Crèche',
    };

    // Vérification et normalisation du type de structure
    String normalizedStructure =
        structureMapping[structureType.trim()] ?? "Structure inconnue";
    String price = pricing[normalizedStructure] ?? 'Tarif indisponible';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Abonnement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B8FE5),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            Image.asset('assets/images/umbrella.png', height: 100),
            const SizedBox(height: 20),
            const Text(
              'Poppins',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              normalizedStructure,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Text(
              'Toutes les fonctionnalités pour les $normalizedStructure pour seulement',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              price,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '7 jours dessai gratuit puis abonnement mensuel, résiliation possible à tout moment.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // Correction: Passer le type de structure à l'écran de félicitations
                print("🚀 Naviguer vers /congratulations avec structureType: '$structureType'");
                context.go('/congratulations', extra: structureType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B8FE5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: const Padding(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    child: Text('Sabonner',
        style: TextStyle(fontSize: 18, color: Colors.white)),
  ),
),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
