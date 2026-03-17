import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

const double kDefaultTerminalFontSize = 13.0;

const List<String> _xtermDefaultFallbacks = [
  'Menlo',
  'Monaco',
  'Consolas',
  'Liberation Mono',
  'Courier New',
  'Noto Sans Mono CJK SC',
  'Noto Sans Mono CJK TC',
  'Noto Sans Mono CJK KR',
  'Noto Sans Mono CJK JP',
  'Noto Sans Mono CJK HK',
  'Noto Color Emoji',
  'Noto Sans Symbols',
  'monospace',
  'sans-serif',
];

const List<String> _macOsTerminalFonts = [
  'SF Mono',
  'Menlo',
  'Monaco',
  'JetBrains Mono',
  'Fira Code',
  'monospace',
];

const List<String> _windowsTerminalFonts = [
  'Consolas',
  'Cascadia Mono',
  'Cascadia Code',
  'JetBrains Mono',
  'Fira Code',
  'Courier New',
  'Lucida Console',
  'monospace',
];

const List<String> _linuxTerminalFonts = [
  'DejaVu Sans Mono',
  'Liberation Mono',
  'Noto Sans Mono',
  'JetBrains Mono',
  'Fira Code',
  'monospace',
];

TargetPlatform _resolvedPlatform(TargetPlatform? platform) {
  return platform ?? defaultTargetPlatform;
}

List<String> terminalFontOptions([TargetPlatform? platform]) {
  return switch (_resolvedPlatform(platform)) {
    TargetPlatform.macOS => _macOsTerminalFonts,
    TargetPlatform.windows => _windowsTerminalFonts,
    _ => _linuxTerminalFonts,
  };
}

String defaultTerminalFontFamily([TargetPlatform? platform]) {
  return terminalFontOptions(platform).first;
}

String resolveTerminalFontFamily(
  String? fontFamily, [
  TargetPlatform? platform,
]) {
  final requestedFont = fontFamily?.trim();
  if (requestedFont == null || requestedFont.isEmpty) {
    return defaultTerminalFontFamily(platform);
  }

  final supportedFonts = terminalFontOptions(platform);
  if (supportedFonts.contains(requestedFont)) {
    return requestedFont;
  }

  return defaultTerminalFontFamily(platform);
}

List<String> terminalFontFallbacks(
  String? fontFamily, [
  TargetPlatform? platform,
]) {
  final resolvedPlatform = _resolvedPlatform(platform);
  final fallbacks = <String>[
    resolveTerminalFontFamily(fontFamily, resolvedPlatform),
    ...switch (resolvedPlatform) {
      TargetPlatform.macOS => ['SF Mono', 'Menlo', 'Monaco', 'monospace'],
      TargetPlatform.windows => [
        'Consolas',
        'Cascadia Mono',
        'Cascadia Code',
        'Courier New',
        'Lucida Console',
        'monospace',
      ],
      _ => [
        'DejaVu Sans Mono',
        'Liberation Mono',
        'Noto Sans Mono',
        'monospace',
      ],
    },
    ..._xtermDefaultFallbacks,
  ];

  final uniqueFallbacks = <String>[];
  for (final fallback in fallbacks) {
    if (!uniqueFallbacks.contains(fallback)) {
      uniqueFallbacks.add(fallback);
    }
  }

  return uniqueFallbacks;
}

TerminalStyle buildTerminalTextStyle({
  required String? fontFamily,
  required double? fontSize,
  required double lineHeight,
  TargetPlatform? platform,
}) {
  final resolvedPlatform = _resolvedPlatform(platform);
  final resolvedFontFamily = resolveTerminalFontFamily(
    fontFamily,
    resolvedPlatform,
  );

  return TerminalStyle(
    fontFamily: resolvedFontFamily,
    fontSize: fontSize ?? kDefaultTerminalFontSize,
    height: lineHeight,
    fontFamilyFallback: terminalFontFallbacks(
      resolvedFontFamily,
      resolvedPlatform,
    ),
  );
}
