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
  final Medicine? existingMedicine;
  final List<String>? candidates;

  const AddManuallyScreen({
    super.key,
    this.isFromScan = false,
    this.initialName,
    this.initialDosage,
    this.initialInstructions,
    this.patientId,
    this.patientName,
    this.existingMedicine,
    this.candidates,
  });

  @override
  State<AddManuallyScreen> createState() => AddManuallyScreenState();
}

class AddManuallyScreenState extends State<AddManuallyScreen> {
  GlobalKey<FormState>? _formKey;
  GlobalKey<FormState> get formKey => _formKey ??= GlobalKey<FormState>();

  List<String> get _candidates => widget.candidates ?? [];

  TextEditingController? _nameController;
  TextEditingController? _dosageController;
  TextEditingController? _instructionsController;

  TextEditingController get nameController => _nameController ??= TextEditingController(
        text: widget.existingMedicine?.name ??
            widget.initialName ??
            (widget.isFromScan && _candidates.isNotEmpty ? _candidates.first : ''),
      );
  TextEditingController get dosageController => _dosageController ??= TextEditingController(
        text: widget.existingMedicine?.dosage ?? widget.initialDosage ?? '',
      );
  TextEditingController get instructionsController =>
      _instructionsController ??= TextEditingController(
        text: widget.existingMedicine?.instructions ?? widget.initialInstructions ?? '',
      );

  String? _frequency;
  String get frequency => _frequency ?? widget.existingMedicine?.frequency ?? '';

  Set<String> _selectedTimesOfDay = {'Morning'};
  Set<String> get selectedTimesOfDay => _selectedTimesOfDay;
  String get selectedTimeOfDay => _selectedTimesOfDay.isNotEmpty ? _selectedTimesOfDay.first : 'Morning';

  bool _isSaving = false;
  bool _isCaregiver = false;
  List<UserProfile> _linkedPatients = [];
  String? _selectedPatientId;
  String? _selectedPatientName;
  bool _isLoadingPatients = false;

  bool get _isSaveEnabled {
    final hasName = (_nameController?.text ?? '').trim().isNotEmpty;
    final hasDosage = (_dosageController?.text ?? '').trim().isNotEmpty;
    final hasFreq = (_frequency ?? '').trim().isNotEmpty;
    return hasName && hasDosage && hasFreq && _selectedTimesOfDay.isNotEmpty && !_isSaving;
  }

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
    final initialName = widget.existingMedicine?.name ??
        widget.initialName ??
        (widget.isFromScan && _candidates.isNotEmpty ? _candidates.first : '');

    _nameController = TextEditingController(text: initialName);
    _dosageController = TextEditingController(
      text: widget.existingMedicine?.dosage ?? widget.initialDosage ?? '',
    );
    _instructionsController = TextEditingController(
      text: widget.existingMedicine?.instructions ?? widget.initialInstructions ?? '',
    );

    _nameController?.addListener(_onFieldChanged);
    _dosageController?.addListener(_onFieldChanged);

    final existingFreq = widget.existingMedicine?.frequency;
    if (existingFreq != null && existingFreq.isNotEmpty) {
      final matched = _frequencies.firstWhere(
        (f) => f.toLowerCase() == existingFreq.trim().toLowerCase(),
        orElse: () => _frequencies.contains(existingFreq) ? existingFreq : _frequencies.first,
      );
      _frequency = matched;
    } else {
      _frequency = null;
    }

    _selectedTimesOfDay = <String>{};
    if (widget.existingMedicine?.scheduledTimes.isNotEmpty == true) {
      for (final st in widget.existingMedicine!.scheduledTimes) {
        final hour = st.hour;
        if (hour >= 17 && hour < 20) {
          _selectedTimesOfDay.add('Evening');
        } else if (hour >= 20 || hour < 5) {
          _selectedTimesOfDay.add('Night');
        } else {
          _selectedTimesOfDay.add('Morning');
        }
      }
    }
    if (_selectedTimesOfDay.isEmpty) {
      _selectedTimesOfDay.add('Morning');
    }

    _selectedPatientId = widget.patientId ?? widget.existingMedicine?.patientId;
    _selectedPatientName = widget.patientName;
    _initCaregiverPatientSelection();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController?.removeListener(_onFieldChanged);
    _dosageController?.removeListener(_onFieldChanged);
    _nameController?.dispose();
    _dosageController?.dispose();
    _instructionsController?.dispose();
    super.dispose();
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

  Widget _buildTimeCheckboxOption({
    required String value,
    required String title,
    required String timeSubtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    final isSelected = _selectedTimesOfDay.contains(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedTimesOfDay.contains(value)) {
              if (_selectedTimesOfDay.length > 1) {
                _selectedTimesOfDay.remove(value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('At least one time of day must be selected.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } else {
              _selectedTimesOfDay.add(value);
            }
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandTeal.withValues(alpha: 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.brandTeal : AppColors.borderSubtle,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Checkbox widget
              Checkbox(
                value: isSelected,
                activeColor: AppColors.brandTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedTimesOfDay.add(value);
                    } else {
                      if (_selectedTimesOfDay.length > 1) {
                        _selectedTimesOfDay.remove(value);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('At least one time of day must be selected.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  });
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

    if (_selectedTimesOfDay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one time of day (Morning, Evening, or Night).'),
          backgroundColor: AppColors.statusLate,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();

      final List<DateTime> scheduledTimesList = [];
      if (_selectedTimesOfDay.contains('Morning')) {
        scheduledTimesList.add(DateTime(now.year, now.month, now.day, 8, 0));
      }
      if (_selectedTimesOfDay.contains('Evening')) {
        scheduledTimesList.add(DateTime(now.year, now.month, now.day, 18, 0));
      }
      if (_selectedTimesOfDay.contains('Night')) {
        scheduledTimesList.add(DateTime(now.year, now.month, now.day, 21, 0));
      }

      if (scheduledTimesList.isEmpty) {
        scheduledTimesList.add(DateTime(now.year, now.month, now.day, 8, 0));
      }

      final patientId = _isCaregiver
          ? (_selectedPatientId ?? widget.patientId ?? AuthService.instance.currentUser?.uid ?? 'p1')
          : (widget.patientId ?? AuthService.instance.currentUser?.uid ?? 'p1');
      final medicineId = widget.existingMedicine?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final medicine = Medicine(
        id: medicineId,
        patientId: patientId,
        name: nameController.text.trim(),
        dosage: dosageController.text.trim(),
        frequency: frequency,
        instructions: instructionsController.text.trim(),
        scheduledTimes: scheduledTimesList,
        createdAt: widget.existingMedicine?.createdAt ?? now,
        addedViaScan: widget.existingMedicine?.addedViaScan ?? widget.isFromScan,
        synced: false,
      );

      // Persist in local storage
      await LocalDbService.instance.upsertMedicine(medicine);

      // Create initial dose log for each scheduled time for the day
      final List<DoseLog> createdLogs = [];
      for (final doseTime in scheduledTimesList) {
        final doseLog = DoseLog(
          id: 'dose_${medicineId}_${now.day}_${doseTime.hour}_${doseTime.minute}',
          medicineId: medicineId,
          scheduledFor: doseTime,
          status: DoseStatus.pending,
          synced: false,
        );
        await LocalDbService.instance.upsertDoseLog(doseLog);
        createdLogs.add(doseLog);
      }

      // Persist to Firebase Firestore (times out gracefully if offline)
      try {
        final firestore = FirebaseFirestore.instance;

        // 1. Root collection `medicines`
        await firestore
            .collection('medicines')
            .doc(medicine.id)
            .set(medicine.toMap(), SetOptions(merge: true))
            .timeout(const Duration(milliseconds: 1500));

        // 2. Under patient profile: users/{patientId}/medicines/{medicineId}
        await firestore
            .collection('users')
            .doc(patientId)
            .collection('medicines')
            .doc(medicine.id)
            .set(medicine.toMap(), SetOptions(merge: true))
            .timeout(const Duration(milliseconds: 1500));

        await LocalDbService.instance.markMedicineSynced(medicine.id);

        // 3. Save each dose log in Firestore
        for (final doseLog in createdLogs) {
          try {
            await firestore
                .collection('dose_logs')
                .doc(doseLog.id)
                .set(doseLog.toMap(), SetOptions(merge: true))
                .timeout(const Duration(milliseconds: 1500));

            await LocalDbService.instance.markSynced(doseLog.id);
          } catch (_) {}
        }
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
                  widget.existingMedicine != null
                      ? '${medicine.name} updated successfully!'
                      : (_isCaregiver && _selectedPatientName != null && _selectedPatientName!.isNotEmpty
                          ? '${medicine.name} added for $_selectedPatientName!'
                          : '${medicine.name} added successfully!'),
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
                                color: AppColors.brandTeal.withValues(alpha: 0.12),
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
                                  Text(
                                    widget.existingMedicine != null
                                        ? 'EDIT MEDICINE'
                                        : (l10n?.manualEntry ?? 'MANUAL ENTRY'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: AppColors.brandTeal,
                                    ),
                                  ),
                                  Text(
                                    widget.existingMedicine != null
                                        ? 'Edit medicine'
                                        : (l10n?.addMedicine ?? 'Add medicine'),
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
                          widget.existingMedicine != null
                              ? 'Update the medication details and reminder schedule below.'
                              : (l10n?.manualEntrySubtitle ?? 'Fill in the medication details and reminder schedule below.'),
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
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
                      if (widget.isFromScan && _candidates.isEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Couldn't read the name, please type it",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      if (widget.isFromScan && _candidates.length > 1) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Other detected names:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _candidates.skip(1).map((candidate) {
                            final isSelected = _nameController?.text.trim() == candidate;
                            return ChoiceChip(
                              label: Text(candidate),
                              selected: isSelected,
                              selectedColor: AppColors.brandTeal.withValues(alpha: 0.18),
                              backgroundColor: const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.brandTeal : AppColors.textDark,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _nameController?.text = candidate;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],

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
                        value: _frequency != null && _frequencies.contains(_frequency) ? _frequency : null,
                        hint: const Text('Select frequency', style: TextStyle(color: AppColors.textMuted)),
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
                            setState(() {
                              _frequency = val;
                              if (val == 'Twice daily') {
                                _selectedTimesOfDay = {'Morning', 'Night'};
                              } else if (val == 'Three times daily' || val == 'Every 8 hours') {
                                _selectedTimesOfDay = {'Morning', 'Evening', 'Night'};
                              }
                            });
                          }
                        },
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please select how often to take this medicine';
                          }
                          return null;
                        },
                      ),

                      // 4. When to take (Time of day) - Multi-select Checkboxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildFieldLabel(l10n?.whenToTake ?? 'When to take (Time of day)'),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedTimesOfDay = {'Morning', 'Evening', 'Night'};
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandTeal.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'All 3',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.brandTeal,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedTimesOfDay = {'Morning', 'Night'};
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandNavy.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Morning & Night',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.brandNavy,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Check one, two, or all times of day when this medicine should be taken.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                      _buildTimeCheckboxOption(
                        value: 'Morning',
                        title: l10n?.morning ?? 'Morning',
                        timeSubtitle: 'Around 8:00 AM • Recommended with breakfast',
                        icon: Icons.wb_sunny_rounded,
                        iconColor: const Color(0xFFD97706),
                        iconBgColor: const Color(0xFFFEF3C7),
                      ),
                      _buildTimeCheckboxOption(
                        value: 'Evening',
                        title: l10n?.evening ?? 'Evening',
                        timeSubtitle: 'Around 6:00 PM • Recommended with dinner',
                        icon: Icons.wb_twilight_rounded,
                        iconColor: const Color(0xFFEA580C),
                        iconBgColor: const Color(0xFFFFEDD5),
                      ),
                      _buildTimeCheckboxOption(
                        value: 'Night',
                        title: l10n?.night ?? 'Night',
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
                          onPressed: _isSaveEnabled ? _handleSave : null,
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
                                ? (l10n?.saving ?? 'Saving...')
                                : (widget.existingMedicine != null
                                    ? 'Update medicine'
                                    : (l10n?.saveMedicine ?? 'Save medicine')),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandTeal,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.brandTeal.withValues(alpha: 0.4),
                            disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
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
