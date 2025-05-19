import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Déplacer l'énumération à l'extérieur de la classe, au niveau du fichier
enum AuthFlowState {
  emailEntry,     // Entrée de l'email seulement
  existingUser,   // Utilisateur existant (demande mot de passe)
  newMamMember,   // Nouveau membre MAM (création mot de passe)
  newParent,      // Nouveau parent (création mot de passe)
  registration    // Inscription complète (création structure)
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = "";
  bool isLoading = false;
  bool rememberEmail = false;
  
  // Utiliser l'énumération définie à l'extérieur
  AuthFlowState currentState = AuthFlowState.emailEntry;
  
  // Stocker les informations contextuelles
  String? structureName;
  String? childName;
  String? userRole;
  String? structureType;
  String? structureId;
  
  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  // Charger l'email enregistré au démarrage
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final savedEmail = prefs.getString('savedEmail') ?? '';
      final savedRememberEmail = prefs.getBool('rememberEmail') ?? false;
      
      if (savedRememberEmail) {
        emailController.text = savedEmail;
        rememberEmail = true;
      }
    });
  }

  // Sauvegarder l'email si la case est cochée
  Future<void> _saveEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberEmail) {
      await prefs.setString('savedEmail', emailController.text.trim());
      await prefs.setBool('rememberEmail', true);
    } else {
      // Supprimer l'email sauvegardé si la case n'est pas cochée
      await prefs.remove('savedEmail');
      await prefs.remove('rememberEmail');
    }
  }

  // Méthode: Vérifier l'état de l'email
  Future<void> _checkEmailStatus() async {
  final email = emailController.text.trim().toLowerCase();
  
  if (email.isEmpty) {
    setState(() {
      errorMessage = "Veuillez entrer votre adresse e-mail";
    });
    return;
  }
  
  setState(() {
    isLoading = true;
    errorMessage = "";
  });
  
  try {
    // 1. Vérifier si l'email existe déjà dans Firebase Auth
    final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
    print("Email vérifié: $email - Méthodes de connexion trouvées: ${methods.length}");
    
    if (methods.isNotEmpty) {
      // Email déjà associé à un compte -> demander mot de passe
      setState(() {
        currentState = AuthFlowState.existingUser;
        isLoading = false;
      });
      return;
    }
    
    // 2. Vérifier si l'email correspond à une structure
    final structuresWithEmail = await FirebaseFirestore.instance
        .collection('structures')
        .where('email', isEqualTo: email)
        .get();
    
    if (structuresWithEmail.docs.isNotEmpty) {
      print("Email trouvé dans structures: ${structuresWithEmail.docs.first.id}");
      // Email trouvé dans Firestore mais pas dans Auth -> problème de synchronisation
      setState(() {
        currentState = AuthFlowState.existingUser;
        isLoading = false;
      });
      return;
    }
    
    // 3. Vérifier si l'email est dans la collection users (pour les first login)
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .get();

    if (userDoc.exists) {
      print("Email trouvé dans users: $email");
      final userData = userDoc.data()!;
      
      // Vérifier si c'est un utilisateur qui doit faire sa première connexion
      if (userData['isFirstLogin'] == true) {
        final userRole = userData['role'] as String?;
        
        if (userRole == 'parent') {
          // C'est un parent qui se connecte pour la première fois
          setState(() {
            currentState = AuthFlowState.newParent;
            structureName = userData['structureName'] ?? "la structure";
            childName = userData['childName'] ?? "votre enfant";
            structureId = userData['structureId'];
            this.userRole = 'parent';
            isLoading = false;
          });
          return;
        } else if (userRole == 'mamMember') {
          // C'est un membre de MAM qui se connecte pour la première fois
          setState(() {
            currentState = AuthFlowState.newMamMember;
            structureName = userData['structureName'] ?? "la MAM";
            structureId = userData['structureId'];
            this.userRole = 'mamMember';
            isLoading = false;
          });
          return;
        }
      } else {
        // C'est un utilisateur existant normal (mais sans Auth)
        setState(() {
          currentState = AuthFlowState.existingUser;
          isLoading = false;
        });
        return;
      }
    }
    
    // 4. Vérifier si c'est un membre MAM invité mais pas encore dans users
    final mamMemberInfo = await _checkIfMamMember(email);
    if (mamMemberInfo.isNotEmpty) {
      print("Email trouvé comme membre MAM invité: $email");
      setState(() {
        currentState = AuthFlowState.newMamMember;
        structureName = mamMemberInfo['structureName'] ?? "la MAM";
        structureId = mamMemberInfo['structureId'];
        userRole = 'mamMember';
        isLoading = false;
      });
      return;
    }
    
    // 5. Vérifier si c'est un parent invité mais pas encore dans users
    final parentInfo = await _checkIfParent(email);
    if (parentInfo.isNotEmpty) {
      print("Email trouvé comme parent invité: $email");
      setState(() {
        currentState = AuthFlowState.newParent;
        structureName = parentInfo['structureName'] ?? "la structure";
        childName = parentInfo['childName'] ?? "votre enfant";
        structureId = parentInfo['structureId'];
        userRole = 'parent';
        isLoading = false;
      });
      return;
    }
    
    // Si aucun des cas précédents -> email non reconnu
    setState(() {
      isLoading = false;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Email non reconnu",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              "Cette adresse e-mail n'est associée à aucun compte existant ou invitation.",
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              "Veuillez retourner à l'écran d'accueil pour créer un compte ou redemander une invitation auprès de la structure.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  currentState = AuthFlowState.emailEntry;
                  emailController.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B8FE5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text("RETOUR À L'ACCUEIL"),
            ),
          ),
        ],
      ),
    );
    
  } catch (e) {
    setState(() {
      errorMessage = "Une erreur est survenue lors de la vérification de l'e-mail";
      isLoading = false;
    });
    print("Erreur lors de la vérification de l'email: $e");
  }
}
  
  // Méthode pour vérifier si l'email appartient à un membre MAM
  Future<Map<String, String>> _checkIfMamMember(String email) async {
    try {
      // Parcourir toutes les structures
      final structuresQuery = await FirebaseFirestore.instance
          .collection('structures')
          .where('structureType', isEqualTo: 'MAM')
          .get();
      
      for (var structureDoc in structuresQuery.docs) {
        final membersQuery = await structureDoc.reference
            .collection('members')
            .where('email', isEqualTo: email)
            .get();
        
        if (membersQuery.docs.isNotEmpty) {
          // Récupérer le nom de la structure
          final structureName = structureDoc.data()['structureName'] ?? 'MAM';
          
          return {
            'memberId': membersQuery.docs.first.id,
            'structureId': structureDoc.id,
            'structureName': structureName
          };
        }
      }
      
      return {};
    } catch (e) {
      print("Erreur lors de la recherche de membre MAM: $e");
      return {};
    }
  }
  
  // Méthode pour vérifier si l'email appartient à un parent
  Future<Map<String, String>> _checkIfParent(String email) async {
  try {
    print("Vérification si $email est un parent...");
    final structuresQuery = await FirebaseFirestore.instance
        .collection('structures')
        .get();
    
    for (var structureDoc in structuresQuery.docs) {
      final childrenQuery = await structureDoc.reference
          .collection('children')
          .get();
      
      print("Vérification dans ${structureDoc.id} avec ${childrenQuery.docs.length} enfants");
      
      for (var childDoc in childrenQuery.docs) {
        final childData = childDoc.data();
        
        // Ajouter des logs détaillés
        if (childData['parent1'] != null) {
          print("Parent1 email: ${childData['parent1']['email']}");
        }
        if (childData['parent2'] != null) {
          print("Parent2 email: ${childData['parent2']['email']}");
        }
        
        // Vérifier parent1
        if (childData['parent1'] != null && 
            childData['parent1']['email'] != null && 
            childData['parent1']['email'].toString().toLowerCase() == email.toLowerCase()) {
          
          print("Match trouvé pour parent1 de ${childData['firstName']}");
          return {
            'childId': childDoc.id,
            'structureId': structureDoc.id,
            'structureName': structureDoc.data()?['structureName'] ?? 'Structure',
            'childName': childData['firstName'] ?? 'Enfant'
          };
        }
        
        // Vérifier parent2
        if (childData['parent2'] != null && 
            childData['parent2']['email'] != null && 
            childData['parent2']['email'].toString().toLowerCase() == email.toLowerCase()) {
          
          print("Match trouvé pour parent2 de ${childData['firstName']}");
          return {
            'childId': childDoc.id,
            'structureId': structureDoc.id,
            'structureName': structureDoc.data()?['structureName'] ?? 'Structure',
            'childName': childData['firstName'] ?? 'Enfant'
          };
        }
      }
    }
    
    print("Aucun parent trouvé pour cet email");
    return {};
  } catch (e) {
    print("Erreur lors de la recherche de parent: $e");
    return {};
  }
}

  // Création de compte pour nouveau membre MAM
  Future<void> _createMamMemberAccount() async {
    if (passwordController.text.trim().length < 6) {
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
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text.trim();
      
      // Créer l'utilisateur dans Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Récupérer les informations du membre depuis la collection members
      final membersQuery = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .where('email', isEqualTo: email)
          .get();
      
      if (membersQuery.docs.isEmpty) {
        throw Exception("Membre non trouvé");
      }
      
      final memberData = membersQuery.docs.first.data();
      
      // Créer/mettre à jour le document utilisateur
      await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .set({
            'email': email,
            'firstName': memberData['firstName'] ?? '',
            'lastName': memberData['lastName'] ?? '',
            'role': 'mamMember',
            'structureId': structureId,
            'isFirstLogin': false,
            'firebaseUid': userCredential.user?.uid
          });
      
      // Redirection vers la page d'accueil MAM
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'email-already-in-use':
              errorMessage = "Cette adresse e-mail est déjà utilisée";
              break;
            case 'weak-password':
              errorMessage = "Le mot de passe est trop faible (minimum 6 caractères)";
              break;
            default:
              errorMessage = "Erreur lors de la création du compte: ${e.message}";
          }
        } else {
          errorMessage = "Une erreur est survenue lors de la création du compte";
        }
        isLoading = false;
      });
    }
  }
  
  // Création de compte pour nouveau parent
  Future<void> _createParentAccount() async {
    if (passwordController.text.trim().length < 6) {
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
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text.trim();
      
      // Créer l'utilisateur dans Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Trouver l'enfant associé au parent
      final structuresSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .get();

      String? childId;
      Map<String, dynamic>? parentData;
      
      // Parcourir les structures pour trouver l'enfant
      for (var structureDoc in structuresSnapshot.docs) {
        if (structureDoc.id != structureId) continue;
        
        final childrenSnapshot = await structureDoc.reference
            .collection('children')
            .get();
        
        for (var childDoc in childrenSnapshot.docs) {
          final childData = childDoc.data();
          
          // Vérifier parent1
          if (childData['parent1'] != null && 
              childData['parent1']['email'] != null && 
              childData['parent1']['email'].toString().toLowerCase() == email) {
            
            childId = childDoc.id;
            parentData = childData['parent1'];
            break;
          }
          
          // Vérifier parent2
          if (childData['parent2'] != null && 
              childData['parent2']['email'] != null && 
              childData['parent2']['email'].toString().toLowerCase() == email) {
            
            childId = childDoc.id;
            parentData = childData['parent2'];
            break;
          }
        }
        
        if (childId != null) break;
      }
      
      // Vérifier que les données du parent sont trouvées
      if (childId == null || parentData == null) {
        throw Exception("Enfant non trouvé pour ce parent");
      }
      
      // Créer un document utilisateur pour le parent
      await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .set({
            'email': email,
            'firstName': parentData['firstName'] ?? '',
            'lastName': parentData['lastName'] ?? '',
            'role': 'parent',
            'children': [childId],
            'structureId': structureId,
            'isFirstLogin': false,
            'firebaseUid': userCredential.user?.uid
          });
      
      // Redirection vers l'interface parent
      if (mounted) context.go('/parent/home');
    } catch (e) {
      setState(() {
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'email-already-in-use':
              errorMessage = "Cette adresse e-mail est déjà utilisée";
              break;
            case 'weak-password':
              errorMessage = "Le mot de passe est trop faible (minimum 6 caractères)";
              break;
            default:
              errorMessage = "Erreur lors de la création du compte: ${e.message}";
          }
        } else {
          errorMessage = "Une erreur est survenue lors de la création du compte";
        }
        isLoading = false;
      });
    }
  }

  // Connexion utilisateur existant
  Future<void> _login() async {
    await _saveEmail();

    if (passwordController.text.trim().isEmpty) {
      setState(() {
        errorMessage = "Veuillez entrer votre mot de passe";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = "";
    });
  
    try {
      // Connecter l'utilisateur avec Firebase Auth
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim().toLowerCase(),
        password: passwordController.text.trim(),
      );
      
      final userEmail = userCredential.user!.email?.toLowerCase() ?? '';

      // Vérifier d'abord si l'email correspond à une structure (MAM ou AssistanteMaternelle)
      final structuresQuery = await FirebaseFirestore.instance
          .collection('structures')
          .where('email', isEqualTo: userEmail)
          .get();

      if (structuresQuery.docs.isNotEmpty) {
        // C'est une structure (MAM ou AssistanteMaternelle)
        final structureData = structuresQuery.docs.first.data();
        final structureType = structureData['structureType'] as String?;
        
        // Vérifier que c'est bien un type de structure valide (MAM ou AssistanteMaternelle)
        if (structureType == 'MAM' || structureType == 'AssistanteMaternelle') {
          // Rediriger vers l'espace structure
          if (mounted) context.go('/home');
          return;
        }
      }

      // Vérifier si l'utilisateur est un membre d'une MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();
          
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final role = userData['role'] as String?;
        
        if (role == 'mamMember') {
          // Rediriger vers l'espace MAM
          if (mounted) context.go('/home');
          return;
        } else if (role == 'parent') {
          // Rediriger vers l'espace parent
          if (mounted) context.go('/parent/home');
          return;
        }
      }
      
      // Si l'utilisateur n'a pas de rôle défini, afficher une erreur
      setState(() {
        errorMessage = "Compte utilisateur non configuré correctement";
        isLoading = false;
      });

    } catch (e) {
      setState(() {
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'invalid-email':
              errorMessage = "L'adresse e-mail est mal formatée.";
              break;
            case 'user-disabled':
              errorMessage = "Ce compte a été désactivé.";
              break;
            case 'user-not-found':
            case 'wrong-password':
              errorMessage = "Email ou mot de passe incorrect.";
              break;
            default:
              errorMessage = "Erreur de connexion.";
          }
        } else {
          errorMessage = "Email ou mot de passe incorrect.";
        }
        isLoading = false;
      });
    }
  }

  // Réinitialisation du mot de passe
  Future<void> _resetPassword() async {
    if (emailController.text.trim().isEmpty) {
      setState(() {
        errorMessage = "Veuillez entrer votre email.";
      });
      return;
    }
    
    setState(() {
      isLoading = true;
      errorMessage = "";
    });
    
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Un email de réinitialisation a été envoyé.")),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = "Impossible de réinitialiser le mot de passe.";
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  // Naviguer vers l'écran d'inscription complète
  void _navigateToRegistration() {
    setState(() {
      currentState = AuthFlowState.registration;
    });
  }
  void _showRegistrationDialog() {
  final TextEditingController emailRegController = TextEditingController(text: emailController.text);
  final TextEditingController passwordRegController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Inscription", 
            style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailRegController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordRegController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Mot de passe",
                    helperText: "Minimum 6 caractères",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Confirmer le mot de passe",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("ANNULER", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validation de base
                if (emailRegController.text.isEmpty || 
                    passwordRegController.text.isEmpty ||
                    confirmPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Veuillez remplir tous les champs"))
                  );
                  return;
                }
                
                if (passwordRegController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Les mots de passe ne correspondent pas"))
                  );
                  return;
                }
                
                if (passwordRegController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Le mot de passe doit contenir au moins 6 caractères"))
                  );
                  return;
                }
                
                try {
                  // Créer l'utilisateur
                  await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: emailRegController.text.trim(),
                    password: passwordRegController.text.trim(),
                  );
                  
                  // Fermer le dialogue
                  Navigator.of(context).pop();
                  
                  // Redirection vers l'écran de création de structure
                  context.go('/create-structure');
                } catch (e) {
                  String errorMessage = "Une erreur est survenue";
                  
                  if (e is FirebaseAuthException) {
                    switch (e.code) {
                      case 'email-already-in-use':
                        errorMessage = "Cette adresse e-mail est déjà utilisée";
                        break;
                      case 'invalid-email':
                        errorMessage = "Format d'e-mail invalide";
                        break;
                      case 'weak-password':
                        errorMessage = "Le mot de passe est trop faible (minimum 6 caractères)";
                        break;
                    }
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(errorMessage))
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B8FE5),
                foregroundColor: Colors.white,
              ),
              child: const Text("S'INSCRIRE"),
            ),
          ],
        );
      },
    ),
  );
}
  // Retour à l'écran d'email
  void _backToEmailScreen() {
    setState(() {
      currentState = AuthFlowState.emailEntry;
      passwordController.clear();
      errorMessage = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                
                // Titre
                Text(
                  _getScreenTitle(),
                  style: const TextStyle(
                    fontSize: 26, 
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Sous-titre contextuel
                if (_getSubtitle().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _getSubtitle(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                const SizedBox(height: 30),

                // Logo parapluie
                Image.asset(
                  "assets/images/umbrella.png",
                  height: 100,
                  width: 100,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 40),

                // Contenu spécifique selon l'état actuel
                _buildCurrentStateContent(),
                
                // En mode email entry seulement: afficher "OU" et le bouton d'inscription
                if (currentState == AuthFlowState.emailEntry) ...[
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "ou", 
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey)),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Bouton Créer un compte
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _navigateToRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF8B8FE5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF8B8FE5)),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "CRÉER UN COMPTE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Affichage des erreurs
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 30), // Espace en bas pour le scroll
              ],
            ),
          ),
        ),),
    );
  }
  
  // Obtenir le titre de l'écran selon l'état actuel
  String _getScreenTitle() {
    switch (currentState) {
      case AuthFlowState.emailEntry:
        return "Bienvenue sur Poppins";
      case AuthFlowState.existingUser:
        return "Connexion";
      case AuthFlowState.newMamMember:
        return "Première connexion";
      case AuthFlowState.newParent:
        return "Première connexion";
      case AuthFlowState.registration:
        return "Création de compte";
    }
  }
  
  // Obtenir le sous-titre selon l'état actuel
  String _getSubtitle() {
    switch (currentState) {
      case AuthFlowState.newMamMember:
        return "Vous avez été invité(e) en tant que membre de la MAM $structureName";
      case AuthFlowState.newParent:
        return "Vous avez été invité(e) en tant que parent de $childName";
      default:
        return "";
    }
  }
  
  // Construire le contenu selon l'état actuel
  Widget _buildCurrentStateContent() {
    switch (currentState) {
      case AuthFlowState.emailEntry:
        return _buildEmailEntryContent();
      case AuthFlowState.existingUser:
        return _buildExistingUserContent();
      case AuthFlowState.newMamMember:
        return _buildNewMamMemberContent();
      case AuthFlowState.newParent:
        return _buildNewParentContent();
      case AuthFlowState.registration:
        return _buildRegistrationContent();
    }
  }
  
  // Contenu pour l'entrée d'email
  Widget _buildEmailEntryContent() {
    return Column(
      children: [
        // Champ email
        _buildTextField(emailController, "Email", false),
        
        // Case à cocher "Se souvenir de l'email"
        Row(
          children: [
            Checkbox(
              value: rememberEmail,
              onChanged: (bool? value) {
                setState(() {
                  rememberEmail = value ?? false;
                });
              },
              activeColor: const Color(0xFF8B8FE5),
            ),
            const Text(
              "Se souvenir de mon email",
              style: TextStyle(color: Color(0xFF1A237E)),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Bouton Continuer
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _checkEmailStatus,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B8FE5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                    "CONTINUER",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
  
  // Contenu pour l'utilisateur existant
  Widget _buildExistingUserContent() {
    return Column(
      children: [
        // Email (non modifiable)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, color: Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  emailController.text,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                onPressed: _backToEmailScreen,
                tooltip: "Changer d'email",
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Champ mot de passe
        _buildTextField(passwordController, "Mot de passe", true),
        
        // Lien "Mot de passe oublié"
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton(
              onPressed: isLoading ? null : _resetPassword,
              child: const Text(
                "Mot de passe oublié ?",
                style: TextStyle(color: Color(0xFF8B8FE5)),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Bouton Se connecter
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B8FE5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                    "SE CONNECTER",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
  
  // Contenu pour nouveau membre MAM
  Widget _buildNewMamMemberContent() {
    return Column(
      children: [
        // Email (non modifiable)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, color: Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  emailController.text,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                onPressed: _backToEmailScreen,
                tooltip: "Changer d'email",
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Champ mot de passe
        _buildTextField(passwordController, "Créer un mot de passe", true),
        
        const SizedBox(height: 8),
        
        // Message d'aide
        const Text(
          "Le mot de passe doit contenir au moins 6 caractères",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Bouton Créer mon compte
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _createMamMemberAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A085),  // Couleur MAM
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
  
  // Contenu pour nouveau parent
  Widget _buildNewParentContent() {
    return Column(
      children: [
        // Email (non modifiable)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, color: Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  emailController.text,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                onPressed: _backToEmailScreen,
                tooltip: "Changer d'email",
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Champ mot de passe
        _buildTextField(passwordController, "Créer un mot de passe", true),
        
        const SizedBox(height: 8),
        
        // Message d'aide
        const Text(
          "Le mot de passe doit contenir au moins 6 caractères",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Bouton Créer mon compte
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _createParentAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,  // Couleur parent
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
  
  // Contenu pour l'inscription complète (création structure)
  Widget _buildRegistrationContent() {
    return Column(
      children: [
        // Message d'information
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Création d'une nouvelle structure",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Cette option est réservée à la création d'une nouvelle structure (Assistante Maternelle ou MAM).",
                style: TextStyle(color: Colors.blue),
              ),
              const SizedBox(height: 8),
              const Text(
                "Si vous êtes parent ou membre d'une MAM, vous devriez avoir reçu une invitation par email.",
                style: TextStyle(color: Colors.blue),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Bouton Continuer vers l'inscription
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : () {
              // Naviguer vers un nouvel écran d'inscription au lieu d'afficher un popup
              context.push('/register');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B8FE5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              "CONTINUER VERS L'INSCRIPTION",
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Bouton Retour
        TextButton.icon(
          onPressed: _backToEmailScreen,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text("Retour à l'écran précédent"),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}