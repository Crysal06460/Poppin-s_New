import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poppins_app/screens/user_role_service.dart';

class SessionUtil {
  static Future<void> signOut() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentEmail = currentUser?.email?.toLowerCase();

    // Tenter de retirer le token FCM du compte courant et de le supprimer côté device
    try {
      if (currentEmail != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentEmail)
            .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}

    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('last_login_date');
    UserRoleService.clearCache();
  }
}
