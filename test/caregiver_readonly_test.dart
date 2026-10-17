import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/models/user_profile.dart';
import 'package:medicare_app/services/auth_service.dart';
import 'package:medicare_app/services/local_db_service.dart';
import 'package:medicare_app/widgets/medicine_card.dart';
import 'package:medicare_app/widgets/medicines_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMedicine = Medicine(
    id: 'med-101',
    patientId: 'patient-42',
    name: 'Atorvastatin',
    dosage: '20 mg',
    frequency: 'Once daily',
    instructions: 'At bedtime',
    scheduledTimes: [DateTime(2026, 10, 16, 21, 0)],
    createdAt: DateTime(2026, 10, 16),
  );

  group('Layer 1 UI: MedicineCard readOnly mode', () {
    testWidgets('MedicineCard(readOnly: true) shows status chip and no Taken/Skipped buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineCard(
              medicine: testMedicine,
              doseTime: DateTime(2026, 10, 16, 21, 0),
              status: DoseStatus.taken,
              readOnly: true,
            ),
          ),
        ),
      );

      // Verify Taken/Skipped ElevatedButton buttons are NOT rendered
      expect(find.byType(ElevatedButton), findsNothing);

      // Verify read-only status label is shown
      expect(find.text('Taken'), findsOneWidget);
      expect(find.text('Atorvastatin'), findsOneWidget);
      expect(find.text('20 mg • At bedtime'), findsOneWidget);
    });

    testWidgets('MedicineCard(readOnly: true) displays correct chips for various statuses', (tester) async {
      for (final status in [DoseStatus.pending, DoseStatus.late, DoseStatus.missed, DoseStatus.skipped]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MedicineCard(
                medicine: testMedicine,
                doseTime: DateTime(2026, 10, 16, 21, 0),
                status: status,
                readOnly: true,
              ),
            ),
          ),
        );

        expect(find.byType(ElevatedButton), findsNothing);
        final expectedLabel = switch (status) {
          DoseStatus.taken => 'Taken',
          DoseStatus.skipped => 'Skipped',
          DoseStatus.late => 'Late',
          DoseStatus.missed => 'Missed',
          DoseStatus.pending => 'Pending',
        };
        expect(find.text(expectedLabel), findsOneWidget);
      }
    });

    testWidgets('MedicineCard(readOnly: false) renders actionable Taken and Skipped buttons', (tester) async {
      bool takenPressed = false;
      bool skippedPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineCard(
              medicine: testMedicine,
              doseTime: DateTime(2026, 10, 16, 21, 0),
              status: DoseStatus.pending,
              readOnly: false,
              onTaken: () => takenPressed = true,
              onSkipped: () => skippedPressed = true,
            ),
          ),
        ),
      );

      // Verify buttons exist
      expect(find.byType(ElevatedButton), findsNWidgets(2));
      expect(find.text('Taken'), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);

      // Tap Taken
      await tester.tap(find.text('Taken'));
      await tester.pump();
      expect(takenPressed, isTrue);

      // Tap Skipped
      await tester.tap(find.text('Skipped'));
      await tester.pump();
      expect(skippedPressed, isTrue);
    });
  });

  group('Layer 2 Service Guard: LocalDbService role enforcement', () {
    setUp(() {
      LocalDbService.instance.useMemoryStorage = true;
    });

    tearDown(() {
      AuthService.instance.setCurrentProfileForTesting(null);
    });

    test('Caregiver role throws PermissionDeniedException on upsertMedicine, deleteMedicine, upsertDoseLog', () async {
      const caregiverProfile = UserProfile(
        uid: 'caregiver-007',
        name: 'Caregiver John',
        phoneNumber: '+94770000001',
        role: UserRole.caregiver,
        language: AppLanguage.english,
        linkedPatientIds: ['patient-42'],
      );
      AuthService.instance.setCurrentProfileForTesting(caregiverProfile);

      final db = LocalDbService.instance;

      // upsertMedicine must throw PermissionDeniedException
      expect(
        () => db.upsertMedicine(testMedicine),
        throwsA(
          isA<PermissionDeniedException>().having(
            (e) => e.message,
            'message',
            contains('Caregivers have read-only access'),
          ),
        ),
      );

      // deleteMedicine must throw PermissionDeniedException
      expect(
        () => db.deleteMedicine(testMedicine.id),
        throwsA(
          isA<PermissionDeniedException>().having(
            (e) => e.message,
            'message',
            contains('Caregivers have read-only access'),
          ),
        ),
      );

      // upsertDoseLog must throw PermissionDeniedException
      final testLog = DoseLog(
        id: 'log-001',
        medicineId: testMedicine.id,
        scheduledFor: DateTime(2026, 10, 16, 21, 0),
        status: DoseStatus.taken,
      );
      expect(
        () => db.upsertDoseLog(testLog),
        throwsA(
          isA<PermissionDeniedException>().having(
            (e) => e.message,
            'message',
            contains('Caregivers have read-only access'),
          ),
        ),
      );
    });

    test('Patient role succeeds when modifying own data, throws on another patient data', () async {
      const patientProfile = UserProfile(
        uid: 'patient-42',
        name: 'Patient Alice',
        phoneNumber: '+94770000002',
        role: UserRole.patient,
        language: AppLanguage.english,
      );
      AuthService.instance.setCurrentProfileForTesting(patientProfile);

      final db = LocalDbService.instance;

      // 1. Patient modifying own medicine: succeeds
      await expectLater(db.upsertMedicine(testMedicine), completes);

      final retrieved = await db.getMedicine(testMedicine.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Atorvastatin');

      // 2. Patient logging dose for own medicine: succeeds
      final testLog = DoseLog(
        id: 'log-002',
        medicineId: testMedicine.id,
        scheduledFor: DateTime(2026, 10, 16, 21, 0),
        status: DoseStatus.taken,
      );
      await expectLater(db.upsertDoseLog(testLog), completes);

      // 3. Patient deleting own medicine: succeeds
      await expectLater(db.deleteMedicine(testMedicine.id), completes);

      // 4. Patient attempting to upsert another patient\'s medicine: throws PermissionDeniedException
      final otherPatientMedicine = Medicine(
        id: 'med-999',
        patientId: 'patient-other-999',
        name: 'Metformin',
        dosage: '500 mg',
        frequency: 'Daily',
        instructions: 'With meals',
        scheduledTimes: [DateTime(2026, 10, 16, 8, 0)],
        createdAt: DateTime(2026, 10, 16),
      );

      expect(
        () => db.upsertMedicine(otherPatientMedicine),
        throwsA(
          isA<PermissionDeniedException>().having(
            (e) => e.message,
            'message',
            contains('Patients can only modify their own data'),
          ),
        ),
      );
    });
  });

  group('MedicinesModalSheet role enforcement', () {
    testWidgets('Caregiver mode: shows read-only banner and hides edit/delete/add controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MedicinesModalSheet(
              patientId: 'patient-42',
              patientName: 'Test Patient',
              isCaregiver: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Caregiver View indicator should be visible
      expect(find.text('Caregiver View'), findsOneWidget);

      // Add medicine buttons should NOT exist for caregiver
      expect(find.text('Add'), findsNothing);
      expect(find.text('Add First Medicine'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);

      // Edit and delete icons must not exist
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('Patient mode: shows Add Medicine button and does not display read-only badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MedicinesModalSheet(
              patientId: 'patient-42',
              patientName: 'Myself',
              isCaregiver: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Caregiver View badge should NOT be displayed
      expect(find.text('Caregiver View'), findsNothing);

      // Add Medicine buttons must be displayed for patient
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Add Medicine'), findsOneWidget);
    });

    testWidgets('MedicineDetailSheet in Patient mode offers Edit and Remove actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineDetailSheet(
              medicine: testMedicine,
              isCaregiver: false,
              patientId: 'patient-42',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atorvastatin'), findsOneWidget);
      expect(find.text('20 mg'), findsOneWidget);
      expect(find.text('Edit Medicine'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.textContaining('Caregiver View'), findsNothing);
    });

    testWidgets('MedicineDetailSheet in Caregiver mode is strictly read-only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineDetailSheet(
              medicine: testMedicine,
              isCaregiver: true,
              patientId: 'patient-42',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atorvastatin'), findsOneWidget);
      expect(find.text('20 mg'), findsOneWidget);
      expect(find.textContaining('Caregiver View'), findsOneWidget);
      expect(find.text('Edit Medicine'), findsNothing);
      expect(find.text('Remove'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('MedicineCard responds to onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineCard(
              medicine: testMedicine,
              doseTime: DateTime(2026, 10, 16, 21, 0),
              status: DoseStatus.pending,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Atorvastatin'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
