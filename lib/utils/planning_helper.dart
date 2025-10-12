import 'package:cloud_firestore/cloud_firestore.dart';

import '../planning/planning_models.dart';
import '../planning/planning_repository.dart';
import '../planning/planning_resolver.dart';

class PlanningHelper {
  const PlanningHelper._();

  static const Map<String, Weekday> _frenchWeekdayMap = {
    'lundi': Weekday.mon,
    'mardi': Weekday.tue,
    'mercredi': Weekday.wed,
    'jeudi': Weekday.thu,
    'vendredi': Weekday.fri,
    'samedi': Weekday.sat,
    'dimanche': Weekday.sun,
  };

  static PlanningData? planningFromSnapshot(Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      var parsed = PlanningData.fromJson(data);
      switch (parsed.type) {
        case PlanningType.fixed:
          parsed = parsed.copyWith(
            clearAltWeeks: true,
            clearMonthly: true,
          );
          break;
        case PlanningType.altWeeks:
          parsed = parsed.copyWith(
            clearFixed: true,
            clearMonthly: true,
          );
          break;
        case PlanningType.monthly:
          parsed = parsed.copyWith(
            clearAltWeeks: true,
          );
          break;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static Weekday _weekdayFromKey(String raw) {
    final normalized = raw.toLowerCase().trim();
    if (_frenchWeekdayMap.containsKey(normalized)) {
      return _frenchWeekdayMap[normalized]!;
    }
    return Weekday.values.firstWhere(
      (w) => w.toKey() == normalized,
      orElse: () => Weekday.mon,
    );
  }

  static PlanningData? planningFromChild(Map<String, dynamic> child) {
    final planningField = child['planning'];
    if (planningField is Map<String, dynamic>) {
      final planning = planningFromSnapshot(planningField);
      if (planning != null) return planning;
    }

    final dotted = _extractPlanningFromDotted(child);
    if (dotted != null) {
      final planning = planningFromSnapshot(dotted);
      if (planning != null) return planning;
    }

    // Legacy fallback using weekly schedule.
    final legacy = child['schedule'];
    if (legacy is Map<String, dynamic>) {
      final days = <Weekday, List<TimeSlot>>{
        for (final weekday in Weekday.values) weekday: const <TimeSlot>[],
      };
      for (final entry in legacy.entries) {
        final weekday = _weekdayFromKey(entry.key.toString());
        if (entry.value is List) {
          days[weekday] = (entry.value as List)
              .whereType<Map<String, dynamic>>()
              .map(
                (e) => TimeSlot(
                  start: (e['start'] ?? e['arrival'] ?? '').toString(),
                  end: (e['end'] ?? e['departure'] ?? '').toString(),
                ),
              )
              .toList();
        }
      }
      return PlanningData(
        type: PlanningType.fixed,
        fixed: FixedSchema(days: days, exceptions: const <ExceptionDay>[]),
        timezone: 'Europe/Paris',
        updatedAt: DateTime.now(),
        updatedBy: 'legacy',
      );
    }
    return null;
  }

  static List<TimeSlot> resolveSlotsForDate(
    Map<String, dynamic> child,
    DateTime date,
  ) {
    final planning = planningFromChild(child);
    if (planning == null) {
      return const <TimeSlot>[];
    }
    print(
        '[PlanningHelper] resolved planning type: ${planning.type} for ${(child['id'] ?? child['firstName'] ?? 'unknown')}');
    print('[PlanningHelper] fixed slots for sun: '
        '${planning.fixed?.days[Weekday.sun]?.map((e) => '${e.start}-${e.end}').toList()}');
    print('[PlanningHelper] monthly months: ${planning.monthly?.months.keys}');
    return resolveDaySlots(date, planning);
  }

  static bool isScheduledForDate(
    Map<String, dynamic> child,
    DateTime date,
  ) {
    final planningMap = child['planning'];
    if (planningMap is Map<String, dynamic>) {
      final direct = _checkFixedSlotsDirectly(planningMap, date);
      if (direct != null) {
        return direct;
      }
    }
    return resolveSlotsForDate(child, date).isNotEmpty;
  }

  static Future<PlanningData?> fetchPlanning({
    required String structureId,
    required String childId,
    required String currentUserId,
    PlanningRepository? repository,
  }) {
    return (repository ?? PlanningRepository()).initOrLoad(
      structureId: structureId,
      childId: childId,
      updatedBy: currentUserId,
    );
  }

  static Future<void> attachPlanningToChildDoc({
    required String structureId,
    required String childId,
    required PlanningData planning,
    FirebaseFirestore? firestore,
  }) {
    return (firestore ?? FirebaseFirestore.instance)
        .collection('structures')
        .doc(structureId)
        .collection('children')
        .doc(childId)
        .set(
      {
        'planning': planning.toJson(),
        'planningType': planning.type.name,
        'planningUpdatedAt': planning.updatedAt.millisecondsSinceEpoch,
        'planningUpdatedBy': planning.updatedBy,
      },
      SetOptions(merge: true),
    );
  }

  static bool? _checkFixedSlotsDirectly(
    Map<String, dynamic> planning,
    DateTime date,
  ) {
    final type = planning['type']?.toString();
    if (type != PlanningType.fixed.name) {
      return null;
    }

    final fixed = planning['fixed'];
    if (fixed is! Map) return null;

    final exceptions = fixed['exceptions'];
    if (exceptions is List) {
      final iso = toIsoDate(date);
      for (final entry in exceptions) {
        if (entry is Map &&
            entry['dateIso']?.toString() == iso &&
            entry['slots'] is List) {
          return (entry['slots'] as List).isNotEmpty;
        }
      }
    }

    final days = fixed['days'];
    if (days is! Map) return null;
    final weekday = Weekday.fromDateTime(date).toKey();
    final rawSlots = days[weekday];
    if (rawSlots is List) {
      return rawSlots.isNotEmpty;
    }
    return null;
  }
}

Map<String, dynamic>? _extractPlanningFromDotted(
  Map<String, dynamic> child,
) {
  final type = child['planning.type'] ?? child['planningType'];
  final fixed = child['planning.fixed'];
  final altWeeks = child['planning.altWeeks'];
  final monthly = child['planning.monthly'];
  final timezone = child['planning.timezone'] ?? child['timezone'];
  final updatedAt = child['planning.updatedAt'] ?? child['planningUpdatedAt'];
  final updatedBy = child['planning.updatedBy'] ?? child['planningUpdatedBy'];

  if (type == null && fixed == null && altWeeks == null && monthly == null) {
    return null;
  }

  return {
    'type': type,
    if (timezone != null) 'timezone': timezone,
    if (updatedAt != null) 'updatedAt': updatedAt,
    if (updatedBy != null) 'updatedBy': updatedBy,
    'fixed': fixed,
    'altWeeks': altWeeks,
    'monthly': monthly,
  };
}
