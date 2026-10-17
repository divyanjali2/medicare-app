import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import 'sign_in_screen.dart';

enum ForgotPasswordStep {
  enterPhone,
  verifyOtp,
  resetPassword,
}

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialPhone;

  const ForgotPasswordScreen({super.key, this.initialPhone});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  ForgotPasswordStep _currentStep = ForgotPasswordStep.enterPhone;

  // Phone Step Controllers
  final _phoneFormKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;

  // OTP Step Controllers
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  String? _verificationId;
  String? _demoOtpCode;
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  // Password Step Controllers
  final _passwordFormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
        setState(() {
          _resendCountdown = 0;
          _canResend = true;
        });
      }
    });
  }

  // --- Step 1: Send OTP to Phone ---
  Future<void> _handleSendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.instance.sendPasswordResetOtp(phone);

      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(result.errorMessage ?? 'Failed to send OTP code.'),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() {
        _verificationId = result.verificationId;
        _demoOtpCode = result.debugOtp;
        _currentStep = ForgotPasswordStep.verifyOtp;
      });

      _startResendTimer();

      // Clear any previous OTP inputs
      for (final c in _otpControllers) {
        c.clear();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.brandTeal,
          content: Text('Verification code sent to $phone'),
          duration: const Duration(seconds: 3),
        ),
      );

      // Focus first digit box
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_otpFocusNodes.isNotEmpty && mounted) {
          _otpFocusNodes[0].requestFocus();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error sending code: ${e.toString()}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Step 2: Verify OTP ---
  String _getEnteredOtp() {
    return _otpControllers.map((c) => c.text.trim()).join();
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _getEnteredOtp();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Please enter the complete 6-digit verification code.'),
        ),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    setState(() => _isLoading = true);

    try {
      final isValid = await AuthService.instance.verifyOtp(
        phoneNumber: phone,
        otpCode: otp,
        verificationId: _verificationId,
      );

      if (!mounted) return;

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Invalid verification code. Please check and try again.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.statusTaken,
          content: Text('Phone number verified successfully!'),
          duration: Duration(seconds: 2),
        ),
      );

      setState(() {
        _currentStep = ForgotPasswordStep.resetPassword;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Verification failed: ${e.toString()}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Step 3: Reset Password ---
  Future<void> _handleResetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final newPassword = _passwordController.text.trim();
    setState(() => _isLoading = true);

    try {
      await AuthService.instance.resetPassword(
        phoneNumber: phone,
        newPassword: newPassword,
      );

      if (!mounted) return;

      // Show success bottom sheet or dialog
      await _showSuccessDialog(phone);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Failed to reset password: ${e.toString()}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog(String phone) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.statusTaken,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Password Reset Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your password has been changed. You can now sign in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => SignInScreen(initialPhone: phone),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Sign In Now',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Step Indicator Widget ---
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepBadge(1, 'Phone', _currentStep.index >= 0, _currentStep.index > 0),
        Expanded(
          child: Container(
            height: 3,
            color: _currentStep.index >= 1 ? AppColors.brandTeal : AppColors.borderSubtle,
          ),
        ),
        _buildStepBadge(2, 'Verify OTP', _currentStep.index >= 1, _currentStep.index > 1),
        Expanded(
          child: Container(
            height: 3,
            color: _currentStep.index >= 2 ? AppColors.brandTeal : AppColors.borderSubtle,
          ),
        ),
        _buildStepBadge(3, 'New Password', _currentStep.index >= 2, false),
      ],
    );
  }

  Widget _buildStepBadge(int number, String label, bool isActive, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.brandTeal : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.brandTeal : AppColors.borderSubtle,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // --- Step 1: Phone Input View ---
  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.softTealBadge,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: AppColors.brandTeal,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Reset Password',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your registered phone number. We will send an SMS with a 6-digit verification code to reset your password.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Phone number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: '+94 77 123 4567',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.brandTeal),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brandTeal, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your phone number';
              }
              final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.length < 7) {
                return 'Please enter a valid phone number with at least 7 digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Send Verification Code',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 2: OTP Verification View ---
  Widget _buildOtpStep() {
    final phone = _phoneController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.softTealBadge,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.brandTeal,
            size: 30,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Enter Verification Code',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textMuted,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'We sent a 6-digit verification code to '),
              TextSpan(
                text: phone,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const TextSpan(text: '. Enter the code below to continue.'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            setState(() {
              _currentStep = ForgotPasswordStep.enterPhone;
            });
          },
          child: const Text(
            'Wrong number? Change phone number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.brandTeal,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Demo / Fallback indicator if OTP generated locally
        if (_demoOtpCode != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              border: Border.all(color: const Color(0xFF86EFAC)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF15803D), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Demo/Dev verification code: $_demoOtpCode',
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    for (int i = 0; i < 6 && i < _demoOtpCode!.length; i++) {
                      _otpControllers[i].text = _demoOtpCode![i];
                    }
                    setState(() {});
                  },
                  child: const Text(
                    'Auto-fill',
                    style: TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 6-digit PIN Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextFormField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(1),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.brandTeal, width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                  if (_getEnteredOtp().length == 6) {
                    _handleVerifyOtp();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // Resend Timer Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_canResend)
              Text(
                'Resend code in ${_resendCountdown}s',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _handleSendOtp,
                child: const Text(
                  'Didn\'t receive code? Resend OTP',
                  style: TextStyle(
                    color: AppColors.brandTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Verify Code',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // --- Step 3: Reset Password View ---
  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.softTealBadge,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.vpn_key_rounded,
              color: AppColors.brandTeal,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Create New Password',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your identity has been verified. Choose a secure new password for your MediCare account.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // New Password
          const Text(
            'New Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter new password (min. 6 chars)',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.brandTeal),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brandTeal, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a new password';
              }
              if (value.trim().length < 6) {
                return 'Password must be at least 6 characters long';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Confirm Password
          const Text(
            'Confirm New Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Re-enter your new password',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.brandTeal),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brandTeal, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please confirm your new password';
              }
              if (value.trim() != _passwordController.text.trim()) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Update Password',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Top Bar: Logo + Brand & Language Selector ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.brandTeal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.monitor_heart, color: Colors.white, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            l10n?.appName ?? 'MediCare',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const LanguagePillSelector(),
                ],
              ),

              const SizedBox(height: 20),

              // --- Back to Sign In Link ---
              GestureDetector(
                onTap: () {
                  if (_currentStep == ForgotPasswordStep.resetPassword) {
                    setState(() => _currentStep = ForgotPasswordStep.verifyOtp);
                  } else if (_currentStep == ForgotPasswordStep.verifyOtp) {
                    setState(() => _currentStep = ForgotPasswordStep.enterPhone);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, size: 20, color: AppColors.textDark),
                    const SizedBox(width: 8),
                    Text(
                      _currentStep == ForgotPasswordStep.enterPhone
                          ? (l10n?.backButton ?? 'Back to Sign In')
                          : 'Previous Step',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- Step Indicator ---
              _buildStepIndicator(),

              const SizedBox(height: 32),

              // --- Current Step Content ---
              if (_currentStep == ForgotPasswordStep.enterPhone)
                _buildPhoneStep()
              else if (_currentStep == ForgotPasswordStep.verifyOtp)
                _buildOtpStep()
              else
                _buildPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }
}
