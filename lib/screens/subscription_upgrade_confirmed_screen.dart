import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppins_app/screens/mam_member_add_screen.dart'; // Ajout de l'importation manquante

class SubscriptionUpgradeConfirmedScreen extends StatelessWidget {
  final Map<String, dynamic> upgradeInfo;

  const SubscriptionUpgradeConfirmedScreen({
    Key? key,
    required this.upgradeInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Récupérer les informations de mise à niveau
    final String structureType = upgradeInfo['structureType'] ?? 'MAM';
    final int memberCount = upgradeInfo['memberCount'] ?? 3;
    final int oldMemberCount = upgradeInfo['oldMemberCount'] ?? 2;

    // Couleurs officielles de l'application
    const Color primaryRed = Color(0xFFD94350);
    const Color primaryBlue = Color(0xFF3D9DF2);
    const Color lightBlue = Color(0xFFDFE9F2);

    // Déterminer les prix
    String oldPrice;
    String newPrice;

    switch (oldMemberCount) {
      case 2:
        oldPrice = '22 € / mois';
        break;
      case 3:
        oldPrice = '32 € / mois';
        break;
      case 4:
        oldPrice = '40 € / mois';
        break;
      default:
        oldPrice = '22 € / mois';
    }

    switch (memberCount) {
      case 2:
        newPrice = '22 € / mois';
        break;
      case 3:
        newPrice = '32 € / mois';
        break;
      case 4:
        newPrice = '40 € / mois';
        break;
      default:
        newPrice = '40 € / mois';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mise à niveau réussie",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // En-tête avec icône de succès
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
              decoration: const BoxDecoration(
                color: primaryRed,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // Icône de succès
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: primaryRed,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Mise à niveau réussie !",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Contenu principal
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Récapitulatif de la mise à niveau
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Récapitulatif de la mise à niveau",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF455A64),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text(
                                      "Ancien forfait",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "$oldMemberCount membres",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      oldPrice,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward,
                                color: primaryRed,
                                size: 24,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text(
                                      "Nouveau forfait",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "$memberCount membres",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: primaryRed,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      newPrice,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: primaryRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: lightBlue.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.info_outline,
                                  color: primaryBlue,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Votre mise à niveau est désormais active. Vous pouvez maintenant ajouter davantage de membres à votre MAM.",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF455A64),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Informations sur les prochaines étapes
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Prochaines étapes",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF455A64),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildStepItem(
                            icon: Icons.people_outline,
                            title: "Ajouter vos membres",
                            description:
                                "Invitez vos collègues à rejoindre votre MAM.",
                            color: primaryRed,
                          ),
                          const SizedBox(height: 15),
                          _buildStepItem(
                            icon: Icons.check_circle_outline,
                            title: "Configuration terminée",
                            description:
                                "Votre mise à niveau est complète et immédiatement effective.",
                            color: primaryRed,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bouton d'action fixe en bas
            Container(
              padding:
                  const EdgeInsets.all(16), // Réduire légèrement le padding
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          context.go('/dashboard');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.grey.shade800,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8), // Réduire le padding horizontal
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "TABLEAU DE BORD",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize:
                                  13, // Réduire légèrement la taille de police
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // Réduire l'espacement
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MAMMemberAddScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8), // Réduire le padding horizontal
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "AJOUTER UN MEMBRE",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize:
                                  13, // Réduire légèrement la taille de police
                            ),
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
    );
  }

  Widget _buildStepItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF455A64),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
