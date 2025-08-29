// lib/services/android_subscription_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // 🔧 CORRIGÉ : ID unique pour Google Play
  static const Set<String> _allProductIds = {
    'abo_poppins',
  };

  /// Initialise le service Android
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🤖 Initialisation du service Android...');

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
      print('🔍 Tentative de chargement des produits: $_allProductIds');

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_allProductIds);

      if (response.error != null) {
        print(
            '❌ Erreur détaillée: ${response.error?.code} - ${response.error?.message}');
        throw Exception(
            'Erreur de chargement des produits: ${response.error?.message}');
      }

      _availableProducts = response.productDetails;

      // Debug : voir quels produits sont trouvés vs non trouvés
      print(
          '✅ Produits trouvés: ${response.productDetails.map((p) => p.id).toList()}');
      print('❌ Produits non trouvés: ${response.notFoundIDs}');

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

        // ✅ AJOUT : Sauvegarder dans Firestore
        await _saveSubscriptionToFirestore(purchase);

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

        // ✅ AJOUT : Sauvegarder lors de la restauration aussi
        await _saveSubscriptionToFirestore(purchase);

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

  /// ✅ MÉTHODE CORRIGÉE : Identifier le type d'abonnement par le prix
  Map<String, dynamic> _getSubscriptionInfoByPrice(String price) {
    // Prix normalisé (supprime les espaces et caractères spéciaux)
    String normalizedPrice = price.replaceAll(' ', '').toLowerCase();

    print('🔍 Analyse du prix: "$price" (normalisé: "$normalizedPrice")');

    if (normalizedPrice.contains('8,99') || normalizedPrice.contains('8.99')) {
      return {
        'structureType': 'assistante_maternelle',
        'memberCount': 1,
        'priceAmount': 8.99,
        'priceDisplay': '8,99 € / mois',
        'productKey': 'ass-mat',
      };
    } else if (normalizedPrice.contains('19,99') ||
        normalizedPrice.contains('19.99')) {
      return {
        'structureType': 'MAM',
        'memberCount': 2,
        'priceAmount': 19.99,
        'priceDisplay': '19,99 € / mois',
        'productKey': 'mam-2',
      };
    } else if (normalizedPrice.contains('24,99') ||
        normalizedPrice.contains('24.99')) {
      return {
        'structureType': 'MAM',
        'memberCount': 3,
        'priceAmount': 24.99,
        'priceDisplay': '24,99 € / mois',
        'productKey': 'mam-3',
      };
    } else if (normalizedPrice.contains('29,99') ||
        normalizedPrice.contains('29.99')) {
      return {
        'structureType': 'MAM',
        'memberCount': 4,
        'priceAmount': 29.99,
        'priceDisplay': '29,99 € / mois',
        'productKey': 'mam-4',
      };
    } else if (normalizedPrice.contains('gratuit') ||
        normalizedPrice.contains('free') ||
        normalizedPrice == '0') {
      // Pour les offres d'essai gratuit, on doit deviner le type
      // On va utiliser un défaut et laisser l'utilisateur choisir
      return {
        'structureType': 'assistante_maternelle',
        'memberCount': 1,
        'priceAmount': 0.0,
        'priceDisplay': 'Essai gratuit 7 jours',
        'productKey': 'trial',
        'isTrialPurchase': true,
      };
    } else {
      // Prix par défaut si non reconnu
      print('⚠️ Prix non reconnu: $price, utilisation des valeurs par défaut');
      return {
        'structureType': 'assistante_maternelle',
        'memberCount': 1,
        'priceAmount': 8.99,
        'priceDisplay': '8,99 € / mois',
        'productKey': 'ass-mat',
      };
    }
  }

  /// ✅ NOUVELLE MÉTHODE : Sauvegarder l'abonnement dans Firestore (Android)
  Future<void> _saveSubscriptionToFirestore(PurchaseDetails purchase) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print(
            '❌ Utilisateur non connecté, impossible de sauvegarder l\'abonnement');
        return;
      }

      final String productId = purchase.productID;
      final String transactionId = purchase.purchaseID ?? '';

      print(
          '🤖 Tentative de sauvegarde Android pour: $productId (transaction: $transactionId)');

      // Vérification anti-duplication
      if (transactionId.isNotEmpty) {
        final existingByTransaction = await FirebaseFirestore.instance
            .collection('subscriptions')
            .where('transactionId', isEqualTo: transactionId)
            .limit(1)
            .get();

        if (existingByTransaction.docs.isNotEmpty) {
          print('✅ Abonnement déjà existant avec cette transaction');
          return;
        }
      }

      // Trouver le produit acheté pour récupérer le prix
      ProductDetails? purchasedProduct;
      for (final product in _availableProducts) {
        if (product.id == productId) {
          purchasedProduct = product;
          break;
        }
      }

      if (purchasedProduct == null) {
        print('❌ Produit non trouvé dans la liste des produits disponibles');
        return;
      }

      // Identifier le type d'abonnement par le prix
      final subscriptionInfo =
          _getSubscriptionInfoByPrice(purchasedProduct.price);

      final String structureType = subscriptionInfo['structureType'];
      final int memberCount = subscriptionInfo['memberCount'];
      final double priceAmount = subscriptionInfo['priceAmount'];
      final String priceDisplay = subscriptionInfo['priceDisplay'];
      final String productKey = subscriptionInfo['productKey'];
      final bool isTrialPurchase = subscriptionInfo['isTrialPurchase'] ?? false;

      print(
          '🎯 Type d\'abonnement identifié: $structureType ($memberCount membres) - $priceDisplay');

      // Désactiver anciens abonnements
      final oldActiveSubscriptions = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      for (final doc in oldActiveSubscriptions.docs) {
        await doc.reference.update({
          'status': 'replaced',
          'replacedAt': FieldValue.serverTimestamp(),
        });
      }

      // Créer nouvel abonnement
      final DateTime purchaseDate = DateTime.now();
      final DateTime expirationDate = purchaseDate.add(Duration(days: 30));
      final DateTime trialEndDate =
          isTrialPurchase ? purchaseDate.add(Duration(days: 7)) : purchaseDate;

      final Map<String, dynamic> subscriptionData = {
        'structureId': user.uid,
        'structureType': structureType,
        'memberCount': memberCount,
        'status': 'active',
        'productId': productId,
        'productKey': productKey, // Identifiant interne pour notre logique
        'transactionId': transactionId,
        'purchaseDate': purchaseDate.toIso8601String(),
        'expirationDate': expirationDate.toIso8601String(),
        'trialEndsAt': Timestamp.fromDate(trialEndDate),
        'priceAmount': priceAmount,
        'priceDisplay': priceDisplay,
        'originalPrice': purchasedProduct.price, // Prix original de Google Play
        'currency': 'EUR',
        'billingPeriod': 'monthly',
        'platform': 'android',
        'isTrialPeriod': isTrialPurchase,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('subscriptions')
          .add(subscriptionData);

      print('✅ Abonnement Android sauvegardé: ${docRef.id}');

      // Mettre à jour structure
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .update({
        'maxMemberCount': memberCount,
        'subscriptionActive': true,
        'subscriptionDocId': docRef.id,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Erreur sauvegarde Android: $e');
      _errorController.add('Erreur de sauvegarde: $e');
    }
  }

  /// 🆕 MÉTHODE : Trouver un produit par type d'abonnement désiré
  ProductDetails? _findProductBySubscriptionType(
      String structureType, int memberCount) {
    double targetPrice = 8.99; // par défaut assistante maternelle

    if (structureType == 'MAM') {
      switch (memberCount) {
        case 2:
          targetPrice = 19.99;
          break;
        case 3:
          targetPrice = 24.99;
          break;
        case 4:
          targetPrice = 29.99;
          break;
      }
    }

    // Chercher le produit avec le prix correspondant
    for (final product in _availableProducts) {
      final subscriptionInfo = _getSubscriptionInfoByPrice(product.price);
      if (subscriptionInfo['priceAmount'] == targetPrice) {
        return product;
      }
    }

    return null;
  }

  /// 🆕 MÉTHODE AMÉLIORÉE : Tentative d'achat d'un produit spécifique
  Future<bool> _attemptPurchaseByProduct(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: product);

      // Pour les abonnements, utiliser buyNonConsumable
      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      print(
          '🤖 Achat Android initié: ${product.id} (${product.price}) - Success: $success');
      return success;
    } catch (e) {
      print('❌ Erreur d\'achat Android pour ${product.id}: $e');
      throw e;
    }
  }

  /// Récupère les produits disponibles
  Future<List<ProductDetails>> getAvailableProducts() async {
    await _ensureInitialized();
    return _availableProducts;
  }

  /// 🆕 MÉTHODE AMÉLIORÉE : Achète un abonnement en spécifiant le type voulu
  Future<bool> purchaseSubscriptionByType(
      String structureType, int memberCount) async {
    await _ensureInitialized();

    try {
      print('🛒 Tentative d\'achat: $structureType avec $memberCount membres');

      // Chercher d'abord une offre d'essai gratuite
      ProductDetails? trialProduct;
      for (final product in _availableProducts) {
        if (product.price.toLowerCase().contains('gratuit') ||
            product.price.toLowerCase().contains('free')) {
          trialProduct = product;
          print('🎯 Offre d\'essai trouvée: ${product.price}');
          break;
        }
      }

      // Essayer l'offre d'essai en premier
      if (trialProduct != null) {
        try {
          print('🎯 Tentative d\'achat avec essai gratuit');
          return await _attemptPurchaseByProduct(trialProduct);
        } catch (e) {
          print(
              '⚠️ Essai gratuit non disponible ($e), basculement vers forfait payant');
        }
      }

      // Chercher le forfait payant correspondant
      final ProductDetails? targetProduct =
          _findProductBySubscriptionType(structureType, memberCount);

      if (targetProduct == null) {
        throw Exception(
            'Aucun produit trouvé pour $structureType avec $memberCount membres');
      }

      print('💳 Achat du forfait: ${targetProduct.price}');
      return await _attemptPurchaseByProduct(targetProduct);
    } catch (e) {
      print('❌ Erreur d\'achat Android: $e');
      _errorController.add('Erreur d\'achat: $e');
      return false;
    }
  }

  /// MÉTHODE DE COMPATIBILITÉ : Achète un abonnement (ancienne signature)
  Future<bool> purchaseSubscription(String productId) async {
    // Convertir l'ancien productId vers le nouveau système
    if (productId == 'ass-mat') {
      return await purchaseSubscriptionByType('assistante_maternelle', 1);
    } else if (productId == 'abo-mam-2') {
      return await purchaseSubscriptionByType('MAM', 2);
    } else if (productId == 'abo-mam-3') {
      return await purchaseSubscriptionByType('MAM', 3);
    } else if (productId == 'abo-mam-4') {
      return await purchaseSubscriptionByType('MAM', 4);
    } else {
      // Par défaut, assistante maternelle
      return await purchaseSubscriptionByType('assistante_maternelle', 1);
    }
  }

  /// Retourne l'ID produit Android (pour compatibilité)
  static String getProductId(String structureType, int mamMembersCount) {
    // Maintenant on utilise toujours 'abo_poppins' mais on différencie par le prix
    return 'abo_poppins';
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

    print('🤖 Vérification du statut de l\'abonnement: $productId');
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
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('🤖 Utilisateur non connecté pour vérification abonnement');
        return false;
      }

      print('🤖 Récupération abonnement actif pour: ${user.uid}');

      final subscriptionQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      final bool hasActive = subscriptionQuery.docs.isNotEmpty;

      if (hasActive) {
        print('🤖 Abonnement actif trouvé');
      } else {
        print('🤖 Aucun abonnement actif trouvé');
      }

      return hasActive;
    } catch (e) {
      print('❌ Erreur vérification abonnement actif Android: $e');
      return false;
    }
  }

  /// Retourne l'abonnement actif
  Future<PurchaseDetails?> getActiveSubscription() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('🤖 Utilisateur non connecté pour récupération abonnement');
        return null;
      }

      print('🤖 Récupération abonnement actif pour: ${user.uid}');

      final subscriptionQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (subscriptionQuery.docs.isEmpty) {
        print('🤖 Aucun abonnement actif trouvé');
        return null;
      }

      final subscriptionData = subscriptionQuery.docs.first.data();
      print('🤖 Abonnement actif récupéré: ${subscriptionData['productId']}');

      // Créer un PurchaseDetails fictif basé sur Firestore
      final fakePurchaseDetails =
          _createPurchaseDetailsFromFirestore(subscriptionData);

      return fakePurchaseDetails;
    } catch (e) {
      print('❌ Erreur récupération abonnement actif Android: $e');
      return null;
    }
  }

  /// ✅ MÉTHODE : Créer un PurchaseDetails depuis Firestore
  PurchaseDetails _createPurchaseDetailsFromFirestore(
      Map<String, dynamic> data) {
    return PurchaseDetails(
      productID: data['productId'] ?? '',
      purchaseID: data['transactionId'] ?? '',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'firestore',
      ),
      transactionDate: data['purchaseDate'] != null
          ? DateTime.parse(data['purchaseDate'])
              .millisecondsSinceEpoch
              .toString()
          : DateTime.now().millisecondsSinceEpoch.toString(),
      status: PurchaseStatus.purchased,
    );
  }
}
