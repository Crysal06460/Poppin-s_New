// lib/services/unified_subscription_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

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

  // Service Android uniquement (iOS utilise des méthodes statiques)
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
  StreamSubscription<Map<String, dynamic>>? _iOSSubscription;

  /// Initialise le service selon la plateforme
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Platform.isIOS) {
        print('🍎 Initialisation du service iOS natif...');

        // Initialise le service iOS statique
        await iOSNativeSubscriptionService.initialize();

        // Écoute les événements iOS avec purchaseStream
        _iOSSubscription = iOSNativeSubscriptionService.purchaseStream.listen(
          (event) {
            _handleIOSEvent(event);
          },
          onError: (error) {
            _errorController.add('iOS Error: $error');
          },
        );
      } else if (Platform.isAndroid) {
        print('🤖 Initialisation du service Android...');
        _androidService = AndroidSubscriptionService.instance;
        await _androidService!.initialize();

        // Écoute les événements Android
        _androidService!.subscriptionUpdates.listen(
          (subscription) {
            _subscriptionController.add(_mapAndroidSubscription(subscription));
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

  /// Gère les événements iOS
  void _handleIOSEvent(Map<String, dynamic> event) {
    final type = event['type'];

    switch (type) {
      case 'purchase_success':
        final data = event['data'] as Map<String, dynamic>;
        _subscriptionController.add(SubscriptionInfo(
          productId: data['productId'] ?? '',
          localizedPrice: _getPriceFromProductId(data['productId']),
          status: SubscriptionStatus.purchased,
          purchaseDate: data['purchaseDate'] != null
              ? DateTime.tryParse(data['purchaseDate'])
              : DateTime.now(),
          expiryDate: data['expirationDate'] != null
              ? DateTime.tryParse(data['expirationDate'])
              : null,
          isTrialPeriod: true, // Les 7 premiers jours
        ));
        break;

      case 'purchase_error':
        _errorController.add(event['message'] ?? 'Erreur d\'achat');
        break;

      case 'purchase_canceled':
        _errorController.add('Achat annulé par l\'utilisateur');
        break;

      case 'restore_complete':
        final purchases =
            event['purchases'] as List<Map<String, dynamic>>? ?? [];
        for (final purchase in purchases) {
          _subscriptionController.add(SubscriptionInfo(
            productId: purchase['productId'] ?? '',
            localizedPrice: _getPriceFromProductId(purchase['productId']),
            status: SubscriptionStatus.restored,
            purchaseDate: purchase['purchaseDate'] != null
                ? DateTime.tryParse(purchase['purchaseDate'])
                : DateTime.now(),
          ));
        }
        break;
    }
  }

  /// Retourne le prix à partir du productId
  String _getPriceFromProductId(String? productId) {
    if (productId == null) return 'Prix inconnu';

    if (productId.contains('assistante_maternelle')) return '12,99€';
    if (productId.contains('mam_2_members')) return '24,99€';
    if (productId.contains('mam_3_members')) return '34,99€';
    if (productId.contains('mam_4_members')) return '44,99€';

    return 'Prix inconnu';
  }

  /// Mappe les données Android vers le format unifié
  SubscriptionInfo _mapAndroidSubscription(dynamic androidSubscription) {
    return SubscriptionInfo(
      productId: androidSubscription.productID ?? '',
      localizedPrice: 'Prix Android', // TODO: récupérer le vrai prix
      status: _mapAndroidStatus(androidSubscription.status.toString()),
      purchaseDate: DateTime.now(), // TODO: récupérer la vraie date
      expiryDate: null, // TODO: calculer la date d'expiration
      isTrialPeriod: false, // TODO: détecter la période d'essai
    );
  }

  /// Mappe le statut Android
  SubscriptionStatus _mapAndroidStatus(String status) {
    switch (status) {
      case 'PurchaseStatus.purchased':
        return SubscriptionStatus.purchased;
      case 'PurchaseStatus.pending':
        return SubscriptionStatus.pending;
      case 'PurchaseStatus.restored':
        return SubscriptionStatus.restored;
      case 'PurchaseStatus.error':
        return SubscriptionStatus.error;
      case 'PurchaseStatus.canceled':
        return SubscriptionStatus.cancelled;
      default:
        return SubscriptionStatus.unknown;
    }
  }

  /// Récupère les produits disponibles
  Future<List<SubscriptionInfo>> getAvailableSubscriptions() async {
    await _ensureInitialized();

    try {
      if (Platform.isIOS) {
        final products = await iOSNativeSubscriptionService.getProductsInfo();
        return products
            .map<SubscriptionInfo>((product) => SubscriptionInfo(
                  productId: product['productId'] ?? '',
                  localizedPrice: product['price'] ?? '',
                  status: SubscriptionStatus.unknown,
                ))
            .toList();
      } else if (Platform.isAndroid) {
        final products = await _androidService!.getAvailableProducts();
        return products
            .map<SubscriptionInfo>((product) => SubscriptionInfo(
                  productId: product.id,
                  localizedPrice: product.price,
                  status: SubscriptionStatus.unknown,
                ))
            .toList();
      }
      return [];
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
      if (Platform.isIOS) {
        final productKey = _getIOSProductKey(plan);
        await iOSNativeSubscriptionService.purchaseSubscription(productKey);
        return true; // Le callback gérera le résultat
      } else if (Platform.isAndroid) {
        final productId = _getAndroidProductId(plan);
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
        await iOSNativeSubscriptionService.restorePurchases();
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
      if (Platform.isIOS) {
        final status =
            await iOSNativeSubscriptionService.checkSubscriptionStatus();
        if (status != null && status['isActive'] == true) {
          return SubscriptionInfo(
            productId: status['productId'] ?? '',
            localizedPrice: _getPriceFromProductId(status['productId']),
            status: SubscriptionStatus.purchased,
            expiryDate: status['expirationDate'] != null
                ? DateTime.tryParse(status['expirationDate'])
                : null,
          );
        }
      } else if (Platform.isAndroid) {
        final productId = _getAndroidProductId(plan);
        final status =
            await _androidService!.checkSubscriptionStatus(productId);
        return status != null ? _mapAndroidSubscription(status) : null;
      }
      return null;
    } catch (e) {
      _errorController.add('Erreur de vérification: $e');
      return null;
    }
  }

  /// Retourne la clé produit iOS
  String _getIOSProductKey(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.assistantMaternel:
        return 'assistante_maternelle';
      case SubscriptionPlan.mam2Members:
        return 'mam_2_members';
      case SubscriptionPlan.mam3Members:
        return 'mam_3_members';
      case SubscriptionPlan.mam4Members:
        return 'mam_4_members';
    }
  }

  /// Retourne l'ID produit Android
  String _getAndroidProductId(SubscriptionPlan plan) {
    final structureType = _planToStructureType(plan);
    final memberCount = _planToMemberCount(plan);
    return AndroidSubscriptionService.getProductId(structureType, memberCount);
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
    _iOSSubscription?.cancel();
    _subscriptionController.close();
    _errorController.close();
    _isInitialized = false;
  }

  /// Méthodes de commodité pour vérifier les abonnements actifs
  Future<bool> hasActiveSubscription() async {
    if (Platform.isIOS) {
      final status =
          await iOSNativeSubscriptionService.checkSubscriptionStatus();
      return status?['isActive'] == true;
    } else {
      return await _androidService?.hasActiveSubscription() ?? false;
    }
  }

  Future<SubscriptionInfo?> getActiveSubscription() async {
    if (Platform.isIOS) {
      final status =
          await iOSNativeSubscriptionService.checkSubscriptionStatus();
      if (status != null && status['isActive'] == true) {
        return SubscriptionInfo(
          productId: status['productId'] ?? '',
          localizedPrice: _getPriceFromProductId(status['productId']),
          status: SubscriptionStatus.purchased,
          expiryDate: status['expirationDate'] != null
              ? DateTime.tryParse(status['expirationDate'])
              : null,
        );
      }
    } else {
      final subscription = await _androidService?.getActiveSubscription();
      return subscription != null
          ? _mapAndroidSubscription(subscription)
          : null;
    }
    return null;
  }

  /// Vérifie si l'utilisateur est en période d'essai
  Future<bool> isInTrialPeriod() async {
    final activeSubscription = await getActiveSubscription();
    return activeSubscription?.isTrialPeriod ?? false;
  }
}
