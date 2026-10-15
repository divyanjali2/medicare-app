import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medicine.dart';
import '../theme/app_theme.dart';

/// A month-grid calendar widget that displays daily medication adherence status.
///
/// Hand-built using core Flutter widgets for elderly patient accessibility.
///
/// Properties:
/// - [month]: The [DateTime] representing the current month being viewed.
/// - [statusByDay]: A [Map] of normalized [DateTime] (keys normalized to y/m/d with no time)
///   to [DoseStatus] representing each day's adherence status.
/// - [selectedDay]: An optional [DateTime] for the currently selected day.
///
/// Events:
/// - [onDayTap]: Callback invoked with the selected [DateTime] when a day cell is tapped.
/// - [onMonthChange]: Callback invoked with the previous/next month [DateTime] when chevrons are tapped.
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
    // Sunday first: Sunday is weekday 7 in Dart, 7 % 7 = 0 leading blanks.
    final leadingBlanks = firstOfMonth.weekday % 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E3DD), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
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
              if (index < leadingBlanks) {
                return const SizedBox.shrink();
              }
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
          const SizedBox(height: 16),
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

  Widget _buildHeader() {
    final monthTitle = DateFormat('MMMM yyyy').format(month);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          tooltip: 'Previous month',
          onPressed: () =>
              onMonthChange(DateTime(month.year, month.month - 1)),
        ),
        Text(
          monthTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          tooltip: 'Next month',
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
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildLegend() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: AppColors.statusTaken, label: 'Taken'),
        SizedBox(width: 16),
        _LegendDot(color: AppColors.statusLate, label: 'Late'),
        SizedBox(width: 16),
        _LegendDot(color: AppColors.statusMissed, label: 'Missed'),
      ],
    );
  }
}

/// A single day in the month grid, showing date number, ring status, and adherence color.
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

  Color _backgroundColor() {
    switch (status) {
      case DoseStatus.taken:
        return AppColors.statusTaken.withValues(alpha: 0.25);
      case DoseStatus.late:
        return AppColors.statusLate.withValues(alpha: 0.30);
      case DoseStatus.missed:
        return AppColors.statusMissed.withValues(alpha: 0.25);
      case DoseStatus.pending:
      case null:
        return Colors.transparent;
    }
  }

  Border? _border() {
    // Selected day ring takes priority over the today ring.
    if (isSelected) {
      return Border.all(color: AppColors.primaryTeal, width: 3);
    }
    if (isToday) {
      return Border.all(color: AppColors.textPrimary, width: 2);
    }
    return null;
  }

  String _semanticsLabel() {
    final statusLabel = switch (status) {
      DoseStatus.taken => 'taken',
      DoseStatus.late => 'late',
      DoseStatus.missed => 'missed',
      DoseStatus.pending => 'pending',
      null => 'no doses',
    };
    return '${date.day}, $statusLabel';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _semanticsLabel(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _backgroundColor(),
              border: _border(),
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget displaying a colored adherence dot with its descriptive text label.
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
