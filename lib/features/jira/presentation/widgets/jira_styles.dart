import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

/// Colour for a Jira status category (`new`, `indeterminate`, `done`).
Color jiraStatusColor(String? category) {
  switch (category) {
    case 'done':
      return AppColors.success;
    case 'indeterminate':
      return AppColors.vscode;
    default:
      return AppColors.textSecondary;
  }
}

/// Icon and colour for an issue type name.
(IconData, Color) jiraTypeIcon(String? type) {
  switch (type?.trim().toLowerCase()) {
    case 'bug':
      return (Icons.bug_report_rounded, AppColors.error);
    case 'story':
      return (Icons.bookmark_rounded, AppColors.success);
    case 'task':
      return (Icons.check_box_rounded, AppColors.vscode);
    case 'epic':
      return (Icons.bolt_rounded, AppColors.branch);
    case 'new feature':
      return (Icons.add_box_rounded, AppColors.success);
    case 'improvement':
      return (Icons.arrow_circle_up_rounded, AppColors.success);
    default:
      return (Icons.circle_outlined, AppColors.textMuted);
  }
}

/// Colour for a Jira tag's color name (see `jiraTagColors`). Mid-tone, so
/// it reads on both light and dark palettes.
Color jiraTagColor(String name) => switch (name) {
  'blue' => const Color(0xFF3B82F6),
  'green' => const Color(0xFF22C55E),
  'yellow' => const Color(0xFFEAB308),
  'orange' => const Color(0xFFF97316),
  'red' => const Color(0xFFEF4444),
  'purple' => const Color(0xFFA855F7),
  'pink' => const Color(0xFFEC4899),
  _ => const Color(0xFF9CA3AF),
};
