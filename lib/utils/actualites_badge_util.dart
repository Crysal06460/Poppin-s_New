import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActualitesBadgeUtil {
  // Store last-seen timestamps (millis) instead of counts
  static const String _eventsKeyPrefix = 'actualites_last_events_seen_ts';
  static const String _sortiesKeyPrefix = 'actualites_last_sorties_seen_ts';

  static Future<String?> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final email = user.email?.toLowerCase();
    if (email == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .get();
    if (!userDoc.exists) return null;
    final data = userDoc.data();
    return data?['structureId'];
  }

  static String _eventsKey(String structureId, String userId) =>
      '${_eventsKeyPrefix}_${structureId}_$userId';
  static String _sortiesKey(String structureId, String userId) =>
      '${_sortiesKeyPrefix}_${structureId}_$userId';

  static Future<Map<String, int>> _fetchLatestTimestamps(
      String structureId) async {
    // Ne considérer que les actualités à venir (date >= aujourd'hui)
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    // Fetch latest event by date
    final eventsSnap = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('actualites')
        .doc('events')
        .collection('items')
        .where('date', isGreaterThanOrEqualTo: startOfToday)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    final sortiesSnap = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('actualites')
        .doc('sorties')
        .collection('items')
        .where('date', isGreaterThanOrEqualTo: startOfToday)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    int latestEventTs = 0;
    if (eventsSnap.docs.isNotEmpty) {
      final data = eventsSnap.docs.first.data();
      final ts = data['date'];
      if (ts is Timestamp) latestEventTs = ts.millisecondsSinceEpoch;
    }

    int latestSortieTs = 0;
    if (sortiesSnap.docs.isNotEmpty) {
      final data = sortiesSnap.docs.first.data();
      final ts = data['date'];
      if (ts is Timestamp) latestSortieTs = ts.millisecondsSinceEpoch;
    }

    return {
      'events': latestEventTs,
      'sorties': latestSortieTs,
    };
  }

  // Returns whether to show badges for events and sorties respectively
  static Future<Map<String, bool>> shouldShowBadges() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'events': false, 'sorties': false};
      final structureId = await _getStructureId();
      if (structureId == null) return {'events': false, 'sorties': false};

      return await shouldShowBadgesFor(structureId);
    } catch (e) {
      print('📰 ❌ Erreur shouldShowBadges Actualités: $e');
      return {'events': false, 'sorties': false};
    }
  }

  static Future<Map<String, bool>> shouldShowBadgesFor(String structureId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'events': false, 'sorties': false};

      final counts = await _fetchLatestTimestamps(structureId);
      final prefs = await SharedPreferences.getInstance();

      final lastEvents = prefs.getInt(_eventsKey(structureId, user.uid)) ?? 0;
      final lastSorties = prefs.getInt(_sortiesKey(structureId, user.uid)) ?? 0;

      final showEvents = counts['events']! > lastEvents && counts['events']! > 0;
      final showSorties = counts['sorties']! > lastSorties && counts['sorties']! > 0;

      print('📰 Badges check (timestamps) for $structureId → events: ${counts['events']} (last $lastEvents), sorties: ${counts['sorties']} (last $lastSorties)');

      return {'events': showEvents, 'sorties': showSorties};
    } catch (e) {
      print('📰 ❌ Erreur shouldShowBadgesFor Actualités: $e');
      return {'events': false, 'sorties': false};
    }
  }

  static Future<void> markEventsSeen({String? structureId}) async {
    await _markTypeSeen('events', structureId: structureId);
  }

  static Future<void> markSortiesSeen({String? structureId}) async {
    await _markTypeSeen('sorties', structureId: structureId);
  }

  static Future<void> markAllSeen({String? structureId}) async {
    await _markTypeSeen('events', structureId: structureId);
    await _markTypeSeen('sorties', structureId: structureId);
  }

  static Future<void> _markTypeSeen(String type, {String? structureId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final targetStructureId = structureId ?? await _getStructureId();
      if (targetStructureId == null) return;

      final latest = await _fetchLatestTimestamps(targetStructureId);
      final prefs = await SharedPreferences.getInstance();

      if (type == 'events') {
        await prefs.setInt(
            _eventsKey(targetStructureId, user.uid), latest['events'] ?? 0);
      } else if (type == 'sorties') {
        await prefs.setInt(
            _sortiesKey(targetStructureId, user.uid), latest['sorties'] ?? 0);
      }
    } catch (e) {
      print('📰 ❌ Erreur markTypeSeen($type): $e');
    }
  }
}
