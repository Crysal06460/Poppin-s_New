import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'planning_models.dart';

/// Returns a new [DateTime] stripped of time information while preserving the
/// local calendar date (avoids DST glitches).
DateTime dayOnlyLocal(DateTime dt) {
  return DateTime(dt.year, dt.month, dt.day);
}

/// Formats a [DateTime] into "YYYY-MM".
String toYearMonth(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Formats a [DateTime] into "YYYY-MM-DD".
String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Weekday weekdayFrom(DateTime d) => Weekday.fromDateTime(d);

/// Sorts slots by start time and returns a new list.
List<TimeSlot> mergeAndSort(List<TimeSlot> slots) {
  final sorted = [...slots]..sort((a, b) => a.start.compareTo(b.start));
  return sorted;
}

/// Returns true when any overlapping slots are detected.
bool hasOverlap(List<TimeSlot> slots) {
  final sorted = mergeAndSort(slots);
  for (var i = 0; i < sorted.length - 1; i++) {
    final current = sorted[i];
    final next = sorted[i + 1];
    if (current.end.compareTo(next.start) > 0) {
      return true;
    }
  }
  return false;
}

/// Determines if a day belongs to week A based on the provided reference date.
bool isWeekA(String weekAStartIso, DateTime dayLocal) {
  if (weekAStartIso.isEmpty) return true;
  final parts = weekAStartIso.split('-');
  if (parts.length != 3) return true;

  final ref = DateTime(
    int.tryParse(parts[0]) ?? dayLocal.year,
    int.tryParse(parts[1]) ?? dayLocal.month,
    int.tryParse(parts[2]) ?? dayLocal.day,
  );
  final difference =
      dayOnlyLocal(dayLocal).difference(dayOnlyLocal(ref)).inDays;
  if (difference < 0) {
    // Before reference: still week A to avoid surprises.
    return true;
  }
  final weeks = difference ~/ 7;
  return weeks.isEven;
}

/// Resolves the slots applicable for a given local day.
List<TimeSlot> resolveDaySlots(DateTime dayLocal, PlanningData planning) {
  final dateIso = toIsoDate(dayLocal);
  final weekday = weekdayFrom(dayLocal);

  switch (planning.type) {
    case PlanningType.fixed:
      final fixed = planning.fixed;
      if (fixed == null) return const <TimeSlot>[];
      final exception =
          fixed.exceptions.firstWhereOrNull((e) => e.dateIso == dateIso);
      if (exception != null) {
        return mergeAndSort(exception.slots);
      }
      return mergeAndSort(fixed.days[weekday] ?? const <TimeSlot>[]);
    case PlanningType.altWeeks:
      final alt = planning.altWeeks;
      if (alt == null) return _fallbackFixedSlots(planning.fixed, dayLocal);

      final exception =
          alt.exceptions.firstWhereOrNull((e) => e.dateIso == dateIso);
      if (exception != null) {
        return mergeAndSort(exception.slots);
      }

      final isA = isWeekA(alt.weekAStartIso, dayLocal);
      final schema = isA ? alt.weekA : alt.weekB;
      return mergeAndSort(schema.days[weekday] ?? const <TimeSlot>[]);
    case PlanningType.monthly:
      final monthly = planning.monthly;
      if (monthly == null) return const <TimeSlot>[];
      final yearMonth = toYearMonth(dayLocal);
      final monthData = monthly.months[yearMonth];
      final dayKey = toIsoDate(dayLocal);
      if (monthData != null && monthData.days.containsKey(dayKey)) {
        final daySlots = monthData.days[dayKey] ?? const <TimeSlot>[];
        return mergeAndSort(daySlots);
      }
      final fallbackWeekly = monthly.fallback;
      if (fallbackWeekly != null) {
        return mergeAndSort(
          fallbackWeekly.days[weekday] ?? const <TimeSlot>[],
        );
      }
      return _fallbackFixedSlots(planning.fixed, dayLocal);
  }
}

List<TimeSlot> _fallbackFixedSlots(FixedSchema? fixed, DateTime dayLocal) {
  if (fixed == null) return const <TimeSlot>[];
  return mergeAndSort(fixed.days[weekdayFrom(dayLocal)] ?? const <TimeSlot>[]);
}

/// Builds an alt-week schema from a fixed weekly schedule (defaults week B empty).
AltWeeksSchema fixedToAltWeeks({
  required FixedSchema fixed,
  required String weekAStartIso,
}) {
  return AltWeeksSchema(
    weekAStartIso: weekAStartIso,
    weekA: WeeklySchema(days: _cloneWeeklyDays(fixed.days)),
    weekB: WeeklySchema(
      days: {
        for (final weekday in Weekday.values) weekday: const <TimeSlot>[],
      },
    ),
    exceptions: _cloneExceptions(fixed.exceptions),
  );
}

/// Builds a monthly fallback schema from a fixed weekly schedule.
MonthlySchema fixedToMonthly({
  required FixedSchema fixed,
  Map<String, MonthData>? months,
}) {
  return MonthlySchema(
    months: {
      for (final entry in (months ?? const <String, MonthData>{}).entries)
        entry.key: MonthData(
          days: {
            for (final dayEntry in entry.value.days.entries)
              dayEntry.key: List<TimeSlot>.from(dayEntry.value),
          },
        ),
    },
    fallback: WeeklySchema(
      days: _cloneWeeklyDays(fixed.days),
    ),
  );
}

/// Converts alternating weeks back to a fixed schedule by selecting week A or B.
FixedSchema altWeeksToFixed(
  AltWeeksSchema altWeeks, {
  bool useWeekA = true,
}) {
  final schema = useWeekA ? altWeeks.weekA : altWeeks.weekB;
  return FixedSchema(
    days: _cloneWeeklyDays(schema.days),
    exceptions: _cloneExceptions(altWeeks.exceptions),
  );
}

/// Converts monthly planning to fixed, relying on fallback schedule when available.
FixedSchema? monthlyToFixed(
  MonthlySchema monthly,
) {
  final fallback = monthly.fallback;
  if (fallback == null) return null;
  return FixedSchema(
    days: _cloneWeeklyDays(fallback.days),
    exceptions: const <ExceptionDay>[],
  );
}

Map<Weekday, List<TimeSlot>> _cloneWeeklyDays(
  Map<Weekday, List<TimeSlot>> source,
) {
  final copy = {
    for (final entry in source.entries)
      entry.key: List<TimeSlot>.from(entry.value),
  };
  for (final weekday in Weekday.values) {
    copy.putIfAbsent(weekday, () => <TimeSlot>[]);
  }
  return copy;
}

List<ExceptionDay> _cloneExceptions(List<ExceptionDay> source) {
  return source
      .map(
        (e) => ExceptionDay(
          dateIso: e.dateIso,
          slots: List<TimeSlot>.from(e.slots),
        ),
      )
      .toList(growable: false);
}
