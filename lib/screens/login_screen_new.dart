import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  void initState() {
    super.initState();

    // Charger l'email sauvegardé si disponible
    _loadSavedEmail();

    // Pour récupérer les paramètres de l'URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Méthode plus sûre pour vérifier les paramètres d'URL
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

        // Vérifier s'il y a des paramètres spécifiques
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

    // Vérifier s'il existe déjà une session active
    _checkExistingSession();
  }

  // Fonction pour vérifier s'il existe une session active
  Future<void> _checkExistingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSessionTime = prefs.getInt('lastSessionTime') ?? 0;
      final currentUser = FirebaseAuth.instance.currentUser;

      // Si l'utilisateur est déjà connecté et la dernière session est récente (moins de 24h)
      if (currentUser != null &&
          (DateTime.now().millisecondsSinceEpoch - lastSessionTime <
              24 * 60 * 60 * 1000)) {
        print("Session active détectée, redirection automatique...");

        // Déterminer le rôle pour la redirection
        final userRole = await _determineUserRole();

        if (mounted) {
          if (userRole == "parent") {
            context.go('/parent/home');
          } else {
            context.go('/home'); // Pour l'assistante maternelle
          }
        }
      }
    } catch (e) {
      print("Erreur lors de la vérification de session: $e");
      // En cas d'erreur, on continue simplement sans redirection
    }
  }

  // Fonction pour charger l'email sauvegardé
  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('savedEmail');

      if (savedEmail != null && savedEmail.isNotEmpty) {
        setState(() {
          emailController.text = savedEmail;
          _rememberMe = true; // Activer l'option si un email est sauvegardé
        });
      }
    } catch (e) {
      print("Erreur lors du chargement de l'email: $e");
    }
  }

  // Fonction pour sauvegarder l'email si l'option est activée
  Future<void> _saveEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_rememberMe && emailController.text.isNotEmpty) {
        await prefs.setString('savedEmail', emailController.text.trim());
      } else {
        // Si l'option est désactivée, supprimer l'email sauvegardé
        await prefs.remove('savedEmail');
      }
    } catch (e) {
      print("Erreur lors de la sauvegarde de l'email: $e");
    }
  }

  // Fonction pour enregistrer la session active
  Future<void> _saveSessionTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'lastSessionTime', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print("Erreur lors de la sauvegarde de la session: $e");
    }
  }

  /// ✅ Connexion avec email & mot de passe
  Future<void> _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
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
      // Tentative de connexion normale
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Sauvegarder l'email si l'option est activée
      await _saveEmail();

      // Enregistrer l'heure de session
      await _saveSessionTime();

      // Déterminer le rôle de l'utilisateur
      final userRole = await _determineUserRole();

      if (mounted) {
        // Rediriger selon le rôle
        if (userRole == "parent") {
          context.go('/parent/home');
        } else {
          context.go('/home'); // Pour l'assistante maternelle
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

  /// Déterminer le rôle de l'utilisateur (parent ou assistante maternelle)
  Future<String> _determineUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "unknown";

      // Vérifier si c'est une assistante maternelle (structure)
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get();

      if (structureDoc.exists) {
        return "assistante";
      }

      // Vérifier si c'est un parent
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get();

      if (userDoc.exists && userDoc.data()?['role'] == 'parent') {
        return "parent";
      }

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
              context.go('/');
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
                    Image.asset('assets/images/parapluie.png',
                        height: logoSize),

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
                            : (_isForgotPassword ? _resetPassword : _login),
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
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
