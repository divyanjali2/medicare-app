import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/medicine.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../widgets/profile_menu_button.dart';
import 'add_medicine_screen.dart';
import 'pill_calendar_screen.dart';
import 'today_dashboard_screen.dart';
import 'patient_medicines_screen.dart';

class _PatientCardData {
  final UserProfile profile;
  final int activeMedsCount;
  final int todayTaken;
  final int todayTotal;
  final int todayMissed;
  final int adherencePct;
  final bool needsAttention;
  final String statusText;
  final Color statusBadgeColor;
  final Color statusTextColor;

  _PatientCardData({
    required this.profile,
    required this.activeMedsCount,
    required this.todayTaken,
    required this.todayTotal,
    required this.todayMissed,
    required this.adherencePct,
    required this.needsAttention,
    required this.statusText,
    required this.statusBadgeColor,
    required this.statusTextColor,
  });
}

/// Screen — Caregiver View Dashboard.
///
/// Displays linked patients, adherence metrics, recent alerts,
/// and quick actions for caregivers to monitor and check in with patients.
class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  List<_PatientCardData> _patientCards = [];
  bool _isLoadingPatients = true;
  int _overallAdherence = 100;
  int _needsAttentionCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLinkedPatients();
  }

  Future<void> _loadLinkedPatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final caregiverUid = AuthService.instance.currentUser?.uid ??
          AuthService.instance.currentProfile?.uid ??
          '';

      final List<UserProfile> patients =
          await AuthService.instance.getLinkedPatients(caregiverUid);

      final List<_PatientCardData> cards = [];
      int totalAdherenceSum = 0;
      int adherenceCount = 0;
      int attentionCount = 0;

      for (final patient in patients) {
        final cardData = await _computePatientData(patient);
        cards.add(cardData);
        if (cardData.needsAttention) {
          attentionCount++;
        }
        if (cardData.activeMedsCount > 0) {
          totalAdherenceSum += cardData.adherencePct;
          adherenceCount++;
        }
      }

      final avgAdherence =
          adherenceCount > 0 ? (totalAdherenceSum / adherenceCount).round() : 100;

      if (mounted) {
        setState(() {
          _patientCards = cards;
          _overallAdherence = avgAdherence;
          _needsAttentionCount = attentionCount;
          _isLoadingPatients = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error loading linked patients: $e');
    }
    if (mounted) {
      setState(() => _isLoadingPatients = false);
    }
  }

  Future<_PatientCardData> _computePatientData(UserProfile patient) async {
    int activeMedsCount = 0;
    int todayTaken = 0;
    int todayTotal = 0;
    int todayMissed = 0;
    int weekTaken = 0;
    int weekTotal = 0;

    try {
      // 1. Fetch patient's medicines (local + firestore)
      final List<Medicine> meds = [];
      try {
        final localMeds = await LocalDbService.instance.getMedicines(patient.uid);
        meds.addAll(localMeds);
      } catch (_) {}

      try {
        final fMeds = await FirebaseFirestore.instance
            .collection('medicines')
            .where('patientId', isEqualTo: patient.uid)
            .get();
        for (final doc in fMeds.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] ??= doc.id;
            final m = Medicine.fromMap(data);
            if (!meds.any((x) => x.id == m.id)) meds.add(m);
          } catch (_) {}
        }
      } catch (_) {}

      try {
        final subMeds = await FirebaseFirestore.instance
            .collection('users')
            .doc(patient.uid)
            .collection('medicines')
            .get();
        for (final doc in subMeds.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] ??= doc.id;
            final m = Medicine.fromMap(data);
            if (!meds.any((x) => x.id == m.id)) meds.add(m);
          } catch (_) {}
        }
      } catch (_) {}

      activeMedsCount = meds.length;

      // 2. Compute 7-day adherence and today's dose stats
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final sevenDaysAgo = todayDate.subtract(const Duration(days: 6));

      final Map<String, DoseLog> logMap = {};

      // Local dose logs for the last 7 days
      for (int i = 0; i < 7; i++) {
        final d = todayDate.subtract(Duration(days: i));
        try {
          final dayLogs = await LocalDbService.instance.getDoseLogsForDay(d);
          for (final l in dayLogs) {
            if (meds.any((m) => m.id == l.medicineId)) {
              logMap[l.id] = l;
            }
          }
        } catch (_) {}
      }

      // Firestore dose logs
      try {
        final startIso = sevenDaysAgo.toIso8601String();
        final snap = await FirebaseFirestore.instance
            .collection('dose_logs')
            .where('scheduledFor', isGreaterThanOrEqualTo: startIso)
            .get();
        for (final doc in snap.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] ??= doc.id;
            final l = DoseLog.fromMap(data);
            if (meds.any((m) => m.id == l.medicineId)) {
              logMap[l.id] = l;
            }
          } catch (_) {}
        }
      } catch (_) {}

      for (final log in logMap.values) {
        weekTotal++;
        if (log.status == DoseStatus.taken) {
          weekTaken++;
        }

        final isToday = log.scheduledFor.year == now.year &&
            log.scheduledFor.month == now.month &&
            log.scheduledFor.day == now.day;
        if (isToday) {
          todayTotal++;
          if (log.status == DoseStatus.taken) {
            todayTaken++;
          } else if (log.status == DoseStatus.missed || log.status == DoseStatus.late) {
            todayMissed++;
          }
        }
      }

      // If no logs recorded yet today but patient has scheduled times
      if (todayTotal == 0 && meds.isNotEmpty) {
        for (final m in meds) {
          todayTotal += m.scheduledTimes.isNotEmpty ? m.scheduledTimes.length : 1;
        }
      }
    } catch (e) {
      debugPrint('Error calculating patient data for ${patient.name}: $e');
    }

    final adherence = weekTotal > 0 ? ((weekTaken / weekTotal) * 100).round() : 100;
    final needsAttention = todayMissed > 0 || (weekTotal >= 2 && adherence < 80);

    String statusText;
    Color badgeColor;
    Color textColor;

    if (todayMissed > 0) {
      statusText = '$todayMissed dose${todayMissed > 1 ? "s" : ""} missed';
      badgeColor = const Color(0xFFFFE5DE);
      textColor = const Color(0xFFD65646);
    } else if (todayTotal > 0 && todayTaken >= todayTotal) {
      statusText = 'All doses taken ($todayTaken/$todayTotal)';
      badgeColor = const Color(0xFFD4EED8);
      textColor = const Color(0xFF2E7D4E);
    } else if (todayTaken > 0) {
      statusText = '$todayTaken of $todayTotal taken today';
      badgeColor = const Color(0xFFE0F2FE);
      textColor = const Color(0xFF0369A1);
    } else if (todayTotal > 0) {
      statusText = '$todayTotal ${todayTotal == 1 ? "dose" : "doses"} pending today';
      badgeColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFF92400E);
    } else if (activeMedsCount > 0) {
      statusText = '$activeMedsCount medications active';
      badgeColor = const Color(0xFFF1F5F9);
      textColor = AppColors.textDark;
    } else {
      statusText = 'No medications scheduled';
      badgeColor = const Color(0xFFF1F5F9);
      textColor = AppColors.textMuted;
    }

    return _PatientCardData(
      profile: patient,
      activeMedsCount: activeMedsCount,
      todayTaken: todayTaken,
      todayTotal: todayTotal,
      todayMissed: todayMissed,
      adherencePct: adherence,
      needsAttention: needsAttention,
      statusText: statusText,
      statusBadgeColor: badgeColor,
      statusTextColor: textColor,
    );
  }

  void _openLinkPatientDialog(BuildContext context) {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: AppColors.brandTeal),
                  SizedBox(width: 10),
                  Text('Link a Patient', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the registered phone number of the patient you wish to care for:',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Patient Phone Number',
                      hintText: 'e.g. 077 123 4567',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final phone = phoneController.text.trim();
                          if (phone.isEmpty) return;
                          setDialogState(() => isSubmitting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(ctx);
                          try {
                            final caregiverUid = AuthService.instance.currentUser?.uid ??
                                AuthService.instance.currentProfile?.uid ??
                                '';
                            final patient = await AuthService.instance.linkPatientToCaregiver(
                              caregiverUid: caregiverUid,
                              patientPhoneOrCode: phone,
                            );
                            if (!mounted) return;
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Linked with ${patient.name} successfully!'),
                                backgroundColor: const Color(0xFF2E7D4E),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _loadLinkedPatients();
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Link Patient'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openPatientDashboard(BuildContext context, UserProfile patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TodayDashboardScreen(
          viewingPatientId: patient.uid,
          viewingPatientName: patient.name,
        ),
      ),
    ).then((_) => _loadLinkedPatients());
  }

  void _openPatientMedicines(BuildContext context, UserProfile patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientMedicinesScreen(
          viewingPatientId: patient.uid,
          viewingPatientName: patient.name,
        ),
      ),
    ).then((_) => _loadLinkedPatients());
  }

  Future<void> _unlinkPatient(UserProfile patient) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unlink Patient', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to unlink ${patient.name}? You will no longer monitor their medications.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final caregiverUid = AuthService.instance.currentUser?.uid ??
          AuthService.instance.currentProfile?.uid ??
          '';
      await AuthService.instance.unlinkPatientFromCaregiver(
        caregiverUid: caregiverUid,
        patientUid: patient.uid,
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Unlinked from ${patient.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadLinkedPatients();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to unlink: $e')),
        );
      }
    }
  }

  void _openCheckInSheet(BuildContext context, String patientName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Check in with $patientName',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose an action to support $patientName with their medication schedule.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF2E1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.call, color: Color(0xFF2E7D4E)),
                  ),
                  title: Text(
                    'Call $patientName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: const Text('Direct phone call reminder'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Calling $patientName...'),
                        backgroundColor: AppColors.brandTeal,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF0F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.brandTeal,
                    ),
                  ),
                  title: const Text(
                    'Send gentle reminder chime',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: const Text('Triggers gentle sound on patient device'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gentle reminder sent to $patientName!'),
                        backgroundColor: AppColors.brandTeal,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE5C8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF8C581E),
                    ),
                  ),
                  title: const Text(
                    'Mark dose as assisted',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: const Text('Confirm patient took their dose with you'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Dose marked as taken with $patientName.'),
                        backgroundColor: const Color(0xFF2E7D4E),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Dark Header matching design
          Container(
            color: const Color(0xFF0F2E3D),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    // Top Bar: Logo & Subtitle + Language Selector Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.monitor_heart,
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
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Caregiver view',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF9FB2BF),
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
                            LanguagePillSelector(isDark: true),
                            SizedBox(width: 8),
                            ProfileMenuButton(isDark: true),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                // Date Heading
                Text(
                  todayStr,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF55606E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),

                // Main Title
                const Text(
                  'People you care for',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 18),

                // 2 Metric Summary Cards
                Row(
                  children: [
                    // Card 1: Dynamic 7-day adherence
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4EED8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_overallAdherence%',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF357A4C),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '7-day adherence',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Card 2: Dynamic Need attention
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: _needsAttentionCount > 0
                              ? const Color(0xFFFFE5DE)
                              : const Color(0xFFD4EED8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_needsAttentionCount',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: _needsAttentionCount > 0
                                    ? const Color(0xFFD65646)
                                    : const Color(0xFF357A4C),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _needsAttentionCount == 0 ? 'All good' : 'Need attention',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Linked patients',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openLinkPatientDialog(context),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Link patient'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandTeal,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_isLoadingPatients)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36.0),
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(color: AppColors.brandTeal, strokeWidth: 3),
                      ),
                    ),
                  )
                else if (_patientCards.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E4E8)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.brandTeal.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.people_outline, color: AppColors.brandTeal, size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No patients linked yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Connect with a patient by entering their registered phone number to monitor their medications.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openLinkPatientDialog(context),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Link a Patient'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._patientCards.map(
                    (cardData) {
                      final patient = cardData.profile;
                      final initial = patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: cardData.needsAttention
                                ? const Color(0xFFFFCDD2)
                                : const Color(0xFFE2E4E8),
                            width: cardData.needsAttention ? 1.6 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _openPatientDashboard(context, patient),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Avatar, Name, Phone & Menu
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: cardData.needsAttention
                                              ? const Color(0xFFFFEBEE)
                                              : const Color(0xFFDCF0F2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            initial,
                                            style: TextStyle(
                                              color: cardData.needsAttention
                                                  ? const Color(0xFFD32F2F)
                                                  : const Color(0xFF107485),
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    patient.name,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.textDark,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (cardData.needsAttention) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFEBEE),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFD32F2F)),
                                                        SizedBox(width: 2),
                                                        Text(
                                                          'Attention',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFFD32F2F),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              patient.phoneNumber ?? 'Patient',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        onSelected: (value) {
                                          if (value == 'schedule') {
                                            _openPatientDashboard(context, patient);
                                          } else if (value == 'medicines') {
                                            _openPatientMedicines(context, patient);
                                          } else if (value == 'checkin') {
                                            _openCheckInSheet(context, patient.name);
                                          } else if (value == 'unlink') {
                                            _unlinkPatient(patient);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'schedule',
                                            child: Row(
                                              children: [
                                                Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.brandTeal),
                                                SizedBox(width: 8),
                                                Text('View Schedule'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'medicines',
                                            child: Row(
                                              children: [
                                                Icon(Icons.medication_outlined, size: 18, color: Color(0xFF2E7D4E)),
                                                SizedBox(width: 8),
                                                Text('View Medicines'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'checkin',
                                            child: Row(
                                              children: [
                                                Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.brandTeal),
                                                SizedBox(width: 8),
                                                Text('Check In'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'unlink',
                                            child: Row(
                                              children: [
                                                Icon(Icons.link_off, size: 18, color: Colors.redAccent),
                                                SizedBox(width: 8),
                                                Text('Unlink Patient', style: TextStyle(color: Colors.redAccent)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // Dynamic Status & Stats Badges Row
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      // Today's Dose Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: cardData.statusBadgeColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              cardData.todayMissed > 0
                                                  ? Icons.error_outline
                                                  : cardData.todayTaken >= cardData.todayTotal && cardData.todayTotal > 0
                                                      ? Icons.check_circle_outline
                                                      : Icons.schedule,
                                              size: 14,
                                              color: cardData.statusTextColor,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              cardData.statusText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: cardData.statusTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Active Meds Count Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.medication, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 5),
                                            Text(
                                              '${cardData.activeMedsCount} ${cardData.activeMedsCount == 1 ? "med" : "meds"}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 7-day Adherence Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: cardData.adherencePct >= 80
                                              ? const Color(0xFFDCF2E1)
                                              : const Color(0xFFFFE5DE),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.trending_up,
                                              size: 14,
                                              color: cardData.adherencePct >= 80
                                                  ? const Color(0xFF2E7D4E)
                                                  : const Color(0xFFD65646),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${cardData.adherencePct}% 7d',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: cardData.adherencePct >= 80
                                                    ? const Color(0xFF2E7D4E)
                                                    : const Color(0xFFD65646),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // Quick Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _openPatientDashboard(context, patient),
                                          icon: const Icon(Icons.calendar_month, size: 16),
                                          label: const Text('Schedule'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.brandTeal,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _openPatientMedicines(context, patient),
                                          icon: const Icon(Icons.medication_outlined, size: 16),
                                          label: const Text('Meds'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.brandTeal,
                                            side: const BorderSide(color: AppColors.brandTeal),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _openCheckInSheet(context, patient.name),
                                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                        label: const Text('Check In'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF2E7D4E),
                                          side: const BorderSide(color: Color(0xFF2E7D4E)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar matching design with zero overflow (Calendar, Add, Meds, Care)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: BottomNavigationBar(
          currentIndex: 3,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.brandTeal,
          unselectedItemColor: AppColors.textMuted,
          backgroundColor: Colors.white,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          onTap: (index) {
            if (index == 3) return;
            final String? primaryPatientId = _patientCards.isNotEmpty ? _patientCards.first.profile.uid : null;
            final String? primaryPatientName = _patientCards.isNotEmpty ? _patientCards.first.profile.name : null;

            Widget nextScreen;
            if (index == 0) {
              nextScreen = PillCalendarScreen(
                viewingPatientId: primaryPatientId,
                viewingPatientName: primaryPatientName,
              );
            } else if (index == 1) {
              nextScreen = AddMedicineScreen(
                patientId: primaryPatientId,
                patientName: primaryPatientName,
              );
            } else if (index == 2) {
              nextScreen = PatientMedicinesScreen(
                viewingPatientId: primaryPatientId,
                viewingPatientName: primaryPatientName,
              );
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
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: const Icon(Icons.calendar_month),
              label: l10n?.calendar ?? 'Calendar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add),
              label: 'Add',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.medication_outlined),
              activeIcon: Icon(Icons.medication),
              label: 'Medicines',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF0F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF102A36), width: 1.5),
                ),
                child: const Icon(Icons.people_outline, color: Color(0xFF0E7485)),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF0F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF102A36), width: 1.5),
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
