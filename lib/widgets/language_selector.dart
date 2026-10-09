import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // To access MediCareApp.setLocale

class LanguagePillSelector extends StatelessWidget {
  const LanguagePillSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);
    final isSinhala = currentLocale.languageCode == 'si';
    final label = isSinhala ? 'සිංහල' : 'English';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showLanguageMenu(context, isSinhala),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD0D5DD), width: 1.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                size: 18,
                color: Color(0xFF344054),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D2939),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF344054),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageMenu(BuildContext context, bool isSinhala) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Select Language / භාෂාව තෝරන්න',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language, color: AppColors.brandTeal),
              title: const Text('English',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: !isSinhala
                  ? const Icon(Icons.check, color: AppColors.brandTeal)
                  : null,
              onTap: () {
                MediCareApp.setLocale(context, const Locale('en'));
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate, color: AppColors.brandTeal),
              title: const Text('සිංහල (Sinhala)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: isSinhala
                  ? const Icon(Icons.check, color: AppColors.brandTeal)
                  : null,
              onTap: () {
                MediCareApp.setLocale(context, const Locale('si'));
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
