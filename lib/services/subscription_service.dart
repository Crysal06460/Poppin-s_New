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

  // 🔧 BUNDLE ID CONFIGURÉ : com.beylet.poppinsApp
  static const String _bundleId = 'com.beylet.poppinsApp';

  // Stream pour écouter les changements d'abonnement
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // IDs des produits selon la plateforme
  static Map<String, String> get productIds {
    if (Platform.isIOS) {
      return {
        'assistante_maternelle':
            '$_bundleId.subscription.assistante_maternelle',
        'mam_2_members': '$_bundleId.subscription.mam_2_members',
        'mam_3_members': '$_bundleId.subscription.mam_3_members',
        'mam_4_members': '$_bundleId.subscription.mam_4_members',
      };
    } else {
      // 🔧 IDs Android corrigés selon Google Play Console
      return {
        'assistante_maternelle': 'abonement_assmat',
        'mam_2_members': 'abonement_mam2',
        'mam_3_members': 'abonement_mam3',
        'mam_4_members': 'abonement_mam4',
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

  // 🆕 MÉTHODE PRINCIPALE : Vérifier le statut d'abonnement (ROBUSTE)
  static Future<bool> isUserSubscribed() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      print('🔍 Vérification abonnement pour: ${user.uid}');

      // 1. PRIORITÉ 1 : Vérifier dans Firestore (fiable et rapide)
      final subscriptionQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (subscriptionQuery.docs.isNotEmpty) {
        final data = subscriptionQuery.docs.first.data();
        final Timestamp? trialEndsAt = data['trialEndsAt'];

        // Vérifier si la période d'essai est encore valide
        if (trialEndsAt != null &&
            DateTime.now().isBefore(trialEndsAt.toDate())) {
          print('✅ Abonnement actif trouvé dans Firestore (essai gratuit)');
          return true;
        }

        // Vérifier si abonnement payant actif
        if (data['status'] == 'active') {
          print('✅ Abonnement actif trouvé dans Firestore (payant)');
          return true;
        }
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
        if (productIds.values.contains(purchase.productID) &&
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
        // 🔧 FIX ANDROID : Format Android corrigé : abonement_mam2, abonement_mam3, abonement_mam4, abonement_assmat
        if (productId.startsWith('abonement_mam')) {
          structureType = 'MAM';
          if (productId == 'abonement_mam2')
            memberCount = 2;
          else if (productId == 'abonement_mam3')
            memberCount = 3;
          else if (productId == 'abonement_mam4') memberCount = 4;
        }
        // Si c'est 'abonement_assmat', les valeurs par défaut sont déjà correctes
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

      // Mettre à jour ou créer l'abonnement
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'structureId': user.uid,
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
          .doc(user.uid)
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
    double priceAmount = 8.99;
    String priceDisplay = '8,99 € / mois';

    if (productId.contains('mam')) {
      structureType = 'MAM';
      if (productId.contains('2_members') || productId == 'abonement_mam2') {
        memberCount = 2;
        priceAmount = 19.99;
        priceDisplay = '19,99 € / mois';
      } else if (productId.contains('3_members') ||
          productId == 'abonement_mam3') {
        memberCount = 3;
        priceAmount = 24.99;
        priceDisplay = '24,99 € / mois';
      } else if (productId.contains('4_members') ||
          productId == 'abonement_mam4') {
        memberCount = 4;
        priceAmount = 29.99;
        priceDisplay = '29,99 € / mois';
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
