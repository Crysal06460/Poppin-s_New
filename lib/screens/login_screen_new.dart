import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:poppins_app/services/notification_service.dart';
import 'package:poppins_app/services/biometric_auth_service.dart';
import '../utils/user_role_cache.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? errorMessage;
  bool isLoading = false;
  bool _showPassword = false;
  bool _isForgotPassword = false;
  bool _rememberMe = false; // Pour l'option "Se souvenir de moi"
  bool _biometricAvailable = false;
  bool _biometricEnabledForEmail = false;
  bool _enableBiometrics = false;
  String _biometricLabel = 'Biométrie';
  String? _lastBiometricEmailChecked;
  List<BiometricType> _availableBiometricTypes = const [];
  bool _prefilledFromBiometric = false;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  void initState() {
    super.initState();
    emailController.addListener(_onEmailChanged);

    // Charger l'email sauvegardé si disponible
    _loadSavedEmail();
    _initializeBiometrics();

    // Pour récupérer les paramètres de l'URL - GARDEZ CE CODE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final routerState =
            GoRouter.of(context).routerDelegate.currentConfiguration;
        if (routerState != null) {
          final uri = Uri.parse(routerState.uri.toString());
          if (uri.queryParameters.containsKey('forgotPassword') &&
              uri.queryParameters['forgotPassword'] == 'true') {
            setState(() {
              _isForgotPassword = true;
            });
          }
        }

        if (ModalRoute.of(context)?.settings.arguments != null) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          if (args != null && args.containsKey('email')) {
            setState(() {
              emailController.text = args['email'];
            });
          }
        }
      } catch (e) {
        print("Erreur lors de la récupération des paramètres: $e");
      }
    });
  } // ✅ FERMETURE MANQUANTE AJOUTÉE

  // ✅ FONCTION _loadSavedEmail() AJOUTÉE
  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs
          .getString('saved_email'); // ← Changé de 'savedEmail' à 'saved_email'

      if (savedEmail != null && savedEmail.isNotEmpty) {
        setState(() {
          emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
      await _refreshBiometricState();
    } catch (e) {
      print("Erreur lors du chargement de l'email: $e");
    }
  }

  // ✅ FONCTION _saveEmail() CORRIGÉE (UNE SEULE VERSION)
  Future<void> _saveEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_rememberMe && emailController.text.isNotEmpty) {
        await prefs.setString(
            'saved_email', emailController.text.trim()); // ← Changé
        await prefs.setBool('remember_email', true); // ← Ajouté
      } else {
        await prefs.remove('saved_email'); // ← Changé
        await prefs.setBool('remember_email', false); // ← Ajouté
      }
    } catch (e) {
      print("Erreur lors de la sauvegarde de l'email: $e");
    }
  }

  void _onEmailChanged() {
    if (!_biometricAvailable) return;
    _refreshBiometricState();
  }

  Future<void> _initializeBiometrics() async {
    final isAvailable =
        await BiometricAuthService.instance.isBiometricAvailable();
    if (!mounted) return;

    if (!isAvailable) {
      setState(() {
        _biometricAvailable = false;
        _biometricEnabledForEmail = false;
        _enableBiometrics = false;
        _biometricLabel = 'Biométrie';
        _availableBiometricTypes = const [];
        _prefilledFromBiometric = false;
      });
      return;
    }

    final biometrics =
        await BiometricAuthService.instance.getAvailableBiometrics();
    if (!mounted) return;

    setState(() {
      _biometricAvailable = true;
      _availableBiometricTypes = biometrics;
      _biometricLabel = _labelForBiometrics(biometrics);
    });

    await _prefillEmailFromBiometrics();
    await _refreshBiometricState();
  }

  Future<void> _refreshBiometricState() async {
    if (!_biometricAvailable) return;
    final email = emailController.text.trim();
    final normalized = email.toLowerCase();
    _lastBiometricEmailChecked = normalized;

    if (normalized.isEmpty) {
      if (_biometricEnabledForEmail || _enableBiometrics) {
        setState(() {
          _biometricEnabledForEmail = false;
          _enableBiometrics = false;
        });
      }
      return;
    }

    final enabled =
        await BiometricAuthService.instance.isBiometricEnabled(normalized);

    if (!mounted || _lastBiometricEmailChecked != normalized) {
      return;
    }

    setState(() {
      _biometricEnabledForEmail = enabled;
      if (enabled) {
        _enableBiometrics = true;
        _prefilledFromBiometric = true;
      } else if (!_enableBiometrics) {
        _enableBiometrics = false;
      }
    });
  }

  Future<void> _prefillEmailFromBiometrics() async {
    if (!_biometricAvailable) return;
    if (emailController.text.trim().isNotEmpty) return;

    final savedEmail =
        await BiometricAuthService.instance.getLastEnabledEmail();
    if (!mounted) return;

    if (savedEmail != null && savedEmail.isNotEmpty) {
      emailController.text = savedEmail;
      emailController.selection = TextSelection.fromPosition(
        TextPosition(offset: emailController.text.length),
      );
      _prefilledFromBiometric = true;
    }
  }

  String _labelForBiometrics(List<BiometricType> biometrics) {
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    }
    if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Empreinte digitale';
    }
    if (biometrics.contains(BiometricType.iris) ||
        biometrics.contains(BiometricType.strong)) {
      return 'Biométrie sécurisée';
    }
    return 'Biométrie';
  }

  IconData _biometricIcon() {
    if (_availableBiometricTypes.contains(BiometricType.face)) {
      return Icons.face;
    }
    if (_availableBiometricTypes.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    }
    return Icons.lock;
  }

  Future<void> _loginWithBiometrics() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        errorMessage = "Veuillez saisir votre email pour utiliser la biométrie";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final authenticated = await BiometricAuthService.instance.authenticate(
      reason: 'Déverrouillez Poppins avec $_biometricLabel',
    );

    if (!authenticated) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    final savedPassword =
        await BiometricAuthService.instance.getSavedPassword(email);
    if (savedPassword == null || savedPassword.isEmpty) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage =
              "Aucun mot de passe biométrique enregistré. Connectez-vous manuellement.";
          _biometricEnabledForEmail = false;
          _enableBiometrics = false;
        });
      }
      await BiometricAuthService.instance.disableBiometrics(email);
      return;
    }

    passwordController.text = savedPassword;
    await _login(passwordOverride: savedPassword, fromBiometric: true);
  }

  /// ✅ Connexion avec email & mot de passe
  Future<void> _login(
      {String? passwordOverride, bool fromBiometric = false}) async {
    final email = emailController.text.trim();
    final password = (passwordOverride ?? passwordController.text).trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = "Veuillez remplir tous les champs";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Renouveler le token FCM pour éviter d\'hériter d\'un ancien compte
      try {
        await NotificationService.refreshTokenForCurrentUser();
      } catch (_) {}

      // ✅ NOUVELLES SAUVEGARDES
      final prefs = await SharedPreferences.getInstance();

      // Sauvegarder l'email si l'option est activée
      await _saveEmail();

      // Marquer comme connecté
      await prefs.setBool('is_logged_in', true);

      // 🔒 NOUVEAU : Marquer la date de connexion d'aujourd'hui
      final String today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('last_login_date', today);

      // Enregistrer l'heure de session pour gestion arrière-plan
      await prefs.setInt(
          'lastSessionTime', DateTime.now().millisecondsSinceEpoch);

      if (!fromBiometric && _biometricAvailable) {
        if (_enableBiometrics) {
          await BiometricAuthService.instance.enableBiometrics(email, password);
          if (mounted) {
            setState(() {
              _biometricEnabledForEmail = true;
            });
          }
        } else if (_biometricEnabledForEmail) {
          await BiometricAuthService.instance.disableBiometrics(email);
          if (mounted) {
            setState(() {
              _biometricEnabledForEmail = false;
            });
          }
        }
      }

      // Déterminer le rôle de l'utilisateur et naviguer
      final userRole = await _determineUserRole();
      UserRoleCache.setRole(userRole == "parent" ? 'parent' : 'structure');

      if (mounted) {
        if (userRole == "parent") {
          _goAfterLogin('/parent/home');
        } else {
          _goAfterLogin('/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = _getFirebaseErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        errorMessage = "Une erreur inattendue s'est produite";
      });
      print("Erreur de connexion: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _goAfterLogin(String route) {
    NotificationService.setAuthenticationRequired(false);
    context.go(route);
    Future.delayed(const Duration(milliseconds: 250), () {
      NotificationService.synchronizeMissedNotifications();
      NotificationService.showPendingNotificationWhenReady();
    });
  }

  /// Déterminer le rôle de l'utilisateur (parent ou assistante maternelle)
  Future<String> _determineUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "unknown";

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get();

      final String role =
          (userDoc.data()?['role'] ?? '').toString().toLowerCase();
      const parentRoles = {'parent', 'parent_employeur', 'parentemployeur'};

      if (parentRoles.contains(role)) {
        print('🔍 Login: rôle utilisateur Firestore = ' + role);
        UserRoleCache.setRole('parent');
        return "parent";
      }

      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get();

      if (structureDoc.exists) {
        final structureType = (structureDoc.data()?['structureType'] ?? '')
            .toString()
            .toLowerCase();
        print('🔍 Login: structureType Firestore = ' + structureType);
        UserRoleCache.setStructureType(structureType);
        UserRoleCache.setRole('structure');
        return "assistante";
      }

      UserRoleCache.setRole(null);
      return "unknown";
    } catch (e) {
      print("Erreur lors de la détermination du rôle: $e");
      return "unknown";
    }
  }

  /// ✅ Fonction pour réinitialiser le mot de passe
  Future<void> _resetPassword() async {
    if (emailController.text.isEmpty) {
      setState(() => errorMessage =
          "Veuillez entrer votre email pour réinitialiser le mot de passe.");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: emailController.text.trim());

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        // Afficher une notification de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Un email de réinitialisation a été envoyé à ${emailController.text}"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Si on est en mode mot de passe oublié, revenir au mode connexion
        if (_isForgotPassword) {
          setState(() {
            _isForgotPassword = false;
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = _getFirebaseErrorMessage(e.code);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Une erreur inattendue s'est produite";
          isLoading = false;
        });
      }
    }
  }

  /// ✅ Gestion des erreurs Firebase en français
  String _getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case "invalid-email":
        return "L'adresse email est invalide.";
      case "user-not-found":
        return "Aucun compte trouvé pour cet email.";
      case "wrong-password":
        return "Mot de passe incorrect.";
      case "invalid-credential": // ← NOUVEAU CODE D'ERREUR
        return "Email inconnu ou mot de passe incorrect.";
      case "user-disabled":
        return "Ce compte utilisateur a été désactivé.";
      case "too-many-requests":
        return "Trop de tentatives de connexion. Veuillez réessayer plus tard.";
      case "operation-not-allowed":
        return "La connexion par email et mot de passe n'est pas activée.";
      case "email-already-in-use":
        return "Cette adresse email est déjà utilisée par un autre compte.";
      case "network-request-failed":
        return "Vérifiez votre connexion internet.";
      case "weak-password":
        return "Le mot de passe est trop faible.";
      case "account-exists-with-different-credential":
        return "Un compte existe déjà avec cette adresse email.";
      default:
        return "Une erreur est survenue: $errorCode";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Déterminer si l'appareil est un iPad (écran large)
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    // Adapter les dimensions en fonction du type d'appareil
    final double contentMaxWidth = isTablet ? 480 : double.infinity;
    final double logoSize = isTablet ? 90 : 100;
    final double horizontalPadding = isTablet ? 0 : 24;
    final double buttonHeight = isTablet ? 50 : 56;
    final double fontSize = isTablet ? 15 : 16;
    final double titleFontSize = isTablet ? 24 : 26;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isForgotPassword ? "Mot de passe oublié" : "Connexion",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () {
            if (_isForgotPassword) {
              setState(() {
                _isForgotPassword = false;
              });
            } else {
              context.go('/welcome'); // ✅ CHANGÉ DE '/' vers '/welcome'
            }
          },
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                width: contentMaxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                        height: 30), // Légèrement plus petit pour iPad

                    // Logo ou image de l'application
                    Image.asset(
                      'assets/images/parapluie.png',
                      height: logoSize,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.umbrella,
                        size: logoSize,
                        color: primaryBlue,
                      ),
                    ),

                    const SizedBox(
                        height: 25), // Légèrement plus petit pour iPad

                    if (_isForgotPassword)
                      Text(
                        "Réinitialisation du mot de passe",
                        style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 20),

                    // Texte explicatif pour la réinitialisation de mot de passe
                    if (_isForgotPassword)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: primaryBlue.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: primaryBlue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Comment récupérer votre mot de passe",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe.",
                              style: TextStyle(
                                  fontSize: 14, color: Colors.black87),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.mark_email_unread_outlined,
                                    color: primaryBlue, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Le message peut mettre quelques minutes à arriver et peut se trouver dans vos courriers indésirables (spam). Pensez à vérifier.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // ✅ Champ Email
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: TextStyle(color: primaryBlue),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: isTablet ? 12 : 14),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                        prefixIcon:
                            Icon(Icons.email_outlined, color: primaryBlue),
                      ),
                    ),

                    // Ajout de l'option "Se souvenir de moi"
                    if (!_isForgotPassword) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                        child: Row(
                          children: [
                            Transform.scale(
                              scale: isTablet ? 0.9 : 1.0,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            Text(
                              "Se souvenir de mon email",
                              style: TextStyle(
                                fontSize: isTablet ? 13 : 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (!_isForgotPassword) ...[
                      const SizedBox(height: 15),

                      // ✅ Champ Mot de passe
                      TextField(
                        controller: passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: "Mot de passe",
                          labelStyle: TextStyle(color: primaryBlue),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: isTablet ? 12 : 14),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: primaryBlue, width: 2),
                          ),
                          prefixIcon:
                              Icon(Icons.lock_outline, color: primaryBlue),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: primaryBlue,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),

                      const SizedBox(height: 10),

                      if (_biometricAvailable) ...[
                        SwitchListTile.adaptive(
                          value: _enableBiometrics,
                          contentPadding: EdgeInsets.zero,
                          activeColor: primaryBlue,
                          onChanged: emailController.text.trim().isEmpty
                              ? null
                              : (value) async {
                                  setState(() {
                                    _enableBiometrics = value;
                                  });

                                  if (!value && _biometricEnabledForEmail) {
                                    final email = emailController.text.trim();
                                    await BiometricAuthService.instance
                                        .disableBiometrics(email);
                                    if (mounted) {
                                      setState(() {
                                        _biometricEnabledForEmail = false;
                                        _prefilledFromBiometric = false;
                                      });
                                    }
                                  }
                                },
                          title: Text('Activer $_biometricLabel'),
                          subtitle: Text(
                            "Utiliser $_biometricLabel pour les prochaines connexions",
                            style: TextStyle(fontSize: isTablet ? 12 : 13),
                          ),
                        ),
                      ],

                      if (_biometricEnabledForEmail) ...[
                        SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                isLoading ? null : () => _loginWithBiometrics(),
                            icon: Icon(_biometricIcon(), color: primaryBlue),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: isTablet ? 12 : 14,
                              ),
                              side: BorderSide(color: primaryBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            label: Text(
                              "Déverrouiller avec $_biometricLabel",
                              style: TextStyle(
                                color: primaryBlue,
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ✅ Lien "Mot de passe oublié"
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isForgotPassword = true;
                                  });
                                },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 12 : 16,
                              vertical: isTablet ? 6 : 8,
                            ),
                          ),
                          child: Text("Mot de passe oublié ?",
                              style: TextStyle(
                                color: primaryBlue,
                                fontSize: isTablet ? 14 : 15,
                              )),
                        ),
                      ),
                    ],

                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: primaryRed.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: primaryRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(
                                    color: primaryRed,
                                    fontSize: isTablet ? 13 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Bouton principal (se connecter ou réinitialiser)
                    SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                if (_isForgotPassword) {
                                  _resetPassword();
                                } else {
                                  _login();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 12 : 14,
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                height: isTablet ? 22 : 24,
                                width: isTablet ? 22 : 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isForgotPassword
                                    ? "Réinitialiser mon mot de passe"
                                    : "Se connecter",
                                style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),

                    if (!_isForgotPassword) ...[
                      const SizedBox(height: 20),

                      // Séparateur
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text("ou",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: isTablet ? 13 : 14,
                                )),
                          ),
                          Expanded(child: Divider(color: Colors.grey)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Lien pour créer un compte
                      TextButton.icon(
                        onPressed: () {
                          // Navigation vers la page d'inscription
                          context.push('/register');
                        },
                        icon: Icon(
                          Icons.person_add_outlined,
                          color: primaryYellow,
                          size: isTablet ? 20 : 22,
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 16 : 20,
                            vertical: isTablet ? 8 : 10,
                          ),
                        ),
                        label: Text(
                          "Créer un compte",
                          style: TextStyle(
                              color: primaryYellow,
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize),
                        ),
                      ),
                    ],

                    SizedBox(height: isTablet ? 20 : 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.removeListener(_onEmailChanged);
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
