import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'today_dashboard_screen.dart';

/// Screen 0 — Welcome / Landing Screen.
/// Clean, localized onboarding screen using Flutter's official AppLocalizations
/// with instant offline English and Sinhala support.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
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
                            Row(
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
                                Text(
                                  l10n?.appName ?? 'MediCare',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),

                            // Language Selector Pill
                            _LanguagePillSelector(
                              isSinhala: isSinhala,
                              onSelected: (locale) {
                                MediCareApp.setLocale(context, locale);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 36),

                        // --- Security / Trust Shield Icon Box ---
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.softTealBadge,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: _ShieldCheckIcon(
                              size: 28,
                              color: AppColors.brandTeal,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // --- Main Headline ---
                        Text(
                          '${l10n?.yourMedicines ?? "Your medicines."}\n${l10n?.yourSupport ?? "Your support."}',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            height: 1.18,
                            letterSpacing: -0.6,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --- Subtitle / Description ---
                        Text(
                          l10n?.welcomeTagline ??
                              'Create an account for yourself or someone you care for.',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // --- Action Buttons Section ---
                    Column(
                      children: [
                        // Button 1: Sign up as Patient (Teal)
                        _ActionPillButton(
                          title: l10n?.signUpAsPatient ?? 'Sign up as Patient',
                          leadingIcon: Icons.person_outline_rounded,
                          trailingIcon: Icons.chevron_right_rounded,
                          backgroundColor: AppColors.brandTeal,
                          foregroundColor: Colors.white,
                          onTap: () => _handleSignUp(context, UserRole.patient),
                        ),

                        const SizedBox(height: 14),

                        // Button 2: Sign up as Caregiver (Dark Navy)
                        _ActionPillButton(
                          title: l10n?.signUpAsCaregiver ?? 'Sign up as Caregiver',
                          leadingIcon: Icons.people_outline_rounded,
                          trailingIcon: Icons.chevron_right_rounded,
                          backgroundColor: AppColors.brandNavy,
                          foregroundColor: Colors.white,
                          onTap: () => _handleSignUp(context, UserRole.caregiver),
                        ),

                        const SizedBox(height: 14),

                        // Button 3: Sign in (White with Border)
                        _ActionPillButton(
                          title: l10n?.signIn ?? 'Sign in',
                          leadingIcon: Icons.login_rounded,
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textDark,
                          borderColor: AppColors.borderSubtle,
                          centerContent: true,
                          onTap: () => _handleSignIn(context),
                        ),

                        const SizedBox(height: 24),

                        // Bottom Text Link: Explore the demo
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TodayDashboardScreen(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Text(
                                l10n?.exploreDemo ?? 'Explore the demo',
                                style: const TextStyle(
                                  color: AppColors.brandTeal,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
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
    final roleName = role == UserRole.patient ? 'Patient' : 'Caregiver';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: role == UserRole.patient
                      ? AppColors.softTealBadge
                      : const Color(0xFFE2E8F0),
                  child: Icon(
                    role == UserRole.patient
                        ? Icons.person_outline_rounded
                        : Icons.people_outline_rounded,
                    color: role == UserRole.patient
                        ? AppColors.brandTeal
                        : AppColors.brandNavy,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Sign up as $roleName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              role == UserRole.patient
                  ? 'Track your daily medication schedule, scan labels, and receive alerts.'
                  : 'Monitor medications, receive adherence alerts, and assist your loved ones.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: role == UserRole.patient
                      ? AppColors.brandTeal
                      : AppColors.brandNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TodayDashboardScreen(),
                    ),
                  );
                },
                child: Text('Continue to $roleName Dashboard'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _handleSignIn(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to sync your medication schedules and caregiver links.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TodayDashboardScreen(),
                    ),
                  );
                },
                child: const Text('Sign in with demo account'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Action pill button styled matching the design
class _ActionPillButton extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final IconData? trailingIcon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final bool centerContent;
  final VoidCallback onTap;

  const _ActionPillButton({
    required this.title,
    required this.leadingIcon,
    this.trailingIcon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
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
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.2)
                : null,
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
                        style: TextStyle(
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
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (trailingIcon != null)
                        Icon(trailingIcon, color: foregroundColor, size: 22),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Language Selector Pill in the top app bar
class _LanguagePillSelector extends StatelessWidget {
  final bool isSinhala;
  final ValueChanged<Locale> onSelected;

  const _LanguagePillSelector({
    required this.isSinhala,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final label = isSinhala ? 'සිංහල' : 'English';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showLanguageMenu(context),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD0D5DD), width: 1.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                size: 18,
                color: Color(0xFF344054),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D2939),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF344054),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Select Language / භාෂාව තෝරන්න',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language, color: AppColors.brandTeal),
              title: const Text('English',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: !isSinhala
                  ? const Icon(Icons.check, color: AppColors.brandTeal)
                  : null,
              onTap: () {
                onSelected(const Locale('en'));
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate, color: AppColors.brandTeal),
              title: const Text('සිංහල (Sinhala)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: isSinhala
                  ? const Icon(Icons.check, color: AppColors.brandTeal)
                  : null,
              onTap: () {
                onSelected(const Locale('si'));
                Navigator.of(ctx).pop();
              },
            ),
          ],
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

/// Shield with checkmark icon
class _ShieldCheckIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _ShieldCheckIcon({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShieldCheckPainter(color: color),
      ),
    );
  }
}

class _ShieldCheckPainter extends CustomPainter {
  final Color color;

  _ShieldCheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Shield path
    final shieldPath = Path();
    shieldPath.moveTo(w * 0.5, h * 0.15);
    shieldPath.lineTo(w * 0.82, h * 0.28);
    shieldPath.lineTo(w * 0.82, h * 0.56);
    shieldPath.cubicTo(
      w * 0.82,
      h * 0.76,
      w * 0.65,
      h * 0.88,
      w * 0.50,
      h * 0.92,
    );
    shieldPath.cubicTo(
      w * 0.35,
      h * 0.88,
      w * 0.18,
      h * 0.76,
      w * 0.18,
      h * 0.56,
    );
    shieldPath.lineTo(w * 0.18, h * 0.28);
    shieldPath.close();

    canvas.drawPath(shieldPath, strokePaint);

    // Checkmark inside shield
    final checkPath = Path();
    checkPath.moveTo(w * 0.36, h * 0.53);
    checkPath.lineTo(w * 0.46, h * 0.63);
    checkPath.lineTo(w * 0.66, h * 0.43);

    canvas.drawPath(checkPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldCheckPainter oldDelegate) =>
      oldDelegate.color != color;
}
