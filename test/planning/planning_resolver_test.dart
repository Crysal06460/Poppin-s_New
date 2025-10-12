import 'package:flutter_test/flutter_test.dart';
import 'package:poppins_app/planning/planning_models.dart';
import 'package:poppins_app/planning/planning_resolver.dart';
import 'package:poppins_app/utils/planning_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('resolveDaySlots', () {
    test('returns fixed slots for weekday', () {
      final planning = PlanningData(
        type: PlanningType.fixed,
        timezone: 'Europe/Paris',
        updatedAt: DateTime(2024, 1, 1),
        updatedBy: 'tester',
        fixed: FixedSchema(
          days: {
            for (final weekday in Weekday.values) weekday: const <TimeSlot>[],
          }..[Weekday.mon] = const [
              TimeSlot(start: '08:30', end: '16:00'),
            ],
          exceptions: const [],
        ),
      );

      final slots = resolveDaySlots(DateTime(2024, 1, 8), planning);
      expect(slots, hasLength(1));
      expect(slots.first.start, '08:30');
      expect(slots.first.end, '16:00');
    });

    test('exceptions override fixed schedule', () {
      final planning = PlanningData(
        type: PlanningType.fixed,
        timezone: 'Europe/Paris',
        updatedAt: DateTime(2024, 1, 1),
        updatedBy: 'tester',
        fixed: FixedSchema(
          days: {
            for (final weekday in Weekday.values)
              weekday: const [TimeSlot(start: '08:00', end: '17:00')],
          },
          exceptions: const [
            ExceptionDay(dateIso: '2024-11-11', slots: []),
          ],
        ),
      );

      final slots = resolveDaySlots(DateTime(2024, 11, 11), planning);
      expect(slots, isEmpty);
    });

    test('alt weeks alternation works', () {
      final planning = PlanningData(
        type: PlanningType.altWeeks,
        timezone: 'Europe/Paris',
        updatedAt: DateTime(2024, 1, 1),
        updatedBy: 'tester',
        altWeeks: AltWeeksSchema(
          weekAStartIso: '2024-01-01',
          weekA: WeeklySchema(
            days: {
              for (final weekday in Weekday.values) weekday: const [],
            }..[Weekday.mon] = const [
                TimeSlot(start: '08:30', end: '16:00'),
              ],
          ),
          weekB: WeeklySchema(
            days: {
              for (final weekday in Weekday.values) weekday: const [],
            }..[Weekday.mon] = const [
                TimeSlot(start: '09:00', end: '17:00'),
              ],
          ),
          exceptions: const [],
        ),
      );

      final mondayWeekA = resolveDaySlots(DateTime(2024, 1, 1), planning);
      final mondayWeekB = resolveDaySlots(DateTime(2024, 1, 8), planning);
      final mondayWeekARepeat =
          resolveDaySlots(DateTime(2024, 1, 15), planning);

      expect(mondayWeekA.first.start, '08:30');
      expect(mondayWeekB.first.start, '09:00');
      expect(mondayWeekARepeat.first.start, '08:30');
    });

    test('monthly schedule resolves with fallback', () {
      final planning = PlanningData(
        type: PlanningType.monthly,
        timezone: 'Europe/Paris',
        updatedAt: DateTime(2024, 1, 1),
        updatedBy: 'tester',
        monthly: MonthlySchema(
          months: {
            '2024-11': MonthData(days: {
              '2024-11-03': const [
                TimeSlot(start: '08:30', end: '17:30'),
              ],
            }),
          },
          fallback: WeeklySchema(
            days: {
              for (final weekday in Weekday.values) weekday: const [],
            }..[Weekday.mon] = const [
                TimeSlot(start: '09:00', end: '18:00'),
              ],
          ),
        ),
      );

      final daySpecific = resolveDaySlots(DateTime(2024, 11, 3), planning);
      final fallbackDay = resolveDaySlots(DateTime(2024, 11, 4), planning);

      expect(daySpecific, hasLength(1));
      expect(daySpecific.first.start, '08:30');

      expect(fallbackDay, hasLength(1));
      expect(fallbackDay.first.start, '09:00');
    });

    test('dayOnlyLocal removes time information', () {
      final date = DateTime(2024, 3, 31, 2, 30);
      final stripped = dayOnlyLocal(date);
      expect(stripped.hour, 0);
      expect(stripped.minute, 0);
    });
  });

  group('validation helpers', () {
    test('detects overlapping slots', () {
      final slots = const [
        TimeSlot(start: '08:00', end: '10:00'),
        TimeSlot(start: '09:30', end: '11:00'),
      ];
      expect(hasOverlap(slots), isTrue);
    });

    test('mergeAndSort orders slots', () {
      final slots = const [
        TimeSlot(start: '10:00', end: '11:00'),
        TimeSlot(start: '08:00', end: '09:00'),
      ];
      final sorted = mergeAndSort(slots);
      expect(sorted.first.start, '08:00');
    });
  });

  group('isWeekA', () {
    test('alternates every 7 days', () {
      final start = '2024-01-01';
      final monday = DateTime(2024, 1, 1);
      for (var week = 0; week < 6; week++) {
        final date = monday.add(Duration(days: week * 7));
        expect(isWeekA(start, date), week.isEven);
      }
    });
  });

  group('conversions', () {
    test('fixedToMonthly keeps fallback weekly schema', () {
      final fixed = FixedSchema(
        days: {
          for (final weekday in Weekday.values) weekday: const <TimeSlot>[],
        }..[Weekday.mon] = const [
            TimeSlot(start: '08:30', end: '16:00'),
          ],
        exceptions: const [],
      );

      final monthly = fixedToMonthly(fixed: fixed);
      final fallbackSlots = monthly.fallback?.days[Weekday.mon] ?? const [];

      expect(fallbackSlots, isNotEmpty);
      expect(fallbackSlots.first.start, '08:30');
    });

    test('monthlyToFixed returns null when fallback missing', () {
      final monthly = MonthlySchema(
        months: const {},
        fallback: null,
      );

      expect(monthlyToFixed(monthly), isNull);
    });

    test('monthlyToFixed uses fallback when available', () {
      final monthly = MonthlySchema(
        months: const {},
        fallback: WeeklySchema(
          days: {
            for (final weekday in Weekday.values) weekday: const <TimeSlot>[],
          }..[Weekday.tue] = const [
              TimeSlot(start: '09:00', end: '17:00'),
            ],
        ),
      );

      final fixed = monthlyToFixed(monthly);
      expect(fixed, isNotNull);
      final slots = fixed!.days[Weekday.tue] ?? const [];
      expect(slots, hasLength(1));
      expect(slots.first.start, '09:00');
    });
  });

  group('PlanningHelper integration', () {
    test('isScheduledForDate returns true when fixed sunday slot stored as firestore map', () {
      final child = {
        'id': 'child1',
        'firstName': 'Test',
        'planning': {
          'type': 'fixed',
          'timezone': 'Europe/Paris',
          'updatedAt': Timestamp.fromMillisecondsSinceEpoch(1725619200000),
          'updatedBy': 'tester',
          'fixed': {
            'days': {
              'sun': [
                {'start': '08:30', 'end': '17:30'},
              ],
            },
            'exceptions': [],
          },
          'altWeeks': null,
          'monthly': null,
        },
      };

      final sunday = DateTime(2024, 9, 1); // Sunday
      expect(PlanningHelper.isScheduledForDate(child, sunday), isTrue);
    });
  });
}
