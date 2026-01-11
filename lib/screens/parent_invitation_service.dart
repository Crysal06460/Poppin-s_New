import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ParentInvitationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Enjoie une invitation au parent après l'ajout d'un enfant
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
      final normalizedEmail = parentEmail.trim().toLowerCase();

      // 1. Créer le document d'invitation
      // Cela permet au parent de "claim" l'invitation via le lien reçu
      await _firestore.collection('invitations').add({
        'email': normalizedEmail,
        'type': 'parent',
        'structureId': currentUser.uid,
        'structureName': structureName,
        'childId': childId,
        'childName': childFirstName,
        'parentFirstName': parentFirstName,
        'parentLastName': parentLastName,
        'invitedBy': currentUser.uid,
        'status': 'pending', // pending, accepted, expired
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });

      // 2. Ajouter l'email à la file d'attente
      await _firestore.collection('emailQueue').add({
        'to': normalizedEmail,
        'template': 'parent-invitation',
        'subject': 'Invitation à suivre les activités de $childFirstName',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'retryCount': 0,
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

      print('✅ Invitation créée et email en file d\'attente pour $normalizedEmail');

    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'invitation: $e');
      throw e;
    }
  }
}