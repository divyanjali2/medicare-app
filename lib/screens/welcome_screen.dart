import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../widgets/role_gate.dart';
import 'caregiver_signup_screen.dart';
import 'patient_signup_screen.dart';
import 'sign_in_screen.dart';

/// Screen 0 — Welcome / Landing Screen.
/// with instant offline English and Sinhala support.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _checkCachedSession();
  }

  Future<void> _checkCachedSession() async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      final profile = await AuthService.instance.fetchCurrentUserProfile(user.uid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoleGate.getHomeScreenForRole(profile)),
      );
      return;
    }
    if (mounted) {
      setState(() => _isCheckingSession = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession && AuthService.instance.currentUser != null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandTeal),
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final currentLocale = Localizations.localeOf(context);
    final isSinhala = currentLocale.languageCode == 'si';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Top Bar: Logo + Brand & Language Selector ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // MediCare Logo & Title
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandTeal,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: _PulseHeartIcon(
                                        size: 28,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      l10n?.appName ?? 'MediCare',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Language Selector Pill
                            const LanguagePillSelector(),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // --- Welcome Hero Illustration ---
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(
                              maxHeight: 185,
                              maxWidth: 240,
                            ),
                            child: Image.asset(
                              'assets/images/welcome_illustration.png',
                              fit: BoxFit.contain,
                              semanticLabel: 'MediCare Caregiver and Medication Support',
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --- Main Headline (Centered) ---
                        Center(
                          child: Text(
                            '${l10n?.yourMedicines ?? "Your medicines."}\n${l10n?.yourSupport ?? "Your support."}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // --- Subtitle / Description (Centered) ---
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              l10n?.welcomeTagline ??
                                  'Create an account for yourself or someone you care for.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- Action Buttons Section ---
                    Column(
                      children: [
                        // Button 1: Primary Big Sign In Button (Brand Teal)
                        _ActionPillButton(
                          title: l10n?.signIn ?? 'Sign In',
                          leadingIcon: Icons.login_rounded,
                          backgroundColor: AppColors.brandTeal,
                          foregroundColor: Colors.white,
                          centerContent: true,
                          onTap: () => _handleSignIn(context),
                        ),

                        const SizedBox(height: 20),

                        // Subtle Divider
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: AppColors.borderSubtle, thickness: 1),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                isSinhala ? 'හෝ ලියාපදිංචි වන්න' : 'Or register as',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: AppColors.borderSubtle, thickness: 1),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Small Modern Role Buttons: Patient & Caregiver
                        Row(
                          children: [
                            // Patient (Small, Soft Teal / Teal accent)
                            Expanded(
                              child: _SmallRoleButton(
                                title: isSinhala ? 'රෝගියා' : 'Patient',
                                icon: Icons.person_outline_rounded,
                                backgroundColor: AppColors.softTealBadge,
                                foregroundColor: AppColors.brandTeal,
                                borderColor: AppColors.brandTeal.withValues(alpha: 0.3),
                                onTap: () => _handleSignUp(context, UserRole.patient),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Caregiver (Small, Card Background / Navy accent)
                            Expanded(
                              child: _SmallRoleButton(
                                title: isSinhala ? 'රැකබලා ගන්නා' : 'Caregiver',
                                icon: Icons.people_outline_rounded,
                                backgroundColor: const Color(0xFFE8EEF5),
                                foregroundColor: AppColors.brandNavy,
                                borderColor: AppColors.brandNavy.withValues(alpha: 0.3),
                                onTap: () => _handleSignUp(context, UserRole.caregiver),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleSignUp(BuildContext context, UserRole role) {
    if (role == UserRole.patient) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PatientSignupScreen(),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const CaregiverSignupScreen(),
        ),
      );
    }
  }

  void _handleSignIn(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SignInScreen(),
      ),
    );
  }
}

/// Action pill button styled matching the design
class _ActionPillButton extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool centerContent;
  final VoidCallback onTap;

  const _ActionPillButton({
    required this.title,
    required this.leadingIcon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.centerContent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: centerContent
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(leadingIcon, color: foregroundColor, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: foregroundColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(leadingIcon, color: foregroundColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            color: foregroundColor,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Small modern role selector button for Patient / Caregiver
class _SmallRoleButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _SmallRoleButton({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foregroundColor, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: foregroundColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Heart with ECG Pulse waveform icon painted crisply to match MediCare branding
class _PulseHeartIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _PulseHeartIcon({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PulseHeartPainter(color: color),
      ),
    );
  }
}

class _PulseHeartPainter extends CustomPainter {
  final Color color;

  _PulseHeartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Heart outline path
    final heartPath = Path();
    heartPath.moveTo(w * 0.5, h * 0.85);
    heartPath.cubicTo(
      w * 0.1,
      h * 0.58,
      w * 0.05,
      h * 0.28,
      w * 0.28,
      h * 0.18,
    );
    heartPath.cubicTo(
      w * 0.40,
      h * 0.13,
      w * 0.48,
      h * 0.25,
      w * 0.50,
      h * 0.32,
    );
    heartPath.cubicTo(
      w * 0.52,
      h * 0.25,
      w * 0.60,
      h * 0.13,
      w * 0.72,
      h * 0.18,
    );
    heartPath.cubicTo(
      w * 0.95,
      h * 0.28,
      w * 0.90,
      h * 0.58,
      w * 0.5,
      h * 0.85,
    );
    canvas.drawPath(heartPath, strokePaint);

    // ECG pulse line across center
    final ecgPath = Path();
    ecgPath.moveTo(w * 0.15, h * 0.52);
    ecgPath.lineTo(w * 0.36, h * 0.52);
    ecgPath.lineTo(w * 0.42, h * 0.40);
    ecgPath.lineTo(w * 0.50, h * 0.64);
    ecgPath.lineTo(w * 0.58, h * 0.44);
    ecgPath.lineTo(w * 0.64, h * 0.52);
    ecgPath.lineTo(w * 0.85, h * 0.52);

    canvas.drawPath(ecgPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PulseHeartPainter oldDelegate) =>
      oldDelegate.color != color;
}
