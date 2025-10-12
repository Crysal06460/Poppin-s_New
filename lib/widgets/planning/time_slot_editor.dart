import 'package:flutter/material.dart';

import '../../planning/planning_models.dart';
import '../../planning/planning_resolver.dart';

typedef TimeSlotChanged = void Function(TimeSlot slot);
typedef TimeSlotRemoved = void Function();

class TimeSlotEditor extends StatefulWidget {
  const TimeSlotEditor({
    super.key,
    required this.slot,
    required this.onChanged,
    this.onRemove,
  });

  final TimeSlot slot;
  final TimeSlotChanged onChanged;
  final TimeSlotRemoved? onRemove;

  @override
  State<TimeSlotEditor> createState() => _TimeSlotEditorState();
}

class _TimeSlotEditorState extends State<TimeSlotEditor> {
  late TextEditingController _startController;
  late TextEditingController _endController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: widget.slot.start);
    _endController = TextEditingController(text: widget.slot.end);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final start = _startController.text;
    final end = _endController.text;

    if (start.isEmpty || end.isEmpty) {
      setState(() => _error = 'Veuillez remplir les heures de début et de fin');
      return;
    }
    if (start.compareTo(end) >= 0) {
      setState(() => _error = 'L\'heure de fin doit être après l\'heure de début');
      return;
    }
    setState(() => _error = null);
    widget.onChanged(TimeSlot(start: start, end: end));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final controller = isStart ? _startController : _endController;
    TimeOfDay initialTime;
    if (controller.text.isNotEmpty && controller.text.contains(':')) {
      final parts = controller.text.split(':');
      final hour = int.tryParse(parts.first) ?? 0;
      final minute = int.tryParse(parts.last) ?? 0;
      initialTime = TimeOfDay(hour: hour, minute: minute);
    } else {
      initialTime = TimeOfDay.now();
    }

    final theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: theme.colorScheme.surface,
              hourMinuteTextColor: primary,
              dayPeriodTextColor: primary,
              dialHandColor: primary,
              dialBackgroundColor: primary.withOpacity(0.08),
              hourMinuteColor: MaterialStateColor.resolveWith(
                (states) => states.contains(MaterialState.selected)
                    ? primary.withOpacity(0.15)
                    : Colors.transparent,
              ),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _startController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Début (HH:mm)',
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _endController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Fin (HH:mm)',
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Supprimer ce créneau',
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
