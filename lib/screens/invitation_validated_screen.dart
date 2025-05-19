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
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryBlue),
        centerTitle: true,
      ),
      body: Padding(
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
      ),
    );
  }
}
