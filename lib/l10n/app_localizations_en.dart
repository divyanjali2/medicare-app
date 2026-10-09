// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MediCare';

  @override
  String get yourMedicines => 'Your medicines.';

  @override
  String get yourSupport => 'Your support.';

  @override
  String get welcomeTagline =>
      'Create an account for yourself or someone you care for.';

  @override
  String get signUpAsPatient => 'Sign up as Patient';

  @override
  String get signUpAsCaregiver => 'Sign up as Caregiver';

  @override
  String get signIn => 'Sign in';

  @override
  String get exploreDemo => 'Explore the demo';

  @override
  String get selectLanguage => 'Select Language / භාෂාව තෝරන්න';

  @override
  String get taken => 'Taken';

  @override
  String get skipped => 'Skipped';

  @override
  String get today => 'Today';

  @override
  String get calendar => 'Calendar';

  @override
  String get addMedicine => 'Add a medicine';

  @override
  String get scanMedicineLabel => 'Scan medicine label';

  @override
  String get enterManually => 'Enter manually';

  @override
  String get currentStreak => 'Current streak';

  @override
  String get saveMedicine => 'Save medicine';

  @override
  String get patientAccountTitle => 'PATIENT ACCOUNT';

  @override
  String get caregiverAccountTitle => 'CAREGIVER ACCOUNT';

  @override
  String get createAccountTitle => 'Create your account';

  @override
  String get accountDetailsSubtitle =>
      'A few details help us personalize MediCare.';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get fullNameHint => 'Your full name';

  @override
  String get ageLabel => 'Age';

  @override
  String get ageHint => 'Age';

  @override
  String get phoneNumberLabel => 'Phone number';

  @override
  String get phoneNumberHint => '+94 77 123 4567';

  @override
  String get emailOptionalLabel => 'Email (optional)';

  @override
  String get emailOptionalHint => 'you@example.com';

  @override
  String get addEmergencyContact => 'Add emergency contact (optional)';

  @override
  String get contactNameLabel => 'Contact name';

  @override
  String get contactNameHint => 'Name';

  @override
  String get contactPhoneLabel => 'Contact phone';

  @override
  String get reminderPreferencesTitle => 'Reminder preferences';

  @override
  String get soundLabel => 'Sound';

  @override
  String get vibrationLabel => 'Vibration';

  @override
  String get reminderStyleLabel => 'Reminder style';

  @override
  String get gentleReminder => 'Gentle reminder';

  @override
  String get persistentReminder => 'Persistent reminder';

  @override
  String get silentReminder => 'Silent reminder';

  @override
  String get sendVerificationCode => 'Send verification code';

  @override
  String get backButton => 'Back';

  @override
  String get caregiverMode => 'Caregiver';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get noMedicinesAdded => 'No medicines added yet. Tap + to add one.';

  @override
  String streakDaysCount(int count) {
    return '$count days';
  }

  @override
  String get pillCalendarTitle => 'Pill calendar';

  @override
  String get pillCalendarSubtitle => 'A clear view of your progress.';

  @override
  String get detailsPlaceholder => 'details go here';

  @override
  String get statusLate => 'Late';

  @override
  String get statusMissed => 'Missed';

  @override
  String get signInSubtitle =>
      'Sign in to sync your medication schedules and caregiver links.';

  @override
  String get signInWithDemo => 'Sign in with demo account';

  @override
  String get welcomeBackTitle => 'WELCOME BACK';

  @override
  String get signInPhoneTitle => 'Sign in with your phone';

  @override
  String get signInPhoneSubtitle => 'We\'ll send a secure verification code.';
}
