import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'log_service.dart';

/// Service managing Firebase Authentication and the Firestore `users` collection.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// Register a new Patient in Firebase Auth and persist profile in Firestore `users`.
  Future<UserProfile> signUpPatient({
    required String name,
    required String phoneNumber,
    String? password,
    AppLanguage language = AppLanguage.english,
    int? age,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
    int reminderStyle = 0,
  }) async {
    try {
      final sanitizedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final authEmail = _phoneToPlaceholderEmail(sanitizedPhone);
      final authPassword = (password != null && password.length >= 6)
          ? password
          : _generateDeterministicPassword(sanitizedPhone);

      final cred = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: authPassword,
      );

      final profile = UserProfile(
        uid: cred.user!.uid,
        name: name,
        role: UserRole.patient,
        language: language,
        phoneNumber: phoneNumber,
      );

      final data = profile.toMap();
      if (age != null) data['age'] = age;
      if (emergencyContactName != null && emergencyContactName.isNotEmpty) {
        data['emergencyContactName'] = emergencyContactName;
      }
      if (emergencyContactPhone != null && emergencyContactPhone.isNotEmpty) {
        data['emergencyContactPhone'] = emergencyContactPhone;
      }
      data['soundEnabled'] = soundEnabled;
      data['vibrationEnabled'] = vibrationEnabled;
      data['reminderStyle'] = reminderStyle;
      data['createdAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(profile.uid).set(data, SetOptions(merge: true));

      // Sign out after registration so user explicitly signs in from SignIn screen
      await _auth.signOut();

      return profile;
    } catch (e, st) {
      await LogService.instance.logError(
        e,
        stackTrace: st,
        reason: 'Failed to sign up patient in Firebase',
        category: 'AUTH_ERROR',
        context: {'name': name, 'phone': phoneNumber},
      );
      rethrow;
    }
  }

  /// Register a new Caregiver in Firebase Auth and persist profile in Firestore `users`.
  Future<UserProfile> signUpCaregiver({
    required String name,
    required String phoneNumber,
    String? email,
    String? password,
    String? patientInviteCode,
    AppLanguage language = AppLanguage.english,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
    int reminderStyle = 0,
  }) async {
    try {
      final sanitizedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final authEmail = (email != null && email.trim().contains('@'))
          ? email.trim()
          : _phoneToPlaceholderEmail(sanitizedPhone);
      final authPassword = (password != null && password.length >= 6)
          ? password
          : _generateDeterministicPassword(sanitizedPhone);

      final cred = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: authPassword,
      );

      final profile = UserProfile(
        uid: cred.user!.uid,
        name: name,
        role: UserRole.caregiver,
        language: language,
        phoneNumber: phoneNumber,
      );

      final data = profile.toMap();
      if (email != null && email.trim().isNotEmpty) {
        data['email'] = email.trim();
      }
      if (patientInviteCode != null && patientInviteCode.trim().isNotEmpty) {
        data['patientInviteCode'] = patientInviteCode.trim();
      }
      data['soundEnabled'] = soundEnabled;
      data['vibrationEnabled'] = vibrationEnabled;
      data['reminderStyle'] = reminderStyle;
      data['createdAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(profile.uid).set(data, SetOptions(merge: true));

      // Sign out after registration so user explicitly signs in from SignIn screen
      await _auth.signOut();

      return profile;
    } catch (e, st) {
      await LogService.instance.logError(
        e,
        stackTrace: st,
        reason: 'Failed to sign up caregiver in Firebase',
        category: 'AUTH_ERROR',
        context: {'name': name, 'phone': phoneNumber},
      );
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _phoneToPlaceholderEmail(String sanitizedPhone) {
    final clean = sanitizedPhone.isEmpty ? 'guest' : sanitizedPhone;
    return 'user_$clean@medicare.app';
  }

  String _generateDeterministicPassword(String sanitizedPhone) {
    final clean = sanitizedPhone.isEmpty ? '000000' : sanitizedPhone;
    return 'medicare_${clean.padRight(6, '0')}';
  }
}
