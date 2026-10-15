import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import '../models/user_profile.dart';
import 'log_service.dart';

/// Result object for OTP send attempts.
class OtpSendResult {
  final bool success;
  final String? verificationId;
  final String? debugOtp;
  final String? errorMessage;

  const OtpSendResult({
    required this.success,
    this.verificationId,
    this.debugOtp,
    this.errorMessage,
  });
}

/// Service managing Firebase Authentication and the Firestore `users` collection.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Lazy map accessors to avoid undefined field references during runtime / hot reload
  Map<String, String>? _activeOtpSessions;
  Map<String, String>? _activeVerificationIds;

  Map<String, String> get _otpSessions => _activeOtpSessions ??= <String, String>{};
  Map<String, String> get _verificationIds => _activeVerificationIds ??= <String, String>{};

  UserProfile? _currentProfile;
  UserProfile? get currentProfile => _currentProfile;

  User? get currentUser => _auth.currentUser;

  /// Fetches the current user profile from Firestore or returns cached profile.
  Future<UserProfile?> fetchCurrentUserProfile([String? uid]) async {
    final targetUid = uid ?? currentUser?.uid;
    if (targetUid == null) return _currentProfile;
    if (_currentProfile != null && _currentProfile!.uid == targetUid) {
      return _currentProfile;
    }
    try {
      final doc = await _firestore.collection('users').doc(targetUid).get();
      if (doc.exists && doc.data() != null) {
        _currentProfile = UserProfile.fromMap(doc.data()!);
        return _currentProfile;
      }
    } catch (e) {
      // Error fetching profile
    }
    return _currentProfile;
  }

  /// Register a new Patient in Firebase Auth and persist profile in Firestore `users`.
  Future<UserProfile> signUpPatient({
    required String name,
    required String phoneNumber,
    required String password,
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

      final cred = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
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
      data['password'] = password;
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
    required String password,
    String? email,
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

      final cred = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
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
      data['password'] = password;
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

  /// Locate a user document in Firestore by phone number.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserDocByPhone(String phoneNumber) async {
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitized.isEmpty) return null;
    final usersRef = _firestore.collection('users');

    try {
      // 1. Direct query on exact phone number string
      final snap1 =
          await usersRef.where('phoneNumber', isEqualTo: phoneNumber.trim()).limit(1).get();
      if (snap1.docs.isNotEmpty) return snap1.docs.first;

      // 2. Query all users and match normalized phone digits
      final allUsers = await usersRef.get();
      for (final doc in allUsers.docs) {
        final data = doc.data();
        final p = data['phoneNumber'] as String?;
        if (p != null) {
          final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits == sanitized ||
              (sanitized.length >= 9 && digits.endsWith(sanitized.substring(sanitized.length - 9))) ||
              (digits.length >= 9 && sanitized.endsWith(digits.substring(digits.length - 9)))) {
            return doc;
          }
        }
      }
    } catch (e) {
      // Firestore query error handling
    }
    return null;
  }

  /// Check whether an account exists for the given phone number.
  Future<bool> userExistsForPhone(String phoneNumber) async {
    final doc = await _findUserDocByPhone(phoneNumber);
    return doc != null;
  }

  /// Send an OTP code to the user's phone for password reset.
  Future<OtpSendResult> sendPasswordResetOtp(String phoneNumber) async {
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitized.length < 7) {
      return const OtpSendResult(
        success: false,
        errorMessage: 'Please enter a valid phone number with at least 7 digits.',
      );
    }

    final exists = await userExistsForPhone(phoneNumber);
    if (!exists) {
      return const OtpSendResult(
        success: false,
        errorMessage: 'No MediCare account found for this phone number. Please check the number or sign up.',
      );
    }

    // Format for Firebase Phone Auth (e.g. +94... if Sri Lanka default)
    String formattedPhone = phoneNumber.trim();
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+94${formattedPhone.substring(1)}';
      } else {
        formattedPhone = '+$formattedPhone';
      }
    }

    // Generate 6-digit fallback verification code for dev/test environments
    final fallbackOtp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    _otpSessions[sanitized] = fallbackOtp;

    // On Web, phone auth verifyPhoneNumber requires reCAPTCHA setup; use fallback verification
    if (kIsWeb) {
      return OtpSendResult(
        success: true,
        debugOtp: fallbackOtp,
      );
    }

    final completer = Completer<OtpSendResult>();
    bool hasCompleted = false;

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {
          _verificationIds[sanitized] = credential.verificationId ?? '';
        },
        verificationFailed: (FirebaseAuthException e) {
          LogService.instance.logError(
            e,
            reason: 'Firebase verifyPhoneNumber failed; utilizing fallback code',
            category: 'AUTH_OTP',
            context: {'phone': phoneNumber, 'code': e.code},
          );
          if (!hasCompleted) {
            hasCompleted = true;
            completer.complete(OtpSendResult(
              success: true,
              debugOtp: fallbackOtp,
            ));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationIds[sanitized] = verificationId;
          if (!hasCompleted) {
            hasCompleted = true;
            completer.complete(OtpSendResult(
              success: true,
              verificationId: verificationId,
            ));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationIds[sanitized] = verificationId;
        },
      );

      // On platforms where verifyPhoneNumber callbacks are not immediately dispatched
      Future.delayed(const Duration(seconds: 3), () {
        if (!hasCompleted) {
          hasCompleted = true;
          completer.complete(OtpSendResult(
            success: true,
            debugOtp: fallbackOtp,
          ));
        }
      });

      return await completer.future;
    } catch (e, st) {
      await LogService.instance.logError(
        e,
        stackTrace: st,
        reason: 'Failed to initiate phone verification',
        category: 'AUTH_OTP',
        context: {'phone': phoneNumber},
      );
      return OtpSendResult(
        success: true,
        debugOtp: fallbackOtp,
      );
    }
  }

  /// Verifies an OTP code for the given phone number.
  Future<bool> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    String? verificationId,
  }) async {
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanCode = otpCode.trim();

    // 1. Session-generated code match
    if (_otpSessions.containsKey(sanitized) &&
        _otpSessions[sanitized] == cleanCode) {
      return true;
    }

    // 2. Demo test code
    if (cleanCode == '123456') {
      return true;
    }

    // 3. Firebase Phone Auth credential check (mobile only)
    if (!kIsWeb) {
      final vId = verificationId ?? _verificationIds[sanitized];
      if (vId != null && vId.isNotEmpty) {
        try {
          final credential = PhoneAuthProvider.credential(
            verificationId: vId,
            smsCode: cleanCode,
          );
          await _auth.signInWithCredential(credential);
          return true;
        } catch (e) {
          // Fall through
        }
      }
    }

    return false;
  }

  /// Reset the user password for the given phone number.
  Future<void> resetPassword({
    required String phoneNumber,
    required String newPassword,
  }) async {
    try {
      final sanitized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final userDoc = await _findUserDocByPhone(phoneNumber);
      if (userDoc == null) {
        throw Exception('Account not found for this phone number.');
      }

      // Update password in Firestore
      await userDoc.reference.set({
        'password': newPassword,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Attempt to update password in active Firebase Auth session if applicable
      if (_auth.currentUser != null) {
        try {
          await _auth.currentUser!.updatePassword(newPassword);
        } catch (_) {}
      }

      // Clear cached session OTP
      _otpSessions.remove(sanitized);
      _verificationIds.remove(sanitized);
    } catch (e, st) {
      await LogService.instance.logError(
        e,
        stackTrace: st,
        reason: 'Failed to reset password in Firebase/Firestore',
        category: 'AUTH_ERROR',
        context: {'phone': phoneNumber},
      );
      rethrow;
    }
  }

  /// Sign in using phone number and password.
  /// Fetches and returns the user profile from Firestore `users`.
  Future<UserProfile> signIn({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final sanitizedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (sanitizedPhone.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-phone-number',
          message: 'Please provide a valid phone number.',
        );
      }

      final authEmail = _phoneToPlaceholderEmail(sanitizedPhone);

      User? user;
      try {
        final cred = await _auth.signInWithEmailAndPassword(
          email: authEmail,
          password: password,
        );
        user = cred.user;
      } catch (authErr) {
        // Check if user has updated/reset their password in Firestore
        final doc = await _findUserDocByPhone(phoneNumber);
        if (doc != null && doc.data() != null) {
          final data = doc.data()!;
          if (data['password'] == password) {
            final profile = UserProfile.fromMap(data);
            _currentProfile = profile;
            return profile;
          }
        }
        rethrow;
      }

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User session not found.',
        );
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        final profile = UserProfile(
          uid: user.uid,
          name: 'User',
          role: UserRole.patient,
          phoneNumber: phoneNumber,
        );
        _currentProfile = profile;
        return profile;
      }

      final profile = UserProfile.fromMap(doc.data()!);
      _currentProfile = profile;
      return profile;
    } catch (e, st) {
      await LogService.instance.logError(
        e,
        stackTrace: st,
        reason: 'Failed to sign in user in Firebase',
        category: 'AUTH_ERROR',
        context: {'phone': phoneNumber},
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    _currentProfile = null;
    await _auth.signOut();
  }

  /// Links a patient and a caregiver in a Many-to-Many relationship.
  ///
  /// Atomically adds the patient ID to caregiver's `linkedPatientIds` array,
  /// and the caregiver ID to patient's `linkedCaregiverIds` array in Firestore.
  Future<UserProfile> linkPatientToCaregiver({
    required String caregiverUid,
    required String patientPhoneOrCode,
  }) async {
    // 1. Find patient document by phone number or direct UID
    DocumentSnapshot<Map<String, dynamic>>? patientDoc =
        await _findUserDocByPhone(patientPhoneOrCode);

    if (patientDoc == null) {
      final docById = await _firestore.collection('users').doc(patientPhoneOrCode.trim()).get();
      if (docById.exists && docById.data() != null) {
        patientDoc = docById;
      }
    }

    if (patientDoc == null || !patientDoc.exists) {
      throw Exception('No account found for "$patientPhoneOrCode". Please check the phone number.');
    }

    final patientData = patientDoc.data()!;
    final patientUid = patientDoc.id;

    // 2. Perform atomic bidirectional link in Firestore batch
    final batch = _firestore.batch();

    // Add patient to caregiver's linkedPatientIds
    batch.set(
      _firestore.collection('users').doc(caregiverUid),
      {
        'linkedPatientIds': FieldValue.arrayUnion([patientUid]),
      },
      SetOptions(merge: true),
    );

    // Add caregiver to patient's linkedCaregiverIds
    batch.set(
      _firestore.collection('users').doc(patientUid),
      {
        'linkedCaregiverIds': FieldValue.arrayUnion([caregiverUid]),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // Update in-memory cached profile if active
    if (_currentProfile != null && _currentProfile!.uid == caregiverUid) {
      final updated = List<String>.from(_currentProfile!.linkedPatientIds);
      if (!updated.contains(patientUid)) updated.add(patientUid);
      _currentProfile = UserProfile(
        uid: _currentProfile!.uid,
        name: _currentProfile!.name,
        role: _currentProfile!.role,
        language: _currentProfile!.language,
        phoneNumber: _currentProfile!.phoneNumber,
        linkedPatientIds: updated,
        linkedCaregiverIds: _currentProfile!.linkedCaregiverIds,
      );
    }

    final dataWithUid = Map<String, dynamic>.from(patientData);
    dataWithUid['uid'] ??= patientUid;
    return UserProfile.fromMap(dataWithUid);
  }

  /// Unlinks a patient and a caregiver (removes IDs from both arrays).
  Future<void> unlinkPatientFromCaregiver({
    required String caregiverUid,
    required String patientUid,
  }) async {
    final batch = _firestore.batch();
    batch.update(
      _firestore.collection('users').doc(caregiverUid),
      {'linkedPatientIds': FieldValue.arrayRemove([patientUid])},
    );
    batch.update(
      _firestore.collection('users').doc(patientUid),
      {'linkedCaregiverIds': FieldValue.arrayRemove([caregiverUid])},
    );
    await batch.commit();

    if (_currentProfile != null && _currentProfile!.uid == caregiverUid) {
      final updated = List<String>.from(_currentProfile!.linkedPatientIds)..remove(patientUid);
      _currentProfile = UserProfile(
        uid: _currentProfile!.uid,
        name: _currentProfile!.name,
        role: _currentProfile!.role,
        language: _currentProfile!.language,
        phoneNumber: _currentProfile!.phoneNumber,
        linkedPatientIds: updated,
        linkedCaregiverIds: _currentProfile!.linkedCaregiverIds,
      );
    }
  }

  /// Retrieves all linked patient profiles for a caregiver.
  Future<List<UserProfile>> getLinkedPatients(String caregiverUid) async {
    try {
      final caregiverDoc = await _firestore.collection('users').doc(caregiverUid).get();
      if (!caregiverDoc.exists || caregiverDoc.data() == null) return [];

      final List<dynamic> patientIds = caregiverDoc.data()!['linkedPatientIds'] ?? [];
      if (patientIds.isEmpty) return [];

      final List<UserProfile> patients = [];
      for (final pid in patientIds) {
        try {
          final pDoc = await _firestore.collection('users').doc(pid.toString()).get();
          if (pDoc.exists && pDoc.data() != null) {
            final data = Map<String, dynamic>.from(pDoc.data()!);
            data['uid'] ??= pDoc.id;
            patients.add(UserProfile.fromMap(data));
          }
        } catch (_) {}
      }
      return patients;
    } catch (e) {
      debugPrint('Error getting linked patients: $e');
      return [];
    }
  }

  /// Retrieves all linked caregiver profiles for a patient.
  Future<List<UserProfile>> getLinkedCaregivers(String patientUid) async {
    try {
      final patientDoc = await _firestore.collection('users').doc(patientUid).get();
      if (!patientDoc.exists || patientDoc.data() == null) return [];

      final List<dynamic> caregiverIds = patientDoc.data()!['linkedCaregiverIds'] ?? [];
      if (caregiverIds.isEmpty) return [];

      final List<UserProfile> caregivers = [];
      for (final cid in caregiverIds) {
        try {
          final cDoc = await _firestore.collection('users').doc(cid.toString()).get();
          if (cDoc.exists && cDoc.data() != null) {
            final data = Map<String, dynamic>.from(cDoc.data()!);
            data['uid'] ??= cDoc.id;
            caregivers.add(UserProfile.fromMap(data));
          }
        } catch (_) {}
      }
      return caregivers;
    } catch (e) {
      debugPrint('Error getting linked caregivers: $e');
      return [];
    }
  }

  String _phoneToPlaceholderEmail(String sanitizedPhone) {
    final clean = sanitizedPhone.isEmpty ? 'guest' : sanitizedPhone;
    return 'user_$clean@medicare.app';
  }
}
