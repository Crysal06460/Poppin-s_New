import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poppins_app/planning/planning_models.dart';
import 'package:poppins_app/planning/planning_repository.dart';

void main() {
  group('PlanningRepository.save', () {
    test('removes deleted monthly days in both documents', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = PlanningRepository(firestore: firestore);

      MonthlySchema buildMonthly(List<String> dayIsos) => MonthlySchema(
            months: {
              '2025-10': MonthData(
                days: {
                  for (final iso in dayIsos)
                    iso: const [TimeSlot(start: '08:30', end: '17:30')],
                },
              ),
            },
            fallback: null,
          );

      final initialPlanning = PlanningData(
        type: PlanningType.monthly,
        timezone: 'Europe/Paris',
        updatedAt: DateTime.utc(2025, 10, 1),
        updatedBy: 'user-1',
        monthly: buildMonthly(['2025-10-12', '2025-10-13']),
      );

      await repository.save(
        structureId: 'structure-1',
        childId: 'child-1',
        planning: initialPlanning,
      );

      final updatedPlanning = initialPlanning.copyWith(
        updatedAt: DateTime.utc(2025, 10, 2),
        monthly: buildMonthly(['2025-10-13']),
      );

      await repository.save(
        structureId: 'structure-1',
        childId: 'child-1',
        planning: updatedPlanning,
      );

      // Verify the planning document in the sub-collection is updated.
      final planningDoc = await firestore
          .collection('structures')
          .doc('structure-1')
          .collection('children')
          .doc('child-1')
          .collection('planning')
          .doc('default')
          .get();

      final planningData = planningDoc.data()!;
      final monthly = (planningData['monthly'] as Map)['months'] as Map;
      final days = (monthly['2025-10'] as Map)['days'] as Map;
      expect(days.containsKey('2025-10-12'), isFalse);
      expect(days.containsKey('2025-10-13'), isTrue);

      // Verify the flattened planning field on the child document is updated too.
      final childDoc = await firestore
          .collection('structures')
          .doc('structure-1')
          .collection('children')
          .doc('child-1')
          .get();

      final childPlanning = (childDoc.data()!['planning'] as Map)['monthly'] as Map;
      final childDays = (childPlanning['months'] as Map)['2025-10']['days'] as Map;
      expect(childDays.containsKey('2025-10-12'), isFalse);
      expect(childDays.containsKey('2025-10-13'), isTrue);
    });

    test('cleans monthly data when switching back to fixed mode', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = PlanningRepository(firestore: firestore);

      MonthlySchema buildMonthly(List<String> dayIsos) => MonthlySchema(
            months: {
              '2025-10': MonthData(
                days: {
                  for (final iso in dayIsos)
                    iso: const [TimeSlot(start: '08:30', end: '17:30')],
                },
              ),
            },
            fallback: null,
          );

      final monthlyPlanning = PlanningData(
        type: PlanningType.monthly,
        timezone: 'Europe/Paris',
        updatedAt: DateTime.utc(2025, 10, 1),
        updatedBy: 'user-1',
        monthly: buildMonthly(['2025-10-12']),
      );

      await repository.save(
        structureId: 'structure-1',
        childId: 'child-1',
        planning: monthlyPlanning,
      );

      final fixedPlanning = PlanningData(
        type: PlanningType.fixed,
        timezone: 'Europe/Paris',
        updatedAt: DateTime.utc(2025, 10, 2),
        updatedBy: 'user-1',
        fixed: FixedSchema(
          days: {
            Weekday.mon: const [TimeSlot(start: '09:00', end: '12:00')],
            for (final weekday in Weekday.values.where((w) => w != Weekday.mon))
              weekday: const <TimeSlot>[],
          },
          exceptions: const <ExceptionDay>[],
        ),
      );

      await repository.save(
        structureId: 'structure-1',
        childId: 'child-1',
        planning: fixedPlanning,
      );

      final childDoc = await firestore
          .collection('structures')
          .doc('structure-1')
          .collection('children')
          .doc('child-1')
          .get();

      final planningField = childDoc.data()!['planning'] as Map<String, dynamic>;
      expect(planningField['type'], 'fixed');
      expect(planningField.containsKey('monthly'), isFalse);
      expect(planningField.containsKey('months'), isFalse);

      final fixed = planningField['fixed'] as Map<String, dynamic>;
      expect(fixed['days'], isNotNull);
    });
  });
}
