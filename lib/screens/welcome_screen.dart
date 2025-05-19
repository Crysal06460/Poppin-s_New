import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

                        // Séparateur
                        SizedBox(
                          width: buttonWidth,
                          child: Row(
                            children: const [
                              Expanded(child: Divider(color: Colors.grey)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text("ou",
                                    style: TextStyle(color: Colors.grey)),
                              ),
                              Expanded(child: Divider(color: Colors.grey)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Bouton Créer un compte
                        _buildButton(
                          context,
                          text: "Créer un compte",
                          icon: Icons.person_add_outlined,
                          onPressed: () => context.push('/register'),
                          color: primaryYellow,
                          isPrimary: true,
                          width: buttonWidth,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
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
