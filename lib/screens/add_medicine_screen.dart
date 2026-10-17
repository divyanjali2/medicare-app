import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../widgets/profile_menu_button.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/ocr_service.dart';
import 'caregiver_screen.dart';
import 'today_dashboard_screen.dart';
import 'pill_calendar_screen.dart';
import 'add_manually_screen.dart';
import 'patient_medicines_screen.dart';

class AddMedicineScreen extends StatefulWidget {
  final String? patientId;
  final String? patientName;

  const AddMedicineScreen({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final int _currentIndex = 2; // Add tab
  String _effectivePatientId = 'p1';
  bool _isCaregiverMode = false;
  String _patientName = '';

  List<UserProfile> _linkedPatients = [];

  @override
  void initState() {
    super.initState();
    _resolvePatient();
  }

  Future<void> _resolvePatient() async {
    final currentUid = AuthService.instance.currentUser?.uid;
    final profile = await AuthService.instance.fetchCurrentUserProfile(currentUid);

    String patientId = widget.patientId ?? '';
    bool caregiverMode = widget.patientId != null;
    List<UserProfile> linked = [];

    if (profile?.role == UserRole.caregiver) {
      caregiverMode = true;
      if (currentUid != null) {
        linked = await AuthService.instance.getLinkedPatients(currentUid);
      }
      if (patientId.isEmpty && linked.isNotEmpty) {
        patientId = linked.first.uid;
      } else if (patientId.isEmpty && profile!.linkedPatientIds.isNotEmpty) {
        patientId = profile.linkedPatientIds.first;
      }
    }

    if (patientId.isEmpty) {
      patientId = currentUid ?? (profile?.uid ?? 'p1');
    }

    String patientName = widget.patientName ?? '';
    if (patientName.isEmpty && linked.isNotEmpty) {
      final matched = linked.where((p) => p.uid == patientId).firstOrNull;
      if (matched != null) {
        patientName = matched.name;
      }
    }
    if (patientName.isEmpty) {
      patientName = profile?.name ?? '';
    }

    if (mounted) {
      setState(() {
        _effectivePatientId = patientId;
        _isCaregiverMode = caregiverMode;
        _linkedPatients = linked;
        _patientName = patientName;
      });
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    Widget nextScreen;
    if (index == 0) {
      nextScreen = TodayDashboardScreen(
        viewingPatientId: _isCaregiverMode ? _effectivePatientId : null,
        viewingPatientName: _isCaregiverMode ? _patientName : null,
      );
    } else if (index == 1) {
      nextScreen = PillCalendarScreen(
        viewingPatientId: _isCaregiverMode ? _effectivePatientId : null,
        viewingPatientName: _isCaregiverMode ? _patientName : null,
      );
    } else if (index == 3) {
      nextScreen = PatientMedicinesScreen(
        viewingPatientId: _isCaregiverMode ? _effectivePatientId : null,
        viewingPatientName: _isCaregiverMode ? _patientName : null,
      );
    } else if (index == 4 && _isCaregiverMode) {
      nextScreen = const CaregiverScreen();
    } else {
      return;
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

  Future<void> _pickAndScanImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) {
        // User cancelled picker
        return;
      }

      List<String> candidates = [];
      try {
        final ocr = OcrService();
        try {
          candidates = await ocr.scanName(File(photo.path));
        } finally {
          await ocr.dispose();
        }
      } catch (ocrError) {
        debugPrint('OCR scanning error: $ocrError');
      }

      if (candidates.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't read text from card, please enter details manually."),
            backgroundColor: AppColors.statusLate,
          ),
        );
      }

      if (!mounted) return;

      final navigator = Navigator.of(context);
      final result = await navigator.push(
        MaterialPageRoute(
          builder: (_) => AddManuallyScreen(
            isFromScan: true,
            candidates: candidates,
            patientId: _isCaregiverMode ? _effectivePatientId : null,
            patientName: _isCaregiverMode ? _patientName : null,
          ),
        ),
      );

      if (result != null && mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => TodayDashboardScreen(
              viewingPatientId: _isCaregiverMode ? _effectivePatientId : null,
              viewingPatientName: _isCaregiverMode ? _patientName : null,
            ),
          ),
          (r) => false,
        );
      }
    } catch (e) {
      debugPrint('Image selection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'Camera access unavailable. Switching to manual entry.'
                  : 'Gallery access unavailable. Switching to manual entry.',
            ),
            backgroundColor: AppColors.statusLate,
          ),
        );
        final navigator = Navigator.of(context);
        final result = await navigator.push(
          MaterialPageRoute(
            builder: (_) => AddManuallyScreen(
              isFromScan: false,
              patientId: _isCaregiverMode ? _effectivePatientId : null,
              patientName: _isCaregiverMode ? _patientName : null,
            ),
          ),
        );
        if (result != null && mounted) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => TodayDashboardScreen(
                viewingPatientId: _isCaregiverMode ? _effectivePatientId : null,
                viewingPatientName: _isCaregiverMode ? _patientName : null,
              ),
            ),
            (r) => false,
          );
        }
      }
    }
  }

  void _showImageSourcePicker() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.scanMedicineCard ?? 'Scan Medicine Card',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose where to get the medicine image from:',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: AppColors.brandTeal),
                  ),
                  title: Text(l10n?.takePhoto ?? 'Take a photo', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Point camera at the medicine card or box'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAndScanImage(ImageSource.camera);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.brandNavy.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: AppColors.brandNavy),
                  ),
                  title: Text(l10n?.uploadFromGallery ?? 'Upload from gallery', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Choose a photo from your device library'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAndScanImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
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
                                    ? 'Caregiver View • Add Medication'
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.brandNavy.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, color: AppColors.brandNavy, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Adding medicine for patient:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandNavy,
                            ),
                          ),
                          if (_linkedPatients.length > 1)
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _linkedPatients.any((p) => p.uid == _effectivePatientId)
                                    ? _effectivePatientId
                                    : _linkedPatients.first.uid,
                                isDense: true,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, color: AppColors.brandNavy),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandNavy,
                                ),
                                items: _linkedPatients.map((p) {
                                  return DropdownMenuItem<String>(
                                    value: p.uid,
                                    child: Text(
                                      '${p.name.isNotEmpty ? p.name : "Patient"} (${(p.phoneNumber ?? "").isNotEmpty ? p.phoneNumber : p.uid})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final selected = _linkedPatients.firstWhere((p) => p.uid == val);
                                    setState(() {
                                      _effectivePatientId = selected.uid;
                                      _patientName = selected.name;
                                    });
                                  }
                                },
                              ),
                            )
                          else
                            Text(
                              _patientName.isNotEmpty ? _patientName : 'Patient ($_effectivePatientId)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandNavy,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (Navigator.of(context).canPop())
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Exit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandNavy,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1, color: AppColors.borderSubtle),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _isCaregiverMode
                          ? 'Add medicine for $_patientName'
                          : (l10n?.addMedicine ?? 'Add a medicine'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.addMedicineSubtitle ?? 'Point your camera at the medicine label.',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Scan Box
                    GestureDetector(
                      onTap: _showImageSourcePicker,
                      child: CustomPaint(
                        painter: DashedRectPainter(
                          color: AppColors.brandTeal,
                          strokeWidth: 1.5,
                          gap: 5.0,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: AppColors.brandTeal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  color: AppColors.brandTeal,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                l10n?.scanMedicineCard ?? 'Scan medicine card',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandTeal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n?.scanMedicineLabelSubtitle ?? "We'll fill in the details for you",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Upload from gallery button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickAndScanImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 20, color: AppColors.brandTeal),
                        label: Text(
                          l10n?.uploadFromGallery ?? 'Upload from gallery',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandTeal,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.brandTeal, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: AppColors.brandTeal.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Or Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.borderSubtle)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n?.orText ?? 'or',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppColors.borderSubtle)),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Enter Manually Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final result = await navigator.push(
                            MaterialPageRoute(
                              builder: (_) => AddManuallyScreen(
                                isFromScan: false,
                                patientId: _isCaregiverMode ? _effectivePatientId : null,
                                patientName: _isCaregiverMode ? _patientName : null,
                              ),
                            ),
                          );
                          if (result != null && mounted) {
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => TodayDashboardScreen(
                                  viewingPatientId: _isCaregiverMode ? _effectivePatientId : null,
                                  viewingPatientName: _isCaregiverMode ? _patientName : null,
                                ),
                              ),
                              (r) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: Text(
                          l10n?.enterManually ?? 'Enter manually',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: const BorderSide(color: AppColors.borderSubtle),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Tip Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBEBC7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.brown, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n?.addMedicineTip ?? 'Tip: Place the bottle on a flat surface with good lighting.',
                              style: const TextStyle(
                                color: Colors.brown,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
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
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add, color: AppColors.brandTeal),
              ),
              label: 'Add',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.medication_outlined),
              activeIcon: Icon(Icons.medication),
              label: 'Medicines',
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
                label: 'Care',
              ),
          ],
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    this.color = Colors.black,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );

    Path path = Path()..addRRect(rrect);
    Path dashPath = _dashPath(path, dashArray: CircularIntervalList<double>([gap, gap]));
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(Path source, {required CircularIntervalList<double> dashArray}) {
    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = dashArray.next;
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CircularIntervalList<T> {
  CircularIntervalList(this._vals);
  final List<T> _vals;
  int _idx = 0;
  T get next {
    if (_idx >= _vals.length) _idx = 0;
    return _vals[_idx++];
  }
}
