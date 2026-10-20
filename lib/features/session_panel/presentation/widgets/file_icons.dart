import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/core/design_system/app_theme.dart';

/// The icon and its color for a file named [name], by its extension.
({IconData icon, Color color}) fileIcon(String name) {
  final lower = name.toLowerCase();
  final extension = p.extension(lower);
  return switch (extension) {
    '.md' ||
    '.markdown' => (icon: Icons.article_outlined, color: AppColors.vscode),
    '.html' || '.htm' => (icon: Icons.html_rounded, color: AppColors.claude),
    '.pdf' => (icon: Icons.picture_as_pdf_outlined, color: AppColors.error),
    '.json' ||
    '.yaml' ||
    '.yml' ||
    '.toml' ||
    '.xml' ||
    '.plist' => (icon: Icons.data_object_rounded, color: AppColors.branch),
    '.png' ||
    '.jpg' ||
    '.jpeg' ||
    '.gif' ||
    '.svg' ||
    '.webp' ||
    '.ico' => (icon: Icons.image_outlined, color: AppColors.success),
    '.sh' ||
    '.zsh' ||
    '.bash' => (icon: Icons.terminal_rounded, color: AppColors.terminal),
    '.dart' ||
    '.cs' ||
    '.ts' ||
    '.tsx' ||
    '.js' ||
    '.jsx' ||
    '.py' ||
    '.swift' ||
    '.kt' ||
    '.java' ||
    '.go' ||
    '.rs' ||
    '.sql' ||
    '.css' ||
    '.scss' => (icon: Icons.code_rounded, color: AppColors.accent),
    _ when lower.startsWith('.env') || lower.startsWith('.git') => (
      icon: Icons.settings_outlined,
      color: AppColors.textMuted,
    ),
    _ => (icon: Icons.insert_drive_file_outlined, color: AppColors.textMuted),
  };
}
