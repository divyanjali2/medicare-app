import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// A single dose card on the Today dashboard, with large Taken/Skipped
/// buttons (elderly-friendly: one tap, no forms). See docs/ui-ux.md 2.1.
class MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final DateTime doseTime;
  final DoseStatus status;
  final VoidCallback? onTaken;
  final VoidCallback? onSkipped;
  final VoidCallback? onTap;
  final bool readOnly;

  const MedicineCard({
    super.key,
    required this.medicine,
    required this.doseTime,
    required this.status,
    this.onTaken,
    this.onSkipped,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTaken = status == DoseStatus.taken;
    final isLate = status == DoseStatus.late || status == DoseStatus.skipped;
    final isMissed = status == DoseStatus.missed;
    
    Color backgroundColor = Colors.white;
    Color borderColor = const Color(0xFFE5E3DD);
    if (isTaken) {
      backgroundColor = AppColors.statusTaken.withValues(alpha: 0.08);
      borderColor = AppColors.statusTaken.withValues(alpha: 0.3);
    } else if (isLate) {
      backgroundColor = AppColors.statusLate.withValues(alpha: 0.08);
      borderColor = AppColors.statusLate.withValues(alpha: 0.3);
    } else if (isMissed) {
      backgroundColor = AppColors.statusMissed.withValues(alpha: 0.08);
      borderColor = AppColors.statusMissed.withValues(alpha: 0.3);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isTaken 
                      ? AppColors.primaryTeal.withValues(alpha: 0.15)
                      : AppColors.primaryTeal.withValues(alpha: 0.2),
                child: Text(
                  medicine.name.isNotEmpty ? medicine.name[0] : '?',
                  style: const TextStyle(
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            medicine.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: AppColors.textDark),
                            const SizedBox(width: 4),
                            Text(
                              TimeOfDay.fromDateTime(doseTime).format(context),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${medicine.dosage} • ${medicine.instructions}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (readOnly)
            _buildReadOnlyStatusChip(context)
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isTaken ? null : onTaken,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      AppLocalizations.of(context)?.taken ?? 'Taken',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTaken ? AppColors.statusTaken : Colors.white,
                      foregroundColor: isTaken ? Colors.white : AppColors.statusTaken,
                      elevation: 0,
                      side: isTaken ? BorderSide.none : const BorderSide(color: AppColors.statusTaken),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isLate || isMissed) ? null : onSkipped,
                    icon: const Icon(Icons.skip_next_outlined, size: 18),
                    label: Text(
                      AppLocalizations.of(context)?.skipped ?? 'Skipped',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusLate.withValues(alpha: 0.3),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      side: BorderSide(color: AppColors.statusLate.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

  Widget _buildReadOnlyStatusChip(BuildContext context) {
    final (String label, Color color, IconData icon) = switch (status) {
      DoseStatus.taken => ('Taken', AppColors.statusTaken, Icons.check_circle_outline),
      DoseStatus.skipped => ('Skipped', AppColors.statusLate, Icons.skip_next_outlined),
      DoseStatus.late => ('Late', AppColors.statusLate, Icons.access_time),
      DoseStatus.missed => ('Missed', AppColors.statusMissed, Icons.cancel_outlined),
      DoseStatus.pending => ('Pending', AppColors.textMuted, Icons.hourglass_empty),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
