// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
}
