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

  // Remplacer la méthode build() existante par celle-ci
  @override
  Widget build(BuildContext context) {
    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête avec fond de couleur - Responsive
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryBlue,
                  primaryBlue.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(screenSize.width * 0.06),
                bottomRight: Radius.circular(screenSize.width * 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * 0.02,
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * (isTablet ? 0.02 : 0.025),
                ),
                child: Row(
                  children: [
                    // Bouton retour avec meilleur contraste
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(
                            screenSize.width * (isTablet ? 0.015 : 0.02)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: screenSize.width * (isTablet ? 0.025 : 0.06),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: screenSize.width * (isTablet ? 0.02 : 0.04)),
                    // Titre avec meilleur style
                    Expanded(
                      child: Text(
                        "Gestion des membres",
                        style: TextStyle(
                          fontSize:
                              screenSize.width * (isTablet ? 0.028 : 0.055),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal avec adaptation pour iPad
          _isLoading && _currentMemberCount == 0
              ? Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  ),
                )
              : Expanded(
                  child:
                      isTablet ? _buildTabletContent() : _buildPhoneContent(),
                ),
        ],
      ),
    );
  }

// Nouvelle méthode pour le contenu tablette
  Widget _buildTabletContent() {
    return LayoutBuilder(builder: (context, constraints) {
      final double maxWidth = constraints.maxWidth;
      final double maxHeight = constraints.maxHeight;
      final double sideMargin = maxWidth * 0.03;
      final double columnGap = maxWidth * 0.025;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          sideMargin,
          maxHeight * 0.02,
          sideMargin,
          maxHeight * 0.02,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panneau latéral gauche (Informations MAM et statut)
            Expanded(
              flex: 4,
              child: Container(
                margin: EdgeInsets.only(right: columnGap),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(maxWidth * 0.025),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre avec icône
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt,
                            color: primaryBlue,
                            size: maxWidth * 0.07,
                          ),
                          SizedBox(width: maxWidth * 0.015),
                          Expanded(
                            child: Text(
                              "Statut des membres",
                              style: TextStyle(
                                fontSize: maxWidth * 0.022,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Carte du statut des membres
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(maxWidth * 0.025),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryBlue.withOpacity(0.1),
                              lightBlue.withOpacity(0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryBlue.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.groups,
                              color: primaryBlue,
                              size: maxWidth * 0.08,
                            ),
                            SizedBox(height: maxHeight * 0.02),
                            Text(
                              "$_currentMemberCount/$_maxMemberCount",
                              style: TextStyle(
                                fontSize: maxWidth * 0.035,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                            SizedBox(height: maxHeight * 0.01),
                            Text(
                              "Membres actuels",
                              style: TextStyle(
                                fontSize: maxWidth * 0.018,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: maxHeight * 0.02),
                            // Barre de progression
                            Container(
                              width: double.infinity,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _maxMemberCount > 0
                                    ? _currentMemberCount / _maxMemberCount
                                    : 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        _currentMemberCount >= _maxMemberCount
                                            ? primaryRed
                                            : primaryBlue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: maxHeight * 0.04),

                      // Information sur l'abonnement
                      _buildTabletInfoCard(
                        icon: Icons.card_membership,
                        title: "Abonnement",
                        description: "Limite: $_maxMemberCount membres",
                        maxWidth: maxWidth,
                      ),

                      SizedBox(height: maxHeight * 0.02),

                      // Information sur l'invitation
                      _buildTabletInfoCard(
                        icon: Icons.email,
                        title: "Processus d'invitation",
                        description:
                            "Le membre recevra un email d'invitation pour rejoindre votre MAM",
                        maxWidth: maxWidth,
                      ),

                      if (_currentMemberCount >= _maxMemberCount) ...[
                        SizedBox(height: maxHeight * 0.04),
                        // Actions alternatives quand limite atteinte
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(maxWidth * 0.02),
                          decoration: BoxDecoration(
                            color: primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryRed.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning,
                                color: primaryRed,
                                size: maxWidth * 0.03,
                              ),
                              SizedBox(height: maxHeight * 0.01),
                              Text(
                                "Limite atteinte",
                                style: TextStyle(
                                  fontSize: maxWidth * 0.018,
                                  fontWeight: FontWeight.bold,
                                  color: primaryRed,
                                ),
                              ),
                              SizedBox(height: maxHeight * 0.01),
                              Text(
                                "Retirez un membre ou mettez à niveau votre abonnement",
                                style: TextStyle(
                                  fontSize: maxWidth * 0.014,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Panneau de droite (Formulaire ou limite atteinte)
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(maxWidth * 0.025),
                  child: _currentMemberCount >= _maxMemberCount
                      ? _buildTabletLimitReached(maxWidth, maxHeight)
                      : _buildTabletAddForm(maxWidth, maxHeight),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

// Méthode pour créer une carte d'information pour iPad
  Widget _buildTabletInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required double maxWidth,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(maxWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(maxWidth * 0.01),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: primaryBlue,
                  size: maxWidth * 0.02,
                ),
              ),
              SizedBox(width: maxWidth * 0.015),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: maxWidth * 0.016,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: maxWidth * 0.01),
          Text(
            description,
            style: TextStyle(
              fontSize: maxWidth * 0.014,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

// Méthode pour le formulaire d'ajout sur iPad
  Widget _buildTabletAddForm(double maxWidth, double maxHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de la section
        Text(
          "Ajouter un nouveau membre",
          style: TextStyle(
            fontSize: maxWidth * 0.022,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),

        SizedBox(height: maxHeight * 0.03),

        // Formulaire
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _buildTabletFormField(
                  controller: _emailController,
                  label: 'Adresse email',
                  icon: Icons.email,
                  maxWidth: maxWidth,
                  keyboardType: TextInputType.emailAddress,
                  hintText: 'email@exemple.com',
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

                SizedBox(height: maxHeight * 0.025),

                _buildTabletFormField(
                  controller: _firstNameController,
                  label: 'Prénom',
                  icon: Icons.person,
                  maxWidth: maxWidth,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Veuillez entrer un prénom";
                    }
                    return null;
                  },
                ),

                SizedBox(height: maxHeight * 0.025),

                _buildTabletFormField(
                  controller: _lastNameController,
                  label: 'Nom',
                  icon: Icons.person_outline,
                  maxWidth: maxWidth,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Veuillez entrer un nom";
                    }
                    return null;
                  },
                ),

                SizedBox(height: maxHeight * 0.025),

                // Message d'erreur
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(maxWidth * 0.02),
                    margin: EdgeInsets.only(bottom: maxHeight * 0.025),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error,
                            color: Colors.red, size: maxWidth * 0.02),
                        SizedBox(width: maxWidth * 0.015),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: maxWidth * 0.014,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: maxHeight * 0.04),

                // Bouton d'ajout
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _addMAMMember,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: maxWidth * 0.08,
                          vertical: maxHeight * 0.02,
                        ),
                        decoration: BoxDecoration(
                          gradient: _isLoading
                              ? null
                              : LinearGradient(
                                  colors: [
                                    primaryBlue,
                                    primaryBlue.withOpacity(0.8)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _isLoading ? Colors.grey.shade300 : null,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: _isLoading
                              ? null
                              : [
                                  BoxShadow(
                                    color: primaryBlue.withOpacity(0.3),
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
                                  ),
                                ],
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: maxWidth * 0.025,
                                height: maxWidth * 0.025,
                                child: CircularProgressIndicator(
                                  color: primaryBlue,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_add,
                                    color: Colors.white,
                                    size: maxWidth * 0.022,
                                  ),
                                  SizedBox(width: maxWidth * 0.015),
                                  Text(
                                    'AJOUTER LE MEMBRE',
                                    style: TextStyle(
                                      fontSize: maxWidth * 0.018,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

// Méthode pour l'interface limite atteinte sur iPad
  Widget _buildTabletLimitReached(double maxWidth, double maxHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de la section
        Text(
          "Limite de membres atteinte",
          style: TextStyle(
            fontSize: maxWidth * 0.022,
            fontWeight: FontWeight.bold,
            color: primaryRed,
          ),
        ),

        SizedBox(height: maxHeight * 0.04),

        // Contenu centré
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_alt_outlined,
                size: maxWidth * 0.1,
                color: primaryRed.withOpacity(0.7),
              ),
              SizedBox(height: maxHeight * 0.03),
              Container(
                padding: EdgeInsets.all(maxWidth * 0.025),
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
                        fontSize: maxWidth * 0.016,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: maxHeight * 0.02),
                    Text(
                      "Pour ajouter d'autres membres, veuillez retirer un membre existant ou mettre à niveau votre abonnement.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: maxWidth * 0.014,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: maxHeight * 0.04),
              // Boutons d'action pour iPad
              Row(
                children: [
                  Expanded(
                    child: _buildTabletActionButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MAMMemberRemovalScreen(),
                          ),
                        );
                      },
                      icon: Icons.person_remove,
                      label: "RETIRER UN MEMBRE",
                      color: primaryRed,
                      maxWidth: maxWidth,
                      maxHeight: maxHeight,
                    ),
                  ),
                  SizedBox(width: maxWidth * 0.02),
                  Expanded(
                    child: _buildTabletActionButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/subscription-upgrade');
                      },
                      icon: Icons.upgrade,
                      label: "METTRE À NIVEAU",
                      color: primaryBlue,
                      maxWidth: maxWidth,
                      maxHeight: maxHeight,
                      isOutlined: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

// Méthode pour créer un bouton d'action pour iPad
  Widget _buildTabletActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required double maxWidth,
    required double maxHeight,
    bool isOutlined = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: maxHeight * 0.015,
          ),
          decoration: BoxDecoration(
            gradient: isOutlined
                ? null
                : LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: isOutlined ? Colors.white : null,
            border: isOutlined ? Border.all(color: color, width: 2) : null,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isOutlined
                ? null
                : [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isOutlined ? color : Colors.white,
                size: maxWidth * 0.02,
              ),
              SizedBox(width: maxWidth * 0.01),
              Text(
                label,
                style: TextStyle(
                  fontSize: maxWidth * 0.014,
                  color: isOutlined ? color : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Méthode pour créer un champ de formulaire stylé pour iPad
  Widget _buildTabletFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double maxWidth,
    TextInputType? keyboardType,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          fontSize: maxWidth * 0.018,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Container(
            margin: EdgeInsets.all(maxWidth * 0.015),
            padding: EdgeInsets.all(maxWidth * 0.01),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryBlue,
              size: maxWidth * 0.022,
            ),
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: maxWidth * 0.016,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: maxWidth * 0.015,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: maxWidth * 0.04,
            vertical: maxWidth * 0.02,
          ),
        ),
      ),
    );
  }

// Méthode pour le contenu iPhone (améliorée)
  Widget _buildPhoneContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: _currentMemberCount >= _maxMemberCount
            ? _buildPhoneLimitReached()
            : _buildPhoneAddForm(),
      ),
    );
  }

// Méthode pour l'interface limite atteinte sur iPhone
  Widget _buildPhoneLimitReached() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 40),
        Icon(
          Icons.people_alt,
          size: 80,
          color: primaryBlue.withOpacity(0.7),
        ),
        SizedBox(height: 24),
        Text(
          "Limite de membres atteinte",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 24),
        Container(
          padding: EdgeInsets.all(20),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
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
        SizedBox(height: 40),
        _buildPhoneActionButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MAMMemberRemovalScreen(),
              ),
            );
          },
          icon: Icons.person_remove,
          label: "RETIRER UN MEMBRE",
          color: primaryRed,
        ),
        SizedBox(height: 16),
        _buildPhoneActionButton(
          onPressed: () {
            Navigator.pop(context);
            context.go('/subscription-upgrade');
          },
          icon: Icons.upgrade,
          label: "METTRE À NIVEAU L'ABONNEMENT",
          color: primaryBlue,
          isOutlined: true,
        ),
      ],
    );
  }

// Méthode pour le formulaire d'ajout sur iPhone
  Widget _buildPhoneAddForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre de la page
          Text(
            "Informations du nouveau membre",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),

          // Carte du statut des membres
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryBlue.withOpacity(0.1),
                  lightBlue.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.people,
                  color: primaryBlue,
                  size: 32,
                ),
                SizedBox(height: 12),
                Text(
                  "Membres: $_currentMemberCount/$_maxMemberCount",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                // Barre de progression
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _maxMemberCount > 0
                        ? _currentMemberCount / _maxMemberCount
                        : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _currentMemberCount >= _maxMemberCount
                            ? primaryRed
                            : primaryBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Informations
          Container(
            padding: EdgeInsets.all(16),
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

          SizedBox(height: 32),

          // Formulaire
          _buildPhoneFormField(
            controller: _emailController,
            label: "Adresse email",
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            hintText: "email@exemple.com",
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
          SizedBox(height: 20),

          _buildPhoneFormField(
            controller: _firstNameController,
            label: "Prénom",
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Veuillez entrer un prénom";
              }
              return null;
            },
          ),
          SizedBox(height: 20),

          _buildPhoneFormField(
            controller: _lastNameController,
            label: "Nom",
            icon: Icons.person_outline,
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
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // Bouton d'ajout
          _buildPhoneActionButton(
            onPressed: _isLoading ? null : _addMAMMember,
            icon: Icons.person_add,
            label: _isLoading ? "AJOUT EN COURS..." : "AJOUTER LE MEMBRE",
            color: primaryBlue,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

// Méthode pour créer un champ de formulaire stylé pour iPhone
  Widget _buildPhoneFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryBlue,
              size: 20,
            ),
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

// Méthode pour créer un bouton d'action pour iPhone
  Widget _buildPhoneActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isOutlined = false,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: isOutlined || onPressed == null
            ? null
            : [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: isOutlined || onPressed == null
                  ? null
                  : LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: isOutlined
                  ? Colors.white
                  : (onPressed == null ? Colors.grey.shade300 : null),
              border: isOutlined ? Border.all(color: color, width: 2) : null,
              borderRadius: BorderRadius.circular(30),
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isOutlined ? color : Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          color: isOutlined ? color : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
