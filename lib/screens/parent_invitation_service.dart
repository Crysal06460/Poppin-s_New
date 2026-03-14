import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    required String structureId,
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
          .doc(structureId)
          .get();

      if (!structureDoc.exists) {
        throw Exception("Structure introuvable");
      }

      final structureName = structureDoc.data()?['structureName'] ?? 'Structure d\'accueil';
      final normalizedEmail = parentEmail.trim().toLowerCase();

      // 🔧 VÉRIFICATION DOUBLON : ne pas créer si une invitation pending existe déjà
      final existingInvitation = await _firestore
          .collection('invitations')
          .where('email', isEqualTo: normalizedEmail)
          .where('childId', isEqualTo: childId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingInvitation.docs.isNotEmpty) {
        print('ℹ️ Invitation déjà existante pour $normalizedEmail / enfant $childId, pas de doublon créé.');
        return;
      }

      // 1. Créer le document d'invitation
      DocumentReference? invitationRef;
      try {
        invitationRef = await _firestore.collection('invitations').add({
          'email': normalizedEmail,
          'type': 'parent',
          'structureId': structureId,
          'structureName': structureName,
          'childId': childId,
          'childName': childFirstName,
          'parentFirstName': parentFirstName,
          'parentLastName': parentLastName,
          'invitedBy': currentUser.uid,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        });
      } catch (e) {
        print('❌ Erreur création invitation Firestore: $e');
        rethrow;
      }

      // 2. Ajouter l'email à la file d'attente
      // Si l'ajout à la queue échoue, on marque l'invitation comme 'email_failed'
      // pour pouvoir la relancer manuellement
      try {
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
            'structureId': structureId,
            'androidLink': 'https://play.google.com/store/apps/details?id=com.example.poppins_app',
            'iosLink': 'https://apps.apple.com/app/id123456789',
            'year': DateTime.now().year.toString()
          }
        });
      } catch (emailError) {
        // Marquer l'invitation comme 'email_failed' pour suivi
        print('⚠️ Erreur ajout emailQueue pour $normalizedEmail: $emailError');
        if (invitationRef != null) {
          try {
            await invitationRef.update({'status': 'email_failed'});
          } catch (_) {}
        }
        rethrow;
      }

      print('✅ Invitation créée et email en file d\'attente pour $normalizedEmail');

    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'invitation: $e');
      rethrow;
    }
  }
}
