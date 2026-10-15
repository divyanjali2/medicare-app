import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medicine.dart';
import '../widgets/pill_calendar.dart';
import '../widgets/language_selector.dart';
import '../widgets/profile_menu_button.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import 'caregiver_screen.dart';
import 'today_dashboard_screen.dart';
import 'add_medicine_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/local_db_service.dart';

class PillCalendarScreen extends StatefulWidget {
  final String? viewingPatientId;
  final String? viewingPatientName;

  const PillCalendarScreen({
    super.key,
    this.viewingPatientId,
    this.viewingPatientName,
  });

  @override
  State<PillCalendarScreen> createState() => _PillCalendarScreenState();
}

class _CalendarDayDose {
  final Medicine medicine;
  final DateTime scheduledFor;
  DoseStatus status;
  final String? doseLogId;

  _CalendarDayDose({
    required this.medicine,
    required this.scheduledFor,
    required this.status,
    this.doseLogId,
  });
}

class _PillCalendarScreenState extends State<PillCalendarScreen> {
  final int _currentIndex = 1; // Calendar tab
  String _effectivePatientId = 'p1';
  bool _isCaregiverMode = false;
  String _patientName = '';

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  Map<DateTime, DoseStatus> _statusByDay = {};
  final Map<String, Medicine> _medicines = {};
  final Map<String, DoseLog> _monthLogsByKey = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolvePatient();
  }

  Future<void> _resolvePatient() async {
    final currentUid = AuthService.instance.currentUser?.uid;
    final profile = await AuthService.instance.fetchCurrentUserProfile(currentUid);

    String patientId = widget.viewingPatientId ?? '';
    bool caregiverMode = widget.viewingPatientId != null;

    if (profile?.role == UserRole.caregiver) {
      caregiverMode = true;
      if (patientId.isEmpty && profile!.linkedPatientIds.isNotEmpty) {
        patientId = profile.linkedPatientIds.first;
      }
    }

    if (patientId.isEmpty) {
      patientId = currentUid ?? (profile?.uid ?? 'p1');
    }

    if (mounted) {
      setState(() {
        _effectivePatientId = patientId;
        _isCaregiverMode = caregiverMode;
        _patientName = widget.viewingPatientName ?? profile?.name ?? 'Patient';
      });
      await _loadCalendarData();
    }
  }

  /// Loads real medicines and dose logs from offline database and Firestore,
  /// then calculates adherence for each day of the active month using summarizeDay.
  Future<void> _loadCalendarData() async {
    setState(() => _isLoading = true);

    try {
      final patientId = _effectivePatientId;

      // 1. Fetch medicines from local DB & Firestore
      _medicines.clear();

      try {
        final localMeds = await LocalDbService.instance.getMedicines(patientId);
        for (final m in localMeds) {
          _medicines[m.id] = m;
        }
      } catch (e) {
        debugPrint('Error loading local medicines for calendar: $e');
      }

      try {
        final snap = await FirebaseFirestore.instance
            .collection('medicines')
            .where('patientId', isEqualTo: patientId)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          data['id'] ??= doc.id;
          final med = Medicine.fromMap(data);
          _medicines[med.id] = med;
          await LocalDbService.instance.upsertMedicine(med);
        }
      } catch (_) {}

      try {
        final subSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .collection('medicines')
            .get();
        for (final doc in subSnap.docs) {
          final data = doc.data();
          data['id'] ??= doc.id;
          final med = Medicine.fromMap(data);
          _medicines[med.id] = med;
          await LocalDbService.instance.upsertMedicine(med);
        }
      } catch (_) {}

      // 2. Fetch dose logs for the month
      _monthLogsByKey.clear();
      final monthStart = DateTime(_month.year, _month.month, 1);
      final monthEnd = DateTime(_month.year, _month.month + 1, 1);

      try {
        final localLogs = await LocalDbService.instance.getDoseLogsForRange(monthStart, monthEnd);
        for (final log in localLogs) {
          final key = '${log.medicineId}_${log.scheduledFor.year}_${log.scheduledFor.month}_${log.scheduledFor.day}_${log.scheduledFor.hour}_${log.scheduledFor.minute}';
          _monthLogsByKey[key] = log;
          final dayKey = '${log.medicineId}_${log.scheduledFor.year}_${log.scheduledFor.month}_${log.scheduledFor.day}';
          _monthLogsByKey.putIfAbsent(dayKey, () => log);
        }
      } catch (e) {
        debugPrint('Error loading local logs for calendar: $e');
      }

      try {
        final startStr = monthStart.toIso8601String();
        final endStr = monthEnd.toIso8601String();
        final remoteLogs = await FirebaseFirestore.instance
            .collection('dose_logs')
            .where('scheduledFor', isGreaterThanOrEqualTo: startStr)
            .where('scheduledFor', isLessThan: endStr)
            .get();
        for (final doc in remoteLogs.docs) {
          final data = doc.data();
          data['id'] ??= doc.id;
          final log = DoseLog.fromMap(data);
          final key = '${log.medicineId}_${log.scheduledFor.year}_${log.scheduledFor.month}_${log.scheduledFor.day}_${log.scheduledFor.hour}_${log.scheduledFor.minute}';
          _monthLogsByKey[key] = log;
          final dayKey = '${log.medicineId}_${log.scheduledFor.year}_${log.scheduledFor.month}_${log.scheduledFor.day}';
          _monthLogsByKey.putIfAbsent(dayKey, () => log);
          await LocalDbService.instance.upsertDoseLog(log);
        }
      } catch (_) {}

      // 3. Calculate summarizeDay for each day of the month
      final Map<DateTime, DoseStatus> newStatusByDay = {};
      final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

      for (int d = 1; d <= daysInMonth; d++) {
        final dayDate = DateTime(_month.year, _month.month, d);
        final dayDoses = _getDosesForDay(dayDate);
        if (dayDoses.isNotEmpty) {
          final logs = dayDoses
              .map((dose) => DoseLog(
                    id: dose.doseLogId ?? 'gen_${dose.medicine.id}_${dayDate.day}',
                    medicineId: dose.medicine.id,
                    scheduledFor: dose.scheduledFor,
                    status: dose.status,
                  ))
              .toList();

          final status = summarizeDay(logs);
          if (status != null) {
            newStatusByDay[dayDate] = status;
          }
        }
      }

      if (mounted) {
        setState(() {
          _statusByDay = newStatusByDay;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading calendar data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Gets all doses scheduled for a specific day from the patient's active medicines.
  List<_CalendarDayDose> _getDosesForDay(DateTime day) {
    final List<_CalendarDayDose> result = [];
    final dayNormalized = DateTime(day.year, day.month, day.day);
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);

    for (final med in _medicines.values) {
      final medCreatedDay = DateTime(med.createdAt.year, med.createdAt.month, med.createdAt.day);
      // Skip days before medicine was added
      if (dayNormalized.isBefore(medCreatedDay)) {
        continue;
      }

      final times = med.scheduledTimes.isNotEmpty
          ? med.scheduledTimes
          : [DateTime(day.year, day.month, day.day, 8, 0)];

      for (final t in times) {
        final scheduledDateTime = DateTime(day.year, day.month, day.day, t.hour, t.minute);
        final fullKey = '${med.id}_${day.year}_${day.month}_${day.day}_${t.hour}_${t.minute}';
        final dayKey = '${med.id}_${day.year}_${day.month}_${day.day}';

        final log = _monthLogsByKey[fullKey] ?? _monthLogsByKey[dayKey];

        DoseStatus doseStatus;
        if (log != null) {
          doseStatus = log.status;
        } else {
          // If no log exists:
          // Past days: missed. Today past dose time (>60m ago): missed. Today upcoming/future: pending.
          if (dayNormalized.isBefore(todayNormalized)) {
            doseStatus = DoseStatus.missed;
          } else if (dayNormalized.isAtSameMomentAs(todayNormalized)) {
            if (scheduledDateTime.isBefore(now.subtract(const Duration(hours: 1)))) {
              doseStatus = DoseStatus.missed;
            } else {
              doseStatus = DoseStatus.pending;
            }
          } else {
            doseStatus = DoseStatus.pending;
          }
        }

        result.add(
          _CalendarDayDose(
            medicine: med,
            scheduledFor: scheduledDateTime,
            status: doseStatus,
            doseLogId: log?.id,
          ),
        );
      }
    }

    result.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return result;
  }

  /// Marks a dose as taken and persists to local DB and Firestore.
  Future<void> _markDoseTaken(_CalendarDayDose dose) async {
    final now = DateTime.now();
    final logId = dose.doseLogId ??
        'log_${dose.medicine.id}_${dose.scheduledFor.millisecondsSinceEpoch}';

    // If taken within 60 mins of schedule -> taken; if >60 mins late -> late
    final diffMinutes = now.difference(dose.scheduledFor).inMinutes;
    final newStatus = diffMinutes > 60 ? DoseStatus.late : DoseStatus.taken;

    final newLog = DoseLog(
      id: logId,
      medicineId: dose.medicine.id,
      scheduledFor: dose.scheduledFor,
      status: newStatus,
      respondedAt: now,
      synced: false,
    );

    // Save locally
    await LocalDbService.instance.upsertDoseLog(newLog);

    // Push to Firestore if connected
    try {
      await FirebaseFirestore.instance.collection('dose_logs').doc(logId).set(
        newLog.toMap()..['patientId'] = _effectivePatientId,
        SetOptions(merge: true),
      );
    } catch (_) {}

    // Reload calendar data to refresh color dots and panel
    await _loadCalendarData();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    Widget nextScreen;
    if (index == 0) {
      nextScreen = TodayDashboardScreen(
        viewingPatientId: _isCaregiverMode ? _effectivePatientId : null,
        viewingPatientName: _isCaregiverMode ? _patientName : null,
      );
    } else if (index == 2) {
      nextScreen = AddMedicineScreen(
        patientId: _isCaregiverMode ? _effectivePatientId : null,
        patientName: _isCaregiverMode ? _patientName : null,
      );
    } else if (index == 3 && _isCaregiverMode) {
      nextScreen = const CaregiverScreen();
    } else {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (r) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (Navigator.of(context).canPop())
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isCaregiverMode ? AppColors.brandNavy : AppColors.brandTeal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              _isCaregiverMode ? Icons.people_outline : Icons.monitor_heart,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.appName ?? 'MediCare',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                _isCaregiverMode
                                    ? 'Caregiver View • Patient Calendar'
                                    : (l10n?.patientViewSubtitle ?? 'Patient view'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isCaregiverMode ? AppColors.brandNavy : AppColors.textMuted,
                                  fontWeight: _isCaregiverMode ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LanguagePillSelector(),
                      SizedBox(width: 8),
                      ProfileMenuButton(),
                    ],
                  ),
                ],
              ),
            ),
            if (_isCaregiverMode)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brandNavy.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.brandNavy, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Monitoring $_patientName\'s calendar',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandNavy,
                        ),
                      ),
                    ),
                    if (Navigator.of(context).canPop())
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Exit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandNavy,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  Text(
                    l10n?.pillCalendarTitle ?? 'Pill calendar',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.pillCalendarSubtitle ?? 'A clear view of your progress.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFFE5E3DD),
                        color: AppColors.primaryTeal,
                        minHeight: 3,
                      ),
                    ),
                  PillCalendar(
                    month: _month,
                    statusByDay: _statusByDay,
                    selectedDay: _selectedDay,
                    onMonthChange: (m) {
                      setState(() {
                        _month = m;
                        _selectedDay = DateTime(m.year, m.month, 1);
                      });
                      _loadCalendarData();
                    },
                    onDayTap: (d) => setState(() => _selectedDay = d),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedDay != null)
                    _DayDetailPanel(
                      day: _selectedDay!,
                      doses: _getDosesForDay(_selectedDay!),
                      onTakeDose: _markDoseTaken,
                      isCaregiverMode: _isCaregiverMode,
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.brandTeal,
          unselectedItemColor: AppColors.textMuted,
          backgroundColor: Colors.white,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          onTap: _onTabTapped,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.calendar_month, color: AppColors.brandTeal),
              ),
              label: 'Calendar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add),
              label: 'Add',
            ),
            if (_isCaregiverMode)
              BottomNavigationBarItem(
                icon: const Icon(Icons.people_outline),
                activeIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF0F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.people, color: Color(0xFF0E7485)),
                ),
                label: 'Care',
              ),
          ],
        ),
      ),
    );
  }
}

class _DayDetailPanel extends StatelessWidget {
  final DateTime day;
  final List<_CalendarDayDose> doses;
  final ValueChanged<_CalendarDayDose> onTakeDose;
  final bool isCaregiverMode;

  const _DayDetailPanel({
    required this.day,
    required this.doses,
    required this.onTakeDose,
    required this.isCaregiverMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeStr = Localizations.localeOf(context).toString();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy', localeStr).format(day);

    final logs = doses
        .map((d) => DoseLog(
              id: d.doseLogId ?? '',
              medicineId: d.medicine.id,
              scheduledFor: d.scheduledFor,
              status: d.status,
            ))
        .toList();
    final dayStatus = summarizeDay(logs);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E3DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildSummaryHeader(dayStatus, l10n),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: AppColors.borderSubtle),
          ),
          if (doses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No medicines scheduled for this day.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: doses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final dose = doses[index];
                return _buildDoseRow(context, dose);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(DoseStatus? status, AppLocalizations? l10n) {
    String title;
    Color iconBg;
    IconData icon;

    switch (status) {
      case DoseStatus.taken:
        title = l10n?.allTakenTitle ?? 'All taken';
        iconBg = AppColors.statusTaken;
        icon = Icons.check;
        break;
      case DoseStatus.late:
        title = 'Taken late';
        iconBg = AppColors.statusLate;
        icon = Icons.done_all;
        break;
      case DoseStatus.missed:
        title = 'Doses missed';
        iconBg = AppColors.statusMissed;
        icon = Icons.priority_high;
        break;
      case DoseStatus.pending:
        title = 'Pending doses';
        iconBg = AppColors.primaryTeal;
        icon = Icons.schedule;
        break;
      case null:
        title = 'No doses';
        iconBg = AppColors.textMuted;
        icon = Icons.event_available;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildDoseRow(BuildContext context, _CalendarDayDose dose) {
    final timeStr = DateFormat('h:mm a').format(dose.scheduledFor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFECE6)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medication,
              color: AppColors.primaryTeal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicine.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                if (dose.medicine.dosage.isNotEmpty)
                  Text(
                    dose.medicine.dosage,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              _buildStatusAction(dose),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAction(_CalendarDayDose dose) {
    if (dose.status == DoseStatus.taken) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.statusTaken.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14, color: Color(0xFF167B46)),
            SizedBox(width: 4),
            Text(
              'Taken',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF167B46),
              ),
            ),
          ],
        ),
      );
    }

    if (dose.status == DoseStatus.late) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.statusLate.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Late',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4D00),
          ),
        ),
      );
    }

    if (dose.status == DoseStatus.missed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.statusMissed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Missed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB12F24),
          ),
        ),
      );
    }

    // Pending: if not caregiver, allow marking as taken directly
    if (!isCaregiverMode) {
      return GestureDetector(
        onTap: () => onTakeDose(dose),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryTeal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Mark Taken',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Pending',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
