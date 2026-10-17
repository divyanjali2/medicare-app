import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/medicine.dart';
import '../models/user_profile.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';
import '../services/phone_call_service.dart';
import '../widgets/medicine_card.dart';
import '../widgets/medicines_modal.dart';
import '../widgets/pill_calendar.dart';

/// Read-only detail screen for a caregiver viewing a linked patient's data.
/// Enforces Layer 1: Caregiver can view PillCalendar and today's doses via
/// MedicineCard(readOnly: true), but has zero controls to add, edit, delete,
/// or log doses.
class PatientDetailScreen extends StatefulWidget {
  final UserProfile patient;

  const PatientDetailScreen({
    super.key,
    required this.patient,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  List<Medicine> _medicines = [];
  Map<DateTime, DoseStatus> _statusByDay = {};
  List<_ScheduledDose> _selectedDayDoses = [];
  List<_ScheduledDose> _todayDoses = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() => _isLoading = true);

    try {
      final patientId = widget.patient.uid;

      // 1. Fetch medicines
      final List<Medicine> meds = [];
      try {
        final localMeds = await LocalDbService.instance.getMedicines(patientId);
        meds.addAll(localMeds);
      } catch (_) {}

      try {
        final snap = await FirebaseFirestore.instance
            .collection('medicines')
            .where('patientId', isEqualTo: patientId)
            .get();
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] ??= doc.id;
          final m = Medicine.fromMap(data);
          if (!meds.any((x) => x.id == m.id)) {
            meds.add(m);
          }
        }
      } catch (_) {}

      // 2. Fetch dose logs for the month
      final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);

      final List<DoseLog> logs = [];
      try {
        final localLogs = await LocalDbService.instance.getDoseLogsForRange(monthStart, monthEnd);
        logs.addAll(localLogs);
      } catch (_) {}

      try {
        final snap = await FirebaseFirestore.instance
            .collection('dose_logs')
            .where('scheduledFor', isGreaterThanOrEqualTo: monthStart.toIso8601String())
            .where('scheduledFor', isLessThanOrEqualTo: monthEnd.toIso8601String())
            .get();
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] ??= doc.id;
          final l = DoseLog.fromMap(data);
          if (!logs.any((x) => x.id == l.id)) {
            logs.add(l);
          }
        }
      } catch (_) {}

      // 3. Compute statusByDay for the month
      final Map<DateTime, List<DoseLog>> logsByDay = {};
      for (final log in logs) {
        final dayKey = DateTime(log.scheduledFor.year, log.scheduledFor.month, log.scheduledFor.day);
        logsByDay.putIfAbsent(dayKey, () => []).add(log);
      }

      final Map<DateTime, DoseStatus> statusMap = {};
      logsByDay.forEach((day, dayLogs) {
        final summary = summarizeDay(dayLogs);
        if (summary != null) {
          statusMap[day] = summary;
        }
      });

      // 4. Derive scheduled doses for today and selected day
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      final todayList = _computeDosesForDay(todayDate, meds, logs);
      final selectedList = _computeDosesForDay(_selectedDate, meds, logs);

      if (mounted) {
        setState(() {
          _medicines = meds;
          _statusByDay = statusMap;
          _todayDoses = todayList;
          _selectedDayDoses = selectedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading patient detail: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<_ScheduledDose> _computeDosesForDay(
    DateTime targetDay,
    List<Medicine> meds,
    List<DoseLog> allLogs,
  ) {
    final List<_ScheduledDose> result = [];
    final now = DateTime.now();

    for (final med in meds) {
      final times = med.scheduledTimes.isNotEmpty
          ? med.scheduledTimes
          : [DateTime(targetDay.year, targetDay.month, targetDay.day, 8, 0)];

      for (final t in times) {
        final doseDateTime = DateTime(targetDay.year, targetDay.month, targetDay.day, t.hour, t.minute);

        // Find existing log
        DoseLog? matchedLog;
        for (final log in allLogs) {
          if (log.medicineId == med.id &&
              log.scheduledFor.year == doseDateTime.year &&
              log.scheduledFor.month == doseDateTime.month &&
              log.scheduledFor.day == doseDateTime.day &&
              log.scheduledFor.hour == doseDateTime.hour &&
              log.scheduledFor.minute == doseDateTime.minute) {
            matchedLog = log;
            break;
          }
        }

        DoseStatus status = matchedLog?.status ?? DoseStatus.pending;
        if (matchedLog == null) {
          if (doseDateTime.isBefore(now.subtract(const Duration(hours: 2)))) {
            status = DoseStatus.missed;
          } else {
            status = DoseStatus.pending;
          }
        }

        result.add(_ScheduledDose(
          medicine: med,
          time: doseDateTime,
          status: status,
        ));
      }
    }

    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  void _onDaySelected(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    setState(() {
      _selectedDate = normalized;
      _selectedDayDoses = _computeDosesForDay(normalized, _medicines, []);
    });
    // Reload full day breakdown from data
    _loadPatientData();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.patient.name,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0E7485),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  l10n?.caregiverView ?? 'Caregiver View',
                  style: const TextStyle(
                    color: Color(0xFF0E7485),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Color(0xFF2E7D4E)),
            tooltip: 'Call ${widget.patient.name}',
            onPressed: () {
              PhoneCallService.instance.makePhoneCall(
                context: context,
                phoneNumber: widget.patient.phoneNumber,
                recipientName: widget.patient.name,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.medication_outlined, color: AppColors.textDark),
            tooltip: 'View medicines',
            onPressed: () {
              showMedicinesModal(
                context: context,
                patientId: widget.patient.uid,
                patientName: widget.patient.name,
                isCaregiver: true,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandTeal))
          : SingleChildScrollView(
              key: const PageStorageKey('patient_detail_scroll_view'),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informational Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF0F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBCE1E6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20, color: Color(0xFF0E7485)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n?.scheduleManagedByPatient ??
                                'Medication schedule and dose logs are managed directly by the patient.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F3943),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 1: Pill Calendar
                  Text(
                    l10n?.adherenceCalendar ?? (l10n?.calendar ?? 'Adherence Calendar'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap a day to inspect medication adherence history.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  PillCalendar(
                    month: _currentMonth,
                    statusByDay: _statusByDay,
                    selectedDay: _selectedDate,
                    onDayTap: _onDaySelected,
                    onMonthChange: (newMonth) {
                      setState(() => _currentMonth = newMonth);
                      _loadPatientData();
                    },
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Selected Day Breakdown (Read-Only)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E4E8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM d').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Day Details',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_selectedDayDoses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No scheduled doses recorded for this day.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          )
                        else
                          ..._selectedDayDoses.map((dose) => _buildDayDoseItem(dose)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Section 3: Today's Doses
                  Text(
                    l10n?.todaysDoses ?? (l10n?.today ?? "Today's Doses"),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_todayDoses.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E4E8)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.check_circle_outline, color: Color(0xFF2E7D4E), size: 36),
                          SizedBox(height: 8),
                          Text(
                            'No doses scheduled for today.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._todayDoses.map(
                      (dose) => MedicineCard(
                        medicine: dose.medicine,
                        doseTime: dose.time,
                        status: dose.status,
                        readOnly: true,
                        onTap: () {
                          showMedicineDetailModal(
                            context: context,
                            medicine: dose.medicine,
                            isCaregiver: true,
                            patientId: widget.patient.uid,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildDayDoseItem(_ScheduledDose dose) {
    final (String label, Color color, IconData icon) = switch (dose.status) {
      DoseStatus.taken => ('Taken', AppColors.statusTaken, Icons.check_circle_outline),
      DoseStatus.skipped => ('Skipped', AppColors.statusLate, Icons.skip_next_outlined),
      DoseStatus.late => ('Late', AppColors.statusLate, Icons.access_time),
      DoseStatus.missed => ('Missed', AppColors.statusMissed, Icons.cancel_outlined),
      DoseStatus.pending => ('Pending', AppColors.textMuted, Icons.hourglass_empty),
    };

    final timeStr = DateFormat('hh:mm a').format(dose.time);

    return InkWell(
      onTap: () {
        showMedicineDetailModal(
          context: context,
          medicine: dose.medicine,
          isCaregiver: true,
          patientId: widget.patient.uid,
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicine.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  '$timeStr • ${dose.medicine.dosage}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _ScheduledDose {
  final Medicine medicine;
  final DateTime time;
  final DoseStatus status;

  _ScheduledDose({
    required this.medicine,
    required this.time,
    required this.status,
  });
}