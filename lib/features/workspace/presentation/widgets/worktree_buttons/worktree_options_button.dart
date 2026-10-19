import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_buttons/action_buttons.dart';

/// Overflow "more options" button for a worktree row. Opens a menu offering
/// Attach/Edit JIRA ticket, Copy path, Hide/Unhide, Snooze/Unsnooze, and (for
/// non-main worktrees) Delete.
class WorktreeOptionsButton extends StatefulWidget {
  final Worktree worktree;
  const WorktreeOptionsButton({super.key, required this.worktree});

  @override
  State<WorktreeOptionsButton> createState() => _WorktreeOptionsButtonState();
}

class _WorktreeOptionsButtonState extends State<WorktreeOptionsButton> {
  bool _hovered = false;

  void _showMenu(BuildContext context) {
    final repoProvider = context.read<WorkspaceController>();
    final wt = widget.worktree;

    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label, {
      Color? color,
    }) {
      final c = color ?? AppColors.textPrimary;
      return PopupMenuItem<String>(
        value: value,
        height: 36,
        child: Row(
          children: [
            Icon(icon, size: 14, color: color ?? AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      );
    }

    showMenuBelow<String>(
      context,
      minWidth: 180,
      items: [
        item(
          'editJira',
          Icons.confirmation_number_outlined,
          (wt.jiraIssue == null || wt.jiraIssue!.isEmpty)
              ? 'Attach JIRA ticket'
              : 'Edit JIRA ticket',
        ),
        item('copyPath', Icons.content_copy_rounded, 'Copy path'),
        const PopupMenuDivider(height: 1),
        item(
          'hide',
          wt.isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          wt.isHidden ? 'Unhide' : 'Hide',
        ),
        item(
          'snooze',
          wt.isSnoozed
              ? Icons.notifications_active_rounded
              : Icons.snooze_rounded,
          wt.isSnoozed ? 'Unsnooze' : 'Snooze',
        ),
        if (!wt.isMain) ...[
          const PopupMenuDivider(height: 1),
          item(
            'delete',
            Icons.delete_outline_rounded,
            'Delete',
            color: AppColors.error,
          ),
        ],
      ],
    ).then((value) {
      switch (value) {
        case 'editJira':
          // Defer past the popup-menu route's focus restoration, which would
          // otherwise return focus to the underlying terminal and steal it from
          // the dialog's text field.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) editJiraIssueDialog(context, wt);
          });
          break;
        case 'copyPath':
          if (context.mounted) copyToClipboard(context, wt.path, 'Path');
          break;
        case 'hide':
          repoProvider.setWorktreeHidden(wt.path, !wt.isHidden);
          break;
        case 'snooze':
          repoProvider.setWorktreeSnoozed(wt.path, !wt.isSnoozed);
          break;
        case 'delete':
          if (context.mounted) confirmDeleteWorktree(context, wt);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showMenu(context),
        child: Tooltip(
          message: 'More options',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.more_vert_rounded,
              size: 16,
              color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pull-latest button
// ---------------------------------------------------------------------------
