// subscription_service.dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';

class SubscriptionService {
  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  // IDs des produits d'abonnement (basés sur vos IDs App Store Connect)
  static const Map<String, String> productIds = {
    'assistante_maternelle': '01',
    'mam_2_members': '02',
    'mam_3_members': '03',
    'mam_4_members': '04',
  };

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

      // Récupérer les détails du produit
      final ProductDetailsResponse response =
          await inAppPurchase.queryProductDetails({productId});

      if (response.error != null) {
        print('❌ Erreur lors de la récupération du produit: ${response.error}');
        return false;
      }

      if (response.productDetails.isEmpty) {
        print('❌ Produit non trouvé: $productId');
        return false;
      }

      // Lancer l'achat
      final ProductDetails productDetails = response.productDetails.first;
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
}
