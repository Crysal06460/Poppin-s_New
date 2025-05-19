import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum UserRole {
  assistanteMat,
  parent,
  unknown
}

class UserRoleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Cache pour éviter des requêtes répétées
  static UserRole? _cachedRole;
  static String? _cachedUserId;
  
  /// Détermine le rôle de l'utilisateur actuellement connecté
  static Future<UserRole> determineUserRole() async {
    try {
      final User? currentUser = _auth.currentUser;
      
      // Si aucun utilisateur n'est connecté
      if (currentUser == null) {
        return UserRole.unknown;
      }
      
      // Si le rôle est déjà en cache et que l'utilisateur n'a pas changé
      if (_cachedRole != null && _cachedUserId == currentUser.uid) {
        return _cachedRole!;
      }
      
      // Vérifier dans la collection 'structures' (assistantes maternelles)
      final structureDoc = await _firestore
          .collection('structures')
          .doc(currentUser.uid)
          .get();
          
      if (structureDoc.exists) {
        _cachedRole = UserRole.assistanteMat;
        _cachedUserId = currentUser.uid;
        return UserRole.assistanteMat;
      }
      
      // Vérifier dans la collection 'users' (parents)
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.email?.toLowerCase())
          .get();
          
      if (userDoc.exists && userDoc.data()?['role'] == 'parent') {
        _cachedRole = UserRole.parent;
        _cachedUserId = currentUser.uid;
        return UserRole.parent;
      }
      
      // Si aucun rôle n'est trouvé
      return UserRole.unknown;
    } catch (e) {
      print('❌ Erreur lors de la détermination du rôle: $e');
      return UserRole.unknown;
    }
  }
  
  /// Récupère les enfants associés à l'utilisateur actuel
  static Future<List<Map<String, dynamic>>> getUserChildren() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }
      
      final userRole = await determineUserRole();
      
      switch (userRole) {
        case UserRole.assistanteMat:
          // Récupérer tous les enfants de la structure
          final childrenSnapshot = await _firestore
              .collection('structures')
              .doc(currentUser.uid)
              .collection('children')
              .get();
              
          return childrenSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'firstName': data['firstName'] ?? 'Sans nom',
              'lastName': data['lastName'] ?? '',
              'photoUrl': data['photoUrl'],
              // Autres informations pertinentes...
            };
          }).toList();
          
        case UserRole.parent:
          // Récupérer le document utilisateur du parent
          final userDoc = await _firestore
              .collection('users')
              .doc(currentUser.email?.toLowerCase())
              .get();
              
          if (!userDoc.exists) {
            return [];
          }
          
          final userData = userDoc.data()!;
          final childrenIds = List<String>.from(userData['children'] ?? []);
          final structureId = userData['structureId'];
          
          if (childrenIds.isEmpty || structureId == null) {
            return [];
          }
          
          // Récupérer les informations des enfants
          List<Map<String, dynamic>> children = [];
          
          for (final childId in childrenIds) {
            final childDoc = await _firestore
                .collection('structures')
                .doc(structureId)
                .collection('children')
                .doc(childId)
                .get();
                
            if (childDoc.exists) {
              final data = childDoc.data()!;
              children.add({
                'id': childDoc.id,
                'firstName': data['firstName'] ?? 'Sans nom',
                'lastName': data['lastName'] ?? '',
                'photoUrl': data['photoUrl'],
                'structureId': structureId,
                // Autres informations pertinentes...
              });
            }
          }
          
          return children;
          
        case UserRole.unknown:
        default:
          return [];
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des enfants: $e');
      return [];
    }
  }
  
  /// Efface le cache de rôle utilisateur
  static void clearCache() {
    _cachedRole = null;
    _cachedUserId = null;
  }
}