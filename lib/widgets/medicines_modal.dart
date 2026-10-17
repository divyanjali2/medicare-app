import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/medicine.dart';
import '../models/user_profile.dart';
import '../screens/add_manually_screen.dart';
import '../screens/add_medicine_screen.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../theme/app_theme.dart';

/// Opens a modal bottom sheet displaying the list of medicines for a patient.
///
/// Role-based behavior:
/// - If [isCaregiver] is true: Shows medicines in read-only mode with no edit or delete actions.
///   Caregivers can only view medicines of patients linked to their account.
/// - If [isCaregiver] is false (the patient): Shows edit and remove/delete options on every medicine,
///   plus an 'Add Medicine' button.
Future<void> showMedicinesModal({
  required BuildContext context,
  required String patientId,
  String? patientName,
  required bool isCaregiver,
  VoidCallback? onMedicinesChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MedicinesModalSheet(
      patientId: patientId,
      patientName: patientName,
      isCaregiver: isCaregiver,
      onMedicinesChanged: onMedicinesChanged,
    ),
  );
}

/// Opens a detailed modal bottom sheet for a single medicine.
///
/// Role-based behavior:
/// - If [isCaregiver] is true: Read-only inspection of medicine details, frequency, schedule, and dosage.
/// - If [isCaregiver] is false (patient): Full CRUD capabilities (Edit medicine, Remove medicine, view schedule).
Future<void> showMedicineDetailModal({
  required BuildContext context,
  required Medicine medicine,
  required bool isCaregiver,
  required String patientId,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MedicineDetailSheet(
      medicine: medicine,
      isCaregiver: isCaregiver,
      patientId: patientId,
      onChanged: onChanged,
    ),
  );
}

class MedicinesModalSheet extends StatefulWidget {
  final String patientId;
  final String? patientName;
  final bool isCaregiver;
  final VoidCallback? onMedicinesChanged;

  const MedicinesModalSheet({
    super.key,
    required this.patientId,
    this.patientName,
    required this.isCaregiver,
    this.onMedicinesChanged,
  });

  @override
  State<MedicinesModalSheet> createState() => _MedicinesModalSheetState();
}

class _MedicinesModalSheetState extends State<MedicinesModalSheet> {
  bool _isLoading = true;
  bool _isNotLinked = false;
  List<Medicine> _medicines = [];
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _displayName = widget.patientName ?? (widget.isCaregiver ? 'Patient' : 'You');
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() {
      _isLoading = true;
      _isNotLinked = false;
    });

    // Enforce caregiver restriction: caregiver can ONLY view linked patients' medicines
    if (widget.isCaregiver) {
      final currentUid = AuthService.instance.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        final profile = await AuthService.instance.fetchCurrentUserProfile(currentUid);
        if (profile != null && profile.role == UserRole.caregiver) {
          final isLinked = profile.linkedPatientIds.contains(widget.patientId);
          if (!isLinked) {
            if (mounted) {
              setState(() {
                _medicines = [];
                _isNotLinked = true;
                _isLoading = false;
              });
            }
            return;
          }
        }
      }
    }

    final List<Medicine> list = [];

    try {
      // 1. Fetch from Local SQLite / In-memory web
      final local = await LocalDbService.instance.getMedicines(widget.patientId);
      list.addAll(local);

      // 2. Supplement from Firestore root medicines if online
      try {
        final snap = await FirebaseFirestore.instance
            .collection('medicines')
            .where('patientId', isEqualTo: widget.patientId)
            .get()
            .timeout(const Duration(milliseconds: 1500));

        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          final m = Medicine.fromMap(data);
          if (!list.any((existing) => existing.id == m.id)) {
            list.add(m);
          }
        }
      } catch (_) {}

      // Sort alphabetically by name
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      debugPrint('Error loading medicines in modal: $e');
    } finally {
      if (mounted) {
        setState(() {
          _medicines = list;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteMedicine(Medicine med) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Medicine', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "${med.name}" from your active medicines?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await LocalDbService.instance.deleteMedicine(med.id);

      // Delete from Firestore if available
      try {
        await FirebaseFirestore.instance.collection('medicines').doc(med.id).delete();
      } catch (_) {}

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${med.name} removed successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadMedicines();
        widget.onMedicinesChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _editMedicine(Medicine med) async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddManuallyScreen(
          existingMedicine: med,
          patientId: widget.patientId,
          patientName: widget.patientName,
        ),
      ),
    );

    if (updated != null && mounted) {
      await _loadMedicines();
      widget.onMedicinesChanged?.call();
    }
  }

  Future<void> _addNewMedicine() async {
    final added = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddMedicineScreen(),
      ),
    );

    if (added != null && mounted) {
      await _loadMedicines();
      widget.onMedicinesChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top drag handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medication_rounded, color: AppColors.brandTeal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isCaregiver ? '$_displayName\'s Medicines' : (l10n?.navMedicines ?? 'Medicines'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (widget.isCaregiver)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCF0F2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, size: 12, color: Color(0xFF0E7485)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Caregiver View',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0E7485),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text(
                                '${_medicines.length} ${_medicines.length == 1 ? "medicine" : "medicines"} configured',
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isCaregiver)
                    TextButton.icon(
                      onPressed: _addNewMedicine,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandTeal,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textDark),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 20, color: Color(0xFFE5E7EB)),

            // Body Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.brandTeal))
                  : _isNotLinked
                      ? _buildNotLinkedState()
                      : _medicines.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: _medicines.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, index) {
                                final med = _medicines[index];
                                return _buildMedicineTile(med);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLinkedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_off, color: Colors.redAccent, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Patient Not Linked',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Caregivers can only view medicines of patients linked to their account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brandTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medication_outlined, color: AppColors.brandTeal, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Medicines Added Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isCaregiver
                  ? 'This patient has not configured any medications yet.'
                  : 'Tap "Add" in the top corner to add your prescriptions or scan a label.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            if (!widget.isCaregiver) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _addNewMedicine,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Medicine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineTile(Medicine med) {
    final timesFormatted = med.scheduledTimes.isNotEmpty
        ? med.scheduledTimes.map((t) {
            final h = t.hour.toString().padLeft(2, '0');
            final m = t.minute.toString().padLeft(2, '0');
            return '$h:$m';
          }).join(', ')
        : '08:00';

    return InkWell(
      onTap: () {
        showMedicineDetailModal(
          context: context,
          medicine: med,
          isCaregiver: widget.isCaregiver,
          patientId: widget.patientId,
          onChanged: () {
            _loadMedicines();
            widget.onMedicinesChanged?.call();
          },
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.brandTeal.withValues(alpha: 0.15),
                child: Text(
                  med.name.isNotEmpty ? med.name[0].toUpperCase() : 'M',
                  style: const TextStyle(
                    color: AppColors.brandTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(
                        fontSize: 17,
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
              if (!widget.isCaregiver) ...[
                // Edit button for patient
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.brandTeal),
                  onPressed: () => _editMedicine(med),
                  tooltip: 'Edit medicine',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                // Remove button for patient
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  onPressed: () => _deleteMedicine(med),
                  tooltip: 'Remove medicine',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Pills for frequency and schedule
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (med.frequency.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E4E8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        med.frequency,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: AppColors.brandTeal),
                    const SizedBox(width: 4),
                    Text(
                      timesFormatted,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandTeal),
                    ),
                  ],
                ),
              ),
              if (med.addedViaScan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.document_scanner_outlined, size: 12, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text(
                        'Scanned',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (med.instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      med.instructions,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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

/// Modal bottom sheet showing full details for a single medicine.
/// Provides patient CRUD actions (Edit, Remove) and caregiver read-only view.
class MedicineDetailSheet extends StatelessWidget {
  final Medicine medicine;
  final bool isCaregiver;
  final String patientId;
  final VoidCallback? onChanged;

  const MedicineDetailSheet({
    super.key,
    required this.medicine,
    required this.isCaregiver,
    required this.patientId,
    this.onChanged,
  });

  Future<void> _handleEdit(BuildContext context) async {
    Navigator.of(context).pop();
    final updated = await Navigator.of(context).push<Medicine>(
      MaterialPageRoute(
        builder: (_) => AddManuallyScreen(
          existingMedicine: medicine,
          patientId: patientId,
        ),
      ),
    );
    if (updated != null) {
      onChanged?.call();
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Medicine', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "${medicine.name}"? This will delete all scheduled doses.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await LocalDbService.instance.deleteMedicine(medicine.id);
        try {
          await FirebaseFirestore.instance.collection('medicines').doc(medicine.id).delete();
        } catch (_) {}
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${medicine.name} removed successfully'),
              backgroundColor: AppColors.brandTeal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        onChanged?.call();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing medicine: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timesFormatted = medicine.scheduledTimes.isNotEmpty
        ? medicine.scheduledTimes.map((t) {
            final h = t.hour.toString().padLeft(2, '0');
            final m = t.minute.toString().padLeft(2, '0');
            return '$h:$m';
          }).join(', ')
        : '08:00';

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.brandTeal.withValues(alpha: 0.15),
                    child: Text(
                      medicine.name.isNotEmpty ? medicine.name[0].toUpperCase() : 'M',
                      style: const TextStyle(
                        color: AppColors.brandTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (medicine.dosage.isNotEmpty)
                          Text(
                            medicine.dosage,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textDark),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Role Badge
              if (isCaregiver)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF0F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: Color(0xFF0E7485)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Caregiver View (Prescriptions managed by patient)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0E7485),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Detail cards
              _buildDetailItem(
                icon: Icons.repeat,
                title: 'Frequency',
                value: medicine.frequency,
              ),
              const SizedBox(height: 10),
              _buildDetailItem(
                icon: Icons.access_time,
                title: 'Daily Schedule',
                value: timesFormatted,
              ),
              const SizedBox(height: 10),
              _buildDetailItem(
                icon: Icons.info_outline,
                title: 'Instructions',
                value: medicine.instructions.isNotEmpty ? medicine.instructions : 'No special instructions',
              ),
              const SizedBox(height: 10),
              _buildDetailItem(
                icon: medicine.addedViaScan ? Icons.document_scanner_outlined : Icons.edit_note,
                title: 'Entry Method',
                value: medicine.addedViaScan ? 'Scanned from prescription label' : 'Entered manually',
              ),

              const SizedBox(height: 24),

              // Action buttons (Patient: Edit + Remove; Caregiver: Close)
              if (!isCaregiver)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleDelete(context),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        label: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleEdit(context),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Medicine', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.brandTeal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
