import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'planning_models.dart';
import 'planning_resolver.dart';

class PlanningRepository {
  PlanningRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _childDoc(
    String structureId,
    String childId,
  ) {
    return _firestore
        .collection('structures')
        .doc(structureId)
        .collection('children')
        .doc(childId);
  }

  DocumentReference<Map<String, dynamic>> _defaultPlanningDoc(
    String structureId,
    String childId,
  ) {
    return _childDoc(structureId, childId).collection('planning').doc('default');
  }

  Future<PlanningData?> load({
    required String structureId,
    required String childId,
  }) async {
    final snapshot = await _defaultPlanningDoc(structureId, childId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;
    return PlanningData.fromJson(data);
  }

  Future<void> save({
    required String structureId,
    required String childId,
    required PlanningData planning,
  }) async {
    final docPayload = _preparePlanningDocument(planning);
    final childPayload = _prepareChildUpdateMap(planning);

    try {
      await _defaultPlanningDoc(structureId, childId).delete();
    } catch (_) {
      // ignore if doc doesn't exist yet
    }
    await _defaultPlanningDoc(structureId, childId).set(docPayload);

    try {
      await _childDoc(structureId, childId)
          .update({'planning': FieldValue.delete()});
    } catch (_) {
      // ignore if planning field missing
    }
    try {
      await _childDoc(structureId, childId).set(
        {'planning': FieldValue.delete()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // ignore if planning not present yet
    }
    await _childDoc(structureId, childId)
        .set(childPayload, SetOptions(merge: true));
    try {
      await _childDoc(structureId, childId)
          .set({'schedule': FieldValue.delete()}, SetOptions(merge: true));
    } catch (_) {
      // ignore deletion errors (legacy data may already be absent)
    }
  }

  /// Migration helper: build a [PlanningData] instance from legacy fields.
  Future<PlanningData> migrateLegacy({
    required String structureId,
    required String childId,
    required String updatedBy,
    String timezone = 'Europe/Paris',
  }) async {
    final doc = await _childDoc(structureId, childId).get();
    final data = doc.data();
    if (data == null) {
      return PlanningFactory.emptyFixed(
        timezone: timezone,
        updatedBy: updatedBy,
      );
    }

    final dynamic legacy = data['schedule'];
    if (legacy is! Map) {
      return PlanningFactory.emptyFixed(
        timezone: timezone,
        updatedBy: updatedBy,
      );
    }

    final days = <Weekday, List<TimeSlot>>{
      for (final weekday in Weekday.values) weekday: const <TimeSlot>[],
    };

    for (final entry in legacy.entries) {
      final weekday = Weekday.values
          .firstWhere((w) => w.toKey() == entry.key, orElse: () => Weekday.mon);
      if (entry.value is List) {
        days[weekday] = (entry.value as List)
            .whereType<Map<String, dynamic>>()
            .map(
              (json) => TimeSlot(
                start: (json['start'] ?? '').toString(),
                end: (json['end'] ?? '').toString(),
              ),
            )
            .toList();
      }
    }

    return PlanningData(
      type: PlanningType.fixed,
      timezone: timezone,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
      fixed: FixedSchema(days: days, exceptions: const <ExceptionDay>[]),
    );
  }

  /// Convenience method for UI integration on first load.
  Future<PlanningData?> initOrLoad({
    required String structureId,
    required String childId,
    required String updatedBy,
    String timezone = 'Europe/Paris',
  }) async {
    final existing = await load(structureId: structureId, childId: childId);
    if (existing != null) return existing;

    final migrated = await migrateLegacy(
      structureId: structureId,
      childId: childId,
      updatedBy: updatedBy,
      timezone: timezone,
    );
    await save(
      structureId: structureId,
      childId: childId,
      planning: migrated,
    );
    return migrated;
  }

  Map<String, dynamic> _preparePlanningDocument(PlanningData planning) {
    final map = <String, dynamic>{
      'type': planning.type.name,
      'timezone': planning.timezone,
      'updatedAt': planning.updatedAt.millisecondsSinceEpoch,
      'updatedBy': planning.updatedBy,
    };

    final sanitizedMonthly =
        planning.type == PlanningType.monthly ? _sanitizeMonthly(planning.monthly) : null;

    switch (planning.type) {
      case PlanningType.fixed:
        map['fixed'] = planning.fixed?.toJson();
        break;
      case PlanningType.altWeeks:
        map['altWeeks'] = planning.altWeeks?.toJson();
        break;
      case PlanningType.monthly:
        map['monthly'] = sanitizedMonthly?.toJson();
        break;
    }

    return map;
  }

  Map<String, dynamic> _prepareChildUpdateMap(PlanningData planning) {
    final sanitizedMonthly =
        planning.type == PlanningType.monthly ? _sanitizeMonthly(planning.monthly) : null;
    final legacySchedule = _buildLegacySchedule(planning);
    final planningField = buildPlanningField(
      planning,
      sanitizedMonthly: sanitizedMonthly,
    );
    final update = <String, dynamic>{
      'planning': planningField,
      'planningUpdatedAt': planning.updatedAt.millisecondsSinceEpoch,
      'planningUpdatedBy': planning.updatedBy,
      'planningType': planning.type.name,
      'schedule': legacySchedule.isEmpty ? FieldValue.delete() : legacySchedule,
    };

    switch (planning.type) {
      case PlanningType.fixed:
        update['planning.altWeeks'] = FieldValue.delete();
        update['planning.monthly'] = FieldValue.delete();
        update['planning.months'] = FieldValue.delete();
        break;
      case PlanningType.altWeeks:
        update['planning.fixed'] = FieldValue.delete();
        update['planning.monthly'] = FieldValue.delete();
        update['planning.months'] = FieldValue.delete();
        break;
      case PlanningType.monthly:
        update['planning.fixed'] = FieldValue.delete();
        update['planning.altWeeks'] = FieldValue.delete();
        update['planning.months'] = FieldValue.delete();
        break;
    }

    return update;
  }
}

@visibleForTesting
Map<String, dynamic> buildPlanningField(
  PlanningData planning, {
  MonthlySchema? sanitizedMonthly,
}) {
  final field = <String, dynamic>{
    'type': planning.type.name,
    'timezone': planning.timezone,
    'updatedAt': planning.updatedAt.millisecondsSinceEpoch,
    'updatedBy': planning.updatedBy,
  };

  switch (planning.type) {
    case PlanningType.fixed:
      final fixed = planning.fixed;
      if (fixed != null) {
        field['fixed'] = fixed.toJson();
      }
      break;
    case PlanningType.altWeeks:
      final altWeeks = planning.altWeeks;
      if (altWeeks != null) {
        field['altWeeks'] = altWeeks.toJson();
      }
      break;
    case PlanningType.monthly:
      final effectiveMonthly = sanitizedMonthly ?? _sanitizeMonthly(planning.monthly);
      if (effectiveMonthly != null) {
        field['monthly'] = effectiveMonthly.toJson();
      }
      break;
  }

  return field;
}

MonthlySchema? _sanitizeMonthly(MonthlySchema? monthly) {
  if (monthly == null) return null;
  final cleanedMonths = <String, MonthData>{};
  for (final entry in monthly.months.entries) {
    final cleanedDays = <String, List<TimeSlot>>{};
    for (final dayEntry in entry.value.days.entries) {
      if (dayEntry.value.isEmpty) continue;
      cleanedDays[dayEntry.key] = List<TimeSlot>.from(dayEntry.value);
    }
    if (cleanedDays.isNotEmpty) {
      cleanedMonths[entry.key] = MonthData(days: cleanedDays);
    }
  }
  return MonthlySchema(
    months: cleanedMonths,
    fallback: monthly.fallback,
  );
}

Map<String, dynamic> _buildLegacySchedule(PlanningData planning) {
  const weekdayLabels = {
    Weekday.mon: 'Lundi',
    Weekday.tue: 'Mardi',
    Weekday.wed: 'Mercredi',
    Weekday.thu: 'Jeudi',
    Weekday.fri: 'Vendredi',
    Weekday.sat: 'Samedi',
    Weekday.sun: 'Dimanche',
  };

  final Map<String, dynamic> schedule = {};

  Map<Weekday, List<TimeSlot>>? source;

  switch (planning.type) {
    case PlanningType.fixed:
      source = planning.fixed?.days;
      break;
    case PlanningType.altWeeks:
      source = planning.altWeeks?.weekA.days;
      break;
    case PlanningType.monthly:
      // Pas de conversion évidente → laisser vide.
      break;
  }

  if (source != null) {
    for (final entry in source.entries) {
      if (entry.value.isEmpty) continue;
      final label = weekdayLabels[entry.key];
      if (label == null) continue;
      schedule[label] = entry.value
          .map((slot) => {'start': slot.start, 'end': slot.end})
          .toList();
    }
  }

  return schedule;
}

/// Integration helpers to call from UI.
Future<void> onSavePressed(
  String structureId,
  String childId,
  PlanningData data, {
  required PlanningRepository repository,
}) async {
  await repository.save(
    structureId: structureId,
    childId: childId,
    planning: data,
  );
}
