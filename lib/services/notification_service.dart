import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/medicine.dart';

/// Local (offline-capable) reminder notifications, plus the hook point for
/// Firebase Cloud Messaging caregiver alerts once a device is back online.
///
/// Reminders are scheduled with flutter_local_notifications so they fire
/// even with no network connection — this is the core of the app's
/// offline-first requirement for the daily reminder loop.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  /// Schedules one local notification per scheduled dose time for a medicine.
  /// [titleFor]/[bodyFor] are passed in already localized (English or
  /// Sinhala) by the caller — see lib/l10n.
  Future<void> scheduleDoseReminders({
    required Medicine medicine,
    required String Function(Medicine) titleFor,
    required String Function(Medicine) bodyFor,
  }) async {
    for (final time in medicine.scheduledTimes) {
      final id = Object.hash(medicine.id, time).hashCode & 0x7fffffff;
      await _plugin.zonedSchedule(
        id,
        titleFor(medicine),
        bodyFor(medicine),
        // TODO: convert `time` (time-of-day) into the next tz.TZDateTime
        // occurrence using the `timezone` package before scheduling.
        _nextInstanceOf(time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dose_reminders',
            'Medicine reminders',
            channelDescription: 'Daily medicine dose reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  dynamic _nextInstanceOf(DateTime time) {
    // Placeholder — real implementation uses `timezone` package's
    // tz.TZDateTime so reminders survive device timezone/DST changes.
    throw UnimplementedError(
      'Wire up the timezone package before scheduling real reminders.',
    );
  }
}
