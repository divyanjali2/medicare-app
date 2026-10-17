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
  String get welcomeTagline => 'Create an account for yourself or someone you care for.';

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
  String get accountDetailsSubtitle => 'A few details help us personalize MediCare.';

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
  String get signInSubtitle => 'Sign in to sync your medication schedules and caregiver links.';

  @override
  String get signInWithDemo => 'Sign in with demo account';

  @override
  String get welcomeBackTitle => 'WELCOME BACK';

  @override
  String get signInPhoneTitle => 'Sign in with your phone';

  @override
  String get signInPhoneSubtitle => 'Enter your phone number and password to continue.';

  @override
  String get patientViewSubtitle => 'Patient view';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get testReminderButton => 'Test reminder';

  @override
  String goodMorningName(String name) {
    return 'Good morning, $name';
  }

  @override
  String get addMedicineSubtitle => 'Point your camera at the medicine label.';

  @override
  String get scanMedicineLabelSubtitle => 'We\'ll fill in the details for you';

  @override
  String get orText => 'or';

  @override
  String get addMedicineTip => 'Tip: Place the bottle on a flat surface with good lighting.';

  @override
  String get backToScan => 'Back to scan';

  @override
  String get scanComplete => 'Scan complete';

  @override
  String get checkDetailsTitle => 'Check the details';

  @override
  String get checkDetailsSubtitle => 'Make sure everything matches your label.';

  @override
  String get medicineNameLabel => 'Medicine name';

  @override
  String get dosageLabel => 'Dosage';

  @override
  String get frequencyLabel => 'How often?';

  @override
  String get instructionsLabel => 'Instructions';

  @override
  String get allTakenTitle => 'All taken';

  @override
  String get navToday => 'Today';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navAdd => 'Add';

  @override
  String get navMedicines => 'Medicines';

  @override
  String get navCare => 'Care';

  @override
  String get caregiverView => 'Caregiver view';

  @override
  String get peopleYouCareFor => 'People you care for';

  @override
  String get sevenDayAdherence => '7-day adherence';

  @override
  String get needAttention => 'Need attention';

  @override
  String get allGood => 'All good';

  @override
  String get linkedPatients => 'Linked patients';

  @override
  String get linkPatient => 'Link patient';

  @override
  String get noPatientsLinked => 'No patients linked yet';

  @override
  String get linkCaregiverTitle => 'Link Caregiver';

  @override
  String get familyAccessTitle => 'Family & Caregiver Access';

  @override
  String get familyAccessDesc => 'Give a one-time invite code to your family or doctor so they can see when you take your medicines.';

  @override
  String get oneTimeInviteCode => 'ONE-TIME INVITE CODE';

  @override
  String get generateCode => 'Generate code';

  @override
  String get codeExpiresIn => 'Code expires in 24 hours';

  @override
  String get linkedCaregiversTitle => 'LINKED CAREGIVERS';

  @override
  String get noCaregiversLinked => 'No caregivers linked yet';

  @override
  String get unlink => 'Unlink';

  @override
  String get cancel => 'Cancel';

  @override
  String get addedMedicinesTitle => 'Added Medicines';

  @override
  String get morning => 'Morning';

  @override
  String get evening => 'Evening';

  @override
  String get night => 'Night';

  @override
  String get whenToTake => 'When to take (Time of day)';

  @override
  String get saving => 'Saving...';

  @override
  String get exit => 'Exit';

  @override
  String get manualEntry => 'MANUAL ENTRY';

  @override
  String get manualEntrySubtitle => 'Fill in the medication details and reminder schedule below.';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get careAlerts => 'Care Alerts';

  @override
  String get careAlertsDesc => 'Real-time medication adherence alerts for your linked patients.';

  @override
  String get allPatientsOnTrack => 'All Patients On Track';

  @override
  String get noMissedDosesToday => 'No missed or late medication doses detected for your linked patients today.';

  @override
  String get viewAction => 'View';

  @override
  String get callAction => 'Call';

  @override
  String get checkIn => 'Check In';

  @override
  String get settings => 'Settings';

  @override
  String get appLanguage => 'App Language';

  @override
  String get roleCaregiver => 'Role: Caregiver';

  @override
  String get rolePatient => 'Role: Patient';

  @override
  String get adherenceCalendar => 'Adherence Calendar';

  @override
  String get todaysDoses => 'Today\'s Doses';

  @override
  String get scheduleManagedByPatient => 'Medication schedule and dose logs are managed directly by the patient.';

  @override
  String get scanMedicineCard => 'Scan medicine card';

  @override
  String get uploadFromGallery => 'Upload from gallery';

  @override
  String get takePhoto => 'Take photo with camera';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get customTime => 'Custom time';

  @override
  String get selectTime => 'Select Time';

  @override
  String get deleteMedicine => 'Delete Medicine';

  @override
  String get confirmDeleteMedicine => 'Are you sure you want to delete this medicine?';

  @override
  String get editMedicine => 'Edit Medicine';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get enterInviteCodeHint => 'Enter the 6-character invite code generated on your patient\'s device:';

  @override
  String get inviteCodeLabel => 'Invite Code';

  @override
  String get linkPatientBtn => 'Link Patient';

  @override
  String get unlinkPatientTitle => 'Unlink Patient';

  @override
  String get copyNumber => 'Copy Number';

  @override
  String get openPhoneDialer => 'Open Phone Dialer';

  @override
  String get directPhoneCall => 'Direct phone call';

  @override
  String get timesOfDay => 'Times of day';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get enterNewPassword => 'Enter new password';

  @override
  String get verifyOtp => 'Verify Code';

  @override
  String get otpSentToPhone => 'Verification code has been sent to your phone';
}
