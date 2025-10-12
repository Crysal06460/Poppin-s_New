import 'package:flutter/material.dart';
import '../../planning/planning_models.dart';

typedef PlanningModeChanged = void Function(PlanningType type);

class PlanningModeSelector extends StatelessWidget {
  const PlanningModeSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final PlanningType current;
  final PlanningModeChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de planning',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<PlanningType>(
          segments: const [
            ButtonSegment(
              value: PlanningType.fixed,
              label: Text('Horaires fixes'),
            ),
            ButtonSegment(
              value: PlanningType.altWeeks,
              label: Text('1 sem/2'),
            ),
            ButtonSegment(
              value: PlanningType.monthly,
              label: Text('Planning mensuel'),
            ),
          ],
          selected: {current},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            if (value.isEmpty) return;
            onChanged(value.first);
          },
        ),
      ],
    );
  }
}
