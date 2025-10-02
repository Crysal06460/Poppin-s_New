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
  int? _lastRequestedMemberCount;

  // 🔧 NOUVEAUX IDS : Abonnements séparés avec offres d'essai
  static const Set<String> _allProductIds = {
    // Forfaits de base
    'abonnement_assmat',
    'abonnement_mam2',
    'abonnement_mam3',
    'abonnement_mam4',
    // Offres d'essai 7 jours
    'essaigratuit-assmat',
    'essaigratuit-mam2',
    'essaigratuit-mam3',
    'essaigratuit-mam4',
  };

  // Mapping des IDs pour compatibilité
  static const Map<String, String> _legacyToNewProductIds = {
    'ass-mat': 'abonnement_assmat',
    'abo-mam-2': 'abonnement_mam2',
    'abo-mam-3': 'abonnement_mam4',
    'abo-mam-4': 'abonnement_mam4',
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
        await _verifyPurchase(purchase);
        await _saveSubscriptionToFirestore(purchase);

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
        await _saveSubscriptionToFirestore(purchase);
        _subscriptionController.add(purchase);
        break;

      case PurchaseStatus.canceled:
        print('❌ Achat Android annulé: ${purchase.productID}');
        _errorController.add('Achat annulé par l\'utilisateur');
        break;
    }
  }

  /// Vérifie un achat
  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      print('✅ Achat Android vérifié: ${purchase.productID}');
    } catch (e) {
      print('❌ Erreur de vérification: $e');
      _errorController.add('Erreur de vérification: $e');
    }
  }

  /// Identifie le type d'abonnement par l'ID produit
  Map<String, dynamic> _getSubscriptionInfoByProductId(String productId) {
    print('🔍 Analyse de l\'ID produit: $productId');

    // Forfaits de base
    if (productId == 'abonnement_assmat') {
      return {
        'structureType': 'assistante_maternelle',
        'memberCount': 1,
        'priceAmount': 6.99,
        'priceDisplay': '6,99 € / mois',
        'productKey': 'ass-mat',
        'isTrialPurchase': false,
      };
    } else if (productId == 'abonnement_mam2') {
      final int resolvedMembers =
          ((_lastRequestedMemberCount ?? 3).clamp(2, 3) as num).toInt();
      return {
        'structureType': 'MAM',
        'memberCount': resolvedMembers,
        'priceAmount': 19.99,
        'priceDisplay': '19,99 € / mois',
        'productKey': 'mam-2-3',
        'isTrialPurchase': false,
      };
    } else if (productId == 'abonnement_mam3') {
      return {
        'structureType': 'MAM',
        'memberCount': 4,
        'priceAmount': 24.99,
        'priceDisplay': '24,99 € / mois',
        'productKey': 'mam-4-legacy',
        'isTrialPurchase': false,
      };
    } else if (productId == 'abonnement_mam4') {
      return {
        'structureType': 'MAM',
        'memberCount': 4,
        'priceAmount': 24.99,
        'priceDisplay': '24,99 € / mois',
        'productKey': 'mam-4-plus',
        'isTrialPurchase': false,
      };
    }
    // Offres d'essai
    else if (productId == 'essaigratuit-assmat') {
      return {
        'structureType': 'assistante_maternelle',
        'memberCount': 1,
        'priceAmount': 0.0,
        'priceDisplay': 'Essai gratuit 7 jours',
        'productKey': 'trial-ass-mat',
        'isTrialPurchase': true,
      };
    } else if (productId == 'essaigratuit-mam2') {
      final int resolvedMembers =
          ((_lastRequestedMemberCount ?? 3).clamp(2, 3) as num).toInt();
      return {
        'structureType': 'MAM',
        'memberCount': resolvedMembers,
        'priceAmount': 0.0,
        'priceDisplay': 'Essai gratuit 7 jours',
        'productKey': 'trial-mam-2-3',
        'isTrialPurchase': true,
      };
    } else if (productId == 'essaigratuit-mam3') {
      return {
        'structureType': 'MAM',
        'memberCount': 4,
        'priceAmount': 0.0,
        'priceDisplay': 'Essai gratuit 7 jours',
        'productKey': 'trial-mam-4-legacy',
        'isTrialPurchase': true,
      };
    } else if (productId == 'essaigratuit-mam4') {
      return {
        'structureType': 'MAM',
        'memberCount': 4,
        'priceAmount': 0.0,
        'priceDisplay': 'Essai gratuit 7 jours',
        'productKey': 'trial-mam-4-plus',
        'isTrialPurchase': true,
      };
    }

    // Par défaut
    print('⚠️ ID produit non reconnu: $productId');
    return {
      'structureType': 'assistante_maternelle',
      'memberCount': 1,
      'priceAmount': 6.99,
      'priceDisplay': '6,99 € / mois',
      'productKey': 'ass-mat',
      'isTrialPurchase': false,
    };
  }

  /// Sauvegarde l'abonnement dans Firestore
  Future<void> _saveSubscriptionToFirestore(PurchaseDetails purchase) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ Utilisateur non connecté');
        return;
      }

      final String productId = purchase.productID;
      final String transactionId = purchase.purchaseID ?? '';

      print(
          '🤖 Sauvegarde Android pour: $productId (transaction: $transactionId)');

      // Vérification anti-duplication
      if (transactionId.isNotEmpty) {
        final existingByTransaction = await FirebaseFirestore.instance
            .collection('subscriptions')
            .where('transactionId', isEqualTo: transactionId)
            .limit(1)
            .get();

        if (existingByTransaction.docs.isNotEmpty) {
          print('✅ Abonnement déjà existant');
          return;
        }
      }

      // Identifier le type d'abonnement par l'ID
      final subscriptionInfo = _getSubscriptionInfoByProductId(productId);

      final String structureType = subscriptionInfo['structureType'];
      final int memberCount = subscriptionInfo['memberCount'];
      final double priceAmount = subscriptionInfo['priceAmount'];
      final String priceDisplay = subscriptionInfo['priceDisplay'];
      final String productKey = subscriptionInfo['productKey'];
      final bool isTrialPurchase = subscriptionInfo['isTrialPurchase'];

      print(
          '🎯 Type identifié: $structureType ($memberCount membres) - $priceDisplay');

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
        'productKey': productKey,
        'transactionId': transactionId,
        'purchaseDate': purchaseDate.toIso8601String(),
        'expirationDate': expirationDate.toIso8601String(),
        'trialEndsAt': Timestamp.fromDate(trialEndDate),
        'priceAmount': priceAmount,
        'priceDisplay': priceDisplay,
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

      // Réinitialiser la sélection après traitement
      _lastRequestedMemberCount = null;

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

  /// Trouve un produit par type et nombre de membres
  ProductDetails? _findProduct(String structureType, int memberCount,
      {bool preferTrial = true}) {
    // IDs cibles
    String targetTrialId = '';
    String targetPaidId = '';

    final String normalizedType = structureType.toLowerCase();

    if (normalizedType == 'assistante_maternelle') {
      targetTrialId = 'essaigratuit-assmat';
      targetPaidId = 'abonnement_assmat';
    } else if (normalizedType == 'mam') {
      if (memberCount <= 3) {
        targetTrialId = 'essaigratuit-mam2';
        targetPaidId = 'abonnement_mam2';
      } else {
        targetTrialId = 'essaigratuit-mam4';
        targetPaidId = 'abonnement_mam4';
      }
    }

    print(
        '🎯 Recherche: type=$structureType, members=$memberCount, trial=$targetTrialId, paid=$targetPaidId, preferTrial=$preferTrial');

    // Chercher d'abord l'essai si préféré
    if (preferTrial && targetTrialId.isNotEmpty) {
      for (final product in _availableProducts) {
        if (product.id == targetTrialId) {
          print('✅ Essai trouvé: ${product.id}');
          return product;
        }
      }
    }

    // Chercher le forfait payant
    if (targetPaidId.isNotEmpty) {
      for (final product in _availableProducts) {
        if (product.id == targetPaidId) {
          print('✅ Forfait payant trouvé: ${product.id}');
          return product;
        }
      }
    }

    // Fallback pour anciens IDs MAM 4 membres
    if (normalizedType == 'mam' && memberCount > 3) {
      if (preferTrial) {
        for (final product in _availableProducts) {
          if (product.id == 'essaigratuit-mam4' ||
              product.id == 'essaigratuit-mam3') {
            print('✅ Essai legacy trouvé: ${product.id}');
            return product;
          }
        }
      }
      for (final product in _availableProducts) {
        if (product.id == 'abonnement_mam4' ||
            product.id == 'abonnement_mam3') {
          print('✅ Forfait legacy trouvé: ${product.id}');
          return product;
        }
      }
    }

    print('❌ Aucun produit trouvé pour $structureType ($memberCount membres)');
    return null;
  }

  /// Lance l'achat d'un produit
  Future<bool> _attemptPurchase(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: product);

      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      print('🤖 Achat initié: ${product.id} - Success: $success');
      return success;
    } catch (e) {
      print('❌ Erreur d\'achat pour ${product.id}: $e');
      throw e;
    }
  }

  /// Récupère les produits disponibles
  Future<List<ProductDetails>> getAvailableProducts() async {
    await _ensureInitialized();
    return _availableProducts;
  }

  /// Achète un abonnement par type (nouvelle méthode principale)
  Future<bool> purchaseSubscriptionByType(
      String structureType, int memberCount) async {
    await _ensureInitialized();

    try {
      print('🛒 Achat: $structureType avec $memberCount membres');

      // Mémoriser la sélection pour ajuster la sauvegarde Firestore
      _lastRequestedMemberCount = memberCount;

      // Chercher d'abord l'essai gratuit
      ProductDetails? product =
          _findProduct(structureType, memberCount, preferTrial: true);

      if (product != null) {
        return await _attemptPurchase(product);
      }

      throw Exception(
          'Aucun produit disponible pour $structureType avec $memberCount membres');
    } catch (e) {
      print('❌ Erreur d\'achat Android: $e');
      _errorController.add('Erreur d\'achat: $e');
      _lastRequestedMemberCount = null;
      return false;
    }
  }

  /// Méthode de compatibilité (ancienne signature)
  Future<bool> purchaseSubscription(String productId) async {
    // Convertir ancien productId vers nouveau système
    if (productId == 'ass-mat' || productId == 'abonnement_assmat') {
      return await purchaseSubscriptionByType('assistante_maternelle', 1);
    } else if (productId == 'abo-mam-2' || productId == 'abonnement_mam2') {
      return await purchaseSubscriptionByType('MAM', 3);
    } else if (productId == 'abo-mam-3' || productId == 'abonnement_mam3') {
      return await purchaseSubscriptionByType('MAM', 4);
    } else if (productId == 'abo-mam-4' || productId == 'abonnement_mam4') {
      return await purchaseSubscriptionByType('MAM', 4);
    } else {
      return await purchaseSubscriptionByType('assistante_maternelle', 1);
    }
  }

  /// Retourne l'ID produit Android (compatibilité)
  static String getProductId(String structureType, int mamMembersCount) {
    final String normalizedType = structureType.toLowerCase();

    if (normalizedType == 'assistante_maternelle') {
      return 'abonnement_assmat';
    }

    if (normalizedType == 'mam') {
      if (mamMembersCount <= 3) {
        return 'abonnement_mam2';
      }
      return 'abonnement_mam4';
    }

    return 'abonnement_assmat';
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
      if (user == null) return false;

      final subscriptionQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return subscriptionQuery.docs.isNotEmpty;
    } catch (e) {
      print('❌ Erreur vérification abonnement: $e');
      return false;
    }
  }

  /// Retourne l'abonnement actif
  Future<PurchaseDetails?> getActiveSubscription() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final subscriptionQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (subscriptionQuery.docs.isEmpty) return null;

      final subscriptionData = subscriptionQuery.docs.first.data();
      return _createPurchaseDetailsFromFirestore(subscriptionData);
    } catch (e) {
      print('❌ Erreur récupération abonnement: $e');
      return null;
    }
  }

  /// Crée un PurchaseDetails depuis Firestore
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

  Future<PurchaseDetails?> checkSubscriptionStatus(String productId) async {
    await _ensureInitialized();
    return null;
  }
}
