import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // ✅ AJOUTÉ
import 'dart:async'; // ✅ AJOUTÉ
import '../services/subscription_service.dart';
import 'package:flutter/foundation.dart';

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

  // NOUVELLE MÉTHODE : Calculer le prix en euros (nombre uniquement)
  double _calculatePrice(bool isMam, int memberCount) {
    if (isMam) {
      switch (memberCount) {
        case 2:
          return 24.99;
        case 3:
          return 34.99;
        case 4:
          return 44.99;
        default:
          return 24.99;
      }
    } else {
      return 12.99;
    }
  }

  // MÉTHODE MODIFIÉE : Obtenir le prix formaté pour l'affichage
  String _getFormattedPrice(bool isMam, int memberCount) {
    double price = _calculatePrice(isMam, memberCount);
    // Enlever .toInt() pour garder les décimales
    if (price == price.roundToDouble()) {
      // Si le prix est un nombre entier (comme 32.0), afficher sans décimales
      return '${price.toInt()} € / mois';
    } else {
      // Si le prix a des décimales (comme 24.99), les afficher
      return '${price.toStringAsFixed(2)} € / mois';
    }
  }

  Widget _buildPhoneContent(Color primaryColor, String displayName,
      String price, List<String> featuresList, bool isMam) {
    return Column(
      children: [
        // En-tête moderne avec design sophistiqué
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.85),
                primaryColor.withOpacity(0.9),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(40),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                offset: const Offset(0, 10),
                blurRadius: 30,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Éléments décoratifs
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),

              // Contenu principal
              Column(
                children: [
                  const SizedBox(height: 20),

                  // Logo moderne
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/parapluie.png',
                        width: 70,
                        height: 70,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Type de structure
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Prix moderne
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.euro,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          price,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Badge essai gratuit moderne
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "7 jours d'essai gratuit",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Contenu principal moderne
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sélecteur MAM moderne
                if (isMam) ...[
                  _buildModernMAMSelectorPhone(primaryColor),
                  const SizedBox(height: 25),
                ],

                // Titre section moderne
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Pourquoi choisir Poppin's ?",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            "Fonctionnalités incluses",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // Grille moderne des fonctionnalités
                _buildModernPhoneFeaturesGrid(featuresList, primaryColor),

                const SizedBox(height: 25),

                // Info box moderne
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [lightBlue, lightBlue.withOpacity(0.5)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryBlue.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, 4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Résiliation possible à tout moment depuis l'AppStore (iOS) ou GooglePlay (Android)",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF455A64),
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

        // Bouton moderne
        _buildModernPhoneActionButton(primaryColor, isMam),
      ],
    );
  }

// Sélecteur MAM moderne pour téléphone
  Widget _buildModernMAMSelectorPhone(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lightBlue, lightBlue.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.group_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Nombre d'assistants maternels dans votre MAM",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF455A64),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 2; i <= 4; i++)
                _buildModernMemberButtonPhone(i, primaryColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Le prix de l'abonnement s'adapte au nombre de membres.",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

// Boutons membres modernes pour téléphone
  Widget _buildModernMemberButtonPhone(int count, Color primaryColor) {
    final bool isSelected = _mamMembersCount == count;
    return GestureDetector(
      onTap: () => setState(() => _mamMembersCount = count),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          children: [
            Text(
              "$count",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "membres",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white.withOpacity(0.9)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Grille moderne des fonctionnalités pour téléphone
  Widget _buildModernPhoneFeaturesGrid(
      List<String> featuresList, Color primaryColor) {
    // Icônes pour chaque fonctionnalité
    final List<IconData> icons = [
      Icons.access_time_rounded, // Transmissions temps réel
      Icons.chat_bubble_rounded, // Chat instantané
      Icons.campaign_rounded, // Actualités
      Icons.health_and_safety_rounded, // Santé
      Icons.dashboard_rounded, // Tableau de bord
      Icons.file_copy_rounded, // Dématérialisation
      Icons.school_rounded, // Professionnalisation
      Icons.child_care_rounded, // Suivi enfant
      Icons.favorite_rounded, // Amélioration relation
      Icons.verified_rounded, // Confiance
      Icons.group_rounded, // Gestion multi-membres
      Icons.share_rounded, // Tableau partagé
    ];

    return Column(
      children: featuresList.asMap().entries.map((entry) {
        final int index = entry.key;
        final String feature = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                offset: const Offset(0, 4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  index < icons.length
                      ? icons[index]
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  feature,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF455A64),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModernPhoneActionButton(Color primaryColor, bool isMam) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.4),
                offset: const Offset(0, 8),
                blurRadius: 25,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () async {
              final String structureType =
                  widget.structureInfo['structureType'] ??
                      'assistante_maternelle';
              final String structureId =
                  widget.structureInfo['structureId'] ?? '';

              final double priceAmount =
                  _calculatePrice(isMam, _mamMembersCount);
              final String priceDisplay =
                  _getFormattedPrice(isMam, _mamMembersCount);
              final String productId = SubscriptionService.getProductId(
                  structureType, _mamMembersCount);

              print('🛒 Tentative d\'achat du produit: $productId');

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text('Ouverture de l\'App Store...',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              );

              try {
                // ✅ NOUVEAU : Vérifier si on est en mode développement
                const bool isProduction =
                    bool.fromEnvironment('dart.vm.product');

                if (!isProduction) {
                  // ✅ MODE DEV : Utiliser la simulation fiable
                  try {
                    final subscriptionData =
                        await SubscriptionService.simulateDevPurchaseSuccess(
                            productId);

                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }

                    print(
                        '✅ DEV: Simulation réussie, redirection vers confirmation');

                    context.go('/subscription-confirmed', extra: {
                      'structureType': subscriptionData['structureType'],
                      'structureId': structureId,
                      'memberCount': subscriptionData['memberCount'],
                      'priceAmount': subscriptionData['priceAmount'],
                      'priceDisplay': subscriptionData['priceDisplay'],
                      'currency': subscriptionData['currency'],
                      'billingPeriod': subscriptionData['billingPeriod'],
                      'productId': subscriptionData['productId'],
                    });
                    return;
                  } catch (e) {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                    print('❌ DEV: Erreur simulation: $e');
                    _showErrorMessage('Erreur de simulation: ${e.toString()}');
                    return;
                  }
                }

                // ✅ MODE PRODUCTION : Logique normale avec les streams
                StreamSubscription<List<PurchaseDetails>>? purchaseSubscription;

                purchaseSubscription = InAppPurchase.instance.purchaseStream
                    .listen((purchaseDetailsList) {
                  for (PurchaseDetails purchase in purchaseDetailsList) {
                    print(
                        '📱 État achat: ${purchase.productID} - ${purchase.status}');

                    if (purchase.productID == productId) {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                      purchaseSubscription?.cancel();

                      if (purchase.status == PurchaseStatus.purchased) {
                        print('✅ Achat confirmé !');
                        context.go('/subscription-confirmed', extra: {
                          'structureType': structureType,
                          'structureId': structureId,
                          'memberCount': isMam ? _mamMembersCount : 1,
                          'priceAmount': priceAmount,
                          'priceDisplay': priceDisplay,
                          'currency': 'EUR',
                          'billingPeriod': 'monthly',
                          'productId': productId,
                        });
                      } else if (purchase.status == PurchaseStatus.error) {
                        print('❌ Erreur d\'achat: ${purchase.error}');
                        _showErrorMessage(
                            'Erreur lors de l\'achat: ${purchase.error?.message ?? "Erreur inconnue"}');
                      } else if (purchase.status == PurchaseStatus.canceled) {
                        print('⚠️ Achat annulé par l\'utilisateur');
                        _showErrorMessage('Achat annulé');
                      }

                      if (purchase.pendingCompletePurchase) {
                        InAppPurchase.instance.completePurchase(purchase);
                      }
                    }
                  }
                });

                await SubscriptionService.purchaseSubscription(productId);

                Timer(const Duration(seconds: 60), () {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  purchaseSubscription?.cancel();
                  _showErrorMessage('Timeout - Veuillez réessayer');
                });
              } catch (e) {
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
                print('❌ Erreur lors de l\'achat: $e');
                _showErrorMessage('Erreur lors de l\'achat: ${e.toString()}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.diamond_rounded,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  "S'ABONNER",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      'assistante_maternelle': 'Assistante Maternelle', // ✅ Bonne clé
      'MAM': 'Maison d\'Assistants Maternels',
    };

    // TARIFS MODIFIÉS : Utiliser la nouvelle méthode
    String price = _getFormattedPrice(isMam, _mamMembersCount);

    // Mapping des caractéristiques selon le type - REMPLACER la variable features existante
    Map<String, List<String>> features = {
      'assistante_maternelle': [
        'Transmissions en temps réel\n(pointage horaire, repas, sieste, soins, activités, ...)',
        'Chat instantané avec les parents\n(chat + partage de fichiers)',
        'Actualités\n(menu, sorties, évènements)',
        'Santé\n(PAI, allergies, ...)',
        'Tableau de bord\n(planning enfant, planning entretien, coordonnées parents, autorisations, droit à l\'image, ...)',
        'Dématérialisation des tâches',
        'Professionnalisation du métier d\'assistant maternel',
        'Suivi précis de l\'enfant',
        'Amélioration de la relation parent - équipe',
      ],
      'MAM': [
        'Transmissions en temps réel\n(pointage horaire, repas, sieste, soins, activités, ...)',
        'Chat instantané avec les parents\n(chat + partage de fichiers)',
        'Actualités\n(menu, sorties, évènements)',
        'Santé\n(PAI, allergies, ...)',
        'Tableau de bord\n(planning enfant, planning entretien, coordonnées parents, autorisations, droit à l\'image, ...)',
        'Dématérialisation des tâches',
        'Professionnalisation du métier d\'assistant maternel',
        'Suivi précis de l\'enfant',
        'Amélioration de la relation parent - équipe',
        'Gestion multi-membres',
        'Tableau de bord partagé',
      ],
    };

    // Obtenir le nom d'affichage et les caractéristiques
    String displayName = structureDisplayNames[structureType] ?? "";
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
        centerTitle: true,
        leading: Padding(
          padding: EdgeInsets.all(isTablet ? 12.0 : 8.0),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: isTablet ? 24 : 20,
              ),
            ),
          ),
        ),
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

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: maxWidth * 0.06,
            vertical: maxHeight * 0.04,
          ),
          child: Column(
            children: [
              // Section héro avec design moderne
              Container(
                height: maxHeight * 0.35, // ✅ RETOUR à la hauteur originale
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.8),
                      primaryColor.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4),
                      offset: const Offset(0, 20),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Éléments décoratifs
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),

                    // Contenu principal
                    Padding(
                      padding: EdgeInsets.all(maxWidth * 0.04),
                      child: Row(
                        children: [
                          // Partie gauche - Logo et infos
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Logo moderne
                                Container(
                                  width: maxWidth * 0.12,
                                  height: maxWidth * 0.12,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/parapluie.png',
                                      width: maxWidth * 0.08,
                                      height: maxWidth * 0.08,
                                    ),
                                  ),
                                ),

                                SizedBox(height: maxHeight * 0.03),

                                // Titre
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: maxWidth * 0.032,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),

                                SizedBox(height: maxHeight * 0.02),

                                // Prix avec design moderne
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: maxWidth * 0.025,
                                    vertical: maxHeight * 0.015,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.euro,
                                        color: Colors.white,
                                        size: maxWidth * 0.025,
                                      ),
                                      SizedBox(width: maxWidth * 0.01),
                                      Text(
                                        price,
                                        style: TextStyle(
                                          fontSize: maxWidth * 0.028,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Partie droite - Badge, bouton et sélecteur MAM
                          Expanded(
                            flex: 3,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min, // ✅ AJOUTÉ
                              children: [
                                // Badge essai gratuit
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: maxWidth * 0.03,
                                    vertical: maxHeight *
                                        0.015, // ✅ RÉDUIT de 0.02 à 0.015
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: primaryColor,
                                        size: maxWidth * 0.02,
                                      ),
                                      SizedBox(width: maxWidth * 0.01),
                                      Text(
                                        "7 jours d'essai gratuit",
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: maxWidth * 0.018,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ✅ NOUVEAU : Bouton S'abonner juste en dessous
                                SizedBox(
                                    height: maxHeight *
                                        0.015), // ✅ RÉDUIT de 0.02 à 0.015
                                // ✅ REMPLACER TOUT LE CONTAINER + GESTUREDETECTOR du bouton S'abonner dans _buildTabletContent
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: maxWidth * 0.03,
                                    vertical: maxHeight * 0.015,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: GestureDetector(
                                    onTap: () async {
                                      // ✅ LOGIQUE D'ACHAT COMPLÈTE CORRIGÉE
                                      final String structureType = widget
                                              .structureInfo['structureType'] ??
                                          'assistante_maternelle';
                                      final String structureId =
                                          widget.structureInfo['structureId'] ??
                                              '';

                                      final double priceAmount =
                                          _calculatePrice(
                                              isMam, _mamMembersCount);
                                      final String priceDisplay =
                                          _getFormattedPrice(
                                              isMam, _mamMembersCount);
                                      final String productId =
                                          SubscriptionService.getProductId(
                                              structureType, _mamMembersCount);

                                      print(
                                          '🛒 Tentative d\'achat du produit: $productId');

                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => AlertDialog(
                                          content: Row(
                                            children: [
                                              CircularProgressIndicator(
                                                  color: primaryColor),
                                              SizedBox(width: 16),
                                              Expanded(
                                                child: Text(
                                                    'Ouverture de l\'App Store...',
                                                    style: TextStyle(
                                                        fontSize: 16)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                      try {
                                        // ✅ NOUVEAU : Vérifier si on est en mode développement
                                        const bool isProduction =
                                            bool.fromEnvironment(
                                                'dart.vm.product');

                                        if (!isProduction) {
                                          // ✅ MODE DEV : Utiliser la simulation fiable
                                          try {
                                            final subscriptionData =
                                                await SubscriptionService
                                                    .simulateDevPurchaseSuccess(
                                                        productId);

                                            if (Navigator.canPop(context)) {
                                              Navigator.of(context).pop();
                                            }

                                            print(
                                                '✅ DEV: Simulation réussie, redirection vers confirmation');

                                            context.go(
                                                '/subscription-confirmed',
                                                extra: {
                                                  'structureType':
                                                      subscriptionData[
                                                          'structureType'],
                                                  'structureId': structureId,
                                                  'memberCount':
                                                      subscriptionData[
                                                          'memberCount'],
                                                  'priceAmount':
                                                      subscriptionData[
                                                          'priceAmount'],
                                                  'priceDisplay':
                                                      subscriptionData[
                                                          'priceDisplay'],
                                                  'currency': subscriptionData[
                                                      'currency'],
                                                  'billingPeriod':
                                                      subscriptionData[
                                                          'billingPeriod'],
                                                  'productId': subscriptionData[
                                                      'productId'],
                                                });
                                            return;
                                          } catch (e) {
                                            if (Navigator.canPop(context)) {
                                              Navigator.of(context).pop();
                                            }
                                            print(
                                                '❌ DEV: Erreur simulation: $e');
                                            _showErrorMessage(
                                                'Erreur de simulation: ${e.toString()}');
                                            return;
                                          }
                                        }

                                        // ✅ MODE PRODUCTION : Logique normale avec les streams
                                        StreamSubscription<
                                                List<PurchaseDetails>>?
                                            purchaseSubscription;

                                        purchaseSubscription = InAppPurchase
                                            .instance.purchaseStream
                                            .listen((purchaseDetailsList) {
                                          for (PurchaseDetails purchase
                                              in purchaseDetailsList) {
                                            print(
                                                '📱 État achat: ${purchase.productID} - ${purchase.status}');

                                            if (purchase.productID ==
                                                productId) {
                                              if (Navigator.canPop(context)) {
                                                Navigator.of(context).pop();
                                              }
                                              purchaseSubscription?.cancel();

                                              if (purchase.status ==
                                                  PurchaseStatus.purchased) {
                                                print('✅ Achat confirmé !');
                                                context.go(
                                                    '/subscription-confirmed',
                                                    extra: {
                                                      'structureType':
                                                          structureType,
                                                      'structureId':
                                                          structureId,
                                                      'memberCount': isMam
                                                          ? _mamMembersCount
                                                          : 1,
                                                      'priceAmount':
                                                          priceAmount,
                                                      'priceDisplay':
                                                          priceDisplay,
                                                      'currency': 'EUR',
                                                      'billingPeriod':
                                                          'monthly',
                                                      'productId': productId,
                                                    });
                                              } else if (purchase.status ==
                                                  PurchaseStatus.error) {
                                                print(
                                                    '❌ Erreur d\'achat: ${purchase.error}');
                                                _showErrorMessage(
                                                    'Erreur lors de l\'achat: ${purchase.error?.message ?? "Erreur inconnue"}');
                                              } else if (purchase.status ==
                                                  PurchaseStatus.canceled) {
                                                print(
                                                    '⚠️ Achat annulé par l\'utilisateur');
                                                _showErrorMessage(
                                                    'Achat annulé');
                                              }

                                              if (purchase
                                                  .pendingCompletePurchase) {
                                                InAppPurchase.instance
                                                    .completePurchase(purchase);
                                              }
                                            }
                                          }
                                        });

                                        await SubscriptionService
                                            .purchaseSubscription(productId);

                                        Timer(Duration(seconds: 60), () {
                                          if (Navigator.canPop(context)) {
                                            Navigator.of(context).pop();
                                          }
                                          purchaseSubscription?.cancel();
                                          _showErrorMessage(
                                              'Timeout - Veuillez réessayer');
                                        });
                                      } catch (e) {
                                        if (Navigator.canPop(context)) {
                                          Navigator.of(context).pop();
                                        }
                                        print('❌ Erreur lors de l\'achat: $e');
                                        _showErrorMessage(
                                            'Erreur lors de l\'achat: ${e.toString()}');
                                      }
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.diamond_rounded,
                                          color: primaryColor,
                                          size: maxWidth * 0.02,
                                        ),
                                        SizedBox(width: maxWidth * 0.01),
                                        Text(
                                          "S'ABONNER",
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: maxWidth * 0.018,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Sélecteur MAM moderne si applicable
                                if (isMam) ...[
                                  SizedBox(
                                      height: maxHeight *
                                          0.015), // ✅ RÉDUIT de 0.025 à 0.015
                                  _buildModernMAMSelector(
                                      primaryColor, maxWidth, maxHeight),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: maxHeight * 0.05),

              // Section fonctionnalités moderne
              _buildModernFeaturesSection(
                  featuresList, primaryColor, maxWidth, maxHeight),
            ],
          ),
        );
      },
    );
  }

// ✅ NOUVEAU : Bouton héro en blanc
  Widget _buildModernHeroButton(
      Color primaryColor, double maxWidth, double maxHeight, bool isMam) {
    return Container(
      width: maxWidth * 0.4,
      height: maxHeight * 0.07,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 8),
            blurRadius: 25,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          final String structureType =
              widget.structureInfo['structureType'] ?? 'assistante_maternelle';
          final String structureId = widget.structureInfo['structureId'] ?? '';

          final double priceAmount = _calculatePrice(isMam, _mamMembersCount);
          final String priceDisplay =
              _getFormattedPrice(isMam, _mamMembersCount);
          final String productId =
              SubscriptionService.getProductId(structureType, _mamMembersCount);

          print('🛒 Tentative d\'achat du produit: $productId');

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text('Ouverture de l\'App Store...',
                        style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          );

          try {
            // ✅ NOUVEAU : Vérifier si on est en mode développement
            const bool isProduction = bool.fromEnvironment('dart.vm.product');

            if (!isProduction) {
              // ✅ MODE DEV : Utiliser la simulation fiable
              try {
                final subscriptionData =
                    await SubscriptionService.simulateDevPurchaseSuccess(
                        productId);

                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }

                print(
                    '✅ DEV: Simulation réussie, redirection vers confirmation');

                context.go('/subscription-confirmed', extra: {
                  'structureType': subscriptionData['structureType'],
                  'structureId': structureId,
                  'memberCount': subscriptionData['memberCount'],
                  'priceAmount': subscriptionData['priceAmount'],
                  'priceDisplay': subscriptionData['priceDisplay'],
                  'currency': subscriptionData['currency'],
                  'billingPeriod': subscriptionData['billingPeriod'],
                  'productId': subscriptionData['productId'],
                });
                return;
              } catch (e) {
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
                print('❌ DEV: Erreur simulation: $e');
                _showErrorMessage('Erreur de simulation: ${e.toString()}');
                return;
              }
            }

            // ✅ MODE PRODUCTION : Logique normale avec les streams
            StreamSubscription<List<PurchaseDetails>>? purchaseSubscription;

            purchaseSubscription = InAppPurchase.instance.purchaseStream
                .listen((purchaseDetailsList) {
              for (PurchaseDetails purchase in purchaseDetailsList) {
                print(
                    '📱 État achat: ${purchase.productID} - ${purchase.status}');

                if (purchase.productID == productId) {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  purchaseSubscription?.cancel();

                  if (purchase.status == PurchaseStatus.purchased) {
                    print('✅ Achat confirmé !');
                    context.go('/subscription-confirmed', extra: {
                      'structureType': structureType,
                      'structureId': structureId,
                      'memberCount': isMam ? _mamMembersCount : 1,
                      'priceAmount': priceAmount,
                      'priceDisplay': priceDisplay,
                      'currency': 'EUR',
                      'billingPeriod': 'monthly',
                      'productId': productId,
                    });
                  } else if (purchase.status == PurchaseStatus.error) {
                    print('❌ Erreur d\'achat: ${purchase.error}');
                    _showErrorMessage(
                        'Erreur lors de l\'achat: ${purchase.error?.message ?? "Erreur inconnue"}');
                  } else if (purchase.status == PurchaseStatus.canceled) {
                    print('⚠️ Achat annulé par l\'utilisateur');
                    _showErrorMessage('Achat annulé');
                  }

                  if (purchase.pendingCompletePurchase) {
                    InAppPurchase.instance.completePurchase(purchase);
                  }
                }
              }
            });

            await SubscriptionService.purchaseSubscription(productId);

            Timer(Duration(seconds: 60), () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              purchaseSubscription?.cancel();
              _showErrorMessage('Timeout - Veuillez réessayer');
            });
          } catch (e) {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            print('❌ Erreur lors de l\'achat: $e');
            _showErrorMessage('Erreur lors de l\'achat: ${e.toString()}');
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.diamond_rounded,
              size: maxWidth * 0.02,
              color: primaryColor,
            ),
            SizedBox(width: maxWidth * 0.01),
            Text(
              "S'ABONNER MAINTENANT",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: maxWidth * 0.018,
                letterSpacing: 1.2,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Sélecteur MAM moderne
  // Sélecteur MAM moderne
  Widget _buildModernMAMSelector(
      Color primaryColor, double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all(maxWidth * 0.015), // ✅ RÉDUIT de 0.02 à 0.015
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16), // ✅ RÉDUIT de 20 à 16
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            "Nombre d'assistants maternels",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: maxWidth * 0.014, // ✅ RÉDUIT de 0.016 à 0.014
              color: Colors.white,
            ),
          ),
          SizedBox(height: maxHeight * 0.01), // ✅ RÉDUIT de 0.015 à 0.01
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 2; i <= 4; i++)
                _buildModernMemberButton(i, maxWidth, maxHeight),
            ],
          ),
        ],
      ),
    );
  }

// Boutons membres modernes
  // Boutons membres modernes
  Widget _buildModernMemberButton(
      int count, double maxWidth, double maxHeight) {
    final bool isSelected = _mamMembersCount == count;
    return GestureDetector(
      onTap: () => setState(() => _mamMembersCount = count),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: maxWidth * 0.05, // ✅ RÉDUIT de 0.06 à 0.05
        height: maxWidth * 0.05, // ✅ RÉDUIT de 0.06 à 0.05
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12), // ✅ RÉDUIT de 16 à 12
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8, // ✅ RÉDUIT de 10 à 8
                    offset: const Offset(0, 3), // ✅ RÉDUIT de 4 à 3
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            "$count",
            style: TextStyle(
              fontSize: maxWidth * 0.018, // ✅ RÉDUIT de 0.02 à 0.018
              fontWeight: FontWeight.bold,
              color: isSelected ? primaryRed : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

// Section fonctionnalités moderne
  Widget _buildModernFeaturesSection(List<String> featuresList,
      Color primaryColor, double maxWidth, double maxHeight) {
    return Column(
      children: [
        // Titre moderne
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(maxWidth * 0.015),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: maxWidth * 0.025,
              ),
            ),
            SizedBox(width: maxWidth * 0.02),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pourquoi choisir Poppin's ?",
                    style: TextStyle(
                      fontSize: maxWidth * 0.028,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    "Fonctionnalités incluses",
                    style: TextStyle(
                      fontSize: maxWidth * 0.018,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: maxHeight * 0.04),

        // Grille moderne des fonctionnalités
        _buildModernFeaturesGrid(
            featuresList, primaryColor, maxWidth, maxHeight),

        SizedBox(height: maxHeight * 0.04),

        // Info box moderne
        Container(
          padding: EdgeInsets.all(maxWidth * 0.03),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightBlue, lightBlue.withOpacity(0.5)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryBlue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(maxWidth * 0.015),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: primaryBlue,
                  size: maxWidth * 0.022,
                ),
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: Text(
                  "Résiliation possible à tout moment depuis l'AppStore (iOS) ou GooglePlay (Android)",
                  style: TextStyle(
                    fontSize: maxWidth * 0.016,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF455A64),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// Grille moderne des fonctionnalités
  Widget _buildModernFeaturesGrid(List<String> featuresList, Color primaryColor,
      double maxWidth, double maxHeight) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: maxWidth * 0.02,
        mainAxisSpacing: maxHeight * 0.02,
        childAspectRatio: 2.5,
      ),
      itemCount: featuresList.length,
      itemBuilder: (context, index) {
        return _buildModernFeatureCard(
            featuresList[index], primaryColor, maxWidth, maxHeight, index);
      },
    );
  }

// Carte fonctionnalité moderne
  Widget _buildModernFeatureCard(String feature, Color primaryColor,
      double maxWidth, double maxHeight, int index) {
    // Icônes pour chaque fonctionnalité
    final List<IconData> icons = [
      Icons.access_time_rounded, // Transmissions temps réel
      Icons.chat_bubble_rounded, // Chat instantané
      Icons.campaign_rounded, // Actualités
      Icons.health_and_safety_rounded, // Santé
      Icons.dashboard_rounded, // Tableau de bord
      Icons.file_copy_rounded, // Dématérialisation
      Icons.school_rounded, // Professionnalisation
      Icons.child_care_rounded, // Suivi enfant
      Icons.favorite_rounded, // Amélioration relation
      Icons.verified_rounded, // Confiance
      Icons.group_rounded, // Gestion multi-membres
      Icons.share_rounded, // Tableau partagé
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(maxWidth * 0.02),
        child: Row(
          children: [
            Container(
              width: maxWidth * 0.025,
              height: maxWidth * 0.025,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                index < icons.length
                    ? icons[index]
                    : Icons.check_circle_rounded,
                color: Colors.white,
                size: maxWidth * 0.015,
              ),
            ),
            SizedBox(width: maxWidth * 0.015),
            Expanded(
              child: Text(
                feature,
                style: TextStyle(
                  fontSize: maxWidth * 0.014,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF455A64),
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Bouton d'action moderne
  Widget _buildModernActionButton(
      Color primaryColor, double maxWidth, double maxHeight, bool isMam) {
    return Container(
      width: maxWidth * 0.5,
      height: maxHeight * 0.08,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            offset: const Offset(0, 8),
            blurRadius: 25,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          // Même logique d'achat que before...
          // [Copier le code onPressed existant]
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.diamond_rounded,
              size: maxWidth * 0.02,
            ),
            SizedBox(width: maxWidth * 0.01),
            Text(
              "S'ABONNER MAINTENANT",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: maxWidth * 0.018,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
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
            "Nombre d'assistants maternels",
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

  Widget _buildTabletActionButton(
      Color primaryColor, double maxWidth, double maxHeight, bool isMam) {
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
        onPressed: () async {
          final String structureType =
              widget.structureInfo['structureType'] ?? 'assistante_maternelle';
          final String structureId = widget.structureInfo['structureId'] ?? '';

          final double priceAmount = _calculatePrice(isMam, _mamMembersCount);
          final String priceDisplay =
              _getFormattedPrice(isMam, _mamMembersCount);
          final String productId =
              SubscriptionService.getProductId(structureType, _mamMembersCount);

          print('🛒 Tentative d\'achat du produit: $productId');

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text('Ouverture de l\'App Store...',
                        style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          );

          try {
            // ✅ NOUVEAU : Vérifier si on est en mode développement
            const bool isProduction = bool.fromEnvironment('dart.vm.product');

            if (!isProduction) {
              // ✅ MODE DEV : Utiliser la simulation fiable
              try {
                final subscriptionData =
                    await SubscriptionService.simulateDevPurchaseSuccess(
                        productId);

                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }

                print(
                    '✅ DEV: Simulation réussie, redirection vers confirmation');

                context.go('/subscription-confirmed', extra: {
                  'structureType': subscriptionData['structureType'],
                  'structureId': structureId,
                  'memberCount': subscriptionData['memberCount'],
                  'priceAmount': subscriptionData['priceAmount'],
                  'priceDisplay': subscriptionData['priceDisplay'],
                  'currency': subscriptionData['currency'],
                  'billingPeriod': subscriptionData['billingPeriod'],
                  'productId': subscriptionData['productId'],
                });
                return;
              } catch (e) {
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
                print('❌ DEV: Erreur simulation: $e');
                _showErrorMessage('Erreur de simulation: ${e.toString()}');
                return;
              }
            }

            // ✅ MODE PRODUCTION : Logique normale avec les streams
            StreamSubscription<List<PurchaseDetails>>? purchaseSubscription;

            purchaseSubscription = InAppPurchase.instance.purchaseStream
                .listen((purchaseDetailsList) {
              for (PurchaseDetails purchase in purchaseDetailsList) {
                print(
                    '📱 État achat: ${purchase.productID} - ${purchase.status}');

                if (purchase.productID == productId) {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  purchaseSubscription?.cancel();

                  if (purchase.status == PurchaseStatus.purchased) {
                    print('✅ Achat confirmé !');
                    context.go('/subscription-confirmed', extra: {
                      'structureType': structureType,
                      'structureId': structureId,
                      'memberCount': isMam ? _mamMembersCount : 1,
                      'priceAmount': priceAmount,
                      'priceDisplay': priceDisplay,
                      'currency': 'EUR',
                      'billingPeriod': 'monthly',
                      'productId': productId,
                    });
                  } else if (purchase.status == PurchaseStatus.error) {
                    print('❌ Erreur d\'achat: ${purchase.error}');
                    _showErrorMessage(
                        'Erreur lors de l\'achat: ${purchase.error?.message ?? "Erreur inconnue"}');
                  } else if (purchase.status == PurchaseStatus.canceled) {
                    print('⚠️ Achat annulé par l\'utilisateur');
                    _showErrorMessage('Achat annulé');
                  }

                  if (purchase.pendingCompletePurchase) {
                    InAppPurchase.instance.completePurchase(purchase);
                  }
                }
              }
            });

            await SubscriptionService.purchaseSubscription(productId);

            Timer(Duration(seconds: 60), () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              purchaseSubscription?.cancel();
              _showErrorMessage('Timeout - Veuillez réessayer');
            });
          } catch (e) {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
            print('❌ Erreur lors de l\'achat: $e');
            _showErrorMessage('Erreur lors de l\'achat: ${e.toString()}');
          }
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

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }
}
