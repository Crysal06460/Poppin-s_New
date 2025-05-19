import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ParentInvitationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Envoie une invitation au parent après l'ajout d'un enfant
  /// Cette méthode est appelée automatiquement à la fin de l'ajout d'un enfant
  static Future<void> sendInvitationToParent({
    required String childId,
    required String childFirstName,
    required String parentEmail,
    required String parentFirstName,
    required String parentLastName,
  }) async {
    try {
      // Vérifier que l'utilisateur est connecté
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception("Vous devez être connecté pour envoyer une invitation");
      }

      // Récupérer les détails de la structure
      final structureDoc = await _firestore
          .collection('structures')
          .doc(currentUser.uid)
          .get();
      
      if (!structureDoc.exists) {
        throw Exception("Structure introuvable");
      }

      final structureName = structureDoc.data()?['structureName'] ?? 'Structure d\'accueil';

      // Ajouter le document à la file d'attente d'emails
      await _firestore.collection('emailQueue').add({
  'to': parentEmail,
  'template': 'parent-invitation', // Modifier pour correspondre au nom du fichier HTML
  'subject': 'Invitation à suivre les activités de ${childFirstName}',
  'status': 'pending',
  'createdAt': FieldValue.serverTimestamp(),
  'templateData': {
    'firstName': parentFirstName,
    'lastName': parentLastName,
    'childName': childFirstName,
    'childId': childId,
    'structureName': structureName,
    'structureId': currentUser.uid,
    'androidLink': 'https://play.google.com/store/apps/details?id=com.example.poppins_app',
    'iosLink': 'https://apps.apple.com/app/id123456789',
    'year': DateTime.now().year.toString()
  }
});

      // Créer un compte utilisateur pour le parent avec un mot de passe temporaire
      try {
        // Vérifier d'abord si l'utilisateur existe déjà
        final methods = await _auth.fetchSignInMethodsForEmail(parentEmail);
        if (methods.isEmpty) {
          // L'utilisateur n'existe pas encore, on le crée
          final temporaryPassword = _generateTemporaryPassword();
          
          // Créer l'utilisateur dans FirebaseAuth
          await _auth.createUserWithEmailAndPassword(
            email: parentEmail,
            password: temporaryPassword,
          );

          // Se reconnecter avec le compte de l'assistante maternelle
          await _auth.signInWithEmailAndPassword(
            email: currentUser.email!,
            password: 'CURRENT_USER_PASSWORD', // Ce n'est pas sécurisé et devrait être géré différemment
          );

          // Marquer ce compte comme un compte parent dans Firestore
          await _firestore.collection('users').doc(parentEmail.toLowerCase()).set({
            'email': parentEmail.toLowerCase(),
            'firstName': parentFirstName,
            'lastName': parentLastName,
            'role': 'parent',
            'createdAt': FieldValue.serverTimestamp(),
            'children': [childId],
            'structureId': currentUser.uid,
          });
        } else {
          // L'utilisateur existe déjà, mettre à jour ses informations
          await _firestore.collection('users').doc(parentEmail.toLowerCase()).update({
            'firstName': parentFirstName,
            'lastName': parentLastName,
            'children': FieldValue.arrayUnion([childId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        print('✅ Invitation envoyée à $parentEmail pour l\'enfant $childFirstName');
      } catch (authError) {
        print('❌ Erreur lors de la création du compte parent: $authError');
        // Continuer quand même, l'email sera envoyé et le parent pourra s'inscrire lui-même
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'invitation: $e');
      throw e;
    }
  }

  /// Génère un mot de passe temporaire aléatoire
  static String _generateTemporaryPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(10, (_) => chars.codeUnitAt((DateTime.now().millisecondsSinceEpoch % chars.length))),
    );
  }
}