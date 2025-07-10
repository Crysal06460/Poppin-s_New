// lib/services/android_subscription_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Service d'abonnement spécifique à Android utilisant in_app_purchase
class AndroidSubscriptionService {
  static AndroidSubscriptionService? _instance;
  static AndroidSubscriptionService get instance =>
      _instance ??= AndroidSubscriptionService._internal();

  AndroidSubscriptionService._internal();

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

  // 🔧 CORRIGÉ : IDs des produits Android (Google Play) - CORRESPONDENT À GOOGLE PLAY CONSOLE
  static const Map<String, String> _androidProductIds = {
    'assistante_maternelle': 'assmat', // ← CORRIGÉ
    'mam_2_members': 'mam2', // ← CORRIGÉ
    'mam_3_members': 'mam3', // ← CORRIGÉ
    'mam_4_members': 'mam4', // ← CORRIGÉ
  };

  static const Set<String> _allProductIds = {
    'assmat', // ← CORRIGÉ
    'mam2', // ← CORRIGÉ
    'mam3', // ← CORRIGÉ
    'mam4', // ← CORRIGÉ
  };

  /// Initialise le service Android
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Vérifier la disponibilité
      final bool isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) {
        throw Exception('Google Play Store n\'est pas disponible');
      }

      // Écouter les mises à jour d'achat
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => print('🤖 Stream d\'achat Android fermé'),
        onError: (error) {
          print('❌ Erreur stream Android: $error');
          _errorController.add('Erreur de stream: $error');
        },
      );

      // Charger les produits disponibles
      await _loadProducts();

      _isInitialized = true;
      print('✅ Service d\'abonnement Android initialisé');
    } catch (e) {
      print('❌ Erreur d\'initialisation Android: $e');
      _errorController.add('Erreur d\'initialisation: $e');
      rethrow;
    }
  }

  /// Charge les produits depuis Google Play
  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_allProductIds);

      if (response.error != null) {
        throw Exception(
            'Erreur de chargement des produits: ${response.error?.message}');
      }

      _availableProducts = response.productDetails;

      print('🤖 Produits Android chargés: ${_availableProducts.length}');
      for (final product in _availableProducts) {
        print('  - ${product.id}: ${product.price}');
      }

      if (_availableProducts.isEmpty) {
        print('⚠️ Aucun produit trouvé sur Google Play');
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
        '🤖 Traitement achat Android: ${purchase.productID} - ${purchase.status}');

    switch (purchase.status) {
      case PurchaseStatus.purchased:
        // Vérifier la transaction
        await _verifyPurchase(purchase);

        // Finaliser l'achat si nécessaire
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }

        _subscriptionController.add(purchase);
        break;

      case PurchaseStatus.error:
        print('❌ Erreur d\'achat Android: ${purchase.error?.message}');
        _errorController.add(
            'Erreur d\'achat: ${purchase.error?.message ?? "Erreur inconnue"}');
        break;

      case PurchaseStatus.pending:
        print('⏳ Achat Android en attente: ${purchase.productID}');
        _subscriptionController.add(purchase);
        break;

      case PurchaseStatus.restored:
        print('🔄 Achat Android restauré: ${purchase.productID}');
        _subscriptionController.add(purchase);
        break;

      case PurchaseStatus.canceled:
        print('❌ Achat Android annulé: ${purchase.productID}');
        _errorController.add('Achat annulé par l\'utilisateur');
        break;
    }
  }

  /// Vérifie un achat (validation côté serveur recommandée)
  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      // TODO: Implémenter la vérification côté serveur
      // Envoyer purchase.verificationData.serverVerificationData à votre serveur
      // pour vérifier avec Google Play Developer API

      print('✅ Achat Android vérifié: ${purchase.productID}');
    } catch (e) {
      print('❌ Erreur de vérification: $e');
      _errorController.add('Erreur de vérification: $e');
    }
  }

  /// Retourne l'ID produit Android
  static String getProductId(String structureType, int mamMembersCount) {
    switch (structureType) {
      case 'assistante_maternelle':
        return _androidProductIds['assistante_maternelle']!;
      case 'mam':
        switch (mamMembersCount) {
          case 2:
            return _androidProductIds['mam_2_members']!;
          case 3:
            return _androidProductIds['mam_3_members']!;
          case 4:
            return _androidProductIds['mam_4_members']!;
          default:
            return _androidProductIds['mam_2_members']!;
        }
      default:
        return _androidProductIds['assistante_maternelle']!;
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

      print('🤖 Achat Android initié: $productId - Success: $success');
      return success;
    } catch (e) {
      print('❌ Erreur d\'achat Android: $e');
      _errorController.add('Erreur d\'achat: $e');
      return false;
    }
  }

  /// Restaure les achats
  Future<void> restorePurchases() async {
    await _ensureInitialized();

    try {
      await _inAppPurchase.restorePurchases();
      print('🤖 Restauration Android terminée');
    } catch (e) {
      print('❌ Erreur de restauration Android: $e');
      _errorController.add('Erreur de restauration: $e');
      rethrow;
    }
  }

  /// Vérifie le statut d'un abonnement
  Future<PurchaseDetails?> checkSubscriptionStatus(String productId) async {
    await _ensureInitialized();

    // Pour le moment, on utilise une approche simplifiée
    // Dans un vrai projet, il faudrait implémenter une vérification côté serveur
    print('🤖 Vérification du statut de l\'abonnement: $productId');

    // TODO: Implémenter la vérification d'abonnement avec votre backend
    // qui interroge l'API Google Play Developer

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
      // avec l'API Google Play Developer
      print('🤖 Vérification d\'abonnement actif');

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
      print('🤖 Récupération de l\'abonnement actif');

      // TODO: Implémenter avec votre backend
      return null;
    } catch (e) {
      print('❌ Erreur de récupération d\'abonnement actif: $e');
      return null;
    }
  }
}
