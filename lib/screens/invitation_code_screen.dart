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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Invitation",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
      ),
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
