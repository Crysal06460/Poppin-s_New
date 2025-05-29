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
// Version téléphone - garde le design original
  Widget _buildPhoneContent(Color primaryColor, String displayName,
      String price, List<String> featuresList, bool isMam) {
    return Column(
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
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
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
                final String structureType =
                    widget.structureInfo['structureType'] ??
                        'assistante_maternelle';
                final String structureId =
                    widget.structureInfo['structureId'] ?? '';

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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer les informations de la structure
    final String structureType =
        widget.structureInfo['structureType'] ?? 'assistante_maternelle';
    final String structureId = widget.structureInfo['structureId'] ?? '';
    final bool isMam = structureType == 'MAM';

    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;

    // Déterminer si on est sur iPad
    final bool isTablet = screenSize.shortestSide >= 600;

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
        title: Text(
          "Abonnement",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 24 : 20,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: isTablet
          ? _buildTabletContent(
              primaryColor, displayName, price, featuresList, isMam, screenSize)
          : _buildPhoneContent(
              primaryColor, displayName, price, featuresList, isMam),
    );
  }
// AJOUTEZ CES MÉTHODES DANS VOTRE CLASSE _PricingScreenState

  Widget _buildTabletContent(Color primaryColor, String displayName,
      String price, List<String> featuresList, bool isMam, Size screenSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        // Calculer des dimensions en pourcentages
        final double sideMargin = maxWidth * 0.04; // 4% de marge sur les côtés
        final double topMargin = maxHeight * 0.03; // 3% de marge en haut

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              sideMargin, topMargin, sideMargin, maxHeight * 0.02),
          child: Column(
            children: [
              // Section principale avec disposition en rangée pour iPad
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Panneau gauche - Information sur l'abonnement
                  Expanded(
                    flex: 5,
                    child: Container(
                      margin: EdgeInsets.only(right: maxWidth * 0.025),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            primaryColor,
                            primaryColor.withOpacity(0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            offset: const Offset(0, 8),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(maxWidth * 0.04),
                        child: Column(
                          children: [
                            // Logo avec taille adaptative
                            Container(
                              width: maxWidth * 0.15,
                              height: maxWidth * 0.15,
                              padding: EdgeInsets.all(maxWidth * 0.025),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),

                            SizedBox(height: maxHeight * 0.03),

                            // Type de structure avec taille adaptative
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: maxWidth * 0.028,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: maxHeight * 0.02),

                            // Prix avec taille impressionnante sur iPad
                            Text(
                              price,
                              style: TextStyle(
                                fontSize: maxWidth * 0.042,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),

                            SizedBox(height: maxHeight * 0.025),

                            // Période d'essai
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: maxWidth * 0.025,
                                  vertical: maxHeight * 0.015),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                "7 jours d'essai gratuit",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: maxWidth * 0.018,
                                ),
                              ),
                            ),

                            // Sélecteur de membres MAM si applicable
                            if (isMam) ...[
                              SizedBox(height: maxHeight * 0.04),
                              _buildTabletMAMSelector(
                                  primaryColor, maxWidth, maxHeight),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Panneau droit - Fonctionnalités et informations
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        // Section des fonctionnalités
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                offset: const Offset(0, 4),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(maxWidth * 0.03),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Titre section caractéristiques
                                Row(
                                  children: [
                                    Icon(
                                      Icons.featured_play_list_outlined,
                                      color: primaryColor,
                                      size: maxWidth * 0.025,
                                    ),
                                    SizedBox(width: maxWidth * 0.01),
                                    Text(
                                      "Fonctionnalités incluses",
                                      style: TextStyle(
                                        fontSize: maxWidth * 0.024,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: maxHeight * 0.025),

                                // Grille de fonctionnalités pour iPad
                                _buildTabletFeaturesGrid(featuresList,
                                    primaryColor, maxWidth, maxHeight),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: maxHeight * 0.03),

                        // Informations supplémentaires
                        Container(
                          padding: EdgeInsets.all(maxWidth * 0.025),
                          decoration: BoxDecoration(
                            color: lightBlue,
                            borderRadius: BorderRadius.circular(18),
                            border:
                                Border.all(color: primaryBlue.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                offset: const Offset(0, 3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(maxWidth * 0.015),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  color: primaryBlue,
                                  size: maxWidth * 0.022,
                                ),
                              ),
                              SizedBox(width: maxWidth * 0.02),
                              Expanded(
                                child: Text(
                                  "Vous pouvez résilier votre abonnement à tout moment depuis les paramètres de votre compte.",
                                  style: TextStyle(
                                    fontSize: maxWidth * 0.016,
                                    height: 1.4,
                                    color: const Color(0xFF455A64),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: maxHeight * 0.04),

              // Bouton d'action adaptatif pour iPad
              _buildTabletActionButton(primaryColor, maxWidth, maxHeight),
            ],
          ),
        );
      },
    );
  }

  // Sélecteur MAM adapté pour tablette
  Widget _buildTabletMAMSelector(
      Color primaryColor, double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all(maxWidth * 0.025),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Nombre d'assistantes maternelles",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: maxWidth * 0.018,
              color: Colors.white,
            ),
          ),
          SizedBox(height: maxHeight * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 2; i <= 4; i++)
                _buildTabletMemberCountButton(
                  count: i,
                  isSelected: _mamMembersCount == i,
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
            ],
          ),
          SizedBox(height: maxHeight * 0.015),
          Text(
            "Le prix s'adapte au nombre de membres.",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: maxWidth * 0.014,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // Boutons de sélection membres adaptés pour tablette
  Widget _buildTabletMemberCountButton({
    required int count,
    required bool isSelected,
    required double maxWidth,
    required double maxHeight,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _mamMembersCount = count;
        });
      },
      child: Container(
        width: maxWidth * 0.08,
        padding: EdgeInsets.symmetric(vertical: maxHeight * 0.015),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              "$count",
              style: TextStyle(
                fontSize: maxWidth * 0.022,
                fontWeight: FontWeight.bold,
                color: isSelected ? primaryRed : Colors.white,
              ),
            ),
            SizedBox(height: maxHeight * 0.005),
            Text(
              "membres",
              style: TextStyle(
                fontSize: maxWidth * 0.012,
                color: isSelected ? primaryRed : Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Grille de fonctionnalités adaptée pour tablette
  Widget _buildTabletFeaturesGrid(List<String> featuresList, Color primaryColor,
      double maxWidth, double maxHeight) {
    // Diviser les fonctionnalités en colonnes pour une meilleure répartition
    final int itemsPerColumn = (featuresList.length / 2).ceil();
    final List<String> leftColumn = featuresList.take(itemsPerColumn).toList();
    final List<String> rightColumn = featuresList.skip(itemsPerColumn).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonne gauche
        Expanded(
          child: Column(
            children: leftColumn
                .map((feature) => _buildTabletFeatureItem(
                    feature, primaryColor, maxWidth, maxHeight))
                .toList(),
          ),
        ),
        SizedBox(width: maxWidth * 0.03),
        // Colonne droite
        Expanded(
          child: Column(
            children: rightColumn
                .map((feature) => _buildTabletFeatureItem(
                    feature, primaryColor, maxWidth, maxHeight))
                .toList(),
          ),
        ),
      ],
    );
  }

  // Item de fonctionnalité adapté pour tablette
  Widget _buildTabletFeatureItem(
      String feature, Color primaryColor, double maxWidth, double maxHeight) {
    return Padding(
      padding: EdgeInsets.only(bottom: maxHeight * 0.02),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(maxWidth * 0.008),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: primaryColor,
              size: maxWidth * 0.018,
            ),
          ),
          SizedBox(width: maxWidth * 0.015),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                fontSize: maxWidth * 0.016,
                height: 1.4,
                color: const Color(0xFF455A64),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bouton d'action adapté pour tablette
  Widget _buildTabletActionButton(
      Color primaryColor, double maxWidth, double maxHeight) {
    return Container(
      width: maxWidth * 0.4, // 40% de la largeur de l'écran
      height: maxHeight * 0.08, // 8% de la hauteur de l'écran
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          final String structureType =
              widget.structureInfo['structureType'] ?? 'assistante_maternelle';
          final String structureId = widget.structureInfo['structureId'] ?? '';
          final bool isMam = structureType == 'MAM';

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
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          "S'ABONNER",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: maxWidth * 0.02,
            letterSpacing: 1.1,
          ),
        ),
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
