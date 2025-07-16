// lib/services/account_deletion_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'unified_subscription_service.dart';

class AccountDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final UnifiedSubscriptionService _subscriptionService =
      UnifiedSubscriptionService.instance;

  /// Vérifie le statut de l'abonnement et retourne les informations
  static Future<Map<String, dynamic>> checkSubscriptionStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'hasSubscription': false, 'error': 'Utilisateur non connecté'};
      }

      // Vérifier dans Firestore les informations d'abonnement
      final subscriptionQuery = await _firestore
          .collection('subscriptions')
          .where('structureId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (subscriptionQuery.docs.isEmpty) {
        return {'hasSubscription': false};
      }

      final subscriptionData = subscriptionQuery.docs.first.data();
      final String expirationDateStr = subscriptionData['expirationDate'] ?? '';

      if (expirationDateStr.isEmpty) {
        return {'hasSubscription': false};
      }

      final DateTime expirationDate = DateTime.parse(expirationDateStr);
      final DateTime now = DateTime.now();

      if (expirationDate.isBefore(now)) {
        return {'hasSubscription': false};
      }

      final int daysRemaining = expirationDate.difference(now).inDays;

      return {
        'hasSubscription': true,
        'daysRemaining': daysRemaining,
        'expirationDate': expirationDate,
        'priceDisplay': subscriptionData['priceDisplay'] ?? 'N/A',
        'platform': subscriptionData['platform'] ?? 'unknown',
        'isTrialPeriod': subscriptionData['isTrialPeriod'] ?? false,
      };
    } catch (e) {
      print('❌ Erreur lors de la vérification de l\'abonnement: $e');
      return {'hasSubscription': false, 'error': e.toString()};
    }
  }

  /// Supprime toutes les données associées au compte
  static Future<void> deleteAccountData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final String userId = user.uid;
      final String userEmail = user.email?.toLowerCase() ?? '';

      print('🗑️ Début de la suppression des données pour: $userEmail');

      // 1. Supprimer les photos du Storage
      await _deleteUserPhotos(userId);

      // 2. Supprimer les données de la structure
      await _deleteStructureData(userId);

      // 3. Supprimer le document utilisateur
      await _deleteUserDocument(userEmail);

      // 4. Marquer les abonnements comme supprimés
      await _markSubscriptionsAsDeleted(userId);

      // 5. Supprimer l'utilisateur Firebase Auth
      await user.delete();

      print('✅ Suppression du compte terminée avec succès');
    } catch (e) {
      print('❌ Erreur lors de la suppression du compte: $e');
      rethrow;
    }
  }

  /// Supprime les photos du Storage
  static Future<void> _deleteUserPhotos(String userId) async {
    try {
      print('📸 Suppression des photos...');

      // Supprimer le dossier structure
      final structureRef = _storage.ref().child('structures/$userId');
      await _deleteStorageFolder(structureRef);

      // Supprimer le dossier uploads (si existant)
      final uploadsRef = _storage.ref().child('uploads/$userId');
      await _deleteStorageFolder(uploadsRef);

      print('✅ Photos supprimées');
    } catch (e) {
      print('⚠️ Erreur lors de la suppression des photos: $e');
      // Ne pas faire échouer la suppression pour les photos
    }
  }

  /// Supprime un dossier et tout son contenu du Storage
  static Future<void> _deleteStorageFolder(Reference folderRef) async {
    try {
      final ListResult result = await folderRef.listAll();

      // Supprimer tous les fichiers
      for (final Reference fileRef in result.items) {
        await fileRef.delete();
      }

      // Supprimer récursivement tous les sous-dossiers
      for (final Reference subfolderRef in result.prefixes) {
        await _deleteStorageFolder(subfolderRef);
      }
    } catch (e) {
      print(
          '⚠️ Erreur lors de la suppression du dossier ${folderRef.fullPath}: $e');
    }
  }

  /// Supprime toutes les données de la structure
  static Future<void> _deleteStructureData(String userId) async {
    try {
      print('🏢 Suppression des données de structure...');

      // Supprimer les enfants et leurs sous-collections
      await _deleteChildrenData(userId);

      // Supprimer les membres MAM
      await _deleteCollection('structures/$userId/members');

      // Supprimer les autres sous-collections
      await _deleteCollection('structures/$userId/fridgeTemperatures');
      await _deleteCollection('structures/$userId/freezerTemperatures');
      await _deleteCollection('structures/$userId/cleaningSchedule');

      // Supprimer le document principal de la structure
      await _firestore.collection('structures').doc(userId).delete();

      print('✅ Données de structure supprimées');
    } catch (e) {
      print('❌ Erreur lors de la suppression des données de structure: $e');
      rethrow;
    }
  }

  /// Supprime tous les enfants et leurs données
  static Future<void> _deleteChildrenData(String userId) async {
    try {
      print('👶 Suppression des données des enfants...');

      final childrenSnapshot = await _firestore
          .collection('structures')
          .doc(userId)
          .collection('children')
          .get();

      for (final childDoc in childrenSnapshot.docs) {
        final String childId = childDoc.id;

        // Supprimer les sous-collections de chaque enfant
        await _deleteCollection(
            'structures/$userId/children/$childId/activities');
        await _deleteCollection('structures/$userId/children/$childId/meals');
        await _deleteCollection('structures/$userId/children/$childId/naps');
        await _deleteCollection('structures/$userId/children/$childId/health');
        await _deleteCollection('structures/$userId/children/$childId/diapers');
        await _deleteCollection(
            'structures/$userId/children/$childId/schedules');
        await _deleteCollection('structures/$userId/children/$childId/photos');
        await _deleteCollection(
            'structures/$userId/children/$childId/transmissions');
        await _deleteCollection('structures/$userId/children/$childId/stock');
        await _deleteCollection('structures/$userId/children/$childId/news');
        await _deleteCollection('structures/$userId/children/$childId/recaps');

        // Supprimer les échanges liés à cet enfant
        await _deleteExchangesForChild(childId);

        // Supprimer le document enfant
        await childDoc.reference.delete();
      }

      print('✅ Données des enfants supprimées');
    } catch (e) {
      print('❌ Erreur lors de la suppression des données des enfants: $e');
      rethrow;
    }
  }

  /// Supprime les échanges pour un enfant
  static Future<void> _deleteExchangesForChild(String childId) async {
    try {
      final exchangesSnapshot = await _firestore
          .collection('exchanges')
          .where('childId', isEqualTo: childId)
          .get();

      for (final exchangeDoc in exchangesSnapshot.docs) {
        await exchangeDoc.reference.delete();
      }
    } catch (e) {
      print(
          '⚠️ Erreur lors de la suppression des échanges pour l\'enfant $childId: $e');
    }
  }

  /// Supprime une collection entière
  static Future<void> _deleteCollection(String collectionPath) async {
    try {
      final collectionRef = _firestore.collection(collectionPath);
      final snapshot = await collectionRef.get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print(
          '⚠️ Erreur lors de la suppression de la collection $collectionPath: $e');
    }
  }

  /// Supprime le document utilisateur
  static Future<void> _deleteUserDocument(String userEmail) async {
    try {
      print('👤 Suppression du document utilisateur...');

      await _firestore.collection('users').doc(userEmail).delete();

      print('✅ Document utilisateur supprimé');
    } catch (e) {
      print('❌ Erreur lors de la suppression du document utilisateur: $e');
      rethrow;
    }
  }

  /// Marque les abonnements comme supprimés
  static Future<void> _markSubscriptionsAsDeleted(String userId) async {
    try {
      print('💳 Marquage des abonnements comme supprimés...');

      final subscriptionsSnapshot = await _firestore
          .collection('subscriptions')
          .where('structureId', isEqualTo: userId)
          .get();

      for (final subscriptionDoc in subscriptionsSnapshot.docs) {
        await subscriptionDoc.reference.update({
          'status': 'deleted',
          'deletedAt': FieldValue.serverTimestamp(),
          'accountDeleted': true,
        });
      }

      print('✅ Abonnements marqués comme supprimés');
    } catch (e) {
      print('❌ Erreur lors du marquage des abonnements: $e');
      rethrow;
    }
  }

  /// Retourne les instructions pour résilier l'abonnement selon la plateforme
  static String getCancellationInstructions(String platform) {
    if (platform == 'ios') {
      return '''
Pour résilier votre abonnement sur iPhone/iPad :

1. Ouvrez l'app "Réglages" sur votre iPhone/iPad
2. Touchez votre nom en haut de l'écran
3. Touchez "Abonnements"
4. Sélectionnez l'abonnement Poppins App
5. Touchez "Annuler l'abonnement"
6. Confirmez l'annulation

Votre abonnement restera actif jusqu'à la fin de la période payée.
''';
    } else if (platform == 'android') {
      return '''
Pour résilier votre abonnement sur Android :

1. Ouvrez l'app Google Play Store
2. Touchez le menu (3 barres) puis "Abonnements"
3. Sélectionnez l'abonnement Poppins App
4. Touchez "Annuler l'abonnement"
5. Suivez les instructions à l'écran

Votre abonnement restera actif jusqu'à la fin de la période payée.
''';
    } else {
      return '''
Pour résilier votre abonnement :

• Sur iPhone/iPad : Réglages > [Votre nom] > Abonnements
• Sur Android : Google Play Store > Menu > Abonnements

Votre abonnement restera actif jusqu'à la fin de la période payée.
''';
    }
  }
}
