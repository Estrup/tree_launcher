import 'package:flutter/material.dart';

/// Immutable color palette that defines all app + terminal colors.
class AppColorPalette {
  // App surface layers
  final Color base;
  final Color? terminalSurface;
  final Color surface0;
  final Color surface1;
  final Color surface2;
  final Color surfaceHover;

  // Borders
  final Color border;
  final Color borderSubtle;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Accent
  final Color accent;
  final Color accentMuted;

  // Action colors
  final Color terminal;
  final Color terminalBg;
  final Color copilot;
  final Color copilotBg;
  final Color vscode;
  final Color vscodeBg;

  // Status
  final Color error;
  final Color success;

  // Terminal ANSI colors (normal)
  final Color ansiBlack;
  final Color ansiRed;
  final Color ansiGreen;
  final Color ansiYellow;
  final Color ansiBlue;
  final Color ansiMagenta;
  final Color ansiCyan;
  final Color ansiWhite;

  // Terminal ANSI colors (bright)
  final Color ansiBrightBlack;
  final Color ansiBrightRed;
  final Color ansiBrightGreen;
  final Color ansiBrightYellow;
  final Color ansiBrightBlue;
  final Color ansiBrightMagenta;
  final Color ansiBrightCyan;
  final Color ansiBrightWhite;

  const AppColorPalette({
    required this.base,
    this.terminalSurface,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.surfaceHover,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentMuted,
    required this.terminal,
    required this.terminalBg,
    required this.copilot,
    required this.copilotBg,
    required this.vscode,
    required this.vscodeBg,
    required this.error,
    required this.success,
    required this.ansiBlack,
    required this.ansiRed,
    required this.ansiGreen,
    required this.ansiYellow,
    required this.ansiBlue,
    required this.ansiMagenta,
    required this.ansiCyan,
    required this.ansiWhite,
    required this.ansiBrightBlack,
    required this.ansiBrightRed,
    required this.ansiBrightGreen,
    required this.ansiBrightYellow,
    required this.ansiBrightBlue,
    required this.ansiBrightMagenta,
    required this.ansiBrightCyan,
    required this.ansiBrightWhite,
  });
}

// ---------------------------------------------------------------------------
// Preset palettes
// ---------------------------------------------------------------------------

const palettes = <String, AppColorPalette>{
  'vivid': AppColorPalette(
    base: Color(0xFF0D0F12),
    terminalSurface: Color.fromARGB(255, 29, 31, 36),
    surface0: Color(0xFF14171C),
    surface1: Color(0xFF1A1E24),
    surface2: Color(0xFF22272E),
    surfaceHover: Color(0xFF2A3038),
    border: Color(0xFF2D3239),
    borderSubtle: Color(0xFF1F2329),
    textPrimary: Color(0xFFE5E7EB),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    accent: Color(0xFFF59E0B),
    accentMuted: Color(0x33F59E0B),
    terminal: Color(0xFF10B981),
    terminalBg: Color(0x1A10B981),
    copilot: Color(0xFF8B5CF6),
    copilotBg: Color(0x1A8B5CF6),
    vscode: Color(0xFF3B82F6),
    vscodeBg: Color(0x1A3B82F6),
    error: Color(0xFFEF4444),
    success: Color(0xFF10B981),
    ansiBlack: Color(0xFF0D0F12),
    ansiRed: Color(0xFFEF4444),
    ansiGreen: Color(0xFF10B981),
    ansiYellow: Color(0xFFF59E0B),
    ansiBlue: Color(0xFF3B82F6),
    ansiMagenta: Color(0xFF8B5CF6),
    ansiCyan: Color(0xFF06B6D4),
    ansiWhite: Color(0xFFE5E7EB),
    ansiBrightBlack: Color(0xFF6B7280),
    ansiBrightRed: Color(0xFFF87171),
    ansiBrightGreen: Color(0xFF34D399),
    ansiBrightYellow: Color(0xFFFBBF24),
    ansiBrightBlue: Color(0xFF60A5FA),
    ansiBrightMagenta: Color(0xFFA78BFA),
    ansiBrightCyan: Color(0xFF22D3EE),
    ansiBrightWhite: Color(0xFFFFFFFF),
  ),
  'muted': AppColorPalette(
    base: Color(0xFF161B22),
    surface0: Color(0xFF1C2128),
    surface1: Color(0xFF22272E),
    surface2: Color(0xFF2A3038),
    surfaceHover: Color(0xFF323940),
    border: Color(0xFF363D45),
    borderSubtle: Color(0xFF272D35),
    textPrimary: Color(0xFFCDD1D8),
    textSecondary: Color(0xFF8B929A),
    textMuted: Color(0xFF636A73),
    accent: Color(0xFFD4A054),
    accentMuted: Color(0x33D4A054),
    terminal: Color(0xFF56B88A),
    terminalBg: Color(0x1A56B88A),
    copilot: Color(0xFF8E7CC3),
    copilotBg: Color(0x1A8E7CC3),
    vscode: Color(0xFF6E9ECF),
    vscodeBg: Color(0x1A6E9ECF),
    error: Color(0xFFCF6A6A),
    success: Color(0xFF56B88A),
    ansiBlack: Color(0xFF161B22),
    ansiRed: Color(0xFFBF6868),
    ansiGreen: Color(0xFF7EAE82),
    ansiYellow: Color(0xFFD4A054),
    ansiBlue: Color(0xFF6E9ECF),
    ansiMagenta: Color(0xFF9E82B8),
    ansiCyan: Color(0xFF5DA5A5),
    ansiWhite: Color(0xFFCDD1D8),
    ansiBrightBlack: Color(0xFF636A73),
    ansiBrightRed: Color(0xFFCF8A8A),
    ansiBrightGreen: Color(0xFF98C49B),
    ansiBrightYellow: Color(0xFFDEB877),
    ansiBrightBlue: Color(0xFF8DB8DE),
    ansiBrightMagenta: Color(0xFFB69ECC),
    ansiBrightCyan: Color(0xFF7FBFBF),
    ansiBrightWhite: Color(0xFFE8E8E8),
  ),
  'nord': AppColorPalette(
    base: Color(0xFF2E3440),
    surface0: Color(0xFF3B4252),
    surface1: Color(0xFF434C5E),
    surface2: Color(0xFF4C566A),
    surfaceHover: Color(0xFF5A657A),
    border: Color(0xFF4C566A),
    borderSubtle: Color(0xFF3B4252),
    textPrimary: Color(0xFFD8DEE9),
    textSecondary: Color(0xFF9DA8BE),
    textMuted: Color(0xFF6C7A96),
    accent: Color(0xFF88C0D0),
    accentMuted: Color(0x3388C0D0),
    terminal: Color(0xFFA3BE8C),
    terminalBg: Color(0x1AA3BE8C),
    copilot: Color(0xFFB48EAD),
    copilotBg: Color(0x1AB48EAD),
    vscode: Color(0xFF81A1C1),
    vscodeBg: Color(0x1A81A1C1),
    error: Color(0xFFBF616A),
    success: Color(0xFFA3BE8C),
    ansiBlack: Color(0xFF3B4252),
    ansiRed: Color(0xFFBF616A),
    ansiGreen: Color(0xFFA3BE8C),
    ansiYellow: Color(0xFFEBCB8B),
    ansiBlue: Color(0xFF81A1C1),
    ansiMagenta: Color(0xFFB48EAD),
    ansiCyan: Color(0xFF88C0D0),
    ansiWhite: Color(0xFFE5E9F0),
    ansiBrightBlack: Color(0xFF4C566A),
    ansiBrightRed: Color(0xFFD08770),
    ansiBrightGreen: Color(0xFFA3BE8C),
    ansiBrightYellow: Color(0xFFEBCB8B),
    ansiBrightBlue: Color(0xFF88C0D0),
    ansiBrightMagenta: Color(0xFFB48EAD),
    ansiBrightCyan: Color(0xFF8FBCBB),
    ansiBrightWhite: Color(0xFFECEFF4),
  ),
  'catppuccin': AppColorPalette(
    base: Color(0xFF1E1E2E),
    surface0: Color(0xFF181825),
    surface1: Color(0xFF313244),
    surface2: Color(0xFF45475A),
    surfaceHover: Color(0xFF585B70),
    border: Color(0xFF45475A),
    borderSubtle: Color(0xFF313244),
    textPrimary: Color(0xFFCDD6F4),
    textSecondary: Color(0xFFA6ADC8),
    textMuted: Color(0xFF6C7086),
    accent: Color(0xFFCBA6F7),
    accentMuted: Color(0x33CBA6F7),
    terminal: Color(0xFFA6E3A1),
    terminalBg: Color(0x1AA6E3A1),
    copilot: Color(0xFFB4BEFE),
    copilotBg: Color(0x1AB4BEFE),
    vscode: Color(0xFF89B4FA),
    vscodeBg: Color(0x1A89B4FA),
    error: Color(0xFFF38BA8),
    success: Color(0xFFA6E3A1),
    ansiBlack: Color(0xFF45475A),
    ansiRed: Color(0xFFF38BA8),
    ansiGreen: Color(0xFFA6E3A1),
    ansiYellow: Color(0xFFF9E2AF),
    ansiBlue: Color(0xFF89B4FA),
    ansiMagenta: Color(0xFFCBA6F7),
    ansiCyan: Color(0xFF94E2D5),
    ansiWhite: Color(0xFFBAC2DE),
    ansiBrightBlack: Color(0xFF585B70),
    ansiBrightRed: Color(0xFFEBA0AC),
    ansiBrightGreen: Color(0xFFA6E3A1),
    ansiBrightYellow: Color(0xFFF9E2AF),
    ansiBrightBlue: Color(0xFFB4BEFE),
    ansiBrightMagenta: Color(0xFFF5C2E7),
    ansiBrightCyan: Color(0xFF89DCEB),
    ansiBrightWhite: Color(0xFFCDD6F4),
  ),
  'minimal': AppColorPalette(
    base: Color(0xFF191919),
    surface0: Color(0xFF222222),
    surface1: Color(0xFF2A2A2A),
    surface2: Color(0xFF333333),
    surfaceHover: Color(0xFF3A3A3A),
    border: Color(0xFF3E3E3E),
    borderSubtle: Color(0xFF2D2D2D),
    textPrimary: Color(0xFFEBEBEB),
    textSecondary: Color(0xFFA1A1A1),
    textMuted: Color(0xFF737373),
    accent: Color(0xFFD97A5E),
    accentMuted: Color(0x33D97A5E),
    terminal: Color(0xFF7EAE82),
    terminalBg: Color(0x1A7EAE82),
    copilot: Color(0xFF9E82B8),
    copilotBg: Color(0x1A9E82B8),
    vscode: Color(0xFF6E9ECF),
    vscodeBg: Color(0x1A6E9ECF),
    error: Color(0xFFCF6A6A),
    success: Color(0xFF7EAE82),
    ansiBlack: Color(0xFF191919),
    ansiRed: Color(0xFFCF6A6A),
    ansiGreen: Color(0xFF7EAE82),
    ansiYellow: Color(0xFFD4A054),
    ansiBlue: Color(0xFF6E9ECF),
    ansiMagenta: Color(0xFF9E82B8),
    ansiCyan: Color(0xFF5DA5A5),
    ansiWhite: Color(0xFFEBEBEB),
    ansiBrightBlack: Color(0xFF737373),
    ansiBrightRed: Color(0xFFCF8A8A),
    ansiBrightGreen: Color(0xFF98C49B),
    ansiBrightYellow: Color(0xFFDEB877),
    ansiBrightBlue: Color(0xFF8DB8DE),
    ansiBrightMagenta: Color(0xFFB69ECC),
    ansiBrightCyan: Color(0xFF7FBFBF),
    ansiBrightWhite: Color(0xFFFFFFFF),
  ),
};

/// Human-readable names for the theme picker UI.
const paletteDisplayNames = <String, String>{
  'vivid': 'Vivid',
  'muted': 'Muted',
  'nord': 'Nord',
  'catppuccin': 'Catppuccin',
  'minimal': 'Minimal',
};

// ---------------------------------------------------------------------------
// AppColors — static getters delegating to the active palette
// ---------------------------------------------------------------------------

class AppColors {
  static AppColorPalette _current = palettes['minimal']!;

  static void setTheme(String name) {
    _current = palettes[name] ?? palettes['minimal']!;
  }

  static AppColorPalette get current => _current;

  // Surfaces
  static Color get base => _current.base;
  static Color get surface0 => _current.surface0;
  static Color get surface1 => _current.surface1;
  static Color get surface2 => _current.surface2;
  static Color get surfaceHover => _current.surfaceHover;

  // Borders
  static Color get border => _current.border;
  static Color get borderSubtle => _current.borderSubtle;

  // Text
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textMuted => _current.textMuted;

  // Accent
  static Color get accent => _current.accent;
  static Color get accentMuted => _current.accentMuted;

  // Action colors
  static Color get terminal => _current.terminal;
  static Color get terminalBg => _current.terminalBg;
  static Color get copilot => _current.copilot;
  static Color get copilotBg => _current.copilotBg;
  static Color get vscode => _current.vscode;
  static Color get vscodeBg => _current.vscodeBg;

  // Status
  static Color get error => _current.error;
  static Color get success => _current.success;
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.base,
      colorScheme: ColorScheme.dark(
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
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface2,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: TextTheme(
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
        bodyMedium: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        bodySmall: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
