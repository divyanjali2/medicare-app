import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/medicine.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import 'add_medicine_screen.dart';
import 'pill_calendar_screen.dart';
import 'today_dashboard_screen.dart';
import 'welcome_screen.dart';

class PatientMedicinesScreen extends StatefulWidget {
  const PatientMedicinesScreen({super.key});

  @override
  State<PatientMedicinesScreen> createState() => _PatientMedicinesScreenState();
}

class _PatientMedicinesScreenState extends State<PatientMedicinesScreen> {
  final int _currentIndex = 3; // Medicines tab (next to Add)
  bool _isLoading = true;
  List<Medicine> _medicines = [];

  @override
  void initState() {
    super.initState();
    _loadAllMedicines();
  }

  Future<void> _loadAllMedicines() async {
    String patientId = 'p1';
    try {
      patientId = AuthService.instance.currentUser?.uid ?? 'p1';
    } catch (_) {}
    final List<Medicine> combined = [];

    // 1. Load from local database / web memory
    try {
      final localMeds = await LocalDbService.instance.getMedicines(patientId);
      combined.addAll(localMeds);
    } catch (_) {}

    // 2. Load from Firebase Firestore
    try {
      final snap = await FirebaseFirestore.instance
          .collection('medicines')
          .where('patientId', isEqualTo: patientId)
          .get();
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
      // Also check users/{patientId}/medicines subcollection
      try {
        final subSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .collection('medicines')
            .get();
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
    } catch (_) {}

    if (mounted) {
      setState(() {
        _medicines = combined;
        _isLoading = false;
      });
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
        await FirebaseFirestore.instance.collection('medicines').doc(med.id).delete();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(med.patientId)
            .collection('medicines')
            .doc(med.id)
            .delete();
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

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    Widget nextScreen;
    if (index == 0) {
      nextScreen = const TodayDashboardScreen();
    } else if (index == 1) {
      nextScreen = const PillCalendarScreen();
    } else if (index == 2) {
      nextScreen = const AddMedicineScreen();
    } else {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextScreen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (r) => false,
    );
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
                                l10n?.patientViewSubtitle ?? 'Patient view',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
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
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await AuthService.instance.signOut();
                        if (!mounted) return;
                        nav.pushAndRemoveUntil(
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

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.brandTeal),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAllMedicines,
                      color: AppColors.brandTeal,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                                      l10n?.yourMedicines ?? 'Your medicines',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_medicines.length} ${_medicines.length == 1 ? "medicine" : "medicines"} added for this patient',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
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
                          ),
                          const SizedBox(height: 20),

                          if (_medicines.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              margin: const EdgeInsets.only(top: 40),
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
                                    'Tap the Add button to add a prescription or scan a label.',
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
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
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Today',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add),
              label: 'Add',
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
              label: 'Meds',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(Medicine med) {
    String timeHint = 'Morning';
    if (med.scheduledTimes.isNotEmpty) {
      final hour = med.scheduledTimes.first.hour;
      if (hour >= 18) {
        timeHint = 'Night';
      } else if (hour >= 12) {
        timeHint = 'Evening';
      }
    }

    return Container(
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.medication_rounded, color: AppColors.brandTeal, size: 26),
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            med.dosage,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            med.frequency,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                timeHint == 'Night'
                                    ? Icons.nightlight_round
                                    : (timeHint == 'Evening'
                                        ? Icons.wb_twilight_rounded
                                        : Icons.wb_sunny_rounded),
                                size: 12,
                                color: const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeHint,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                onPressed: () => _deleteMedicine(med),
                tooltip: 'Remove',
              ),
            ],
          ),
          if (med.instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
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
    );
  }
}
