import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PricingScreen extends StatefulWidget {
  final Map<String, dynamic> structureInfo;

  const PricingScreen({
    Key? key,
    required this.structureInfo,
  }) : super(key: key);

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color lightBlue = Color(0xFFDFE9F2);
  static const Color brightCyan = Color(0xFF05C7F2);
  static const Color primaryYellow = Color(0xFFF2B705);

  // Nombre de membres MAM (valeur par défaut)
  int _mamMembersCount = 2;

  @override
  Widget build(BuildContext context) {
    // Récupérer les informations de la structure
    final String structureType =
        widget.structureInfo['structureType'] ?? 'assistante_maternelle';
    final String structureId = widget.structureInfo['structureId'] ?? '';
    final bool isMam = structureType == 'MAM';

    // Mapping des types techniques vers les noms d'affichage
    Map<String, String> structureDisplayNames = {
      'AssistanteMaternelle': 'Assistante Maternelle',
      'MAM': 'Maison d\'Assistantes Maternelles',
    };

    // Tarifs selon le type de structure
    String price;
    if (isMam) {
      // Prix selon le nombre de membres pour une MAM
      switch (_mamMembersCount) {
        case 2:
          price = '22 € / mois';
          break;
        case 3:
          price = '32 € / mois';
          break;
        case 4:
          price = '40 € / mois';
          break;
        default:
          price = '22 € / mois';
      }
    } else {
      // Prix fixe pour une assistante maternelle
      price = '12 € / mois';
    }

    // Mapping des caractéristiques selon le type
    Map<String, List<String>> features = {
      'AssistanteMaternelle': [
        'Gestion des enfants',
        'Suivi des activités',
        'Journal quotidien',
        'Gestion des présences',
        'Communication avec les parents',
      ],
      'MAM': [
        'Gestion des enfants',
        'Suivi des activités',
        'Journal quotidien',
        'Gestion des présences',
        'Communication avec les parents',
        'Gestion multi-membres',
        'Tableau de bord partagé',
      ],
    };

    // Obtenir le nom d'affichage et les caractéristiques
    String displayName =
        structureDisplayNames[structureType] ?? "Structure inconnue";
    List<String> featuresList = features[structureType] ?? [];

    // Couleur principale en fonction du type de structure
    Color primaryColor = isMam ? primaryRed : primaryBlue;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Abonnement",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // En-tête avec couleur selon le type de structure
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  padding: const EdgeInsets.all(15),
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
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 70,
                  ),
                ),

                const SizedBox(height: 15),

                // Type de structure
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 5),

                // Prix
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 5),

                // Période d'essai
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "7 jours d'essai gratuit",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenu principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sélecteur du nombre de membres pour les MAM
                  if (isMam) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Nombre d'assistantes maternelles dans votre MAM",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF455A64),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (int i = 2; i <= 4; i++)
                                _buildMemberCountButton(
                                  count: i,
                                  isSelected: _mamMembersCount == i,
                                  color: primaryColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Le prix de l'abonnement s'adapte au nombre de membres.",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              color: Color(0xFF455A64),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Titre section caractéristiques
                  Text(
                    "Fonctionnalités incluses",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Liste des caractéristiques
                  ...featuresList.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: primaryColor,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),

                  const SizedBox(height: 20),

                  // Informations supplémentaires
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lightBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: primaryBlue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Vous pouvez résilier votre abonnement à tout moment depuis les paramètres de votre compte.",
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
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

          // Bouton d'action fixe en bas
          Container(
            padding: const EdgeInsets.all(20),
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
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  // Rediriger vers la page de confirmation d'abonnement
                  context.go('/subscription-confirmed', extra: {
                    'structureType': structureType,
                    'structureId': structureId,
                    'memberCount': isMam ? _mamMembersCount : 1,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "S'ABONNER",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour les boutons de sélection du nombre de membres
  Widget _buildMemberCountButton({
    required int count,
    required bool isSelected,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _mamMembersCount = count;
        });
      },
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              "$count",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "membres",
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
