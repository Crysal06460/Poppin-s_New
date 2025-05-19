import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String errorMessage = "";
  bool isLoading = false;
  bool isAssistanteMaterCheck = true;
  bool isMAMCheck = false;

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
    final double titleFontSize = isTablet ? 22 : 24;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Inscription",
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () => Navigator.of(context).pop(),
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
                        height: 25), // Légèrement plus petit pour iPad

                    // Logo
                    Image.asset(
                      "assets/images/parapluie.png",
                      height: logoSize,
                      width: logoSize,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(
                        height: 25), // Légèrement plus petit pour iPad

                    Text(
                      "Créer un compte structure",
                      style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Sélection du type de structure - Adaptée pour iPad
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: isTablet ? 20 : 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTypeCheckbox(
                              title: "Assistante Maternelle",
                              isChecked: isAssistanteMaterCheck,
                              onChanged: (value) {
                                if (value == true) {
                                  setState(() {
                                    isAssistanteMaterCheck = true;
                                    isMAMCheck = false;
                                  });
                                }
                              },
                              isTablet: isTablet,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTypeCheckbox(
                              title: "MAM",
                              isChecked: isMAMCheck,
                              onChanged: (value) {
                                if (value == true) {
                                  setState(() {
                                    isAssistanteMaterCheck = false;
                                    isMAMCheck = true;
                                  });
                                }
                              },
                              isTablet: isTablet,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Message d'information pour MAM - Adapté pour iPad
                    if (isMAMCheck)
                      Container(
                        padding: EdgeInsets.all(isTablet ? 14 : 16),
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
                                Icon(Icons.info_outline,
                                    color: primaryBlue,
                                    size: isTablet ? 18 : 20),
                                SizedBox(width: isTablet ? 6 : 8),
                                Expanded(
                                  child: Text(
                                    "Information importante",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryBlue,
                                      fontSize: isTablet ? 13 : 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isTablet ? 6 : 8),
                            Text(
                              "Un seul membre de la MAM doit créer le compte. Les autres membres pourront être ajoutés par la suite via des invitations.",
                              style: TextStyle(
                                  fontSize: isTablet ? 12 : 13,
                                  color: Color(0xFF455A64)),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Champs de formulaire adaptés pour iPad
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: TextStyle(color: primaryBlue),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: primaryBlue, width: 2)),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: isTablet ? 12 : 14),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 16), // Plus compact pour iPad

                    // Champ mot de passe
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Mot de passe",
                        labelStyle: TextStyle(color: primaryBlue),
                        helperText: "Minimum 6 caractères",
                        helperStyle: TextStyle(
                          color: primaryBlue.withOpacity(0.7),
                          fontSize: isTablet ? 11 : 12,
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: primaryBlue, width: 2)),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: isTablet ? 12 : 14),
                      ),
                    ),

                    const SizedBox(height: 16), // Plus compact pour iPad

                    // Champ confirmation mot de passe
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Confirmer le mot de passe",
                        labelStyle: TextStyle(color: primaryBlue),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: primaryBlue, width: 2)),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: isTablet ? 12 : 14),
                      ),
                    ),

                    // Affichage des erreurs - Adapté pour iPad
                    if (errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
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
                                  color: primaryRed, size: isTablet ? 16 : 18),
                              SizedBox(width: isTablet ? 6 : 8),
                              Expanded(
                                child: Text(
                                  errorMessage,
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

                    const SizedBox(height: 25), // Ajusté pour iPad

                    // Bouton S'inscrire - Adapté pour iPad
                    SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryYellow,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 12 : 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
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
                                "S'INSCRIRE",
                                style: TextStyle(
                                    fontSize: isTablet ? 16 : 18,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16), // Plus compact pour iPad

                    // Déjà un compte - Adapté pour iPad
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Vous avez déjà un compte ?",
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 15,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context.go('/login');
                          },
                          child: Text(
                            "Se connecter",
                            style: TextStyle(
                              color: primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: isTablet ? 14 : 15,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryBlue,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 8 : 10,
                              vertical: isTablet ? 4 : 6,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16), // Plus petit pour iPad
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCheckbox({
    required String title,
    required bool isChecked,
    required Function(bool?) onChanged,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: isTablet ? 10 : 12, horizontal: isTablet ? 12 : 16),
      decoration: BoxDecoration(
        color: isChecked ? primaryBlue.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChecked ? primaryBlue : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isTablet ? 20 : 24,
            height: isTablet ? 20 : 24,
            child: Transform.scale(
              scale: isTablet ? 0.9 : 1.0,
              child: Checkbox(
                value: isChecked,
                onChanged: onChanged,
                activeColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 6 : 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isTablet ? 13 : 14,
                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                color: isChecked ? primaryBlue : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    // Validation de base
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      setState(() {
        errorMessage = "Veuillez remplir tous les champs";
      });
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        errorMessage = "Les mots de passe ne correspondent pas";
      });
      return;
    }

    if (passwordController.text.length < 6) {
      setState(() {
        errorMessage = "Le mot de passe doit contenir au moins 6 caractères";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      // Créer l'utilisateur
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim().toLowerCase(),
        password: passwordController.text.trim(),
      );

      // Déterminer le type de structure sélectionné
      final String structureType = isMAMCheck ? 'MAM' : 'AssistanteMaternelle';

      // Créer le document structure dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(userCredential.user!.uid)
          .set({
        'email': emailController.text.trim().toLowerCase(),
        'structureType': structureType,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Après l'inscription, rediriger vers l'écran de tarification
      if (mounted) {
        context.go('/pricing', extra: {
          'structureType': structureType,
          'structureId': userCredential.user!.uid,
        });
      }
    } catch (e) {
      String message = "Une erreur est survenue lors de l'inscription";

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            message = "Cette adresse e-mail est déjà utilisée";
            break;
          case 'invalid-email':
            message = "Format d'e-mail invalide";
            break;
          case 'weak-password':
            message = "Le mot de passe est trop faible (minimum 6 caractères)";
            break;
        }
      }

      setState(() {
        errorMessage = message;
        isLoading = false;
      });
    }
  }
}
