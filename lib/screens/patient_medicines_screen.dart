import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/medicine.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../widgets/profile_menu_button.dart';
import 'add_manually_screen.dart';
import 'add_medicine_screen.dart';
import 'caregiver_screen.dart';
import 'pill_calendar_screen.dart';
import 'today_dashboard_screen.dart';
import '../widgets/medicines_modal.dart';

/// Full page to view all medicines added for the patient.
class PatientMedicinesScreen extends StatefulWidget {
  final String? viewingPatientId;
  final String? viewingPatientName;

  const PatientMedicinesScreen({
    super.key,
    this.viewingPatientId,
    this.viewingPatientName,
  });

  @override
  State<PatientMedicinesScreen> createState() => _PatientMedicinesScreenState();
}

class _PatientMedicinesScreenState extends State<PatientMedicinesScreen> {
  int get _currentIndex => _isCaregiverMode ? 2 : 3; // Medicines tab
  bool _isLoading = true;
  List<Medicine> _medicines = [];
  String _effectivePatientId = 'p1';
  bool _isCaregiverMode = false;
  String _patientName = '';

  @override
  void initState() {
    super.initState();
    if (widget.viewingPatientName != null && widget.viewingPatientName!.isNotEmpty) {
      _patientName = widget.viewingPatientName!;
      _isCaregiverMode = true;
    }
    _loadAllMedicines();
  }

  Future<void> _loadAllMedicines() async {
    final List<Medicine> combined = [];
    try {
      String? currentUid;
      UserProfile? profile;
      try {
        currentUid = AuthService.instance.currentUser?.uid;
        profile = await AuthService.instance.fetchCurrentUserProfile(currentUid);
      } catch (_) {}

      String patientId = widget.viewingPatientId ?? '';
      bool caregiverMode = widget.viewingPatientId != null;

      if (profile?.role == UserRole.caregiver) {
        caregiverMode = true;
        if (patientId.isEmpty && profile!.linkedPatientIds.isNotEmpty) {
          patientId = profile.linkedPatientIds.first;
        }
      }

      if (patientId.isEmpty) {
        patientId = currentUid ?? (profile?.uid ?? 'p1');
      }

      _effectivePatientId = patientId;
      _isCaregiverMode = caregiverMode;

      if (widget.viewingPatientName != null && widget.viewingPatientName!.isNotEmpty) {
        _patientName = widget.viewingPatientName!;
      } else if (caregiverMode && patientId != currentUid && patientId != 'p1') {
        try {
          final pDoc = await FirebaseFirestore.instance.collection('users').doc(patientId).get();
          if (pDoc.exists && pDoc.data() != null && mounted) {
            setState(() {
              _patientName = pDoc.data()!['name'] ?? 'Patient';
            });
          }
        } catch (_) {}
      } else if (profile != null && profile.name.isNotEmpty) {
        _patientName = profile.name;
      }

      // 1. Load from local database / web memory
      try {
        final localMeds = await LocalDbService.instance.getMedicines(patientId);
        combined.addAll(localMeds);
      } catch (_) {}

      // 2. Load from Firebase Firestore root collection
      try {
        final snap = await FirebaseFirestore.instance
            .collection('medicines')
            .where('patientId', isEqualTo: patientId)
            .get()
            .timeout(const Duration(milliseconds: 1500));
        for (final doc in snap.docs) {
          try {
            final data = doc.data();
            data['id'] ??= doc.id;
            final med = Medicine.fromMap(data);
            if (!combined.any((m) => m.id == med.id || (m.name.toLowerCase() == med.name.toLowerCase() && m.name.isNotEmpty))) {
              combined.add(med);
            }
          } catch (_) {}
        }
      } catch (_) {}

      // 3. Check users/{patientId}/medicines subcollection
      try {
        final subSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .collection('medicines')
            .get()
            .timeout(const Duration(milliseconds: 1500));
        for (final doc in subSnap.docs) {
          try {
            final data = doc.data();
            data['id'] ??= doc.id;
            final med = Medicine.fromMap(data);
            if (!combined.any((m) => m.id == med.id || (m.name.toLowerCase() == med.name.toLowerCase() && m.name.isNotEmpty))) {
              combined.add(med);
            }
          } catch (_) {}
        }
      } catch (_) {}
    } catch (_) {
      // Defensive fallback
    } finally {
      if (mounted) {
        setState(() {
          _medicines = combined;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteMedicine(Medicine med) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Are you sure you want to remove ${med.name} from your medications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusMissed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await LocalDbService.instance.deleteMedicine(med.id);
      try {
        await FirebaseFirestore.instance
            .collection('medicines')
            .doc(med.id)
            .delete()
            .timeout(const Duration(milliseconds: 1500));
        await FirebaseFirestore.instance
            .collection('users')
            .doc(med.patientId)
            .collection('medicines')
            .doc(med.id)
            .delete()
            .timeout(const Duration(milliseconds: 1500));
      } catch (_) {}

      setState(() {
        _medicines.removeWhere((m) => m.id == med.id);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${med.name} removed.'),
          backgroundColor: AppColors.statusMissed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<void> _editMedicine(Medicine med) async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddManuallyScreen(
          existingMedicine: med,
          patientId: _isCaregiverMode ? _effectivePatientId : null,
          patientName: _isCaregiverMode ? _patientName : null,
        ),
      ),
    );

    if (updated != null && mounted) {
      await _loadAllMedicines();
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    Widget nextScreen;
    if (_isCaregiverMode) {
      if (index == 0) {
        nextScreen = TodayDashboardScreen(
          viewingPatientId: _effectivePatientId,
          viewingPatientName: _patientName,
        );
      } else if (index == 1) {
        nextScreen = PillCalendarScreen(
          viewingPatientId: _effectivePatientId,
          viewingPatientName: _patientName,
        );
      } else if (index == 3) {
        nextScreen = const CaregiverScreen();
      } else {
        return;
      }
    } else {
      if (index == 0) {
        nextScreen = const TodayDashboardScreen();
      } else if (index == 1) {
        nextScreen = const PillCalendarScreen();
      } else if (index == 2) {
        nextScreen = const AddMedicineScreen();
      } else {
        return;
      }
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextScreen,
        transitionDuration: const Duration(milliseconds: 1),
        reverseTransitionDuration: const Duration(milliseconds: 1),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayName = _patientName.isNotEmpty ? _patientName : 'Patient';

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
                  if (Navigator.of(context).canPop())
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textDark),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isCaregiverMode ? AppColors.brandNavy : AppColors.brandTeal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              _isCaregiverMode ? Icons.people_outline : Icons.monitor_heart,
                              color: Colors.white,
                              size: 24,
                            ),
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
                                _isCaregiverMode
                                    ? 'Caregiver View • Patient Medications'
                                    : (l10n?.patientViewSubtitle ?? 'Patient view'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isCaregiverMode ? AppColors.brandNavy : AppColors.textMuted,
                                  fontWeight: _isCaregiverMode ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LanguagePillSelector(),
                      SizedBox(width: 8),
                      ProfileMenuButton(),
                    ],
                  ),
                ],
              ),
            ),
            if (_isCaregiverMode)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brandNavy.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.brandNavy, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Monitoring $displayName\'s medicines',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1, color: AppColors.borderSubtle),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: AppColors.brandTeal,
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  : ListView(
                      key: const PageStorageKey('medicines_list_view'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n?.addedMedicinesTitle ?? 'Added Medicines',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_medicines.length} ${_medicines.length == 1 ? "medicine" : "medicines"} configured for $displayName',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: AppColors.brandTeal, size: 22),
                                  onPressed: _loadAllMedicines,
                                  tooltip: 'Refresh',
                                ),
                                if (!_isCaregiverMode) ...[
                                  const SizedBox(width: 4),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AddMedicineScreen(
                                            patientId: _isCaregiverMode ? _effectivePatientId : null,
                                            patientName: _isCaregiverMode ? _patientName : null,
                                          ),
                                        ),
                                      ).then((_) => _loadAllMedicines());
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brandTeal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                          if (_medicines.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              margin: const EdgeInsets.only(top: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9FB),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: AppColors.brandTeal.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.medication_outlined,
                                      color: AppColors.brandTeal,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No medicines added yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tap the Add button above to add a prescription or scan a label.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._medicines.map((med) => _buildMedicineCard(med)),

                          const SizedBox(height: 24),
                        ],
                      ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: BottomNavigationBar(
          currentIndex: _isCaregiverMode ? 2 : 3,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.brandTeal,
          unselectedItemColor: AppColors.textMuted,
          backgroundColor: Colors.white,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
          onTap: _onTabTapped,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: l10n?.navToday ?? 'Today',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: const Icon(Icons.calendar_month),
              label: l10n?.navCalendar ?? 'Calendar',
            ),
            if (!_isCaregiverMode)
              BottomNavigationBarItem(
                icon: const Icon(Icons.add),
                label: l10n?.navAdd ?? 'Add',
              ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.medication_outlined),
              activeIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.medication, color: AppColors.brandTeal),
              ),
              label: l10n?.navMedicines ?? 'Medicines',
            ),
            if (_isCaregiverMode)
              BottomNavigationBarItem(
                icon: const Icon(Icons.people_outline),
                activeIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF0F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.people, color: Color(0xFF0E7485)),
                ),
                label: l10n?.navCare ?? 'Care',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(Medicine med) {
    final timesFormatted = med.scheduledTimes.isNotEmpty
        ? med.scheduledTimes.map((t) {
            final h = t.hour.toString().padLeft(2, '0');
            final m = t.minute.toString().padLeft(2, '0');
            return '$h:$m';
          }).join(', ')
        : '08:00';

    return InkWell(
      onTap: () {
        if (!_isCaregiverMode) {
          _editMedicine(med);
        } else {
          showMedicineDetailModal(
            context: context,
            medicine: med,
            isCaregiver: _isCaregiverMode,
            patientId: _effectivePatientId,
            onChanged: _loadAllMedicines,
          );
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E4E8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.medication_rounded, color: AppColors.brandTeal, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (med.dosage.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        med.dosage,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (med.addedViaScan)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.document_scanner_outlined, size: 12, color: Color(0xFF0369A1)),
                      SizedBox(width: 4),
                      Text(
                        'Scanned',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_isCaregiverMode) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.brandTeal, size: 20),
                  onPressed: () => _editMedicine(med),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                  onPressed: () => _deleteMedicine(med),
                  tooltip: 'Remove',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (med.frequency.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        med.frequency,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_filled_rounded, size: 13, color: AppColors.brandTeal),
                    const SizedBox(width: 4),
                    Text(
                      timesFormatted,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (med.instructions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      med.instructions,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
