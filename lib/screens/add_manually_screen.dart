import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/medicine.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import 'caregiver_screen.dart';
import 'welcome_screen.dart';

class AddManuallyScreen extends StatefulWidget {
  final bool isFromScan;
  final String? initialName;
  final String? initialDosage;
  final String? initialInstructions;
  final String? patientId;
  final String? patientName;

  const AddManuallyScreen({
    super.key,
    this.isFromScan = false,
    this.initialName,
    this.initialDosage,
    this.initialInstructions,
    this.patientId,
    this.patientName,
  });

  @override
  State<AddManuallyScreen> createState() => _AddManuallyScreenState();
}

class _AddManuallyScreenState extends State<AddManuallyScreen> {
  GlobalKey<FormState>? _formKey;
  GlobalKey<FormState> get formKey => _formKey ??= GlobalKey<FormState>();

  TextEditingController? _nameController;
  TextEditingController? _dosageController;
  TextEditingController? _instructionsController;

  TextEditingController get nameController => _nameController ??= TextEditingController(
        text: widget.initialName ?? (widget.isFromScan ? 'Metformin' : ''),
      );
  TextEditingController get dosageController => _dosageController ??= TextEditingController(
        text: widget.initialDosage ?? (widget.isFromScan ? '500 mg' : ''),
      );
  TextEditingController get instructionsController =>
      _instructionsController ??= TextEditingController(
        text: widget.initialInstructions ?? (widget.isFromScan ? 'Take with food' : ''),
      );

  String? _frequency;
  String get frequency => _frequency ??= 'Once daily';

  String? _selectedTimeOfDay;
  String get selectedTimeOfDay => _selectedTimeOfDay ??= 'Morning';

  bool _isSaving = false;
  bool _isCaregiver = false;
  List<UserProfile> _linkedPatients = [];
  String? _selectedPatientId;
  String? _selectedPatientName;
  bool _isLoadingPatients = false;

  static const List<String> _frequencies = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Every 8 hours',
    'Every 12 hours',
    'As needed',
  ];

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _nameController = TextEditingController(
      text: widget.initialName ?? (widget.isFromScan ? 'Metformin' : ''),
    );
    _dosageController = TextEditingController(
      text: widget.initialDosage ?? (widget.isFromScan ? '500 mg' : ''),
    );
    _instructionsController = TextEditingController(
      text: widget.initialInstructions ?? (widget.isFromScan ? 'Take with food' : ''),
    );
    _frequency = 'Once daily';
    _selectedTimeOfDay = 'Morning';
    _selectedPatientId = widget.patientId;
    _selectedPatientName = widget.patientName;
    _initCaregiverPatientSelection();
  }

  Future<void> _initCaregiverPatientSelection() async {
    final currentUid = AuthService.instance.currentUser?.uid;
    final profile = await AuthService.instance.fetchCurrentUserProfile(currentUid);
    final isCaregiver = profile?.role == UserRole.caregiver || widget.patientId != null;

    if (!isCaregiver) return;

    if (mounted) {
      setState(() {
        _isCaregiver = true;
        _isLoadingPatients = true;
      });
    }

    List<UserProfile> patients = [];
    if (currentUid != null) {
      patients = await AuthService.instance.getLinkedPatients(currentUid);
    }

    if (mounted) {
      setState(() {
        _isLoadingPatients = false;
        _linkedPatients = patients;
        if (_selectedPatientId == null || _selectedPatientId!.isEmpty) {
          if (patients.isNotEmpty) {
            _selectedPatientId = patients.first.uid;
            _selectedPatientName = patients.first.name;
          }
        } else {
          final matched = patients.where((p) => p.uid == _selectedPatientId).firstOrNull;
          if (matched != null) {
            _selectedPatientName = matched.name;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController?.dispose();
    _dosageController?.dispose();
    _instructionsController?.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String label, {bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 18.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          if (isOptional)
            const Padding(
              padding: EdgeInsets.only(left: 6.0),
              child: Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeRadioOption({
    required String value,
    required String title,
    required String timeSubtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    final isSelected = selectedTimeOfDay == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTimeOfDay = value;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandTeal.withOpacity(0.07) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.brandTeal : AppColors.borderSubtle,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Radio widget
              Radio<String>(
                value: value,
                groupValue: selectedTimeOfDay,
                activeColor: AppColors.brandTeal,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedTimeOfDay = val);
                  }
                },
              ),
              const SizedBox(width: 8),

              // Time badge icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      timeSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.brandTeal, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final form = formKey.currentState;
    if (form != null && !form.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();

      // Schedule time corresponding to the selected radio button
      DateTime doseTime;
      switch (selectedTimeOfDay) {
        case 'Evening':
          doseTime = DateTime(now.year, now.month, now.day, 18, 0);
          break;
        case 'Night':
          doseTime = DateTime(now.year, now.month, now.day, 21, 0);
          break;
        case 'Morning':
        default:
          doseTime = DateTime(now.year, now.month, now.day, 8, 0);
          break;
      }

      final patientId = _isCaregiver
          ? (_selectedPatientId ?? widget.patientId ?? AuthService.instance.currentUser?.uid ?? 'p1')
          : (widget.patientId ?? AuthService.instance.currentUser?.uid ?? 'p1');
      final medicineId = DateTime.now().millisecondsSinceEpoch.toString();

      final medicine = Medicine(
        id: medicineId,
        patientId: patientId,
        name: nameController.text.trim(),
        dosage: dosageController.text.trim(),
        frequency: frequency,
        instructions: instructionsController.text.trim(),
        scheduledTimes: [doseTime],
        createdAt: now,
        addedViaScan: widget.isFromScan,
      );

      // Persist in local storage
      await LocalDbService.instance.upsertMedicine(medicine);

      // Create initial dose log for the day
      final doseLog = DoseLog(
        id: 'dose_${medicineId}_${now.day}',
        medicineId: medicineId,
        scheduledFor: doseTime,
        status: DoseStatus.pending,
      );
      await LocalDbService.instance.upsertDoseLog(doseLog);

      // Persist to Firebase Firestore
      try {
        final firestore = FirebaseFirestore.instance;

        // 1. Root collection `medicines`
        await firestore
            .collection('medicines')
            .doc(medicine.id)
            .set(medicine.toMap(), SetOptions(merge: true));

        // 2. Under patient profile: users/{patientId}/medicines/{medicineId}
        await firestore
            .collection('users')
            .doc(patientId)
            .collection('medicines')
            .doc(medicine.id)
            .set(medicine.toMap(), SetOptions(merge: true));

        // 3. Save dose log in Firestore
        await firestore
            .collection('dose_logs')
            .doc(doseLog.id)
            .set(doseLog.toMap(), SetOptions(merge: true));

        await LocalDbService.instance.markSynced(doseLog.id);
      } catch (firestoreError) {
        debugPrint('Firestore save deferred or offline: $firestoreError');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isCaregiver && _selectedPatientName != null && _selectedPatientName!.isNotEmpty
                      ? '${medicine.name} added for $_selectedPatientName!'
                      : '${medicine.name} added successfully!',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.statusTaken,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.of(context).pop(medicine);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save medicine: $e'),
          backgroundColor: AppColors.statusMissed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.appName ?? 'MediCare',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                _isCaregiver
                                    ? 'Caregiver View • Add Medication'
                                    : (l10n?.patientViewSubtitle ?? 'Patient view'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isCaregiver ? AppColors.brandNavy : AppColors.textMuted,
                                  fontWeight: _isCaregiver ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const LanguagePillSelector(),
                ],
              ),
            ),

            // Top Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const CaregiverScreen()),
                          (r) => false,
                        );
                      },
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: Text(l10n?.caregiverMode ?? 'Caregiver'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDark,
                        side: const BorderSide(color: AppColors.borderSubtle),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
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
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(color: AppColors.borderSubtle),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.brandTeal),
                            const SizedBox(width: 8),
                            Text(
                              widget.isFromScan
                                  ? (l10n?.backToScan ?? 'Back to scan')
                                  : (l10n?.backButton ?? 'Back'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brandTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Header Section
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
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n?.checkDetailsSubtitle ?? 'Make sure everything matches your label.',
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.brandTeal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Icon(Icons.medication_rounded, color: AppColors.brandTeal, size: 28),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MANUAL ENTRY',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: AppColors.brandTeal,
                                    ),
                                  ),
                                  Text(
                                    l10n?.addMedicine ?? 'Add medicine',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Fill in the medication details and reminder schedule below.',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // 0. Patient Selection (Caregiver Mode)
                      if (_isCaregiver) ...[
                        _buildFieldLabel('Patient (Select patient for this medicine) *'),
                        if (_isLoadingPatients)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Loading linked patients...',
                                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          )
                        else if (_linkedPatients.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: _linkedPatients.any((p) => p.uid == _selectedPatientId)
                                ? _selectedPatientId
                                : _linkedPatients.first.uid,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person, color: AppColors.brandNavy),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              filled: true,
                              fillColor: const Color(0xFFF0F4F8),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.brandNavy.withValues(alpha: 0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.brandNavy, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.statusMissed, width: 1.5),
                              ),
                            ),
                            dropdownColor: Colors.white,
                            items: _linkedPatients.map((p) {
                              return DropdownMenuItem<String>(
                                value: p.uid,
                                child: Text(
                                  '${p.name.isNotEmpty ? p.name : "Patient"} (${(p.phoneNumber ?? "").isNotEmpty ? p.phoneNumber : p.uid})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedPatientId = val;
                                  _selectedPatientName =
                                      _linkedPatients.firstWhere((p) => p.uid == val).name;
                                });
                              }
                            },
                            validator: (val) {
                              if (_isCaregiver && (val == null || val.isEmpty)) {
                                return 'Please select which patient this medicine is for';
                              }
                              return null;
                            },
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDBA74)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFFC2410C), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedPatientName != null && _selectedPatientName!.isNotEmpty
                                        ? 'Assigned to: $_selectedPatientName'
                                        : 'No linked patients found. Please link a patient first.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9A3412),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],

                      // 1. Medicine Name Field
                      _buildFieldLabel(l10n?.medicineNameLabel ?? 'Medicine name'),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'e.g., Metformin, Lisinopril, Panadol',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
                          prefixIcon: const Icon(Icons.medication_outlined, color: AppColors.brandTeal),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: const Color(0xFFF9F9FB),
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
                            borderSide: const BorderSide(color: AppColors.statusMissed, width: 1.5),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.statusMissed, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the medicine name';
                          }
                          return null;
                        },
                      ),

                      // 2. Dosage Field
                      _buildFieldLabel(l10n?.dosageLabel ?? 'Dosage'),
                      TextFormField(
                        controller: dosageController,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'e.g., 500 mg, 1 tablet, 10 ml',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
                          prefixIcon: const Icon(Icons.vaccines_outlined, color: AppColors.brandTeal),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: const Color(0xFFF9F9FB),
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
                            borderSide: const BorderSide(color: AppColors.statusMissed, width: 1.5),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.statusMissed, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the dosage';
                          }
                          return null;
                        },
                      ),

                      // 3. How Often (Frequency) Field
                      _buildFieldLabel(l10n?.frequencyLabel ?? 'How often?'),
                      DropdownButtonFormField<String>(
                        value: _frequencies.contains(frequency) ? frequency : _frequencies.first,
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.event_repeat_outlined, color: AppColors.brandTeal),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: const Color(0xFFF9F9FB),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.brandTeal, width: 2),
                          ),
                        ),
                        items: _frequencies.map((freq) {
                          return DropdownMenuItem<String>(
                            value: freq,
                            child: Text(
                              freq,
                              style: const TextStyle(fontSize: 16, color: AppColors.textDark),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _frequency = val);
                          }
                        },
                      ),

                      // 4. Radio Button: Morning, Evening, Night
                      _buildFieldLabel('When to take (Time of day)'),
                      _buildTimeRadioOption(
                        value: 'Morning',
                        title: 'Morning',
                        timeSubtitle: 'Around 8:00 AM • Recommended with breakfast',
                        icon: Icons.wb_sunny_rounded,
                        iconColor: const Color(0xFFD97706),
                        iconBgColor: const Color(0xFFFEF3C7),
                      ),
                      _buildTimeRadioOption(
                        value: 'Evening',
                        title: 'Evening',
                        timeSubtitle: 'Around 6:00 PM • Recommended with dinner',
                        icon: Icons.wb_twilight_rounded,
                        iconColor: const Color(0xFFEA580C),
                        iconBgColor: const Color(0xFFFFEDD5),
                      ),
                      _buildTimeRadioOption(
                        value: 'Night',
                        title: 'Night',
                        timeSubtitle: 'Around 9:00 PM • Recommended before sleep',
                        icon: Icons.nightlight_round,
                        iconColor: const Color(0xFF4F46E5),
                        iconBgColor: const Color(0xFFEEF2FF),
                      ),

                      // 5. Instructions (Optional)
                      _buildFieldLabel(l10n?.instructionsLabel ?? 'Instructions', isOptional: true),
                      TextFormField(
                        controller: instructionsController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 16),
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'e.g., Take with food, drink a full glass of water, avoid dairy',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Icon(Icons.notes_rounded, color: AppColors.textMuted),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: const Color(0xFFF9F9FB),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.brandTeal, width: 2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _handleSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.check, size: 22),
                          label: Text(
                            _isSaving
                                ? 'Saving...'
                                : (l10n?.saveMedicine ?? 'Save medicine'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandTeal,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.brandTeal.withOpacity(0.6),
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
