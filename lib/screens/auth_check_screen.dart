import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../utils/user_role_cache.dart';
import 'dart:async';
import 'package:poppins_app/services/notification_service.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);

  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  // Couleurs de l'app
  static const Color primaryBlue = Color(0xFF3D9DF2);
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // Vérifications d'état
    final bool wasAppKilled = prefs.getBool('app_killed') ?? true;
    final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final bool rememberEmail = prefs.getBool('remember_email') ?? false;
    final String? savedEmail = prefs.getString('saved_email');
    final User? firebaseUser = FirebaseAuth.instance.currentUser;
    final bool hasFirebaseSession = firebaseUser != null;

    // 🔒 SÉCURITÉ : Vérifier si c'est le premier lancement du jour
    final String today =
        DateTime.now().toIso8601String().split('T')[0]; // "2025-07-22"
    final String? lastLoginDate = prefs.getString('last_login_date');
    final bool isFirstLaunchToday = (lastLoginDate != today);
    final bool needsAuthentication =
        isFirstLaunchToday || !isLoggedIn || !hasFirebaseSession;
    NotificationService.setAuthenticationRequired(needsAuthentication);

    print(
        "🔍 AuthCheck - wasAppKilled: $wasAppKilled, isLoggedIn: $isLoggedIn, hasFirebaseSession: $hasFirebaseSession");
    print(
        "🔍 AuthCheck - rememberEmail: $rememberEmail, savedEmail: $savedEmail");
    print(
        "🔍 AuthCheck - today: $today, lastLoginDate: $lastLoginDate, needsAuth: $needsAuthentication");

    // Petite pause pour éviter le flash
    await Future.delayed(Duration(milliseconds: 500));

    if (needsAuthentication) {
      final bool dailySecurity = isFirstLaunchToday;
      final String reason = dailySecurity ? 'daily_security' : 'app_closed';

      // Préférer l'email sauvegardé, sinon tenter celui de Firebase si encore disponible
      final String? quickLoginEmail =
          (rememberEmail && savedEmail != null && savedEmail.isNotEmpty)
              ? savedEmail
              : firebaseUser?.email;

      if (dailySecurity) {
        print("🔒 Premier lancement du jour - Sécurité quotidienne activée");
      } else {
        print(
            "❌ Session invalide (dailySecurity: $dailySecurity, hasFirebaseSession: $hasFirebaseSession) - authentification requise");
      }

      if (quickLoginEmail != null && quickLoginEmail.isNotEmpty) {
        context.go('/quick-login',
            extra: {'email': quickLoginEmail.trim(), 'reason': reason});
      } else {
        context.go('/welcome');
      }

      // Marquer que l'app est active même si on redirige vers l'authentification
      await prefs.setBool('app_killed', false);
      return;
    }

    // 📱 Session déjà validée aujourd'hui = accès direct au bon écran
    print(
        "📱 AuthCheck - Session quotidienne valide, redirection directe (wasAppKilled: $wasAppKilled)");
    await _navigateToCorrectHome();
    Future.delayed(const Duration(milliseconds: 250), () {
      NotificationService.synchronizeMissedNotifications();
      NotificationService.showPendingNotificationWhenReady();
    });

    // Marquer que l'app est active
    await prefs.setBool('app_killed', false);
  }

  // Méthode pour naviguer vers le bon écran selon le rôle
  Future<void> _navigateToCorrectHome() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        context.go('/welcome');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase() ?? '')
          .get()
          .timeout(Duration(seconds: 3));

      final String userRole =
          (userDoc.data()?['role'] ?? '').toString().toLowerCase();
      print('🔍 AuthCheck: rôle utilisateur Firestore = ' + userRole);

      const parentRoles = {
        'parent',
        'parent_employeur',
        'parentemployeur',
      };

      if (parentRoles.contains(userRole)) {
        print("✅ Utilisateur parent détecté, redirection vers parent home");
        UserRoleCache.setRole('parent');
        context.go('/parent/home');
        return;
      }

      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get()
          .timeout(Duration(seconds: 5));

      if (structureDoc.exists) {
        final String structureType =
            (structureDoc.data()?['structureType'] ?? '')
                .toString()
                .toLowerCase();
        print('🔍 AuthCheck: structureType Firestore = ' + structureType);
        if (parentRoles.contains(structureType)) {
          print(
              "✅ Structure parent employeur détectée, redirection vers parent home");
          UserRoleCache.setRole('parent');
          UserRoleCache.setStructureType(structureType);
          context.go('/parent/home');
          return;
        }

        print("✅ Structure trouvée, redirection vers home");
        UserRoleCache.setRole('structure');
        context.go('/home');
        return;
      }

      print("⚠️ Utilisateur sans rôle défini, redirection vers Welcome");
      UserRoleCache.setRole(null);
      context.go('/welcome');
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        setState(() {
          _isOffline = true;
        });
      } else {
        print("⚠️ Firebase erreur: ${e.code}");
        context.go('/welcome');
      }
    } on TimeoutException {
      setState(() {
        _isOffline = true;
      });
    } catch (e) {
      print("⚠️ Erreur navigation: $e, fallback vers Welcome");
      UserRoleCache.setRole(null);
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: 80,
                color: Colors.grey[600],
              ),
              SizedBox(height: 20),
              Text(
                "Connexion perdue",
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isOffline = false;
                  });
                  _navigateToCorrectHome();
                },
                child: Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo de l'app
            Image.asset(
              "assets/images/parapluie.png",
              height: 100,
              width: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.umbrella,
                size: 100,
                color: primaryBlue,
              ),
            ),
            SizedBox(height: 30),

            // Indicateur de chargement
            CircularProgressIndicator(
              color: primaryBlue,
              strokeWidth: 3,
            ),

            SizedBox(height: 20),

            Text(
              "Vérification de la sécurité...",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
