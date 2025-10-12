import 'package:flutter/material.dart';

import '../../planning/planning_models.dart';
import '../../planning/planning_repository.dart';
import '../../planning/planning_resolver.dart';
import 'alt_weeks_planner_form.dart';
import 'confirm_change_mode_dialog.dart';
import 'fixed_planner_form.dart';
import 'monthly_planner.dart';
import 'planner_types.dart';
import 'planning_mode_selector.dart';

class PlanningEditor extends StatefulWidget {
  const PlanningEditor({
    super.key,
    required this.initialPlanning,
    required this.onPlanningChanged,
    this.onValidationError,
  });

  final PlanningData initialPlanning;
  final ValueChanged<PlanningData> onPlanningChanged;
  final PlannerValidationError? onValidationError;

  @override
  State<PlanningEditor> createState() => _PlanningEditorState();
}

class _PlanningEditorState extends State<PlanningEditor> {
  late PlanningData _planning;
  @override
  void initState() {
    super.initState();
    _planning = widget.initialPlanning;
  }

  void _emit(PlanningData planning) {
    setState(() => _planning = planning);
    widget.onPlanningChanged(planning);
  }

  Future<void> _handleModeChange(PlanningType newType) async {
    if (newType == _planning.type) return;
    final confirmed = await showConfirmChangeModeDialog(
      context,
      from: _planning.type,
      to: newType,
    );
    if (!confirmed) return;

    PlanningData converted;
    switch (newType) {
      case PlanningType.fixed:
        converted = _planning.copyWith(
          type: PlanningType.fixed,
          fixed: _emptyFixedSchema(),
          clearAltWeeks: true,
          clearMonthly: true,
        );
        break;
      case PlanningType.altWeeks:
        converted = _planning.copyWith(
          type: PlanningType.altWeeks,
          altWeeks: _emptyAltWeeksSchema(),
          clearFixed: true,
          clearMonthly: true,
        );
        break;
      case PlanningType.monthly:
        converted = _planning.copyWith(
          type: PlanningType.monthly,
          monthly: _emptyMonthlySchema(),
          clearFixed: true,
          clearAltWeeks: true,
        );
        break;
    }

    _emit(converted);
  }

  Map<Weekday, List<TimeSlot>> _emptyWeekdays() {
    return {
      for (final weekday in Weekday.values) weekday: const <TimeSlot>[],
    };
  }

  WeeklySchema _emptyWeeklySchema() {
    return WeeklySchema(days: _emptyWeekdays());
  }

  FixedSchema _emptyFixedSchema() {
    return FixedSchema(
      days: _emptyWeekdays(),
      exceptions: const <ExceptionDay>[],
    );
  }

  AltWeeksSchema _emptyAltWeeksSchema() {
    return AltWeeksSchema(
      weekAStartIso: toIsoDate(DateTime.now()),
      weekA: _emptyWeeklySchema(),
      weekB: _emptyWeeklySchema(),
      exceptions: const <ExceptionDay>[],
    );
  }

  MonthlySchema _emptyMonthlySchema() {
    return const MonthlySchema(
      months: {},
      fallback: null,
    );
  }

  void _handleFixedChanged(FixedSchema schema) {
    _emit(
      _planning.copyWith(
        type: PlanningType.fixed,
        fixed: schema,
        clearAltWeeks: true,
        clearMonthly: true,
      ),
    );
  }

  void _handleAltWeeksChanged(AltWeeksSchema schema) {
    _emit(
      _planning.copyWith(
        type: PlanningType.altWeeks,
        altWeeks: schema,
        clearFixed: true,
        clearMonthly: true,
      ),
    );
  }

  void _handleMonthlyChanged(MonthlySchema schema) {
    _emit(
      _planning.copyWith(
        type: PlanningType.monthly,
        monthly: schema,
        clearFixed: true,
        clearAltWeeks: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlanningModeSelector(
          current: _planning.type,
          onChanged: _handleModeChange,
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            switch (_planning.type) {
              case PlanningType.fixed:
                return FixedPlannerForm(
                  key: const ValueKey('fixed-planner'),
                  schema: _planning.fixed ??
                      FixedSchema(
                        days: {
                          for (final weekday in Weekday.values)
                            weekday: const <TimeSlot>[],
                        },
                      ),
                  onChanged: _handleFixedChanged,
                  onValidationError: widget.onValidationError,
                );
              case PlanningType.altWeeks:
                return AltWeeksPlannerForm(
                  key: const ValueKey('altweeks-planner'),
                  schema: _planning.altWeeks ??
                      AltWeeksSchema(
                        weekAStartIso: toIsoDate(DateTime.now()),
                        weekA: WeeklySchema(
                          days: {
                            for (final weekday in Weekday.values)
                              weekday: const <TimeSlot>[],
                          },
                        ),
                        weekB: WeeklySchema(
                          days: {
                            for (final weekday in Weekday.values)
                              weekday: const <TimeSlot>[],
                          },
                        ),
                      ),
                  onChanged: _handleAltWeeksChanged,
                  onValidationError: widget.onValidationError,
                );
              case PlanningType.monthly:
                return MonthlyPlanner(
                  key: const ValueKey('monthly-planner'),
                  schema: _planning.monthly ??
                      MonthlySchema(
                        months: const {},
                        fallback: null,
                      ),
                  onChanged: _handleMonthlyChanged,
                  onValidationError: widget.onValidationError,
                );
            }
          },
        ),
      ],
    );
  }
}

/// Simple facade to integrate into existing screens.
class PlanningEditorController {
  PlanningEditorController({
    required this.repository,
  });

  final PlanningRepository repository;

  Future<PlanningData?> init({
    required String structureId,
    required String childId,
    required String userId,
  }) {
    return repository.initOrLoad(
      structureId: structureId,
      childId: childId,
      updatedBy: userId,
    );
  }

  Future<void> save({
    required String structureId,
    required String childId,
    required PlanningData planning,
  }) {
    return onSavePressed(
      structureId,
      childId,
      planning,
      repository: repository,
    );
  }
}
