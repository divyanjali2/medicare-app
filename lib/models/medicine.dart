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
  });

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
      };

  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(
        id: map['id'] as String,
        patientId: map['patientId'] as String,
        name: map['name'] as String,
        dosage: map['dosage'] as String,
        frequency: map['frequency'] as String,
        instructions: map['instructions'] as String,
        scheduledTimes: (map['scheduledTimes'] as List)
            .map((s) => DateTime.parse(s as String))
            .toList(),
        createdAt: DateTime.parse(map['createdAt'] as String),
        addedViaScan: map['addedViaScan'] as bool? ?? false,
      );
}

/// Adherence status for a single scheduled dose on a given day.
enum DoseStatus { pending, taken, late, missed }

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

  factory DoseLog.fromMap(Map<String, dynamic> map) => DoseLog(
        id: map['id'] as String,
        medicineId: map['medicineId'] as String,
        scheduledFor: DateTime.parse(map['scheduledFor'] as String),
        status: DoseStatus.values.byName(map['status'] as String),
        respondedAt: map['respondedAt'] != null
            ? DateTime.parse(map['respondedAt'] as String)
            : null,
        synced: (map['synced'] as int) == 1,
      );
}
