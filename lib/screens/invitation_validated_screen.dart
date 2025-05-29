import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InvitationValidatedScreen extends StatelessWidget {
  final Map<String, dynamic> invitationInfo;

  const InvitationValidatedScreen({
    Key? key,
    required this.invitationInfo,
  }) : super(key: key);

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  Widget build(BuildContext context) {
    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;

    // Déterminer si on est sur iPad
    final bool isTablet = screenSize.shortestSide >= 600;

    final String invitationType = invitationInfo['invitationType'] ?? 'unknown';
    final String email = invitationInfo['email'] ?? '';
    final String structureId = invitationInfo['structureId'] ?? '';
    final String structureName =
        invitationInfo['structureName'] ?? 'la structure';

    // Variables spécifiques au type d'invitation
    String messageTitle = "Invitation trouvée !";
    String messageText = "";
    IconData invitationIcon = Icons.group;
    Color accentColor = primaryBlue;

    if (invitationType == 'mamMember') {
      messageText =
          "Vous êtes invité(e) à rejoindre $structureName en tant que membre.";
      invitationIcon = Icons.business;
      accentColor = brightCyan; // Utiliser brightCyan pour les MAM
    } else if (invitationType == 'parent') {
      final String childName = invitationInfo['childName'] ?? 'votre enfant';
      messageText =
          "Vous êtes invité(e) à rejoindre $structureName en tant que parent de $childName.";
      invitationIcon = Icons.family_restroom;
      accentColor = primaryYellow; // Utiliser primaryYellow pour les parents
    } else {
      messageText =
          "Type d'invitation inconnu. Veuillez contacter l'administrateur.";
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Invitation",
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 24 : 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryBlue),
        centerTitle: true,
      ),
      body: isTablet
          ? _buildTabletContent(context, screenSize, messageTitle, messageText,
              invitationIcon, accentColor, email)
          : _buildPhoneContent(context, messageTitle, messageText,
              invitationIcon, accentColor, email),
    );
  }

  Widget _buildPhoneContent(
      BuildContext context, // AJOUTER ce paramètre
      String messageTitle,
      String messageText,
      IconData invitationIcon,
      Color accentColor,
      String email) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icône d'invitation validée
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: accentColor,
          ),

          const SizedBox(height: 30),

          // Titre du message
          Text(
            messageTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryBlue,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Message contextualisé
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    invitationIcon,
                    size: 40,
                    color: accentColor,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    messageText,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Text(
                      "Email associé: $email",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Texte de guidance
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryBlue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Prochaine étape",
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
                  "Veuillez continuer pour créer votre compte et rejoindre la structure.",
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Bouton pour continuer
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                // Rediriger vers la page d'inscription avec les données de l'invitation
                context.go('/invitation-signup', extra: invitationInfo);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "CONTINUER",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Option pour retourner à l'accueil
          TextButton.icon(
            onPressed: () {
              context.go('/');
            },
            icon: Icon(Icons.arrow_back, size: 16, color: primaryBlue),
            label: Text(
              "Retour à l'accueil",
              style: TextStyle(color: primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletContent(
      BuildContext context, // AJOUTER ce paramètre
      Size screenSize,
      String messageTitle,
      String messageText,
      IconData invitationIcon,
      Color accentColor,
      String email) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        // Calculer des dimensions en pourcentages pour une adaptation parfaite
        final double contentWidth = maxWidth * 0.55; // 55% de la largeur
        final double sideMargin =
            (maxWidth - contentWidth) / 2; // Centrage automatique

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              sideMargin,
              maxHeight * 0.06, // 6% de marge en haut
              sideMargin,
              maxHeight * 0.04),
          child: Container(
            width: contentWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(0, 12),
                  blurRadius: 32,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: accentColor.withOpacity(0.1),
                  offset: const Offset(0, 6),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(maxWidth * 0.04),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Container d'en-tête avec icône de validation
                  Container(
                    width: maxWidth * 0.15,
                    height: maxWidth * 0.15,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withOpacity(0.1),
                          accentColor.withOpacity(0.2),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: maxWidth * 0.08,
                      color: accentColor,
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.04),

                  // Titre du message avec design amélioré
                  Text(
                    messageTitle,
                    style: TextStyle(
                      fontSize: maxWidth * 0.032,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: maxHeight * 0.04),

                  // Card d'information modernisée
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(maxWidth * 0.035),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade50,
                          Colors.white,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: accentColor.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Icône spécifique au type d'invitation
                        Container(
                          padding: EdgeInsets.all(maxWidth * 0.02),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            invitationIcon,
                            size: maxWidth * 0.035,
                            color: accentColor,
                          ),
                        ),

                        SizedBox(height: maxHeight * 0.025),

                        // Message principal
                        Text(
                          messageText,
                          style: TextStyle(
                            fontSize: maxWidth * 0.02,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        if (email.isNotEmpty) ...[
                          SizedBox(height: maxHeight * 0.025),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: maxWidth * 0.025,
                              vertical: maxHeight * 0.015,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: accentColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: maxWidth * 0.018,
                                  color: accentColor,
                                ),
                                SizedBox(width: maxWidth * 0.01),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: maxWidth * 0.018,
                                    color: accentColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.045),

                  // Container de guidance modernisé
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(maxWidth * 0.03),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          lightBlue.withOpacity(0.7),
                          lightBlue.withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryBlue.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // En-tête avec icône et titre
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(maxWidth * 0.015),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.info_outline,
                                  color: primaryBlue, size: maxWidth * 0.022),
                            ),
                            SizedBox(width: maxWidth * 0.02),
                            Expanded(
                              child: Text(
                                "Prochaine étape",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                  fontSize: maxWidth * 0.022,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: maxHeight * 0.02),
                        // Description
                        Text(
                          "Veuillez continuer pour créer votre compte et rejoindre la structure.",
                          style: TextStyle(
                            fontSize: maxWidth * 0.019,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.05),

                  // Bouton principal modernisé
                  Container(
                    width: contentWidth * 0.65, // 65% de la largeur du contenu
                    height: maxHeight * 0.08,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        // Rediriger vers la page d'inscription avec les données de l'invitation
                        context.go('/invitation-signup', extra: invitationInfo);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        "CONTINUER",
                        style: TextStyle(
                          fontSize: maxWidth * 0.022,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.035),

                  // Lien retour modernisé
                  TextButton.icon(
                    onPressed: () {
                      context.go('/');
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: maxWidth * 0.025,
                        vertical: maxHeight * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.arrow_back,
                        size: maxWidth * 0.02, color: primaryBlue),
                    label: Text(
                      "Retour à l'accueil",
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: maxWidth * 0.019,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
