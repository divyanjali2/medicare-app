import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/log_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';

/// Entry point.
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize LogService: sets up the logs folder and global error interception
    await LogService.initialize();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize offline sync listener
    SyncService.instance.startListening();
    SyncService.instance.syncNow();

    runApp(const MediCareApp());
  }, (error, stackTrace) {
    // Intercepts any unhandled asynchronous or zone errors
    LogService.instance.recordPlatformError(
      error,
      stackTrace,
      reason: 'Uncaught Zone / Asynchronous Exception',
    );
  });
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
  Locale _locale = const Locale('si');

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
      // TODO: swap for an auth-gated root once AuthService is wired up —
      // this currently opens straight to the patient dashboard.
      home: const WelcomeScreen(),
    );
  }
}