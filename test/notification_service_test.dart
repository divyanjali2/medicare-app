import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationService notificationService;

  setUp(() {
    notificationService = NotificationService.instance;
    notificationService.resetSentHistory();
  });

  group('NotificationService - 5-min Patient Reminders & 20-min Caregiver Alerts', () {
    final testMedicine = Medicine(
      id: 'med-9am-test',
      patientId: 'patient-test-1',
      name: 'Metformin',
      dosage: '500 mg',
      frequency: 'Once daily',
      instructions: 'With breakfast',
      scheduledTimes: [DateTime(2026, 10, 17, 9, 0)], // 9:00 AM
      createdAt: DateTime(2026, 10, 17),
    );

    test('Patient receives reminder 5 minutes before scheduled dose (at 8:55 AM)', () async {
      // 8:55 AM is exactly 5 minutes before 9:00 AM
      final testTime = DateTime(2026, 10, 17, 8, 55);

      await notificationService.checkDoseNotifications(
        medicines: [testMedicine],
        doseLogs: {},
        patientId: 'patient-test-1',
        patientName: 'Kamal Perera',
        testNow: testTime,
      );

      expect(notificationService.sentNotificationsHistory.length, equals(1));
      final notification = notificationService.sentNotificationsHistory.first;
      expect(notification['type'], equals('patient_reminder_5min'));
      expect(notification['title'], contains('Metformin'));
      expect(notification['body'], contains('Upcoming dose in 5 minutes (9:00 AM)'));
      expect(notification['body'], contains('500 mg'));
    });

    test('Patient does NOT receive reminder if more than 5 minutes before (e.g., at 8:50 AM)', () async {
      // 8:50 AM is 10 minutes before 9:00 AM
      final testTime = DateTime(2026, 10, 17, 8, 50);

      await notificationService.checkDoseNotifications(
        medicines: [testMedicine],
        doseLogs: {},
        patientId: 'patient-test-1',
        patientName: 'Kamal Perera',
        testNow: testTime,
      );

      expect(notificationService.sentNotificationsHistory, isEmpty);
    });

    test('Patient does NOT receive reminder if dose was already taken', () async {
      final testTime = DateTime(2026, 10, 17, 8, 56);
      final takenLog = DoseLog(
        id: 'dose-log-1',
        medicineId: testMedicine.id,
        scheduledFor: DateTime(2026, 10, 17, 9, 0),
        status: DoseStatus.taken,
      );

      await notificationService.checkDoseNotifications(
        medicines: [testMedicine],
        doseLogs: {'${testMedicine.id}_9_0': takenLog},
        patientId: 'patient-test-1',
        patientName: 'Kamal Perera',
        testNow: testTime,
      );

      expect(notificationService.sentNotificationsHistory, isEmpty);
    });

    test('Caregiver receives alert 20 minutes after 9:00 AM if dose is NOT taken (at 9:20 AM)', () async {
      // 9:20 AM is exactly 20 minutes after 9:00 AM
      final testTime = DateTime(2026, 10, 17, 9, 20);

      await notificationService.checkDoseNotifications(
        medicines: [testMedicine],
        doseLogs: {},
        patientId: 'patient-test-1',
        patientName: 'Kamal Perera',
        testNow: testTime,
      );

      final alerts = notificationService.sentNotificationsHistory
          .where((n) => n['type'] == 'caregiver_missed_alert_20min')
          .toList();

      expect(alerts.length, equals(1));
      final alert = alerts.first;
      expect(alert['title'], contains('Caregiver Alert: Missed Medicine'));
      expect(alert['body'], contains('Kamal Perera has not taken Metformin (500 mg)'));
      expect(alert['body'], contains('scheduled for 9:00 AM (20 minutes past due)'));
    });

    test('Caregiver does NOT receive alert if dose was marked taken before 20 minutes', () async {
      final testTime = DateTime(2026, 10, 17, 9, 21);
      final takenLog = DoseLog(
        id: 'dose-log-1',
        medicineId: testMedicine.id,
        scheduledFor: DateTime(2026, 10, 17, 9, 0),
        status: DoseStatus.taken,
      );

      await notificationService.checkDoseNotifications(
        medicines: [testMedicine],
        doseLogs: {'${testMedicine.id}_9_0': takenLog},
        patientId: 'patient-test-1',
        patientName: 'Kamal Perera',
        testNow: testTime,
      );

      final alerts = notificationService.sentNotificationsHistory
          .where((n) => n['type'] == 'caregiver_missed_alert_20min')
          .toList();

      expect(alerts, isEmpty);
    });

    test('Notifications are not duplicated when checked multiple times', () async {
      final testTime = DateTime(2026, 10, 17, 8, 56);

      // First check
      await notificationService.checkDoseNotifications(
        medicines: [testMedicine],
        doseLogs: {},
        patientId: 'patient-test-1',
        patientName: 'Kamal Perera',
        testNow: testTime,
      );

      // Second check 10 seconds later
      await notificationService.checkDoseNotifications(
        medicines: [testMedicine],
        doseLogs: {},
        patientId: 'patient-test-1',
        patientName: 'Kamal Perera',
        testNow: testTime.add(const Duration(seconds: 10)),
      );

      expect(notificationService.sentNotificationsHistory.length, equals(1));
    });
  });
}
