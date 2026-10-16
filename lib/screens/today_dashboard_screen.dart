import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medicine.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';
import '../widgets/medicine_card.dart';
import '../widgets/language_selector.dart';
import '../widgets/profile_menu_button.dart';
import '../l10n/app_localizations.dart';
import 'add_medicine_screen.dart';
import 'caregiver_screen.dart';
import 'link_caregiver_screen.dart';
import 'pill_calendar_screen.dart';
import 'patient_medicines_screen.dart';

/// Screen 1 — Today / Home Dashboard (patient view).
/// Fetches patient medication schedule and adherence metrics directly
/// from Firebase Firestore and offline local database.
class TodayDashboardScreen extends StatefulWidget {
  final UserProfile? initialProfile;
  final String? viewingPatientId;
  final String? viewingPatientName;

  const TodayDashboardScreen({
    super.key,
    this.initialProfile,
    this.viewingPatientId,
    this.viewingPatientName,
  });

  @override
  State<TodayDashboardScreen> createState() => _TodayDashboardScreenState();
}

class _TodayDashboardScreenState extends State<TodayDashboardScreen> {
  final int _currentIndex = 0;
  List<_TodayDose> _doses = [];
  bool _isLoading = true;
  String _userName = 'User';
  int _streakDays = 0;
  String _effectivePatientId = 'p1';
  bool _isCaregiverMode = false;
  String? _linkedCaregiverName;

  @override
  void initState() {
    super.initState();
    if (widget.viewingPatientName != null && widget.viewingPatientName!.isNotEmpty) {
      _userName = widget.viewingPatientName!;
      _isCaregiverMode = true;
    } else if (widget.initialProfile != null && widget.initialProfile!.name.isNotEmpty) {
      _userName = widget.initialProfile!.name;
    } else if (AuthService.instance.currentProfile != null &&
        AuthService.instance.currentProfile!.name.isNotEmpty) {
      _userName = AuthService.instance.currentProfile!.name;
    }
    _loadDashboardData();
  }

  /// Loads patient profile, medicines list, today's dose logs, and streak metrics
  /// from Firestore and offline storage.
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final currentUid = AuthService.instance.currentUser?.uid;

      // 1. Fetch user profile from backend
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

      _effectivePatientId = patientId;
      _isCaregiverMode = caregiverMode;

      // Resolve user name
      if (widget.viewingPatientName != null && widget.viewingPatientName!.isNotEmpty) {
        _userName = widget.viewingPatientName!;
      } else if (caregiverMode && patientId != currentUid && patientId != 'p1') {
        try {
          final pDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .get()
              .timeout(const Duration(milliseconds: 1500));
          if (pDoc.exists && pDoc.data() != null && mounted) {
            setState(() {
              _userName = pDoc.data()!['name'] ?? 'Patient';
            });
          }
        } catch (_) {}
      } else if (profile != null && profile.name.isNotEmpty && mounted) {
        setState(() {
          _userName = profile.name;
        });
      }

      // Resolve linked caregiver name for patient
      String? linkedCgName;
      if (!caregiverMode && profile != null && profile.linkedCaregiverIds.isNotEmpty) {
        try {
          final cgs = await AuthService.instance.getLinkedCaregivers(patientId);
          if (cgs.isNotEmpty) {
            linkedCgName = cgs.map((c) => c.name).join(', ');
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _linkedCaregiverName = linkedCgName;
        });
      }

      // 2. Fetch medicines for patient from Local DB and Firestore
      final Map<String, Medicine> medicinesMap = {};

      // 2a. Local DB
      try {
        final localMeds = await LocalDbService.instance.getMedicines(patientId);
        for (final m in localMeds) {
          medicinesMap[m.id] = m;
        }
      } catch (e) {
        debugPrint('Error loading local medicines: $e');
      }

      // 2b. Firestore root collection `medicines`
      try {
        final snap = await FirebaseFirestore.instance
            .collection('medicines')
            .where('patientId', isEqualTo: patientId)
            .get()
            .timeout(const Duration(milliseconds: 1500));
        for (final doc in snap.docs) {
          final data = doc.data();
          data['id'] ??= doc.id;
          final med = Medicine.fromMap(data);
          medicinesMap[med.id] = med;
          // Cache locally for offline access
          await LocalDbService.instance.upsertMedicine(med);
        }
      } catch (e) {
        debugPrint('Error querying Firestore root medicines: $e');
      }

      // 2c. Firestore user subcollection `users/{patientId}/medicines`
      try {
        final subSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .collection('medicines')
            .get()
            .timeout(const Duration(milliseconds: 1500));
        for (final doc in subSnap.docs) {
          final data = doc.data();
          data['id'] ??= doc.id;
          final med = Medicine.fromMap(data);
          medicinesMap[med.id] = med;
          await LocalDbService.instance.upsertMedicine(med);
        }
      } catch (e) {
        debugPrint('Error querying Firestore subcollection medicines: $e');
      }

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      // 3. Fetch dose logs for today
      final Map<String, DoseLog> todayLogs = {};

      // 3a. Local dose logs
      try {
        final localLogs = await LocalDbService.instance.getDoseLogsForDay(todayDate);
        for (final log in localLogs) {
          final key = '${log.medicineId}_${log.scheduledFor.hour}_${log.scheduledFor.minute}';
          todayLogs[key] = log;
          todayLogs[log.medicineId] ??= log;
        }
      } catch (e) {
        debugPrint('Error loading local dose logs: $e');
      }

      // 3b. Firestore dose logs
      try {
        final startStr = todayDate.toIso8601String();
        final endStr = todayDate.add(const Duration(days: 1)).toIso8601String();
        final logsSnap = await FirebaseFirestore.instance
            .collection('dose_logs')
            .where('scheduledFor', isGreaterThanOrEqualTo: startStr)
            .where('scheduledFor', isLessThan: endStr)
            .get()
            .timeout(const Duration(milliseconds: 1500));
        for (final doc in logsSnap.docs) {
          try {
            final data = doc.data();
            data['id'] ??= doc.id;
            final log = DoseLog.fromMap(data);
            final key = '${log.medicineId}_${log.scheduledFor.hour}_${log.scheduledFor.minute}';
            todayLogs[key] = log;
            todayLogs[log.medicineId] ??= log;
            await LocalDbService.instance.upsertDoseLog(log);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Error querying Firestore dose logs: $e');
      }

      // 4. Build _TodayDose list for today from actual medicines
      final List<_TodayDose> builtDoses = [];

      for (final med in medicinesMap.values) {
        if (med.scheduledTimes.isNotEmpty) {
          for (final st in med.scheduledTimes) {
            final doseTime = DateTime(now.year, now.month, now.day, st.hour, st.minute);
            final key = '${med.id}_${st.hour}_${st.minute}';
            final log = todayLogs[key] ?? todayLogs[med.id];
            builtDoses.add(
              _TodayDose(
                medicine: med,
                time: doseTime,
                status: log?.status ?? DoseStatus.pending,
                doseLogId: log?.id,
              ),
            );
          }
        } else {
          // If no specific times were configured, default to 8:00 AM
          final doseTime = DateTime(now.year, now.month, now.day, 8, 0);
          final log = todayLogs[med.id];
          builtDoses.add(
            _TodayDose(
              medicine: med,
              time: doseTime,
              status: log?.status ?? DoseStatus.pending,
              doseLogId: log?.id,
            ),
          );
        }
      }

      // Sort doses chronologically
      builtDoses.sort((a, b) => a.time.compareTo(b.time));

      // 5. Calculate streak days dynamically
      int calculatedStreak = 0;
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(patientId).get();
        if (userDoc.exists && userDoc.data() != null && userDoc.data()!['streakDays'] is int) {
          calculatedStreak = userDoc.data()!['streakDays'] as int;
        } else {
          calculatedStreak = await _computeStreakDays(patientId, builtDoses);
        }
      } catch (_) {
        calculatedStreak = await _computeStreakDays(patientId, builtDoses);
      }

      if (mounted) {
        setState(() {
          _doses = builtDoses;
          _streakDays = calculatedStreak;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error in _loadDashboardData: $e\n$st');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Dynamically computes streak days based on completed dose history.
  Future<int> _computeStreakDays(String patientId, List<_TodayDose> currentDoses) async {
    try {
      int streak = 0;
      final now = DateTime.now();

      // Check consecutive previous days up to 30 days
      for (int i = 1; i <= 30; i++) {
        final day = DateTime(now.year, now.month, now.day - i);
        final logs = await LocalDbService.instance.getDoseLogsForDay(day);
        if (logs.isEmpty) {
          break;
        }
        final allTaken = logs.every((l) => l.status == DoseStatus.taken);
        if (allTaken) {
          streak++;
        } else {
          break;
        }
      }

      // If all doses for today have been taken, include today
      if (currentDoses.isNotEmpty && currentDoses.every((d) => d.status == DoseStatus.taken)) {
        streak++;
      }

      return streak;
    } catch (_) {
      return 0;
    }
  }

  /// Updates dose status in state, local database, and Firebase Firestore.
  Future<void> _updateStatus(_TodayDose dose, DoseStatus status) async {
    setState(() => dose.status = status);

    final patientId = _effectivePatientId;
    final now = DateTime.now();
    final logId = dose.doseLogId ??
        'dose_${dose.medicine.id}_${dose.time.year}${dose.time.month.toString().padLeft(2, '0')}${dose.time.day.toString().padLeft(2, '0')}_${dose.time.hour.toString().padLeft(2, '0')}${dose.time.minute.toString().padLeft(2, '0')}';
    dose.doseLogId = logId;

    final log = DoseLog(
      id: logId,
      medicineId: dose.medicine.id,
      scheduledFor: dose.time,
      status: status,
      respondedAt: now,
      synced: false,
    );

    // Save to local offline database
    await LocalDbService.instance.upsertDoseLog(log);

    // Save to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('dose_logs')
          .doc(log.id)
          .set(log.toMap(), SetOptions(merge: true))
          .timeout(const Duration(milliseconds: 1500));
      await LocalDbService.instance.markSynced(log.id);
    } catch (e) {
      debugPrint('Firestore dose log sync offline: $e');
    }

    // Recalculate streak
    final newStreak = await _computeStreakDays(patientId, _doses);
    if (mounted) {
      setState(() => _streakDays = newStreak);
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .set({'streakDays': newStreak}, SetOptions(merge: true))
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final localeStr = locale?.toString() ?? 'en';
    String todayStr;
    try {
      todayStr = DateFormat('EEEE, MMMM d', localeStr).format(DateTime.now());
    } catch (_) {
      todayStr = DateFormat('EEEE, MMMM d').format(DateTime.now());
    }

    final dosesTaken = _doses.where((d) => d.status == DoseStatus.taken).length;
    final totalDoses = _doses.length;

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
                                    ? 'Caregiver View • Patient Schedule'
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
                        'Monitoring $_userName\'s schedule',
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
                        child: Text(
                          l10n?.exit ?? 'Exit',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandNavy,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else if (_linkedCaregiverName != null && _linkedCaregiverName!.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LinkCaregiverScreen(
                      patientId: _effectivePatientId,
                      patientName: _userName,
                    ),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F6F4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.brandTeal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Linked with $_linkedCaregiverName',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandNavy,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.brandTeal),
                    ],
                  ),
                ),
              ),

            // Main Content Area with Pull-to-Refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: AppColors.brandTeal,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    Text(
                      todayStr,
                      style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.goodMorningName(_userName) ?? 'Good morning, $_userName',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _StreakCard(
                      streakDays: _streakDays,
                      dosesTaken: dosesTaken,
                      totalDoses: totalDoses,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.yourMedicines ?? 'Your medicines',
                                style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                l10n?.today ?? 'Today',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.notifications_active, color: Colors.white),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _doses.isNotEmpty
                                            ? 'Reminder chime: Time to take ${_doses.first.medicine.name} (${_doses.first.medicine.dosage})'
                                            : 'Reminder chime tested successfully.',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.brandTeal,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          icon: const Icon(Icons.notifications_none, size: 18),
                          label: Text(
                            l10n?.testReminderButton ?? 'Test reminder',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brandTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48.0),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.brandTeal),
                        ),
                      )
                    else if (_doses.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9FB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.brandTeal.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.medication_outlined,
                                color: AppColors.brandTeal,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              l10n?.noMedicinesAdded ?? 'No medicines added yet. Tap + to add one.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Medications you add will appear here with scheduled times.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
                                ).then((_) => _loadDashboardData());
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(l10n?.addMedicine ?? 'Add a medicine'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._doses.map(
                        (d) => MedicineCard(
                          medicine: d.medicine,
                          doseTime: d.time,
                          status: d.status,
                          onTaken: () => _updateStatus(d, DoseStatus.taken),
                          onSkipped: () => _updateStatus(d, DoseStatus.late),
                        ),
                      ),
                  ],
                ),
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
          onTap: (index) {
            if (index == _currentIndex) return;
            Widget nextScreen;
            if (index == 1) {
              nextScreen = PillCalendarScreen(
                viewingPatientId: _isCaregiverMode ? _effectivePatientId : null,
                viewingPatientName: _isCaregiverMode ? _userName : null,
              );
            } else if (index == 2) {
              nextScreen = AddMedicineScreen(
                patientId: _isCaregiverMode ? _effectivePatientId : null,
                patientName: _isCaregiverMode ? _userName : null,
              );
            } else if (index == 3) {
              nextScreen = PatientMedicinesScreen(
                viewingPatientId: _isCaregiverMode ? _effectivePatientId : null,
                viewingPatientName: _isCaregiverMode ? _userName : null,
              );
            } else if (index == 4 && _isCaregiverMode) {
              nextScreen = const CaregiverScreen();
            } else {
              return;
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => nextScreen,
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentIndex == 0 ? AppColors.brandTeal.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.home_outlined),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.home, color: AppColors.brandTeal),
              ),
              label: l10n?.today ?? 'Today',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: const Icon(Icons.calendar_month),
              label: l10n?.calendar ?? 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.add),
              label: l10n?.navAdd ?? 'Add',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.medication_outlined),
              activeIcon: const Icon(Icons.medication),
              label: l10n?.navMedicines ?? 'Medicines',
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
                label: l10n?.navCare ?? 'Care',
              ),
          ],
        ),
      ),
    );
  }

}

class _TodayDose {
  final Medicine medicine;
  final DateTime time;
  DoseStatus status;
  String? doseLogId;

  _TodayDose({
    required this.medicine,
    required this.time,
    required this.status,
    this.doseLogId,
  });
}

class _StreakCard extends StatelessWidget {
  final int streakDays;
  final int dosesTaken;
  final int totalDoses;

  const _StreakCard({
    required this.streakDays,
    required this.dosesTaken,
    required this.totalDoses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.caregiverAccent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    (AppLocalizations.of(context)?.currentStreak ?? 'CURRENT STREAK').toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.streakDaysCount(streakDays) ?? '$streakDays days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          // Progress Ring
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: totalDoses > 0 ? dosesTaken / totalDoses : 0,
                    strokeWidth: 4,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                Text(
                  '$dosesTaken/$totalDoses',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
