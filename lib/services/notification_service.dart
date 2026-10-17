import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/medicine.dart';
import 'local_db_service.dart';

/// Service managing offline-capable local notifications for patients
/// (sent 5 minutes before scheduled dose) and caregiver alerts (sent if
/// a dose is not marked as taken 20 minutes after scheduled time).
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Timer? _periodicTimer;

  /// In-memory history of sent notifications for debugging, event feed, and tests.
  final List<Map<String, dynamic>> sentNotificationsHistory = [];

  final Set<String> _sentReminderKeys = {};
  final Set<String> _sentCaregiverAlertKeys = {};

  Set<String> get sentReminderKeys => _sentReminderKeys;
  Set<String> get sentCaregiverAlertKeys => _sentCaregiverAlertKeys;

  static const AndroidNotificationDetails _patientReminderAndroidDetails =
      AndroidNotificationDetails(
    'dose_reminders',
    'Medicine Reminders',
    channelDescription: 'Patient reminders sent 5 minutes before scheduled dose',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  static const AndroidNotificationDetails _caregiverAlertAndroidDetails =
      AndroidNotificationDetails(
    'caregiver_alerts',
    'Caregiver Alerts',
    channelDescription: 'Caregiver alerts for doses missed by 20 minutes',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  /// Initializes the local notifications plugin and creates notification channels.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error (safe to ignore in test/web): $e');
    }
  }

  /// Formats time as "9:00 AM".
  static String formatDoseTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Triggers a patient reminder 5 minutes before a dose.
  Future<void> showPatientUpcomingReminder({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    final timeStr = formatDoseTime(scheduledTime);
    final title = '💊 Medicine Reminder: $medicineName';
    final body = 'Upcoming dose in 5 minutes ($timeStr). Please get your $dosage ready!';
    final id = Object.hash(medicineId, scheduledTime, 'reminder').hashCode & 0x7fffffff;

    sentNotificationsHistory.add({
      'type': 'patient_reminder_5min',
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'dosage': dosage,
      'scheduledTime': scheduledTime,
      'title': title,
      'body': body,
      'timestamp': DateTime.now(),
    });

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: _patientReminderAndroidDetails,
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Local notification show error: $e');
    }
  }

  /// Triggers a caregiver alert when a dose is not marked taken after 20 minutes.
  Future<void> showCaregiverMissedDoseAlert({
    required String patientId,
    required String patientName,
    required String medicineId,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    final timeStr = formatDoseTime(scheduledTime);
    final title = '⚠️ Caregiver Alert: Missed Medicine';
    final body = '$patientName has not taken $medicineName ($dosage) scheduled for $timeStr (20 minutes past due).';
    final id = Object.hash(medicineId, scheduledTime, 'caregiver_alert').hashCode & 0x7fffffff;

    sentNotificationsHistory.add({
      'type': 'caregiver_missed_alert_20min',
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'dosage': dosage,
      'scheduledTime': scheduledTime,
      'title': title,
      'body': body,
      'timestamp': DateTime.now(),
    });

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: _caregiverAlertAndroidDetails,
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Caregiver alert show error: $e');
    }

    // Persist alert to Firestore collection `caregiver_alerts`
    try {
      final alertId = 'alert_${medicineId}_${scheduledTime.year}${scheduledTime.month.toString().padLeft(2, '0')}${scheduledTime.day.toString().padLeft(2, '0')}_${scheduledTime.hour.toString().padLeft(2, '0')}${scheduledTime.minute.toString().padLeft(2, '0')}';
      await FirebaseFirestore.instance.collection('caregiver_alerts').doc(alertId).set({
        'id': alertId,
        'patientId': patientId,
        'patientName': patientName,
        'medicineId': medicineId,
        'medicineName': medicineName,
        'dosage': dosage,
        'scheduledFor': scheduledTime.toIso8601String(),
        'alertTime': DateTime.now().toIso8601String(),
        'message': body,
        'status': 'active',
      }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }

  /// Evaluates medicines against the current time:
  /// 1. Sends patient reminder if now is within 5 minutes before scheduled dose time: [doseTime - 5 mins, doseTime)
  /// 2. Sends caregiver alert if now >= doseTime + 20 mins and dose is NOT marked as taken.
  Future<void> checkDoseNotifications({
    required List<Medicine> medicines,
    required Map<String, DoseLog> doseLogs,
    required String patientId,
    required String patientName,
    DateTime? testNow,
  }) async {
    final now = testNow ?? DateTime.now();

    for (final med in medicines) {
      for (final st in med.scheduledTimes) {
        final doseTime = DateTime(now.year, now.month, now.day, st.hour, st.minute);
        final doseKey = '${med.id}_${now.year}${now.month}${now.day}_${st.hour}_${st.minute}';
        final reminderKey = '${doseKey}_5min_reminder';
        final alertKey = '${doseKey}_20min_missed_alert';

        // Check if dose has already been taken
        final log = doseLogs['${med.id}_${st.hour}_${st.minute}'] ??
            doseLogs[med.id] ??
            doseLogs.values.where((l) =>
                l.medicineId == med.id &&
                l.scheduledFor.hour == st.hour &&
                l.scheduledFor.minute == st.minute).firstOrNull;
        final isTaken = log?.status == DoseStatus.taken;

        // 1. Patient reminder: 5 minutes before scheduled dose time
        final fiveMinutesBefore = doseTime.subtract(const Duration(minutes: 5));
        if ((now.isAfter(fiveMinutesBefore) || now.isAtSameMomentAs(fiveMinutesBefore)) &&
            now.isBefore(doseTime)) {
          if (!isTaken && !_sentReminderKeys.contains(reminderKey)) {
            _sentReminderKeys.add(reminderKey);
            await showPatientUpcomingReminder(
              medicineId: med.id,
              medicineName: med.name,
              dosage: med.dosage,
              scheduledTime: doseTime,
            );
          }
        }

        // 2. Caregiver alert: 20 minutes after scheduled dose if NOT taken
        final twentyMinutesAfter = doseTime.add(const Duration(minutes: 20));
        if (now.isAfter(twentyMinutesAfter) || now.isAtSameMomentAs(twentyMinutesAfter)) {
          if (!isTaken && !_sentCaregiverAlertKeys.contains(alertKey)) {
            _sentCaregiverAlertKeys.add(alertKey);

            // Update local status to missed if not yet updated
            if (log != null && log.status == DoseStatus.pending) {
              log.status = DoseStatus.missed;
              try {
                await LocalDbService.instance.upsertDoseLog(log);
              } catch (_) {}
            }

            await showCaregiverMissedDoseAlert(
              patientId: patientId,
              patientName: patientName,
              medicineId: med.id,
              medicineName: med.name,
              dosage: med.dosage,
              scheduledTime: doseTime,
            );
          }
        }
      }
    }
  }

  /// Starts background periodic checking every 30 seconds while the app is active.
  void startPeriodicMonitoring({
    required Future<List<Medicine>> Function() fetchMedicines,
    required Future<Map<String, DoseLog>> Function() fetchDoseLogs,
    required String Function() getPatientId,
    required String Function() getPatientName,
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final medicines = await fetchMedicines();
        final logs = await fetchDoseLogs();
        final patientId = getPatientId();
        final patientName = getPatientName();
        await checkDoseNotifications(
          medicines: medicines,
          doseLogs: logs,
          patientId: patientId,
          patientName: patientName,
        );
      } catch (e) {
        debugPrint('Periodic notification monitor error: $e');
      }
    });
  }

  /// Stops periodic monitoring.
  void stopMonitoring() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Resets in-memory notification history and keys (used in tests).
  void resetSentHistory() {
    sentNotificationsHistory.clear();
    _sentReminderKeys.clear();
    _sentCaregiverAlertKeys.clear();
  }
}
