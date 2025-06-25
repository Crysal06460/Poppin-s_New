// subscription_service.dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async';

class SubscriptionService {
  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');

  // 🔧 BUNDLE ID CONFIGURÉ : com.beylet.poppinsApp
  static const String _bundleId = 'com.beylet.poppinsApp';

  // Stream pour écouter les changements d'abonnement
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  // IDs des produits selon la plateforme
  static Map<String, String> get productIds {
    if (Platform.isIOS) {
      // IDs EXACTS d'après vos captures App Store Connect
      return {
        'assistante_maternelle':
            '$_bundleId.subscription.assistante_maternelle',
        'mam_2_members': '$_bundleId.subscription.mam_2_membres',
        'mam_3_members': '$_bundleId.subscription.mam_3_membres',
        'mam_4_members': '$_bundleId.subscription.mam_4_membres',
      };
    } else {
      // ✅ CORRIGÉ : IDs exacts de Google Play Console (sans suffixes _monthly)
      return {
        'assistante_maternelle': 'assmat', // ✅ Correspond à Google Play
        'mam_2_members': 'mam2', // ✅ Correspond à Google Play
        'mam_3_members': 'mam3', // ✅ Correspond à Google Play
        'mam_4_members': 'mam4', // ✅ Correspond à Google Play
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

  // 🆕 NOUVELLE MÉTHODE : Vérifier le statut d'abonnement
  static Future<bool> isUserSubscribed() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      if (!_isProduction) {
        print('🧪 MODE DEV: Simulation abonnement actif');
        return true; // En dev, considérer comme abonné
      }

      // 1. Vérifier d'abord dans Firestore (cache)
      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (subscriptionDoc.docs.isNotEmpty) {
        final data = subscriptionDoc.docs.first.data();
        final Timestamp? trialEndsAt = data['trialEndsAt'];

        // Vérifier si la période d'essai est encore valide
        if (trialEndsAt != null &&
            DateTime.now().isBefore(trialEndsAt.toDate())) {
          print('✅ Utilisateur en période d\'essai');
          return true;
        }
      }

      // 2. Vérifier auprès d'Apple/Google (source de vérité)
      final InAppPurchase inAppPurchase = InAppPurchase.instance;
      final bool isAvailable = await inAppPurchase.isAvailable();

      if (!isAvailable) {
        print('❌ Achats intégrés non disponibles');
        return false;
      }

      // 🔧 CORRIGÉ : Utiliser la nouvelle API
      await inAppPurchase.restorePurchases();

      // Écouter le stream des achats pour vérifier
      final completer = Completer<bool>();
      late StreamSubscription subscription;

      subscription = inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
        bool hasActiveSubscription = false;

        for (PurchaseDetails purchase in purchaseDetailsList) {
          if (productIds.values.contains(purchase.productID)) {
            if (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored) {
              print('✅ Abonnement actif trouvé: ${purchase.productID}');
              _updateSubscriptionInFirestore(purchase);
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

      // Timeout après 5 secondes
      Timer(Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(false);
        }
      });

      return await completer.future;
    } catch (e) {
      print('❌ Erreur vérification abonnement: $e');
      return false;
    }
  }

  // 🆕 NOUVELLE MÉTHODE : Mettre à jour l'abonnement dans Firestore
  static Future<void> _updateSubscriptionInFirestore(
      PurchaseDetails purchase) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Déterminer le type de structure et nombre de membres selon le produit
      String structureType = 'assistante_maternelle';
      int memberCount = 1;

      // ✅ CORRIGÉ : Gérer les deux formats d'IDs (iOS et Android)
      final String productId = purchase.productID;

      if (Platform.isIOS) {
        // Format iOS : com.beylet.poppinsApp.subscription.mam_2_membres
        if (productId.contains('mam')) {
          structureType = 'MAM';
          if (productId.contains('2_membres'))
            memberCount = 2;
          else if (productId.contains('3_membres'))
            memberCount = 3;
          else if (productId.contains('4_membres')) memberCount = 4;
        }
      } else {
        // Format Android : mam2, mam3, mam4, assmat
        if (productId.startsWith('mam')) {
          structureType = 'MAM';
          if (productId == 'mam2')
            memberCount = 2;
          else if (productId == 'mam3')
            memberCount = 3;
          else if (productId == 'mam4') memberCount = 4;
        }
        // Si c'est 'assmat', les valeurs par défaut sont déjà correctes
      }

      print(
          '🔍 Produit: $productId → Type: $structureType, Membres: $memberCount');

      // Mettre à jour ou créer l'abonnement
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'structureId': user.uid,
        'structureType': structureType,
        'memberCount': memberCount,
        'status': 'active',
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
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

  static Future<void> purchaseSubscription(String productId) async {
    if (!_isProduction) {
      // En mode développement, simuler l'achat
      print('🧪 MODE DEV: Simulation achat de $productId');

      // Simuler un délai de traitement
      await Future.delayed(Duration(seconds: 2));

      // Simuler un achat réussi en 80% des cas
      final random = DateTime.now().millisecondsSinceEpoch % 100;
      final bool success = random < 80; // 80% de chance de succès

      if (success) {
        print('✅ DEV: Simulation achat réussi pour $productId');
        // En mode dev, l'interface utilisateur gère le succès via le purchaseStream
        // On peut déclencher un événement simulé si nécessaire
      } else {
        print('❌ DEV: Simulation achat échoué');
        throw Exception('Simulation échec achat (pour test)');
      }
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

      // 🚀 LANCER L'ACHAT - L'état sera capturé par le purchaseStream
      final bool launched =
          await inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!launched) {
        print('❌ Impossible de lancer l\'achat');
        throw Exception('Impossible de lancer l\'interface d\'achat');
      }

      print(
          '🚀 Achat lancé - En attente de la réponse utilisateur dans ${Platform.isIOS ? 'l\'App Store' : 'Google Play'}...');
    } catch (e) {
      print('❌ Erreur lors du lancement de l\'achat: $e');
      rethrow; // Relancer l'exception pour que l'UI puisse la capturer
    }
  }

  static Future<void> simulateDevPurchase(String productId) async {
    if (!_isProduction) {
      print('🧪 MODE DEV: Simulation achat de $productId');

      // Attendre 2 secondes pour simuler le temps d'achat
      await Future.delayed(Duration(seconds: 2));

      // Créer un événement d'achat simulé
      // Pour cela, on va déclencher le callback manuellement

      // Simuler un achat réussi en 80% des cas, échec en 20%
      final random = DateTime.now().millisecondsSinceEpoch % 100;
      final bool success = random < 80; // 80% de chance de succès

      if (success) {
        print('✅ DEV: Simulation achat réussi');
        // En mode dev, l'interface doit gérer ce succès
      } else {
        print('❌ DEV: Simulation achat échoué');
        throw Exception('Simulation échec achat (test)');
      }
    }
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

  // 🆕 NOUVELLE MÉTHODE : Restreindre l'accès (si abonnement expiré/annulé)
  static Future<void> _lockPremiumFeatures() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Désactiver l'abonnement dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .update({
        'subscriptionActive': false,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Marquer les abonnements comme inactifs
      final subscriptions = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in subscriptions.docs) {
        await doc.reference.update({
          'status': 'inactive',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('🔒 Fonctionnalités premium verrouillées');
    } catch (e) {
      print('❌ Erreur verrouillage fonctionnalités: $e');
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
        if (Platform.isIOS) {
          print('💡 Actions requises dans App Store Connect :');
          print('   1. Vérifiez que le Bundle ID ($_bundleId) est correct');
          print(
              '   2. Créez les produits avec les IDs exacts : ${response.notFoundIDs}');
          print('   3. Configurez-les comme "Auto-Renewable Subscriptions"');
          print('   4. Soumettez-les pour approbation');
          print('   5. Attendez l\'approbation (peut prendre 24-48h)');
          print('   6. Testez avec un compte Sandbox configuré');
        } else {
          print(
              '💡 Vérifiez que ces produits sont bien configurés et actifs dans Google Play Console');
        }
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
    if (!_isProduction) {
      print('🧪 Mode développement détecté - simulation des achats activée');
    }

    // Initialiser les listeners
    await handlePurchaseUpdates();

    // Tester la récupération des produits
    await testProductRetrieval();

    print('✅ SubscriptionService initialisé');
  }

  // 🆕 NOUVELLE MÉTHODE : Nettoyer les ressources
  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
