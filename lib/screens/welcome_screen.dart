import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 🧪 AJOUT : Import pour kDebugMode
import 'package:go_router/go_router.dart';

// 🧪 AJOUT : Import pour le test sandbox
import '../screens/subscription_test_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  Widget build(BuildContext context) {
    // Déterminer si l'appareil est un iPad (écran large)
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    // Adapter la largeur des boutons selon le type d'appareil
    final double buttonWidth = isTablet ? 450 : double.infinity;

    // Adapter la taille du logo selon le type d'appareil
    final double logoSize = isTablet ? 120 : 150;

    // Adapter le padding horizontal selon le type d'appareil
    final double horizontalPadding = isTablet ? 0 : 24;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Titre avec la typographie Disney
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: "Bienvenue sur ",
                      style: TextStyle(
                        fontSize: isTablet ? 30 : 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Waltograph', // Police Disney-like
                      ),
                      children: [
                        TextSpan(
                          text: "Poppin's",
                          style: TextStyle(
                            fontSize: isTablet ? 32 : 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'Waltograph', // Police Disney-like
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Logo parapluie
                  Image.asset(
                    "assets/images/parapluie.png",
                    height: logoSize,
                    width: logoSize,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 50),

                  // Conteneur pour centrer les boutons sur iPad
                  Container(
                    width: buttonWidth,
                    child: Column(
                      children: [
                        // Bouton Email
                        _buildButton(
                          context,
                          text: "Se connecter avec Email",
                          icon: Icons.email_outlined,
                          onPressed: () => context.push('/login'),
                          color: primaryBlue,
                          isPrimary: true,
                          width: buttonWidth,
                        ),

                        const SizedBox(height: 16),

                        // Bouton Email d'Invitation
                        _buildButton(
                          context,
                          text: "J'ai reçu un email d'invitation",
                          icon: Icons.email_outlined,
                          onPressed: () => context.push('/invitation-code'),
                          color: brightCyan,
                          isPrimary: true,
                          width: buttonWidth,
                        ),

                        const SizedBox(height: 20),

                        // 🆕 SECTION NOUVEAU SUR POPPIN'S
                        Container(
                          width: buttonWidth,
                          margin: const EdgeInsets.only(top: 20, bottom: 10),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA), // Gris très léger / bleuté
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE1E8ED),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Nouveau sur Poppin’s ?",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2C3E50),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "La création de compte se fait sur notre site internet.\nUne fois inscrit(e), connectez-vous ici.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Bouton Site Web
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    final Uri url = Uri.parse('https://www.poppin-s.fr');
                                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                      // Gérer l'erreur si nécessaire, ou juste ne rien faire
                                      debugPrint('Could not launch \$url');
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: primaryRed.withOpacity(0.2), // Petite touche de rouge Poppin's
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          "Découvrir Poppin's",
                                          style: TextStyle(
                                            color: primaryRed,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 16,
                                          color: primaryRed,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),



                        // 🧪 NOUVEAU : Bouton de test sandbox (seulement en mode debug)
                        if (kDebugMode) ...[
                          const SizedBox(height: 30),

                          // Séparateur pour les tests
                          SizedBox(
                            width: buttonWidth,
                            child: Row(
                              children: const [
                                Expanded(child: Divider(color: Colors.purple)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    "🧪 DEBUG",
                                    style: TextStyle(
                                      color: Colors.purple,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.purple)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Bouton Test Sandbox
                          _buildButton(
                            context,
                            text: "🧪 Test Abonnements Sandbox",
                            icon: Icons.science,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubscriptionTestScreen(),
                                ),
                              );
                            },
                            color: Colors.purple,
                            isPrimary: true,
                            width: buttonWidth,
                          ),

                          const SizedBox(height: 8),

                          // Note explicative
                          SizedBox(
                            width: buttonWidth,
                            child: Text(
                              "Mode Sandbox activé - Achats gratuits pour test",
                              style: TextStyle(
                                fontSize: isTablet ? 11 : 12,
                                color: Colors.purple[600],
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),



                  const SizedBox(height: 30),

                  // Disclaimer text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "🔐 Cette application est accessible aux professionnels/parents disposant d’un compte ou d'une invitation Poppin’s.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool isPrimary = true,
    required double width,
  }) {
    // Détecter si c'est un iPad
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    // Adapter la hauteur du bouton selon le type d'appareil
    final double buttonHeight = isTablet ? 50 : 56;

    // Adapter la taille du texte selon le type d'appareil
    final double fontSize = isTablet ? 15 : 16;

    return SizedBox(
      width: width,
      height: buttonHeight,
      child: isPrimary
          ? ElevatedButton.icon(
              icon: Icon(icon, color: Colors.white, size: isTablet ? 20 : 22),
              label: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            )
          : OutlinedButton.icon(
              icon: Icon(icon, color: color, size: isTablet ? 20 : 22),
              label: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
    );
  }
}
