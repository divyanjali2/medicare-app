import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import '../models/user_profile.dart';
import 'local_db_service.dart';
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

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Lazy map accessors to avoid undefined field references during runtime / hot reload
  Map<String, String>? _activeOtpSessions;
  Map<String, String>? _activeVerificationIds;

  Map<String, String> get _otpSessions => _activeOtpSessions ??= <String, String>{};
  Map<String, String> get _verificationIds => _activeVerificationIds ??= <String, String>{};

  UserProfile? _currentProfile;
  UserProfile? get currentProfile => _currentProfile;

  /// Allows unit tests to inject a specific UserProfile without network calls.
  void setCurrentProfileForTesting(UserProfile? profile) {
    _currentProfile = profile;
  }

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the current user profile from Firestore or returns cached profile.
  Future<UserProfile?> fetchCurrentUserProfile([String? uid]) async {
    final targetUid = uid ?? currentUser?.uid;
    if (targetUid == null) return _currentProfile;
    if (_currentProfile != null && _currentProfile!.uid == targetUid) {
      return _currentProfile;
    }

    // Try reading local offline cache first so offline load is instant
    _currentProfile = await LocalDbService.instance.getCachedUserProfile(targetUid);

    try {
      final doc = await _firestore
          .collection('users')
          .doc(targetUid)
          .get()
          .timeout(const Duration(milliseconds: 1500));
      if (doc.exists && doc.data() != null) {
        _currentProfile = UserProfile.fromMap(doc.data()!);
        await LocalDbService.instance.saveUserProfile(_currentProfile!);
        return _currentProfile;
      }
    } catch (e) {
      // Error fetching profile or offline timeout
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

      // Allow Firebase up to 15 seconds to send SMS before falling back to demo code
      Future.delayed(const Duration(seconds: 15), () {
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
    await LocalDbService.instance.clearCachedUserProfile();
    await _auth.signOut();
  }

  /// Generates a random 6-character single-use invite code for a patient.
  /// Valid for 24 hours. Stored under `inviteCodes/{code}`.
  Future<Map<String, dynamic>> generateInviteCode({
    required String patientId,
    required String patientName,
  }) async {
    // 1. Check internet connectivity
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((c) => c == ConnectivityResult.none)) {
        throw Exception('Connect to the internet to link.');
      }
    } catch (e) {
      if (e.toString().contains('Connect to the internet to link')) rethrow;
    }

    // 2. Generate unambiguous 6-character code (avoiding 0, O, 1, I)
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final rand = Random.secure();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    final codeData = {
      'code': code,
      'patientId': patientId,
      'patientName': patientName,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'used': false,
    };

    try {
      await _firestore
          .collection('inviteCodes')
          .doc(code)
          .set(codeData)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      throw Exception('Connect to the internet to link.');
    }

    return {
      'code': code,
      'expiresAt': expiresAt,
    };
  }

  /// Looks up active (unexpired, unused) invite code generated for this patient.
  Future<Map<String, dynamic>?> getActiveInviteCode(String patientId) async {
    try {
      final now = DateTime.now();
      final snap = await _firestore
          .collection('inviteCodes')
          .where('patientId', isEqualTo: patientId)
          .where('used', isEqualTo: false)
          .limit(5)
          .get()
          .timeout(const Duration(seconds: 3));

      for (final doc in snap.docs) {
        final data = doc.data();
        DateTime? expiresAt;
        final rawExpires = data['expiresAt'];
        if (rawExpires is Timestamp) {
          expiresAt = rawExpires.toDate();
        } else if (rawExpires is String) {
          expiresAt = DateTime.tryParse(rawExpires);
        }
        if (expiresAt != null && expiresAt.isAfter(now)) {
          return {
            'code': doc.id,
            'expiresAt': expiresAt,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  /// Redeems a single-use invite code to link a caregiver with a patient.
  Future<UserProfile> redeemInviteCode({
    required String caregiverUid,
    required String code,
  }) async {
    // 1. Check internet connectivity
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((c) => c == ConnectivityResult.none)) {
        throw Exception('Connect to the internet to link.');
      }
    } catch (e) {
      if (e.toString().contains('Connect to the internet to link')) rethrow;
    }

    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.length != 6) {
      throw Exception('Please enter a valid 6-character code (e.g. K7F2QM).');
    }

    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _firestore
          .collection('inviteCodes')
          .doc(normalizedCode)
          .get()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      throw Exception('Connect to the internet to link.');
    }

    if (!doc.exists || doc.data() == null) {
      throw Exception('Invite code not found. Please check with the patient.');
    }

    final data = doc.data()!;
    final bool used = data['used'] == true;
    if (used) {
      throw Exception('This invite code has already been used. Please ask the patient to generate a new code.');
    }

    DateTime? expiresAt;
    final rawExpires = data['expiresAt'];
    if (rawExpires is Timestamp) {
      expiresAt = rawExpires.toDate();
    } else if (rawExpires is String) {
      expiresAt = DateTime.tryParse(rawExpires);
    }

    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw Exception('This invite code has expired. Please ask the patient to generate a new code.');
    }

    final patientId = data['patientId'] as String?;
    if (patientId == null || patientId.isEmpty) {
      throw Exception('Invalid patient record for this code.');
    }

    if (patientId == caregiverUid) {
      throw Exception('You cannot link to your own account as a caregiver.');
    }

    // 2. Fetch patient profile to verify and return
    DocumentSnapshot<Map<String, dynamic>> patientDoc;
    try {
      patientDoc = await _firestore
          .collection('users')
          .doc(patientId)
          .get()
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      throw Exception('Connect to the internet to link.');
    }

    if (!patientDoc.exists || patientDoc.data() == null) {
      throw Exception('Patient account could not be found.');
    }

    final now = DateTime.now();
    // 3. Perform atomic batch write:
    // - Add patientId to caregiver's linkedPatientIds
    // - Add caregiverUid to patient's linkedCaregiverIds
    // - Mark code used: true
    final batch = _firestore.batch();

    batch.set(
      _firestore.collection('users').doc(caregiverUid),
      {
        'linkedPatientIds': FieldValue.arrayUnion([patientId]),
      },
      SetOptions(merge: true),
    );

    batch.set(
      _firestore.collection('users').doc(patientId),
      {
        'linkedCaregiverIds': FieldValue.arrayUnion([caregiverUid]),
      },
      SetOptions(merge: true),
    );

    batch.update(
      _firestore.collection('inviteCodes').doc(normalizedCode),
      {
        'used': true,
        'usedAt': Timestamp.fromDate(now),
        'usedByCaregiverId': caregiverUid,
      },
    );

    try {
      await batch.commit().timeout(const Duration(seconds: 5));
    } catch (_) {
      throw Exception('Connect to the internet to link.');
    }

    // Update in-memory cached profile if active
    if (_currentProfile != null && _currentProfile!.uid == caregiverUid) {
      final updated = List<String>.from(_currentProfile!.linkedPatientIds);
      if (!updated.contains(patientId)) updated.add(patientId);
      _currentProfile = _currentProfile!.copyWith(linkedPatientIds: updated);
      await LocalDbService.instance.saveUserProfile(_currentProfile!);
    }

    final patientData = Map<String, dynamic>.from(patientDoc.data()!);
    patientData['uid'] ??= patientId;
    return UserProfile.fromMap(patientData);
  }

  /// Links a patient and a caregiver in a Many-to-Many relationship (fallback by code or phone).
  Future<UserProfile> linkPatientToCaregiver({
    required String caregiverUid,
    required String patientPhoneOrCode,
  }) async {
    final clean = patientPhoneOrCode.trim();
    if (clean.length == 6 && !RegExp(r'^\d+$').hasMatch(clean)) {
      return redeemInviteCode(caregiverUid: caregiverUid, code: clean);
    }

    // 1. Find patient document by phone number or direct UID
    DocumentSnapshot<Map<String, dynamic>>? patientDoc;
    try {
      patientDoc = await _findUserDocByPhone(clean)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (patientDoc == null) {
      try {
        final docById = await _firestore
            .collection('users')
            .doc(clean)
            .get()
            .timeout(const Duration(seconds: 4));
        if (docById.exists && docById.data() != null) {
          patientDoc = docById;
        }
      } catch (_) {}
    }

    if (patientDoc == null || !patientDoc.exists) {
      throw Exception('Unable to find account for "$clean". An internet connection is required.');
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

    try {
      await batch.commit().timeout(const Duration(seconds: 4));
    } catch (_) {
      throw Exception('An internet connection is required to link caregiver and patient accounts.');
    }

    // Update in-memory cached profile if active
    if (_currentProfile != null && _currentProfile!.uid == caregiverUid) {
      final updated = List<String>.from(_currentProfile!.linkedPatientIds);
      if (!updated.contains(patientUid)) updated.add(patientUid);
      _currentProfile = _currentProfile!.copyWith(linkedPatientIds: updated);
      await LocalDbService.instance.saveUserProfile(_currentProfile!);
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

    if (_currentProfile != null) {
      if (_currentProfile!.uid == caregiverUid) {
        final updated = List<String>.from(_currentProfile!.linkedPatientIds)..remove(patientUid);
        _currentProfile = _currentProfile!.copyWith(linkedPatientIds: updated);
        await LocalDbService.instance.saveUserProfile(_currentProfile!);
      } else if (_currentProfile!.uid == patientUid) {
        final updated = List<String>.from(_currentProfile!.linkedCaregiverIds)..remove(caregiverUid);
        _currentProfile = _currentProfile!.copyWith(linkedCaregiverIds: updated);
        await LocalDbService.instance.saveUserProfile(_currentProfile!);
      }
    }
  }

  /// Retrieves all linked patient profiles for a caregiver.
  /// Caregivers can only view patients that are explicitly linked in their profile.
  Future<List<UserProfile>> getLinkedPatients(String caregiverUid) async {
    try {
      if (caregiverUid.isEmpty) return [];

      List<String> patientIds = [];

      // Check Firestore caregiver document
      try {
        final caregiverDoc = await _firestore
            .collection('users')
            .doc(caregiverUid)
            .get()
            .timeout(const Duration(milliseconds: 1500));
        if (caregiverDoc.exists && caregiverDoc.data() != null) {
          final rawIds = caregiverDoc.data()!['linkedPatientIds'] as List<dynamic>? ?? [];
          patientIds = rawIds.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
        }
      } catch (_) {}

      // If Firestore failed or was offline, check locally cached profile
      if (patientIds.isEmpty) {
        final localProfile = await LocalDbService.instance.getCachedUserProfile(caregiverUid);
        if (localProfile != null && localProfile.linkedPatientIds.isNotEmpty) {
          patientIds = List<String>.from(localProfile.linkedPatientIds);
        }
      }

      if (patientIds.isEmpty) {
        return [];
      }

      final List<UserProfile> patients = [];
      for (final pid in patientIds) {
        try {
          // 1. Try local cache first for instant retrieval
          final localPatient = await LocalDbService.instance.getCachedUserProfile(pid);
          if (localPatient != null && !patients.any((p) => p.uid == localPatient.uid)) {
            patients.add(localPatient);
          }

          // 2. Refresh from Firestore if available
          final pDoc = await _firestore
              .collection('users')
              .doc(pid)
              .get()
              .timeout(const Duration(milliseconds: 1500));
          if (pDoc.exists && pDoc.data() != null) {
            final data = Map<String, dynamic>.from(pDoc.data()!);
            data['uid'] ??= pDoc.id;
            final updated = UserProfile.fromMap(data);
            await LocalDbService.instance.saveUserProfile(updated);
            final idx = patients.indexWhere((p) => p.uid == updated.uid);
            if (idx >= 0) {
              patients[idx] = updated;
            } else {
              patients.add(updated);
            }
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
        if (cid == null) continue;
        final cidStr = '$cid'.trim();
        if (cidStr.isEmpty) continue;
        try {
          final cDoc = await _firestore.collection('users').doc(cidStr).get();
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
