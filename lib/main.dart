import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/today_dashboard_screen.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';

/// Entry point.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      // TODO: swap for an auth-gated root once AuthService is wired up —
      // this currently opens straight to the patient dashboard.
      home: const WelcomeScreen(),
    );
  }
}