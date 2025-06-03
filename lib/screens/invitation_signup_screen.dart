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
  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasDigit = false;

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
    // Écouter les changements du mot de passe pour la validation en temps réel
    passwordController.addListener(_validatePassword);
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
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Finaliser l'inscription",
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
                helperText: "Min. 6 caractères, 1 majuscule, 1 chiffre",
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
            const SizedBox(height: 8),
            _buildPasswordValidationIndicators(accentColor),

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
                      invitationType == 'mamMember'
                          ? Icons.business
                          : Icons.family_restroom,
                      size: maxWidth * 0.06,
                      color: accentColor,
                    ),
                  ),

                  SizedBox(height: maxHeight * 0.03),

                  // Titre principal
                  Text(
                    invitationType == 'mamMember'
                        ? "Rejoindre en tant que membre"
                        : "Rejoindre en tant que parent",
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
                    invitationType == 'mamMember'
                        ? "Vous allez rejoindre $structureName"
                        : "Vous allez rejoindre $structureName pour $childName",
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
                                "Création de votre compte",
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
                          "Pour finaliser votre inscription, veuillez créer un mot de passe sécurisé pour votre compte.",
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
                        hintText: "Créez un mot de passe",
                        helperText: "Min. 6 caractères, 1 majuscule, 1 chiffre",
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
                  _buildTabletPasswordValidationIndicators(
                      maxWidth, maxHeight, accentColor),

                  SizedBox(height: maxHeight * 0.025),

                  // Confirmation du mot de passe adaptatif
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
                      onPressed: isLoading ? null : _createAccount,
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
                              "CRÉER MON COMPTE",
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

    if (!hasMinLength || !hasUppercase || !hasDigit) {
      setState(() {
        errorMessage =
            "Le mot de passe doit contenir au moins 6 caractères, une majuscule et un chiffre";
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
