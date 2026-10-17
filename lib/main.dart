import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/log_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'widgets/role_gate.dart';

/// Entry point.
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize LogService: sets up logs directory and error handlers
    try {
      await LogService.initialize();
    } catch (e, st) {
      debugPrint('LogService initialization bypassed: $e\n$st');
    }

    // 2. Initialize NotificationService: creates notification channels
    try {
      await NotificationService.instance.init();
    } catch (e, st) {
      debugPrint('NotificationService initialization bypassed: $e\n$st');
    }

    // 3. Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      debugPrint('Firebase initialization bypassed: $e\n$st');
    }

    // 4. Initialize offline sync listener
    try {
      SyncService.instance.startListening();
      SyncService.instance.syncNow();
    } catch (e, st) {
      debugPrint('SyncService initialization bypassed: $e\n$st');
    }

    // Always launch the application UI
    runApp(const MediCareApp());
  }, (error, stackTrace) {
    // Intercepts any unhandled asynchronous or zone errors
    try {
      LogService.instance.recordPlatformError(
        error,
        stackTrace,
        reason: 'Uncaught Zone / Asynchronous Exception',
      );
    } catch (_) {}
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
      home: const RoleGate(),
    );
  }
}