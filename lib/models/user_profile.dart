enum AppLanguage { english, sinhala }

enum UserRole { patient, caregiver }

class UserProfile {
  final String uid;
  final String name;
  final UserRole role;
  final AppLanguage language;
  final String? phoneNumber;
  final List<String> linkedPatientIds; // populated for caregivers
  final List<String> linkedCaregiverIds; // populated for patients

  const UserProfile({
    required this.uid,
    required this.name,
    required this.role,
    this.language = AppLanguage.english,
    this.phoneNumber,
    this.linkedPatientIds = const [],
    this.linkedCaregiverIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'role': role.name,
        'language': language.name,
        'phoneNumber': phoneNumber,
        'linkedPatientIds': linkedPatientIds,
        'linkedCaregiverIds': linkedCaregiverIds,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        uid: map['uid'] as String,
        name: map['name'] as String,
        role: UserRole.values.byName(map['role'] as String),
        language: AppLanguage.values.byName(map['language'] as String? ?? 'english'),
        phoneNumber: map['phoneNumber'] as String?,
        linkedPatientIds: List<String>.from(map['linkedPatientIds'] ?? []),
        linkedCaregiverIds: List<String>.from(map['linkedCaregiverIds'] ?? []),
      );
}
