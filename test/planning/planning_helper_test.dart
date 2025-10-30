import 'package:flutter_test/flutter_test.dart';
import 'package:poppins_app/planning/planning_models.dart';
import 'package:poppins_app/utils/planning_helper.dart';

Map<Weekday, List<TimeSlot>> _emptyWeek() {
  return {
    for (final weekday in Weekday.values) weekday: const <TimeSlot>[],
  };
}

void main() {
  group('PlanningHelper.shouldShowChildOnDate', () {
    test('returns true when no planning data is present', () {
      final child = {'id': 'child-1'};
      final date = DateTime.utc(2024, 05, 10);

      expect(PlanningHelper.shouldShowChildOnDate(child, date), isTrue);
    });

    test('returns true for monthly planning when the day has no entry', () {
      final planning = PlanningData(
        type: PlanningType.monthly,
        timezone: 'Europe/Paris',
        updatedAt: DateTime.utc(2024, 05, 01),
        updatedBy: 'tester',
        monthly: MonthlySchema(
          months: {
            '2024-05': MonthData(
              days: {
                '2024-05-15': const [TimeSlot(start: '08:00', end: '17:00')],
              },
            ),
          },
          fallback: null,
        ),
      );

      final child = {
        'planning': planning.toJson(),
      };

      expect(
        PlanningHelper.shouldShowChildOnDate(
          child,
          DateTime.utc(2024, 05, 14),
        ),
        isTrue,
      );
      expect(
        PlanningHelper.shouldShowChildOnDate(
          child,
          DateTime.utc(2024, 05, 15),
        ),
        isTrue,
      );
    });

    test('respects alt weeks scheduling when slots are defined for the day',
        () {
      final weekA = _emptyWeek()
        ..[Weekday.mon] = const [TimeSlot(start: '08:00', end: '17:00')];
      final weekB = _emptyWeek();

      final planning = PlanningData(
        type: PlanningType.altWeeks,
        timezone: 'Europe/Paris',
        updatedAt: DateTime.utc(2024, 05, 01),
        updatedBy: 'tester',
        altWeeks: AltWeeksSchema(
          weekAStartIso: '2024-05-13',
          weekA: WeeklySchema(days: weekA),
          weekB: WeeklySchema(days: weekB),
          exceptions: const <ExceptionDay>[],
        ),
      );

      final child = {
        'planning': planning.toJson(),
      };

      expect(
        PlanningHelper.shouldShowChildOnDate(
          child,
          DateTime.utc(2024, 05, 13),
        ),
        isTrue,
      );
      expect(
        PlanningHelper.shouldShowChildOnDate(
          child,
          DateTime.utc(2024, 05, 14),
        ),
        isFalse,
      );
    });
  });
}
