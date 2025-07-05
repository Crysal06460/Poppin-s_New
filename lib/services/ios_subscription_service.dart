// ios_subscription_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';

class iOSNativeSubscriptionService {
  static const MethodChannel _channel = MethodChannel('ios_subscription');

  // Configuration des produits
  static const String bundleId = 'com.beylet.poppinsApp';
  static const Map<String, String> productIds = {
    'assistante_maternelle':
        'com.beylet.poppinsApp.subscription.assistante_maternelle',
    'mam_2_members': 'com.beylet.poppinsApp.subscription.mam_2_members',
    'mam_3_members': 'com.beylet.poppinsApp.subscription.mam_3_members',
    'mam_4_members': 'com.beylet.poppinsApp.subscription.mam_4_members',
  };

  // Stream controller pour les événements d'achat
  static final StreamController<Map<String, dynamic>> _purchaseController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get purchaseStream =>
      _purchaseController.stream;

  static bool _isInitialized = false;
  static bool get isInDevMode => kDebugMode;

  /// Initialiser le service avec l'API native iOS
  static Future<void> initialize() async {
    if (_isInitialized) return;

    print('🍎 Initialisation du service d\'abonnement iOS natif...');

    try {
      // Configurer le listener pour les callbacks natifs
      _channel.setMethodCallHandler(_handleNativeCallback);

      if (Platform.isIOS && !isInDevMode) {
        // Initialiser StoreKit natif
        final result = await _channel.invokeMethod('initialize', {
          'productIds': productIds.values.toList(),
          'bundleId': bundleId,
        });

        print('✅ StoreKit initialisé: $result');
      } else {
        print('🧪 Mode développement - simulation activée');
      }

      _isInitialized = true;
      print('✅ Service d\'abonnement iOS initialisé avec succès');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation: $e');
      // En cas d'erreur, on peut continuer en mode simulation
      _isInitialized = true;
    }
  }

  /// Gérer les callbacks depuis le code natif iOS
  static Future<void> _handleNativeCallback(MethodCall call) async {
    print('📱 Callback natif reçu: ${call.method}');

    switch (call.method) {
      case 'onPurchaseSuccess':
        await _handlePurchaseSuccess(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onPurchaseError':
        await _handlePurchaseError(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onPurchaseCanceled':
        await _handlePurchaseCanceled();
        break;
      case 'onRestoreComplete':
        await _handleRestoreComplete(
            List<Map<String, dynamic>>.from(call.arguments));
        break;
      default:
        print('⚠️ Callback non géré: ${call.method}');
    }
  }

  /// Lancer un achat d'abonnement
  static Future<void> purchaseSubscription(String productKey) async {
    if (!_isInitialized) {
      throw Exception('Service non initialisé. Appelez initialize() d\'abord.');
    }

    final productId = productIds[productKey];
    if (productId == null) {
      throw Exception('Produit non trouvé: $productKey');
    }

    print('🛒 Lancement achat: $productKey ($productId)');

    if (isInDevMode) {
      // Simulation en mode développement
      await _simulatePurchaseSuccess(productKey);
      return;
    }

    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('purchaseProduct', {
          'productId': productId,
        });
      } else {
        throw Exception('Service iOS uniquement');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'achat: $e');
      _purchaseController.add({
        'type': 'error',
        'message': e.toString(),
      });
      rethrow;
    }
  }

  /// Restaurer les achats précédents
  static Future<void> restorePurchases() async {
    if (!_isInitialized) {
      throw Exception('Service non initialisé');
    }

    print('🔄 Restauration des achats...');

    if (isInDevMode) {
      _purchaseController.add({
        'type': 'restore_complete',
        'purchases': [],
      });
      return;
    }

    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('restorePurchases');
      }
    } catch (e) {
      print('❌ Erreur lors de la restauration: $e');
      rethrow;
    }
  }

  /// Vérifier le statut d'abonnement actuel
  static Future<Map<String, dynamic>?> checkSubscriptionStatus() async {
    if (!_isInitialized) {
      await initialize();
    }

    print('🔍 Vérification du statut d\'abonnement...');

    if (isInDevMode) {
      return {
        'isActive': true,
        'productId': 'dev_subscription',
        'expirationDate':
            DateTime.now().add(Duration(days: 7)).toIso8601String(),
      };
    }

    try {
      if (Platform.isIOS) {
        final result = await _channel.invokeMethod('checkSubscriptionStatus');
        return Map<String, dynamic>.from(result ?? {});
      }
      return null;
    } catch (e) {
      print('❌ Erreur vérification statut: $e');
      return null;
    }
  }

  /// Obtenir les informations des produits
  static Future<List<Map<String, dynamic>>> getProductsInfo() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (isInDevMode) {
      return [
        {
          'productId': 'subscription_assistante_maternelle',
          'title': 'Abonnement Assistant Maternel',
          'price': '12,99 €',
          'description': 'Abonnement mensuel pour assistants maternels',
        },
        {
          'productId': 'subscription_mam_2_members',
          'title': 'Abonnement MAM 2 membres',
          'price': '24,99 €',
          'description': 'Abonnement mensuel MAM pour 2 membres',
        },
      ];
    }

    try {
      if (Platform.isIOS) {
        final result = await _channel.invokeMethod('getProductsInfo');
        return List<Map<String, dynamic>>.from(result ?? []);
      }
      return [];
    } catch (e) {
      print('❌ Erreur récupération produits: $e');
      return [];
    }
  }

  /// Simulation d'achat réussi (mode dev)
  static Future<void> _simulatePurchaseSuccess(String productKey) async {
    print('🧪 Simulation achat réussi: $productKey');

    await Future.delayed(Duration(seconds: 2));

    final Map<String, dynamic> purchaseData = {
      'productId': productIds[productKey],
      'transactionId': 'dev_${DateTime.now().millisecondsSinceEpoch}',
      'purchaseDate': DateTime.now().toIso8601String(),
      'expirationDate':
          DateTime.now().add(Duration(days: 30)).toIso8601String(),
    };

    await _handlePurchaseSuccess(purchaseData);
  }

  /// Gérer un achat réussi
  static Future<void> _handlePurchaseSuccess(
      Map<String, dynamic> purchaseData) async {
    print('✅ Achat réussi: ${purchaseData['productId']}');

    try {
      // Sauvegarder dans Firestore
      await _saveSubscriptionToFirestore(purchaseData);

      // Notifier l'interface
      _purchaseController.add({
        'type': 'purchase_success',
        'data': purchaseData,
      });
    } catch (e) {
      print('❌ Erreur sauvegarde achat: $e');
    }
  }

  /// Gérer une erreur d'achat
  static Future<void> _handlePurchaseError(
      Map<String, dynamic> errorData) async {
    print('❌ Erreur d\'achat: ${errorData['message']}');

    _purchaseController.add({
      'type': 'purchase_error',
      'message': errorData['message'] ?? 'Erreur inconnue',
      'code': errorData['code'],
    });
  }

  /// Gérer l'annulation d'achat
  static Future<void> _handlePurchaseCanceled() async {
    print('⚠️ Achat annulé par l\'utilisateur');

    _purchaseController.add({
      'type': 'purchase_canceled',
    });
  }

  /// Gérer la restauration terminée
  static Future<void> _handleRestoreComplete(
      List<Map<String, dynamic>> purchases) async {
    print('🔄 Restauration terminée: ${purchases.length} achats trouvés');

    for (var purchase in purchases) {
      await _saveSubscriptionToFirestore(purchase);
    }

    _purchaseController.add({
      'type': 'restore_complete',
      'purchases': purchases,
    });
  }

  /// Sauvegarder l'abonnement dans Firestore
  static Future<void> _saveSubscriptionToFirestore(
      Map<String, dynamic> purchaseData) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String productId = purchaseData['productId'] ?? '';

      // Déterminer le type de structure et nombre de membres
      String structureType = 'assistante_maternelle';
      int memberCount = 1;
      double priceAmount = 12.99;
      String priceDisplay = '12,99 € / mois';

      if (productId.contains('mam')) {
        structureType = 'MAM';
        if (productId.contains('2_members')) {
          memberCount = 2;
          priceAmount = 24.99;
          priceDisplay = '24,99 € / mois';
        } else if (productId.contains('3_members')) {
          memberCount = 3;
          priceAmount = 34.99;
          priceDisplay = '34,99 € / mois';
        } else if (productId.contains('4_members')) {
          memberCount = 4;
          priceAmount = 44.99;
          priceDisplay = '44,99 € / mois';
        }
      }

      // Sauvegarder dans Firestore
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'structureId': user.uid,
        'structureType': structureType,
        'memberCount': memberCount,
        'status': 'active',
        'productId': productId,
        'transactionId': purchaseData['transactionId'],
        'purchaseDate': purchaseData['purchaseDate'],
        'expirationDate': purchaseData['expirationDate'],
        'priceAmount': priceAmount,
        'priceDisplay': priceDisplay,
        'currency': 'EUR',
        'billingPeriod': 'monthly',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mettre à jour la structure
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .update({
        'maxMemberCount': memberCount,
        'subscriptionActive': true,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
        'currentPriceAmount': priceAmount,
        'currentPriceDisplay': priceDisplay,
      });

      print('✅ Abonnement sauvegardé dans Firestore');
    } catch (e) {
      print('❌ Erreur sauvegarde Firestore: $e');
    }
  }

  /// Obtenir les informations d'abonnement depuis Firestore
  static Future<Map<String, dynamic>?> getSubscriptionInfo() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (subscriptionDoc.docs.isNotEmpty) {
        return subscriptionDoc.docs.first.data();
      }

      return null;
    } catch (e) {
      print('❌ Erreur récupération abonnement: $e');
      return null;
    }
  }

  /// Nettoyer les ressources
  static void dispose() {
    _purchaseController.close();
  }

  /// Obtenir le product ID pour un type de structure
  static String getProductId(String structureType, int memberCount) {
    if (structureType == 'MAM') {
      return productIds['mam_${memberCount}_members'] ??
          productIds['mam_2_members']!;
    }
    return productIds['assistante_maternelle']!;
  }

  /// Calculer le prix pour un type d'abonnement
  static Map<String, dynamic> calculatePrice(
      String structureType, int memberCount) {
    double priceAmount;
    String priceDisplay;

    if (structureType == 'MAM') {
      switch (memberCount) {
        case 2:
          priceAmount = 24.99;
          priceDisplay = '24,99 € / mois';
          break;
        case 3:
          priceAmount = 34.99;
          priceDisplay = '34,99 € / mois';
          break;
        case 4:
          priceAmount = 44.99;
          priceDisplay = '44,99 € / mois';
          break;
        default:
          priceAmount = 24.99;
          priceDisplay = '24,99 € / mois';
      }
    } else {
      priceAmount = 12.99;
      priceDisplay = '12,99 € / mois';
    }

    return {
      'amount': priceAmount,
      'display': priceDisplay,
      'currency': 'EUR',
    };
  }
}
