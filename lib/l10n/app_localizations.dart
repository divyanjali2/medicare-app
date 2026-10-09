import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MediCare'**
  String get appName;

  /// No description provided for @yourMedicines.
  ///
  /// In en, this message translates to:
  /// **'Your medicines.'**
  String get yourMedicines;

  /// No description provided for @yourSupport.
  ///
  /// In en, this message translates to:
  /// **'Your support.'**
  String get yourSupport;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Create an account for yourself or someone you care for.'**
  String get welcomeTagline;

  /// No description provided for @signUpAsPatient.
  ///
  /// In en, this message translates to:
  /// **'Sign up as Patient'**
  String get signUpAsPatient;

  /// No description provided for @signUpAsCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Sign up as Caregiver'**
  String get signUpAsCaregiver;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @exploreDemo.
  ///
  /// In en, this message translates to:
  /// **'Explore the demo'**
  String get exploreDemo;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language / භාෂාව තෝරන්න'**
  String get selectLanguage;

  /// No description provided for @taken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get taken;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @addMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add a medicine'**
  String get addMedicine;

  /// No description provided for @scanMedicineLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan medicine label'**
  String get scanMedicineLabel;

  /// No description provided for @enterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get enterManually;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get currentStreak;

  /// No description provided for @saveMedicine.
  ///
  /// In en, this message translates to:
  /// **'Save medicine'**
  String get saveMedicine;

  /// No description provided for @patientAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'PATIENT ACCOUNT'**
  String get patientAccountTitle;

  /// No description provided for @caregiverAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'CAREGIVER ACCOUNT'**
  String get caregiverAccountTitle;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccountTitle;

  /// No description provided for @accountDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A few details help us personalize MediCare.'**
  String get accountDetailsSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get fullNameHint;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @ageHint.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageHint;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumberLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'+94 77 123 4567'**
  String get phoneNumberHint;

  /// No description provided for @emailOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptionalLabel;

  /// No description provided for @emailOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailOptionalHint;

  /// No description provided for @addEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Add emergency contact (optional)'**
  String get addEmergencyContact;

  /// No description provided for @contactNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact name'**
  String get contactNameLabel;

  /// No description provided for @contactNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactNameHint;

  /// No description provided for @contactPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get contactPhoneLabel;

  /// No description provided for @reminderPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder preferences'**
  String get reminderPreferencesTitle;

  /// No description provided for @soundLabel.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundLabel;

  /// No description provided for @vibrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibrationLabel;

  /// No description provided for @reminderStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder style'**
  String get reminderStyleLabel;

  /// No description provided for @gentleReminder.
  ///
  /// In en, this message translates to:
  /// **'Gentle reminder'**
  String get gentleReminder;

  /// No description provided for @persistentReminder.
  ///
  /// In en, this message translates to:
  /// **'Persistent reminder'**
  String get persistentReminder;

  /// No description provided for @silentReminder.
  ///
  /// In en, this message translates to:
  /// **'Silent reminder'**
  String get silentReminder;

  /// No description provided for @sendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send verification code'**
  String get sendVerificationCode;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @caregiverMode.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get caregiverMode;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @noMedicinesAdded.
  ///
  /// In en, this message translates to:
  /// **'No medicines added yet. Tap + to add one.'**
  String get noMedicinesAdded;

  /// No description provided for @streakDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String streakDaysCount(int count);

  /// No description provided for @pillCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Pill calendar'**
  String get pillCalendarTitle;

  /// No description provided for @pillCalendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A clear view of your progress.'**
  String get pillCalendarSubtitle;

  /// No description provided for @detailsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'details go here'**
  String get detailsPlaceholder;

  /// No description provided for @statusLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get statusLate;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your medication schedules and caregiver links.'**
  String get signInSubtitle;

  /// No description provided for @signInWithDemo.
  ///
  /// In en, this message translates to:
  /// **'Sign in with demo account'**
  String get signInWithDemo;

  /// No description provided for @welcomeBackTitle.
  ///
  /// In en, this message translates to:
  /// **'WELCOME BACK'**
  String get welcomeBackTitle;

  /// No description provided for @signInPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone'**
  String get signInPhoneTitle;

  /// No description provided for @signInPhoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a secure verification code.'**
  String get signInPhoneSubtitle;

  /// No description provided for @patientViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Patient view'**
  String get patientViewSubtitle;

  /// No description provided for @signOutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutButton;

  /// No description provided for @testReminderButton.
  ///
  /// In en, this message translates to:
  /// **'Test reminder'**
  String get testReminderButton;

  /// No description provided for @goodMorningName.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String goodMorningName(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'si'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
