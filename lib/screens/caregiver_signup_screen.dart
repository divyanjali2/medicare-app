import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'today_dashboard_screen.dart';

class CaregiverSignupScreen extends StatefulWidget {
  const CaregiverSignupScreen({super.key});

  @override
  State<CaregiverSignupScreen> createState() => _CaregiverSignupScreenState();
}

class _CaregiverSignupScreenState extends State<CaregiverSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _reminderStyle = 'Gentle reminder';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleSignup() {
    if (_formKey.currentState!.validate()) {
      // Simulate sending verification code
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const TodayDashboardScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Top Bar: Logo & Language Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                        const Text(
                          'MediCare',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderSubtle),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.language, size: 16, color: AppColors.textDark),
                          SizedBox(width: 6),
                          Text(
                            'English',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textDark),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Back Button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Row(
                    children: const [
                      Icon(Icons.arrow_back, size: 20, color: AppColors.textDark),
                      SizedBox(width: 8),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                const Text(
                  'CAREGIVER ACCOUNT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandTeal,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create your account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A few details help us personalize MediCare.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Full Name Field
                _buildFieldLabel('Full name'),
                _buildTextField(
                  controller: _nameController,
                  placeholder: 'Your full name',
                ),
                const SizedBox(height: 20),
                
                // Phone Number Field
                _buildFieldLabel('Phone number'),
                _buildTextField(
                  controller: _phoneController,
                  placeholder: '+94 77 123 4567',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                
                // Email Field (Optional)
                _buildFieldLabel('Email (optional)'),
                _buildTextField(
                  controller: _emailController,
                  placeholder: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                ),
                
                const SizedBox(height: 32),
                
                // Reminder preferences section
                const Text(
                  'Reminder preferences',
                  style: TextStyle(
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
                      // Sound
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.volume_up_outlined, color: AppColors.textDark, size: 22),
                              SizedBox(width: 12),
                              Text(
                                'Sound',
                                style: TextStyle(
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
                      
                      // Vibration
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.vibration_outlined, color: AppColors.textDark, size: 22),
                              SizedBox(width: 12),
                              Text(
                                'Vibration',
                                style: TextStyle(
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
                      
                      // Reminder style
                      _buildFieldLabel('Reminder style'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.borderSubtle),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _reminderStyle,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                            items: ['Gentle reminder', 'Persistent reminder', 'Silent reminder']
                                .map((style) => DropdownMenuItem(
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
                              if (val != null) setState(() => _reminderStyle = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Send verification code Button (Navy Blue for Caregiver)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _handleSignup,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.send_to_mobile_outlined, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Send verification code',
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
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.textMuted) : null,
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
      ),
    );
  }
}
