import 'package:flutter/material.dart';

/// Central color palette and ThemeData for MediCare.
/// Colors chosen for an elderly-focused healthcare app: calm, muted,
/// high-contrast, and non-clinical. See docs/ui-ux.md for rationale.
class AppColors {
  AppColors._();

  static const Color primaryTeal = Color(0xFF2E7D91);
  static const Color backgroundOffWhite = Color(0xFFFAFAF7);
  static const Color cardBackground = Color(0xFFF5F3EE);

  // Status colors (used consistently across dashboard + pill calendar)
  static const Color statusTaken = Color(0xFF5A9E6F);
  static const Color statusLate = Color(0xFFE8A33D);
  static const Color statusMissed = Color(0xFFD9534F);

  static const Color textPrimary = Color(0xFF2B2B2B);
  static const Color textSecondary = Color(0xFF666666);
  static const Color caregiverAccent = Color(0xFF2C3E50);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundOffWhite,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryTeal,
        primary: AppColors.primaryTeal,
        surface: AppColors.backgroundOffWhite,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 26,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 20,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 18),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56), // large tap target
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE5E3DD)),
        ),
      ),
    );
  }
}
