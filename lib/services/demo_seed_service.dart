import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../utils/demo_firestore.dart';

class DemoSeedService {
  DemoSeedService._();

  static const String _demoStructureId = 'demo';
  static const String _demoTenant = 'DEMO';

  static const Map<String, Map<String, List<Map<String, String>>>>
      _demoSchedules = {
    'demo-child-alex': {
      'Lundi': [
        {'start': '08:15', 'end': '17:15'},
      ],
      'Mardi': [
        {'start': '08:30', 'end': '17:00'},
      ],
      'Mercredi': [
        {'start': '08:45', 'end': '16:30'},
      ],
      'Jeudi': [
        {'start': '09:00', 'end': '16:45'},
      ],
      'Vendredi': [
        {'start': '08:30', 'end': '16:15'},
      ],
    },
    'demo-child-zoe': {
      'Lundi': [
        {'start': '09:00', 'end': '17:30'},
      ],
      'Mardi': [
        {'start': '09:15', 'end': '17:00'},
      ],
      'Jeudi': [
        {'start': '09:30', 'end': '16:45'},
      ],
      'Vendredi': [
        {'start': '09:00', 'end': '16:30'},
      ],
    },
  };

  static Map<String, dynamic> defaultScheduleForChild(String childId) {
    final base =
        _demoSchedules[childId] ?? _demoSchedules['demo-child-alex']!;
    return base.map(
      (day, segments) => MapEntry(
        day,
        segments.map((seg) => Map<String, String>.from(seg)).toList(),
      ),
    );
  }

  static Future<void> ensureSeedData(User user) async {
    final firestore = FirebaseFirestore.instance;
    final structureRef =
        firestore.collection('structures').doc(_demoStructureId);

    final structureDoc = await structureRef.get();

    final batch = firestore.batch();
    final now = DateTime.now();

    final DateTime expiresAt = now.add(const Duration(hours: 3));

    final structureData = <String, dynamic>{
      'structureId': _demoStructureId,
      'structureName': "Poppin's Demo",
      'structureType': 'AssistanteMaternelle',
      'ownerUid': user.uid,
      'ownerEmail': user.email ?? '',
      'maxMemberCount': 3,
      'currentMemberCount': 2,
      'subscriptionStatus': 'trial',
      'subscriptionActive': true,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      'subscriptionExpiresAt': Timestamp.fromDate(expiresAt),
      'timezone': 'Europe/Paris',
      'showAllChildrenOnHome': true,
      'showDashboardNews': true,
    }.withDemoStamp(structureId: _demoStructureId, force: true);

    if (!structureDoc.exists) {
      structureData['createdAt'] = FieldValue.serverTimestamp();
    }

    batch.set(structureRef, structureData, SetOptions(merge: true));

    final memberRef =
        structureRef.collection('members').doc('member-assistante-demo');
    final memberData = <String, dynamic>{
      'email': (user.email ?? '').toLowerCase(),
      'name': "Démo Assistante",
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }.withDemoStamp(structureId: _demoStructureId, force: true);
    batch.set(memberRef, memberData, SetOptions(merge: true));

    Map<String, dynamic> _buildChildSeed({
      required String id,
      required String firstName,
      required String lastName,
      required String gender,
      required DateTime birthDate,
      String? allergies,
    }) {
      final schedule = defaultScheduleForChild(id);
      Map<String, dynamic> childData = {
        'firstName': firstName,
        'lastName': lastName,
        'birthdate': Timestamp.fromDate(birthDate),
        'gender': gender,
        'photoUrl': null,
        'status': 'present',
        'allergies': allergies ?? '',
        'structureId': _demoStructureId,
        'createdAt': FieldValue.serverTimestamp(),
        'assignedMemberEmail': (user.email ?? '').toLowerCase(),
        'schedule': schedule,
        'careDays': schedule.keys.toList(),
        'notes': 'Données de démonstration',
      };

      childData = childData.withDemoStamp(
        structureId: _demoStructureId,
        force: true,
      );

      return {
        'id': id,
        'firstName': firstName,
        'data': childData,
        'schedule': schedule,
      };
    }

    final childSeeds = [
      _buildChildSeed(
        id: 'demo-child-alex',
        firstName: 'Alex',
        lastName: 'Martin',
        gender: 'boy',
        birthDate: DateTime(now.year - 2, now.month, 15),
        allergies: 'Aucune',
      ),
      _buildChildSeed(
        id: 'demo-child-zoe',
        firstName: 'Zoé',
        lastName: 'Durand',
        gender: 'girl',
        birthDate: DateTime(now.year - 3, now.month - 1, 4),
        allergies: 'Intolérance lactose',
      ),
    ];

    for (final seed in childSeeds) {
      final childRef =
          structureRef.collection('children').doc(seed['id'] as String);
      batch.set(
        childRef,
        seed['data'] as Map<String, dynamic>,
        SetOptions(merge: true),
      );
    }

    DateTime _combine(DateTime base, String hhmm) {
      final parts = hhmm.split(':');
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateTime(base.year, base.month, base.day, hour, minute);
    }

    final horairesCollection = structureRef.collection('horaires');
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final List<DateTime> seedDates = List.generate(
      7,
      (index) => DateTime(now.year, now.month, now.day - 2 + index),
    );

    for (final date in seedDates) {
      final String docId = dateFormatter.format(date);
      final Map<String, dynamic> docData = {
        'structureId': _demoStructureId,
        'generatedAt': FieldValue.serverTimestamp(),
      };

      final dayLabel = DateFormat('EEEE', 'fr_FR').format(date);
      final capitalizedDay =
          dayLabel[0].toUpperCase() + dayLabel.substring(1).toLowerCase();

      for (final seed in childSeeds) {
        final String childId = seed['id'] as String;
        final String firstName = seed['firstName'] as String;
        final schedule = seed['schedule'] as Map<String, dynamic>;

        Map<String, dynamic>? daySegments;
        if (schedule.containsKey(capitalizedDay)) {
          final segments = schedule[capitalizedDay];
          if (segments is List && segments.isNotEmpty) {
            daySegments = Map<String, dynamic>.from(segments.first);
          }
        }
        if (daySegments == null) {
          final fallback = schedule.values.first as List;
          daySegments = Map<String, dynamic>.from(fallback.first);
        }

        final String plannedStart = (daySegments['start'] ?? '08:30').toString();
        final String plannedEnd = (daySegments['end'] ?? '17:00').toString();

        final arrivalTime = _combine(date, plannedStart);
        final departureTime = _combine(date, plannedEnd);

        final arrivalStr = DateFormat('HH:mm').format(arrivalTime);
        final departureStr = DateFormat('HH:mm').format(departureTime);

        docData[childId] = {
          'actionType': 'present',
          'arrivee': arrivalStr,
          'depart': departureStr,
          'prenom': firstName,
          'segments': [
            {
              'index': 0,
              'arrivee': arrivalStr,
              'depart': departureStr,
              'heureDebut': plannedStart,
              'heureFin': plannedEnd,
            }
          ],
          'km': childId == 'demo-child-alex' ? 6 : 4,
          'exactTime': Timestamp.fromDate(arrivalTime),
        };
      }

      final payload = docData.withDemoStamp(
        structureId: _demoStructureId,
        force: true,
      );
      batch.set(
        horairesCollection.doc(docId),
        payload,
        SetOptions(merge: true),
      );
    }

    final subscriptionRef =
        firestore.collection('subscriptions').doc(_demoStructureId);
    final subscriptionData = <String, dynamic>{
      'structureId': _demoStructureId,
      'status': 'trial',
      'plan': 'demo',
      'billingPlatform': 'internal',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'validUntil': Timestamp.fromDate(expiresAt),
      'active': true,
    }.withDemoStamp(structureId: _demoStructureId, force: true);
    batch.set(subscriptionRef, subscriptionData, SetOptions(merge: true));

    final seedInfoRef =
        firestore.collection('demo_sessions').doc('seed-info');
    batch.set(
      seedInfoRef,
      <String, dynamic>{
        'seededAt': FieldValue.serverTimestamp(),
        'tenant_id': _demoTenant,
        'is_demo': true,
      }.withDemoStamp(structureId: _demoStructureId, force: true),
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
