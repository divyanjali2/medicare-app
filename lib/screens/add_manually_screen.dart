import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import 'welcome_screen.dart';

class AddManuallyScreen extends StatefulWidget {
  final bool isFromScan;
  
  const AddManuallyScreen({super.key, this.isFromScan = true});

  @override
  State<AddManuallyScreen> createState() => _AddManuallyScreenState();
}

class _AddManuallyScreenState extends State<AddManuallyScreen> {
  final _nameController = TextEditingController(text: 'Metformin');
  final _dosageController = TextEditingController(text: '500 mg');
  final _instructionsController = TextEditingController(text: 'Take with food');
  
  int _frequencyIndex = 0; // "Twice daily"
  
  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 20.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final frequencies = ['Twice daily', 'Once daily', 'As needed'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.appName ?? 'MediCare',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            l10n?.patientViewSubtitle ?? 'Patient view',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const LanguagePillSelector(),
                ],
              ),
            ),
            
            // Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: Text(l10n?.caregiverMode ?? 'Caregiver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (r) => false,
                      );
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(l10n?.signOutButton ?? 'Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(color: AppColors.borderSubtle),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.brandTeal),
                          const SizedBox(width: 8),
                          Text(
                            l10n?.backToScan ?? 'Back to scan',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (widget.isFromScan) ...[
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD5F0D6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Icon(Icons.document_scanner_outlined, color: AppColors.statusTaken, size: 28),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n?.scanComplete ?? 'Scan complete',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.statusTaken,
                                  ),
                                ),
                                Text(
                                  l10n?.checkDetailsTitle ?? 'Check the details',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n?.checkDetailsSubtitle ?? 'Make sure everything matches your label.',
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Fields
                    _buildFieldLabel(l10n?.medicineNameLabel ?? 'Medicine name'),
                    _buildTextField(_nameController),

                    _buildFieldLabel(l10n?.dosageLabel ?? 'Dosage'),
                    _buildTextField(_dosageController),

                    _buildFieldLabel(l10n?.frequencyLabel ?? 'How often?'),
                    DropdownButtonFormField<int>(
                      value: _frequencyIndex,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.brandTeal, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.brandTeal, width: 2),
                        ),
                      ),
                      items: List.generate(frequencies.length, (index) {
                        return DropdownMenuItem(
                          value: index,
                          child: Text(frequencies[index]),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setState(() => _frequencyIndex = val);
                      },
                    ),

                    _buildFieldLabel(l10n?.instructionsLabel ?? 'Instructions'),
                    _buildTextField(_instructionsController),

                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.check, size: 20),
                        label: Text(
                          l10n?.saveMedicine ?? 'Save medicine',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
