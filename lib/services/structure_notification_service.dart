import 'package:cloud_firestore/cloud_firestore.dart';

/// Gestion centralisée des notifications structurelles stockées dans Firestore.
class StructureNotificationService {
  const StructureNotificationService._();

  /// Retourne la collection des notifications pour une structure donnée.
  static CollectionReference<Map<String, dynamic>> collection(
    String structureId,
  ) {
    return FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('notifications');
  }

  /// Publie une nouvelle notification pour toute la structure.
  static Future<void> publish({
    required String structureId,
    required String title,
    required String body,
    String? createdBy,
    DateTime? createdAt,
    Map<String, dynamic>? extra,
  }) async {
    final now = createdAt ?? DateTime.now();
    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'createdAt': Timestamp.fromDate(now),
      'createdBy': createdBy,
      'readBy': <String>[],
      if (extra != null) ...extra,
    };

    await collection(structureId).add(payload);
  }

  /// Diffuse une notification à toutes les structures enregistrées.
  static Future<void> broadcast({
    required String title,
    required String body,
    String? createdBy,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final structuresSnap = await firestore.collection('structures').get();
    if (structuresSnap.docs.isEmpty) return;

    final timestamp = DateTime.now();
    for (final doc in structuresSnap.docs) {
      final sid = doc.id;
      if (sid.isEmpty) continue;
      await publish(
        structureId: sid,
        title: title,
        body: body,
        createdBy: createdBy,
        createdAt: timestamp,
      );
    }
  }

  /// Marque la notification comme lue par un utilisateur (email ou UID).
  static Future<void> markAsRead({
    required String structureId,
    required String notificationId,
    required String readerId,
  }) async {
    if (readerId.isEmpty) return;
    await collection(structureId).doc(notificationId).set(
      {
        'readBy': FieldValue.arrayUnion([readerId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
