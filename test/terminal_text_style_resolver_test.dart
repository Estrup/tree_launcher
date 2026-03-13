import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/terminal/presentation/terminal_text_style_resolver.dart';

void main() {
  group('terminal text style resolver', () {
    test('uses Consolas as the Windows default terminal font', () {
      expect(defaultTerminalFontFamily(TargetPlatform.windows), 'Consolas');
    });

    test('normalizes unsupported Windows terminal fonts to the Windows default', () {
      expect(
        resolveTerminalFontFamily('SF Mono', TargetPlatform.windows),
        'Consolas',
      );
      expect(
        resolveTerminalFontFamily('Menlo', TargetPlatform.windows),
        'Consolas',
      );
    });

    test('keeps supported Windows terminal fonts', () {
      expect(
        resolveTerminalFontFamily('Cascadia Mono', TargetPlatform.windows),
        'Cascadia Mono',
      );
      expect(
        resolveTerminalFontFamily('JetBrains Mono', TargetPlatform.windows),
        'JetBrains Mono',
      );
    });

    test('builds a Windows-safe fallback chain', () {
      final fallbacks = terminalFontFallbacks(
        'Cascadia Mono',
        TargetPlatform.windows,
      );

      expect(
        fallbacks.take(5),
        orderedEquals([
          'Cascadia Mono',
          'Consolas',
          'Cascadia Code',
          'Courier New',
          'Lucida Console',
        ]),
      );
      expect(fallbacks, contains('monospace'));
    });

    test('buildTerminalTextStyle normalizes legacy Windows selections', () {
      final style = buildTerminalTextStyle(
        fontFamily: 'SF Mono',
        fontSize: null,
        lineHeight: 1.9,
        platform: TargetPlatform.windows,
      );

      expect(style.fontFamily, 'Consolas');
      expect(style.fontSize, kDefaultTerminalFontSize);
      expect(style.height, 1.9);
      expect(style.fontFamilyFallback.first, 'Consolas');
    });
  });
}
