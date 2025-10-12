import 'package:flutter/material.dart';

import '../../planning/planning_models.dart';
import '../../planning/planning_resolver.dart';
import 'planner_types.dart';
import 'time_slot_editor.dart';

typedef AltWeeksPlannerChanged = void Function(AltWeeksSchema schema);

class AltWeeksPlannerForm extends StatefulWidget {
  const AltWeeksPlannerForm({
    super.key,
    required this.schema,
    required this.onChanged,
    this.onValidationError,
  });

  final AltWeeksSchema schema;
  final AltWeeksPlannerChanged onChanged;
  final PlannerValidationError? onValidationError;

  @override
  State<AltWeeksPlannerForm> createState() => _AltWeeksPlannerFormState();
}

class _AltWeeksPlannerFormState extends State<AltWeeksPlannerForm>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VoidCallback? _tabListener;
  late String _weekAStartIso;
  late WeeklySchema _weekA;
  late WeeklySchema _weekB;
  late List<ExceptionDay> _exceptions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _tabListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _tabController.addListener(_tabListener!);
    _weekAStartIso = widget.schema.weekAStartIso;
    _weekA = WeeklySchema(days: {
      for (final entry in widget.schema.weekA.days.entries)
        entry.key: List<TimeSlot>.from(entry.value),
    });
    _weekB = WeeklySchema(days: {
      for (final entry in widget.schema.weekB.days.entries)
        entry.key: List<TimeSlot>.from(entry.value),
    });
    _exceptions = widget.schema.exceptions.map((e) {
      return ExceptionDay(
        dateIso: e.dateIso,
        slots: List<TimeSlot>.from(e.slots),
      );
    }).toList();
  }

  @override
  void dispose() {
    if (_tabListener != null) {
      _tabController.removeListener(_tabListener!);
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickWeekAStart() async {
    final now = DateTime.now();
    final initialDate = DateTime.tryParse(_weekAStartIso) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      locale: const Locale('fr'),
      helpText: 'Début de la semaine A',
    );
    if (picked == null) return;
    setState(() => _weekAStartIso = toIsoDate(picked));
    _notifyChange();
  }

  void _notifyChange() {
    for (final entry in _weekA.days.entries) {
      if (hasOverlap(entry.value)) {
        widget.onValidationError?.call(
          'Chevauchement détecté dans la semaine A (${_weekdayLabel(entry.key)})',
        );
        return;
      }
    }
    for (final entry in _weekB.days.entries) {
      if (hasOverlap(entry.value)) {
        widget.onValidationError?.call(
          'Chevauchement détecté dans la semaine B (${_weekdayLabel(entry.key)})',
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
      AltWeeksSchema(
        weekAStartIso: _weekAStartIso,
        weekA: WeeklySchema(
          days: {
            for (final entry in _weekA.days.entries)
              entry.key: List<TimeSlot>.from(entry.value),
          },
        ),
        weekB: WeeklySchema(
          days: {
            for (final entry in _weekB.days.entries)
              entry.key: List<TimeSlot>.from(entry.value),
          },
        ),
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

  void _addSlot(WeeklySchema schema, Weekday weekday) {
    final isWeekA = identical(schema, _weekA);
    final current = List<TimeSlot>.from(
      schema.days[weekday] ?? const <TimeSlot>[],
    )..add(const TimeSlot(start: '08:30', end: '17:30'));

    final updated = Map<Weekday, List<TimeSlot>>.from(schema.days);
    updated[weekday] = current;

    setState(() {
      if (isWeekA) {
        _weekA = WeeklySchema(days: updated);
      } else {
        _weekB = WeeklySchema(days: updated);
      }
    });
    _notifyChange();
  }

  void _updateSlot(
    WeeklySchema schema,
    Weekday weekday,
    int index,
    TimeSlot slot,
  ) {
    final isWeekA = identical(schema, _weekA);
    final current = List<TimeSlot>.from(
      schema.days[weekday] ?? const <TimeSlot>[],
    );
    if (index < 0 || index >= current.length) return;
    current[index] = slot;
    final updated = Map<Weekday, List<TimeSlot>>.from(schema.days);
    updated[weekday] = current;
    setState(() {
      if (isWeekA) {
        _weekA = WeeklySchema(days: updated);
      } else {
        _weekB = WeeklySchema(days: updated);
      }
    });
    _notifyChange();
  }

  void _removeSlot(
    WeeklySchema schema,
    Weekday weekday,
    int index,
  ) {
    final isWeekA = identical(schema, _weekA);
    final current = List<TimeSlot>.from(
      schema.days[weekday] ?? const <TimeSlot>[],
    );
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);
    final updated = Map<Weekday, List<TimeSlot>>.from(schema.days);
    updated[weekday] = current;
    setState(() {
      if (isWeekA) {
        _weekA = WeeklySchema(days: updated);
      } else {
        _weekB = WeeklySchema(days: updated);
      }
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Début de la 1ère semaine de présence (Semaine A)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _pickWeekAStart,
              icon: const Icon(Icons.event),
              label: Text(_weekAStartIso.isEmpty
                  ? 'Choisir une date'
                  : _weekAStartIso),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choisissez le lundi de la première semaine de présence (Semaine A). Les semaines alterneront automatiquement.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey[700]),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.onSurface,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Semaine A'),
              Tab(text: 'Semaine B'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _WeekCardList(
            schema: _tabController.index == 0 ? _weekA : _weekB,
            onAddSlot: (weekday) {
              if (_tabController.index == 0) {
                _addSlot(_weekA, weekday);
              } else {
                _addSlot(_weekB, weekday);
              }
            },
            onSlotChanged: (weekday, index, slot) {
              if (_tabController.index == 0) {
                _updateSlot(_weekA, weekday, index, slot);
              } else {
                _updateSlot(_weekB, weekday, index, slot);
              }
            },
            onSlotRemoved: (weekday, index) {
              if (_tabController.index == 0) {
                _removeSlot(_weekA, weekday, index);
              } else {
                _removeSlot(_weekB, weekday, index);
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_exceptions.isNotEmpty)
          const SizedBox(height: 16),
      ],
    );
  }
}

class _WeekCardList extends StatelessWidget {
  const _WeekCardList({
    required this.schema,
    required this.onAddSlot,
    required this.onSlotChanged,
    required this.onSlotRemoved,
  });

  final WeeklySchema schema;
  final void Function(Weekday weekday) onAddSlot;
  final void Function(Weekday weekday, int index, TimeSlot slot) onSlotChanged;
  final void Function(Weekday weekday, int index) onSlotRemoved;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final weekday in Weekday.values)
          Card(
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
                        _weekdayLabel(weekday),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: () => onAddSlot(weekday),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un créneau'),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      for (var i = 0;
                          i < (schema.days[weekday]?.length ?? 0);
                          i++)
                        TimeSlotEditor(
                          key: ValueKey(
                              'week-${weekday.toKey()}-$i-${schema.days[weekday]?[i].start}'),
                          slot: schema.days[weekday]![i],
                          onChanged: (slot) =>
                              onSlotChanged(weekday, i, slot),
                          onRemove: () => onSlotRemoved(weekday, i),
                        ),
                      if ((schema.days[weekday]?.isEmpty ?? true))
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
          ),
      ],
    );
  }
}
