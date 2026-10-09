import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../widgets/pill_calendar.dart';
import '../l10n/app_localizations.dart';

/// Screen 2 — Pill Calendar. Wraps the custom [PillCalendar] component.
/// See docs/ui-ux.md section 2.2.
class PillCalendarScreen extends StatefulWidget {
  const PillCalendarScreen({super.key});

  @override
  State<PillCalendarScreen> createState() => _PillCalendarScreenState();
}

class _PillCalendarScreenState extends State<PillCalendarScreen> {
  DateTime _month = DateTime.now();
  DateTime? _selectedDay;

  // TODO: load real per-day summary from LocalDbService / Firestore.
  final Map<DateTime, DoseStatus> _statusByDay = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)?.pillCalendarTitle ?? 'Pill calendar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocalizations.of(context)?.pillCalendarSubtitle ?? 'A clear view of your progress.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          PillCalendar(
            month: _month,
            statusByDay: _statusByDay,
            selectedDay: _selectedDay,
            onMonthChange: (m) => setState(() => _month = m),
            onDayTap: (d) => setState(() => _selectedDay = d),
          ),
          const SizedBox(height: 16),
          if (_selectedDay != null) _DayDetailPanel(day: _selectedDay!),
        ],
      ),
    );
  }
}

class _DayDetailPanel extends StatelessWidget {
  final DateTime day;

  const _DayDetailPanel({required this.day});

  @override
  Widget build(BuildContext context) {
    // TODO: query DoseLogs for `day` and list each medicine + status.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E3DD)),
      ),
      child: Text('${day.day}/${day.month}/${day.year} — ${AppLocalizations.of(context)?.detailsPlaceholder ?? 'details go here'}'),
    );
  }
}
