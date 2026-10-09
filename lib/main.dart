import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

/// Entry point.
///
/// Firebase.initializeApp(), NotificationService.instance.init(), and
/// SyncService.instance.startListening() are wired here once the Firebase
/// project is configured (see docs/decisions.md -> "Backend setup").
/// Left out of this scaffold so the project runs without a Firebase
/// project attached yet.
void main() {
  runApp(const MediCareApp());
}

class MediCareApp extends StatefulWidget {
  const MediCareApp({super.key});

  /// Allows any descendant widget to change the app language dynamically.
  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_MediCareAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MediCareApp> createState() => _MediCareAppState();
}

class _MediCareAppState extends State<MediCareApp> {
  Locale _locale = const Locale('en');

  void setLocale(Locale newLocale) {
    setState(() => _locale = newLocale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const WelcomeScreen(),
    );
  }
}
