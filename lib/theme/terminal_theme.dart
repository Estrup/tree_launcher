import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'app_theme.dart';

/// Maps the app's dark palette to xterm's TerminalTheme.
TerminalTheme get appTerminalTheme => TerminalTheme(
      cursor: AppColors.accent,
      selection: AppColors.accent.withValues(alpha: 0.3),
      foreground: AppColors.textPrimary,
      background: AppColors.base,
      black: AppColors.base,
      red: const Color(0xFFEF4444),
      green: const Color(0xFF10B981),
      yellow: const Color(0xFFF59E0B),
      blue: const Color(0xFF3B82F6),
      magenta: const Color(0xFF8B5CF6),
      cyan: const Color(0xFF06B6D4),
      white: AppColors.textPrimary,
      brightBlack: AppColors.textMuted,
      brightRed: const Color(0xFFF87171),
      brightGreen: const Color(0xFF34D399),
      brightYellow: const Color(0xFFFBBF24),
      brightBlue: const Color(0xFF60A5FA),
      brightMagenta: const Color(0xFFA78BFA),
      brightCyan: const Color(0xFF22D3EE),
      brightWhite: const Color(0xFFFFFFFF),
      searchHitBackground: AppColors.accent.withValues(alpha: 0.3),
      searchHitBackgroundCurrent: AppColors.accent.withValues(alpha: 0.5),
      searchHitForeground: AppColors.textPrimary,
    );
