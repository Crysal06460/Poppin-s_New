import 'package:cloud_firestore/cloud_firestore.dart';

class Delegation {
  final String id;
  final String structureId; // MAM/structure ID
  final String childId;
  final String amOriginId; // Assistante d'origine (UID membre)
  final String amDelegateId; // Assistante déléguée (UID membre)
  final DateTime date; // Délégation à la journée
  final String status; // proposed, accepted, declined, canceled, completed
  final String? reason;
  final String createdBy;
  final String? acceptedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Delegation({
    required this.id,
    required this.structureId,
    required this.childId,
    required this.amOriginId,
    required this.amDelegateId,
    required this.date,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.reason,
    this.acceptedBy,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'structureId': structureId,
      'childId': childId,
      'amOriginId': amOriginId,
      'amDelegateId': amDelegateId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'status': status,
      'reason': reason,
      'createdBy': createdBy,
      'acceptedBy': acceptedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Delegation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Delegation(
      id: doc.id,
      structureId: data['structureId'] ?? '',
      childId: data['childId'] ?? '',
      amOriginId: data['amOriginId'] ?? '',
      amDelegateId: data['amDelegateId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      status: data['status'] ?? 'proposed',
      reason: data['reason'],
      createdBy: data['createdBy'] ?? '',
      acceptedBy: data['acceptedBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

