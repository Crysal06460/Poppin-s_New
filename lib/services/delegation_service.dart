import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:poppins_app/models/delegation_model.dart';

class DelegationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> getCurrentStructureId() async {
    final user = _auth.currentUser;
    if (user == null) return '';

    final userDoc = await _firestore
        .collection('users')
        .doc(user.email?.toLowerCase() ?? '')
        .get();

    if (userDoc.exists &&
        userDoc.data() != null &&
        userDoc.data()!.containsKey('structureId')) {
      return userDoc.data()!['structureId'];
    }
    return user.uid;
  }

  Future<List<Delegation>> getDelegationsForDay(DateTime day) async {
    final structureId = await getCurrentStructureId();
    if (structureId.isEmpty) return [];
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('structures')
        .doc(structureId)
        .collection('delegations')
        .where('status', isEqualTo: 'accepted')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    return snapshot.docs
        .map((d) => Delegation.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  Future<List<Delegation>> getPendingForMe(DateTime day) async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final structureId = await getCurrentStructureId();
    if (structureId.isEmpty) return [];
    final myMemberId = await _resolveMyMemberId(structureId);
    if (myMemberId == null) return [];
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final snapshot = await _firestore
        .collection('structures')
        .doc(structureId)
        .collection('delegations')
        .where('status', isEqualTo: 'proposed')
        .where('amDelegateId', isEqualTo: myMemberId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snapshot.docs
        .map((d) => Delegation.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  Future<List<Delegation>> getAcceptedForMe(DateTime day) async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final structureId = await getCurrentStructureId();
    if (structureId.isEmpty) return [];
    final myMemberId = await _resolveMyMemberId(structureId);
    if (myMemberId == null) return [];
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final snapshot = await _firestore
        .collection('structures')
        .doc(structureId)
        .collection('delegations')
        .where('status', isEqualTo: 'accepted')
        .where('amDelegateId', isEqualTo: myMemberId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snapshot.docs
        .map((d) => Delegation.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
  }

  Future<String?> proposeDelegation({
    required String childId,
    required String amDelegateId,
    required DateTime date,
    String? reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final structureId = await getCurrentStructureId();
    final myMemberId = await _resolveMyMemberId(structureId);
    if (myMemberId == null) return null;
    final data = {
      'structureId': structureId,
      'childId': childId,
      // Stocker les IDs de membre (cohérents avec gardes)
      'amOriginId': myMemberId,
      'amDelegateId': amDelegateId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'status': 'proposed',
      'reason': reason,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore
        .collection('structures')
        .doc(structureId)
        .collection('delegations')
        .add(data);
    return docRef.id;
  }

  Future<bool> acceptDelegation(String delegationId) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('acceptDelegation');
      final structureId = await getCurrentStructureId();
      final res = await callable.call({'delegationId': delegationId, 'structureId': structureId});
      return res.data == true || res.data['success'] == true;
    } catch (e) {
      // Fallback client-side (sans garantie transactionnelle)
      try {
        final structureId = await getCurrentStructureId();
        await _firestore
            .collection('structures')
            .doc(structureId)
            .collection('delegations')
            .doc(delegationId)
            .update({
          'status': 'accepted',
          'acceptedBy': _auth.currentUser?.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> declineDelegation(String delegationId) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('declineDelegation');
      final structureId = await getCurrentStructureId();
      final res = await callable.call({'delegationId': delegationId, 'structureId': structureId});
      return res.data == true || res.data['success'] == true;
    } catch (e) {
      try {
        final structureId = await getCurrentStructureId();
        await _firestore
            .collection('structures')
            .doc(structureId)
            .collection('delegations')
            .doc(delegationId)
            .update({
          'status': 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> cancelDelegation(String delegationId) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('cancelDelegation');
      final structureId = await getCurrentStructureId();
      final res = await callable.call({'delegationId': delegationId, 'structureId': structureId});
      return res.data == true || res.data['success'] == true;
    } catch (e) {
      try {
        final structureId = await getCurrentStructureId();
        await _firestore
            .collection('structures')
            .doc(structureId)
            .collection('delegations')
            .doc(delegationId)
            .update({
          'status': 'canceled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // Trouver l'ID de membre du user courant dans la MAM
  Future<String?> _resolveMyMemberId(String structureId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final email = (user.email ?? '').toLowerCase();
      // 1) match par email
      if (email.isNotEmpty) {
        final byEmail = await _firestore
            .collection('structures')
            .doc(structureId)
            .collection('members')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) return byEmail.docs.first.id;
      }
      // 2) match par id == uid
      final byId = await _firestore
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .doc(user.uid)
          .get();
      if (byId.exists) return byId.id;
    } catch (_) {}
    return null;
  }
}
