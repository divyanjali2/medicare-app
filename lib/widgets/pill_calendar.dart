import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../theme/app_theme.dart';

/// Custom component (built by the student, not from a library) that shows
/// a month grid color-coded by daily adherence status.
///
/// Properties:
/// - [month]            : the month currently displayed
/// - [statusByDay]       : Map<DateTime, DoseStatus> — one summarized status
///                         per calendar day (green/amber/red)
/// - [selectedDay]       : the currently highlighted day
///
/// Events:
/// - [onDayTap]          : fired when the user taps a day cell
/// - [onMonthChange]     : fired when the user navigates to prev/next month
class PillCalendar extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, DoseStatus> statusByDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onMonthChange;

  const PillCalendar({
    super.key,
    required this.month,
    required this.statusByDay,
    required this.onDayTap,
    required this.onMonthChange,
    this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // Sun = 0

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E3DD)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          _buildWeekdayLabels(),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = index - leadingBlanks + 1;
              final date = DateTime(month.year, month.month, day);
              return _DayCell(
                date: date,
                status: _statusFor(date),
                isSelected: _isSameDay(date, selectedDay),
                isToday: _isSameDay(date, DateTime.now()),
                onTap: () => onDayTap(date),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  DoseStatus? _statusFor(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return statusByDay[key];
  }

  bool _isSameDay(DateTime a, DateTime? b) {
    if (b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildHeader(BuildContext context) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () =>
              onMonthChange(DateTime(month.year, month.month - 1)),
        ),
        Text(
          '${months[month.month - 1]} ${month.year}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () =>
              onMonthChange(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels() {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: labels
          .map((l) => Expanded(
                child: Center(
                  child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      children: const [
        _LegendDot(color: AppColors.statusTaken, label: 'Taken'),
        _LegendDot(color: AppColors.statusLate, label: 'Late'),
        _LegendDot(color: AppColors.statusMissed, label: 'Missed'),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final DoseStatus? status;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.status,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  Color _bgColor() {
    switch (status) {
      case DoseStatus.taken:
        return AppColors.statusTaken.withOpacity(0.25);
      case DoseStatus.late:
        return AppColors.statusLate.withOpacity(0.3);
      case DoseStatus.missed:
        return AppColors.statusMissed.withOpacity(0.25);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _bgColor(),
          shape: BoxShape.circle,
          border: isToday
              ? Border.all(color: AppColors.textPrimary, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text('${date.day}'),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
