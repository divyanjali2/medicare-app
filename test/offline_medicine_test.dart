import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/services/local_db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Medicine Storage and Sync Status', () {
    setUpAll(() {
      LocalDbService.instance.useMemoryStorage = true;
    });

    test('Medicine model default synced is false and copyWith works', () {
      final med = Medicine(
        id: 'test-med-1',
        patientId: 'patient-1',
        name: 'Paracetamol',
        dosage: '500 mg',
        frequency: 'Daily',
        instructions: 'After meals',
        scheduledTimes: [DateTime(2026, 10, 15, 8, 0)],
        createdAt: DateTime(2026, 10, 15),
      );

      expect(med.synced, isFalse);

      final syncedMed = med.copyWith(synced: true);
      expect(syncedMed.synced, isTrue);

      final map = syncedMed.toMap();
      expect(map['synced'], isTrue);

      final reconstructed = Medicine.fromMap(map);
      expect(reconstructed.synced, isTrue);
    });

    test('LocalDbService upserts medicine with unsynced status and marks synced', () async {
      final db = LocalDbService.instance;
      final med = Medicine(
        id: 'test-offline-med-2',
        patientId: 'patient-offline',
        name: 'Amoxicillin',
        dosage: '250 mg',
        frequency: 'Twice daily',
        instructions: 'With water',
        scheduledTimes: [DateTime(2026, 10, 15, 8, 0)],
        createdAt: DateTime(2026, 10, 15),
        synced: false,
      );

      await db.upsertMedicine(med);

      // Verify retrieval
      final unsynced = await db.getUnsyncedMedicines();
      expect(unsynced.any((m) => m.id == 'test-offline-med-2'), isTrue);

      // Mark synced
      await db.markMedicineSynced('test-offline-med-2');

      final afterSync = await db.getUnsyncedMedicines();
      expect(afterSync.any((m) => m.id == 'test-offline-med-2'), isFalse);
    });
  });
}
