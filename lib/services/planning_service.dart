import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:poppins_app/models/garde_model.dart';

class PlanningService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtenir l'ID de structure actuelle de l'utilisateur connecté
  Future<String> getCurrentStructureId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "";

      // Vérifier si l'utilisateur est un membre MAM
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email?.toLowerCase() ?? '')
          .get();

      // Si c'est un membre MAM, obtenir l'ID de la structure associée
      if (userDoc.exists &&
          userDoc.data() != null &&
          userDoc.data()!.containsKey('structureId')) {
        return userDoc.data()!['structureId'];
      }

      // Par défaut, utiliser l'ID de l'utilisateur
      return user.uid;
    } catch (e) {
      print("Erreur lors de la récupération de l'ID de structure: $e");
      return "";
    }
  }

  // Sauvegarder ou mettre à jour une garde
  Future<bool> saveGarde(Garde garde) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Obtenir l'ID de structure
      final structureId = await getCurrentStructureId();
      if (structureId.isEmpty) return false;

      // En mode MAM, vérifier si l'utilisateur a le droit de modifier cette garde
      if (garde.id.isNotEmpty && garde.membreId != user.uid) {
        // Vérifier si l'utilisateur est admin
        final userDoc = await _firestore
            .collection('users')
            .doc(user.email?.toLowerCase() ?? '')
            .get();

        final bool isAdmin = userDoc.exists &&
            userDoc.data() != null &&
            userDoc.data()!.containsKey('role') &&
            userDoc.data()!['role'] == 'admin';

        if (!isAdmin) {
          print(
              'Erreur: Vous ne pouvez pas modifier les gardes d\'un autre membre');
          return false;
        }
      }

      // Préparation des données à sauvegarder
      final gardeData = garde.toJson();

      // Création ou mise à jour
      if (garde.id.isEmpty) {
        // Nouvelle garde
        await _firestore
            .collection('structures')
            .doc(structureId)
            .collection('gardes')
            .add(gardeData);
      } else {
        // Mise à jour
        await _firestore
            .collection('structures')
            .doc(structureId)
            .collection('gardes')
            .doc(garde.id)
            .update(gardeData);
      }

      return true;
    } catch (e) {
      print('Erreur lors de la sauvegarde de la garde: $e');
      return false;
    }
  }

  // Supprimer une garde
  Future<bool> deleteGarde(String gardeId, String membreId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Obtenir l'ID de structure
      final structureId = await getCurrentStructureId();
      if (structureId.isEmpty) return false;

      // En mode MAM, vérifier si l'utilisateur a le droit de supprimer cette garde
      if (membreId != user.uid) {
        // Vérifier si l'utilisateur est admin
        final userDoc = await _firestore
            .collection('users')
            .doc(user.email?.toLowerCase() ?? '')
            .get();

        final bool isAdmin = userDoc.exists &&
            userDoc.data() != null &&
            userDoc.data()!.containsKey('role') &&
            userDoc.data()!['role'] == 'admin';

        if (!isAdmin) {
          print(
              'Erreur: Vous ne pouvez pas supprimer les gardes d\'un autre membre');
          return false;
        }
      }

      // Supprimer la garde
      await _firestore
          .collection('structures')
          .doc(structureId)
          .collection('gardes')
          .doc(gardeId)
          .delete();

      return true;
    } catch (e) {
      print('Erreur lors de la suppression de la garde: $e');
      return false;
    }
  }
}
