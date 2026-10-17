/// A medicine added by a patient, with a derived daily dose schedule.
///
/// Names, dosage, and instructions are always captured in English
/// (see docs/decisions.md — OCR is scoped to printed English labels only).
/// The surrounding app UI may be shown in Sinhala, but this record's
/// content is not translated.
class Medicine {
  final String id;
  final String patientId;
  final String name;
  final String dosage; // e.g. "500 mg"
  final String frequency; // e.g. "Twice daily"
  final String instructions; // e.g. "With breakfast"
  final List<DateTime> scheduledTimes; // times of day, derived from frequency
  final DateTime createdAt;
  final bool addedViaScan;
  final bool synced;

  const Medicine({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.instructions,
    required this.scheduledTimes,
    required this.createdAt,
    this.addedViaScan = false,
    this.synced = false,
  });

  Medicine copyWith({
    String? id,
    String? patientId,
    String? name,
    String? dosage,
    String? frequency,
    String? instructions,
    List<DateTime>? scheduledTimes,
    DateTime? createdAt,
    bool? addedViaScan,
    bool? synced,
  }) {
    return Medicine(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      instructions: instructions ?? this.instructions,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
      createdAt: createdAt ?? this.createdAt,
      addedViaScan: addedViaScan ?? this.addedViaScan,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'patientId': patientId,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'instructions': instructions,
        'scheduledTimes':
            scheduledTimes.map((t) => t.toIso8601String()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'addedViaScan': addedViaScan,
        'synced': synced,
      };

  factory Medicine.fromMap(Map<String, dynamic> map) {
    final timesList = <DateTime>[];
    final rawTimes = map['scheduledTimes'];
    if (rawTimes is List) {
      for (final t in rawTimes) {
        if (t is String && t.isNotEmpty) {
          try {
            timesList.add(DateTime.parse(t));
          } catch (_) {}
        } else if (t is DateTime) {
          timesList.add(t);
        } else if (t != null) {
          try {
            final dynamic dt = t;
            if (dt.toDate != null) {
              timesList.add(dt.toDate() as DateTime);
            }
          } catch (_) {}
        }
      }
    } else if (rawTimes is String && rawTimes.isNotEmpty) {
      for (final part in rawTimes.split('|')) {
        if (part.isNotEmpty) {
          try {
            timesList.add(DateTime.parse(part));
          } catch (_) {}
        }
      }
    }

    DateTime parsedCreatedAt = DateTime.now();
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      try {
        parsedCreatedAt = DateTime.parse(rawCreatedAt);
      } catch (_) {}
    } else if (rawCreatedAt is DateTime) {
      parsedCreatedAt = rawCreatedAt;
    } else if (rawCreatedAt != null) {
      try {
        final dynamic dt = rawCreatedAt;
        if (dt.toDate != null) {
          parsedCreatedAt = dt.toDate() as DateTime;
        }
      } catch (_) {}
    }

    return Medicine(
      id: (map['id'] ?? '').toString(),
      patientId: (map['patientId'] ?? '').toString(),
      name: (map['name'] ?? 'Medicine').toString(),
      dosage: (map['dosage'] ?? '').toString(),
      frequency: (map['frequency'] ?? 'Daily').toString(),
      instructions: (map['instructions'] ?? '').toString(),
      scheduledTimes: timesList,
      createdAt: parsedCreatedAt,
      addedViaScan: map['addedViaScan'] == true || map['addedViaScan'] == 1,
      synced: map['synced'] == true || map['synced'] == 1,
    );
  }
}

/// Adherence status for a single scheduled dose on a given day.
enum DoseStatus { pending, taken, late, missed, skipped }

class DoseLog {
  final String id;
  final String medicineId;
  final DateTime scheduledFor;
  DoseStatus status;
  DateTime? respondedAt;
  final bool synced; // false until pushed to Firestore

  DoseLog({
    required this.id,
    required this.medicineId,
    required this.scheduledFor,
    this.status = DoseStatus.pending,
    this.respondedAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'medicineId': medicineId,
        'scheduledFor': scheduledFor.toIso8601String(),
        'status': status.name,
        'respondedAt': respondedAt?.toIso8601String(),
        'synced': synced ? 1 : 0,
      };

  factory DoseLog.fromMap(Map<String, dynamic> map) {
    DateTime parsedScheduled;
    final rawScheduled = map['scheduledFor'];
    if (rawScheduled is String && rawScheduled.isNotEmpty) {
      parsedScheduled = DateTime.tryParse(rawScheduled) ?? DateTime.now();
    } else if (rawScheduled is DateTime) {
      parsedScheduled = rawScheduled;
    } else {
      try {
        final dynamic dt = rawScheduled;
        parsedScheduled = dt?.toDate != null ? (dt.toDate() as DateTime) : DateTime.now();
      } catch (_) {
        parsedScheduled = DateTime.now();
      }
    }

    DateTime? parsedResponded;
    final rawResponded = map['respondedAt'];
    if (rawResponded is String && rawResponded.isNotEmpty) {
      parsedResponded = DateTime.tryParse(rawResponded);
    } else if (rawResponded is DateTime) {
      parsedResponded = rawResponded;
    } else if (rawResponded != null) {
      try {
        final dynamic dt = rawResponded;
        parsedResponded = dt?.toDate != null ? (dt.toDate() as DateTime) : null;
      } catch (_) {}
    }

    final statusStr = map['status']?.toString();
    final status = DoseStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => DoseStatus.pending,
    );

    final rawSynced = map['synced'];
    final isSynced = rawSynced == 1 || rawSynced == true || rawSynced == '1';

    return DoseLog(
      id: (map['id'] ?? '').toString(),
      medicineId: (map['medicineId'] ?? '').toString(),
      scheduledFor: parsedScheduled,
      status: status,
      respondedAt: parsedResponded,
      synced: isSynced,
    );
  }
}

/// Summarizes daily medication adherence from a list of scheduled [DoseLog] entries.
///
/// Rules:
/// - Empty list returns `null` (no scheduled doses for the day).
/// - If any dose is [DoseStatus.missed], returns [DoseStatus.missed].
/// - Else if any dose is [DoseStatus.late], returns [DoseStatus.late].
/// - Else if all doses are [DoseStatus.taken], returns [DoseStatus.taken].
/// - Otherwise, returns [DoseStatus.pending].
DoseStatus? summarizeDay(List<DoseLog> logs) {
  if (logs.isEmpty) {
    return null;
  }
  if (logs.any((log) => log.status == DoseStatus.missed)) {
    return DoseStatus.missed;
  }
  if (logs.any((log) => log.status == DoseStatus.late)) {
    return DoseStatus.late;
  }
  if (logs.every((log) => log.status == DoseStatus.taken)) {
    return DoseStatus.taken;
  }
  return DoseStatus.pending;
}

