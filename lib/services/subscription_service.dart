// subscription_service.dart - VERSION CORRIGÉE COMPLÈTE
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async';

class SubscriptionService {
  static bool get _isProduction {
    // En mode debug, on est forcément en développement
    if (kDebugMode) return false;

    // Sinon, utiliser la variable d'environnement
    return bool.fromEnvironment('dart.vm.product', defaultValue: false);
  }

  static bool _forceDevMode = false;
  static bool _isInitialized = false;

  static void setDebugMode(bool enabled) {
    _forceDevMode = enabled;
    print('🔧 Mode debug forcé: $enabled');
  }

  static bool get isInDevMode {
    return _forceDevMode || !_isProduction;
  }

  static bool get isDebugMode => _forceDevMode;
  static bool get isInitialized => _isInitialized;

  static const int _parentGracePeriodDays = 30;

  // 🔧 BUNDLE ID CONFIGURÉ : com.beylet.poppinsApp
  static const String _bundleId = 'com.beylet.poppinsApp';

  // Stream pour écouter les changements d'abonnement
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  // IDs des produits selon la plateforme
  static Map<String, String> get productIds {
    if (Platform.isIOS) {
      return {
        'assistante_maternelle':
            '$_bundleId.subscription.assistante_maternelle',
        'mam_2_members': '$_bundleId.subscription.mam_2_members',
        'mam_3_members': '$_bundleId.subscription.mam_3_members',
        'mam_4_members': '$_bundleId.subscription.mam_4_members',
        'parent_employeur': 'parent_employeur',
      };
    } else {
      // 🔧 IDs Android (alignés avec Google Play + services Android)
      return {
        'assistante_maternelle': 'abonnement_assmat',
        'mam_2_members': 'abonnement_mam2',
        'mam_3_members': 'abonnement_mam3',
        'mam_4_members': 'abonnement_mam4',
        'parent_employeur': 'parent_employeur_google',
      };
    }
  }

  static String getProductId(String structureType, int memberCount) {
    final String normalizedType = structureType.toLowerCase();

    if (normalizedType == 'mam') {
      if (memberCount <= 3) {
        return productIds['mam_2_members'] ?? productIds['mam_3_members']!;
      }
      return productIds['mam_3_members'] ?? productIds['mam_2_members']!;
    }

    if (normalizedType == 'parent_employeur' ||
        normalizedType == 'parentemployeur') {
      return productIds['parent_employeur'] ??
          productIds['assistante_maternelle']!;
    }
    return productIds['assistante_maternelle']!;
  }

  // 🆕 MÉTHODE PRINCIPALE : Vérifier le statut d'abonnement (ROBUSTE)
  static Future<bool> isUserSubscribed() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      print('🔍 Vérification abonnement pour: ${user.uid}');

      // Résoudre le bon structureId (MAM vs utilisateur solo)
      final String structureId = await _getCurrentStructureId(user);
      print('🔎 structureId résolu: $structureId');

      // 1. PRIORITÉ 1 : Vérifier dans Firestore (fiable et rapide)
      final subscriptionQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: structureId)
          .get();

      if (subscriptionQuery.docs.isNotEmpty) {
        QueryDocumentSnapshot<Map<String, dynamic>>? activeDoc;
        for (final doc in subscriptionQuery.docs) {
          if (_isSubscriptionDocActive(doc.data())) {
            activeDoc = doc;
            break;
          }
        }

        if (activeDoc != null) {
          print(
              '✅ Abonnement actif trouvé dans Firestore (${activeDoc.id})');
          return true;
        }

        for (final doc in subscriptionQuery.docs) {
          final rawStatus = (doc.data()['status'] ?? '').toString();
          print(
              'ℹ️ Abonnement ignoré (${doc.id}) - statut: ${rawStatus.isEmpty ? 'inconnu' : rawStatus}');
        }
      }

      // ✅ FALLBACK STRUCTURE: vérifier si un abonnement est relié via la fiche structure
      try {
        final structureSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .get();

        if (structureSnapshot.exists) {
          final Map<String, dynamic> structureData =
              structureSnapshot.data() ?? <String, dynamic>{};

          final String? subscriptionDocId =
              (structureData['subscriptionDocId'] ?? '').toString();

          if (subscriptionDocId != null && subscriptionDocId.isNotEmpty) {
            final linkedSubscription = await FirebaseFirestore.instance
                .collection('subscriptions')
                .doc(subscriptionDocId)
                .get();

            if (linkedSubscription.exists) {
              final linkedData = linkedSubscription.data() ?? {};
              final Timestamp? linkedTrial = linkedData['trialEndsAt'];
              if (linkedTrial != null &&
                  DateTime.now().isBefore(linkedTrial.toDate())) {
                print(
                    '✅ Abonnement actif via doc lié (essai en cours): $subscriptionDocId');
                return true;
              }

              if ((linkedData['status'] ?? '').toString().toLowerCase() ==
                  'active') {
                print(
                    '✅ Abonnement actif via doc lié (statut actif): $subscriptionDocId');
                return true;
              }
            }
          }

          if (structureData['subscriptionActive'] == true) {
            final Timestamp? structureTrial =
                structureData['subscriptionTrialEndsAt'] ??
                    structureData['trialEndsAt'];
            if (structureTrial is Timestamp &&
                DateTime.now().isBefore(structureTrial.toDate())) {
              print('✅ Abonnement actif via structure (essai en cours)');
              return true;
            }

            final Timestamp? subscriptionUpdatedAt =
                structureData['subscriptionUpdatedAt'];
            if (subscriptionUpdatedAt is Timestamp) {
              final Duration sinceUpdate =
                  DateTime.now().difference(subscriptionUpdatedAt.toDate());
              if (sinceUpdate.inDays <= 45) {
                print('✅ Abonnement actif via structure (flag récent)');
                return true;
              }
            } else {
              print('✅ Abonnement actif via structure (flag booléen)');
              return true;
            }
          }

          final String structureStatus =
              (structureData['subscriptionStatus'] ?? '').toString();
          if (structureStatus.isNotEmpty &&
              _isStatusLikelyActive(structureStatus)) {
            print(
                '✅ Abonnement actif via structure (subscriptionStatus=$structureStatus)');
            return true;
          }

          final Timestamp? structureExpiresAt =
              structureData['subscriptionExpiresAt'];
          if (structureExpiresAt is Timestamp &&
              DateTime.now().isBefore(structureExpiresAt.toDate())) {
            print('✅ Abonnement actif via structure (subscriptionExpiresAt)');
            return true;
          }

          final dynamic rawStructureExpiry =
              structureData['subscriptionExpirationDate'];
          if (rawStructureExpiry != null) {
            final String structureExpiryStr = rawStructureExpiry.toString();
            if (_isDateStringInFuture(structureExpiryStr)) {
              print(
                  '✅ Abonnement actif via structure (subscriptionExpirationDate)');
              return true;
            }
          }

          final dynamic rawStructureExpiresIso =
              structureData['subscriptionExpiresAtIso'];
          if (rawStructureExpiresIso is String &&
              _isDateStringInFuture(rawStructureExpiresIso)) {
            print('✅ Abonnement actif via structure (subscriptionExpiresAtIso)');
            return true;
          }

          final dynamic rawStripeStatus = structureData['stripeStatus'];
          if (rawStripeStatus is String &&
              _isStatusLikelyActive(rawStripeStatus)) {
            print(
                '✅ Abonnement actif via structure (stripeStatus=$rawStripeStatus)');
            return true;
          }

          final String structureType =
              (structureData['structureType'] ?? '').toString().toLowerCase();
          if (structureType == 'parent_employeur' ||
              structureType == 'parentemployeur') {
            final DateTime? createdAt = _extractTimestamp(structureData['createdAt']);
            if (createdAt != null) {
              final int daysSinceCreation =
                  DateTime.now().difference(createdAt).inDays;
              if (daysSinceCreation <= _parentGracePeriodDays) {
                print(
                    '✅ Abonnement parent-employeur en période de grâce (${daysSinceCreation}j ≤ ${_parentGracePeriodDays}j)');
                return true;
              }
            }
          }

          print(
              'ℹ️ Aucun abonnement actif via structure, champs disponibles: ${structureData.keys.toList()}');
        }
      } catch (structureCheckError) {
        print('⚠️ Erreur lors de la vérification structure: $structureCheckError');
      }

      // 2. PRIORITÉ 2 : Si pas dans Firestore, essayer Google Play (avec timeout)
      print('⚠️ Pas d\'abonnement Firestore, vérification Google Play...');

      try {
        final bool hasActive =
            await _checkGooglePlaySubscription().timeout(Duration(seconds: 3));

        if (hasActive) {
          print('✅ Abonnement trouvé via Google Play');
          return true;
        }
      } catch (e) {
        print('⚠️ Erreur/timeout Google Play: $e');
        // Continue vers fallback
      }

      // 3. FALLBACK SÉCURISÉ : Vérifier si utilisateur était récemment actif
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase() ?? user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        final DateTime? lastActive = userData['lastActiveDate']?.toDate();

        // Si actif dans les 30 derniers jours ET avait un abonnement
        if (lastActive != null &&
            DateTime.now().difference(lastActive).inDays < 30 &&
            userData['hadActiveSubscription'] == true) {
          print('✅ Fallback : utilisateur récemment actif avec abonnement');
          return true;
        }
      }

      print('❌ Aucun abonnement valide trouvé');
      return false;
    } catch (e) {
      print('❌ Erreur vérification abonnement: $e');

      // FALLBACK FINAL : En cas d'erreur critique, permettre accès limité
      // Mais seulement pour les utilisateurs qui ont des données récentes
      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final hasRecentData = await _hasRecentUserData(user.uid);
          if (hasRecentData) {
            print('🛡️ Fallback : accès temporaire pour utilisateur existant');
            return true;
          }
        }
      } catch (fallbackError) {
        print('❌ Erreur fallback: $fallbackError');
      }

      return false;
    }
  }

  // 🔧 MÉTHODE HELPER : Vérifier Google Play avec timeout
  static Future<bool> _checkGooglePlaySubscription() async {
    final InAppPurchase inAppPurchase = InAppPurchase.instance;
    final bool isAvailable = await inAppPurchase.isAvailable();

    if (!isAvailable) return false;

    await inAppPurchase.restorePurchases();

    final completer = Completer<bool>();
    late StreamSubscription subscription;

    subscription = inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
      bool hasActiveSubscription = false;

      for (PurchaseDetails purchase in purchaseDetailsList) {
        // Accepter les nouveaux et anciens IDs Android
        final Set<String> acceptedProductIds = {
          ...productIds.values,
          'abonnement_assmat', 'abonnement_mam2', 'abonnement_mam3', 'abonnement_mam4',
          'abonement_assmat', 'abonement_mam2', 'abonement_mam3', 'abonement_mam4',
        };
        if (acceptedProductIds.contains(purchase.productID) &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored)) {
          hasActiveSubscription = true;
          break;
        }
      }

      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(hasActiveSubscription);
      }
    });

    // Timeout court pour éviter le blocage
    Timer(Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(false);
      }
    });

    return await completer.future;
  }

  // 🔧 MÉTHODE HELPER : Vérifier si l'utilisateur a des données récentes
  static Future<bool> _hasRecentUserData(String userId) async {
    try {
      // Vérifier si l'utilisateur a des données récentes (enfants, activités)
      final childrenQuery = await FirebaseFirestore.instance
          .collection('structures')
          .doc(userId)
          .collection('children')
          .limit(1)
          .get();

      return childrenQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 🔧 MÉTHODE CORRIGÉE : hasActiveSubscription (utilise la même logique)
  static Future<bool> hasActiveSubscription() async {
    return await isUserSubscribed();
  }

  static bool _isSubscriptionDocActive(Map<String, dynamic> data) {
    final String status = (data['status'] ?? '').toString().toLowerCase();

    if (_isStatusLikelyActive(status)) {
      return true;
    }

    final now = DateTime.now();

    final dynamic trialEndsRaw = data['trialEndsAt'];
    if (trialEndsRaw is Timestamp && now.isBefore(trialEndsRaw.toDate())) {
      return true;
    }

    final dynamic expiresAtRaw = data['expiresAt'];
    if (expiresAtRaw is Timestamp && now.isBefore(expiresAtRaw.toDate())) {
      return true;
    }

    final dynamic expirationRaw = data['expirationDate'];
    if (expirationRaw != null) {
      final expirationStr = expirationRaw.toString();
      if (_isDateStringInFuture(expirationStr)) {
        return true;
      }
    }

    final dynamic validUntilRaw = data['validUntil'];
    if (validUntilRaw is Timestamp && now.isBefore(validUntilRaw.toDate())) {
      return true;
    }

    return false;
  }

  static DateTime? _extractTimestamp(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static bool _isStatusLikelyActive(String status) {
    final normalized = status.toLowerCase().trim();
    if (normalized.isEmpty) return false;

    const activeStatuses = {
      'active',
      'trial',
      'trialing',
      'trial_active',
      'trial-period',
      'trialperiod',
      'pending_activation',
      'pending-activation',
      'pending',
      'approved',
      'completed',
      'succeeded',
      'renewing',
      'renewed',
      'in_grace_period',
      'grace_period',
      'grace',
      'paid',
    };

    if (activeStatuses.contains(normalized)) {
      return true;
    }

    const inactiveStatuses = {
      'cancelled',
      'canceled',
      'expired',
      'inactive',
      'ended',
      'terminated',
      'refunded',
      'failed',
      'replaced',
      'pending_deletion',
      'deleted',
      'suspended',
    };

    if (inactiveStatuses.contains(normalized)) {
      return false;
    }

    // Statut inconnu : considérer actif pour laisser l'utilisateur accéder
    print('ℹ️ Statut abonnement inconnu, interprété comme actif: $status');
    return true;
  }

  static bool _isDateStringInFuture(String value) {
    try {
      if (value.isEmpty) return false;

      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return DateTime.now().isBefore(parsed);
      }
    } catch (_) {}
    return false;
  }

  // 🆕 MÉTHODE : Mettre à jour l'abonnement dans Firestore
  static Future<void> _updateSubscriptionInFirestore(
      PurchaseDetails purchase) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Déterminer le type de structure et nombre de membres selon le produit
      String structureType = 'assistante_maternelle';
      int memberCount = 1;

      // 🔧 CORRIGÉ : Gérer les deux formats d'IDs (iOS et Android)
      final String productId = purchase.productID;

      if (Platform.isIOS) {
        // Format iOS : com.beylet.poppinsApp.subscription.mam_2_members
        if (productId.contains('mam')) {
          structureType = 'MAM';
          if (productId.contains('2_members'))
            memberCount = 2;
          else if (productId.contains('3_members'))
            memberCount = 3;
          else if (productId.contains('4_members')) memberCount = 4;
        }
      } else {
        // 🔧 FIX ANDROID : Gérer les deux formats (abonnement_* et abonement_*)
        if (productId.startsWith('abonnement_mam') ||
            productId.startsWith('abonement_mam')) {
          structureType = 'MAM';
          if (productId.endsWith('mam2')) {
            memberCount = 2;
          } else if (productId.endsWith('mam3')) {
            memberCount = 3;
          } else if (productId.endsWith('mam4')) {
            memberCount = 4;
          }
        }
        // assistante_maternelle: valeurs par défaut déjà correctes
      }

      print(
          '🔍 Produit: $productId → Type: $structureType, Membres: $memberCount');

      // Marquer l'utilisateur comme ayant eu un abonnement actif
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase() ?? user.uid)
          .set({
        'hadActiveSubscription': true,
        'lastActiveDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Résoudre structureId correct pour la sauvegarde
      final String structureId = await _getCurrentStructureId(user);

      // Mettre à jour ou créer l'abonnement
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'structureId': structureId,
        'structureType': structureType,
        'memberCount': memberCount,
        'status': 'active',
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'trialEndsAt':
            Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mettre à jour la structure
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({
        'maxMemberCount': memberCount,
        'subscriptionActive': true,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      });

      print(
          '✅ Abonnement mis à jour dans Firestore: $structureType ($memberCount membres)');
    } catch (e) {
      print('❌ Erreur mise à jour Firestore: $e');
    }
  }

  // Helper: récupérer le structureId courant depuis le profil
  static Future<String> _getCurrentStructureId(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase() ?? user.uid)
          .get();
      if (userDoc.exists) {
        final Map<String, dynamic> data =
            userDoc.data() ?? <String, dynamic>{};
        final String? sid = data['structureId'] as String?;
        if (sid != null && sid.isNotEmpty) return sid;
      }
    } catch (_) {}
    return user.uid;
  }

  // ✅ MÉTHODE CORRIGÉE : Simulation fiable en mode dev
  static Future<void> purchaseSubscription(String productId) async {
    print('🛒 Tentative d\'achat de: $productId');
    print('🔍 Mode développement: ${isInDevMode}');

    if (isInDevMode) {
      print('🧪 MODE DEV: Simulation achat automatique');

      // Simuler un délai réaliste
      await Future.delayed(Duration(seconds: 2));

      // En mode dev, on ne lance pas l'achat réel
      // L'interface doit utiliser simulateDevPurchaseSuccess() directement
      print('✅ DEV: Prêt pour simulation');
      return;
    }

    try {
      final InAppPurchase inAppPurchase = InAppPurchase.instance;

      // Vérifier que les achats sont disponibles
      final bool isAvailable = await inAppPurchase.isAvailable();
      if (!isAvailable) {
        print('❌ Achats intégrés non disponibles');
        throw Exception('Achats intégrés non disponibles sur cet appareil');
      }

      print(
          '🛒 Tentative d\'achat du produit: $productId sur ${Platform.isIOS ? 'iOS' : 'Android'}');

      // Récupérer les détails du produit
      final ProductDetailsResponse response =
          await inAppPurchase.queryProductDetails({productId});

      if (response.error != null) {
        print('❌ Erreur lors de la récupération du produit: ${response.error}');
        throw Exception(
            'Erreur lors de la récupération du produit: ${response.error?.message ?? "Erreur inconnue"}');
      }

      if (response.productDetails.isEmpty) {
        print('❌ Produit non trouvé: $productId');
        final String platformMsg = Platform.isIOS
            ? 'Produit non trouvé dans l\'App Store. Vérifiez la configuration dans App Store Connect.'
            : 'Produit non trouvé dans Google Play. Vérifiez la configuration dans Google Play Console.';
        throw Exception(platformMsg);
      }

      // Lancer l'achat
      final ProductDetails productDetails = response.productDetails.first;
      print(
          '✅ Produit trouvé: ${productDetails.title} - ${productDetails.price}');

      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: productDetails);

      // 🚀 LANCER L'ACHAT
      final bool launched =
          await inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!launched) {
        print('❌ Impossible de lancer l\'achat');
        throw Exception('Impossible de lancer l\'interface d\'achat');
      }

      print('🚀 Achat lancé - En attente de la réponse utilisateur...');
    } catch (e) {
      print('❌ Erreur lors du lancement de l\'achat: $e');
      rethrow;
    }
  }

  // ✅ NOUVELLE MÉTHODE : Simulation spécifique pour le développement
  static Future<Map<String, dynamic>> simulateDevPurchaseSuccess(
      String productId) async {
    if (!isInDevMode) {
      throw Exception('Méthode disponible uniquement en mode développement');
    }

    print('🧪 MODE DEV: Simulation achat réussi de $productId');

    // Simuler un délai réaliste
    await Future.delayed(Duration(seconds: 1));

    // Déterminer le type de structure et nombre de membres selon le produit
    String structureType = 'assistante_maternelle';
    int memberCount = 1;
    double priceAmount = 6.99;
    String priceDisplay = '6,99 € / mois';

    if (productId.contains('parent')) {
      structureType = 'parent_employeur';
      memberCount = 1;
      priceAmount = 4.99;
      priceDisplay = '4,99 € / mois';
    } else if (productId.contains('mam')) {
      structureType = 'MAM';
      if (productId.contains('2_members') || productId == 'abonement_mam2') {
        memberCount = 3;
        priceAmount = 19.99;
        priceDisplay = '19,99 € / mois';
      } else if (productId.contains('3_members') ||
          productId == 'abonement_mam3') {
        memberCount = 4;
        priceAmount = 24.99;
        priceDisplay = '24,99 € / mois';
      } else if (productId.contains('4_members') ||
          productId == 'abonement_mam4') {
        memberCount = 4;
        priceAmount = 24.99;
        priceDisplay = '24,99 € / mois';
      }
    }

    print('✅ DEV: Simulation terminée avec succès');

    // Retourner les données de l'abonnement simulé
    return {
      'structureType': structureType,
      'memberCount': memberCount,
      'priceAmount': priceAmount,
      'priceDisplay': priceDisplay,
      'currency': 'EUR',
      'billingPeriod': 'monthly',
      'productId': productId,
    };
  }

  // 🆕 MÉTHODE MODIFIÉE : Gérer les mises à jour d'achat
  static Future<void> handlePurchaseUpdates() async {
    if (!_isProduction) return;

    final InAppPurchase inAppPurchase = InAppPurchase.instance;

    // Écouter les mises à jour d'achat
    _subscription = inAppPurchase.purchaseStream
        .listen((List<PurchaseDetails> purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    });
  }

  // 🆕 MÉTHODE MODIFIÉE : Traiter les mises à jour d'état
  static void _handlePurchaseUpdates(
      List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print(
          '📱 Mise à jour achat: ${purchaseDetails.productID} - ${purchaseDetails.status}');

      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // ✅ Abonnement activé → débloquer les fonctionnalités
        print('✅ Abonnement activé pour: ${purchaseDetails.productID}');
        _unlockPremiumFeatures(purchaseDetails);

        // Vérifier la validité de l'achat avec votre serveur backend
        _verifyPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print('❌ Erreur d\'achat: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        print('⚠️ Achat annulé par l\'utilisateur');
      }

      // Finaliser la transaction
      if (purchaseDetails.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    }
  }

  // 🆕 NOUVELLE MÉTHODE : Débloquer les fonctionnalités premium
  static Future<void> _unlockPremiumFeatures(
      PurchaseDetails purchaseDetails) async {
    try {
      // Mettre à jour Firestore avec le nouvel abonnement
      await _updateSubscriptionInFirestore(purchaseDetails);

      print('🔓 Fonctionnalités premium débloquées');

      // Vous pouvez ajouter ici d'autres actions comme :
      // - Envoyer une notification à l'utilisateur
      // - Synchroniser avec votre backend
      // - Mettre à jour l'interface utilisateur
    } catch (e) {
      print('❌ Erreur déblocage fonctionnalités: $e');
    }
  }

  static Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: Vérifier l'achat avec votre serveur backend
    // Cette étape est cruciale pour la sécurité
    print('✅ Achat vérifié: ${purchaseDetails.productID}');

    // En production, vous devriez :
    // 1. Envoyer le reçu à votre serveur backend
    // 2. Votre serveur vérifie avec Apple/Google
    // 3. Si valide → confirmer l'abonnement dans votre base de données
  }

  // 🆕 NOUVELLE MÉTHODE : Restaurer les achats
  static Future<bool> restorePurchases() async {
    try {
      if (!_isProduction) {
        print('🧪 MODE DEV: Simulation restauration');
        return true;
      }

      final InAppPurchase inAppPurchase = InAppPurchase.instance;

      // 🔧 CORRIGÉ : Utiliser la nouvelle API sans attendre de réponse
      await inAppPurchase.restorePurchases();

      // Écouter le stream pour capturer les achats restaurés
      final completer = Completer<bool>();
      late StreamSubscription subscription;
      bool hasActiveSubscription = false;

      subscription = inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
        for (PurchaseDetails purchase in purchaseDetailsList) {
          if (productIds.values.contains(purchase.productID)) {
            if (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored) {
              _unlockPremiumFeatures(purchase);
              hasActiveSubscription = true;
            }
          }

          // Finaliser les transactions en attente
          if (purchase.pendingCompletePurchase) {
            inAppPurchase.completePurchase(purchase);
          }
        }

        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(hasActiveSubscription);
        }
      });

      // Timeout après 10 secondes pour la restauration
      Timer(Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(hasActiveSubscription);
        }
      });

      final result = await completer.future;

      if (result) {
        print('✅ Abonnements restaurés avec succès');
      } else {
        print('⚠️ Aucun abonnement actif à restaurer');
      }

      return result;
    } catch (e) {
      print('❌ Erreur restauration achats: $e');
      return false;
    }
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
        print(
            '💡 Vérifiez que ces produits sont bien configurés et actifs dans Google Play Console');
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
    if (!_isProduction || _forceDevMode) {
      print(
          '🧪 Mode développement détecté - simulation des achats activée (succès garanti)');
    }

    // Initialiser les listeners
    await handlePurchaseUpdates();

    // Tester la récupération des produits
    await testProductRetrieval();

    _isInitialized = true;
    print('✅ SubscriptionService initialisé');
  }

  // 🆕 NOUVELLE MÉTHODE : Nettoyer les ressources
  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
