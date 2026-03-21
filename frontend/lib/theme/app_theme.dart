import 'package:flutter/material.dart';

// ── Design Tokens ──────────────────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFF0E9F6E);
  static const surface = Color(0xFF0F1923);
  static const card = Color(0xFF1A2535);
  static const textPrimary = Color(0xFFECF0F1);
  static const textSecondary = Color(0xFF8899AA);

  static const allow = Color(0xFF0B8A40);
  static const deny = Color(0xFFCC2233);
  static const error = Color(0xFFB54708);
  static const review = Color(0xFF2663B3);
  static const ready = Color(0xFF0E9F6E);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.surface,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(color: AppColors.card),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.deny,
            side: const BorderSide(color: AppColors.deny),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ALLOW':
        return AppColors.allow;
      case 'DENY':
        return AppColors.deny;
      case 'ERROR':
        return AppColors.error;
      case 'REVIEW':
      case 'AUTH':
        return AppColors.review;
      default:
        return AppColors.ready;
    }
  }

  static IconData statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'ALLOW':
        return Icons.check_circle_rounded;
      case 'DENY':
        return Icons.cancel_rounded;
      case 'ERROR':
        return Icons.warning_rounded;
      case 'REVIEW':
      case 'AUTH':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.shield_rounded;
    }
  }
}
