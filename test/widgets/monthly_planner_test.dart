import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poppins_app/planning/planning_models.dart';
import 'package:poppins_app/widgets/planning/monthly_planner.dart';

void main() {
  testWidgets('Monthly planner removes day when clearing', (tester) async {
    final initialSchema = MonthlySchema(
      months: {
        '2025-10': MonthData(days: {
          '2025-10-12': const [TimeSlot(start: '08:30', end: '17:30')],
          '2025-10-13': const [TimeSlot(start: '08:30', end: '17:30')],
        }),
      },
      fallback: null,
    );

    MonthlySchema? emitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlyPlanner(
              schema: initialSchema,
              onChanged: (schema) => emitted = schema,
            ),
          ),
        ),
      ),
    );

    // Tap the day 12 cell.
    await tester.tap(find.text('12').first);
    await tester.pumpAndSettle();

    // Tap "Effacer la journée" in the bottom sheet.
    await tester.tap(find.text('Effacer la journée'));
    await tester.pumpAndSettle();

    expect(emitted, isNotNull);
    final monthData = emitted!.months['2025-10'];
    expect(monthData, isNotNull);
    expect(monthData!.days.containsKey('2025-10-12'), isFalse);
    // Other days are still present.
    expect(monthData.days.containsKey('2025-10-13'), isTrue);
  });
}
