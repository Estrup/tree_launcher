import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// Number of the selected repo's open pull request from [branch], or null
/// when there is none (or the PR list isn't available).
int? openPrNumberForBranch(BuildContext context, String? branch) {
  if (branch == null || branch.isEmpty) return null;
  return Provider.of<GithubPrsController?>(context, listen: false)
      ?.pullRequests
      .where((pr) => pr.headBranch == branch)
      .firstOrNull
      ?.number;
}

/// Copies [value] to the clipboard and shows a brief confirmation snackbar.
void copyToClipboard(BuildContext context, String value, String label) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label copied to clipboard'),
      duration: const Duration(milliseconds: 1500),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Shows the standard delete-worktree confirmation dialog and, when confirmed,
/// closes any open terminal sessions for the path and deletes the worktree.
Future<void> confirmDeleteWorktree(BuildContext context, Worktree wt) async {
  final repoProvider = context.read<WorkspaceController>();
  final terminalProvider = context.read<TerminalController>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete worktree?'),
      content: Text(
        'This will permanently remove "${wt.name}" (${wt.branch}) from disk and git.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      terminalProvider.closeSessionsForPath(wt.path);
      await repoProvider.deleteWorktree(wt);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }
}

/// Confirms and deletes several worktrees sequentially, blocking the UI with a
/// non-dismissible progress dialog until all deletions finish. Failures are
/// collected and reported in a summary snackbar; they do not abort the run.
Future<void> confirmBulkDeleteWorktrees(
  BuildContext context,
  List<Worktree> worktrees,
) async {
  if (worktrees.isEmpty) return;
  final repoProvider = context.read<WorkspaceController>();
  final terminalProvider = context.read<TerminalController>();

  // Cap the listed names so a huge selection doesn't overflow the dialog.
  const maxListed = 8;
  final listed = worktrees.take(maxListed).toList();
  final remaining = worktrees.length - listed.length;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete ${worktrees.length} worktrees?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will permanently remove these worktrees from disk and git:',
          ),
          const SizedBox(height: 12),
          for (final wt in listed)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${wt.name} (${wt.branch})',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                ),
              ),
            ),
          if (remaining > 0)
            Text(
              '+ $remaining more',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // Modal barrier + canPop:false locks the whole UI (clicks and Escape) until
  // the loop below pops the dialog. Capture the navigator now: by the time the
  // run finishes, deleted rows have rebuilt the tree behind the barrier.
  final progress = ValueNotifier<int>(1);
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 16),
            ValueListenableBuilder<int>(
              valueListenable: progress,
              builder: (_, done, _) =>
                  Text('Deleting $done of ${worktrees.length}…'),
            ),
          ],
        ),
      ),
    ),
  );

  final failures = <String>[];
  for (var i = 0; i < worktrees.length; i++) {
    final wt = worktrees[i];
    progress.value = i + 1;
    try {
      terminalProvider.closeSessionsForPath(wt.path);
      await repoProvider.deleteWorktree(wt);
    } catch (_) {
      failures.add(wt.name);
    }
  }

  navigator.pop();
  progress.dispose();

  if (!context.mounted) return;
  final deleted = worktrees.length - failures.length;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failures.isEmpty
            ? 'Deleted $deleted worktrees'
            : 'Deleted $deleted of ${worktrees.length} — '
                  'failed: ${failures.join(', ')}',
      ),
      duration: failures.isEmpty
          ? const Duration(seconds: 3)
          : const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Shows a dialog to add, edit, or clear the JIRA ticket key attached to [wt].
/// Persists via [WorkspaceController.updateJiraIssue]; an empty value clears the key.
Future<void> editJiraIssueDialog(BuildContext context, Worktree wt) async {
  final repoProvider = context.read<WorkspaceController>();
  final controller = TextEditingController(text: wt.jiraIssue ?? '');
  final focusNode = FocusNode();

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      String? error;
      var requestedFocus = false;
      return StatefulBuilder(
        builder: (ctx, setState) {
          // Claim focus once after the first frame. Relying on autofocus loses a
          // race with the popup menu's focus restoration (see WorktreeOptions).
          if (!requestedFocus) {
            requestedFocus = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (focusNode.canRequestFocus) focusNode.requestFocus();
            });
          }

          void submit() {
            final value = controller.text.trim();
            final validationError = validateJiraKey(value);
            if (validationError != null) {
              setState(() => error = validationError);
              return;
            }
            Navigator.of(ctx).pop(true);
          }

          return AlertDialog(
            title: const Text('JIRA ticket'),
            content: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (_) {
                if (error != null) setState(() => error = null);
              },
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                hintText: 'AU2-0001',
                errorText: error,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(onPressed: submit, child: const Text('Save')),
            ],
          );
        },
      );
    },
  );

  if (saved == true) {
    final value = controller.text.trim();
    try {
      await repoProvider.updateJiraIssue(wt.path, value.isEmpty ? null : value);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update JIRA: $e')));
      }
    }
  }
  controller.dispose();
  focusNode.dispose();
}
