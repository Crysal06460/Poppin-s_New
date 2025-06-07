// subscription_service.dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class SubscriptionService {
  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  // 🔧 BUNDLE ID CONFIGURÉ : com.beylet.poppinsApp
  static const String _bundleId = 'com.beylet.poppinsApp';

  // IDs des produits selon la plateforme
  static Map<String, String> get productIds {
    if (Platform.isIOS) {
      // IDs App Store Connect (iOS) avec votre Bundle ID
      return {
        'assistante_maternelle':
            '$_bundleId.subscription.assistante_maternelle',
        'mam_2_members': '$_bundleId.subscription.mam_2_members',
        'mam_3_members': '$_bundleId.subscription.mam_3_members',
        'mam_4_members': '$_bundleId.subscription.mam_4_members',
      };
    } else {
      // IDs Google Play Console (Android)
      return {
        'assistante_maternelle': 'assmat',
        'mam_2_members': 'mam2',
        'mam_3_members': 'mam3',
        'mam_4_members': 'mam4',
      };
    }
  }

  static String getProductId(String structureType, int memberCount) {
    if (structureType == 'MAM') {
      return productIds['mam_${memberCount}_members'] ??
          productIds['mam_2_members']!;
    }
    return productIds['assistante_maternelle']!;
  }

  static Future<bool> purchaseSubscription(String productId) async {
    if (!_isProduction) {
      // En mode développement, simuler l'achat
      print('🧪 MODE DEV: Simulation achat de $productId');
      await Future.delayed(Duration(seconds: 2));
      return true;
    }

    try {
      final InAppPurchase inAppPurchase = InAppPurchase.instance;

      // Vérifier que les achats sont disponibles
      final bool isAvailable = await inAppPurchase.isAvailable();
      if (!isAvailable) {
        print('❌ Achats intégrés non disponibles');
        return false;
      }

      print(
          '🛒 Tentative d\'achat du produit: $productId sur ${Platform.isIOS ? 'iOS' : 'Android'}');

      // Récupérer les détails du produit
      final ProductDetailsResponse response =
          await inAppPurchase.queryProductDetails({productId});

      if (response.error != null) {
        print('❌ Erreur lors de la récupération du produit: ${response.error}');
        return false;
      }

      if (response.productDetails.isEmpty) {
        print('❌ Produit non trouvé: $productId');
        if (Platform.isIOS) {
          print(
              '💡 Vérifiez que le produit est bien configuré dans App Store Connect et qu\'il est approuvé');
        } else {
          print(
              '💡 Vérifiez que le produit est bien configuré dans Google Play Console et qu\'il est actif');
        }
        return false;
      }

      // Lancer l'achat
      final ProductDetails productDetails = response.productDetails.first;
      print(
          '✅ Produit trouvé: ${productDetails.title} - ${productDetails.price}');

      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: productDetails);

      // IMPORTANT: Pour les abonnements, utiliser buyNonConsumable au lieu de buyConsumable
      final bool success =
          await inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      return success;
    } catch (e) {
      print('❌ Erreur lors de l\'achat: $e');
      return false;
    }
  }

  static Future<void> handlePurchaseUpdates() async {
    if (!_isProduction) return;

    final InAppPurchase inAppPurchase = InAppPurchase.instance;

    // Écouter les mises à jour d'achat
    inAppPurchase.purchaseStream
        .listen((List<PurchaseDetails> purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    });
  }

  static void _handlePurchaseUpdates(
      List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Vérifier la validité de l'achat avec votre serveur backend
        _verifyPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print('❌ Erreur d\'achat: ${purchaseDetails.error}');
      }

      // Finaliser la transaction
      if (purchaseDetails.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    }
  }

  static Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: Vérifier l'achat avec votre serveur backend
    // Cette étape est cruciale pour la sécurité
    print('✅ Achat vérifié: ${purchaseDetails.productID}');
  }

  // Tester la récupération des produits avec plus de détails
  static Future<void> testProductRetrieval() async {
    try {
      final InAppPurchase inAppPurchase = InAppPurchase.instance;
      final bool isAvailable = await inAppPurchase.isAvailable();

      print('📱 Plateforme: ${Platform.isIOS ? 'iOS' : 'Android'}');
      print('🔧 Bundle ID configuré: $_bundleId');
      print('🛒 Achats disponibles: $isAvailable');

      if (!isAvailable) {
        print('❌ Les achats intégrés ne sont pas disponibles sur cet appareil');
        if (Platform.isIOS) {
          print('💡 Sur iOS Simulator, les achats ne sont pas disponibles');
          print('💡 Testez sur un vrai appareil iOS');
        }
        return;
      }

      final Set<String> allProductIds = productIds.values.toSet();
      print('🔍 Recherche des produits: $allProductIds');

      final ProductDetailsResponse response =
          await inAppPurchase.queryProductDetails(allProductIds);

      print('✅ Produits trouvés: ${response.productDetails.length}');
      for (var product in response.productDetails) {
        print('  - ${product.id}: ${product.title} (${product.price})');
      }

      if (response.notFoundIDs.isNotEmpty) {
        print('❌ Produits non trouvés: ${response.notFoundIDs}');
        if (Platform.isIOS) {
          print('💡 Actions requises dans App Store Connect :');
          print('   1. Vérifiez que le Bundle ID ($_bundleId) est correct');
          print(
              '   2. Créez les produits avec les IDs exacts : ${response.notFoundIDs}');
          print('   3. Configurez-les comme "Auto-Renewable Subscriptions"');
          print('   4. Soumettez-les pour approbation');
          print('   5. Attendez l\'approbation (peut prendre 24-48h)');
          print('   6. Testez avec un compte Sandbox configuré');
        } else {
          print(
              '💡 Vérifiez que ces produits sont bien configurés et actifs dans Google Play Console');
        }
      }

      if (response.error != null) {
        print('❌ Erreur: ${response.error}');
      }
    } catch (e) {
      print('❌ Erreur test produits: $e');
    }
  }

  // Initialiser le service et tester
  static Future<void> initialize() async {
    print('🚀 Initialisation SubscriptionService...');

    // Vérifier l'environnement
    if (!_isProduction) {
      print('🧪 Mode développement détecté - simulation des achats activée');
    }

    // Initialiser les listeners
    await handlePurchaseUpdates();

    // Tester la récupération des produits
    await testProductRetrieval();

    print('✅ SubscriptionService initialisé');
  }
}
