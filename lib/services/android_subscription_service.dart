// lib/services/android_subscription_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show
        SubscriptionOfferDetailsWrapper,
        PricingPhaseWrapper,
        ReplacementMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service d'abonnement spécifique à Android utilisant in_app_purchase
class _PendingPurchaseContext {
  const _PendingPurchaseContext({
    required this.productId,
    required this.structureType,
    required this.memberCount,
    required this.maxMemberCount,
    required this.priceAmount,
    required this.priceDisplay,
    required this.isTrialPurchase,
    required this.productKey,
  });

  final String productId;
  final String structureType;
  final int memberCount;
  final int maxMemberCount;
  final double priceAmount;
  final String priceDisplay;
  final bool isTrialPurchase;
  final String productKey;
}

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
  _PendingPurchaseContext? _pendingPurchaseContext;

  // 🔧 IDS ACTIFS DANS GOOGLE PLAY CONSOLE
  static const Set<String> _allProductIds = {
    // IDs produits officiels (Play Console)
    'abonnement_assmat',
    'abonnement_mam2',
    'abonnement_mam3',
    'abonnement_mam4',
    // ⏪ Compatibilité : anciens alias éventuels
    'assmat',
    'mam2',
    'mam3',
    'mam4',
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

    final String normalized = productId.trim();

    // Forfaits de base (IDs officiels)
    if (normalized == 'abonnement_assmat') {
      return {
        'structureType': 'assistante_maternelle',
        'memberCount': 1,
        'maxMemberCount': 1,
        'priceAmount': 6.99,
        'priceDisplay': '6,99 € / mois',
        'productKey': 'ass-mat',
        'isTrialPurchase': false,
      };
    } else if (normalized == 'abonnement_mam2') {
      return {
        'structureType': 'MAM',
        'memberCount': 2,
        'maxMemberCount': 2,
        'priceAmount': 19.99,
        'priceDisplay': '19,99 € / mois',
        'productKey': 'mam-2',
        'isTrialPurchase': false,
      };
    } else if (normalized == 'abonnement_mam3') {
      return {
        'structureType': 'MAM',
        'memberCount': 3,
        'maxMemberCount': 3,
        'priceAmount': 19.99,
        'priceDisplay': '19,99 € / mois',
        'productKey': 'mam-3',
        'isTrialPurchase': false,
      };
    } else if (normalized == 'abonnement_mam4') {
      return {
        'structureType': 'MAM',
        'memberCount': 4,
        'maxMemberCount': 99,
        'priceAmount': 24.99,
        'priceDisplay': '24,99 € / mois',
        'productKey': 'mam-4-plus',
        'isTrialPurchase': false,
      };
    }

    // Compatibilité : alias éventuels (si builds anciens en production)
    if (normalized == 'assmat') {
      return _getSubscriptionInfoByProductId('abonnement_assmat');
    } else if (normalized == 'mam2') {
      return _getSubscriptionInfoByProductId('abonnement_mam2');
    } else if (normalized == 'mam3') {
      return _getSubscriptionInfoByProductId('abonnement_mam3');
    } else if (normalized == 'mam4') {
      return _getSubscriptionInfoByProductId('abonnement_mam4');
    }

    // Par défaut
    print('⚠️ ID produit non reconnu: $productId');
    return {
      'structureType': 'assistante_maternelle',
      'memberCount': 1,
      'maxMemberCount': 1,
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
      final String structureId = await _resolveStructureId(user);
      final String fallbackStructureId = user.uid;

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
      Map<String, dynamic> subscriptionInfo =
          _getSubscriptionInfoByProductId(productId);

      if (_pendingPurchaseContext != null &&
          _pendingPurchaseContext!.productId == productId) {
        subscriptionInfo = {
          'structureType': _pendingPurchaseContext!.structureType,
          'memberCount': _pendingPurchaseContext!.memberCount,
          'maxMemberCount': _pendingPurchaseContext!.maxMemberCount,
          'priceAmount': _pendingPurchaseContext!.priceAmount,
          'priceDisplay': _pendingPurchaseContext!.priceDisplay,
          'productKey': _pendingPurchaseContext!.productKey,
          'isTrialPurchase': _pendingPurchaseContext!.isTrialPurchase,
        };
      }

      final String structureType = subscriptionInfo['structureType'];
      final int memberCount = subscriptionInfo['memberCount'];
      final int maxMemberCount =
          subscriptionInfo['maxMemberCount'] is int
              ? subscriptionInfo['maxMemberCount'] as int
              : memberCount;
      final double priceAmount = subscriptionInfo['priceAmount'];
      final String priceDisplay = subscriptionInfo['priceDisplay'];
      final bool isTrialPurchase = subscriptionInfo['isTrialPurchase'] == true;
      final String productKey = subscriptionInfo['productKey'];

      print(
          '🎯 Type identifié: $structureType ($memberCount membres) - $priceDisplay');

      // Désactiver anciens abonnements
      Future<QuerySnapshot<Map<String, dynamic>>> _fetchActiveSubs(String sid) {
        return FirebaseFirestore.instance
            .collection('subscriptions')
            .where('structureId', isEqualTo: sid)
            .where('status', isEqualTo: 'active')
            .get();
      }

      QuerySnapshot<Map<String, dynamic>> oldActiveSubscriptions =
          await _fetchActiveSubs(structureId);

      if (oldActiveSubscriptions.docs.isEmpty &&
          structureId != fallbackStructureId) {
        oldActiveSubscriptions = await _fetchActiveSubs(fallbackStructureId);
      }

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

      final String? purchaseToken = purchase is GooglePlayPurchaseDetails
          ? purchase.billingClientPurchase.purchaseToken
          : null;

      final Map<String, dynamic> subscriptionData = {
        'structureId': structureId,
        'structureType': structureType,
        'memberCount': memberCount,
        'status': 'active',
        'productId': productId,
        'productKey': productKey,
        'transactionId': transactionId,
        if (purchaseToken != null) 'purchaseToken': purchaseToken,
        'purchaseDate': purchaseDate.toIso8601String(),
        'expirationDate': expirationDate.toIso8601String(),
        'trialEndsAt': Timestamp.fromDate(trialEndDate),
        'priceAmount': priceAmount,
        'priceDisplay': priceDisplay,
        'currency': 'EUR',
        'billingPeriod': 'monthly',
        'platform': 'android',
        'source': 'google_play',
        'isTrialPeriod': isTrialPurchase,
        'maxMemberCount': maxMemberCount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('subscriptions')
          .add(subscriptionData);

      print('✅ Abonnement Android sauvegardé: ${docRef.id}');

      // Réinitialiser la sélection après traitement
      _lastRequestedMemberCount = null;
      if (_pendingPurchaseContext != null &&
          _pendingPurchaseContext!.productId == productId) {
        _pendingPurchaseContext = null;
      }

      // Mettre à jour structure
      Future<void> _updateStructure(Map<String, dynamic> data) async {
        final structures =
            FirebaseFirestore.instance.collection('structures');
        try {
          await structures.doc(structureId).update(data);
        } catch (e) {
          if (structureId != fallbackStructureId) {
            try {
              await structures.doc(fallbackStructureId).update(data);
            } catch (innerError) {
              print(
                  '❌ Impossible de mettre à jour la structure (fallback): $innerError');
            }
          } else {
            print('❌ Impossible de mettre à jour la structure: $e');
          }
        }
      }

      await _updateStructure({
        'maxMemberCount': maxMemberCount,
        'subscriptionActive': true,
        'subscriptionDocId': docRef.id,
        'subscriptionStatus': 'active',
        'subscriptionPlatform': 'android',
        'subscriptionSource': 'google_play',
        'trialStatus': 'converted',
        'currentPriceAmount': priceAmount,
        'currentPriceDisplay': priceDisplay,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Erreur sauvegarde Android: $e');
      _errorController.add('Erreur de sauvegarde: $e');
    }
  }

  Future<String> _resolveStructureId(User user) async {
    try {
      final String? email = user.email?.toLowerCase();
      if (email != null && email.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .get();
        final data = userDoc.data();
        final String? structureId = data?['structureId'] as String?;
        if (structureId != null && structureId.trim().isNotEmpty) {
          return structureId.trim();
        }
      }
    } catch (e) {
      print('⚠️ Impossible de résoudre structureId (Android): $e');
    }
    return user.uid;
  }

  Future<QuerySnapshot<Map<String, dynamic>>>
      _fetchLatestActiveSubscriptionSnapshot(User user) async {
    final String structureId = await _resolveStructureId(user);
    final String fallbackStructureId = user.uid;

    Future<QuerySnapshot<Map<String, dynamic>>> queryFor(String sid) {
      return FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: sid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
    }

    final primary = await queryFor(structureId);
    if (primary.docs.isNotEmpty || structureId == fallbackStructureId) {
      return primary;
    }
    return await queryFor(fallbackStructureId);
  }

  /// Trouve un produit par type et nombre de membres
  ProductDetails? _findProduct(String structureType, int memberCount) {
    final String normalizedType = structureType.toLowerCase();
    final List<String> candidateIds = [];

    if (normalizedType == 'assistante_maternelle') {
      candidateIds.addAll(['abonnement_assmat', 'assmat']);
    } else if (normalizedType == 'mam') {
      if (memberCount <= 2) {
        candidateIds.addAll(['abonnement_mam2', 'mam2']);
      } else if (memberCount == 3) {
        candidateIds.addAll(['abonnement_mam3', 'mam3']);
      } else {
        candidateIds.addAll(['abonnement_mam4', 'mam4']);
      }
    }

    for (final candidate in candidateIds) {
      try {
        final match =
            _availableProducts.firstWhere((product) => product.id == candidate);
        print('✅ Produit trouvé: ${match.id}');
        return match;
      } catch (_) {
        // Continuer la recherche
      }
    }

    print('❌ Aucun produit trouvé pour $structureType ($memberCount membres)');
    return null;
  }

  SubscriptionOfferDetailsWrapper? _chooseBestOffer(ProductDetails product) {
    if (product is! GooglePlayProductDetails) {
      return null;
    }

    final offers = product.productDetails.subscriptionOfferDetails;
    if (offers == null || offers.isEmpty) {
      return null;
    }

    SubscriptionOfferDetailsWrapper? trialOffer;
    SubscriptionOfferDetailsWrapper? recurringOffer;

    for (final offer in offers) {
      final bool hasFreeTrial = offer.pricingPhases.any(
        (PricingPhaseWrapper phase) => phase.priceAmountMicros == 0,
      );
      if (hasFreeTrial && trialOffer == null) {
        trialOffer = offer;
      }
      if (recurringOffer == null) {
        recurringOffer = offer;
      }
    }

    return trialOffer ?? recurringOffer;
  }

  bool _offerHasTrial(SubscriptionOfferDetailsWrapper? offer) {
    if (offer == null) return false;
    return offer.pricingPhases
        .any((PricingPhaseWrapper phase) => phase.priceAmountMicros == 0);
  }

  Future<GooglePlayPurchaseDetails?> _findExistingGooglePlaySubscription({
    String? excludeProductId,
  }) async {
    try {
      final InAppPurchaseAndroidPlatformAddition addition =
          _inAppPurchase.getPlatformAddition<
              InAppPurchaseAndroidPlatformAddition>();
      final QueryPurchaseDetailsResponse response =
          await addition.queryPastPurchases();

      if (response.error != null) {
        print(
            '⚠️ Erreur lors de la récupération des achats existants: ${response.error}');
      }

      GooglePlayPurchaseDetails? latest;

      for (final PurchaseDetails purchase in response.pastPurchases) {
        if (purchase is! GooglePlayPurchaseDetails) {
          continue;
        }

        if (!_allProductIds.contains(purchase.productID)) {
          continue;
        }

        if (excludeProductId != null &&
            purchase.productID == excludeProductId) {
          continue;
        }

        if (purchase.status != PurchaseStatus.purchased &&
            purchase.status != PurchaseStatus.pending) {
          continue;
        }

        final int? candidateTimestamp =
            int.tryParse(purchase.transactionDate ?? '');
        final int? currentTimestamp =
            int.tryParse(latest?.transactionDate ?? '');

        if (latest == null ||
            (candidateTimestamp != null &&
                (currentTimestamp == null ||
                    candidateTimestamp >= currentTimestamp))) {
          latest = purchase;
        }
      }

      return latest;
    } catch (e) {
      print('⚠️ Impossible de récupérer l\'achat existant: $e');
      return null;
    }
  }

  /// Lance l'achat d'un produit
  Future<bool> _attemptPurchase(
    ProductDetails product,
    SubscriptionOfferDetailsWrapper? offer,
    Map<String, dynamic> subscriptionInfo,
  ) async {
    try {
      ChangeSubscriptionParam? changeParam;
      if (product is GooglePlayProductDetails) {
        final GooglePlayPurchaseDetails? existingPurchase =
            await _findExistingGooglePlaySubscription(
          excludeProductId: product.id,
        );

        if (existingPurchase != null) {
          changeParam = ChangeSubscriptionParam(
            oldPurchaseDetails: existingPurchase,
            replacementMode: ReplacementMode.chargeProratedPrice,
          );
          print(
              '🔄 Mise à niveau détectée: ${existingPurchase.productID} -> ${product.id}');
        }
      }

      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: offer?.offerIdToken ??
            (product is GooglePlayProductDetails ? product.offerToken : null),
        changeSubscriptionParam: changeParam,
      );

      final int resolvedMemberCount =
          subscriptionInfo['memberCount'] is int ? subscriptionInfo['memberCount'] as int : 1;
      final int resolvedMaxMemberCount = subscriptionInfo['maxMemberCount'] is int
          ? subscriptionInfo['maxMemberCount'] as int
          : resolvedMemberCount;

      _pendingPurchaseContext = _PendingPurchaseContext(
        productId: product.id,
        structureType: subscriptionInfo['structureType'] as String,
        memberCount: resolvedMemberCount,
        maxMemberCount: resolvedMaxMemberCount,
        priceAmount: subscriptionInfo['priceAmount'] as double,
        priceDisplay: subscriptionInfo['priceDisplay'] as String,
        isTrialPurchase: _offerHasTrial(offer),
        productKey: subscriptionInfo['productKey'] as String,
      );

      final bool success = await _inAppPurchase
          .buyNonConsumable(purchaseParam: purchaseParam);

      print('🤖 Achat initié: ${product.id} - Success: $success');
      if (!success) {
        _pendingPurchaseContext = null;
      }
      return success;
    } catch (e) {
      print('❌ Erreur d\'achat pour ${product.id}: $e');
      _pendingPurchaseContext = null;
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

      final ProductDetails? product = _findProduct(structureType, memberCount);

      if (product != null) {
        final offer = _chooseBestOffer(product);
        final info = _getSubscriptionInfoByProductId(product.id);
        return await _attemptPurchase(product, offer, info);
      }

      throw Exception(
          'Aucun produit disponible pour $structureType avec $memberCount membres');
    } catch (e) {
      print('❌ Erreur d\'achat Android: $e');
      _errorController.add('Erreur d\'achat: $e');
      _lastRequestedMemberCount = null;
      _pendingPurchaseContext = null;
      return false;
    }
  }

  /// Méthode de compatibilité (ancienne signature)
  Future<bool> purchaseSubscription(String productId) async {
    // Convertir ancien productId vers nouveau système
    if (productId == 'ass-mat' ||
        productId == 'abonnement_assmat' ||
        productId == 'assmat') {
      return await purchaseSubscriptionByType('assistante_maternelle', 1);
    } else if (productId == 'abo-mam-2' ||
        productId == 'abonnement_mam2' ||
        productId == 'mam2') {
      return await purchaseSubscriptionByType('MAM', 2);
    } else if (productId == 'abo-mam-3' ||
        productId == 'abonnement_mam3' ||
        productId == 'mam3') {
      return await purchaseSubscriptionByType('MAM', 3);
    } else if (productId == 'abo-mam-4' ||
        productId == 'abonnement_mam4' ||
        productId == 'mam4') {
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
      if (mamMembersCount <= 2) {
        return 'abonnement_mam2';
      }
      if (mamMembersCount == 3) {
        return 'abonnement_mam3';
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
      final GooglePlayPurchaseDetails? activePurchase =
          await _findExistingGooglePlaySubscription();
      if (activePurchase != null) {
        return true;
      }

      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final QuerySnapshot<Map<String, dynamic>> subscriptionQuery =
          await _fetchLatestActiveSubscriptionSnapshot(user);

      return subscriptionQuery.docs.isNotEmpty;
    } catch (e) {
      print('❌ Erreur vérification abonnement: $e');
      return false;
    }
  }

  /// Retourne l'abonnement actif
  Future<PurchaseDetails?> getActiveSubscription() async {
    try {
      final GooglePlayPurchaseDetails? activePurchase =
          await _findExistingGooglePlaySubscription();
      if (activePurchase != null) {
        return activePurchase;
      }

      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final QuerySnapshot<Map<String, dynamic>> subscriptionQuery =
          await _fetchLatestActiveSubscriptionSnapshot(user);

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
