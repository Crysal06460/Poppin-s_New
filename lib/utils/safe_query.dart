import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides resilient Firestore streams that prefer server-side ordering
/// when the composite index exists, and gracefully fall back to
/// client-side sorting if not available.
class SafeQuery {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // Cache per childId whether the indexed query is available
  static final Map<String, bool> _indexedOkCache = {};

  /// Returns an exchanges stream for a child.
  /// If [lastOnly] is true, the stream is limited to the last message when
  /// the index exists; otherwise it returns the full stream for client-side picking.
  static Future<Stream<QuerySnapshot>> exchangesStream(
    String childId, {
    bool lastOnly = false,
  }) async {
    final canUseIndexed = await _canUseIndexedQuery(childId);
    final base = _fs.collection('exchanges').where('childId', isEqualTo: childId);

    if (canUseIndexed) {
      final q = base.orderBy('timestamp', descending: true);
      return lastOnly ? q.limit(1).snapshots() : q.snapshots();
    }

    // Fallback: no server-side ordering to avoid index errors
    // The caller should sort client-side when needed
    return base.snapshots();
  }

  /// Quick probe to determine if the composite index for (childId eq, orderBy timestamp)
  /// is available. Caches result per childId.
  static Future<bool> _canUseIndexedQuery(String childId) async {
    if (_indexedOkCache.containsKey(childId)) {
      return _indexedOkCache[childId] == true;
    }

    try {
      // Probe with a tiny get; if the index is missing, Firestore throws failed-precondition
      await _fs
          .collection('exchanges')
          .where('childId', isEqualTo: childId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      _indexedOkCache[childId] = true;
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Composite index not ready or missing
        _indexedOkCache[childId] = false;
        return false;
      }
      // Any other error: be conservative and fallback
      _indexedOkCache[childId] = false;
      return false;
    } catch (_) {
      _indexedOkCache[childId] = false;
      return false;
    }
  }
}

