import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poppins_app/services/notification_service.dart';
import '../utils/user_role_cache.dart';

class QuickLoginScreen extends StatefulWidget {
  final Map<String, String> data;

  const QuickLoginScreen({Key? key, required this.data}) : super(key: key);

  @override
  _QuickLoginScreenState createState() => _QuickLoginScreenState();
}

class _QuickLoginScreenState extends State<QuickLoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;

  // Couleurs de l'app
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color primaryRed = Color(0xFFD94350);

  String get email => widget.data['email']!;
  String get reason => widget.data['reason'] ?? 'app_closed';

  String _getWelcomeMessage() {
    switch (reason) {
      case 'daily_security':
        return "Sécurité quotidienne 🔒";
      case 'app_closed':
        return "Bon retour ! 👋";
      default:
        return "Connexion";
    }
  }

  String _getSubMessage() {
    switch (reason) {
      case 'daily_security':
        return "Premier lancement du jour\nMot de passe requis pour la sécurité";
      case 'app_closed':
        return "Veuillez saisir votre mot de passe";
      default:
        return "Connexion requise";
    }
  }

  Future<void> _login() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = "Veuillez saisir votre mot de passe";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Tentative de connexion
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // Renouveler le token FCM au login rapide
      try {
        await NotificationService.refreshTokenForCurrentUser();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);

      // 🔒 Marquer la date de connexion d'aujourd'hui
      final String today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('last_login_date', today);

      // Enregistrer l'heure de session pour la gestion arrière-plan
      await prefs.setInt(
          'lastSessionTime', DateTime.now().millisecondsSinceEpoch);

      // Navigation selon le rôle de l'utilisateur
      await _navigateAfterLogin();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Une erreur inattendue s'est produite";
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateAfterLogin() async {
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
      print('🔍 QuickLogin: rôle utilisateur Firestore = $userRole');
      const parentRoles = {'parent', 'parent_employeur', 'parentemployeur'};

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
        print('🔍 QuickLogin: structureType = $structureType');
        UserRoleCache.setStructureType(structureType);
        if (parentRoles.contains(structureType)) {
          print(
              "✅ Structure parent employeur détectée, redirection vers parent home");
          UserRoleCache.setRole('parent');
          context.go('/parent/home');
          return;
        }

        print("✅ Structure trouvée, redirection vers home");
        UserRoleCache.setRole('structure');
        context.go('/home');
        return;
      }

      print(
          "⚠️ Utilisateur sans rôle défini, redirection vers home par défaut");
      UserRoleCache.setRole('structure');
      context.go('/home');
    } catch (e) {
      print("⚠️ Erreur navigation: $e, fallback vers home");
      UserRoleCache.setRole('structure');
      context.go('/home');
    }
  }

  String _getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case "invalid-email":
        return "L'adresse email est invalide.";
      case "user-not-found":
        return "Aucun compte trouvé pour cet email.";
      case "wrong-password":
        return "Mot de passe incorrect.";
      case "invalid-credential":
        return "Email inconnu ou mot de passe incorrect.";
      case "user-disabled":
        return "Ce compte utilisateur a été désactivé.";
      case "too-many-requests":
        return "Trop de tentatives de connexion. Veuillez réessayer plus tard.";
      default:
        return "Une erreur est survenue: $errorCode";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double contentMaxWidth = isTablet ? 480 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () => context.go('/welcome'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 24),
            child: Container(
              width: contentMaxWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    "assets/images/parapluie.png",
                    height: isTablet ? 90 : 100,
                    width: isTablet ? 90 : 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.umbrella,
                      size: isTablet ? 90 : 100,
                      color: primaryBlue,
                    ),
                  ),

                  SizedBox(height: isTablet ? 25 : 30),

                  // Message personnalisé selon le contexte
                  Text(
                    _getWelcomeMessage(),
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Waltograph',
                      color: reason == 'daily_security'
                          ? Colors.orange[700]
                          : primaryBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 16),

                  // Email (non modifiable)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email, color: primaryBlue, size: 20),
                        SizedBox(width: 10),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: isTablet ? 15 : 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8),

                  // Sous-message
                  Text(
                    _getSubMessage(),
                    style: TextStyle(
                      fontSize: isTablet ? 13 : 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 40),

                  // Champ mot de passe
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: "Mot de passe",
                      labelStyle: TextStyle(color: primaryBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: primaryBlue, width: 2),
                      ),
                      prefixIcon: Icon(Icons.lock, color: primaryBlue),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (reason == 'daily_security')
                            Icon(Icons.security, color: Colors.orange[700]),
                          IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: primaryBlue,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ],
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: isTablet ? 12 : 14),
                    ),
                    onSubmitted: (_) => _login(),
                  ),

                  // Message d'erreur
                  if (_errorMessage != null) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryRed.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: primaryRed, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: primaryRed, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  // Bouton de connexion
                  SizedBox(
                    width: double.infinity,
                    height: isTablet ? 50 : 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: reason == 'daily_security'
                            ? Colors.orange[700]
                            : primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "Se connecter",
                              style: TextStyle(
                                fontSize: isTablet ? 15 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  // Message informatif pour sécurité quotidienne
                  if (reason == 'daily_security') ...[
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange[700], size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Pour votre sécurité, nous demandons votre mot de passe une fois par jour",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
