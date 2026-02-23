import 'package:flutter/material.dart';

class AppColors {
  // Base layers (darkest to lightest)
  static const base = Color(0xFF0D0F12);
  static const surface0 = Color(0xFF14171C);
  static const surface1 = Color(0xFF1A1E24);
  static const surface2 = Color(0xFF22272E);
  static const surfaceHover = Color(0xFF2A3038);

  // Borders
  static const border = Color(0xFF2D3239);
  static const borderSubtle = Color(0xFF1F2329);

  // Text
  static const textPrimary = Color(0xFFE5E7EB);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);

  // Accent
  static const accent = Color(0xFFF59E0B);
  static const accentMuted = Color(0x33F59E0B);

  // Action colors
  static const terminal = Color(0xFF10B981);
  static const terminalBg = Color(0x1A10B981);
  static const copilot = Color(0xFF8B5CF6);
  static const copilotBg = Color(0x1A8B5CF6);
  static const vscode = Color(0xFF3B82F6);
  static const vscodeBg = Color(0x1A3B82F6);

  // Status
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.base,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface0,
        primary: AppColors.accent,
        secondary: AppColors.textSecondary,
        error: AppColors.error,
        onSurface: AppColors.textPrimary,
        onPrimary: AppColors.base,
        outline: AppColors.border,
        outlineVariant: AppColors.borderSubtle,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface2,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
