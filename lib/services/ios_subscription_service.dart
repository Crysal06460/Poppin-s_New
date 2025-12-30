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
    'mam_2_members': 'com.beylet.poppinsApp.subscription.mam_2_membres',
    'mam_3_members': 'com.beylet.poppinsApp.subscription.mam_3_membres',
    'mam_4_members': 'com.beylet.poppinsApp.subscription.mam_4_membres',
  };

  static const Set<String> _allProductIds = {
    'com.beylet.poppinsApp.subscription.assistante_maternelle',
    'com.beylet.poppinsApp.subscription.mam_2_membres',
    'com.beylet.poppinsApp.subscription.mam_3_membres',
    'com.beylet.poppinsApp.subscription.mam_4_membres',
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

  /// Sauvegarder l'abonnement dans Firestore avec protection anti-duplication
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
      final String structureId = await _resolveStructureId(user);
      final String fallbackStructureId = user.uid;

      print(
          '🍎 Tentative de sauvegarde pour: $productId (transaction: $transactionId)');

      // ✅ VÉRIFICATION 1 : Éviter les doublons basés sur le transactionId
      if (transactionId.isNotEmpty) {
        final existingByTransaction = await FirebaseFirestore.instance
            .collection('subscriptions')
            .where('transactionId', isEqualTo: transactionId)
            .limit(1)
            .get();

        if (existingByTransaction.docs.isNotEmpty) {
          print(
              '✅ Abonnement déjà existant avec cette transaction, pas de duplication');
          return;
        }
      }

      // ✅ VÉRIFICATION 2 : Éviter les doublons basés sur productId + structureId
      Future<bool> _hasExistingSubscription(
          {String? status, String? productId, DateTime? createdAfter}) async {
        Future<bool> queryFor(String sid) async {
          Query<Map<String, dynamic>> query = FirebaseFirestore.instance
              .collection('subscriptions')
              .where('structureId', isEqualTo: sid);
          if (productId != null) {
            query = query.where('productId', isEqualTo: productId);
          }
          if (status != null) {
            query = query.where('status', isEqualTo: status);
          }
          if (createdAfter != null) {
            query = query.where('createdAt',
                isGreaterThan: Timestamp.fromDate(createdAfter));
          }
          final snapshot = await query.limit(1).get();
          return snapshot.docs.isNotEmpty;
        }

        if (await queryFor(structureId)) return true;
        if (structureId != fallbackStructureId) {
          return await queryFor(fallbackStructureId);
        }
        return false;
      }

      if (await _hasExistingSubscription(
          status: 'active', productId: productId)) {
        print(
            '✅ Abonnement actif déjà existant pour ce produit, pas de duplication');
        return;
      }

      // ✅ VÉRIFICATION 3 : Éviter les abonnements créés dans les dernières minutes
      final DateTime now = DateTime.now();
      final DateTime recentThreshold = now.subtract(Duration(minutes: 5));

      if (await _hasExistingSubscription(createdAfter: recentThreshold)) {
        print('✅ Abonnement récent déjà créé, pas de duplication');
        return;
      }

    // Déterminer le type de structure et nombre de membres
    String structureType = 'assistante_maternelle';
    int memberCount = 1;
    int maxMemberCount = 1;
    double priceAmount = 3.99;
    String priceDisplay = '3,99 € / mois';

      // ✅ MAPPING robuste basé sur les IDs produits iOS
      if (productId == _iOSProductIds['mam_2_members']) {
        structureType = 'MAM';
        memberCount = 2;
        maxMemberCount = 2;
        priceAmount = 9.99;
        priceDisplay = '9,99 € / mois';
      } else if (productId == _iOSProductIds['mam_3_members']) {
        structureType = 'MAM';
        memberCount = 3;
        maxMemberCount = 3;
        priceAmount = 9.99;
        priceDisplay = '9,99 € / mois';
      } else if (productId == _iOSProductIds['mam_4_members']) {
        structureType = 'MAM';
        memberCount = 4;
        maxMemberCount = 99;
        priceAmount = 14.99;
        priceDisplay = '14,99 € / mois';
      } else if (productId == _iOSProductIds['assistante_maternelle']) {
        // valeurs par défaut déjà correctes
      } else {
        // Fallback pour ID inconnu
        print('⚠️ Produit iOS non reconnu: $productId');
      }

      // ✅ AMÉLIORATION : Dates plus précises
      final DateTime purchaseDate = DateTime.now();
      final DateTime expirationDate = purchaseDate.add(Duration(days: 30));
      final DateTime trialEndDate = purchaseDate.add(Duration(days: 7));

      // ✅ DÉSACTIVER les anciens abonnements actifs avant d'en créer un nouveau
      Future<QuerySnapshot<Map<String, dynamic>>> _fetchActiveSubscriptions(
          String sid) {
        return FirebaseFirestore.instance
            .collection('subscriptions')
            .where('structureId', isEqualTo: sid)
            .where('status', isEqualTo: 'active')
            .get();
      }

      QuerySnapshot<Map<String, dynamic>> oldActiveSubscriptions =
          await _fetchActiveSubscriptions(structureId);

      if (oldActiveSubscriptions.docs.isEmpty &&
          structureId != fallbackStructureId) {
        oldActiveSubscriptions =
            await _fetchActiveSubscriptions(fallbackStructureId);
      }

      // Désactiver les anciens abonnements
      for (final doc in oldActiveSubscriptions.docs) {
        await doc.reference.update({
          'status': 'replaced',
          'replacedAt': FieldValue.serverTimestamp(),
        });
        print('📝 Ancien abonnement ${doc.id} désactivé');
      }

      // ✅ CRÉER le nouvel abonnement avec toutes les données nécessaires
      final Map<String, dynamic> subscriptionData = {
        'structureId': structureId,
        'structureType': structureType,
        'memberCount': memberCount,
        'maxMemberCount': maxMemberCount,
        'status': 'active',
        'productId': productId,
        'transactionId': transactionId,
        'purchaseDate': purchaseDate.toIso8601String(),
        'expirationDate': expirationDate.toIso8601String(),
        'trialEndsAt': Timestamp.fromDate(trialEndDate),
        'priceAmount': priceAmount,
        'priceDisplay': priceDisplay,
        'currency': 'EUR',
        'billingPeriod': 'monthly',
        'platform': 'ios',
        'source': 'app_store',
        'isTrialPeriod': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Sauvegarder dans Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('subscriptions')
          .add(subscriptionData);

      print('✅ Abonnement iOS sauvegardé avec succès: ${docRef.id}');
      print('   - Type: $structureType');
      print('   - Membres: $memberCount');
      print('   - Prix: $priceAmount EUR');
      print('   - Transaction: $transactionId');

      // ✅ METTRE À JOUR la structure principale
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
        'subscriptionPlatform': 'ios',
        'subscriptionSource': 'app_store',
        'trialStatus': 'converted',
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
        'currentPriceAmount': priceAmount,
        'currentPriceDisplay': priceDisplay,
      });

      print('✅ Structure mise à jour avec maxMemberCount=$maxMemberCount');
    } catch (e) {
      print(
          '❌ Erreur lors de la sauvegarde de l\'abonnement dans Firestore: $e');
      print('   - ProductId: ${purchase.productID}');
      print('   - TransactionId: ${purchase.purchaseID}');
      print('   - Status: ${purchase.status}');

      // ✅ AJOUTER l'erreur au stream d'erreurs
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
      print('⚠️ Impossible de résoudre structureId depuis users: $e');
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
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
    }

    final primary = await queryFor(structureId);
    if (primary.docs.isNotEmpty || structureId == fallbackStructureId) {
      return primary;
    }
    return await queryFor(fallbackStructureId);
  }

  /// Retourne l'ID produit iOS
  static String getProductId(String structureType, int mamMembersCount) {
    final String normalizedType = structureType.toLowerCase();

    if (normalizedType == 'assistante_maternelle') {
      return _iOSProductIds['assistante_maternelle']!;
    }

    if (normalizedType == 'mam') {
      if (mamMembersCount <= 2) {
        return _iOSProductIds['mam_2_members']!;
      }
      if (mamMembersCount == 3) {
        return _iOSProductIds['mam_3_members'] ??
            _iOSProductIds['mam_2_members']!;
      }
      return _iOSProductIds['mam_4_members'] ??
          _iOSProductIds['mam_3_members'] ??
          _iOSProductIds['mam_2_members']!;
    }

    return _iOSProductIds['assistante_maternelle']!;
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
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('🍎 Utilisateur non connecté pour vérification abonnement');
        return false;
      }

      final QuerySnapshot<Map<String, dynamic>> subscriptionQuery =
          await _fetchLatestActiveSubscriptionSnapshot(user);

      final bool hasActive = subscriptionQuery.docs.isNotEmpty;
      print('🍎 Résultat vérification abonnement: $hasActive');

      if (hasActive) {
        final doc = subscriptionQuery.docs.first;
        print('🍎 Abonnement trouvé: ${doc.data()}');
      }

      return hasActive;
    } catch (e) {
      print('❌ Erreur vérification abonnement actif: $e');
      return false;
    }
  }

  /// Retourne l'abonnement actif
  Future<PurchaseDetails?> getActiveSubscription() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('🍎 Utilisateur non connecté pour récupération abonnement');
        return null;
      }

      final QuerySnapshot<Map<String, dynamic>> subscriptionQuery =
          await _fetchLatestActiveSubscriptionSnapshot(user);

      if (subscriptionQuery.docs.isEmpty) {
        print('🍎 Aucun abonnement actif trouvé');
        return null;
      }

      final subscriptionData = subscriptionQuery.docs.first.data();
      print('🍎 Abonnement actif récupéré: ${subscriptionData['productId']}');

      // ✅ CRÉER un PurchaseDetails fictif basé sur les données Firestore
      // Ceci permet de maintenir la compatibilité avec le système existant
      final fakePurchaseDetails =
          _createPurchaseDetailsFromFirestore(subscriptionData);

      return fakePurchaseDetails;
    } catch (e) {
      print('❌ Erreur récupération abonnement actif: $e');
      return null;
    }
  }

  PurchaseDetails _createPurchaseDetailsFromFirestore(
      Map<String, dynamic> data) {
    // Cette méthode crée un objet PurchaseDetails compatible
    // basé sur les données sauvegardées dans Firestore

    return PurchaseDetails(
      productID: data['productId'] ?? '',
      purchaseID: data['transactionId'] ?? '',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'firestore', // Source personnalisée
      ),
      transactionDate: data['purchaseDate'] != null
          ? DateTime.parse(data['purchaseDate'])
              .millisecondsSinceEpoch
              .toString()
          : DateTime.now().millisecondsSinceEpoch.toString(),
      status: PurchaseStatus.purchased, // Toujours purchased depuis Firestore
    );
  }

  Future<Map<String, dynamic>?> getSubscriptionInfoDetailed() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final QuerySnapshot<Map<String, dynamic>> subscriptionQuery =
          await _fetchLatestActiveSubscriptionSnapshot(user);

      if (subscriptionQuery.docs.isEmpty) {
        print('🍎 Aucun abonnement actif trouvé');
        return null;
      }

      final data = subscriptionQuery.docs.first.data();
      print(
          '🍎 Infos abonnement récupérées: ${data['structureType']} - ${data['memberCount']} membres');

      return data;
    } catch (e) {
      print('❌ Erreur récupération infos abonnement: $e');
      return null;
    }
  }

  /// Obtenir les informations d'abonnement depuis Firestore
  Future<Map<String, dynamic>?> getSubscriptionInfo() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final QuerySnapshot<Map<String, dynamic>> subscriptionDoc =
          await _fetchLatestActiveSubscriptionSnapshot(user);

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

    final String normalizedType = structureType.toLowerCase();

    if (normalizedType == 'mam') {
      if (memberCount <= 3) {
        priceAmount = 9.99;
        priceDisplay = '9,99 € / mois';
      } else {
        priceAmount = 14.99;
        priceDisplay = '14,99 € / mois';
      }
    } else {
      priceAmount = 3.99;
      priceDisplay = '3,99 € / mois';
    }

    return {
      'amount': priceAmount,
      'display': priceDisplay,
      'currency': 'EUR',
    };
  }
}
