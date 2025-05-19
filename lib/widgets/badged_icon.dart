import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BadgedIcon extends StatelessWidget {
  final IconData icon;
  final bool showBadge;
  final Color iconColor;
  final double size;

  const BadgedIcon({
    Key? key,
    required this.icon,
    required this.showBadge,
    required this.iconColor,
    this.size = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ajouter un print pour déboguer
    print("BadgedIcon construit avec showBadge = $showBadge");
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: iconColor, size: size),
        if (showBadge)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class BadgedMessageIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double size;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  BadgedMessageIcon({
    Key? key,
    required this.icon,
    required this.iconColor,
    this.size = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      // Récupérer d'abord les IDs des enfants
      future: _getChildrenIds(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return Icon(icon, color: iconColor, size: size);
        }
        
        // Une fois les IDs récupérés, utiliser StreamBuilder
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('exchanges')
              .where('childId', whereIn: snapshot.data)
              .where('senderType', isEqualTo: 'staff')
              .where('nonLu', isEqualTo: true)
              .snapshots(),
          builder: (context, querySnapshot) {
            final showBadge = querySnapshot.hasData && querySnapshot.data!.docs.isNotEmpty;
            print("BadgedMessageIcon: showBadge = $showBadge, documents = ${querySnapshot.data?.docs.length ?? 0}, childIds = ${snapshot.data}");
            
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: iconColor, size: size),
                if (showBadge)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
  
  Future<List<String>> _getChildrenIds() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];
      
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get();
          
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return List<String>.from(userData['children'] ?? []);
      }
      return [];
    } catch (e) {
      print("Erreur lors de la récupération des IDs des enfants: $e");
      return [];
    }
  }
}