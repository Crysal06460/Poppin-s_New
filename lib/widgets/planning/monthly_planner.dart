import 'package:flutter/material.dart';

import '../../planning/planning_models.dart';
import '../../planning/planning_resolver.dart';
import 'planner_types.dart';
import 'time_slot_editor.dart';

typedef MonthlyPlannerChanged = void Function(MonthlySchema schema);

class MonthlyPlanner extends StatefulWidget {
  const MonthlyPlanner({
    super.key,
    required this.schema,
    this.onValidationError,
    required this.onChanged,
  });

  final MonthlySchema schema;
  final MonthlyPlannerChanged onChanged;
  final PlannerValidationError? onValidationError;

  @override
  State<MonthlyPlanner> createState() => _MonthlyPlannerState();
}

class _MonthlyPlannerState extends State<MonthlyPlanner> {
  late DateTime _focusedMonth;
  late Map<String, MonthData> _months;
  WeeklySchema? _fallback;

  @override
  void initState() {
    super.initState();
    _focusedMonth = _initialMonth();
    _months = _cloneMonths(widget.schema.months);
    _fallback = _cloneWeeklySchema(widget.schema.fallback);
  }

  @override
  void didUpdateWidget(covariant MonthlyPlanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _months = _cloneMonths(widget.schema.months);
    _fallback = _cloneWeeklySchema(widget.schema.fallback);
  }

  DateTime _initialMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  MonthData _ensureMonth(DateTime month) {
    final key = toYearMonth(month);
    return _months.putIfAbsent(
      key,
      () => const MonthData(days: <String, List<TimeSlot>>{}),
    );
  }

  void _setMonthData(DateTime month, MonthData data) {
    setState(() {
      final key = toYearMonth(month);
      final filteredDays = {
        for (final entry in data.days.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      };

      if (filteredDays.isEmpty) {
        _months.remove(key);
      } else {
        _months[key] = MonthData(days: filteredDays);
      }
      _fallback = null;
    });
    _notifyChange();
  }

  void _notifyChange() {
    for (final month in _months.values) {
      for (final entry in month.days.entries) {
        if (hasOverlap(entry.value)) {
          widget.onValidationError?.call(
            'Chevauchement détecté le ${entry.key}',
          );
          return;
        }
      }
    }
    widget.onChanged(_buildSchema());
  }

  void _changeMonth(int offset) {
    final newDate = DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    setState(() => _focusedMonth = newDate);
  }

  MonthlySchema _buildSchema() {
    return _buildSchemaFromState(_months, _fallback);
  }

  void _editDay(DateTime day) {
    final dayKey = toIsoDate(day);
    final month = _ensureMonth(day);
    final List<TimeSlot> slots = List<TimeSlot>.from(
      month.days[dayKey] ?? const <TimeSlot>[],
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _DayEditorBottomSheet(
            day: day,
            initialSlots: slots,
            onApply: (updatedSlots, {bool copyPrevious = false}) {
              final updatedDays = {
                for (final entry in month.days.entries)
                  entry.key: List<TimeSlot>.from(entry.value),
              };
              updatedDays[dayKey] = List<TimeSlot>.from(updatedSlots);
              _setMonthData(day, MonthData(days: updatedDays));
              if (copyPrevious) {
                final prevDay = day.subtract(const Duration(days: 1));
                final prevMonth = _ensureMonth(prevDay);
                final List<TimeSlot> prevSlots =
                    prevMonth.days[toIsoDate(prevDay)] ?? const <TimeSlot>[];
                final prevDays = {
                  for (final entry in prevMonth.days.entries)
                    entry.key: List<TimeSlot>.from(entry.value),
                };
                prevDays[toIsoDate(prevDay)] = List<TimeSlot>.from(prevSlots);
                _setMonthData(prevDay, MonthData(days: prevDays));
              }
            },
            onClear: () {
              final updatedDays = {
                for (final entry in month.days.entries)
                  entry.key: List<TimeSlot>.from(entry.value)
              }..remove(dayKey);
              _setMonthData(
                day,
                MonthData(days: updatedDays),
              );
            },
            onCopyPrevious: () {
              final prevDay = day.subtract(const Duration(days: 1));
              final prevMonth = _ensureMonth(prevDay);
              final List<TimeSlot> prevSlots =
                  prevMonth.days[toIsoDate(prevDay)] ?? const <TimeSlot>[];
              final updatedDays = {
                for (final entry in month.days.entries)
                  entry.key: List<TimeSlot>.from(entry.value)
              };
              updatedDays[dayKey] = List<TimeSlot>.from(prevSlots);
              _setMonthData(day, MonthData(days: updatedDays));
            },
          ),
        );
      },
    );
  }

  void _duplicatePreviousMonth() {
    final previous = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    final prevData = _months[toYearMonth(previous)];
    if (prevData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun mois précédent à dupliquer.')),
      );
      return;
    }
    final copied = MonthData(
      days: {
        for (final entry in prevData.days.entries)
          entry.key: List<TimeSlot>.from(entry.value),
      },
    );
    setState(() {
      _months[toYearMonth(_focusedMonth)] = copied;
      _fallback = null;
    });
    _notifyChange();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mois dupliqué avec succès.')),
    );
  }

  void _clearMonth() {
    setState(() {
      _months.remove(toYearMonth(_focusedMonth));
      _fallback = null;
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        MaterialLocalizations.of(context).formatMonthYear(_focusedMonth);
    final month = _ensureMonth(_focusedMonth);
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final firstDayWeekday =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    final leadingEmpty =
        (firstDayWeekday + 6) % 7; // convert Monday=1 to index 0
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              monthLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Cliquez sur un jour pour définir les créneaux. Utilisez « Dupliquer le mois précédent » pour gagner du temps.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: PopupMenuButton<_MonthAction>(
            onSelected: (action) {
              switch (action) {
                case _MonthAction.duplicatePrevious:
                  _duplicatePreviousMonth();
                case _MonthAction.clear:
                  _clearMonth();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _MonthAction.duplicatePrevious,
                child: Text('Dupliquer le mois précédent'),
              ),
              PopupMenuItem(
                value: _MonthAction.clear,
                child: Text('Effacer tout le mois'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CalendarGrid(
          totalCells: totalCells,
          leadingEmpty: leadingEmpty,
          daysInMonth: daysInMonth,
          focusedMonth: _focusedMonth,
          month: month,
          onDayTap: _editDay,
        ),
      ],
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
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.totalCells,
    required this.leadingEmpty,
    required this.daysInMonth,
    required this.focusedMonth,
    required this.month,
    required this.onDayTap,
  });

  final int totalCells;
  final int leadingEmpty;
  final int daysInMonth;
  final DateTime focusedMonth;
  final MonthData month;
  final void Function(DateTime day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final headers = const ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final header in headers)
              Expanded(
                child: Center(
                  child: Text(
                    header,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayIndex = index - leadingEmpty + 1;
            if (dayIndex <= 0 || dayIndex > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = DateTime(
              focusedMonth.year,
              focusedMonth.month,
              dayIndex,
            );
            final dayKey = toIsoDate(date);
            final hasSlots = (month.days[dayKey]?.isNotEmpty ?? false);

            return GestureDetector(
              onTap: () => onDayTap(date),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: hasSlots
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayIndex.toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (hasSlots)
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DayEditorBottomSheet extends StatefulWidget {
  const _DayEditorBottomSheet({
    required this.day,
    required this.initialSlots,
    required this.onApply,
    required this.onClear,
    required this.onCopyPrevious,
  });

  final DateTime day;
  final List<TimeSlot> initialSlots;
  final void Function(List<TimeSlot> slots, {bool copyPrevious}) onApply;
  final VoidCallback onClear;
  final VoidCallback onCopyPrevious;

  @override
  State<_DayEditorBottomSheet> createState() => _DayEditorBottomSheetState();
}

class _DayEditorBottomSheetState extends State<_DayEditorBottomSheet> {
  late List<TimeSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = widget.initialSlots
        .map((slot) => TimeSlot(start: slot.start, end: slot.end))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  toIsoDate(widget.day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            for (var i = 0; i < _slots.length; i++)
              TimeSlotEditor(
                slot: _slots[i],
                onChanged: (slot) {
                  _slots[i] = slot;
                },
                onRemove: () {
                  setState(() {
                    _slots.removeAt(i);
                  });
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _slots.add(const TimeSlot(start: '08:30', end: '17:30'));
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un créneau'),
              ),
            ),
            const Divider(),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCopyPrevious();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Copier la veille'),
                ),
                TextButton(
                  onPressed: () {
                    _slots.clear();
                    widget.onClear();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Effacer la journée'),
                ),
                FilledButton(
                  onPressed: () {
                    widget.onApply([..._slots], copyPrevious: false);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _MonthAction { duplicatePrevious, clear }

Map<String, MonthData> _cloneMonths(Map<String, MonthData> source) {
  return {
    for (final entry in source.entries)
      entry.key: MonthData(
        days: {
          for (final dayEntry in entry.value.days.entries)
            dayEntry.key: List<TimeSlot>.from(dayEntry.value),
        },
      ),
  };
}

WeeklySchema? _cloneWeeklySchema(WeeklySchema? schema) {
  if (schema == null) return null;
  final days = {
    for (final entry in schema.days.entries)
      entry.key: List<TimeSlot>.from(entry.value),
  };
  for (final weekday in Weekday.values) {
    days.putIfAbsent(weekday, () => <TimeSlot>[]);
  }
  return WeeklySchema(days: days);
}

MonthlySchema _buildSchemaFromState(
  Map<String, MonthData> months,
  WeeklySchema? fallback,
) {
  final cleanedMonths = <String, MonthData>{};
  for (final entry in months.entries) {
    final cleanedDays = <String, List<TimeSlot>>{};
    for (final dayEntry in entry.value.days.entries) {
      if (dayEntry.value.isEmpty) continue;
      cleanedDays[dayEntry.key] = List<TimeSlot>.from(dayEntry.value);
    }
    if (cleanedDays.isNotEmpty) {
      cleanedMonths[entry.key] = MonthData(days: cleanedDays);
    }
  }
  return MonthlySchema(
    months: cleanedMonths,
    fallback: _cloneWeeklySchema(fallback),
  );
}
