import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

void main() {
  tearDown(() => AppColors.setTheme('minimal'));

  test('every palette has a picker name', () {
    expect(paletteDisplayNames.keys.toSet(), palettes.keys.toSet());
  });

  test('theme brightness follows the active palette', () {
    AppColors.setTheme('light');
    expect(AppTheme.current.brightness, Brightness.light);
    expect(AppTheme.current.colorScheme.brightness, Brightness.light);
    expect(AppTheme.current.scaffoldBackgroundColor, palettes['light']!.base);

    AppColors.setTheme('nord');
    expect(AppTheme.current.brightness, Brightness.dark);
    expect(AppTheme.current.colorScheme.brightness, Brightness.dark);
  });
}
