import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StructureContext {
  StructureContext({
    required this.structureId,
    required this.structureName,
    required this.structureType,
    required this.normalizedStructureType,
    required this.structureData,
    required this.currentUserEmail,
    required this.showAllChildren,
    this.userRole,
    Map<String, dynamic>? userData,
  }) : userData = Map.unmodifiable(userData ?? const {});

  final String structureId;
  final String structureName;
  final String structureType;
  final String normalizedStructureType;
  final Map<String, dynamic> structureData;
  final String currentUserEmail;
  final bool showAllChildren;
  final String? userRole;
  final Map<String, dynamic> userData;

  bool get isMam => normalizedStructureType == 'mam';
  bool get isParentEmployer =>
      normalizedStructureType == 'parent_employeur' ||
      normalizedStructureType == 'parentemployeur';

  bool get isAssistantStructure =>
      !isMam && !isParentEmployer; // default assistante maternelle

  bool get canManageAllStructureChildren =>
      isMam && showAllChildren;
}

class StructureResolver {
  StructureResolver({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<StructureContext> resolve() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Aucun utilisateur connecté.');
    }

    final String currentUserEmail = user.email?.toLowerCase().trim() ?? '';
    Map<String, dynamic> userData = const {};
    String structureId = user.uid;
    String? role;

    if (currentUserEmail.isNotEmpty) {
      final userDoc =
          await _firestore.collection('users').doc(currentUserEmail).get();
      if (userDoc.exists) {
        userData = userDoc.data() ?? const {};
        role = (userData['role'] ?? '').toString();
        final String linkedStructureId =
            (userData['structureId'] ?? '').toString().trim();
        final String normalizedRole = role.toLowerCase().trim();

        if (linkedStructureId.isNotEmpty &&
            (normalizedRole == 'mammember' ||
                normalizedRole == 'assistantfromparent' ||
                normalizedRole == 'assistant' ||
                normalizedRole == 'parent' ||
                normalizedRole == 'parent_employeur' ||
                normalizedRole == 'parentemployeur')) {
          structureId = linkedStructureId;
        }
      }
    }

    DocumentSnapshot<Map<String, dynamic>> structureDoc =
        await _firestore.collection('structures').doc(structureId).get();

    if (!structureDoc.exists && currentUserEmail.isNotEmpty) {
      String? fallbackStructureId;

      final emailQuery = await _firestore
          .collection('structures')
          .where('email', isEqualTo: currentUserEmail)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        fallbackStructureId = emailQuery.docs.first.id;
      } else {
        final ownerEmailQuery = await _firestore
            .collection('structures')
            .where('ownerEmail', isEqualTo: currentUserEmail)
            .limit(1)
            .get();

        if (ownerEmailQuery.docs.isNotEmpty) {
          fallbackStructureId = ownerEmailQuery.docs.first.id;
        }
      }

      if (fallbackStructureId == null) {
        final ownerUidQuery = await _firestore
            .collection('structures')
            .where('ownerUid', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (ownerUidQuery.docs.isNotEmpty) {
          fallbackStructureId = ownerUidQuery.docs.first.id;
        }
      }

      if (fallbackStructureId != null && fallbackStructureId.isNotEmpty) {
        structureId = fallbackStructureId;
        structureDoc =
            await _firestore.collection('structures').doc(structureId).get();

        if (structureDoc.exists) {
          await _firestore
              .collection('users')
              .doc(currentUserEmail)
              .set({'structureId': structureId}, SetOptions(merge: true));
          userData = Map<String, dynamic>.from(userData);
          userData['structureId'] = structureId;
        }
      }
    }

    if (!structureDoc.exists) {
      throw StateError('Structure introuvable pour l\'ID $structureId');
    }

    final Map<String, dynamic> structureData =
        structureDoc.data() ?? <String, dynamic>{};

    String structureTypeRaw =
        (structureData['structureType'] ?? 'AssistanteMaternelle').toString();
    String normalizedType = structureTypeRaw.toLowerCase().trim();

    String structureName = (structureData['structureName'] ??
            structureData['ownerFirstName'] ??
            structureData['firstName'] ??
            '')
        .toString()
        .trim();

    if (structureName.isEmpty) {
      final ownerFirstName = (structureData['ownerFirstName'] ?? '').toString();
      final ownerLastName = (structureData['ownerLastName'] ?? '').toString();
      final combined = '$ownerFirstName $ownerLastName'.trim();
      if (combined.isNotEmpty) {
        structureName = combined;
      }
    }

    if (structureName.isEmpty) {
      structureName = 'Ma Structure';
    }

    if (!structureData.containsKey('structureType')) {
      await _firestore
          .collection('structures')
          .doc(structureId)
          .update({'structureType': structureTypeRaw});
    }

    final dynamic showAllField = structureData['showAllChildrenOnHome'];
    bool showAllChildrenPreference = true;
    if (showAllField is bool) {
      showAllChildrenPreference = showAllField;
    } else {
      await _firestore
          .collection('structures')
          .doc(structureId)
          .set({'showAllChildrenOnHome': true}, SetOptions(merge: true));
    }

    return StructureContext(
      structureId: structureId,
      structureName: structureName,
      structureType: structureTypeRaw,
      normalizedStructureType: normalizedType,
      structureData: structureData,
      currentUserEmail: currentUserEmail,
      showAllChildren: showAllChildrenPreference,
      userRole: role,
      userData: userData,
    );
  }
}
