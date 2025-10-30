import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrialStatus {
  TrialStatus({
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.totalDays,
  });

  final String status;
  final DateTime? startAt;
  final DateTime? endAt;
  final int totalDays;

  bool get hasStarted => startAt != null && endAt != null;

  bool get isActive {
    if (!hasStarted) return false;
    if (endAt!.isBefore(DateTime.now())) return false;
    if (status.toLowerCase() != 'trial' && status.toLowerCase() != 'active') {
      return false;
    }
    return true;
  }

  bool get isExpired {
    if (!hasStarted) return false;
    if (endAt!.isAfter(DateTime.now())) return false;
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'expired' || lowerStatus == 'cancelled') return true;
    if (lowerStatus == 'trial' || lowerStatus == 'trialing') {
      return !isActive;
    }
    return false;
  }

  int get daysRemaining {
    if (!hasStarted || endAt == null) return 0;
    if (endAt!.isBefore(DateTime.now())) return 0;
    final difference = endAt!.difference(DateTime.now());
    return (difference.inHours / 24).ceil();
  }

  int get daysElapsed {
    if (!hasStarted || startAt == null) return 0;
    final now = DateTime.now();
    if (now.isBefore(startAt!)) return 0;
    final elapsed = now.difference(startAt!);
    return elapsed.inDays;
  }

  String get normalizedStatus {
    if (isActive) return 'trial';
    if (isExpired) return 'expired';
    return status.toLowerCase();
  }

  static TrialStatus empty() {
    return TrialStatus(
      status: 'none',
      startAt: null,
      endAt: null,
      totalDays: 0,
    );
  }

  static TrialStatus fromStructureData(Map<String, dynamic> data) {
    final String status =
        (data['trialStatus'] ?? data['subscriptionStatus'] ?? 'none')
            .toString();
    final DateTime? startAt = _extractDateTime(
          data['trialStartAt'] ??
              data['subscriptionTrialStartsAt'] ??
              data['trialStartedAt'],
        ) ??
        _extractDateTime(data['trialStartedAt']);
    final DateTime? endAt = _extractDateTime(
          data['trialEndsAt'] ??
              data['subscriptionTrialEndsAt'] ??
              data['subscriptionExpiresAt'],
        ) ??
        _extractDateTime(data['trialEndsAt']);
    final int totalDays = data['trialDurationDays'] is int
        ? data['trialDurationDays'] as int
        : (startAt != null && endAt != null
            ? endAt.difference(startAt).inDays
            : 0);
    return TrialStatus(
      status: status,
      startAt: startAt,
      endAt: endAt,
      totalDays: totalDays,
    );
  }

  static TrialStatus fromSubscriptionDoc(Map<String, dynamic> data) {
    final String status = (data['status'] ?? 'none').toString();
    final DateTime? startAt = _extractDateTime(
      data['trialStartedAt'] ?? data['trialStartAt'],
    );
    final DateTime? endAt =
        _extractDateTime(data['trialEndsAt'] ?? data['expirationDate']);
    final int totalDays = data['trialDurationDays'] is int
        ? data['trialDurationDays'] as int
        : (startAt != null && endAt != null
            ? endAt.difference(startAt).inDays
            : 0);
    return TrialStatus(
      status: status,
      startAt: startAt,
      endAt: endAt,
      totalDays: totalDays,
    );
  }

  static DateTime? _extractDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class FirebaseTrialService {
  FirebaseTrialService._();

  static const int defaultTrialDays = 7;
  static const String trialPlatform = 'firebase_trial';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<TrialStatus> ensureTrialForCurrentUser({
    int? trialDays,
    String? structureType,
    int? mamMemberCount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return TrialStatus.empty();
    }
    return ensureTrialForStructure(
      structureId: user.uid,
      ownerEmail: user.email,
      structureType: structureType,
      mamMemberCount: mamMemberCount,
      trialDays: trialDays,
    );
  }

  static Future<TrialStatus> ensureTrialForStructure({
    required String structureId,
    String? structureType,
    String? ownerEmail,
    int? mamMemberCount,
    int? trialDays,
  }) async {
    final structureRef = _firestore.collection('structures').doc(structureId);
    final structureSnap = await structureRef.get();
    final Map<String, dynamic> existingData =
        structureSnap.data() ?? <String, dynamic>{};

    final existingTrial = TrialStatus.fromStructureData(existingData);
    final String existingStatus =
        (existingData['subscriptionStatus'] ?? '').toString().toLowerCase();

    if (existingStatus == 'active' || existingStatus == 'purchased') {
      return TrialStatus(
        status: existingStatus,
        startAt: existingTrial.startAt,
        endAt: existingTrial.endAt,
        totalDays: existingTrial.totalDays,
      );
    }

    if (existingTrial.isActive) {
      return existingTrial;
    }

    if (existingTrial.hasStarted) {
      return existingTrial;
    }

    final int duration = trialDays ?? defaultTrialDays;
    final DateTime startDate = DateTime.now();
    final DateTime endDate = startDate.add(Duration(days: duration));
    final Timestamp startTimestamp = Timestamp.fromDate(startDate);
    final Timestamp endTimestamp = Timestamp.fromDate(endDate);

    final WriteBatch batch = _firestore.batch();
    final Map<String, dynamic> structureUpdates = {
      'subscriptionStatus': 'trial',
      'subscriptionActive': true,
      'subscriptionPlatform': trialPlatform,
      'subscriptionSource': trialPlatform,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      'trialStatus': 'trial',
      'trialDurationDays': duration,
      'trialStartAt': startTimestamp,
      'trialEndsAt': endTimestamp,
      'subscriptionTrialStartsAt': startTimestamp,
      'subscriptionTrialEndsAt': endTimestamp,
    };

    if (structureType != null && structureType.isNotEmpty) {
      structureUpdates['structureType'] = structureType;
    }

    if (ownerEmail != null && ownerEmail.isNotEmpty) {
      structureUpdates['ownerEmail'] = ownerEmail.toLowerCase();
    }

    batch.set(
      structureRef,
      structureUpdates,
      SetOptions(merge: true),
    );

    final subscriptionRef =
        _firestore.collection('subscriptions').doc(structureId);
    final subscriptionSnap = await subscriptionRef.get();

    final Map<String, dynamic> subscriptionUpdates = {
      'structureId': structureId,
      'status': 'trial',
      'isTrialPeriod': true,
      'platform': trialPlatform,
      'source': trialPlatform,
      'trialStartedAt': startTimestamp,
      'trialEndsAt': endTimestamp,
      'trialDurationDays': duration,
      'memberCount': mamMemberCount ??
          existingData['memberCount'] ??
          existingData['maxMemberCount'] ??
          1,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final dynamic existingStructureType =
        structureType ?? existingData['structureType'];
    if (existingStructureType != null &&
        existingStructureType.toString().isNotEmpty) {
      subscriptionUpdates['structureType'] = existingStructureType;
    }

    if (!subscriptionSnap.exists) {
      subscriptionUpdates['createdAt'] = FieldValue.serverTimestamp();
    }

    batch.set(
      subscriptionRef,
      subscriptionUpdates,
      SetOptions(merge: true),
    );

    await batch.commit();

    return TrialStatus(
      status: 'trial',
      startAt: startDate,
      endAt: endDate,
      totalDays: duration,
    );
  }

  static Future<TrialStatus> fetchTrialStatus(String structureId) async {
    final structureSnapshot =
        await _firestore.collection('structures').doc(structureId).get();
    if (structureSnapshot.exists) {
      final status =
          TrialStatus.fromStructureData(structureSnapshot.data() ?? {});
      if (status.hasStarted) {
        return status;
      }
    }

    final subscriptionSnapshot =
        await _firestore.collection('subscriptions').doc(structureId).get();
    if (subscriptionSnapshot.exists) {
      return TrialStatus.fromSubscriptionDoc(subscriptionSnapshot.data() ?? {});
    }

    return TrialStatus.empty();
  }

  static Future<TrialStatus> fetchTrialStatusForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return TrialStatus.empty();
    }
    return fetchTrialStatus(user.uid);
  }

  static Future<void> markTrialExpired(String structureId) async {
    final WriteBatch batch = _firestore.batch();
    final structureRef = _firestore.collection('structures').doc(structureId);
    final subscriptionRef =
        _firestore.collection('subscriptions').doc(structureId);

    batch.set(
      structureRef,
      {
        'subscriptionStatus': 'expired',
        'subscriptionActive': false,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
        'trialStatus': 'expired',
        'trialEndedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      subscriptionRef,
      {
        'status': 'expired',
        'isTrialPeriod': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  static Future<void> markTrialExpiredForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await markTrialExpired(user.uid);
  }
}
