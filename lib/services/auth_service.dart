import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

/// Thin wrapper around Firebase Auth + the `users` Firestore collection.
///
/// Patient sign-up and caregiver sign-up share this service; the only
/// difference is the UserRole and the linking step (see
/// docs/decisions.md -> "Account creation").
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserProfile> signUpPatient({
    required String name,
    required String phoneNumber,
    required String password,
    AppLanguage language = AppLanguage.english,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: _phoneToPlaceholderEmail(phoneNumber),
      password: password,
    );
    final profile = UserProfile(
      uid: cred.user!.uid,
      name: name,
      role: UserRole.patient,
      language: language,
      phoneNumber: phoneNumber,
    );
    await _firestore.collection('users').doc(profile.uid).set(profile.toMap());
    return profile;
  }

  Future<UserProfile> signUpCaregiver({
    required String name,
    required String phoneNumber,
    required String password,
    required String patientInviteCode,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: _phoneToPlaceholderEmail(phoneNumber),
      password: password,
    );

    // TODO: resolve patientInviteCode -> patientId via an `invites`
    // Firestore collection, then write the link both ways.
    final profile = UserProfile(
      uid: cred.user!.uid,
      name: name,
      role: UserRole.caregiver,
      phoneNumber: phoneNumber,
    );
    await _firestore.collection('users').doc(profile.uid).set(profile.toMap());
    return profile;
  }

  Future<void> signOut() => _auth.signOut();

  String _phoneToPlaceholderEmail(String phoneNumber) =>
      '$phoneNumber@medicare.local';
}
