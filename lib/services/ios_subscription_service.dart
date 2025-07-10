// lib/services/ios_subscription_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service d'abonnement spécifique à iOS utilisant in_app_purchase
class iOSSubscriptionService {
  static iOSSubscriptionService? _instance;
  static iOSSubscriptionService get instance =>
      _instance ??= iOSSubscriptionService._internal();

  iOSSubscriptionService._internal();

  // Instance in_app_purchase
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Stream controllers
  final StreamController<PurchaseDetails> _subscriptionController =
      StreamController<PurchaseDetails>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Streams publics
  Stream<PurchaseDetails> get subscriptionUpdates =>
      _subscriptionController.stream;
  Stream<String> get errors => _errorController.stream;

  // État
  bool _isInitialized = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _availableProducts = [];

  // IDs des produits iOS (App Store)
  static const Map<String, String> _iOSProductIds = {
    'assistante_maternelle':
        'com.beylet.poppinsApp.subscription.assistante_maternelle',
    'mam_2_members': 'com.beylet.poppinsApp.subscription.mam_2_members',
    'mam_3_members': 'com.beylet.poppinsApp.subscription.mam_3_members',
    'mam_4_members': 'com.beylet.poppinsApp.subscription.mam_4_members',
  };

  static const Set<String> _allProductIds = {
    'com.beylet.poppinsApp.subscription.assistante_maternelle',
    'com.beylet.poppinsApp.subscription.mam_2_members',
    'com.beylet.poppinsApp.subscription.mam_3_members',
    'com.beylet.poppinsApp.subscription.mam_4_members',
  };

  /// Initialise le service iOS
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Vérifier la disponibilité de l'App Store
      final bool isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) {
        throw Exception('App Store n\'est pas disponible');
      }

      // Écouter les mises à jour d'achat
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => print('🍎 Stream d\'achat iOS fermé'),
        onError: (error) {
          print('❌ Erreur stream iOS: $error');
          _errorController.add('Erreur de stream: $error');
        },
      );

      // Charger les produits disponibles
      await _loadProducts();

      _isInitialized = true;
      print('✅ Service d\'abonnement iOS initialisé');
    } catch (e) {
      print('❌ Erreur d\'initialisation iOS: $e');
      _errorController.add('Erreur d\'initialisation: $e');
      rethrow;
    }
  }

  /// Charge les produits depuis l'App Store
  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_allProductIds);

      if (response.error != null) {
        throw Exception(
            'Erreur de chargement des produits: ${response.error?.message}');
      }

      _availableProducts = response.productDetails;

      print('🍎 Produits iOS chargés: ${_availableProducts.length}');
      for (final product in _availableProducts) {
        print('  - ${product.id}: ${product.price}');
      }

      if (_availableProducts.isEmpty) {
        print('⚠️ Aucun produit trouvé sur l\'App Store');
      }
    } catch (e) {
      print('❌ Erreur de chargement des produits: $e');
      _errorController.add('Erreur de chargement: $e');
      rethrow;
    }
  }

  /// Gère les mises à jour d'achat
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      _handlePurchase(purchase);
    }
  }

  /// Traite un achat individuel
  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    print(
        '🍎 Traitement achat iOS: ${purchase.productID} - ${purchase.status}');

    switch (purchase.status) {
      case PurchaseStatus.purchased:
        // Vérifier la transaction
        await _verifyPurchase(purchase);

        // Sauvegarder dans Firestore
        await _saveSubscriptionToFirestore(purchase);

        // Finaliser l'achat si nécessaire
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }

        _subscriptionController.add(purchase);
        break;

      case PurchaseStatus.error:
        print('❌ Erreur d\'achat iOS: ${purchase.error?.message}');
        _errorController.add(
            'Erreur d\'achat: ${purchase.error?.message ?? "Erreur inconnue"}');
        break;

      case PurchaseStatus.pending:
        print('⏳ Achat iOS en attente: ${purchase.productID}');
        _subscriptionController.add(purchase);
        break;

      case PurchaseStatus.restored:
        print('🔄 Achat iOS restauré: ${purchase.productID}');
        await _saveSubscriptionToFirestore(purchase);
        _subscriptionController.add(purchase);
        break;

      case PurchaseStatus.canceled:
        print('❌ Achat iOS annulé: ${purchase.productID}');
        _errorController.add('Achat annulé par l\'utilisateur');
        break;
    }
  }

  /// Vérifie un achat (validation côté serveur recommandée)
  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      // TODO: Implémenter la vérification côté serveur
      // Envoyer purchase.verificationData.serverVerificationData à votre serveur
      // pour vérifier avec l'App Store

      print('✅ Achat iOS vérifié: ${purchase.productID}');
    } catch (e) {
      print('❌ Erreur de vérification: $e');
      _errorController.add('Erreur de vérification: $e');
    }
  }

  /// Sauvegarder l'abonnement dans Firestore
  Future<void> _saveSubscriptionToFirestore(PurchaseDetails purchase) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String productId = purchase.productID;

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
        'transactionId': purchase.purchaseID,
        'purchaseDate': DateTime.now().toIso8601String(),
        'expirationDate':
            DateTime.now().add(Duration(days: 30)).toIso8601String(),
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

      print('✅ Abonnement iOS sauvegardé dans Firestore');
    } catch (e) {
      print('❌ Erreur sauvegarde Firestore: $e');
    }
  }

  /// Retourne l'ID produit iOS
  static String getProductId(String structureType, int mamMembersCount) {
    switch (structureType) {
      case 'assistante_maternelle':
        return _iOSProductIds['assistante_maternelle']!;
      case 'mam':
        switch (mamMembersCount) {
          case 2:
            return _iOSProductIds['mam_2_members']!;
          case 3:
            return _iOSProductIds['mam_3_members']!;
          case 4:
            return _iOSProductIds['mam_4_members']!;
          default:
            return _iOSProductIds['mam_2_members']!;
        }
      default:
        return _iOSProductIds['assistante_maternelle']!;
    }
  }

  /// Récupère les produits disponibles
  Future<List<ProductDetails>> getAvailableProducts() async {
    await _ensureInitialized();
    return _availableProducts;
  }

  /// Achète un abonnement
  Future<bool> purchaseSubscription(String productId) async {
    await _ensureInitialized();

    try {
      // Chercher le produit correspondant
      ProductDetails? product;
      for (final p in _availableProducts) {
        if (p.id == productId) {
          product = p;
          break;
        }
      }

      if (product == null) {
        throw Exception('Produit non trouvé: $productId');
      }

      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: product);

      // Pour les abonnements, utiliser buyNonConsumable
      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      print('🍎 Achat iOS initié: $productId - Success: $success');
      return success;
    } catch (e) {
      print('❌ Erreur d\'achat iOS: $e');
      _errorController.add('Erreur d\'achat: $e');
      return false;
    }
  }

  /// Restaure les achats
  Future<void> restorePurchases() async {
    await _ensureInitialized();

    try {
      await _inAppPurchase.restorePurchases();
      print('🍎 Restauration iOS terminée');
    } catch (e) {
      print('❌ Erreur de restauration iOS: $e');
      _errorController.add('Erreur de restauration: $e');
      rethrow;
    }
  }

  /// Vérifie le statut d'un abonnement
  Future<PurchaseDetails?> checkSubscriptionStatus(String productId) async {
    await _ensureInitialized();

    // Pour le moment, on utilise une approche simplifiée
    // Dans un vrai projet, il faudrait implémenter une vérification côté serveur
    print('🍎 Vérification du statut de l\'abonnement: $productId');

    // TODO: Implémenter la vérification d'abonnement avec votre backend
    // qui interroge l'API App Store

    return null;
  }

  /// S'assure que le service est initialisé
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Nettoie les ressources
  void dispose() {
    _subscription?.cancel();
    _subscriptionController.close();
    _errorController.close();
    _isInitialized = false;
  }

  /// Vérifie si un abonnement est actif
  Future<bool> hasActiveSubscription() async {
    try {
      // Pour une implémentation complète, il faudrait vérifier côté serveur
      // avec l'API App Store
      print('🍎 Vérification d\'abonnement actif');

      // TODO: Implémenter avec votre backend
      return false;
    } catch (e) {
      print('❌ Erreur de vérification d\'abonnement actif: $e');
      return false;
    }
  }

  /// Retourne l'abonnement actif
  Future<PurchaseDetails?> getActiveSubscription() async {
    try {
      // Pour une implémentation complète, il faudrait vérifier côté serveur
      print('🍎 Récupération de l\'abonnement actif');

      // TODO: Implémenter avec votre backend
      return null;
    } catch (e) {
      print('❌ Erreur de récupération d\'abonnement actif: $e');
      return null;
    }
  }

  /// Obtenir les informations d'abonnement depuis Firestore
  Future<Map<String, dynamic>?> getSubscriptionInfo() async {
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
