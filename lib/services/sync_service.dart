import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'local_db_service.dart';
import 'log_service.dart';

/// Pushes locally-logged, unsynced data to Firestore whenever connectivity
/// returns. Local data always wins for that device (last-write-wins by
/// timestamp on the server side) — see docs/decisions.md ("Offline sync").
class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  final _firestore = FirebaseFirestore.instance;
  bool _syncing = false;

  /// Call once at app start. Triggers a sync attempt whenever connectivity
  /// changes from offline -> online.
  void startListening() {
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        syncNow();
      }
    });
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    try {
      // 1. Sync pending medicines
      final pendingMedicines = await LocalDbService.instance.getUnsyncedMedicines();
      for (final med in pendingMedicines) {
        await syncMedicine(med);
        await LocalDbService.instance.markMedicineSynced(med.id);
      }

      // 2. Sync pending dose logs
      final pendingLogs = await LocalDbService.instance.getUnsyncedDoseLogs();
      for (final log in pendingLogs) {
        await _firestore
            .collection('dose_logs')
            .doc(log.id)
            .set(log.toMap(), SetOptions(merge: true));
        await LocalDbService.instance.markSynced(log.id);
      }
    } catch (e, st) {
      await LogService.instance.logError(
        e,
        stackTrace: st,
        reason: 'SyncService failed while uploading unsynced data',
        category: 'SYNC_ERROR',
      );
    } finally {
      _syncing = false;
    }
  }

  Future<void> syncMedicine(dynamic medicine) async {
    try {
      final data = medicine.toMap();
      await _firestore
          .collection('medicines')
          .doc(medicine.id as String)
          .set(data, SetOptions(merge: true));
      await _firestore
          .collection('users')
          .doc(medicine.patientId as String)
          .collection('medicines')
          .doc(medicine.id as String)
          .set(data, SetOptions(merge: true));
    } catch (e, st) {
      await LogService.instance.logError(
        e,
        stackTrace: st,
        reason: 'SyncService failed while uploading medicine to Firestore',
        category: 'SYNC_ERROR',
      );
    }
  }
}
