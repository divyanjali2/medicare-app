import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/medicine.dart';

/// Offline-first local storage.
///
/// Every write in the app (adding a medicine, logging a dose) goes here
/// FIRST, so the app is fully usable with zero connectivity. SyncService
/// later reads the `synced = 0` rows and pushes them to Firestore.
/// See docs/decisions.md for the offline-first rationale.
class LocalDbService {
  LocalDbService._internal();
  static final LocalDbService instance = LocalDbService._internal();

  Database? _db;

  // In-memory fallback for web environment where native SQLite is unavailable
  final Map<String, Medicine> _webMedicines = {};
  final Map<String, DoseLog> _webDoseLogs = {};

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'medicare.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE medicines (
            id TEXT PRIMARY KEY,
            patientId TEXT,
            name TEXT,
            dosage TEXT,
            frequency TEXT,
            instructions TEXT,
            scheduledTimes TEXT,
            createdAt TEXT,
            addedViaScan INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE dose_logs (
            id TEXT PRIMARY KEY,
            medicineId TEXT,
            scheduledFor TEXT,
            status TEXT,
            respondedAt TEXT,
            synced INTEGER
          )
        ''');
      },
    );
  }

  // --- Medicines ---

  Future<void> upsertMedicine(Medicine medicine) async {
    if (kIsWeb) {
      _webMedicines[medicine.id] = medicine;
      return;
    }
    final db = await database;
    await db.insert(
      'medicines',
      medicine.toMap()
        ..update('scheduledTimes', (v) => (v as List).join('|')),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Medicine>> getMedicines(String patientId) async {
    if (kIsWeb) {
      return _webMedicines.values
          .where((m) => m.patientId == patientId)
          .toList();
    }
    final db = await database;
    final rows = await db.query(
      'medicines',
      where: 'patientId = ?',
      whereArgs: [patientId],
    );
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      final rawTimes = map['scheduledTimes'];
      if (rawTimes is String) {
        map['scheduledTimes'] = rawTimes.split('|').where((s) => s.isNotEmpty).toList();
      } else {
        map['scheduledTimes'] = <String>[];
      }
      map['addedViaScan'] = map['addedViaScan'] == 1;
      return Medicine.fromMap(map);
    }).toList();
  }

  Future<void> deleteMedicine(String medicineId) async {
    if (kIsWeb) {
      _webMedicines.remove(medicineId);
      return;
    }
    final db = await database;
    await db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [medicineId],
    );
  }

  // --- Dose logs ---

  Future<void> upsertDoseLog(DoseLog log) async {
    if (kIsWeb) {
      _webDoseLogs[log.id] = log;
      return;
    }
    final db = await database;
    await db.insert(
      'dose_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DoseLog>> getDoseLogsForDay(DateTime day) async {
    if (kIsWeb) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      return _webDoseLogs.values.where((l) {
        return l.scheduledFor.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
            l.scheduledFor.isBefore(end);
      }).toList();
    }
    final db = await database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.query(
      'dose_logs',
      where: 'scheduledFor >= ? AND scheduledFor < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return rows.map((r) => DoseLog.fromMap(r)).toList();
  }

  Future<List<DoseLog>> getUnsyncedDoseLogs() async {
    if (kIsWeb) {
      return _webDoseLogs.values.where((l) => !l.synced).toList();
    }
    final db = await database;
    final rows = await db.query('dose_logs', where: 'synced = 0');
    return rows.map((r) => DoseLog.fromMap(r)).toList();
  }

  Future<void> markSynced(String doseLogId) async {
    if (kIsWeb) {
      final item = _webDoseLogs[doseLogId];
      if (item != null) {
        _webDoseLogs[doseLogId] = DoseLog(
          id: item.id,
          medicineId: item.medicineId,
          scheduledFor: item.scheduledFor,
          status: item.status,
          respondedAt: item.respondedAt,
          synced: true,
        );
      }
      return;
    }
    final db = await database;
    await db.update(
      'dose_logs',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [doseLogId],
    );
  }
}
