import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:poppins_app/services/remplacement_session_service.dart';

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
  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasDigit = false;

  // Données d'invitation
  String email = '';
  String invitationType = 'unknown';
  String structureId = '';
  String structureName = 'la structure';
  String? childName;
  String? childId;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705
  // State variables for existing user check
  bool _isExistingUser = false;
  bool _checkingUser = true;

  @override
  void initState() {
    super.initState();
    _extractInvitationData();
    _checkUserExists();
    // Écouter les changements du mot de passe pour la validation en temps réel
    passwordController.addListener(_validatePassword);
  }

  Future<void> _checkUserExists() async {
    if (email.isEmpty) {
      setState(() => _checkingUser = false);
      return;
    }
    try {
      final methods =
          await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        setState(() {
          _isExistingUser = true;
          _checkingUser = false;
        });
      } else {
        setState(() => _checkingUser = false);
      }
    } catch (e) {
      print("Erreur check user: $e");
      setState(() => _checkingUser = false);
    }
  }

  @override
  void dispose() {
    passwordController.removeListener(_validatePassword);
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
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

  IconData get _headerIcon {
    if (invitationType == 'mamMember') return Icons.business;
    if (invitationType == 'remplacement') return Icons.swap_horiz;
    return Icons.family_restroom;
  }

  String get _headerTitle {
    if (_isExistingUser) {
      return invitationType == 'remplacement'
          ? "Connexion remplaçante"
          : "Rejoindre la structure";
    }
    if (invitationType == 'mamMember') return "Rejoindre en tant que membre";
    if (invitationType == 'remplacement') {
      return "Rejoindre en tant que remplaçante";
    }
    return "Rejoindre en tant que parent";
  }

  String get _headerSubtitle {
    if (invitationType == 'mamMember') return "Vous allez rejoindre $structureName";
    if (invitationType == 'remplacement') {
      return "Vous allez remplacer temporairement $structureName, avec votre "
          "propre mot de passe";
    }
    return "Vous allez rejoindre $structureName pour $childName";
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;

    // Déterminer si on est sur iPad
    final bool isTablet = screenSize.shortestSide >= 600;

    // Déterminer la couleur d'accent selon le type d'invitation
    Color accentColor = primaryBlue;
    if (invitationType == 'mamMember') {
      accentColor = brightCyan;
    } else if (invitationType == 'parent') {
      accentColor = primaryYellow;
    } else if (invitationType == 'remplacement') {
      accentColor = primaryRed;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isExistingUser ? "Connexion" : "Finaliser l'inscription",
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
          ? _buildTabletContent(context, screenSize, accentColor)
          : _buildPhoneContent(context, accentColor),
    );
  }

  void _validatePassword() {
    final password = passwordController.text;
    setState(() {
      hasMinLength = password.length >= 6;
      hasUppercase = password.contains(RegExp(r'[A-Z]'));
      hasDigit = password.contains(RegExp(r'[0-9]'));
    });
  }

  Widget _buildPhoneContent(BuildContext context, Color accentColor) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icône et titre
            Icon(
              _headerIcon,
              size: 60,
              color: accentColor,
            ),

            const SizedBox(height: 20),

            Text(
              _headerTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            Text(
              _headerSubtitle,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            if (_checkingUser)
               const Center(child: CircularProgressIndicator())
            else ...[
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
                            _isExistingUser
                                ? "Compte existant détecté"
                                : "Création de votre compte",
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
                      _isExistingUser
                          ? "Une adresse email existe déjà. Veuillez saisir votre mot de passe pour vous connecter et rejoindre la structure."
                          : "Pour finaliser votre inscription, veuillez créer un mot de passe sécurisé pour votre compte.",
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
                hintText: _isExistingUser
                    ? "Votre mot de passe actuel"
                    : "Créez un mot de passe",
                helperText: _isExistingUser
                    ? null
                    : "Min. 6 caractères, 1 majuscule, 1 chiffre",
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
            if (!_isExistingUser) ...[
              const SizedBox(height: 8),
              _buildPasswordValidationIndicators(accentColor),
            ],

            const SizedBox(height: 20),

            // Confirmation du mot de passe (HIDE IF EXISTING USER)
            if (!_isExistingUser)
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
                onPressed: isLoading ? null : _submitForm,
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
                    : Text(
                        _isExistingUser
                            ? "SE CONNECTER ET REJOINDRE"
                            : "CRÉER MON COMPTE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            // Close logic block
            ],

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

  Widget _buildPasswordValidationIndicators(Color accentColor) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Exigences du mot de passe :",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          SizedBox(height: 6),
          _buildPasswordRequirement("Au moins 6 caractères", hasMinLength),
          _buildPasswordRequirement("Au moins une majuscule", hasUppercase),
          _buildPasswordRequirement("Au moins un chiffre", hasDigit),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirement(String requirement, bool isValid) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid ? Colors.green : Colors.grey,
          ),
          SizedBox(width: 6),
          Text(
            requirement,
            style: TextStyle(
              fontSize: 11,
              color: isValid ? Colors.green : Colors.grey.shade600,
              fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletContent(
      BuildContext context, Size screenSize, Color accentColor) {
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
              maxHeight * 0.03, // 3% de marge en haut
              sideMargin,
              maxHeight * 0.03),
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
              padding: EdgeInsets.all(maxWidth * 0.04), // 4% de padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Container d'en-tête avec icône
                  Container(
                    width: maxWidth * 0.12,
                    height: maxWidth * 0.12,
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
                      _headerIcon,
                      size: maxWidth * 0.06,
                      color: accentColor,
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.03),

                  // Titre principal
                  Text(
                    _isExistingUser
                        ? (invitationType == 'remplacement'
                            ? "Connexion remplaçante"
                            : "Connexion requise")
                        : _headerTitle,
                    style: TextStyle(
                      fontSize: maxWidth * 0.03,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: maxHeight * 0.015),

                  // Sous-titre
                  Text(
                    _headerSubtitle,
                    style: TextStyle(
                      fontSize: maxWidth * 0.02,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: maxHeight * 0.04),

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
                                  color: primaryBlue, size: maxWidth * 0.02),
                            ),
                            SizedBox(width: maxWidth * 0.02),
                            Expanded(
                                child: Text(
                                  _isExistingUser
                                      ? "Compte existant détecté"
                                      : "Création de votre compte",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                    fontSize: maxWidth * 0.02,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: maxHeight * 0.015),
                          // Description
                          Text(
                            _isExistingUser
                                ? "Une adresse email existe déjà. Veuillez saisir votre mot de passe pour vous connecter et rejoindre la structure."
                                : "Pour finaliser votre inscription, veuillez créer un mot de passe sécurisé pour votre compte.",
                            style: TextStyle(
                              fontSize: maxWidth * 0.018,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: maxHeight * 0.04),

                  // Affichage de l'email modernisé
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(maxWidth * 0.025),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade100,
                          Colors.grey.shade50,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(maxWidth * 0.012),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.email_outlined,
                              color: accentColor, size: maxWidth * 0.02),
                        ),
                        SizedBox(width: maxWidth * 0.02),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(
                              fontSize: maxWidth * 0.02,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.03),

                  // Champ pour le mot de passe adaptatif
                  Container(
                    width: double.infinity,
                    child: TextField(
                      controller: passwordController,
                      obscureText: !_showPassword,
                      style: TextStyle(fontSize: maxWidth * 0.019),
                      decoration: InputDecoration(
                        labelText: "Mot de passe",
                        hintText: _isExistingUser
                            ? "Votre mot de passe actuel"
                            : "Créez un mot de passe",
                        helperText: _isExistingUser
                            ? null
                            : "Min. 6 caractères, 1 majuscule, 1 chiffre",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: maxWidth * 0.025,
                          vertical: maxHeight * 0.02,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: accentColor, width: 2.5),
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
                          child: Icon(Icons.lock_outline,
                              color: accentColor, size: maxWidth * 0.02),
                        ),
                        suffixIcon: Padding(
                          padding: EdgeInsets.all(maxWidth * 0.015),
                          child: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: accentColor,
                              size: maxWidth * 0.02,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ),
                        labelStyle: TextStyle(
                          color: accentColor,
                          fontSize: maxWidth * 0.018,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: maxWidth * 0.018,
                        ),
                        helperStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: maxWidth * 0.016,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: maxHeight * 0.015),
                  if (!_isExistingUser)
                    _buildTabletPasswordValidationIndicators(
                        maxWidth, maxHeight, accentColor),

                  SizedBox(height: maxHeight * 0.025),

                  // Confirmation du mot de passe adaptatif (HIDE IF EXISTING)
                  if (!_isExistingUser)
                    Container(
                      width: double.infinity,
                      child: TextField(
                        controller: confirmPasswordController,
                        obscureText: !_showPassword,
                        style: TextStyle(fontSize: maxWidth * 0.019),
                        decoration: InputDecoration(
                          labelText: "Confirmer le mot de passe",
                          hintText: "Confirmez votre mot de passe",
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: maxWidth * 0.025,
                            vertical: maxHeight * 0.02,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: accentColor, width: 2.5),
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
                            child: Icon(Icons.lock_outline,
                                color: accentColor, size: maxWidth * 0.02),
                          ),
                          labelStyle: TextStyle(
                            color: accentColor,
                            fontSize: maxWidth * 0.018,
                          ),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: maxWidth * 0.018,
                          ),
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

                  SizedBox(height: maxHeight * 0.05),

                  // Bouton de création de compte modernisé
                  Container(
                    width: contentWidth * 0.7, // 70% de la largeur du contenu
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
                      onPressed: isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        disabledBackgroundColor: accentColor.withOpacity(0.6),
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
                              _isExistingUser
                                  ? "SE CONNECTER ET REJOINDRE"
                                  : "CRÉER MON COMPTE",
                              style: TextStyle(
                                fontSize: maxWidth * 0.021,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
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

  Widget _buildTabletPasswordValidationIndicators(
      double maxWidth, double maxHeight, Color accentColor) {
    return Container(
      padding: EdgeInsets.all(maxWidth * 0.02),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Exigences du mot de passe :",
            style: TextStyle(
              fontSize: maxWidth * 0.014,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          SizedBox(height: maxHeight * 0.01),
          Row(
            children: [
              Expanded(
                  child: _buildTabletPasswordRequirement(
                      "6+ caractères", hasMinLength, maxWidth)),
              Expanded(
                  child: _buildTabletPasswordRequirement(
                      "1 majuscule", hasUppercase, maxWidth)),
              Expanded(
                  child: _buildTabletPasswordRequirement(
                      "1 chiffre", hasDigit, maxWidth)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletPasswordRequirement(
      String requirement, bool isValid, double maxWidth) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.radio_button_unchecked,
          size: maxWidth * 0.015,
          color: isValid ? Colors.green : Colors.grey,
        ),
        SizedBox(width: maxWidth * 0.005),
        Expanded(
          child: Text(
            requirement,
            style: TextStyle(
              fontSize: maxWidth * 0.012,
              color: isValid ? Colors.green : Colors.grey.shade600,
              fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    // Basic validation
    if (passwordController.text.isEmpty) {
      setState(() => errorMessage = "Veuillez entrer le mot de passe");
      return;
    }

    if (!_isExistingUser) {
      if (confirmPasswordController.text.isEmpty) {
        setState(() => errorMessage = "Veuillez confirmer le mot de passe");
        return;
      }
      if (passwordController.text != confirmPasswordController.text) {
        setState(() => errorMessage = "Les mots de passe ne correspondent pas");
        return;
      }
      if (!hasMinLength || !hasUppercase || !hasDigit) {
        setState(() {
          errorMessage =
              "Le mot de passe doit respecter les critères de sécurité";
        });
        return;
      }
    }

    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      UserCredential? userCredential;

      if (_isExistingUser) {
        // LOGIN
        try {
          userCredential =
              await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: passwordController.text.trim(),
          );
        } catch (e) {
          throw e; // Handled in catch block
        }
      } else {
        // CREATE
        try {
          // Double check existance to be safe
          final methods =
              await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
          if (methods.isNotEmpty) {
            setState(() {
              _isExistingUser = true;
              errorMessage =
                  "Un compte existe déjà. Veuillez vous connecter avec votre mot de passe actuel.";
              isLoading = false;
            });
            return;
          }

          userCredential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: passwordController.text.trim(),
          );
        } catch (e) {
          throw e;
        }
      }

      // Success -> Link Data
      if (userCredential != null && userCredential.user != null) {
        await _linkUserToInvitation(userCredential.user!.uid);
      }
    } catch (e) {
      print("Erreur auth: $e");
      setState(() {
        if (e is FirebaseAuthException) {
          if (e.code == 'wrong-password') {
            errorMessage = "Mot de passe incorrect";
          } else if (e.code == 'user-not-found') {
            // Should not happen if logic is correct
            errorMessage = "Utilisateur non trouvé";
          } else if (e.code == 'email-already-in-use') {
            errorMessage = "Cet email est déjà utilisé";
          } else {
            errorMessage = "Erreur: ${e.message}";
          }
        } else {
          errorMessage = "Une erreur est survenue (${e.toString()})";
        }
        isLoading = false;
      });
    }
  }

  Future<void> _linkUserToInvitation(String uid) async {
    final invitationInfo = widget.invitationInfo;

    try {
       if (invitationType == 'mamMember') {
        // Créer/Merge le document utilisateur pour un membre MAM
        await FirebaseFirestore.instance
            .collection('users')
            .doc(email.toLowerCase())
            .set({
          'email': email.toLowerCase(),
          'role': 'mamMember',
          'structureId': structureId,
          'structureName': structureName,
          'isFirstLogin': false,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'firebaseUid': uid,
        }, SetOptions(merge: true));

        // Redirection vers l'interface MAM
        if (mounted) context.go('/home');
      } else if (invitationType == 'assistant') {
        final String assistantFirstName =
            invitationInfo['assistantFirstName'] ?? '';
        final String assistantLastName =
            invitationInfo['assistantLastName'] ?? '';
        final String assistantPhone = invitationInfo['assistantPhone'] ?? '';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(email.toLowerCase())
            .set({
          'email': email.toLowerCase(),
          'role': 'assistantFromParent',
          'structureId': structureId,
          'structureName': structureName,
          'firstName': assistantFirstName,
          'lastName': assistantLastName,
          'phone': assistantPhone,
          'invitedByParent': true,
          'isFirstLogin': false,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'firebaseUid': uid,
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .set({
          'assistantEmail': email.toLowerCase(),
          'assistantFirstName': assistantFirstName,
          'assistantLastName': assistantLastName,
          'assistantPhone': assistantPhone,
          'assistantInvitationStatus': 'completed',
          'assistantLinkedUserId': uid,
          'assistantLinkedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('assistants')
            .doc(email.toLowerCase())
            .set({
          'firstName': assistantFirstName,
          'lastName': assistantLastName,
          'email': email.toLowerCase(),
          'phone': assistantPhone,
          'status': 'active',
          'linkedUserId': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) context.go('/home');
      } else if (invitationType == 'parent') {
        // Ajouter un log pour déboguer
        print("⭐ Linking compte parent avec childId: $childId");

        // Créer/Merge le document utilisateur pour un parent
        await FirebaseFirestore.instance
            .collection('users')
            .doc(email.toLowerCase())
            .set({
          'email': email.toLowerCase(),
          'role': 'parent',
          'childId': childId, // Keep for legacy/single child refs
          'childName': childName,
          'structureId': structureId,
          'structureName': structureName,
          'isFirstLogin': false,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'firebaseUid': uid,
          // Ajouter l'enfant à la liste
          'children': FieldValue.arrayUnion([childId]),
        }, SetOptions(merge: true));

        print("✅ Compte parent lié avec succès");

        // Update Invitation Status
        try {
          final invitationsQuery = await FirebaseFirestore.instance
              .collection('invitations')
              .where('email', isEqualTo: email)
              .where('structureId', isEqualTo: structureId)
              .get();

          // 🔧 Marquer TOUTES les invitations pending/active comme completed
          for (final doc in invitationsQuery.docs) {
            final status = (doc.data()['status'] ?? '').toString().toLowerCase();
            if (status == 'pending' || status == 'active') {
              await FirebaseFirestore.instance
                  .collection('invitations')
                  .doc(doc.id)
                  .update({'status': 'completed'});
            }
          }
        } catch (e) {
          print("Erreur update invitation: $e");
        }

        // Ajouter un délai pour s'assurer que Firestore a bien été mis à jour
        await Future.delayed(const Duration(milliseconds: 500));

        // Redirection vers l'interface parent
        if (mounted) {
          context.go('/parent/home');
        }
      } else if (invitationType == 'remplacement') {
        // ⚠️ Branche DÉLIBÉRÉMENT différente des autres : on n'écrit JAMAIS
        // sur users/{email} (pas de structureId, pas de role). Si cet email
        // correspond par ailleurs à un vrai compte Poppins existant (le check
        // fetchSignInMethodsForEmail ci-dessus l'a déjà routé vers "connecte-toi
        // avec ton mot de passe réel"), on ne doit surtout pas corrompre ce
        // compte. Tout l'accès temporaire est porté par le doc
        // `remplacements/{id}` + un custom token vers l'UID de la propriétaire
        // (voir RemplacementSessionService), jamais par une identité users/.

        // Marquer l'invitation comme complétée : autorisé par les règles
        // Firestore car la remplaçante ne modifie que le statut de SA PROPRE
        // invitation (resource.data.email == myEmail()).
        try {
          final invitationId = invitationInfo['invitationId'];
          if (invitationId != null && invitationId.toString().isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('invitations')
                .doc(invitationId.toString())
                .update({'status': 'completed'});
          }
        } catch (e) {
          print("Erreur marquage invitation remplacement complétée: $e");
        }

        // Le doc `remplacements/{id}` vit sous structures/{structureId}, que
        // cette remplaçante toute juste créée ne peut PAS écrire directement
        // (elle n'est pas encore membre de la structure — voir
        // isStructureMember() dans firestore.rules). On réutilise donc
        // `activateRemplacementSession` (Cloud Function, Admin SDK) via
        // RemplacementSessionService.tryActivate() : si sa fenêtre est déjà
        // ouverte, ça bascule immédiatement sa session sur l'UID propriétaire
        // ET positionne replacementUid/status côté serveur. Sinon, cela sera
        // fait automatiquement à son premier vrai login (login_screen_new /
        // quick_login_screen), une fois la fenêtre ouverte.
        bool activated = false;
        try {
          activated = await RemplacementSessionService.instance.tryActivate();
        } catch (e) {
          print("Erreur activation remplacement à l'inscription: $e");
        }

        if (!mounted) return;
        if (activated) {
          context.go('/home');
        } else {
          setState(() {
            isLoading = false;
            errorMessage = "Compte créé avec succès. Votre période de "
                "remplacement n'a pas encore commencé (ou est terminée) : "
                "revenez vous connecter sur l'écran de connexion à la date "
                "prévue.";
          });
        }
      }
    } catch (e) {
       print("Erreur linking: $e");
       setState(() {
         errorMessage = "Erreur lors de la configuration du compte: $e";
         isLoading = false;
       });
    }
  }

  // Deprecated/Removed method stub to ensure old calls (if any) are caught
  // (In reality we replaced the entire block so this is just comments)

}
