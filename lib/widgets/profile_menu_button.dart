import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/welcome_screen.dart';
import '../l10n/app_localizations.dart';

/// Reusable profile avatar / menu button displayed next to the language selector.
/// Tapping it presents an options sheet with "My Profile" and "Sign out".
class ProfileMenuButton extends StatelessWidget {
  final bool isDark;

  const ProfileMenuButton({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    UserProfile? profile;
    try {
      profile = AuthService.instance.currentProfile;
    } catch (_) {}
    final initial = (profile != null && profile.name.trim().isNotEmpty)
        ? profile.name.trim()[0].toUpperCase()
        : 'U';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showMenu(context),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.brandTeal.withValues(alpha: 0.1),
            border: Border.all(
              color: isDark ? Colors.white24 : AppColors.brandTeal.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.brandTeal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    UserProfile? profile;
    try {
      profile = AuthService.instance.currentProfile;
    } catch (_) {}
    final l10n = AppLocalizations.of(context);
    final userName = profile?.name ?? 'User';
    final userPhone = profile?.phoneNumber ?? '';
    final roleName = profile?.role == UserRole.caregiver ? 'Caregiver' : 'Patient';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.brandTeal.withValues(alpha: 0.15),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandTeal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (userPhone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              userPhone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: profile?.role == UserRole.caregiver
                            ? const Color(0xFFFBE5C8)
                            : AppColors.brandTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        roleName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: profile?.role == UserRole.caregiver
                              ? const Color(0xFF8C581E)
                              : AppColors.brandTeal,
                        ),
                      ),
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: AppColors.borderSubtle),
                ),

                // Option: My Profile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outline, color: AppColors.brandTeal),
                  ),
                  title: const Text(
                    'My Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: const Text('View account and personal details'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showProfileDetailsDialog(context);
                  },
                ),

                const SizedBox(height: 8),

                // Option: Sign out
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  ),
                  title: Text(
                    l10n?.signOutButton ?? 'Sign out',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                    ),
                  ),
                  subtitle: const Text('End your active session'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final nav = Navigator.of(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                            SizedBox(width: 8),
                            Text('Sign Out?'),
                          ],
                        ),
                        content: const Text(
                          'Note: You need an active internet connection to sign back in.\n\n'
                          'If you are currently offline, stay signed in so you can continue viewing and logging your medicines.',
                          style: TextStyle(fontSize: 14, height: 1.4),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(false),
                            child: const Text('Stay Signed In', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await AuthService.instance.signOut();
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (r) => false,
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProfileDetailsDialog(BuildContext context) {
    UserProfile? profile;
    try {
      profile = AuthService.instance.currentProfile;
    } catch (_) {}
    final userName = profile?.name ?? 'User';
    final userPhone = profile?.phoneNumber ?? 'Not provided';
    final roleName = profile?.role == UserRole.caregiver ? 'Caregiver' : 'Patient';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, color: AppColors.brandTeal),
            SizedBox(width: 10),
            Text('Profile Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', userName),
            const SizedBox(height: 12),
            _buildInfoRow('Phone', userPhone),
            const SizedBox(height: 12),
            _buildInfoRow('Role', roleName),
            const SizedBox(height: 12),
            if (profile?.role == UserRole.caregiver)
              _buildInfoRow('Linked Patients', '${profile?.linkedPatientIds.length ?? 0}')
            else
              _buildInfoRow('Linked Caregivers', '${profile?.linkedCaregiverIds.length ?? 0}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
      ],
    );
  }
}
