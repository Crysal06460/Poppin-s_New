import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String errorMessage = "";
  bool isLoading = false;
  bool isAssistanteMaterCheck = true;
  bool isMAMCheck = false;
  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasDigit = false;

  @override
  void initState() {
    super.initState();
    // Écouter les changements du mot de passe pour la validation en temps réel
    passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    passwordController.removeListener(_validatePassword);
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Déterminer si l'appareil est un iPad (écran large)
    final screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Inscription",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryBlue,
            fontSize: isTablet ? 20 : 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: primaryBlue,
            size: isTablet ? 24 : 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: isTablet ? _buildTabletContent() : _buildPhoneContent(),
      ),
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

  // Version iPhone (garde le code original)
  Widget _buildPhoneContent() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 25),

              // Logo
              Image.asset(
                "assets/images/parapluie.png",
                height: 100,
                width: 100,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 25),

              Text(
                "Créer un compte structure",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Sélection du type de structure
              Row(
                children: [
                  Expanded(
                    child: _buildTypeCheckbox(
                      title: "Assistante Maternelle",
                      isChecked: isAssistanteMaterCheck,
                      onChanged: (value) {
                        if (value == true) {
                          setState(() {
                            isAssistanteMaterCheck = true;
                            isMAMCheck = false;
                          });
                        }
                      },
                      isTablet: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTypeCheckbox(
                      title: "MAM",
                      isChecked: isMAMCheck,
                      onChanged: (value) {
                        if (value == true) {
                          setState(() {
                            isAssistanteMaterCheck = false;
                            isMAMCheck = true;
                          });
                        }
                      },
                      isTablet: false,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Message d'information pour MAM
              if (isMAMCheck)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: lightBlue,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryBlue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: primaryBlue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Information importante",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Un seul membre de la MAM doit créer le compte. Les autres membres pourront être ajoutés par la suite via des invitations.",
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF455A64)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Champs de formulaire
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(color: primaryBlue),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryBlue, width: 2)),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Mot de passe",
                  labelStyle: TextStyle(color: primaryBlue),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryBlue, width: 2)),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),

              const SizedBox(height: 8),
              _buildPasswordValidationIndicators(),

              const SizedBox(height: 16),

              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirmer le mot de passe",
                  labelStyle: TextStyle(color: primaryBlue),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryBlue, width: 2)),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),

              // Affichage des erreurs
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
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
                        SizedBox(width: 8),
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

              const SizedBox(height: 25),

              // Bouton S'inscrire
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryYellow,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "S'INSCRIRE",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Déjà un compte
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Vous avez déjà un compte ?",
                      style: TextStyle(fontSize: 15)),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      "Se connecter",
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryBlue,
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordValidationIndicators() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Exigences du mot de passe :",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primaryBlue,
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

  // Version iPad - Layout moderne et optimisé
  Widget _buildTabletContent() {
    final screenSize = MediaQuery.of(context).size;
    final double maxWidth = screenSize.width;
    final double maxHeight = screenSize.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: maxWidth * 0.1, // 10% de marge horizontale
                vertical: maxHeight * 0.03, // 3% de marge verticale
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: maxWidth * 0.7, // 70% de la largeur max
                  minHeight: maxHeight * 0.8, // 80% de la hauteur min
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 8),
                      blurRadius: 32,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.1),
                      offset: const Offset(0, 0),
                      blurRadius: 1,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(maxWidth * 0.04), // 4% de padding
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // En-tête avec logo et titre
                      _buildTabletHeader(maxWidth, maxHeight),

                      SizedBox(height: maxHeight * 0.04),

                      // Section de sélection du type
                      _buildTabletTypeSelection(maxWidth, maxHeight),

                      SizedBox(height: maxHeight * 0.03),

                      // Message d'information MAM
                      if (isMAMCheck) _buildTabletMAMInfo(maxWidth, maxHeight),

                      if (isMAMCheck) SizedBox(height: maxHeight * 0.03),

                      // Formulaire
                      _buildTabletForm(maxWidth, maxHeight),

                      SizedBox(height: maxHeight * 0.03),

                      // Bouton et liens
                      _buildTabletActions(maxWidth, maxHeight),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletHeader(double maxWidth, double maxHeight) {
    return Column(
      children: [
        // Logo avec design plus subtil
        Container(
          padding: EdgeInsets.all(maxWidth * 0.015), // Réduit de 0.02 à 0.015
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryBlue.withOpacity(0.08), // Plus subtil
                brightCyan.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            "assets/images/parapluie.png",
            height: maxWidth * 0.06, // Réduit de 0.08 à 0.06
            width: maxWidth * 0.06,
            fit: BoxFit.contain,
          ),
        ),

        SizedBox(height: maxHeight * 0.015), // Réduit de 0.02 à 0.015

        // Titre principal
        Text(
          "Créer un compte structure",
          style: TextStyle(
            fontSize: maxWidth * 0.025, // Réduit de 0.028 à 0.025
            fontWeight: FontWeight.w700, // Légèrement moins gras
            color: primaryBlue,
            letterSpacing: 0.3, // Réduit
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: maxHeight * 0.008), // Réduit de 0.01 à 0.008

        // Sous-titre plus discret
        Text(
          "Rejoignez notre plateforme et facilitez la gestion de votre structure",
          style: TextStyle(
            fontSize: maxWidth * 0.016, // Réduit de 0.018 à 0.016
            color: Colors.grey.shade600,
            height: 1.3, // Réduit
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTabletTypeSelection(double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all(maxWidth * 0.02), // Réduit de 0.025 à 0.02
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.2), // Plus subtil
        borderRadius: BorderRadius.circular(16), // Réduit de 20 à 16
        border: Border.all(color: primaryBlue.withOpacity(0.15)), // Plus subtil
      ),
      child: Column(
        children: [
          Text(
            "Type de structure",
            style: TextStyle(
              fontSize: maxWidth * 0.02, // Réduit de 0.022 à 0.02
              fontWeight: FontWeight.w600, // Moins gras
              color: primaryBlue,
            ),
          ),
          SizedBox(height: maxHeight * 0.015), // Réduit de 0.02 à 0.015
          Row(
            children: [
              Expanded(
                child: _buildTabletTypeCard(
                  title: "Assistante Maternelle",
                  subtitle: "Structure individuelle",
                  icon: Icons.person,
                  isSelected: isAssistanteMaterCheck,
                  onTap: () {
                    setState(() {
                      isAssistanteMaterCheck = true;
                      isMAMCheck = false;
                    });
                  },
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
              ),
              SizedBox(width: maxWidth * 0.015), // Réduit de 0.02 à 0.015
              Expanded(
                child: _buildTabletTypeCard(
                  title: "MAM",
                  subtitle: "Maison d'Assistantes Maternelles",
                  icon: Icons.group,
                  isSelected: isMAMCheck,
                  onTap: () {
                    setState(() {
                      isAssistanteMaterCheck = false;
                      isMAMCheck = true;
                    });
                  },
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required double maxWidth,
    required double maxHeight,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: maxWidth * 0.015,
          vertical: maxHeight * 0.015,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.2),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: maxWidth * 0.025, // Réduit de 0.035 à 0.025
              color: isSelected ? Colors.white : primaryBlue,
            ),
            SizedBox(height: maxHeight * 0.008),
            Text(
              title,
              style: TextStyle(
                fontSize: maxWidth * 0.016, // Réduit de 0.018 à 0.016
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : primaryBlue,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: maxHeight * 0.003),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: maxWidth * 0.012, // Réduit de 0.014 à 0.012
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletMAMInfo(double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all(maxWidth * 0.025),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryYellow.withOpacity(0.1),
            primaryYellow.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryYellow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: primaryYellow,
            size: maxWidth * 0.025,
          ),
          SizedBox(width: maxWidth * 0.015),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Information importante",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryYellow,
                    fontSize: maxWidth * 0.018,
                  ),
                ),
                SizedBox(height: maxHeight * 0.01),
                Text(
                  "Un seul membre de la MAM doit créer le compte. Les autres membres pourront être ajoutés par la suite via des invitations.",
                  style: TextStyle(
                    fontSize: maxWidth * 0.016,
                    color: Color(0xFF455A64),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletForm(double maxWidth, double maxHeight) {
    return Column(
      children: [
        // Email
        _buildTabletTextField(
          controller: emailController,
          label: "Adresse email",
          hint: "votre@email.com",
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),

        SizedBox(height: maxHeight * 0.025),

        // Mot de passe
        _buildTabletTextField(
          controller: passwordController,
          label: "Mot de passe",
          hint: "Min. 6 caractères, 1 majuscule, 1 chiffre",
          icon: Icons.lock_outline,
          isPassword: true,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),

        SizedBox(height: maxHeight * 0.015),
        _buildTabletPasswordValidationIndicators(maxWidth, maxHeight),

        SizedBox(height: maxHeight * 0.025),

        // Confirmation mot de passe
        _buildTabletTextField(
          controller: confirmPasswordController,
          label: "Confirmer le mot de passe",
          hint: "Ressaisissez votre mot de passe",
          icon: Icons.lock_outline,
          isPassword: true,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),

        // Message d'erreur
        if (errorMessage.isNotEmpty) ...[
          SizedBox(height: maxHeight * 0.02),
          Container(
            padding: EdgeInsets.all(maxWidth * 0.02),
            decoration: BoxDecoration(
              color: primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryRed.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: primaryRed,
                  size: maxWidth * 0.02,
                ),
                SizedBox(width: maxWidth * 0.015),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      color: primaryRed,
                      fontSize: maxWidth * 0.016,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabletPasswordValidationIndicators(
      double maxWidth, double maxHeight) {
    return Container(
      padding: EdgeInsets.all(maxWidth * 0.02),
      decoration: BoxDecoration(
        color: lightBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Exigences du mot de passe :",
            style: TextStyle(
              fontSize: maxWidth * 0.014,
              fontWeight: FontWeight.bold,
              color: primaryBlue,
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

  Widget _buildTabletTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    required double maxWidth,
    required double maxHeight,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: maxWidth * 0.018),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: primaryBlue,
            size: maxWidth * 0.022,
          ),
          labelStyle: TextStyle(
            color: primaryBlue,
            fontSize: maxWidth * 0.016,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
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
          contentPadding: EdgeInsets.symmetric(
            horizontal: maxWidth * 0.02,
            vertical: maxHeight * 0.02,
          ),
        ),
      ),
    );
  }

  Widget _buildTabletActions(double maxWidth, double maxHeight) {
    return Column(
      children: [
        // Bouton S'inscrire - Plus sobre et moderne
        Container(
          width: double.infinity,
          height: maxHeight * 0.06, // Réduit de 0.08 à 0.06
          child: ElevatedButton(
            onPressed: isLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryYellow,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Réduit de 16 à 12
              ),
              elevation: 2, // Réduit l'élévation
              shadowColor: primaryYellow.withOpacity(0.3),
            ),
            child: isLoading
                ? SizedBox(
                    height: maxWidth * 0.02, // Réduit de 0.025 à 0.02
                    width: maxWidth * 0.02,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    "S'INSCRIRE",
                    style: TextStyle(
                      fontSize: maxWidth * 0.018, // Réduit de 0.02 à 0.018
                      fontWeight: FontWeight.w600, // Moins gras
                      letterSpacing: 0.5, // Réduit de 1 à 0.5
                    ),
                  ),
          ),
        ),

        SizedBox(height: maxHeight * 0.02), // Réduit de 0.025 à 0.02

        // Lien de connexion - Plus subtil
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Vous avez déjà un compte ? ",
              style: TextStyle(
                fontSize: maxWidth * 0.015, // Réduit de 0.017 à 0.015
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
                padding: EdgeInsets.symmetric(
                  horizontal: maxWidth * 0.008, // Réduit
                  vertical: maxHeight * 0.008,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                "Se connecter",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w600, // Moins gras
                  fontSize: maxWidth * 0.015, // Réduit de 0.017 à 0.015
                  decoration: TextDecoration.underline,
                  decorationColor: primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeCheckbox({
    required String title,
    required bool isChecked,
    required Function(bool?) onChanged,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: isTablet ? 10 : 12, horizontal: isTablet ? 12 : 16),
      decoration: BoxDecoration(
        color: isChecked ? primaryBlue.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChecked ? primaryBlue : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isTablet ? 20 : 24,
            height: isTablet ? 20 : 24,
            child: Transform.scale(
              scale: isTablet ? 0.9 : 1.0,
              child: Checkbox(
                value: isChecked,
                onChanged: onChanged,
                activeColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 6 : 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isTablet ? 13 : 14,
                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                color: isChecked ? primaryBlue : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    // Validation de base
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
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
      // Créer l'utilisateur
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim().toLowerCase(),
        password: passwordController.text.trim(),
      );

      // Déterminer le type de structure sélectionné
      final String structureType = isMAMCheck ? 'MAM' : 'AssistanteMaternelle';

      // Créer le document structure dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(userCredential.user!.uid)
          .set({
        'email': emailController.text.trim().toLowerCase(),
        'structureType': structureType,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Après l'inscription, rediriger vers l'écran de tarification
      if (mounted) {
        context.go('/pricing', extra: {
          'structureType': structureType,
          'structureId': userCredential.user!.uid,
        });
      }
    } catch (e) {
      String message = "Une erreur est survenue lors de l'inscription";

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            message = "Cette adresse e-mail est déjà utilisée";
            break;
          case 'invalid-email':
            message = "Format d'e-mail invalide";
            break;
          case 'weak-password':
            message = "Le mot de passe est trop faible (minimum 6 caractères)";
            break;
        }
      }

      setState(() {
        errorMessage = message;
        isLoading = false;
      });
    }
  }
}
