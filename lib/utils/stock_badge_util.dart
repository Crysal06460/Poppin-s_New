import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StockBadgeUtil {
  static const String _stockNeedsKey = 'has_stock_needs';

  // Vérifier si le badge devrait être affiché
  static Future<bool> shouldShowBadge() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Aucun utilisateur connecté");
        return false;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get();

      if (!userDoc.exists) {
        print("❌ Document utilisateur non trouvé");
        return false;
      }

      final userData = userDoc.data()!;
      final childIds = List<String>.from(userData['children'] ?? []);
      final structureId = userData['structureId'];

      print("📦 Vérification du badge stock pour ${childIds.length} enfant(s)");

      if (childIds.isEmpty || structureId == null) {
        print("📦 Aucun enfant ou structure ID manquant");
        await _updateBadgeState(false);
        return false;
      }

      bool hasAnyStockNeeds = false;

      for (final childId in childIds) {
        try {
          final stockDoc = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('children')
              .doc(childId)
              .collection('stocks')
              .doc('current')
              .get();

          if (stockDoc.exists) {
            final stockData = stockDoc.data() as Map<String, dynamic>;

            print("📦 Données stock pour enfant $childId: $stockData");

            // Vérifier s'il y a des besoins actifs (valeur == true)
            bool hasNeedsForThisChild =
                stockData.values.any((value) => value == true);

            if (hasNeedsForThisChild) {
              print("📦 ✅ Besoins détectés pour l'enfant $childId");
              hasAnyStockNeeds = true;
              break; // Pas besoin de vérifier les autres enfants
            } else {
              print("📦 ❌ Aucun besoin pour l'enfant $childId");
            }
          } else {
            print("📦 ❌ Document stock non trouvé pour l'enfant $childId");
          }
        } catch (e) {
          print(
              "📦 ❌ Erreur lors de la vérification pour l'enfant $childId: $e");
        }
      }

      // Mettre à jour l'état du badge
      await _updateBadgeState(hasAnyStockNeeds);

      print("📦 Résultat final du badge: $hasAnyStockNeeds");
      return hasAnyStockNeeds;
    } catch (e) {
      print('📦 ❌ Erreur lors de la vérification du badge stock: $e');
      await _updateBadgeState(false);
      return false;
    }
  }

  // Méthode privée pour mettre à jour l'état du badge
  static Future<void> _updateBadgeState(bool hasNeeds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_stockNeedsKey, hasNeeds);
      print("📦 Badge état mis à jour dans SharedPreferences: $hasNeeds");
    } catch (e) {
      print("📦 ❌ Erreur lors de la mise à jour du badge: $e");
    }
  }

  // Définir l'état du badge (utilisé par les assistantes maternelles)
  static Future<void> setStockNeeds(bool hasNeeds) async {
    await _updateBadgeState(hasNeeds);
  }

  // Réinitialiser le badge
  static Future<void> resetBadge() async {
    await _updateBadgeState(false);
  }

  // Forcer la vérification et mise à jour du badge
  static Future<void> forceRefresh() async {
    print("📦 Actualisation forcée du badge stock");
    await shouldShowBadge();
  }
}
