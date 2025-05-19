import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageBadgeUtil {
  static const String _unreadMessagesKey = 'has_unread_messages';
  
  // Vérifier si le badge devrait être affiché
  // Dans message_badge_util.dart, modifiez la méthode shouldShowBadge :

static Future<bool> shouldShowBadge() async {
  final prefs = await SharedPreferences.getInstance();
  
  // D'abord vérifier Firestore
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Vérifier si l'utilisateur a un compteur de messages non lus
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get();
          
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        // Si l'utilisateur a un compteur de messages non lus, l'utiliser
        if (userData['unreadMessages'] != null && userData['unreadMessages'] > 0) {
          // Mettre aussi à jour les SharedPreferences
          await prefs.setBool(_unreadMessagesKey, true);
          print("⭐ Badge message activé depuis compteur Firestore: ${userData['unreadMessages']}");
          return true;
        }
        
        // Sinon, vérifier les messages non lus pour chaque enfant
        final childIds = List<String>.from(userData['children'] ?? []);
        
        if (childIds.isNotEmpty) {
          // Utiliser une seule requête pour tous les enfants
          final messagesQuery = await FirebaseFirestore.instance
              .collection('exchanges')
              .where('childId', whereIn: childIds)
              .where('senderType', isEqualTo: 'staff')
              .where('nonLu', isEqualTo: true)
              .limit(1)
              .get();

          if (messagesQuery.docs.isNotEmpty) {
            // Mettre aussi à jour les SharedPreferences SEULEMENT si on a trouvé des messages
            await prefs.setBool(_unreadMessagesKey, true);
            print("⭐ Badge message activé depuis Firestore pour au moins un enfant");
            return true;
          }
        }
      }
    }
  } catch (e) {
    print('Erreur lors de la vérification des messages: $e');
  }
  
  // Si rien trouvé dans Firestore, utiliser les SharedPreferences
  // Ne pas réinitialiser automatiquement ici
  final result = prefs.getBool(_unreadMessagesKey) ?? false;
  print("📱 Badge message status depuis SharedPreferences: $result");
  return result;
}
  
  // Définir l'état du badge
  static Future<void> setHasUnreadMessages(bool hasUnread) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unreadMessagesKey, hasUnread);
    print("💬 Badge message modifié dans SharedPreferences: $hasUnread");
    
    if (!hasUnread) {
      // Si on désactive le badge, mettre aussi à jour le compteur Firestore
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.email?.toLowerCase())
              .update({
                'unreadMessages': 0
              });
          print("💬 Compteur de messages non lus réinitialisé dans Firestore");
        }
      } catch (e) {
        print('Erreur lors de la réinitialisation du compteur Firestore: $e');
      }
    }
  }
  // Ajouter cette méthode pour forcer l'affichage du badge
static Future<void> forceShowBadge() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_unreadMessagesKey, true);
  
  // Mettre à jour le compteur dans Firestore
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase())
          .set({
            'unreadMessages': 1 // Force à 1 pour être sûr
          }, SetOptions(merge: true));
      print("📱 Badge message forcé à true");
    } catch (e) {
      print('Erreur lors du forçage du badge dans Firestore: $e');
    }
  }
}
  // Réinitialiser le badge
  static Future<void> resetBadge() async {
    await setHasUnreadMessages(false);
  }
}