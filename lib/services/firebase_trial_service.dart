import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionVerificationResult {
  final String? structureType;
  final int? maxMemberCount;
  final String? subscriptionId;
  final Map<String, dynamic>? rawData;

  SubscriptionVerificationResult({
    this.structureType,
    this.maxMemberCount,
    this.subscriptionId,
    this.rawData,
  });

  bool get isValid => structureType != null;
}

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
    final String normalized = status.toLowerCase();

    // Une fois converti en abonnement payant, on considère l'essai comme actif
    if (normalized == 'converted') {
      return true;
    }

    if (!hasStarted) return false;
    if (endAt!.isBefore(DateTime.now())) return false;
    if (normalized != 'trial' && normalized != 'active') {
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
    final String structureId = await _resolveStructureIdForCurrentUser(user);
    return fetchTrialStatus(structureId);
  }

  static Future<String> _resolveStructureIdForCurrentUser(User user) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.email?.toLowerCase() ?? user.uid)
          .get();
      final data = doc.data();
      final String? sid =
          data != null ? (data['structureId'] as String?)?.trim() : null;
      if (sid != null && sid.isNotEmpty) return sid;
    } catch (_) {}
    return user.uid;
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

  static Future<SubscriptionVerificationResult> verifySubscription({String? email, String? uid}) async {
    try {
      final String? resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
      final String? resolvedEmail = email?.trim().toLowerCase();

      final List<Map<String, dynamic>> candidates = [];

      if (resolvedUid != null && resolvedUid.isNotEmpty) {
        try {
          final subDoc = await _firestore
              .collection('subscriptions')
              .doc(resolvedUid)
              .get();
          final docData = subDoc.data();
          if (docData != null && docData.isNotEmpty) {
            candidates.add(docData);
          }
        } catch (_) {}
      }

      if (resolvedUid != null && resolvedUid.isNotEmpty) {
        try {
          final subQuery = await _firestore
              .collection('subscriptions')
              .where('structureId', isEqualTo: resolvedUid)
              .limit(1)
              .get();
          if (subQuery.docs.isNotEmpty) {
            candidates.add(subQuery.docs.first.data());
          }
        } catch (_) {}
      }

      if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
        try {
          final subQuery = await _firestore
              .collection('subscriptions')
              .where('email', isEqualTo: resolvedEmail)
              .limit(1)
              .get();
          if (subQuery.docs.isNotEmpty) {
            candidates.add(subQuery.docs.first.data());
          }
        } catch (_) {}
      }

      if (candidates.isEmpty) {
        print("🔍 Debug Subscription: Aucune donnée candidate trouvée.");
        return SubscriptionVerificationResult();
      }

      const Set<String> mamSmallPriceIds = {
        'price_1sfkuilid2pa5i1c75uu1tch',
        'price_1sflcbppvdnoe6wk9jqndswp',
      };
      const Set<String> mamLargePriceIds = {
        'price_1sfkwulid2pa5i1cmsdrrf0c',
        'price_1sflcjpgpvnoe6wkfd6blign',
        'price_1sflcjppvdnoe6wkfd6blign', // User Provided (MAM 4)
      };
      const Set<String> assmatPriceIds = {
        'price_1sfl7jppvdnoe6wk7rnj6pm3', // User Provided (Assmat)
      };
      
      Map<String, dynamic>? best;
      int bestScore = -1;

      print("🔍 Debug Subscription: ${candidates.length} candidat(s). Analyse...");

      for (final data in candidates) {
        final String rawStructureType =
            (data['structureType'] ?? '').toString().toLowerCase();
        final String productId =
            (data['productId'] ?? data['planId'] ?? '')
                .toString()
                .toLowerCase();
        final dynamic maxMembersRaw =
            data['maxMemberCount'] ?? data['memberCount'];
        int? maxMembers;
        if (maxMembersRaw is int) {
          maxMembers = maxMembersRaw;
        } else if (maxMembersRaw is num) {
          maxMembers = maxMembersRaw.toInt();
        } else if (maxMembersRaw is String) {
          maxMembers = int.tryParse(maxMembersRaw);
        }

        int score = 0;
        if (mamLargePriceIds.contains(productId) ||
            mamSmallPriceIds.contains(productId) ||
            productId.contains('mam')) {
          score += 4;
        }
        if (assmatPriceIds.contains(productId) ||
            productId.contains('assistante_maternelle') ||
            productId.contains('assmat') ||
            productId == 'abonnement_assmat') {
          score += 3;
        }
        if (maxMembers != null && maxMembers > 1) {
          score += 2;
        }
        if (rawStructureType.contains('mam')) {
          score += 2;
        }
        if (rawStructureType.contains('assistante') ||
            rawStructureType.contains('assmat')) {
          score += 1;
        }

        if (score > bestScore) {
          bestScore = score;
          best = data;
        }
      }

      if (best == null) {
        print("🔍 Debug Subscription: Aucun meilleur candidat retenu.");
        return SubscriptionVerificationResult();
      }

      String? verifiedStructureType;
      int? verifiedMaxMembers;

      final String rawStructureType =
          (best['structureType'] ?? '').toString().toLowerCase();
      final String productId =
          (best['productId'] ?? best['planId'] ?? '')
              .toString()
              .toLowerCase();
      final dynamic maxMembersRaw =
          best['maxMemberCount'] ?? best['memberCount'];
      int? maxMembers;
      if (maxMembersRaw is int) {
        maxMembers = maxMembersRaw;
      } else if (maxMembersRaw is num) {
        maxMembers = maxMembersRaw.toInt();
      } else if (maxMembersRaw is String) {
        maxMembers = int.tryParse(maxMembersRaw);
      }

      bool explicitIdMatch = false;

      if (mamLargePriceIds.contains(productId)) {
        verifiedStructureType = 'MAM';
        verifiedMaxMembers = 50;
        explicitIdMatch = true;
      } else if (mamSmallPriceIds.contains(productId)) {
        verifiedStructureType = 'MAM';
        verifiedMaxMembers = 3; 
        explicitIdMatch = true;
      } else if (productId.contains('mam')) {
        verifiedStructureType = 'MAM';
      } else if (assmatPriceIds.contains(productId) || 
          productId.contains('assistante_maternelle') ||
          productId.contains('assmat') ||
          productId == 'abonnement_assmat') {
        verifiedStructureType = 'assistante_maternelle';
        verifiedMaxMembers = 1;
        explicitIdMatch = true;
      } else if (maxMembers != null && maxMembers > 1) {
        verifiedStructureType = 'MAM';
      } else if (rawStructureType.contains('mam')) {
        verifiedStructureType = 'MAM';
      } else if (rawStructureType.contains('assistante') ||
          rawStructureType.contains('assmat')) {
        verifiedStructureType = 'assistante_maternelle';
      }

      // AJUSTEMENT DES MEMBRES
      if (explicitIdMatch) {
         if (mamSmallPriceIds.contains(productId)) {
             if (productId == 'price_1sflcbppvdnoe6wk9jqndswp') {
                 verifiedMaxMembers = 2;
             } 
             else if (productId.contains('mam_2') || productId.contains('mam2')) {
                verifiedMaxMembers = 2;
             } 
             else if (maxMembers != null && maxMembers > 1) {
                verifiedMaxMembers = maxMembers; 
             } else {
                verifiedMaxMembers = 3;
             }
         }
      } 
      else if (maxMembers != null) {
        verifiedMaxMembers = maxMembers;
      } 
      else if (verifiedStructureType == 'MAM') {
        if (productId.contains('mam_2') || productId.contains('mam2')) {
          verifiedMaxMembers = 2;
        } else if (productId.contains('mam_3') || productId.contains('mam3')) {
          verifiedMaxMembers = 3;
        } else if (productId.contains('mam_4') || productId.contains('mam4')) {
          verifiedMaxMembers = 50;
        } else {
          verifiedMaxMembers = 3;
        }
      } else if (verifiedStructureType == 'assistante_maternelle') {
        verifiedMaxMembers = 1;
      }

      if (verifiedStructureType != null) {
        print(
            "🔒 Abonnement confirmé service: $verifiedStructureType ($verifiedMaxMembers membres).");
      }

      return SubscriptionVerificationResult(
        structureType: verifiedStructureType,
        maxMemberCount: verifiedMaxMembers,
        rawData: best,
      );

    } catch (e) {
      print("⚠️ Erreur vérification abonnement service: $e");
      return SubscriptionVerificationResult();
    }
  }
}
