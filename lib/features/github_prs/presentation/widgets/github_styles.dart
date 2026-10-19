import 'package:flutter/material.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';

/// Parses a GitHub 6-hex label color (e.g. "d73a4a") into a [Color],
/// falling back to the accent color when missing or malformed.
Color githubLabelColor(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return AppColors.accent;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return AppColors.accent;
  return Color(0xFF000000 | value);
}

/// Brightens (dark themes) or darkens (light themes) a label color so its
/// text stays legible on the surface.
Color readableLabelForeground(Color color) {
  final hsl = HSLColor.fromColor(color);
  if (AppColors.brightness == Brightness.light) {
    if (hsl.lightness <= 0.4) return color;
    return hsl.withLightness(0.35).toColor();
  }
  if (hsl.lightness >= 0.65) return color;
  return hsl.withLightness(0.72).toColor();
}

/// A GitHub label in its own color.
class GithubLabelChip extends StatelessWidget {
  final GithubLabel label;

  /// Smaller text, for a single-line list row.
  final bool compact;

  const GithubLabelChip({super.key, required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final base = githubLabelColor(label.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: base.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          color: readableLabelForeground(base),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
