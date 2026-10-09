import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medicine.dart';
import '../theme/app_theme.dart';
import '../widgets/medicine_card.dart';
import '../widgets/language_selector.dart';
import '../l10n/app_localizations.dart';
import 'pill_calendar_screen.dart';
import 'welcome_screen.dart';

/// Screen 1 — Today / Home Dashboard (patient view).
class TodayDashboardScreen extends StatefulWidget {
  const TodayDashboardScreen({super.key});

  @override
  State<TodayDashboardScreen> createState() => _TodayDashboardScreenState();
}

class _TodayDashboardScreenState extends State<TodayDashboardScreen> {
  int _currentIndex = 0;

  final List<_TodayDose> _doses = [
    _TodayDose(
      medicine: Medicine(
        id: '1',
        patientId: 'p1',
        name: 'Metformin',
        dosage: '500 mg',
        frequency: 'Daily',
        instructions: '1 tablet • With breakfast',
        scheduledTimes: [],
        createdAt: DateTime.now(),
      ),
      time: DateTime(2026, 9, 22, 8, 0),
      status: DoseStatus.taken,
    ),
    _TodayDose(
      medicine: Medicine(
        id: '2',
        patientId: 'p1',
        name: 'Lisinopril',
        dosage: '10 mg',
        frequency: 'Daily',
        instructions: '1 tablet • After lunch',
        scheduledTimes: [],
        createdAt: DateTime.now(),
      ),
      time: DateTime(2026, 9, 22, 13, 0),
      status: DoseStatus.taken,
    ),
    _TodayDose(
      medicine: Medicine(
        id: '3',
        patientId: 'p1',
        name: 'Atorvastatin',
        dosage: '20 mg',
        frequency: 'Daily',
        instructions: '1 tablet • Before bed',
        scheduledTimes: [],
        createdAt: DateTime.now(),
      ),
      time: DateTime(2026, 9, 22, 21, 0),
      status: DoseStatus.missed,
    ),
  ];
  
  final int _streakDays = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeStr = Localizations.localeOf(context).toString();
    final todayStr = DateFormat('EEEE, MMMM d', localeStr).format(DateTime.now());
    
    // For the UI, assume the first 2 are taken out of 3.
    final dosesTaken = _doses.where((d) => d.status == DoseStatus.taken).length;
    final totalDoses = _doses.length;

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
            
            // Main Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  Text(
                    todayStr,
                    style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.goodMorningName('Maria') ?? 'Good morning, Maria',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _StreakCard(streakDays: _streakDays, dosesTaken: dosesTaken, totalDoses: totalDoses),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.yourMedicines ?? 'Your medicines',
                            style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
                          ),
                          Text(
                            l10n?.today ?? 'Today',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none, size: 18),
                        label: Text(
                          l10n?.testReminderButton ?? 'Test reminder',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brandTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (_doses.isEmpty)
                    Text(l10n?.noMedicinesAdded ?? 'No medicines added yet. Tap + to add one.')
                  else
                    ..._doses.map(
                      (d) => MedicineCard(
                        medicine: d.medicine,
                        doseTime: d.time,
                        status: d.status,
                        onTaken: () => _updateStatus(d, DoseStatus.taken),
                        onSkipped: () => _updateStatus(d, DoseStatus.late),
                      ),
                    ),
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
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.brandTeal,
          unselectedItemColor: AppColors.textMuted,
          backgroundColor: Colors.white,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PillCalendarScreen()),
              ).then((_) => setState(() => _currentIndex = 0));
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentIndex == 0 ? AppColors.brandTeal.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.home_outlined),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.home, color: AppColors.brandTeal),
              ),
              label: l10n?.today ?? 'Today',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: const Icon(Icons.calendar_month),
              label: l10n?.calendar ?? 'Calendar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add),
              label: 'Add',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Care',
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(_TodayDose dose, DoseStatus status) {
    setState(() => dose.status = status);
  }
}

class _TodayDose {
  final Medicine medicine;
  final DateTime time;
  DoseStatus status;

  _TodayDose({required this.medicine, required this.time, required this.status});
}

class _StreakCard extends StatelessWidget {
  final int streakDays;
  final int dosesTaken;
  final int totalDoses;

  const _StreakCard({
    required this.streakDays,
    required this.dosesTaken,
    required this.totalDoses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.caregiverAccent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                  const SizedBox(width: 6),
                  Text((AppLocalizations.of(context)?.currentStreak ?? 'CURRENT STREAK').toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)?.streakDaysCount(streakDays) ?? '$streakDays days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          
          // Progress Ring
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: totalDoses > 0 ? dosesTaken / totalDoses : 0,
                  strokeWidth: 4,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green), // Actually we should use a brand green if defined.
                ),
                Center(
                  child: Text(
                    '$dosesTaken/$totalDoses',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
