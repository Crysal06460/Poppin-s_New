import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvitationCodeScreen extends StatefulWidget {
  const InvitationCodeScreen({Key? key}) : super(key: key);

  @override
  _InvitationCodeScreenState createState() => _InvitationCodeScreenState();
}

class _InvitationCodeScreenState extends State<InvitationCodeScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Invitation",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 24 : 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: isTablet ? _buildTabletContent(screenSize) : _buildPhoneContent(),
    );
  }

  Widget _buildPhoneContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image d'invitation
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Image.asset(
                'assets/images/logo.png',
                height: 120,
                width: 120,
                fit: BoxFit.contain,
              ),
            ),

            // Texte explicatif
            Text(
              "Avez-vous été invité(e) à rejoindre Poppins ?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Container informatif
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
                          "Comment utiliser votre invitation",
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
                    "Entrez l'adresse email à laquelle vous avez reçu l'invitation pour rejoindre une structure existante en tant que parent ou membre d'une MAM.",
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Champ d'email
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Adresse email",
                hintText: "Entrez votre email",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: brightCyan, width: 2),
                ),
                prefixIcon: Icon(Icons.email_outlined, color: brightCyan),
                labelStyle: TextStyle(color: brightCyan),
              ),
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 30),

            // Bouton de validation
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : _validateInvitationEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brightCyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "VALIDER L'EMAIL",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Lien "Retour à l'accueil"
            TextButton.icon(
              onPressed: () {
                context.go('/');
              },
              icon: Icon(Icons.arrow_back, size: 16, color: primaryBlue),
              label: Text(
                "Retour à l'accueil",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Affichage des erreurs
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryRed.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: primaryRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: TextStyle(color: primaryRed, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletContent(Size screenSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        // Calculer des dimensions en pourcentages pour une adaptation parfaite
        final double contentWidth = maxWidth * 0.6; // 60% de la largeur
        final double sideMargin =
            (maxWidth - contentWidth) / 2; // Centrage automatique

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              sideMargin,
              maxHeight * 0.04, // 4% de marge en haut
              sideMargin,
              maxHeight * 0.04),
          child: Container(
            width: contentWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(maxWidth * 0.04), // 4% de padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo avec taille adaptative
                  Container(
                    width: maxWidth * 0.12, // 12% de la largeur totale
                    height: maxWidth * 0.12,
                    margin: EdgeInsets.symmetric(vertical: maxHeight * 0.03),
                    decoration: BoxDecoration(
                      color: lightBlue.withOpacity(0.3),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(maxWidth * 0.02),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Titre principal avec taille adaptative
                  Text(
                    "Avez-vous été invité(e) à rejoindre Poppins ?",
                    style: TextStyle(
                      fontSize: maxWidth * 0.028, // 2.8% de la largeur
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: maxHeight * 0.035),

                  // Container informatif moderne
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(maxWidth * 0.025),
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
                        color: primaryBlue.withOpacity(0.2),
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
                                  color: primaryBlue, size: maxWidth * 0.02),
                            ),
                            SizedBox(width: maxWidth * 0.02),
                            Expanded(
                              child: Text(
                                "Comment utiliser votre invitation",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                  fontSize: maxWidth * 0.02,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: maxHeight * 0.02),
                        // Description
                        Text(
                          "Entrez l'adresse email à laquelle vous avez reçu l'invitation pour rejoindre une structure existante en tant que parent ou membre d'une MAM.",
                          style: TextStyle(
                            fontSize: maxWidth * 0.018,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.045),

                  // Champ d'email moderne et adaptatif
                  Container(
                    width: double.infinity,
                    child: TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontSize: maxWidth * 0.02),
                      decoration: InputDecoration(
                        labelText: "Adresse email",
                        hintText: "Entrez votre email",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: maxWidth * 0.025,
                          vertical: maxHeight * 0.025,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: brightCyan, width: 2.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Colors.grey.shade300, width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(maxWidth * 0.015),
                          child: Icon(Icons.email_outlined,
                              color: brightCyan, size: maxWidth * 0.022),
                        ),
                        labelStyle: TextStyle(
                          color: brightCyan,
                          fontSize: maxWidth * 0.018,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: maxWidth * 0.018,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.045),

                  // Bouton de validation moderne
                  Container(
                    width: contentWidth * 0.7, // 70% de la largeur du contenu
                    height: maxHeight * 0.08,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: brightCyan.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _validateInvitationEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brightCyan,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: brightCyan.withOpacity(0.6),
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: maxWidth * 0.025,
                              width: maxWidth * 0.025,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              "VALIDER L'EMAIL",
                              style: TextStyle(
                                fontSize: maxWidth * 0.02,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.035),

                  // Lien "Retour à l'accueil" moderne
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
                        fontWeight: FontWeight.w500,
                        fontSize: maxWidth * 0.018,
                      ),
                    ),
                  ),

                  // Affichage des erreurs adaptatif
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: maxHeight * 0.025),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(maxWidth * 0.02),
                        decoration: BoxDecoration(
                          color: primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryRed.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryRed.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(maxWidth * 0.01),
                              decoration: BoxDecoration(
                                color: primaryRed.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.error_outline,
                                  color: primaryRed, size: maxWidth * 0.02),
                            ),
                            SizedBox(width: maxWidth * 0.015),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: TextStyle(
                                  color: primaryRed,
                                  fontSize: maxWidth * 0.017,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
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

  Future<void> _validateInvitationEmail() async {
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      setState(() {
        errorMessage = "Veuillez entrer une adresse email";
      });
      return;
    }

    // Validation simple de format d'email
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(email)) {
      setState(() {
        errorMessage = "Format d'email invalide";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Rechercher les invitations correspondant à cet email
      final invitationsQuery = await FirebaseFirestore.instance
          .collection('invitations')
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'active')
          .get();

      if (invitationsQuery.docs.isEmpty) {
        setState(() {
          errorMessage = "Aucune invitation trouvée pour cet email";
          isLoading = false;
        });
        return;
      }

      // Récupérer les informations d'invitation
      final invitationData = invitationsQuery.docs.first.data();
      final String invitationType = invitationData['type'] ?? 'unknown';
      final String structureId = invitationData['structureId'] ?? '';

      // Vérifier si l'invitation est valide
      final DateTime expirationDate =
          invitationData['expiresAt']?.toDate() ?? DateTime.now();
      if (expirationDate.isBefore(DateTime.now())) {
        setState(() {
          errorMessage = "Cette invitation a expiré";
          isLoading = false;
        });
        return;
      }

      // Vérifier le type d'invitation et rediriger
      if (invitationType == 'mamMember') {
        // Invitation pour un membre MAM
        final String structureName = await _getStructureName(structureId);

        context.go('/invitation-validated', extra: {
          'invitationType': invitationType,
          'email': email,
          'structureId': structureId,
          'structureName': structureName,
        });
      } else if (invitationType == 'parent') {
        // Invitation pour un parent
        final String structureName = await _getStructureName(structureId);
        final String childName = invitationData['childName'] ?? 'votre enfant';
        final String childId = invitationData['childId'] ?? '';

        context.go('/invitation-validated', extra: {
          'invitationType': invitationType,
          'email': email,
          'structureId': structureId,
          'structureName': structureName,
          'childName': childName,
          'childId': childId,
        });
      } else {
        setState(() {
          errorMessage = "Type d'invitation inconnu";
          isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur lors de la validation de l'email: $e");
      setState(() {
        errorMessage = "Une erreur est survenue lors de la validation";
        isLoading = false;
      });
    }
  }

  Future<String> _getStructureName(String structureId) async {
    try {
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureDoc.exists) {
        final data = structureDoc.data();
        return data?['structureName'] ?? 'la structure';
      }

      return 'la structure';
    } catch (e) {
      return 'la structure';
    }
  }
}
