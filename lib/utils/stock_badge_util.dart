import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StockBadgeUtil {
  static const String _stockNeedsKey = 'has_stock_needs';
  
  // Vérifier si le badge devrait être affiché
  static Future<bool> shouldShowBadge() async {
    final prefs = await SharedPreferences.getInstance();
    
    // D'abord vérifier Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email?.toLowerCase())
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final childIds = List<String>.from(userData['children'] ?? []);
          final structureId = userData['structureId'];
          
          if (childIds.isNotEmpty && structureId != null) {
            for (final childId in childIds) {
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
                if (stockData.values.contains(true)) {
                  // Mettre aussi à jour les SharedPreferences
                  await prefs.setBool(_stockNeedsKey, true);
                  print("⭐ Badge activé depuis Firestore pour l'enfant $childId");
                  return true;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification Firestore: $e');
    }
    
    // Si rien trouvé dans Firestore, utiliser les SharedPreferences
    final result = prefs.getBool(_stockNeedsKey) ?? false;
    print("📱 Badge status depuis SharedPreferences: $result");
    return result;
  }
  
  // Définir l'état du badge
  static Future<void> setStockNeeds(bool hasNeeds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_stockNeedsKey, hasNeeds);
    print("🔔 Badge modifié dans SharedPreferences: $hasNeeds");
  }
  
  // Réinitialiser le badge
  static Future<void> resetBadge() async {
    await setStockNeeds(false);
  }
}