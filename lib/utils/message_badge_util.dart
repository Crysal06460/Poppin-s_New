import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageBadgeUtil {
  static const String _unreadMessagesKey = 'has_unread_messages';

  // Vérifier si le badge devrait être affiché
  static Future<bool> shouldShowBadge() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return prefs.getBool(_unreadMessagesKey) ?? false;

      final currentUserEmail = user.email?.toLowerCase();
      if (currentUserEmail == null)
        return prefs.getBool(_unreadMessagesKey) ?? false;

      // Vérifier d'abord le compteur de messages non lus dans le document utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Vérifier si l'utilisateur est un parent
        final bool isParent = userData['role'] == 'parent';

        // Si le compteur est supérieur à 0, on affiche le badge
        if (userData['unreadMessages'] != null &&
            userData['unreadMessages'] > 0) {
          await prefs.setBool(_unreadMessagesKey, true);
          print(
              "✅ Badge actif: compteur unreadMessages = ${userData['unreadMessages']}");
          return true;
        }

        // Traitement spécifique selon le rôle
        if (isParent) {
          // Cas d'un parent
          print(
              "👪 Vérification des messages pour le parent: $currentUserEmail");

          // Récupérer les IDs des enfants du parent
          List<String> childIds = List<String>.from(userData['children'] ?? []);

          if (childIds.isEmpty) {
            print("🚫 Aucun enfant associé au parent");
            await prefs.setBool(_unreadMessagesKey, false);
            return false;
          }

          // Vérifier les messages non lus ENVOYÉS PAR L'ASSISTANTE MATERNELLE uniquement
          final messagesQuery = await FirebaseFirestore.instance
              .collection('exchanges')
              .where('childId', whereIn: childIds)
              .where('senderType',
                  isEqualTo:
                      'assistante') // CORRIGÉ: 'assistante' au lieu de 'staff'
              .where('nonLu', isEqualTo: true)
              .limit(1)
              .get();

          final hasUnreadMessages = messagesQuery.docs.isNotEmpty;

          if (hasUnreadMessages) {
            print(
                "📬 Messages non lus de l'assistante pour le parent $currentUserEmail");
            await prefs.setBool(_unreadMessagesKey, true);
            return true;
          } else {
            print(
                "📭 Aucun message non lu de l'assistante pour le parent $currentUserEmail");
            await prefs.setBool(_unreadMessagesKey, false);
            return false;
          }
        } else {
          // Cas d'une assistante maternelle ou membre MAM
          final bool isMamMember = userData['role'] == 'mamMember';
          final String structureId = userData['structureId'] ?? user.uid;

          if (isMamMember) {
            print(
                "👥 Vérification des messages pour le membre MAM: $currentUserEmail");

            bool allowAllChildren = true;
            try {
              final structureDoc = await FirebaseFirestore.instance
                  .collection('structures')
                  .doc(structureId)
                  .get();
              final data = structureDoc.data();
              if (data != null && data['showAllChildrenOnHome'] is bool) {
                allowAllChildren = data['showAllChildrenOnHome'] as bool;
              }
            } catch (e) {
              print("⚠️ Impossible de récupérer la préférence showAllChildren: $e");
            }

            final childrenCollection = FirebaseFirestore.instance
                .collection('structures')
                .doc(structureId)
                .collection('children');

            final QuerySnapshot childrenSnapshot = allowAllChildren
                ? await childrenCollection.get()
                : await childrenCollection
                    .where('assignedMemberEmail',
                        isEqualTo: currentUserEmail)
                    .get();

            if (childrenSnapshot.docs.isEmpty) {
              print(allowAllChildren
                  ? "🚫 Aucun enfant trouvé dans la structure"
                  : "🚫 Aucun enfant assigné au membre MAM");
              await prefs.setBool(_unreadMessagesKey, false);
              return false;
            }

            final childIds =
                childrenSnapshot.docs.map((doc) => doc.id).toList();
            print(allowAllChildren
                ? "👶 Enfants accessibles pour $currentUserEmail: ${childIds.length} (tous les enfants)"
                : "👶 Enfants assignés à $currentUserEmail: ${childIds.length}");

            // Vérifier s'il y a des messages non lus ENVOYÉS PAR LES PARENTS
            final messagesQuery = await FirebaseFirestore.instance
                .collection('exchanges')
                .where('childId', whereIn: childIds)
                .where('senderType', isEqualTo: 'parent')
                .where('nonLu', isEqualTo: true)
                .limit(1)
                .get();

            final hasUnreadMessages = messagesQuery.docs.isNotEmpty;

            if (hasUnreadMessages) {
              print(
                  "📬 Messages non lus trouvés pour ${allowAllChildren ? 'les enfants de la structure' : 'les enfants assignés'} à $currentUserEmail");
              await prefs.setBool(_unreadMessagesKey, true);
              return true;
            } else {
              print(
                  "📭 Aucun message non lu pour ${allowAllChildren ? 'les enfants de la structure' : 'les enfants assignés'} à $currentUserEmail");
              await prefs.setBool(_unreadMessagesKey, false);
              return false;
            }
          } else {
            // Pour une assistante maternelle individuelle
            print("👩‍⚕️ Vérification pour assistante maternelle individuelle");

            // Récupérer tous les enfants
            final childrenSnapshot = await FirebaseFirestore.instance
                .collection('structures')
                .doc(structureId)
                .collection('children')
                .get();

            final childIds =
                childrenSnapshot.docs.map((doc) => doc.id).toList();

            if (childIds.isEmpty) {
              print("🚫 Aucun enfant trouvé pour l'assistante");
              await prefs.setBool(_unreadMessagesKey, false);
              return false;
            }

            // Vérifier s'il y a des messages non lus ENVOYÉS PAR LES PARENTS
            final messagesQuery = await FirebaseFirestore.instance
                .collection('exchanges')
                .where('childId', whereIn: childIds)
                .where('senderType', isEqualTo: 'parent')
                .where('nonLu', isEqualTo: true)
                .limit(1)
                .get();

            final hasUnreadMessages = messagesQuery.docs.isNotEmpty;

            if (hasUnreadMessages) {
              print("📬 Messages non lus trouvés pour l'assistante");
              await prefs.setBool(_unreadMessagesKey, true);
              return true;
            } else {
              print("📭 Aucun message non lu pour l'assistante");
              await prefs.setBool(_unreadMessagesKey, false);
              return false;
            }
          }
        }
      }
    } catch (e) {
      print("❌ Erreur lors de la vérification du badge: $e");
    }

    // En cas d'erreur ou si aucune condition n'est remplie, utiliser la valeur en cache
    return prefs.getBool(_unreadMessagesKey) ?? false;
  }

  // Forcer l'affichage du badge pour un enfant spécifique
  static Future<void> forceShowBadge(String childId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final currentUserEmail = user.email?.toLowerCase();
      if (currentUserEmail == null) return;

      print("🔍 Recherche de l'enfant $childId pour notifier le bon membre");

      // Récupérer les informations de l'utilisateur connecté
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      if (!userDoc.exists) {
        print("⚠️ Utilisateur non trouvé");
        return;
      }

      final userData = userDoc.data()!;

      // Vérifier si c'est un parent
      final bool isParent = userData['role'] == 'parent';

      if (isParent) {
        // IMPORTANT: Ne pas forcer le badge pour un parent qui envoie un message
        print(
            "👪 L'utilisateur est un parent, pas besoin de forcer le badge pour ses propres messages");
        return;
      }

      final bool isMamMember = userData['role'] == 'mamMember';
      final String structureId = userData['structureId'] ?? user.uid;

      // Récupérer l'enfant concerné
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .get();

      if (!childDoc.exists) {
        print("⚠️ Enfant $childId non trouvé");
        return;
      }

      final childData = childDoc.data()!;

      if (isMamMember) {
        bool allowAllChildren = true;
        try {
          final structureDoc = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .get();
          final data = structureDoc.data();
          if (data != null && data['showAllChildrenOnHome'] is bool) {
            allowAllChildren = data['showAllChildrenOnHome'] as bool;
          }
        } catch (e) {
          print("⚠️ Impossible de récupérer showAllChildren pour forceShowBadge: $e");
        }

        final String? assignedMemberEmail =
            childData['assignedMemberEmail']?.toString().toLowerCase();
        final bool isAssignedToUser = assignedMemberEmail != null &&
            assignedMemberEmail.isNotEmpty &&
            assignedMemberEmail == currentUserEmail;

        if (allowAllChildren || isAssignedToUser) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_unreadMessagesKey, true);

          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserEmail)
              .update({'unreadMessages': FieldValue.increment(1)});

          print(allowAllChildren
              ? "✅ Badge forcé (accès tous les enfants) pour $currentUserEmail"
              : "✅ Badge forcé pour le membre assigné: $currentUserEmail");
        } else {
          if (assignedMemberEmail != null && assignedMemberEmail.isNotEmpty) {
            print(
                "⚠️ Badge non forcé: message destiné à $assignedMemberEmail, utilisateur actuel: $currentUserEmail");
          } else {
            print("⚠️ L'enfant $childId n'a pas de membre assigné");
          }
        }
      } else {
        // Pour une assistante maternelle individuelle
        // Mettre à jour les préférences locales
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_unreadMessagesKey, true);

        // Mettre à jour le compteur dans Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserEmail)
            .update({'unreadMessages': FieldValue.increment(1)});

        print(
            "✅ Badge forcé pour l'assistante individuelle: $currentUserEmail");
      }
    } catch (e) {
      print("❌ Erreur lors du forçage du badge: $e");
    }
  }

  // Réinitialiser le badge
  static Future<void> resetBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_unreadMessagesKey, false);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email?.toLowerCase())
            .update({'unreadMessages': 0});

        print("✅ Badge réinitialisé pour: ${user.email}");
      }
    } catch (e) {
      print("❌ Erreur lors de la réinitialisation du badge: $e");
    }
  }
}
