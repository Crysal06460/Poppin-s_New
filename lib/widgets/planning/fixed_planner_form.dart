import 'package:flutter/material.dart';

import '../../planning/planning_models.dart';
import '../../planning/planning_resolver.dart';
import 'planner_types.dart';
import 'time_slot_editor.dart';

typedef FixedPlannerChanged = void Function(FixedSchema schema);

class FixedPlannerForm extends StatefulWidget {
  const FixedPlannerForm({
    super.key,
    required this.schema,
    required this.onChanged,
    this.onValidationError,
  });

  final FixedSchema schema;
  final FixedPlannerChanged onChanged;
  final PlannerValidationError? onValidationError;

  @override
  State<FixedPlannerForm> createState() => _FixedPlannerFormState();
}

class _FixedPlannerFormState extends State<FixedPlannerForm> {
  late Map<Weekday, List<TimeSlot>> _days;
  late List<ExceptionDay> _exceptions;

  @override
  void initState() {
    super.initState();
    _days = {
      for (final entry in widget.schema.days.entries)
        entry.key: List<TimeSlot>.from(entry.value),
    };

    for (final weekday in Weekday.values) {
      _days.putIfAbsent(weekday, () => <TimeSlot>[]);
    }

    _exceptions = widget.schema.exceptions
        .map(
          (e) => ExceptionDay(
            dateIso: e.dateIso,
            slots: List<TimeSlot>.from(e.slots),
          ),
        )
        .toList();
  }

  void _notifyChange() {
    for (final entry in _days.entries) {
      if (hasOverlap(entry.value)) {
        widget.onValidationError?.call(
          'Chevauchement détecté pour ${_weekdayLabel(entry.key)}',
        );
        return;
      }
    }
    for (final exception in _exceptions) {
      if (hasOverlap(exception.slots)) {
        widget.onValidationError?.call(
          'Chevauchement dans la journée exceptionnelle ${exception.dateIso}',
        );
        return;
      }
    }

    widget.onChanged(
      FixedSchema(
        days: {
          for (final entry in _days.entries)
            entry.key: List<TimeSlot>.from(entry.value),
        },
        exceptions: _exceptions
            .map(
              (e) => ExceptionDay(
                dateIso: e.dateIso,
                slots: List<TimeSlot>.from(e.slots),
              ),
            )
            .toList(),
      ),
    );
  }

  String _weekdayLabel(Weekday weekday) {
    switch (weekday) {
      case Weekday.mon:
        return 'Lundi';
      case Weekday.tue:
        return 'Mardi';
      case Weekday.wed:
        return 'Mercredi';
      case Weekday.thu:
        return 'Jeudi';
      case Weekday.fri:
        return 'Vendredi';
      case Weekday.sat:
        return 'Samedi';
      case Weekday.sun:
        return 'Dimanche';
    }
  }

  void _addSlotToDay(Weekday weekday) {
    final slots = List<TimeSlot>.from(_days[weekday] ?? const <TimeSlot>[]);
    slots.add(const TimeSlot(start: '08:30', end: '17:30'));
    setState(() {
      _days[weekday] = slots;
    });
    _notifyChange();
  }

  void _updateSlotForDay(
    Weekday weekday,
    int index,
    TimeSlot slot,
  ) {
    final slots = List<TimeSlot>.from(_days[weekday] ?? const <TimeSlot>[]);
    if (index < 0 || index >= slots.length) return;
    slots[index] = slot;
    setState(() {
      _days[weekday] = slots;
    });
    _notifyChange();
  }

  void _removeSlotForDay(Weekday weekday, int index) {
    final slots = List<TimeSlot>.from(_days[weekday] ?? const <TimeSlot>[]);
    if (index >= 0 && index < slots.length) {
      slots.removeAt(index);
    }
    setState(() {
      _days[weekday] = slots;
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final weekday in Weekday.values)
          _DayCard(
            label: _weekdayLabel(weekday),
            slots: _days[weekday] ?? const <TimeSlot>[],
            onAddSlot: () => _addSlotToDay(weekday),
            onSlotChanged: (index, slot) =>
                _updateSlotForDay(weekday, index, slot),
            onSlotRemoved: (index) => _removeSlotForDay(weekday, index),
          ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.label,
    required this.slots,
    required this.onAddSlot,
    required this.onSlotChanged,
    required this.onSlotRemoved,
  });

  final String label;
  final List<TimeSlot> slots;
  final VoidCallback onAddSlot;
  final void Function(int index, TimeSlot slot) onSlotChanged;
  final void Function(int index) onSlotRemoved;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: onAddSlot,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un créneau'),
                ),
              ],
            ),
            Column(
              children: [
                for (var i = 0; i < slots.length; i++)
                  TimeSlotEditor(
                    key: ValueKey('$label-$i'),
                    slot: slots[i],
                    onChanged: (slot) => onSlotChanged(i, slot),
                    onRemove: () => onSlotRemoved(i),
                  ),
                if (slots.isEmpty)
                  Text(
                    'Aucun créneau défini',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
