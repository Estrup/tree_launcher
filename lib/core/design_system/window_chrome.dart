import 'package:flutter/services.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';

/// Keeps the native macOS title bar in step with the active palette: the
/// strip above the Flutter view takes the header color (`surface0`) and the
/// window switches between the light and dark system appearance.
class WindowChrome {
  static const _channel = MethodChannel('tree_launcher/window');

  static Future<void> sync(AppColorPalette palette) async {
    try {
      await _channel.invokeMethod<void>('setAppearance', {
        'color': palette.surface0.toARGB32(),
        'dark': palette.brightness == Brightness.dark,
      });
    } on MissingPluginException {
      // No native side (e.g. widget tests).
    } on PlatformException {
      // Cosmetic only; never let it break a theme change.
    }
  }
}
