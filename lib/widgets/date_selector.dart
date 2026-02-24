import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final Color primaryColor;

  const DateSelector({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
    this.primaryColor = const Color(0xFF3D9DF2),
  }) : super(key: key);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _previousWorkingDay {
    // Si lundi (1), on recule de 3 jours pour arriver à vendredi
    // Sinon on recule de 1 jour
    if (_today.weekday == DateTime.monday) {
      return _today.subtract(const Duration(days: 3));
    }
    return _today.subtract(const Duration(days: 1));
  }

  bool get _isToday => isSameDay(selectedDate, _today);
  
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final previousDate = _previousWorkingDay;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDateButton(
              context,
              date: previousDate,
              isSelected: !_isToday,
              label: _formatDateLabel(previousDate),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildDateButton(
              context,
              date: _today,
              isSelected: _isToday,
              label: "Aujourd'hui",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(
    BuildContext context, {
    required DateTime date,
    required bool isSelected,
    required String label,
  }) {
    return GestureDetector(
      onTap: () => onDateSelected(date),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
          border: isSelected
              ? Border.all(color: primaryColor.withOpacity(0.3))
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? primaryColor : Colors.grey.shade600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 2),
              Text(
                DateFormat('dd MMM', 'fr_FR').format(date),
                style: TextStyle(
                  fontSize: 11,
                  color: primaryColor.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  String _formatDateLabel(DateTime date) {
    if (date.weekday == DateTime.friday && _today.weekday == DateTime.monday) {
      return "Vendredi";
    }
    return "Hier";
  }
}
