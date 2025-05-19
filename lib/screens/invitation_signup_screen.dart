import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class InvitationSignupScreen extends StatefulWidget {
  final Map<String, dynamic> invitationInfo;

  const InvitationSignupScreen({
    Key? key,
    required this.invitationInfo,
  }) : super(key: key);

  @override
  _InvitationSignupScreenState createState() => _InvitationSignupScreenState();
}

class _InvitationSignupScreenState extends State<InvitationSignupScreen> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool isLoading = false;
  String errorMessage = '';
  bool _showPassword = false;

  // Données d'invitation
  late String email;
  late String invitationType;
  late String structureId;
  late String structureName;
  String? childName;
  String? childId;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  @override
  void initState() {
    super.initState();
    _extractInvitationData();
  }

  void _extractInvitationData() {
    email = widget.invitationInfo['email'] ?? '';
    invitationType = widget.invitationInfo['invitationType'] ?? 'unknown';
    structureId = widget.invitationInfo['structureId'] ?? '';
    structureName = widget.invitationInfo['structureName'] ?? 'la structure';

    if (invitationType == 'parent') {
      childName = widget.invitationInfo['childName'];
      childId = widget.invitationInfo['childId'];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Déterminer la couleur d'accent selon le type d'invitation
    Color accentColor = primaryBlue;
    if (invitationType == 'mamMember') {
      accentColor = brightCyan;
    } else if (invitationType == 'parent') {
      accentColor = primaryYellow;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Finaliser l'inscription",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryBlue),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icône et titre
              Icon(
                invitationType == 'mamMember'
                    ? Icons.business
                    : Icons.family_restroom,
                size: 60,
                color: accentColor,
              ),

              const SizedBox(height: 20),

              Text(
                invitationType == 'mamMember'
                    ? "Rejoindre en tant que membre"
                    : "Rejoindre en tant que parent",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                invitationType == 'mamMember'
                    ? "Vous allez rejoindre $structureName"
                    : "Vous allez rejoindre $structureName pour $childName",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

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
                            "Création de votre compte",
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
                      "Pour finaliser votre inscription, veuillez créer un mot de passe sécurisé pour votre compte.",
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Affichage de l'email (non modifiable)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: accentColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Champ pour le mot de passe
              TextField(
                controller: passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: "Mot de passe",
                  hintText: "Créez un mot de passe",
                  helperText: "Minimum 6 caractères",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: accentColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: accentColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Confirmation du mot de passe
              TextField(
                controller: confirmPasswordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: "Confirmer le mot de passe",
                  hintText: "Confirmez votre mot de passe",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: accentColor),
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
                            style: TextStyle(
                              color: primaryRed,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // Bouton de création de compte
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                          "CRÉER MON COMPTE",
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
      ),
    );
  }

  Future<void> _createAccount() async {
    // Validation de base
    if (passwordController.text.isEmpty ||
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
      // Vérifier si un compte avec cet email existe déjà
      try {
        final methods =
            await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          // Un compte avec cet email existe déjà, on tente une connexion
          setState(() {
            errorMessage =
                "Un compte existe déjà avec cet email. Vous pouvez vous connecter depuis l'écran de connexion.";
            isLoading = false;
          });
          return;
        }
      } catch (e) {
        // Ignorer l'erreur et continuer avec la création du compte
        print("Erreur lors de la vérification de l'email: $e");
      }

      // Créer l'utilisateur dans Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text.trim(),
      );

      if (invitationType == 'mamMember') {
        // Créer le document utilisateur pour un membre MAM
        await FirebaseFirestore.instance
            .collection('users')
            .doc(email.toLowerCase())
            .set({
          'email': email.toLowerCase(),
          'role': 'mamMember',
          'structureId': structureId,
          'structureName': structureName,
          'isFirstLogin': false,
          'createdAt': FieldValue.serverTimestamp(),
          'firebaseUid': userCredential.user?.uid,
        });

        // Redirection vers l'interface MAM
        if (mounted) context.go('/home');
      } else if (invitationType == 'parent') {
        // Ajouter un log pour déboguer
        print("⭐ Création du compte parent avec childId: $childId");

        // Créer le document utilisateur pour un parent
        await FirebaseFirestore.instance
            .collection('users')
            .doc(email.toLowerCase())
            .set({
          'email': email.toLowerCase(),
          'role': 'parent',
          'childId': childId,
          'childName': childName,
          'structureId': structureId,
          'structureName': structureName,
          'isFirstLogin': false,
          'createdAt': FieldValue.serverTimestamp(),
          'firebaseUid': userCredential.user?.uid,
          // S'assurer que l'enfant est dans la liste des enfants
          'children': [childId],
        });

        print("✅ Compte parent créé avec succès");
        print("📱 Tentative de redirection vers /parent/home");

        // Ajouter un délai pour s'assurer que Firestore a bien été mis à jour
        await Future.delayed(Duration(milliseconds: 500));

        // Redirection vers l'interface parent
        if (mounted) {
          try {
            context.go('/parent/home');
            print("✅ Redirection vers /parent/home réussie");
          } catch (e) {
            print("❌ Erreur lors de la redirection: $e");
          }
        }
      }

      // Mettre à jour l'invitation après utilisation
      try {
        final invitationsQuery = await FirebaseFirestore.instance
            .collection('invitations')
            .where('email', isEqualTo: email)
            .where('structureId', isEqualTo: structureId)
            .get();

        if (invitationsQuery.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('invitations')
              .doc(invitationsQuery.docs.first.id)
              .update({'status': 'completed'});

          print("✅ Invitation marquée comme complétée");
        }
      } catch (e) {
        print("Erreur lors de la mise à jour de l'invitation: $e");
        // Ne pas bloquer le processus si la mise à jour échoue
      }
    } catch (e) {
      print("Erreur lors de la création du compte: $e");
      setState(() {
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'email-already-in-use':
              errorMessage = "Cette adresse e-mail est déjà utilisée";
              break;
            case 'invalid-email':
              errorMessage = "Format d'e-mail invalide";
              break;
            case 'weak-password':
              errorMessage = "Le mot de passe est trop faible";
              break;
            default:
              errorMessage = "Erreur: ${e.message}";
          }
        } else {
          errorMessage =
              "Une erreur est survenue lors de la création du compte";
        }
        isLoading = false;
      });
    }
  }
}
