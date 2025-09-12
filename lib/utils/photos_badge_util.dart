import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhotosBadgeUtil {
  static const String _lastPhotosKeyPrefix = 'photos_last_total_count';

  static String _key(String structureId, String userId) =>
      '${_lastPhotosKeyPrefix}_${structureId}_$userId';

  static Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final email = user.email?.toLowerCase();
    if (email == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .get();
    if (!userDoc.exists) return null;
    return userDoc.data();
  }

  static Future<int> _computeTotalPhotos(
      String structureId, List<String> childIds) async {
    int total = 0;
    for (final childId in childIds) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .doc(childId)
            .collection('medias')
            .get();
        total += snap.docs.length;
      } catch (e) {
        // Continuer pour les autres enfants
        // ignore: avoid_print
        print('📸 ❌ Erreur comptage photos pour $childId: $e');
      }
    }
    return total;
  }

  // Returns whether there are new photos/videos since last seen.
  static Future<bool> shouldShowBadge() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userData = await _getUserData();
      if (userData == null) return false;

      final List<String> childIds = List<String>.from(userData['children'] ?? []);
      final String? structureId = userData['structureId'];
      if (structureId == null || childIds.isEmpty) return false;

      final total = await _computeTotalPhotos(structureId, childIds);
      final prefs = await SharedPreferences.getInstance();
      final key = _key(structureId, user.uid);
      final last = prefs.getInt(key);

      if (last == null) {
        // Première exécution: initialiser sans afficher de badge
        await prefs.setInt(key, total);
        return false;
      }

      final hasNew = total > last;
      // Ne pas mettre à jour ici; on met à jour seulement quand l'utilisateur ouvre les Photos
      // Logs utiles
      print('📸 Badge Photos? total=$total last=$last → $hasNew');
      return hasNew;
    } catch (e) {
      print('📸 ❌ Erreur shouldShowBadge Photos: $e');
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userData = await _getUserData();
      if (userData == null) return;
      final List<String> childIds = List<String>.from(userData['children'] ?? []);
      final String? structureId = userData['structureId'];
      if (structureId == null || childIds.isEmpty) return;

      final total = await _computeTotalPhotos(structureId, childIds);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(structureId, user.uid), total);
      print('📸 Badge Photos reset to $total');
    } catch (e) {
      print('📸 ❌ Erreur markSeen Photos: $e');
    }
  }
}
