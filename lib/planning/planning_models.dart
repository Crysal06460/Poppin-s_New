import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// Planning modes supported by the application.
enum PlanningType { fixed, altWeeks, monthly }

/// Weekday abstraction with helpers for JSON keys and DateTime conversion.
enum Weekday {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun;

  static const _weekdayMap = {
    DateTime.monday: Weekday.mon,
    DateTime.tuesday: Weekday.tue,
    DateTime.wednesday: Weekday.wed,
    DateTime.thursday: Weekday.thu,
    DateTime.friday: Weekday.fri,
    DateTime.saturday: Weekday.sat,
    DateTime.sunday: Weekday.sun,
  };

  static Weekday fromDateTime(DateTime date) {
    return _weekdayMap[date.weekday] ?? Weekday.mon;
  }

  String toKey() => name;

  static Weekday fromKey(String key) {
    return Weekday.values.firstWhere(
      (w) => w.toKey() == key,
      orElse: () => Weekday.mon,
    );
  }
}

/// Simple time interval described by HH:mm strings (local time).
@immutable
class TimeSlot {
  const TimeSlot({required this.start, required this.end});

  final String start;
  final String end;

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      start: (json['start'] ?? '').toString(),
      end: (json['end'] ?? '').toString(),
    );
  }
}

/// Exception for a specific day overriding the default schedule.
@immutable
class ExceptionDay {
  const ExceptionDay({required this.dateIso, required this.slots});

  final String dateIso; // YYYY-MM-DD
  final List<TimeSlot> slots;

  Map<String, dynamic> toJson() => {
        'dateIso': dateIso,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  factory ExceptionDay.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    return ExceptionDay(
      dateIso: (json['dateIso'] ?? '').toString(),
      slots: rawSlots is List
          ? rawSlots
              .whereType<Map<String, dynamic>>()
              .map(TimeSlot.fromJson)
              .toList(growable: false)
          : const <TimeSlot>[],
    );
  }
}

/// Weekly schema used for both fixed planning and alternating weeks.
@immutable
class WeeklySchema {
  const WeeklySchema({required this.days});

  final Map<Weekday, List<TimeSlot>> days;

  Map<String, dynamic> toJson() => {
        'days': days.map(
          (key, value) => MapEntry(
            key.toKey(),
            value.map((s) => s.toJson()).toList(),
          ),
        ),
      };

  factory WeeklySchema.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    if (rawDays is! Map) {
      return WeeklySchema(
        days: {for (var w in Weekday.values) w: const <TimeSlot>[]},
      );
    }

    return WeeklySchema(
      days: {
        for (final entry in rawDays.entries)
          if (entry.value is List)
            Weekday.fromKey(entry.key.toString()): (entry.value as List)
                .whereType<Map<String, dynamic>>()
                .map(TimeSlot.fromJson)
                .toList()
      }..addEntries(
          Weekday.values
              .where((w) => !rawDays.keys.contains(w.toKey()))
              .map((w) => MapEntry(w, const <TimeSlot>[])),
        ),
    );
  }

  WeeklySchema copyWith({
    Map<Weekday, List<TimeSlot>>? days,
  }) {
    return WeeklySchema(days: days ?? this.days);
  }
}

/// Fixed schema wraps a weekly schema and exception days.
@immutable
class FixedSchema {
  const FixedSchema({
    required this.days,
    this.exceptions = const <ExceptionDay>[],
  });

  final Map<Weekday, List<TimeSlot>> days;
  final List<ExceptionDay> exceptions;

  Map<String, dynamic> toJson() => {
        'days': days.map(
          (key, value) => MapEntry(
            key.toKey(),
            value.map((s) => s.toJson()).toList(),
          ),
        ),
        'exceptions': exceptions.map((e) => e.toJson()).toList(),
      };

  factory FixedSchema.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final rawExceptions = json['exceptions'];

    final mappedDays = <Weekday, List<TimeSlot>>{};
    if (rawDays is Map) {
      for (final entry in rawDays.entries) {
        if (entry.value is List) {
          mappedDays[Weekday.fromKey(entry.key.toString())] =
              (entry.value as List)
                  .whereType<Map<String, dynamic>>()
                  .map(TimeSlot.fromJson)
                  .toList();
        }
      }
    }

    for (final weekday in Weekday.values) {
      mappedDays.putIfAbsent(weekday, () => const <TimeSlot>[]);
    }

    return FixedSchema(
      days: mappedDays,
      exceptions: rawExceptions is List
          ? rawExceptions
              .whereType<Map<String, dynamic>>()
              .map(ExceptionDay.fromJson)
              .toList(growable: false)
          : const <ExceptionDay>[],
    );
  }

  FixedSchema copyWith({
    Map<Weekday, List<TimeSlot>>? days,
    List<ExceptionDay>? exceptions,
  }) {
    return FixedSchema(
      days: days ?? this.days,
      exceptions: exceptions ?? this.exceptions,
    );
  }
}

/// Schema for alternating weeks (A/B).
@immutable
class AltWeeksSchema {
  const AltWeeksSchema({
    required this.weekAStartIso,
    required this.weekA,
    required this.weekB,
    this.exceptions = const <ExceptionDay>[],
  });

  final String weekAStartIso;
  final WeeklySchema weekA;
  final WeeklySchema weekB;
  final List<ExceptionDay> exceptions;

  Map<String, dynamic> toJson() => {
        'weekAStartIso': weekAStartIso,
        'weekA': weekA.toJson(),
        'weekB': weekB.toJson(),
        'exceptions': exceptions.map((e) => e.toJson()).toList(),
      };

  factory AltWeeksSchema.fromJson(Map<String, dynamic> json) {
    return AltWeeksSchema(
      weekAStartIso: (json['weekAStartIso'] ?? '').toString(),
      weekA: WeeklySchema.fromJson(
        (json['weekA'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      weekB: WeeklySchema.fromJson(
        (json['weekB'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      exceptions: (json['exceptions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ExceptionDay.fromJson)
              .toList(growable: false) ??
          const <ExceptionDay>[],
    );
  }

  AltWeeksSchema copyWith({
    String? weekAStartIso,
    WeeklySchema? weekA,
    WeeklySchema? weekB,
    List<ExceptionDay>? exceptions,
  }) {
    return AltWeeksSchema(
      weekAStartIso: weekAStartIso ?? this.weekAStartIso,
      weekA: weekA ?? this.weekA,
      weekB: weekB ?? this.weekB,
      exceptions: exceptions ?? this.exceptions,
    );
  }
}

/// Month data container for monthly planning.
@immutable
class MonthData {
  const MonthData({required this.days});

  final Map<String, List<TimeSlot>> days; // YYYY-MM-DD -> slots

  Map<String, dynamic> toJson() => {
        'days': days.map(
          (key, value) => MapEntry(
            key,
            value.map((s) => s.toJson()).toList(),
          ),
        ),
      };

  factory MonthData.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    if (rawDays is! Map) {
      return const MonthData(days: <String, List<TimeSlot>>{});
    }

    return MonthData(
      days: {
        for (final entry in rawDays.entries)
          if (entry.value is List)
            entry.key.toString(): (entry.value as List)
                .whereType<Map<String, dynamic>>()
                .map(TimeSlot.fromJson)
                .toList()
      },
    );
  }
}

/// Monthly schema with optional fallback weekly schedule.
@immutable
class MonthlySchema {
  const MonthlySchema({
    required this.months,
    this.fallback,
  });

  final Map<String, MonthData> months; // YYYY-MM -> MonthData
  final WeeklySchema? fallback;

  Map<String, dynamic> toJson() => {
        'months': months.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        if (fallback != null) 'fallback': fallback!.toJson(),
      };

  factory MonthlySchema.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['months'];
    final mappedMonths = <String, MonthData>{};
    if (rawMonths is Map) {
      for (final entry in rawMonths.entries) {
        if (entry.value is Map) {
          mappedMonths[entry.key.toString()] = MonthData.fromJson(
            (entry.value as Map).cast<String, dynamic>(),
          );
        }
      }
    }

    return MonthlySchema(
      months: mappedMonths,
      fallback: json['fallback'] is Map
          ? WeeklySchema.fromJson(
              (json['fallback'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  MonthlySchema copyWith({
    Map<String, MonthData>? months,
    bool removeFallback = false,
    WeeklySchema? fallback,
  }) {
    return MonthlySchema(
      months: months ?? this.months,
      fallback: removeFallback ? null : (fallback ?? this.fallback),
    );
  }
}

/// Root planning model persisted in Firestore.
@immutable
class PlanningData {
  const PlanningData({
    required this.type,
    required this.timezone,
    required this.updatedAt,
    required this.updatedBy,
    this.fixed,
    this.altWeeks,
    this.monthly,
  });

  final PlanningType type;
  final FixedSchema? fixed;
  final AltWeeksSchema? altWeeks;
  final MonthlySchema? monthly;
  final String timezone;
  final DateTime updatedAt;
  final String updatedBy;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timezone': timezone,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'updatedBy': updatedBy,
        'fixed': fixed?.toJson(),
        'altWeeks': altWeeks?.toJson(),
        'monthly': monthly?.toJson(),
      };

  factory PlanningData.fromJson(Map<String, dynamic> json) {
    final type = _planningTypeFromString(json['type']);
    return PlanningData(
      type: type,
      timezone: (json['timezone'] ?? 'Europe/Paris').toString(),
      updatedAt: _parseDate(json['updatedAt']),
      updatedBy: (json['updatedBy'] ?? '').toString(),
      fixed: json['fixed'] is Map
          ? FixedSchema.fromJson(
              (json['fixed'] as Map).cast<String, dynamic>(),
            )
          : null,
      altWeeks: json['altWeeks'] is Map
          ? AltWeeksSchema.fromJson(
              (json['altWeeks'] as Map).cast<String, dynamic>(),
            )
          : null,
      monthly: json['monthly'] is Map
          ? MonthlySchema.fromJson(
              (json['monthly'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  PlanningData copyWith({
    PlanningType? type,
    FixedSchema? fixed,
    bool clearFixed = false,
    AltWeeksSchema? altWeeks,
    bool clearAltWeeks = false,
    MonthlySchema? monthly,
    bool clearMonthly = false,
    String? timezone,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return PlanningData(
      type: type ?? this.type,
      fixed: clearFixed ? null : (fixed ?? this.fixed),
      altWeeks: clearAltWeeks ? null : (altWeeks ?? this.altWeeks),
      monthly: clearMonthly ? null : (monthly ?? this.monthly),
      timezone: timezone ?? this.timezone,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  static PlanningType _planningTypeFromString(dynamic raw) {
    final value = raw?.toString();
    if (value == null) return PlanningType.fixed;
    return PlanningType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => PlanningType.fixed,
    );
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsed);
      }
    }
    if (raw is DateTime) {
      return raw;
    }
    return DateTime.now();
  }
}

/// Convenience builders for empty schemas.
class PlanningFactory {
  const PlanningFactory._();

  static PlanningData emptyFixed({
    String timezone = 'Europe/Paris',
    required String updatedBy,
    DateTime? updatedAt,
  }) {
    return PlanningData(
      type: PlanningType.fixed,
      timezone: timezone,
      updatedAt: updatedAt ?? DateTime.now(),
      updatedBy: updatedBy,
      fixed: FixedSchema(
        days: {
          for (final weekday in Weekday.values) weekday: const <TimeSlot>[],
        },
        exceptions: const <ExceptionDay>[],
      ),
    );
  }
}

/// Utility extension to deep compare time slots collections in tests.
extension PlanningDeepEquality on PlanningData {
  bool deepEquals(PlanningData other) {
    final eq = const DeepCollectionEquality();
    return type == other.type &&
        timezone == other.timezone &&
        updatedBy == other.updatedBy &&
        eq.equals(fixed?.toJson(), other.fixed?.toJson()) &&
        eq.equals(altWeeks?.toJson(), other.altWeeks?.toJson()) &&
        eq.equals(monthly?.toJson(), other.monthly?.toJson());
  }
}
