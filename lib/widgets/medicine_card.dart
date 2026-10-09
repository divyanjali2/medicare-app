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
  final VoidCallback onTaken;
  final VoidCallback onSkipped;

  const MedicineCard({
    super.key,
    required this.medicine,
    required this.doseTime,
    required this.status,
    required this.onTaken,
    required this.onSkipped,
  });

  @override
  Widget build(BuildContext context) {
    final isTaken = status == DoseStatus.taken;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTaken
            ? AppColors.statusTaken.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E3DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryTeal.withOpacity(0.15),
                child: Text(
                  medicine.name.isNotEmpty ? medicine.name[0] : '?',
                  style: const TextStyle(
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medicine.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      '${medicine.dosage} · ${medicine.instructions}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Text(
                TimeOfDay.fromDateTime(doseTime).format(context),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isTaken ? null : onTaken,
                  icon: const Icon(Icons.check),
                  label: Text(AppLocalizations.of(context)?.taken ?? 'Taken'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusTaken,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSkipped,
                  icon: const Icon(Icons.skip_next),
                  label: Text(AppLocalizations.of(context)?.skipped ?? 'Skipped'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusLate,
                    side: const BorderSide(color: AppColors.statusLate),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
