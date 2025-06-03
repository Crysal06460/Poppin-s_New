// Créer un nouveau fichier: lib/services/photo_cleanup_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhotoCleanupService {
  static const String _lastCleanupKey = 'last_photo_cleanup';
  static const int _retentionDays = 10;

  /// Vérifie si un nettoyage est nécessaire et l'exécute si c'est le cas
  static Future<void> checkAndCleanupPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCleanup = prefs.getString(_lastCleanupKey);

      // Vérifier si le dernier nettoyage date de plus de 24h
      if (lastCleanup != null) {
        final lastCleanupDate = DateTime.parse(lastCleanup);
        final now = DateTime.now();
        final difference = now.difference(lastCleanupDate);

        if (difference.inHours < 24) {
          print(
              "📸 Nettoyage des photos: pas encore nécessaire (dernier: ${difference.inHours}h)");
          return;
        }
      }

      print("📸 Début du nettoyage automatique des photos anciennes...");
      await _performCleanup();

      // Enregistrer la date du dernier nettoyage
      await prefs.setString(_lastCleanupKey, DateTime.now().toIso8601String());
      print("📸 Nettoyage des photos terminé avec succès");
    } catch (e) {
      print("❌ Erreur lors du nettoyage des photos: $e");
    }
  }

  /// Effectue le nettoyage des photos anciennes
  static Future<void> _performCleanup() async {
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    // Date limite (photos plus anciennes que X jours)
    final cutoffDate = DateTime.now().subtract(Duration(days: _retentionDays));
    final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

    print("📸 Suppression des photos antérieures au ${cutoffDate.toLocal()}");

    try {
      // Récupérer toutes les structures
      final structuresSnapshot = await firestore.collection('structures').get();

      int totalPhotosDeleted = 0;
      int totalStorageFilesDeleted = 0;

      for (var structureDoc in structuresSnapshot.docs) {
        final structureId = structureDoc.id;

        // Récupérer tous les enfants de cette structure
        final childrenSnapshot = await firestore
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .get();

        for (var childDoc in childrenSnapshot.docs) {
          final childId = childDoc.id;

          // Récupérer les photos anciennes
          final oldPhotosSnapshot = await firestore
              .collection('structures')
              .doc(structureId)
              .collection('children')
              .doc(childId)
              .collection('medias')
              .where('date', isLessThan: cutoffTimestamp)
              .get();

          print(
              "📸 Enfant $childId: ${oldPhotosSnapshot.docs.length} photos à supprimer");

          // Supprimer les photos une par une
          for (var photoDoc in oldPhotosSnapshot.docs) {
            try {
              final photoData = photoDoc.data();
              final photoUrl = photoData['url'] as String?;

              // Supprimer le fichier du Storage Firebase
              if (photoUrl != null && photoUrl.isNotEmpty) {
                try {
                  final ref = storage.refFromURL(photoUrl);
                  await ref.delete();
                  totalStorageFilesDeleted++;
                  print("📸 Fichier supprimé du Storage: ${ref.name}");
                } catch (storageError) {
                  print(
                      "⚠️ Erreur suppression Storage pour ${photoUrl}: $storageError");
                  // Continuer même si la suppression du fichier échoue
                }
              }

              // Supprimer le document Firestore
              await photoDoc.reference.delete();
              totalPhotosDeleted++;
            } catch (e) {
              print(
                  "❌ Erreur lors de la suppression de la photo ${photoDoc.id}: $e");
            }
          }
        }
      }

      print("📸 Nettoyage terminé:");
      print("   - $totalPhotosDeleted documents supprimés de Firestore");
      print("   - $totalStorageFilesDeleted fichiers supprimés du Storage");
    } catch (e) {
      print("❌ Erreur lors du nettoyage des photos: $e");
      throw e;
    }
  }

  /// Force le nettoyage immédiat (pour les tests ou maintenance manuelle)
  static Future<void> forceCleanup() async {
    print("📸 Nettoyage forcé des photos anciennes...");
    await _performCleanup();

    // Mettre à jour la date du dernier nettoyage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCleanupKey, DateTime.now().toIso8601String());
  }

  /// Récupère la date du dernier nettoyage
  static Future<DateTime?> getLastCleanupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCleanup = prefs.getString(_lastCleanupKey);

    if (lastCleanup != null) {
      return DateTime.parse(lastCleanup);
    }
    return null;
  }

  /// Récupère le nombre de jours de rétention configuré
  static int getRetentionDays() => _retentionDays;

  /// Méthode pour obtenir des statistiques sur les photos anciennes
  static Future<Map<String, int>> getCleanupStats() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final cutoffDate =
          DateTime.now().subtract(Duration(days: _retentionDays));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      int oldPhotosCount = 0;
      int totalPhotosCount = 0;

      final structuresSnapshot = await firestore.collection('structures').get();

      for (var structureDoc in structuresSnapshot.docs) {
        final structureId = structureDoc.id;

        final childrenSnapshot = await firestore
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .get();

        for (var childDoc in childrenSnapshot.docs) {
          final childId = childDoc.id;

          // Compter toutes les photos
          final allPhotosSnapshot = await firestore
              .collection('structures')
              .doc(structureId)
              .collection('children')
              .doc(childId)
              .collection('medias')
              .get();

          totalPhotosCount += allPhotosSnapshot.docs.length;

          // Compter les photos anciennes
          final oldPhotosSnapshot = await firestore
              .collection('structures')
              .doc(structureId)
              .collection('children')
              .doc(childId)
              .collection('medias')
              .where('date', isLessThan: cutoffTimestamp)
              .get();

          oldPhotosCount += oldPhotosSnapshot.docs.length;
        }
      }

      return {
        'totalPhotos': totalPhotosCount,
        'oldPhotos': oldPhotosCount,
        'retentionDays': _retentionDays,
      };
    } catch (e) {
      print("❌ Erreur lors du calcul des statistiques: $e");
      return {
        'totalPhotos': 0,
        'oldPhotos': 0,
        'retentionDays': _retentionDays,
      };
    }
  }
}
