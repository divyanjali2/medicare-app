import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medicine.dart';
import '../widgets/pill_calendar.dart';
import '../widgets/language_selector.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'today_dashboard_screen.dart';
import 'add_medicine_screen.dart';
import 'welcome_screen.dart';

class PillCalendarScreen extends StatefulWidget {
  const PillCalendarScreen({super.key});

  @override
  State<PillCalendarScreen> createState() => _PillCalendarScreenState();
}

class _PillCalendarScreenState extends State<PillCalendarScreen> {
  int _currentIndex = 1; // Calendar tab
  
  DateTime _month = DateTime(2026, 9);
  DateTime? _selectedDay = DateTime(2026, 9, 22);

  // Mock data to match screenshot
  final Map<DateTime, DoseStatus> _statusByDay = {
    DateTime(2026, 9, 1): DoseStatus.taken,
    DateTime(2026, 9, 2): DoseStatus.taken,
    DateTime(2026, 9, 3): DoseStatus.taken,
    DateTime(2026, 9, 4): DoseStatus.taken,
    DateTime(2026, 9, 5): DoseStatus.late,
    DateTime(2026, 9, 6): DoseStatus.taken,
    DateTime(2026, 9, 7): DoseStatus.missed,
    DateTime(2026, 9, 8): DoseStatus.taken,
    DateTime(2026, 9, 9): DoseStatus.taken,
    DateTime(2026, 9, 10): DoseStatus.late,
    DateTime(2026, 9, 11): DoseStatus.taken,
    DateTime(2026, 9, 12): DoseStatus.taken,
    DateTime(2026, 9, 13): DoseStatus.taken,
    DateTime(2026, 9, 14): DoseStatus.missed,
    DateTime(2026, 9, 15): DoseStatus.late,
    DateTime(2026, 9, 16): DoseStatus.taken,
    DateTime(2026, 9, 17): DoseStatus.taken,
    DateTime(2026, 9, 18): DoseStatus.taken,
    DateTime(2026, 9, 19): DoseStatus.taken,
    DateTime(2026, 9, 20): DoseStatus.late,
    DateTime(2026, 9, 21): DoseStatus.missed,
    DateTime(2026, 9, 22): DoseStatus.taken,
    DateTime(2026, 9, 23): DoseStatus.taken,
    DateTime(2026, 9, 24): DoseStatus.taken,
    DateTime(2026, 9, 25): DoseStatus.late,
    DateTime(2026, 9, 26): DoseStatus.taken,
    DateTime(2026, 9, 27): DoseStatus.taken,
    DateTime(2026, 9, 28): DoseStatus.missed,
    DateTime(2026, 9, 29): DoseStatus.taken,
    DateTime(2026, 9, 30): DoseStatus.late,
  };

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TodayDashboardScreen()),
        (r) => false,
      );
    } else if (index == 2) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
        (r) => false,
      );
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
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  Text(
                    l10n?.pillCalendarTitle ?? 'Pill calendar',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.pillCalendarSubtitle ?? 'A clear view of your progress.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PillCalendar(
                    month: _month,
                    statusByDay: _statusByDay,
                    selectedDay: _selectedDay,
                    onMonthChange: (m) => setState(() => _month = m),
                    onDayTap: (d) => setState(() => _selectedDay = d),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedDay != null) _DayDetailPanel(day: _selectedDay!),
                  const SizedBox(height: 32),
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
          onTap: _onTabTapped,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.calendar_month, color: AppColors.brandTeal),
              ),
              label: 'Calendar',
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
}

class _DayDetailPanel extends StatelessWidget {
  final DateTime day;

  const _DayDetailPanel({required this.day});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeStr = Localizations.localeOf(context).toString();
    final dateStr = DateFormat('MMMM d', localeStr).format(day);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6), // Slightly off-white matching mockup
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E3DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.allTakenTitle ?? 'All taken',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.statusTaken,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: AppColors.borderSubtle),
          ),
          // Mock dose rows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Metformin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
              ),
              Text(
                '8:00 AM',
                style: TextStyle(color: AppColors.textMuted, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Lisinopril',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
              ),
              Text(
                '1:00 PM',
                style: TextStyle(color: AppColors.textMuted, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
