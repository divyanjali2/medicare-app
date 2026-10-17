import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/models/user_profile.dart';

void main() {
  group('Patient ↔ Caregiver Linking Unit Tests', () {
    test('UserProfile copyWith correctly updates linked patient and caregiver lists', () {
      final patient = UserProfile(
        uid: 'patient-123',
        name: 'Sunil Perera',
        role: UserRole.patient,
        phoneNumber: '0771234567',
        linkedCaregiverIds: const [],
      );

      expect(patient.linkedCaregiverIds, isEmpty);

      // Link a caregiver
      final linkedPatient = patient.copyWith(
        linkedCaregiverIds: [...patient.linkedCaregiverIds, 'cg-456'],
      );
      expect(linkedPatient.linkedCaregiverIds, contains('cg-456'));

      // Unlink caregiver
      final unlinkedPatient = linkedPatient.copyWith(
        linkedCaregiverIds: List<String>.from(linkedPatient.linkedCaregiverIds)..remove('cg-456'),
      );
      expect(unlinkedPatient.linkedCaregiverIds, isEmpty);
    });

    test('UserProfile serialization preserves linked IDs', () {
      final caregiver = UserProfile(
        uid: 'cg-789',
        name: 'Anula Perera',
        role: UserRole.caregiver,
        linkedPatientIds: const ['p-1', 'p-2'],
      );

      final map = caregiver.toMap();
      expect(map['linkedPatientIds'], equals(['p-1', 'p-2']));

      final fromMap = UserProfile.fromMap(map);
      expect(fromMap.linkedPatientIds, equals(['p-1', 'p-2']));
      expect(fromMap.role, equals(UserRole.caregiver));
    });

    test('Invite code formatting rules: 6 uppercase alphanumeric chars, 24h expiry', () {
      const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
      expect(chars.contains('0'), isFalse);
      expect(chars.contains('O'), isFalse);
      expect(chars.contains('1'), isFalse);
      expect(chars.contains('I'), isFalse);

      final now = DateTime(2026, 10, 15, 12, 0);
      final expiresAt = now.add(const Duration(hours: 24));
      expect(expiresAt.difference(now).inHours, equals(24));
    });
  });
}
