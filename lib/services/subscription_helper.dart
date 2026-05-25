// lib/services/subscription_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'unified_subscription_service.dart';
import 'firebase_trial_service.dart';

class SubscriptionHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final UnifiedSubscriptionService _subscriptionService =
      UnifiedSubscriptionService.instance;

  /// Résout le structureId réel depuis le profil utilisateur
  static Future<String> _resolveStructureId() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email?.toLowerCase() ?? user.uid)
          .get();
      if (userDoc.exists) {
        final sid = userDoc.data()?['structureId'] as String?;
        if (sid != null && sid.trim().isNotEmpty) return sid.trim();
      }
    } catch (_) {}
    return user.uid;
  }

  /// Vérifie si l'utilisateur a un abonnement actif et retourne les détails
  static Future<Map<String, dynamic>> getSubscriptionInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'hasActiveSubscription': false,
          'error': 'Utilisateur non connecté'
        };
      }

      // 🔧 CORRECTION : Résoudre le vrai structureId (pas juste user.uid)
      final String structureId = await _resolveStructureId();

      // Vérifier dans Firestore
      QuerySnapshot<Map<String, dynamic>> subscriptionQuery = await _firestore
          .collection('subscriptions')
          .where('structureId', isEqualTo: structureId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (subscriptionQuery.docs.isEmpty) {
        subscriptionQuery = await _firestore
            .collection('subscriptions')
            .where('structureId', isEqualTo: structureId)
            .where('status', isEqualTo: 'trial')
            .limit(1)
            .get();
      }

      if (subscriptionQuery.docs.isEmpty) {
        subscriptionQuery = await _firestore
            .collection('subscriptions')
            .where('structureId', isEqualTo: structureId)
            .limit(1)
            .get();
      }

      if (subscriptionQuery.docs.isEmpty) {
        return {'hasActiveSubscription': false};
      }

      final subscriptionDoc = subscriptionQuery.docs.first;
      final subscriptionData = subscriptionDoc.data();

      final TrialStatus trialStatus =
          TrialStatus.fromSubscriptionDoc(subscriptionData);
      final bool isTrialPeriod = (subscriptionData['isTrialPeriod'] == true) ||
          trialStatus.normalizedStatus == 'trial';

      DateTime? expirationDate;
      bool isExpired = false;
      if (isTrialPeriod) {
        expirationDate = trialStatus.endAt;
        isExpired = trialStatus.isExpired;
      } else {
        final String expirationDateStr =
            (subscriptionData['expirationDate'] ?? '').toString();
        if (expirationDateStr.isNotEmpty) {
          expirationDate = DateTime.tryParse(expirationDateStr);
        }

        if (expirationDate == null) {
          final dynamic expiresAtRaw = subscriptionData['expiresAt'];
          if (expiresAtRaw is Timestamp) {
            expirationDate = expiresAtRaw.toDate();
          }
        }

        final DateTime now = DateTime.now();
        if (expirationDate != null && expirationDate.isBefore(now)) {
          isExpired = true;
        }
      }

      if (isTrialPeriod && trialStatus.isExpired) {
        return {
          'hasActiveSubscription': false,
          'expiredDate': trialStatus.endAt,
          'isTrialPeriod': true,
          'trialStatus': trialStatus.normalizedStatus,
        };
      }

      if (!isTrialPeriod && isExpired) {
        return {'hasActiveSubscription': false, 'expiredDate': expirationDate};
      }

      int daysRemaining = 0;
      if (isTrialPeriod) {
        daysRemaining = trialStatus.daysRemaining;
      } else if (expirationDate != null) {
        final Duration diff = expirationDate.difference(DateTime.now());
        daysRemaining = diff.isNegative ? 0 : diff.inDays;
      }

      return {
        'hasActiveSubscription':
            isTrialPeriod ? trialStatus.isActive : !isExpired,
        'subscriptionData': subscriptionData,
        'daysRemaining': daysRemaining,
        'expirationDate': expirationDate,
        'priceAmount': subscriptionData['priceAmount'] ?? 0.0,
        'priceDisplay': subscriptionData['priceDisplay'] ?? 'N/A',
        'platform': subscriptionData['platform'] ?? 'unknown',
        'isTrialPeriod': isTrialPeriod,
        'trialStatus': trialStatus.normalizedStatus,
        'trialEndsAt': trialStatus.endAt,
        'structureType': subscriptionData['structureType'] ?? 'unknown',
        'memberCount': subscriptionData['memberCount'] ?? 1,
        'productId': subscriptionData['productId'] ?? '',
        'billingPeriod': subscriptionData['billingPeriod'] ?? 'monthly',
        'createdAt': subscriptionData['createdAt'],
        'subscriptionId': subscriptionQuery.docs.first.id,
      };
    } catch (e) {
      print('Erreur lors de la récupération des infos d\'abonnement: $e');
      return {'hasActiveSubscription': false, 'error': e.toString()};
    }
  }

  /// Calcule le montant à rembourser au prorata
  static double calculateProRataRefund(Map<String, dynamic> subscriptionInfo) {
    if (!subscriptionInfo['hasActiveSubscription']) return 0.0;

    try {
      final double priceAmount =
          subscriptionInfo['priceAmount']?.toDouble() ?? 0.0;
      final int daysRemaining = subscriptionInfo['daysRemaining'] ?? 0;
      final bool isTrialPeriod = subscriptionInfo['isTrialPeriod'] ?? false;

      // Pas de remboursement pendant la période d'essai
      if (isTrialPeriod) return 0.0;

      // Calculer le remboursement au prorata pour un mois (30 jours)
      final double dailyRate = priceAmount / 30.0;
      final double refundAmount = dailyRate * daysRemaining;

      return refundAmount;
    } catch (e) {
      print('Erreur lors du calcul du remboursement: $e');
      return 0.0;
    }
  }

  /// Formate le message pour informer l'utilisateur de son abonnement
  static String formatSubscriptionWarning(
      Map<String, dynamic> subscriptionInfo) {
    if (!subscriptionInfo['hasActiveSubscription']) {
      return 'Aucun abonnement actif détecté.';
    }

    final int daysRemaining = subscriptionInfo['daysRemaining'] ?? 0;
    final bool isTrialPeriod = subscriptionInfo['isTrialPeriod'] ?? false;
    final String priceDisplay = subscriptionInfo['priceDisplay'] ?? 'N/A';
    final double refundAmount = calculateProRataRefund(subscriptionInfo);

    String message = '';

    if (isTrialPeriod) {
      if (daysRemaining == 1) {
        message = '⚠️ Attention: Il vous reste 1 jour d\'essai gratuit.';
      } else {
        message =
            '⚠️ Attention: Il vous reste $daysRemaining jours d\'essai gratuit.';
      }
    } else {
      if (daysRemaining == 1) {
        message =
            '⚠️ Attention: Il vous reste 1 jour sur votre abonnement payant ($priceDisplay).';
      } else {
        message =
            '⚠️ Attention: Il vous reste $daysRemaining jours sur votre abonnement payant ($priceDisplay).';
      }

      if (refundAmount > 0) {
        message +=
            '\n\n💰 Vous devriez pouvoir demander un remboursement de ${refundAmount.toStringAsFixed(2)}€ auprès de ${subscriptionInfo['platform'] == 'ios' ? 'Apple' : 'Google'}.';
      }
    }

    return message;
  }

  /// Retourne les instructions de résiliation selon la plateforme
  static String getCancellationInstructions(String platform) {
    switch (platform.toLowerCase()) {
      case 'ios':
        return '''
📱 **Résiliation sur iPhone/iPad :**

1. Ouvrez l'app "Réglages" 
2. Touchez votre nom en haut
3. Touchez "Abonnements" 
4. Sélectionnez "Poppins App"
5. Touchez "Annuler l'abonnement"
6. Confirmez l'annulation

Votre abonnement restera actif jusqu'à la date d'expiration.

**Important :** Pour demander un remboursement, contactez l'assistance Apple après la résiliation.
''';

      case 'android':
        return '''
🤖 **Résiliation sur Android :**

1. Ouvrez Google Play Store
2. Touchez votre photo de profil
3. Sélectionnez "Paiements et abonnements"
4. Touchez "Abonnements"
5. Sélectionnez "Poppins App"
6. Touchez "Annuler l'abonnement"
7. Suivez les instructions

Votre abonnement restera actif jusqu'à la date d'expiration.

**Important :** Pour demander un remboursement, utilisez le formulaire de remboursement Google Play.
''';

      default:
        return '''
📱 **Résiliation d'abonnement :**

**Sur iPhone/iPad :**
Réglages > [Votre nom] > Abonnements > Poppins App > Annuler

**Sur Android :**
Google Play Store > Profil > Abonnements > Poppins App > Annuler

Votre abonnement restera actif jusqu'à la date d'expiration.

**Important :** Pour un remboursement, contactez l'assistance Apple ou Google après la résiliation.
''';
    }
  }

  /// Marque l'abonnement comme "en attente de suppression"
  static Future<void> markSubscriptionForDeletion(String subscriptionId) async {
    try {
      await _firestore.collection('subscriptions').doc(subscriptionId).update({
        'status': 'pending_deletion',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
        'deletionReason': 'account_deletion_request',
      });
    } catch (e) {
      print('Erreur lors du marquage de l\'abonnement pour suppression: $e');
      rethrow;
    }
  }

  /// Vérifie si l'utilisateur peut supprimer son compte maintenant
  static Future<bool> canDeleteAccountNow() async {
    final subscriptionInfo = await getSubscriptionInfo();

    if (!subscriptionInfo['hasActiveSubscription']) {
      return true; // Pas d'abonnement actif, peut supprimer
    }

    final int daysRemaining = subscriptionInfo['daysRemaining'] ?? 0;
    final bool isTrialPeriod = subscriptionInfo['isTrialPeriod'] ?? false;

    // Pendant la période d'essai, on peut supprimer directement
    if (isTrialPeriod) {
      return true;
    }

    // Pour un abonnement payant, on peut recommander d'attendre la fin
    // ou permettre la suppression immédiate selon la politique de l'app
    return true; // Changez en false si vous voulez empêcher la suppression avec abonnement actif
  }

  /// Retourne les options de suppression recommandées
  static Future<Map<String, dynamic>> getDeletionOptions() async {
    final subscriptionInfo = await getSubscriptionInfo();

    if (!subscriptionInfo['hasActiveSubscription']) {
      return {
        'canDeleteNow': true,
        'recommendedAction': 'direct_deletion',
        'message': 'Vous pouvez supprimer votre compte immédiatement.',
      };
    }

    final int daysRemaining = subscriptionInfo['daysRemaining'] ?? 0;
    final bool isTrialPeriod = subscriptionInfo['isTrialPeriod'] ?? false;
    final double refundAmount = calculateProRataRefund(subscriptionInfo);

    if (isTrialPeriod) {
      return {
        'canDeleteNow': true,
        'recommendedAction': 'direct_deletion',
        'message':
            'Vous êtes en période d\'essai, vous pouvez supprimer votre compte immédiatement.',
      };
    }

    if (daysRemaining <= 3) {
      return {
        'canDeleteNow': true,
        'recommendedAction': 'wait_expiration',
        'message':
            'Votre abonnement expire dans $daysRemaining jour(s). Vous pouvez attendre l\'expiration ou supprimer maintenant.',
      };
    }

    return {
      'canDeleteNow': true,
      'recommendedAction': 'cancel_then_delete',
      'message':
          'Nous recommandons de d\'abord résilier votre abonnement${refundAmount > 0 ? ' et demander un remboursement' : ''}, puis de supprimer votre compte.',
      'refundAmount': refundAmount,
    };
  }

  /// Aide à déterminer si l'utilisateur devrait demander un remboursement
  static bool shouldRequestRefund(Map<String, dynamic> subscriptionInfo) {
    if (!subscriptionInfo['hasActiveSubscription']) return false;

    final bool isTrialPeriod = subscriptionInfo['isTrialPeriod'] ?? false;
    final double refundAmount = calculateProRataRefund(subscriptionInfo);

    return !isTrialPeriod && refundAmount > 1.0; // Remboursement si > 1€
  }
}
