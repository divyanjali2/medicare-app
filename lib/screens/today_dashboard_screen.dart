import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../theme/app_theme.dart';
import '../widgets/medicine_card.dart';
import '../l10n/app_localizations.dart';

/// Screen 1 — Today / Home Dashboard (patient view).
/// See docs/ui-ux.md section 2.1 for the full UI/UX rationale.
class TodayDashboardScreen extends StatefulWidget {
  const TodayDashboardScreen({super.key});

  @override
  State<TodayDashboardScreen> createState() => _TodayDashboardScreenState();
}

class _TodayDashboardScreenState extends State<TodayDashboardScreen> {
  // TODO: replace with data loaded from LocalDbService for the signed-in patient.
  final List<_TodayDose> _doses = [];
  int _streakDays = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.appName ?? 'MediCare'),
        actions: [
          TextButton.icon(
            onPressed: () {
              // TODO: navigate to caregiver view / switch account mode
            },
            icon: const Icon(Icons.people_outline),
            label: Text(AppLocalizations.of(context)?.caregiverMode ?? 'Caregiver'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(AppLocalizations.of(context)?.goodMorning ?? 'Good morning', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          _StreakCard(streakDays: _streakDays),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)?.yourMedicines ?? 'Your medicines', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_doses.isEmpty)
            Text(AppLocalizations.of(context)?.noMedicinesAdded ?? 'No medicines added yet. Tap + to add one.')
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
    );
  }

  void _updateStatus(_TodayDose dose, DoseStatus status) {
    // TODO: write a DoseLog via LocalDbService (offline-first), then let
    // SyncService push it to Firestore once connectivity returns.
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

  const _StreakCard({required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.caregiverAccent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text((AppLocalizations.of(context)?.currentStreak ?? 'CURRENT STREAK').toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)?.streakDaysCount(streakDays) ?? '$streakDays days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
