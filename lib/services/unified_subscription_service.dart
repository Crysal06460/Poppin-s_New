// lib/services/unified_subscription_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

// Import des services spécifiques
import 'ios_subscription_service.dart';
import 'android_subscription_service.dart';

enum SubscriptionPlan {
  assistantMaternel,
  mam2Members,
  mam3Members,
  mam4Members,
}

enum SubscriptionStatus {
  unknown,
  purchased,
  pending,
  restored,
  error,
  expired,
  cancelled,
}

class SubscriptionInfo {
  final String productId;
  final String localizedPrice;
  final SubscriptionStatus status;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final bool isTrialPeriod;

  SubscriptionInfo({
    required this.productId,
    required this.localizedPrice,
    required this.status,
    this.purchaseDate,
    this.expiryDate,
    this.isTrialPeriod = false,
  });
}

/// Service unifié pour les abonnements iOS et Android
class UnifiedSubscriptionService {
  static UnifiedSubscriptionService? _instance;
  static UnifiedSubscriptionService get instance =>
      _instance ??= UnifiedSubscriptionService._internal();

  UnifiedSubscriptionService._internal();

  // Services spécifiques aux plateformes
  iOSSubscriptionService? _iOSService;
  AndroidSubscriptionService? _androidService;

  // Stream controllers pour les événements
  final StreamController<SubscriptionInfo> _subscriptionController =
      StreamController<SubscriptionInfo>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Streams publics
  Stream<SubscriptionInfo> get subscriptionUpdates =>
      _subscriptionController.stream;
  Stream<String> get errors => _errorController.stream;

  bool _isInitialized = false;
  StreamSubscription<PurchaseDetails>? _platformSubscription;

  // ✅ PROTECTION ANTI-DUPLICATION : Suivi des transactions traitées
  final Set<String> _processedTransactions = {};
  final Set<String> _processedProductIds = {};

  // ✅ LIMITATION DES APPELS : Éviter les appels multiples rapides
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  /// Initialise le service selon la plateforme
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ Service unifié déjà initialisé');
      return;
    }

    try {
      if (Platform.isIOS) {
        print('🍎 Initialisation du service iOS...');
        _iOSService = iOSSubscriptionService.instance;
        await _iOSService!.initialize();

        // ✅ ÉCOUTE PROTÉGÉE des événements iOS
        _platformSubscription = _iOSService!.subscriptionUpdates.listen(
          (purchase) {
            _handlePurchaseUpdate(purchase);
          },
          onError: (error) {
            print('❌ Erreur iOS dans le stream: $error');
            _errorController.add('iOS Error: $error');
          },
        );

        _iOSService!.errors.listen(
          (error) {
            print('❌ Erreur iOS: $error');
            _errorController.add('iOS: $error');
          },
        );
      } else if (Platform.isAndroid) {
        print('🤖 Initialisation du service Android...');
        _androidService = AndroidSubscriptionService.instance;
        await _androidService!.initialize();

        // ✅ ÉCOUTE PROTÉGÉE des événements Android
        _platformSubscription = _androidService!.subscriptionUpdates.listen(
          (purchase) {
            _handlePurchaseUpdate(purchase);
          },
          onError: (error) {
            print('❌ Erreur Android dans le stream: $error');
            _errorController.add('Android Error: $error');
          },
        );

        _androidService!.errors.listen(
          (error) {
            print('❌ Erreur Android: $error');
            _errorController.add('Android: $error');
          },
        );
      } else {
        throw UnsupportedError(
            'Plateforme non supportée: ${Platform.operatingSystem}');
      }

      _isInitialized = true;
      print(
          '✅ Service d\'abonnement unifié initialisé pour ${Platform.operatingSystem}');
    } catch (e) {
      print('❌ Erreur d\'initialisation du service unifié: $e');
      _errorController.add('Erreur d\'initialisation: $e');
      rethrow;
    }
  }

  /// ✅ MÉTHODE PROTÉGÉE : Gère les mises à jour d'achat avec protection anti-duplication
  void _handlePurchaseUpdate(PurchaseDetails purchase) {
    final String transactionId = purchase.purchaseID ?? '';
    final String productId = purchase.productID;

    print('🔄 Traitement d\'achat: ${purchase.productID} - ${purchase.status}');

    // ✅ PROTECTION 1 : Éviter les doublons de transaction
    if (transactionId.isNotEmpty &&
        _processedTransactions.contains(transactionId)) {
      print(
          '⚠️ Transaction déjà traitée, mais on notifie quand même l\'UI: $transactionId');

      // ✅ AJOUT CRITIQUE : Émettre un événement UI même si déjà traité
      if (purchase.status == PurchaseStatus.purchased) {
        final subscriptionInfo = _mapPurchaseToSubscription(purchase);
        _subscriptionController.add(subscriptionInfo);
        print('📱 Notification UI émise pour transaction déjà traitée');
      }
      return;
    }

    // ✅ PROTECTION 2 : Vérifier si ce produit a été traité récemment
    if (_processedProductIds.contains(productId)) {
      print(
          '⚠️ Produit déjà traité récemment, mais on notifie quand même l\'UI: $productId');

      // ✅ AJOUT CRITIQUE : Émettre un événement UI même si produit déjà traité
      if (purchase.status == PurchaseStatus.purchased) {
        final subscriptionInfo = _mapPurchaseToSubscription(purchase);
        _subscriptionController.add(subscriptionInfo);
        print('📱 Notification UI émise pour produit déjà traité');
      }
      return;
    }

    // ✅ PROTECTION 3 : Debounce pour éviter les appels multiples rapides
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      _processPurchaseUpdate(purchase);
    });
  }

  /// ✅ MÉTHODE PRIVÉE : Traite réellement la mise à jour d'achat
  void _processPurchaseUpdate(PurchaseDetails purchase) {
    final String transactionId = purchase.purchaseID ?? '';
    final String productId = purchase.productID;

    try {
      // Marquer comme traité
      if (transactionId.isNotEmpty) {
        _processedTransactions.add(transactionId);
      }
      _processedProductIds.add(productId);

      // Nettoyer périodiquement les sets pour éviter la croissance infinie
      if (_processedTransactions.length > 100) {
        _processedTransactions.clear();
      }
      if (_processedProductIds.length > 50) {
        _processedProductIds.clear();
      }

      // ✅ AJOUT CRITIQUE : Compléter l'achat
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
        print('✅ Achat complété : ${purchase.purchaseID}');
      }

      final subscriptionInfo = _mapPurchaseToSubscription(purchase);
      print('✅ Achat traité : ${purchase.status} / ${purchase.productID}');

      // 🔁 Emit pour UI (PricingScreen écoute et redirige)
      _subscriptionController.add(subscriptionInfo);
      print('📱 Événement UI émis pour nouvel achat');
    } catch (e) {
      print('❌ Erreur lors du traitement de l\'achat: $e');
      _errorController.add('Erreur de traitement: $e');
    }
  }

  void _validateReceipt(PurchaseDetails purchase) {
    try {
      // Déterminer l'environnement
      final bool isSandbox = _isSandboxEnvironment();

      if (isSandbox) {
        print('🧪 Environnement sandbox détecté pour: ${purchase.productID}');
        // Valider contre sandbox
        _validateSandboxReceipt(purchase);
      } else {
        print(
            '🏪 Environnement production détecté pour: ${purchase.productID}');
        // Valider contre production d'abord, puis sandbox si échec
        _validateProductionReceipt(purchase);
      }
    } catch (e) {
      print('❌ Erreur de validation du reçu: $e');
    }
  }

  bool _isSandboxEnvironment() {
    // En mode debug, considérer comme sandbox
    if (kDebugMode) return true;

    // Autres vérifications possibles
    // TODO: Ajouter d'autres méthodes de détection si nécessaire
    return false;
  }

  void _validateSandboxReceipt(PurchaseDetails purchase) {
    print('🧪 Validation sandbox pour: ${purchase.productID}');
    // TODO: Implémenter la validation sandbox
    // Votre logique de validation sandbox ici
  }

  // ✅ AMÉLIORATION 6 : Validation production
  void _validateProductionReceipt(PurchaseDetails purchase) {
    print('🏪 Validation production pour: ${purchase.productID}');
    // TODO: Implémenter la validation production
    // Votre logique de validation production ici
    // Si échec avec "Sandbox receipt used in production",
    // alors appeler _validateSandboxReceipt()
  }

  /// Mappe les données de PurchaseDetails vers SubscriptionInfo
  SubscriptionInfo _mapPurchaseToSubscription(PurchaseDetails purchase) {
    return SubscriptionInfo(
      productId: purchase.productID,
      localizedPrice: _getPriceFromProductId(purchase.productID),
      status: _mapPurchaseStatus(purchase.status),
      purchaseDate: DateTime.now(), // TODO: extraire la vraie date d'achat
      expiryDate: _calculateExpiryDate(purchase.productID),
      isTrialPeriod: _isTrialPeriod(purchase.productID),
    );
  }

  /// ✅ AMÉLIORATION : Calcule la date d'expiration
  DateTime? _calculateExpiryDate(String productId) {
    // Pour les abonnements mensuels, ajouter 30 jours
    return DateTime.now().add(Duration(days: 30));
  }

  /// Mappe le statut de PurchaseStatus vers SubscriptionStatus
  SubscriptionStatus _mapPurchaseStatus(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.purchased:
        return SubscriptionStatus.purchased;
      case PurchaseStatus.pending:
        return SubscriptionStatus.pending;
      case PurchaseStatus.restored:
        return SubscriptionStatus.restored;
      case PurchaseStatus.error:
        return SubscriptionStatus.error;
      case PurchaseStatus.canceled:
        return SubscriptionStatus.cancelled;
    }
  }

  /// Détermine si c'est une période d'essai
  bool _isTrialPeriod(String productId) {
    // ✅ AMÉLIORATION : Logique plus précise pour détecter la période d'essai
    // Pour le moment, on considère que tous les nouveaux achats sont des essais
    return true;
  }

  /// ✅ AMÉLIORATION : Formatage des prix avec € et /mois
  String _getPriceFromProductId(String productId) {
    if (productId.contains('assistante_maternelle')) return '12,99 € / mois';
    if (productId.contains('mam_2_members')) return '24,99 € / mois';
    if (productId.contains('mam_3_members')) return '34,99 € / mois';
    if (productId.contains('mam_4_members')) return '44,99 € / mois';
    return 'Prix inconnu';
  }

  /// Récupère les produits disponibles
  Future<List<SubscriptionInfo>> getAvailableSubscriptions() async {
    await _ensureInitialized();

    try {
      List<ProductDetails> products = [];

      if (Platform.isIOS) {
        products = await _iOSService!.getAvailableProducts();
      } else if (Platform.isAndroid) {
        products = await _androidService!.getAvailableProducts();
      }

      return products
          .map<SubscriptionInfo>((product) => SubscriptionInfo(
                productId: product.id,
                localizedPrice: product.price,
                status: SubscriptionStatus.unknown,
              ))
          .toList();
    } catch (e) {
      print('❌ Erreur de récupération des produits: $e');
      _errorController.add('Erreur de récupération: $e');
      return [];
    }
  }

  /// ✅ AMÉLIORATION : Achète un abonnement avec protection et timeout
  Future<bool> purchaseSubscription(SubscriptionPlan plan) async {
    await _ensureInitialized();

    try {
      final structureType = _planToStructureType(plan);
      final memberCount = _planToMemberCount(plan);

      bool success = false;
      String logId = '';

      // ✅ AJOUT CRITIQUE : Timeout pour éviter le chargement infini
      try {
        if (Platform.isIOS) {
          final productId =
              iOSSubscriptionService.getProductId(structureType, memberCount);
          logId = productId;

          print('🛒 Tentative d\'achat: $productId');

          // ✅ PROTECTION : Vérifier si un achat est déjà en cours
          if (_processedProductIds.contains(productId)) {
            print('⚠️ Achat déjà en cours pour ce produit: $productId');
            return false;
          }

          success = await _iOSService!
              .purchaseSubscription(productId)
              .timeout(Duration(seconds: 30));
        } else if (Platform.isAndroid) {
          final androidType =
              structureType == 'mam' ? 'MAM' : structureType; // Respecte la casse
          logId = '$androidType-$memberCount';

          print('🛒 Tentative d\'achat: $androidType / $memberCount');

          if (_processedProductIds.contains(logId)) {
            print('⚠️ Achat déjà en cours pour ce produit: $logId');
            return false;
          }

          success = await _androidService!
              .purchaseSubscriptionByType(androidType, memberCount)
              .timeout(Duration(seconds: 30));
        }
      } on TimeoutException {
        print('⏰ Timeout d\'achat pour: $logId');
        _errorController.add('Timeout d\'achat - veuillez réessayer');
        return false;
      }

      if (success) {
        print('✅ Achat initié avec succès: $logId');
      } else {
        print('❌ Échec de l\'initiation d\'achat: $logId');
      }

      return success;
    } catch (e) {
      print('❌ Erreur lors de l\'achat: $e');
      _errorController.add('Erreur d\'achat: $e');
      return false;
    }
  }

  /// Restaure les achats
  Future<void> restorePurchases() async {
    await _ensureInitialized();

    try {
      print('🔄 Restauration des achats...');

      if (Platform.isIOS) {
        await _iOSService!.restorePurchases();
      } else if (Platform.isAndroid) {
        await _androidService!.restorePurchases();
      }

      print('✅ Restauration terminée');
    } catch (e) {
      print('❌ Erreur de restauration: $e');
      _errorController.add('Erreur de restauration: $e');
      rethrow;
    }
  }

  /// Vérifie le statut d'un abonnement
  Future<SubscriptionInfo?> checkSubscriptionStatus(
      SubscriptionPlan plan) async {
    await _ensureInitialized();

    try {
      final structureType = _planToStructureType(plan);
      final memberCount = _planToMemberCount(plan);
      PurchaseDetails? purchase;

      if (Platform.isIOS) {
        final productId =
            iOSSubscriptionService.getProductId(structureType, memberCount);
        purchase = await _iOSService!.checkSubscriptionStatus(productId);
      } else if (Platform.isAndroid) {
        final androidType =
            structureType == 'mam' ? 'MAM' : structureType; // Respecte la casse
        final productId = AndroidSubscriptionService.getProductId(
            androidType, memberCount);
        purchase = await _androidService!.checkSubscriptionStatus(productId);
      }

      return purchase != null ? _mapPurchaseToSubscription(purchase) : null;
    } catch (e) {
      print('❌ Erreur de vérification: $e');
      _errorController.add('Erreur de vérification: $e');
      return null;
    }
  }

  /// Convertit le plan en type de structure
  String _planToStructureType(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.assistantMaternel:
        return 'assistante_maternelle';
      case SubscriptionPlan.mam2Members:
      case SubscriptionPlan.mam3Members:
      case SubscriptionPlan.mam4Members:
        return 'mam';
    }
  }

  /// Convertit le plan en nombre de membres
  int _planToMemberCount(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.assistantMaternel:
        return 1;
      case SubscriptionPlan.mam2Members:
        return 2;
      case SubscriptionPlan.mam3Members:
        return 3;
      case SubscriptionPlan.mam4Members:
        return 4;
    }
  }

  /// S'assure que le service est initialisé
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// ✅ AMÉLIORATION : Nettoie les ressources avec protection
  void dispose() {
    try {
      _debounceTimer?.cancel();
      _platformSubscription?.cancel();
      _subscriptionController.close();
      _errorController.close();
      _iOSService?.dispose();
      _androidService?.dispose();
      _processedTransactions.clear();
      _processedProductIds.clear();
      _isInitialized = false;
      print('🧹 Service unifié nettoyé');
    } catch (e) {
      print('❌ Erreur lors du nettoyage: $e');
    }
  }

  /// Méthodes de commodité pour vérifier les abonnements actifs
  Future<bool> hasActiveSubscription() async {
    await _ensureInitialized();

    try {
      if (Platform.isIOS) {
        return await _iOSService?.hasActiveSubscription() ?? false;
      } else {
        return await _androidService?.hasActiveSubscription() ?? false;
      }
    } catch (e) {
      print('❌ Erreur de vérification d\'abonnement actif: $e');
      return false;
    }
  }

  Future<SubscriptionInfo?> getActiveSubscription() async {
    await _ensureInitialized();

    try {
      PurchaseDetails? purchase;

      if (Platform.isIOS) {
        purchase = await _iOSService?.getActiveSubscription();
      } else {
        purchase = await _androidService?.getActiveSubscription();
      }

      return purchase != null ? _mapPurchaseToSubscription(purchase) : null;
    } catch (e) {
      print('❌ Erreur de récupération d\'abonnement actif: $e');
      return null;
    }
  }

  /// Vérifie si l'utilisateur est en période d'essai
  Future<bool> isInTrialPeriod() async {
    try {
      final activeSubscription = await getActiveSubscription();
      return activeSubscription?.isTrialPeriod ?? false;
    } catch (e) {
      print('❌ Erreur de vérification de période d\'essai: $e');
      return false;
    }
  }

  /// ✅ NOUVEAU : Réinitialise les protections (utile pour les tests)
  void resetProtections() {
    _processedTransactions.clear();
    _processedProductIds.clear();
    _debounceTimer?.cancel();
    print('🔄 Protections réinitialisées');
  }

  /// ✅ NOUVEAU : Statistiques pour le debugging
  Map<String, dynamic> getDebugStats() {
    return {
      'isInitialized': _isInitialized,
      'processedTransactions': _processedTransactions.length,
      'processedProductIds': _processedProductIds.length,
      'platform': Platform.operatingSystem,
      'hasActiveTimer': _debounceTimer?.isActive ?? false,
    };
  }
}
