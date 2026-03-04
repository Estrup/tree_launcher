import 'package:xterm/xterm.dart';
import 'app_theme.dart';

/// Builds a TerminalTheme from the active palette's ANSI colors.
TerminalTheme get appTerminalTheme {
  final p = AppColors.current;
  return TerminalTheme(
    cursor: p.accent,
    selection: p.accent.withValues(alpha: 0.25),
    foreground: p.textPrimary,
    background: p.base,
    black: p.ansiBlack,
    red: p.ansiRed,
    green: p.ansiGreen,
    yellow: p.ansiYellow,
    blue: p.ansiBlue,
    magenta: p.ansiMagenta,
    cyan: p.ansiCyan,
    white: p.ansiWhite,
    brightBlack: p.ansiBrightBlack,
    brightRed: p.ansiBrightRed,
    brightGreen: p.ansiBrightGreen,
    brightYellow: p.ansiBrightYellow,
    brightBlue: p.ansiBrightBlue,
    brightMagenta: p.ansiBrightMagenta,
    brightCyan: p.ansiBrightCyan,
    brightWhite: p.ansiBrightWhite,
    searchHitBackground: p.accent.withValues(alpha: 0.25),
    searchHitBackgroundCurrent: p.accent.withValues(alpha: 0.45),
    searchHitForeground: p.textPrimary,
  );
}
