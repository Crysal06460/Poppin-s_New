import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

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

    // 🔒 SÉCURITÉ : Vérifier si c'est le premier lancement du jour
    final String today =
        DateTime.now().toIso8601String().split('T')[0]; // "2025-07-22"
    final String? lastLoginDate = prefs.getString('last_login_date');
    final bool isFirstLaunchToday = (lastLoginDate != today);

    print(
        "🔍 AuthCheck - wasAppKilled: $wasAppKilled, isLoggedIn: $isLoggedIn, isFirstLaunchToday: $isFirstLaunchToday");
    print(
        "🔍 AuthCheck - rememberEmail: $rememberEmail, savedEmail: $savedEmail");
    print("🔍 AuthCheck - today: $today, lastLoginDate: $lastLoginDate");

    // Petite pause pour éviter le flash
    await Future.delayed(Duration(milliseconds: 500));

    if (isFirstLaunchToday) {
      // 🌅 Premier lancement du jour = TOUJOURS redemander mot de passe
      print("🔒 Premier lancement du jour - Sécurité quotidienne activée");

      if (rememberEmail && savedEmail != null && savedEmail.isNotEmpty) {
        context.go('/quick-login',
            extra: {'email': savedEmail, 'reason': 'daily_security'});
      } else {
        context.go('/welcome');
      }
    } else if (!wasAppKilled && isLoggedIn) {
      // 📱 App en arrière-plan + déjà connecté aujourd'hui = Direct home selon le rôle
      print("📱 App en arrière-plan - Accès direct selon le rôle");
      await _navigateToCorrectHome();
    } else {
      // ❌ App fermée = Redemander mot de passe
      print("❌ App fermée - Redemander authentification");

      if (rememberEmail && savedEmail != null && savedEmail.isNotEmpty) {
        context.go('/quick-login',
            extra: {'email': savedEmail, 'reason': 'app_closed'});
      } else {
        context.go('/welcome');
      }
    }

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

      // Vérifier si c'est une structure (assistante maternelle)
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get()
          .timeout(Duration(seconds: 5));

      if (structureDoc.exists) {
        print("✅ Structure trouvée, redirection vers home");
        context.go('/home');
        return;
      }

      // Vérifier si c'est un parent
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase() ?? '')
          .get()
          .timeout(Duration(seconds: 3));

      if (userDoc.exists && userDoc.data()?['role'] == 'parent') {
        print("✅ Utilisateur parent détecté, redirection vers parent home");
        context.go('/parent/home');
      } else {
        print("⚠️ Utilisateur sans rôle défini, redirection vers Welcome");
        context.go('/welcome');
      }
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
