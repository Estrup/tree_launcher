import 'package:flutter/material.dart';

/// Curated set of icons available for custom commands.
const Map<String, IconData> commandIconMap = {
  'terminal': Icons.terminal_rounded,
  'play': Icons.play_arrow_rounded,
  'rocket': Icons.rocket_launch_rounded,
  'build': Icons.build_rounded,
  'bug': Icons.bug_report_rounded,
  'cloud': Icons.cloud_rounded,
  'database': Icons.storage_rounded,
  'code': Icons.code_rounded,
  'science': Icons.science_rounded,
  'speed': Icons.speed_rounded,
  'bolt': Icons.bolt_rounded,
  'web': Icons.language_rounded,
  'api': Icons.api_rounded,
  'sync': Icons.sync_rounded,
  'test': Icons.check_circle_outline_rounded,
  'deploy': Icons.cloud_upload_rounded,
  'monitor': Icons.monitor_heart_rounded,
  'docker': Icons.directions_boat_rounded,
  'clean': Icons.cleaning_services_rounded,
  'format': Icons.format_paint_rounded,
};

/// Default icon names cycled for commands without an explicit choice.
const List<String> defaultIconNames = [
  'terminal',
  'play',
  'rocket',
  'build',
  'code',
  'bolt',
  'science',
  'web',
];

/// Preset color palette for custom commands.
const List<Color> commandColorPalette = [
  Color(0xFF10B981), // emerald
  Color(0xFF3B82F6), // blue
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // pink
  Color(0xFF06B6D4), // cyan
  Color(0xFFF97316), // orange
];

/// Hex strings for the palette (without leading #).
const List<String> commandColorHexPalette = [
  '10B981',
  '3B82F6',
  'F59E0B',
  'EF4444',
  '8B5CF6',
  'EC4899',
  '06B6D4',
  'F97316',
];

/// Resolve an icon name to [IconData], falling back to terminal icon.
IconData getCommandIcon(String? iconName) {
  if (iconName != null && commandIconMap.containsKey(iconName)) {
    return commandIconMap[iconName]!;
  }
  return Icons.terminal_rounded;
}

/// Resolve a hex color string to [Color], falling back by index.
Color getCommandColor(String? colorHex, [int fallbackIndex = 0]) {
  if (colorHex != null && colorHex.isNotEmpty) {
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}
  }
  return commandColorPalette[fallbackIndex % commandColorPalette.length];
}

/// Pick a default icon name for a command at the given index.
String defaultIconForIndex(int index) {
  return defaultIconNames[index % defaultIconNames.length];
}

/// Pick a default color hex for a command at the given index.
String defaultColorForIndex(int index) {
  return commandColorHexPalette[index % commandColorHexPalette.length];
}
