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

  /// Initialise le service selon la plateforme
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Platform.isIOS) {
        print('🍎 Initialisation du service iOS...');
        _iOSService = iOSSubscriptionService.instance;
        await _iOSService!.initialize();

        // Écoute les événements iOS
        _platformSubscription = _iOSService!.subscriptionUpdates.listen(
          (purchase) {
            _subscriptionController.add(_mapPurchaseToSubscription(purchase));
          },
          onError: (error) {
            _errorController.add('iOS Error: $error');
          },
        );

        _iOSService!.errors.listen(
          (error) => _errorController.add('iOS: $error'),
        );
      } else if (Platform.isAndroid) {
        print('🤖 Initialisation du service Android...');
        _androidService = AndroidSubscriptionService.instance;
        await _androidService!.initialize();

        // Écoute les événements Android
        _platformSubscription = _androidService!.subscriptionUpdates.listen(
          (purchase) {
            _subscriptionController.add(_mapPurchaseToSubscription(purchase));
          },
          onError: (error) {
            _errorController.add('Android Error: $error');
          },
        );

        _androidService!.errors.listen(
          (error) => _errorController.add('Android: $error'),
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

  /// Mappe les données de PurchaseDetails vers SubscriptionInfo
  SubscriptionInfo _mapPurchaseToSubscription(PurchaseDetails purchase) {
    return SubscriptionInfo(
      productId: purchase.productID,
      localizedPrice: _getPriceFromProductId(purchase.productID),
      status: _mapPurchaseStatus(purchase.status),
      purchaseDate: DateTime.now(), // TODO: extraire la vraie date d'achat
      expiryDate: null, // TODO: calculer la date d'expiration
      isTrialPeriod: _isTrialPeriod(purchase.productID),
    );
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
    // Logique pour déterminer si c'est un essai
    // Pour le moment, on considère que tous les nouveaux achats sont des essais
    return true;
  }

  /// Retourne le prix à partir du productId
  String _getPriceFromProductId(String productId) {
    if (productId.contains('assistante_maternelle')) return '12,99€';
    if (productId.contains('mam_2_members')) return '24,99€';
    if (productId.contains('mam_3_members')) return '34,99€';
    if (productId.contains('mam_4_members')) return '44,99€';
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

  /// Achète un abonnement
  Future<bool> purchaseSubscription(SubscriptionPlan plan) async {
    await _ensureInitialized();

    try {
      final productId = _getProductId(plan);

      if (Platform.isIOS) {
        return await _iOSService!.purchaseSubscription(productId);
      } else if (Platform.isAndroid) {
        return await _androidService!.purchaseSubscription(productId);
      }
      return false;
    } catch (e) {
      _errorController.add('Erreur d\'achat: $e');
      return false;
    }
  }

  /// Restaure les achats
  Future<void> restorePurchases() async {
    await _ensureInitialized();

    try {
      if (Platform.isIOS) {
        await _iOSService!.restorePurchases();
      } else if (Platform.isAndroid) {
        await _androidService!.restorePurchases();
      }
    } catch (e) {
      _errorController.add('Erreur de restauration: $e');
      rethrow;
    }
  }

  /// Vérifie le statut d'un abonnement
  Future<SubscriptionInfo?> checkSubscriptionStatus(
      SubscriptionPlan plan) async {
    await _ensureInitialized();

    try {
      final productId = _getProductId(plan);
      PurchaseDetails? purchase;

      if (Platform.isIOS) {
        purchase = await _iOSService!.checkSubscriptionStatus(productId);
      } else if (Platform.isAndroid) {
        purchase = await _androidService!.checkSubscriptionStatus(productId);
      }

      return purchase != null ? _mapPurchaseToSubscription(purchase) : null;
    } catch (e) {
      _errorController.add('Erreur de vérification: $e');
      return null;
    }
  }

  /// Retourne l'ID produit selon la plateforme et le plan
  String _getProductId(SubscriptionPlan plan) {
    final structureType = _planToStructureType(plan);
    final memberCount = _planToMemberCount(plan);

    if (Platform.isIOS) {
      return iOSSubscriptionService.getProductId(structureType, memberCount);
    } else {
      return AndroidSubscriptionService.getProductId(
          structureType, memberCount);
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

  /// Nettoie les ressources
  void dispose() {
    _platformSubscription?.cancel();
    _subscriptionController.close();
    _errorController.close();
    _iOSService?.dispose();
    _androidService?.dispose();
    _isInitialized = false;
  }

  /// Méthodes de commodité pour vérifier les abonnements actifs
  Future<bool> hasActiveSubscription() async {
    await _ensureInitialized();

    if (Platform.isIOS) {
      return await _iOSService?.hasActiveSubscription() ?? false;
    } else {
      return await _androidService?.hasActiveSubscription() ?? false;
    }
  }

  Future<SubscriptionInfo?> getActiveSubscription() async {
    await _ensureInitialized();

    PurchaseDetails? purchase;

    if (Platform.isIOS) {
      purchase = await _iOSService?.getActiveSubscription();
    } else {
      purchase = await _androidService?.getActiveSubscription();
    }

    return purchase != null ? _mapPurchaseToSubscription(purchase) : null;
  }

  /// Vérifie si l'utilisateur est en période d'essai
  Future<bool> isInTrialPeriod() async {
    final activeSubscription = await getActiveSubscription();
    return activeSubscription?.isTrialPeriod ?? false;
  }
}
