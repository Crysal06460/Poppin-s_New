import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:poppins_app/screens/mam_member_removal_screen.dart';

class MAMMemberAddScreen extends StatefulWidget {
  const MAMMemberAddScreen({Key? key}) : super(key: key);

  @override
  _MAMMemberAddScreenState createState() => _MAMMemberAddScreenState();
}

class _MAMMemberAddScreenState extends State<MAMMemberAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  int _maxMemberCount = 3; // Valeur par défaut
  int _currentMemberCount = 0;

  // Définition des couleurs de la palette
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color primaryRed = Color(0xFFD94350); // #D94350

  @override
  void initState() {
    super.initState();
    _loadMemberInfo();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        throw Exception("Impossible de déterminer la structure");
      }

      // Récupérer le nombre maximum de membres autorisés
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureDoc.exists) {
        final data = structureDoc.data() ?? {};

        // Vérifier d'abord maxMemberCount qui est directement dans la structure
        if (data.containsKey('maxMemberCount')) {
          _maxMemberCount = data['maxMemberCount'] ?? 3;
        }
        // Sinon chercher dans le champ subscription
        else if (data.containsKey('subscription') &&
            data['subscription'] != null) {
          _maxMemberCount = data['subscription']['maxMembers'] ?? 3;
        }

        // Compter les membres actuels
        final membersSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('members')
            .get();

        _currentMemberCount = membersSnapshot.docs.length;

        print(
            "Info MAM: maxMemberCount=$_maxMemberCount, currentMemberCount=$_currentMemberCount");
      }
    } catch (e) {
      print("Erreur lors du chargement des informations MAM: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    // Vérifier d'abord si l'utilisateur est un membre MAM
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email?.toLowerCase() ?? '')
        .get();

    // Si l'utilisateur est membre d'une MAM, récupérer l'ID de la structure
    if (userDoc.exists &&
        userDoc.data() != null &&
        userDoc.data()!.containsKey('structureId')) {
      return userDoc.data()!['structureId'];
    }

    // Par défaut, utiliser l'ID de l'utilisateur (cas d'un propriétaire de structure)
    return user.uid;
  }

  Future<void> _addMAMMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Vérifier si le nombre maximum de membres est atteint
    if (_currentMemberCount >= _maxMemberCount) {
      setState(() {
        _errorMessage =
            "Vous avez atteint le nombre maximum de membres ($_maxMemberCount) autorisé par votre abonnement.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // Récupérer l'ID de la structure
      final structureId = await _getStructureId();
      if (structureId.isEmpty) {
        throw Exception("Impossible de déterminer la structure");
      }

      // Vérifier si l'utilisateur existe déjà
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(email).get();

      if (userDoc.exists) {
        setState(() {
          _errorMessage = "Cet utilisateur existe déjà.";
          _isLoading = false;
        });
        return;
      }

      // Récupérer les informations de la structure
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();
      if (!structureDoc.exists) {
        throw Exception("Structure introuvable");
      }

      final structureData = structureDoc.data() ?? {};
      final structureName = structureData['structureName'] ?? "MAM";

      // Récupérer les informations du fondateur
      final user = FirebaseAuth.instance.currentUser;
      final founderEmail = user?.email ?? "";
      final founderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(founderEmail.toLowerCase())
          .get();

      String founderFirstName = "";
      String founderLastName = "";

      if (founderDoc.exists) {
        final founderData = founderDoc.data() ?? {};
        founderFirstName = founderData['firstName'] ?? "";
        founderLastName = founderData['lastName'] ?? "";
      }

      // Créer le document utilisateur
      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'structureId': structureId,
        'isMAMMember': true,
        'userType': 'mam_member',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Ajouter le membre à la collection de membres de la structure
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .add({
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Envoi de l'invitation par email (comme dans add-mam-members.dart)
      await _sendInvitationEmail(email, firstName, lastName, structureName,
          founderFirstName, founderLastName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Membre ajouté avec succès!"),
          backgroundColor: Colors.green,
        ),
      );

      // Afficher la boîte de dialogue de confirmation
      _showConfirmationDialog(email, structureName);
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors de l'ajout du membre: ${e.toString()}";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Envoyer un email d'invitation comme dans add-mam-members.dart
  Future<void> _sendInvitationEmail(
      String email,
      String firstName,
      String lastName,
      String structureName,
      String founderFirstName,
      String founderLastName) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      final String structureId = await _getStructureId();

      // Définir la date d'expiration (30 jours à partir de maintenant)
      final DateTime expirationDate = DateTime.now().add(Duration(days: 30));

      // Créer l'invitation dans Firestore
      await FirebaseFirestore.instance.collection('invitations').add({
        'email': email.toLowerCase(),
        'type': 'mamMember',
        'structureId': structureId,
        'structureName': structureName,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expirationDate),
        'status': 'active',
      });

      print("✅ Invitation pour membre MAM enregistrée dans Firestore");

      // Construire les données du template pour l'email
      final templateData = {
        'firstName': firstName,
        'lastName': lastName,
        'structureName': structureName,
        'structureId': structureId,
        'inviterName': '$founderFirstName $founderLastName',
        'androidLink':
            'https://play.google.com/store/apps/details?id=com.example.poppins_app',
        'iosLink': 'https://apps.apple.com/app/id123456789',
        'download_link': 'https://poppins-app.com/download',
        'year': DateTime.now().year.toString(),
        'to': email.toLowerCase(),
      };

      // Ajouter l'email à la file d'attente d'envoi
      await FirebaseFirestore.instance.collection('emailQueue').add({
        'to': email.toLowerCase(),
        'template': 'mam-member-invitation',
        'subject':
            'Invitation à rejoindre la MAM "${structureName}" sur Poppins',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'high',
        'retryCount': 0,
        'templateData': templateData
      });

      print("✅ Invitation envoyée au membre MAM: $email");
    } catch (e) {
      print("❌ Erreur lors de l'envoi de l'invitation au membre MAM: $e");
      // Continue même si l'email échoue
    }
  }

  void _showConfirmationDialog(String email, String structureName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Membre ajouté",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                "Un email d'invitation a été envoyé à:",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                "Le nouveau membre pourra rejoindre la MAM \"$structureName\" en s'inscrivant sur l'application avec cette adresse email.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Retourner à l'écran précédent
              },
              child: Text(
                "TERMINER",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestion des membres"),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: _isLoading && _currentMemberCount == 0
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  // Interface différente quand la limite est atteinte
                  child: _currentMemberCount >= _maxMemberCount
                      ? _buildLimitReachedUI()
                      : _buildAddMemberForm(),
                ),
              ),
            ),
    );
  }

  // Nouvelle méthode pour afficher l'interface quand la limite est atteinte
  Widget _buildLimitReachedUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.people_alt,
          size: 70,
          color: primaryBlue.withOpacity(0.7),
        ),
        SizedBox(height: 24),
        Text(
          "Limite de membres atteinte",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                "Vous avez atteint le nombre maximum de membres ($_maxMemberCount) autorisé par votre abonnement.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Pour ajouter d'autres membres, veuillez retirer un membre existant ou mettre à niveau votre abonnement.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Retour au dashboard
                },
                icon: Icon(Icons.arrow_back),
                label: Text("RETOUR"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MAMMemberRemovalScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.person_remove),
                label: Text("RETIRER UN MEMBRE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.go('/subscription-upgrade');
          },
          icon: Icon(Icons.upgrade),
          label: Text("METTRE À NIVEAU L'ABONNEMENT"),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            side: BorderSide(color: primaryBlue),
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }

  // Méthode pour le formulaire d'ajout de membre (votre formulaire actuel)
  Widget _buildAddMemberForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre de la page
          Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "Informations du nouveau membre",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Informations sur l'abonnement
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: lightBlue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lightBlue),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.people,
                  color: primaryBlue,
                  size: 28,
                ),
                SizedBox(height: 8),
                Text(
                  "Membres: $_currentMemberCount/$_maxMemberCount",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Informations
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: lightBlue.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lightBlue),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: primaryBlue,
                  size: 28,
                ),
                SizedBox(height: 12),
                Text(
                  "Le membre recevra une invitation par email pour rejoindre votre MAM. "
                  "Il devra s'inscrire avec l'adresse email que vous indiquez ci-dessous.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Champ Email
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: "Adresse email",
              hintText: "email@exemple.com",
              prefixIcon: Icon(Icons.email, color: primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryBlue, width: 2),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Veuillez entrer une adresse email";
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return "Veuillez entrer une adresse email valide";
              }
              return null;
            },
          ),
          SizedBox(height: 16),

          // Champ Prénom
          TextFormField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: "Prénom",
              prefixIcon: Icon(Icons.person, color: primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryBlue, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Veuillez entrer un prénom";
              }
              return null;
            },
          ),
          SizedBox(height: 16),

          // Champ Nom
          TextFormField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: "Nom",
              prefixIcon: Icon(Icons.person_outline, color: primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryBlue, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Veuillez entrer un nom";
              }
              return null;
            },
          ),
          SizedBox(height: 24),

          // Message d'erreur
          if (_errorMessage.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),

          // Bouton d'ajout
          ElevatedButton(
            onPressed: _isLoading ? null : _addMAMMember,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? CircularProgressIndicator(color: Colors.white)
                : Text(
                    "AJOUTER LE MEMBRE",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
