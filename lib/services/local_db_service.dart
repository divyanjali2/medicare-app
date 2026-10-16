import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/medicine.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

/// Thrown when an unauthorized action is attempted (e.g. caregiver attempting
/// to create, modify, or delete medicines or dose logs).
class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException([this.message = 'Permission denied']);

  @override
  String toString() => 'PermissionDeniedException: $message';
}

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

  /// Allows unit tests or memory-only environments to route through memory storage.
  bool useMemoryStorage = false;

  bool get _isMemory => kIsWeb || useMemoryStorage;

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
      version: 2,
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
            addedViaScan INTEGER,
            synced INTEGER DEFAULT 0
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE medicines ADD COLUMN synced INTEGER DEFAULT 0');
          } catch (_) {}
        }
      },
    );
  }

  // --- Service Guard ---

  /// Service guard ensuring that only patients can modify medicines and dose logs,
  /// and only for their own patient profile. Caregivers are strictly read-only.
  void enforcePatientWritePermission(String targetPatientId) {
    final profile = AuthService.instance.currentProfile;
    if (profile == null) {
      // In offline tests or unauthenticated background tasks, permit.
      return;
    }
    if (profile.role == UserRole.caregiver) {
      throw const PermissionDeniedException('Caregivers have read-only access');
    }
    if (profile.role == UserRole.patient &&
        targetPatientId.isNotEmpty &&
        profile.uid != targetPatientId) {
      throw const PermissionDeniedException('Patients can only modify their own data');
    }
  }

  // --- Medicines ---

  Future<Medicine?> getMedicine(String medicineId) async {
    if (_isMemory) {
      return _webMedicines[medicineId];
    }
    final db = await database;
    final rows = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [medicineId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final map = Map<String, dynamic>.from(rows.first);
    final rawTimes = map['scheduledTimes'];
    if (rawTimes is String) {
      map['scheduledTimes'] = rawTimes.split('|').where((s) => s.isNotEmpty).toList();
    } else {
      map['scheduledTimes'] = <String>[];
    }
    map['addedViaScan'] = map['addedViaScan'] == 1;
    map['synced'] = map['synced'] == 1;
    return Medicine.fromMap(map);
  }

  Future<void> upsertMedicine(Medicine medicine) async {
    enforcePatientWritePermission(medicine.patientId);
    if (_isMemory) {
      _webMedicines[medicine.id] = medicine;
      return;
    }
    final db = await database;
    final map = medicine.toMap();
    map['scheduledTimes'] = (map['scheduledTimes'] as List).join('|');
    map['addedViaScan'] = medicine.addedViaScan ? 1 : 0;
    map['synced'] = medicine.synced ? 1 : 0;
    await db.insert(
      'medicines',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Medicine>> getMedicines(String patientId) async {
    if (_isMemory) {
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
      map['synced'] = map['synced'] == 1;
      return Medicine.fromMap(map);
    }).toList();
  }

  Future<List<Medicine>> getUnsyncedMedicines() async {
    if (_isMemory) {
      return _webMedicines.values.where((m) => !m.synced).toList();
    }
    final db = await database;
    final rows = await db.query('medicines', where: 'synced = 0');
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      final rawTimes = map['scheduledTimes'];
      if (rawTimes is String) {
        map['scheduledTimes'] = rawTimes.split('|').where((s) => s.isNotEmpty).toList();
      } else {
        map['scheduledTimes'] = <String>[];
      }
      map['addedViaScan'] = map['addedViaScan'] == 1;
      map['synced'] = map['synced'] == 1;
      return Medicine.fromMap(map);
    }).toList();
  }

  Future<void> markMedicineSynced(String medicineId) async {
    if (_isMemory) {
      final item = _webMedicines[medicineId];
      if (item != null) {
        _webMedicines[medicineId] = item.copyWith(synced: true);
      }
      return;
    }
    final db = await database;
    await db.update(
      'medicines',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [medicineId],
    );
  }

  Future<void> deleteMedicine(String medicineId) async {
    final existing = await getMedicine(medicineId);
    enforcePatientWritePermission(existing?.patientId ?? '');
    if (_isMemory) {
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
    final med = await getMedicine(log.medicineId);
    enforcePatientWritePermission(med?.patientId ?? '');
    if (_isMemory) {
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
    if (_isMemory) {
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

  Future<List<DoseLog>> getDoseLogsForRange(DateTime start, DateTime end) async {
    if (_isMemory) {
      return _webDoseLogs.values.where((l) {
        return (l.scheduledFor.isAfter(start) || l.scheduledFor.isAtSameMomentAs(start)) &&
            l.scheduledFor.isBefore(end);
      }).toList();
    }
    final db = await database;
    final rows = await db.query(
      'dose_logs',
      where: 'scheduledFor >= ? AND scheduledFor < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return rows.map((r) => DoseLog.fromMap(r)).toList();
  }

  Future<List<DoseLog>> getUnsyncedDoseLogs() async {
    if (_isMemory) {
      return _webDoseLogs.values.where((l) => !l.synced).toList();
    }
    final db = await database;
    final rows = await db.query('dose_logs', where: 'synced = 0');
    return rows.map((r) => DoseLog.fromMap(r)).toList();
  }

  Future<void> markSynced(String doseLogId) async {
    if (_isMemory) {
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

  // --- User Profile Caching ---

  UserProfile? _cachedProfile;

  Future<void> saveUserProfile(UserProfile profile) async {
    _cachedProfile = profile;
    if (!_isMemory) {
      try {
        final db = await database;
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_profile (
            uid TEXT PRIMARY KEY,
            name TEXT,
            phoneNumber TEXT,
            role TEXT,
            language TEXT,
            linkedPatientIds TEXT,
            linkedCaregiverIds TEXT
          )
        ''');
        await db.insert(
          'user_profile',
          {
            'uid': profile.uid,
            'name': profile.name,
            'phoneNumber': profile.phoneNumber,
            'role': profile.role.name,
            'language': profile.language.name,
            'linkedPatientIds': profile.linkedPatientIds.join('|'),
            'linkedCaregiverIds': profile.linkedCaregiverIds.join('|'),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }
  }

  Future<UserProfile?> getCachedUserProfile([String? uid]) async {
    if (_cachedProfile != null && (uid == null || _cachedProfile!.uid == uid)) {
      return _cachedProfile;
    }
    if (!_isMemory) {
      try {
        final db = await database;
        final rows = await db.query(
          'user_profile',
          where: uid != null ? 'uid = ?' : null,
          whereArgs: uid != null ? [uid] : null,
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          final role = (row['role'] == 'caregiver') ? UserRole.caregiver : UserRole.patient;
          final lang = (row['language'] == 'sinhala') ? AppLanguage.sinhala : AppLanguage.english;
          final pIds = (row['linkedPatientIds'] as String? ?? '').split('|').where((s) => s.isNotEmpty).toList();
          final cIds = (row['linkedCaregiverIds'] as String? ?? '').split('|').where((s) => s.isNotEmpty).toList();
          _cachedProfile = UserProfile(
            uid: row['uid'] as String,
            name: row['name'] as String? ?? '',
            phoneNumber: row['phoneNumber'] as String? ?? '',
            role: role,
            language: lang,
            linkedPatientIds: pIds,
            linkedCaregiverIds: cIds,
          );
          return _cachedProfile;
        }
      } catch (_) {}
    }
    return _cachedProfile;
  }

  Future<void> clearCachedUserProfile() async {
    _cachedProfile = null;
    if (!_isMemory) {
      try {
        final db = await database;
        await db.delete('user_profile');
      } catch (_) {}
    }
  }
}
