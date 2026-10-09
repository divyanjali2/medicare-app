import 'package:flutter/material.dart';

import 'screens/today_dashboard_screen.dart';
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

class MediCareApp extends StatelessWidget {
  const MediCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // TODO: swap for an auth-gated root once AuthService is wired to
      // Firebase — this scaffold opens straight to the patient dashboard.
      home: const TodayDashboardScreen(),
    );
  }
}
