// lib/screens/account_deletion_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({Key? key}) : super(key: key);

  @override
  _AccountDeletionScreenState createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _isLoading = false;
  bool _showConfirmation = false;

  // Couleurs de votre app
  static const Color primaryColor = Color(0xFF3D9DF2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor,
                  primaryColor.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/dashboard'),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Supprimer mon compte",
                        style: TextStyle(
                          fontSize: 24,
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

          // Contenu principal
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        SizedBox(height: 20),
                        Text(
                          "Suppression en cours...",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : _showConfirmation
                    ? _buildConfirmationStep()
                    : _buildWarningStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // Icône d'avertissement
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
          ),

          SizedBox(height: 32),

          // Titre
          Text(
            "Suppression définitive",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 16),

          // Message d'avertissement
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.shade200,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade600,
                  size: 32,
                ),
                SizedBox(height: 12),
                Text(
                  "Cette action supprimera définitivement :",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  "• Votre compte et toutes vos données\n"
                  "• Toutes les photos des enfants\n"
                  "• L'historique des activités\n"
                  "• Les informations de structure\n"
                  "• Les transmissions et messages",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.orange.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Note importante sur l'abonnement
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.credit_card,
                  color: primaryColor,
                  size: 32,
                ),
                SizedBox(height: 12),
                Text(
                  "📱 Important : Abonnement",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Vous devez d'abord résilier votre abonnement dans les réglages de votre appareil :\n\n"
                  "• iOS : Réglages > Apple ID > Abonnements\n"
                  "• Autres appareils : Consultez les paramètres de votre magasin d'applications",
                  style: TextStyle(
                    fontSize: 16,
                    color: primaryColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          SizedBox(height: 40),

          // Bouton continuer
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showConfirmation = true;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Je comprends, continuer',
                        style: TextStyle(
                          fontSize: 18,
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

          SizedBox(height: 16),

          // Bouton annuler
          TextButton(
            onPressed: () => context.go('/dashboard'),
            child: Text(
              'Annuler',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // Icône de confirmation
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_forever,
              size: 64,
              color: Colors.red.shade600,
            ),
          ),

          SizedBox(height: 32),

          Text(
            "Confirmation finale",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 24),

          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.shade200,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  "⚠️ DERNIÈRE CHANCE",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Vous êtes sur le point de supprimer définitivement votre compte. Cette action est irréversible.\n\n"
                  "Êtes-vous absolument certain(e) de vouloir continuer ?",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          SizedBox(height: 40),

          // Bouton suppression définitive
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _deleteAccount,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_forever,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'SUPPRIMER DÉFINITIVEMENT',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 16),

          // Bouton retour
          Container(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showConfirmation = false;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Retour',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
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
    );
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Supprimer les données Firestore
      await _deleteFirestoreData(user.uid);

      // 2. Supprimer les fichiers Storage
      await _deleteStorageFiles(user.uid);

      // 3. Supprimer le compte Firebase Auth
      await user.delete();

      // 4. Rediriger vers l'écran de bienvenue
      if (mounted) {
        context.go('/');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Compte supprimé avec succès"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la suppression: $e');

      // Gestion spéciale pour l'erreur de réauthentification
      if (e.toString().contains('requires-recent-login')) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showReauthenticationDialog();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur lors de la suppression: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showReauthenticationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.security,
                color: primaryColor,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Sécurité renforcée",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade600,
                      size: 32,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Pour votre sécurité, vous devez vous reconnecter avant de supprimer votre compte.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange.shade800,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                "Vous allez être déconnecté(e). Reconnectez-vous puis revenez sur cette page.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/dashboard');
              },
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Déconnecter l'utilisateur
                await FirebaseAuth.instance.signOut();

                // Rediriger vers login
                context.go('/login');

                // Message d'information
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Reconnectez-vous puis revenez sur 'Supprimer mon compte'",
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: primaryColor,
                    duration: Duration(seconds: 4),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Me reconnecter',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFirestoreData(String userId) async {
    final batch = FirebaseFirestore.instance.batch();

    try {
      // Supprimer les collections principales
      final collections = [
        'structures',
        'users',
        'children',
        'activities',
        'photos',
        'transmissions',
        'messages',
      ];

      for (String collection in collections) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection(collection)
            .where('userId', isEqualTo: userId)
            .get();

        for (var doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
    } catch (e) {
      print('Erreur suppression Firestore: $e');
    }
  }

  Future<void> _deleteStorageFiles(String userId) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('users/$userId');
      await _deleteStorageFolder(storageRef);
    } catch (e) {
      print('Erreur suppression Storage: $e');
    }
  }

  Future<void> _deleteStorageFolder(Reference ref) async {
    try {
      final ListResult result = await ref.listAll();

      // Supprimer tous les fichiers
      for (Reference fileRef in result.items) {
        await fileRef.delete();
      }

      // Supprimer récursivement les sous-dossiers
      for (Reference folderRef in result.prefixes) {
        await _deleteStorageFolder(folderRef);
      }
    } catch (e) {
      print('Erreur suppression dossier Storage: $e');
    }
  }
}
