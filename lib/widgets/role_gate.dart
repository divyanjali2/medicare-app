import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../screens/caregiver_screen.dart';
import '../screens/today_dashboard_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Centralized entry point deciding which home screen to display based on the
/// signed-in user's role (patient vs. caregiver), enforcing Layer 1 separation.
class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  /// Single source of truth for routing a user to their role-specific home screen.
  static Widget getHomeScreenForRole(UserProfile? profile) {
    if (profile == null) {
      return const WelcomeScreen();
    }
    return switch (profile.role) {
      UserRole.caregiver => const CaregiverScreen(),
      UserRole.patient => TodayDashboardScreen(initialProfile: profile),
    };
  }

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  bool _isLoading = true;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _profile = null;
        });
      }
      return;
    }

    final profile = await AuthService.instance.fetchCurrentUserProfile(user.uid);
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.brandTeal,
          ),
        ),
      );
    }

    return RoleGate.getHomeScreenForRole(_profile);
  }
}
