import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

enum RepoContextMenuAction { openSettings, remove }

Future<RepoContextMenuAction?> showRepoContextMenu({
  required BuildContext context,
  required Offset position,
}) {
  return showMenu<RepoContextMenuAction>(
    context: context,
    color: AppColors.surface1,
    constraints: const BoxConstraints(minWidth: 180),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppColors.border),
    ),
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: [
      PopupMenuItem(
        value: RepoContextMenuAction.openSettings,
        height: 36,
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              'Open settings',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
      PopupMenuItem(
        value: RepoContextMenuAction.remove,
        height: 36,
        child: Row(
          children: [
            Icon(Icons.close_rounded, size: 15, color: AppColors.error),
            const SizedBox(width: 10),
            Text(
              'Delete',
              style: TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ],
        ),
      ),
    ],
  );
}
