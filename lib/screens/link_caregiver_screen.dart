import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Screen for patients to generate 6-character single-use invite codes
/// and manage their linked caregivers.
class LinkCaregiverScreen extends StatefulWidget {
  final String? patientId;
  final String? patientName;

  const LinkCaregiverScreen({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  State<LinkCaregiverScreen> createState() => _LinkCaregiverScreenState();
}

class _LinkCaregiverScreenState extends State<LinkCaregiverScreen> {
  String _effectivePatientId = '';
  String _effectivePatientName = '';

  String? _activeCode;
  DateTime? _expiresAt;
  bool _isLoadingCode = true;
  bool _isGenerating = false;

  List<UserProfile> _linkedCaregivers = [];
  bool _isLoadingCaregivers = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final currentUid = AuthService.instance.currentUser?.uid;
    final profile = await AuthService.instance.fetchCurrentUserProfile(currentUid);

    _effectivePatientId = widget.patientId ?? currentUid ?? profile?.uid ?? 'p1';
    _effectivePatientName = widget.patientName ?? profile?.name ?? 'Patient';

    await Future.wait([
      _loadActiveCode(),
      _loadCaregivers(),
    ]);
  }

  Future<void> _loadActiveCode() async {
    setState(() => _isLoadingCode = true);
    try {
      final codeInfo = await AuthService.instance.getActiveInviteCode(_effectivePatientId);
      if (mounted) {
        setState(() {
          _activeCode = codeInfo?['code'];
          _expiresAt = codeInfo?['expiresAt'];
          _isLoadingCode = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCode = false);
    }
  }

  Future<void> _loadCaregivers() async {
    setState(() => _isLoadingCaregivers = true);
    try {
      final caregivers = await AuthService.instance.getLinkedCaregivers(_effectivePatientId);
      if (mounted) {
        setState(() {
          _linkedCaregivers = caregivers;
          _isLoadingCaregivers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCaregivers = false);
    }
  }

  Future<void> _handleGenerateCode() async {
    setState(() => _isGenerating = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await AuthService.instance.generateInviteCode(
        patientId: _effectivePatientId,
        patientName: _effectivePatientName,
      );

      if (mounted) {
        setState(() {
          _activeCode = result['code'];
          _expiresAt = result['expiresAt'];
          _isGenerating = false;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('New 6-character invite code generated! Valid for 24 hours.'),
            backgroundColor: Color(0xFF2E7D4E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        final errText = e.toString().contains('Connect to the internet')
            ? 'Connect to the internet to link.'
            : e.toString().replaceAll('Exception: ', '');
        messenger.showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleUnlinkCaregiver(UserProfile caregiver) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n?.unlink ?? 'Unlink Caregiver', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove ${caregiver.name}? They will no longer be able to view your medication adherence.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n?.unlink ?? 'Unlink'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instance.unlinkPatientFromCaregiver(
        caregiverUid: caregiver.uid,
        patientUid: _effectivePatientId,
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Unlinked from ${caregiver.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadCaregivers();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to unlink: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code "$code" copied to clipboard!'),
        backgroundColor: AppColors.brandTeal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n?.linkCaregiverTitle ?? 'Link Caregiver',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _initData,
        color: AppColors.brandTeal,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            // Top Description Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.brandTeal, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.familyAccessTitle ?? 'Family & Caregiver Access',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n?.familyAccessDesc ??
                              'Give a one-time invite code to your family or doctor so they can see when you take your medicines.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 1: One-Time Invite Code
            Text(
              l10n?.oneTimeInviteCode ?? 'ONE-TIME INVITE CODE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),

            _buildInviteCodeBox(),

            const SizedBox(height: 32),

            // Section 2: Linked Caregivers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n?.linkedCaregiversTitle ?? "LINKED CAREGIVERS"} (${_linkedCaregivers.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                if (_linkedCaregivers.isNotEmpty)
                  GestureDetector(
                    onTap: _loadCaregivers,
                    child: const Icon(Icons.refresh, size: 18, color: AppColors.brandTeal),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            _buildLinkedCaregiversList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCodeBox() {
    if (_isLoadingCode) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.brandTeal),
        ),
      );
    }

    if (_activeCode != null) {
      final code = _activeCode!;
      final formattedExpiry = _expiresAt != null
          ? 'Valid until ${_expiresAt!.hour.toString().padLeft(2, '0')}:${_expiresAt!.minute.toString().padLeft(2, '0')} (${_expiresAt!.day}/${_expiresAt!.month})'
          : 'Valid for 24 hours';

      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F6F4), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandTeal.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.brandTeal),
                const SizedBox(width: 6),
                Text(
                  formattedExpiry,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Large Code Display (Letters spaced)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: code.split('').map((char) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 44,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brandTeal, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      char,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandNavy,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Text(
              'Tell this code to your caregiver by phone or message.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            // Copy & Regenerate Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(code),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandTeal,
                      side: const BorderSide(color: AppColors.brandTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _handleGenerateCode,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text('New Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // No code generated yet
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          const Icon(Icons.key_rounded, size: 48, color: AppColors.brandTeal),
          const SizedBox(height: 12),
          const Text(
            'Generate a One-Time Invite Code',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Creates a secure 6-character code (valid for 24 hours) for your family member to connect.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _handleGenerateCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      AppLocalizations.of(context)?.generateCode ?? 'Generate Code',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedCaregiversList() {
    if (_isLoadingCaregivers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: AppColors.brandTeal),
        ),
      );
    }

    if (_linkedCaregivers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            const Icon(Icons.people_outline, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)?.noCaregiversLinked ?? 'No Caregivers Linked Yet',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Generate an invite code above to link your family member or caregiver.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _linkedCaregivers.map((cg) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFBE5C8),
                child: Text(
                  cg.name.isNotEmpty ? cg.name[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8C581E),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cg.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (cg.phoneNumber != null && cg.phoneNumber!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        cg.phoneNumber!,
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _handleUnlinkCaregiver(cg),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Unlink', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
