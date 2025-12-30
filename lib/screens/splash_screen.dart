import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/subscription_service.dart';
import '../utils/user_role_cache.dart';
import '../services/firebase_trial_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  String _statusText = "Initialisation...";
  double _progress = 0.0;
  bool _hasError = false;

  // 🎨 PERSONNALISATION : Couleurs et design
  static const Color backgroundGradientStart =
      Color(0xFF3D9DF2); // Bleu principal
  static const Color backgroundGradientEnd =
      Color(0xFF2B7BD9); // Bleu plus foncé
  static const Color logoBackgroundColor = Colors.white;
  static const Color logoIconColor = Color(0xFF3D9DF2);
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Color(0xFFE8F4FD); // Blanc cassé
  static const Color progressBarColor = Colors.white;
  static const Color progressBackgroundColor =
      Color(0x4DFFFFFF); // Blanc transparent

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeServices();
  }

  void _setupAnimations() {
    // Animation de pulsation du logo
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Animation de fade pour le texte
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // 1. Vérification de l'authentification
      _updateProgress(0.1, "On ouvre le parapluie magique...");
      await Future.delayed(Duration(milliseconds: 800));

      final User? user = FirebaseAuth.instance.currentUser;

      // 2. Connexion aux services
      _updateProgress(0.3, "Un peu de sucre... pour activer les services ✨");
      await Future.delayed(Duration(milliseconds: 600));

      // 3. Services d'abonnement avec timeout
      _updateProgress(0.5, "On range les jouets dans le sac sans fond 🎒");

      try {
        await SubscriptionService.initialize().timeout(
          Duration(seconds: 15),
          onTimeout: () {
            print('⚠️ Timeout SubscriptionService');
            throw TimeoutException('Services lents');
          },
        );
        _updateProgress(0.8, "Le vent d'Est souffle... tout est prêt !");
        await Future.delayed(Duration(milliseconds: 500));
      } catch (e) {
        print('⚠️ Erreur services: $e');
        _updateProgress(0.8,
            "Le cerf-volant s'est emmêlé... passage en mode hors ligne 🪁");
        await Future.delayed(Duration(milliseconds: 500));
      }

      // 4. Finalisation
      _updateProgress(0.95, "Mise en place des petits chaussons 👟...");
      await Future.delayed(Duration(milliseconds: 400));

      _updateProgress(1.0, "Abracadabra... Bienvenue dans Poppin's ! 🎉");
      await Future.delayed(Duration(milliseconds: 300));

      // 5. Navigation avec fallback robuste
      _pulseController.stop();
      _fadeController.reverse();
      await Future.delayed(Duration(milliseconds: 200));

      // Navigation avec gestion d'erreur
      await _navigateAfterSplash(user);
    } catch (e) {
      print('❌ Erreur critique: $e');
      _handleError();
    }
  }

  // ✅ MÉTHODE AMÉLIORÉE : Navigation après splash avec gestion d'erreur robuste
  Future<void> _navigateAfterSplash(User? user) async {
    try {
      if (user != null) {
        print("✅ Utilisateur connecté: ${user.email}");

          // ✅ AMÉLIORATION : Vérification avec timeout pour éviter les blocages
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.email?.toLowerCase() ?? '')
                .get()
                .timeout(Duration(seconds: 3));

            final String userRole =
                (userDoc.data()?['role'] ?? '').toString().toLowerCase();
            print('🔍 Splash: rôle utilisateur Firestore = ' + userRole);
            const parentRoles = {'parent', 'parent_employeur', 'parentemployeur'};
            final String structureId =
                (userDoc.data()?['structureId'] ?? user.uid).toString();

            if (parentRoles.contains(userRole)) {
              print("✅ Utilisateur parent détecté, redirection vers parent home");
              UserRoleCache.setRole('parent');
              final bool allowed =
                  await _ensureActiveAccessOrRedirect(structureId: structureId);
              if (allowed && mounted) context.go('/parent/home');
              return;
            }

            final structureDoc = await FirebaseFirestore.instance
                .collection('structures')
                .doc(structureId)
                .get()
                .timeout(
              Duration(seconds: 5),
              onTimeout: () {
                print("⚠️ Timeout vérification structure");
              throw TimeoutException('Vérification structure lente');
            },
          );

          if (structureDoc.exists) {
            final String structureType =
                (structureDoc.data()?['structureType'] ?? '')
                    .toString()
                    .toLowerCase();
            print('🔍 Splash: structureType Firestore = ' + structureType);
            UserRoleCache.setStructureType(structureType);
            if (parentRoles.contains(structureType)) {
              print(
                  "✅ Structure parent employeur détectée, redirection vers parent home");
              UserRoleCache.setRole('parent');
              final bool allowed = await _ensureActiveAccessOrRedirect(
                structureId: structureId,
                structureDoc: structureDoc,
              );
              if (allowed && mounted) context.go('/parent/home');
              return;
            }

            print("✅ Structure trouvée, redirection vers dashboard");
            UserRoleCache.setRole('structure');
            final bool allowed = await _ensureActiveAccessOrRedirect(
              structureId: structureId,
              structureDoc: structureDoc,
            );
            if (allowed && mounted) context.go('/dashboard');
          } else {
            print("⚠️ Structure non trouvée pour uid: ${user.uid}");
            UserRoleCache.setRole(null);
            if (mounted) context.go('/');
          }
        } catch (e) {
          print("⚠️ Erreur vérification structure/utilisateur: $e");
          UserRoleCache.setRole(null);
          if (mounted) context.go('/');
        }
      } else {
        print("ℹ️ Utilisateur non connecté, redirection vers Welcome");
        UserRoleCache.setRole(null);
        if (mounted) context.go('/');
      }
    } catch (e) {
      print("❌ Erreur navigation critique: $e, fallback vers Welcome");
      // En cas d'erreur, toujours rediriger vers Welcome
      if (mounted) {
        context.go('/');
      }
    }
  }

  Future<bool> _ensureActiveAccessOrRedirect({
    String? structureId,
    DocumentSnapshot<Map<String, dynamic>>? structureDoc,
  }) async {
    try {
      final bool subscribed = await SubscriptionService.isUserSubscribed();
      final TrialStatus trialStatus =
          await FirebaseTrialService.fetchTrialStatusForCurrentUser();
      final bool hasActiveTrial = trialStatus.isActive;

      if (!hasActiveTrial && trialStatus.isExpired) {
        await FirebaseTrialService.markTrialExpiredForCurrentUser();
      }

      if (subscribed || hasActiveTrial) {
        return true;
      }

      final Map<String, dynamic> extras = _buildPricingExtras(
        structureId: structureId,
        structureDoc: structureDoc,
      );

      if (mounted) {
        context.go('/pricing', extra: extras);
      }
      return false;
    } catch (e) {
      print("❌ Erreur vérification accès actif (splash): $e");
      if (mounted) {
        context.go(
          '/pricing',
          extra: _buildPricingExtras(
            structureId: structureId,
            structureDoc: structureDoc,
          ),
        );
      }
      return false;
    }
  }

  Map<String, dynamic> _buildPricingExtras({
    String? structureId,
    DocumentSnapshot<Map<String, dynamic>>? structureDoc,
  }) {
    final Map<String, dynamic> data = structureDoc?.data() ?? {};

    String structureType =
        (data['structureType'] ?? 'assistante_maternelle').toString();
    structureType = structureType.toLowerCase().contains('mam')
        ? 'mam'
        : 'assistante_maternelle';

    int? memberCount;
    final dynamic preferredPlan = data['mamPreferredPlan'];
    final dynamic maxMemberCount = data['maxMemberCount'];
    final dynamic memberCountRaw = data['memberCount'];

    if (preferredPlan is int && preferredPlan > 0) {
      memberCount = preferredPlan;
    } else if (memberCountRaw is int && memberCountRaw > 0) {
      memberCount = memberCountRaw;
    } else if (maxMemberCount is int && maxMemberCount > 0) {
      memberCount = maxMemberCount;
    }

    return {
      'structureType': structureType,
      if (structureType == 'mam' && memberCount != null) 'memberCount': memberCount,
    };
  }

  // ✅ MÉTHODE AMÉLIORÉE : Gestion d'erreur avec retry automatique
  void _handleError() {
    if (!mounted) return;

    setState(() {
      _hasError = true;
      _statusText = "Connexion difficile...";
    });

    // Retry automatique avec fallback vers Welcome
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        _retryOrContinue();
      }
    });
  }

  // ✅ MÉTHODE AMÉLIORÉE : Retry avec fallback garanti
  Future<void> _retryOrContinue() async {
    if (!mounted) return;

    setState(() {
      _hasError = false;
      _statusText = "Nouvelle tentative...";
      _progress = 0.0;
    });

    await Future.delayed(Duration(milliseconds: 500));

    try {
      await _initializeServices();
    } catch (e) {
      print("❌ Échec retry définitif: $e, redirection vers Welcome");
      // En cas d'échec définitif, toujours aller vers Welcome
      if (mounted) {
        context.go('/');
      }
    }
  }

  void _updateProgress(double progress, String status) {
    if (mounted) {
      setState(() {
        _progress = progress;
        _statusText = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 🎨 FOND AVEC GRADIENT PERSONNALISABLE
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundGradientStart,
              backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🎨 LOGO PERSONNALISABLE
                  _buildAnimatedLogo(),

                  SizedBox(height: 50),

                  // 🎨 NOM DE L'APP PERSONNALISABLE
                  _buildAppTitle(),

                  SizedBox(height: 20),

                  // 🎨 SLOGAN PERSONNALISABLE (OPTIONNEL)
                  _buildSlogan(),

                  SizedBox(height: 70),

                  // 🎨 BARRE DE PROGRESSION PERSONNALISABLE
                  _buildProgressBar(),

                  SizedBox(height: 25),

                  // 🎨 TEXTE DE STATUT PERSONNALISABLE
                  _buildStatusText(),

                  SizedBox(height: 15),

                  // 🎨 POURCENTAGE PERSONNALISABLE
                  _buildPercentage(),

                  // 🎨 GESTION D'ERREUR PERSONNALISABLE
                  if (_hasError) _buildErrorWidget(),

                  SizedBox(height: 100),

                  // 🎨 FOOTER PERSONNALISABLE
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 COMPOSANTS PERSONNALISABLES

  Widget _buildAnimatedLogo() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Image.asset(
        'assets/images/app_icon.png', // 🎨 VOTRE PARAPLUIE SANS FOND
        width: 130, // 🎨 TAILLE PERSONNALISABLE
        height: 130,
        fit: BoxFit.contain, // Garde les proportions
        // ✅ NOUVEAU : Gestion d'erreur si l'image n'existe pas
        errorBuilder: (context, error, stackTrace) {
          print("⚠️ Erreur chargement logo: $error");
          return Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.umbrella,
              size: 60,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppTitle() {
    return Column(
      children: [
        Text(
          // 🎨 NOM DE L'APP PERSONNALISABLE
          "Poppin's",
          style: TextStyle(
            fontSize: 34, // 🎨 TAILLE PERSONNALISABLE
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
            letterSpacing: 1.5,
            // 🎨 OMBRE POUR LE TEXTE
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlogan() {
    return Text(
      // 🎨 SLOGAN PERSONNALISABLE (masquer en commentant cette ligne)
      "",
      style: TextStyle(
        fontSize: 16,
        color: textSecondaryColor,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildProgressBar() {
    return Container(
      width: 220, // 🎨 LARGEUR PERSONNALISABLE
      height: 6, // 🎨 HAUTEUR PERSONNALISABLE
      decoration: BoxDecoration(
        color: progressBackgroundColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _progress,
        child: Container(
          decoration: BoxDecoration(
            color: progressBarColor,
            borderRadius: BorderRadius.circular(3),
            // 🎨 EFFET GLOW SUR LA BARRE
            boxShadow: [
              BoxShadow(
                color: progressBarColor.withOpacity(0.6),
                blurRadius: 8,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: Text(
        _statusText,
        key: ValueKey(_statusText), // Pour l'animation de transition
        style: TextStyle(
          fontSize: 17, // 🎨 TAILLE PERSONNALISABLE
          color: textPrimaryColor,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPercentage() {
    return Text(
      "${(_progress * 100).toInt()}%",
      style: TextStyle(
        fontSize: 15, // 🎨 TAILLE PERSONNALISABLE
        color: textSecondaryColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      margin: EdgeInsets.only(top: 30, left: 50, right: 50), // ✅ COMBINÉ
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        // 🎨 OMBRE POUR LA CARTE D'ERREUR
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🎨 ICÔNE D'ERREUR PERSONNALISABLE
          Icon(
            Icons
                .wifi_off, // Changez par : Icons.error, Icons.signal_wifi_off, etc.
            color: Colors.white,
            size: 28,
          ),
          SizedBox(height: 12),
          Text(
            // 🎨 TEXTE D'ERREUR PERSONNALISABLE
            "Connexion lente détectée",
            style: TextStyle(
              fontSize: 16,
              color: textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            // 🎨 SOUS-TEXTE D'ERREUR PERSONNALISABLE
            "Nouvelle tentative en cours...",
            style: TextStyle(
              fontSize: 13,
              color: textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          // 🎨 VERSION PERSONNALISABLE
          "Version 1.0.2",
          style: TextStyle(
            fontSize: 13,
            color: textSecondaryColor.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 5),
        Text(
          // 🎨 TEXTE FOOTER PERSONNALISABLE
          "Chargement intelligent",
          style: TextStyle(
            fontSize: 11,
            color: textSecondaryColor.withOpacity(0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ✅ CLASSE D'EXCEPTION POUR LES TIMEOUTS
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
