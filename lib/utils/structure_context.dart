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
    this.userRole,
    Map<String, dynamic>? userData,
  }) : userData = Map.unmodifiable(userData ?? const {});

  final String structureId;
  final String structureName;
  final String structureType;
  final String normalizedStructureType;
  final Map<String, dynamic> structureData;
  final String currentUserEmail;
  final String? userRole;
  final Map<String, dynamic> userData;

  bool get isMam => normalizedStructureType == 'mam';
  bool get isParentEmployer =>
      normalizedStructureType == 'parent_employeur' ||
      normalizedStructureType == 'parentemployeur';

  bool get isAssistantStructure =>
      !isMam && !isParentEmployer; // default assistante maternelle
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

    final structureDoc =
        await _firestore.collection('structures').doc(structureId).get();
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

    return StructureContext(
      structureId: structureId,
      structureName: structureName,
      structureType: structureTypeRaw,
      normalizedStructureType: normalizedType,
      structureData: structureData,
      currentUserEmail: currentUserEmail,
      userRole: role,
      userData: userData,
    );
  }
}
