import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

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
          _buildLegend(context),
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
    final locale = Localizations.localeOf(context).toString();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
          onPressed: () =>
              onMonthChange(DateTime(month.year, month.month - 1)),
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat.yMMMM(locale).format(month),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textDark),
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
                  child: Text(
                    l, 
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: AppColors.textDark,
                      fontSize: 14,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
      child: Wrap(
        spacing: 16,
        children: [
          _LegendDot(color: AppColors.statusTaken, label: AppLocalizations.of(context)?.taken ?? 'Taken'),
          _LegendDot(color: AppColors.statusLate, label: AppLocalizations.of(context)?.statusLate ?? 'Late'),
          _LegendDot(color: AppColors.statusMissed, label: AppLocalizations.of(context)?.statusMissed ?? 'Missed'),
        ],
      ),
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
        return const Color(0xFFCEEDCD); // Matches mockup green
      case DoseStatus.late:
        return const Color(0xFFFEE1B4); // Matches mockup orange
      case DoseStatus.missed:
        return const Color(0xFFFBDAD6); // Matches mockup red
      default:
        return Colors.transparent;
    }
  }

  Color _textColor() {
    switch (status) {
      case DoseStatus.taken:
        return const Color(0xFF167B46);
      case DoseStatus.late:
        return const Color(0xFF8B4D00);
      case DoseStatus.missed:
        return const Color(0xFFB12F24);
      default:
        return AppColors.textDark;
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
          border: isSelected
              ? Border.all(color: AppColors.textDark, width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: _textColor(),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label, 
          style: const TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
