import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../l10n/app_localizations.dart';
import 'sign_in_screen.dart';

class PatientSignupScreen extends StatefulWidget {
  const PatientSignupScreen({super.key});

  @override
  State<PatientSignupScreen> createState() => _PatientSignupScreenState();
}

class _PatientSignupScreenState extends State<PatientSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  bool _showEmergencyContact = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  int _reminderStyleIndex = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();

      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your full name.')),
        );
        return;
      }

      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your phone number.')),
        );
        return;
      }

      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 6 characters.')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final currentLocale = Localizations.localeOf(context);
        final language = currentLocale.languageCode == 'si'
            ? AppLanguage.sinhala
            : AppLanguage.english;

        final age = int.tryParse(_ageController.text.trim());

        await AuthService.instance.signUpPatient(
          name: name,
          phoneNumber: phone,
          password: password,
          age: age,
          emergencyContactName: _emergencyNameController.text.trim(),
          emergencyContactPhone: _emergencyPhoneController.text.trim(),
          soundEnabled: _soundEnabled,
          vibrationEnabled: _vibrationEnabled,
          reminderStyle: _reminderStyleIndex,
          language: language,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.brandTeal,
            content: Text('Account created successfully! Please sign in.'),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SignInScreen(),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        String message = 'Sign up failed. Please try again.';
        if (e.toString().contains('email-already-in-use')) {
          message = 'An account with this phone number already exists. Please sign in.';
        } else if (e.toString().contains('network-request-failed')) {
          message = 'Network error. Please check your internet connection.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(message),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                
                const SizedBox(height: 24),
                
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back, size: 20, color: AppColors.textDark),
                      const SizedBox(width: 8),
                      Text(
                        l10n?.backButton ?? 'Back',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  l10n?.patientAccountTitle ?? 'PATIENT ACCOUNT',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandTeal,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n?.createAccountTitle ?? 'Create your account',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n?.accountDetailsSubtitle ?? 'A few details help us personalize MediCare.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildFieldLabel(l10n?.fullNameLabel ?? 'Full name'),
                _buildTextField(
                  controller: _nameController,
                  placeholder: l10n?.fullNameHint ?? 'Your full name',
                ),
                const SizedBox(height: 20),
                
                _buildFieldLabel(l10n?.ageLabel ?? 'Age'),
                _buildTextField(
                  controller: _ageController,
                  placeholder: l10n?.ageHint ?? 'Age',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                
                _buildFieldLabel(l10n?.phoneNumberLabel ?? 'Phone number'),
                _buildTextField(
                  controller: _phoneController,
                  placeholder: l10n?.phoneNumberHint ?? '+94 77 123 4567',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                
                _buildFieldLabel('Password'),
                _buildTextField(
                  controller: _passwordController,
                  placeholder: 'Create a password (min 6 characters)',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.trim().length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEmergencyContact = !_showEmergencyContact;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderSubtle),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showEmergencyContact ? Icons.arrow_drop_down : Icons.play_arrow,
                          color: AppColors.brandTeal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n?.addEmergencyContact ?? 'Add emergency contact (optional)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (_showEmergencyContact) ...[
                  const SizedBox(height: 20),
                  _buildFieldLabel(l10n?.contactNameLabel ?? 'Contact name'),
                  _buildTextField(
                    controller: _emergencyNameController,
                    placeholder: l10n?.contactNameHint ?? 'Name',
                  ),
                  const SizedBox(height: 20),
                  _buildFieldLabel(l10n?.contactPhoneLabel ?? 'Contact phone'),
                  _buildTextField(
                    controller: _emergencyPhoneController,
                    placeholder: l10n?.phoneNumberHint ?? '+94 77 123 4567',
                    keyboardType: TextInputType.phone,
                  ),
                ],
                
                const SizedBox(height: 32),
                
                Text(
                  l10n?.reminderPreferencesTitle ?? 'Reminder preferences',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderSubtle),
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.volume_up_outlined, color: AppColors.textDark, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                l10n?.soundLabel ?? 'Sound',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _soundEnabled,
                            onChanged: (val) => setState(() => _soundEnabled = val),
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.brandTeal,
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.borderSubtle),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.vibration_outlined, color: AppColors.textDark, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                l10n?.vibrationLabel ?? 'Vibration',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _vibrationEnabled,
                            onChanged: (val) => setState(() => _vibrationEnabled = val),
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.brandTeal,
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.borderSubtle),
                      
                      _buildFieldLabel(l10n?.reminderStyleLabel ?? 'Reminder style'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.borderSubtle),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: [
                              l10n?.gentleReminder ?? 'Gentle reminder',
                              l10n?.persistentReminder ?? 'Persistent reminder',
                              l10n?.silentReminder ?? 'Silent reminder'
                            ][_reminderStyleIndex],
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                            items: [
                              l10n?.gentleReminder ?? 'Gentle reminder',
                              l10n?.persistentReminder ?? 'Persistent reminder',
                              l10n?.silentReminder ?? 'Silent reminder'
                            ].map((style) => DropdownMenuItem(
                                      value: style,
                                      child: Text(
                                        style,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final options = [
                                  l10n?.gentleReminder ?? 'Gentle reminder',
                                  l10n?.persistentReminder ?? 'Persistent reminder',
                                  l10n?.silentReminder ?? 'Silent reminder'
                                ];
                                setState(() => _reminderStyleIndex = options.indexOf(val));
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_rounded, size: 20),
                              const SizedBox(width: 12),
                              const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
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
    );
  }
}
