import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart'; 
import '../utils/session_util.dart';
import '../utils/message_badge_util.dart';
import '../utils/stock_badge_util.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({Key? key}) : super(key: key);

  @override
  _ParentSettingsScreenState createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Couleurs officielles
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color primaryRed = Color(0xFFD94350);

  bool _isLoading = true;
  String _parentName = "";
  String _parentEmail = "";
  
  // Badge states
  bool _showMessageBadge = false;
  bool _showStockBadge = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkBadges();
  }
  
  Future<void> _checkBadges() async {
      await _checkMessageBadge();
      await _checkStockBadge();
  }

  Future<void> _checkMessageBadge() async {
    try {
      final shouldShow = await MessageBadgeUtil.shouldShowBadge();
      if (mounted) setState(() => _showMessageBadge = shouldShow);
    } catch (e) {
      print('Erreur badge message: $e');
    }
  }

  Future<void> _checkStockBadge() async {
    try {
      final shouldShow = await StockBadgeUtil.shouldShowBadge();
      if (mounted) setState(() => _showStockBadge = shouldShow);
    } catch (e) {
      print('Erreur badge stock: $e');
    }
  }
  
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        context.go('/login');
        return;
      }
      
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get();
          
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          _parentName = "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}";
          _parentEmail = userData['email'] ?? '';
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _logout() async {
    await SessionUtil.signOut();
    context.go('/login');
  }

  // --- LOGIQUE CHANGEMENT EMAIL parent ---

  Future<void> _showEmailChangeDialog() async {
    final TextEditingController newEmailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final _dialogFormKey = GlobalKey<FormState>();
    bool _isDialogLoading = false;
    String? _dialogError;
    // Utilisation de la couleur primaire de l'app plutôt que l'ancienne 0xFF8B8FE5
    const dialogPrimaryColor = primaryBlue; 

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: dialogPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock_person, color: dialogPrimaryColor),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Changer mon email",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: primaryBlue, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Votre identifiant de connexion sera modifié. Vous devrez vous reconnecter après validation.",
                                style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      TextFormField(
                        controller: newEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Nouvel email",
                          prefixIcon: Icon(Icons.alternate_email, color: dialogPrimaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: dialogPrimaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return "Email requis";
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return "Email invalide";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Mot de passe actuel",
                          prefixIcon: Icon(Icons.lock_outline, color: dialogPrimaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                           enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: dialogPrimaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          helperText: "Pour confirmer votre identité",
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return "Mot de passe requis";
                          return null;
                        },
                      ),
                      if (_dialogError != null) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _dialogError!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 24),
              actions: [
                TextButton(
                  onPressed: _isDialogLoading ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: _isDialogLoading
                      ? null
                      : () async {
                          if (_dialogFormKey.currentState!.validate()) {
                            setState(() {
                              _isDialogLoading = true;
                              _dialogError = null;
                            });

                            final success = await _changeEmail(
                              newEmailController.text.trim(),
                              passwordController.text,
                              (error) => setState(() => _dialogError = error),
                            );

                            setState(() => _isDialogLoading = false);

                            if (success && mounted) {
                              Navigator.of(context).pop();
                              await SessionUtil.signOut();
                              context.go('/login');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Email modifié avec succès. Veuillez vous reconnecter."),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dialogPrimaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isDialogLoading
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Valider"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _changeEmail(
      String newEmail, String password, Function(String) onError) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      if (user.email == newEmail) {
        onError("Le nouvel email doit être différent.");
        return false;
      }

      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('updateUserEmail');

      await callable.call({
        'newEmail': newEmail,
        'password': password,
      });

      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        onError("Mot de passe incorrect.");
      } else {
        onError("Erreur d'authentification: ${e.message}");
      }
      return false;
    } on FirebaseFunctionsException catch (e) {
      onError("${e.message}");
      return false;
    } catch (e) {
      onError("Erreur: $e");
      return false;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA), // Fond plus clair, style moderne
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Header moderne avec dégradé
                SliverAppBar(
                  expandedHeight: 140.0,
                  pinned: true,
                  backgroundColor: primaryBlue,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryBlue,
                            primaryBlue.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child:  Padding(
                          padding: const EdgeInsets.only(left: 24, bottom: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Paramètres",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Gérez votre compte et vos préférences",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                SliverToBoxAdapter(child: SizedBox(height: 24)),

                // SECTION PROFIL
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSectionHeader("Mon Profil"),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 15,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildProfileHeader(),
                            Divider(height: 1, indent: 20, endIndent: 20),
                            _buildSettingsTile(
                              icon: Icons.alternate_email,
                              title: "Adresse Email",
                              subtitle: _parentEmail,
                              trailing: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text("Modifier", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              onTap: _showEmailChangeDialog,
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 30),
                      
                      // BOUTON DÉCONNEXION
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryRed,
                            elevation: 0,
                            side: BorderSide(color: primaryRed.withOpacity(0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Se déconnecter",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 50),
                      Center(
                        child: Text(
                          "Version 1.0.0",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(height: 100), // Espace pour la bottom nav
                    ]),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            context.go('/parent/home');
          } else if (index == 1) {
             context.go('/parent/messages');
          } else if (index == 2) {
             context.go('/parent/stocks');
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.black87,
        elevation: 15, // Ombre plus marquée pour le style
        type: BottomNavigationBarType.fixed, // Assure que le style est constant
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12, color: Colors.black87),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_home.png',
              width: 60,
              height: 60,
            ),
             activeIcon: Image.asset(
              'assets/images/Icone_home.png',
              width: 60,
              height: 60,
            ),
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Image.asset(
                  'assets/images/Icone_message.png',
                  width: 60,
                  height: 60,
                ),
                if (_showMessageBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                    ),
                  ),
              ],
            ),
             activeIcon: Stack(
              children: [
                Image.asset(
                  'assets/images/Icone_message.png',
                  width: 60,
                  height: 60,
                ),
                if (_showMessageBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                    ),
                  ),
              ],
            ),
            label: "Messages",
          ),
          BottomNavigationBarItem(
             icon: Stack(
              children: [
                Image.asset(
                  'assets/images/Icone_stock.png',
                  width: 60,
                  height: 60,
                ),
                if (_showStockBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                    ),
                  ),
              ],
            ),
             activeIcon: Stack(
              children: [
                Image.asset(
                  'assets/images/Icone_stock.png',
                  width: 60,
                  height: 60,
                ),
                if (_showStockBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                    ),
                  ),
              ],
            ),
            label: "Stocks",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone-parametres.png',
              width: 50,
              height: 50,
            ),
             activeIcon: Image.asset(
              'assets/images/Icone-parametres.png',
              width: 50,
              height: 50,
            ),
            label: "Paramètres",
          ),
        ],
      ),
    );
  }
  
  // WIDGETS D'INTERFACE UTILS

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  
  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _parentName.isNotEmpty ? _parentName[0].toUpperCase() : "?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _parentName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Compte Parent",
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.grey[700], size: 22),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(Icons.chevron_right, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}