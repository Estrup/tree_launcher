import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/github_prs/presentation/pr_worktree_actions.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';

class GithubPrsTab extends StatelessWidget {
  const GithubPrsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final prs = context.watch<GithubPrsController>();
    final repo = workspace.selectedRepo;
    final config = repo?.githubConfig;

    if (config == null || !config.isConfigured) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.merge_type_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Configure GitHub in repo settings',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 17,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'Pull Requests',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (prs.pullRequests.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${prs.pullRequests.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (prs.lastRefreshed != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    _formatLastRefreshed(prs.lastRefreshed!),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              if (prs.isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                Tooltip(
                  message: 'Refresh pull requests',
                  child: ActionButton(
                    compact: true,
                    icon: Icons.refresh,
                    color: AppColors.accent,
                    bgColor: AppColors.accentMuted,
                    onPressed: () => prs.refresh(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (prs.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prs.error!,
                      style: TextStyle(color: AppColors.error, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!prs.isLoading && prs.error == null && prs.pullRequests.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: AppColors.success.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text(
                    'No open pull requests',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              itemCount: prs.pullRequests.length,
              itemBuilder: (context, index) {
                final pr = prs.pullRequests[index];
                return _PullRequestRow(
                  pr: pr,
                  onOpenInBrowser: () =>
                      Process.run('open', [pr.htmlUrl]),
                  onCreateWorktree: () =>
                      _showAddWorktreeDialog(context, pr),
                  onQuickCreateWorktree: () => createWorktreeForPr(
                    context.read<WorkspaceController>(),
                    pr,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showAddWorktreeDialog(BuildContext context, GithubPullRequest pr) {
    AddWorktreeDialog.show(
      context,
      initialName: pr.headBranch,
    );
  }

  String _formatLastRefreshed(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _PullRequestRow extends StatelessWidget {
  final GithubPullRequest pr;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onCreateWorktree;
  final Future<void> Function() onQuickCreateWorktree;

  const _PullRequestRow({
    required this.pr,
    required this.onOpenInBrowser,
    required this.onCreateWorktree,
    required this.onQuickCreateWorktree,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: PR icon + number, title, actions
          Row(
            children: [
              Icon(
                Icons.merge_type_rounded,
                size: 14,
                color: pr.draft ? AppColors.textMuted : AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                '#${pr.number}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onOpenInBrowser,
                    child: Text(
                      pr.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _QuickCreateButton(
                headBranch: pr.headBranch,
                onPressed: onQuickCreateWorktree,
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Create worktree from ${pr.headBranch}…',
                child: ActionButton(
                  compact: true,
                  icon: Icons.add_circle_outline,
                  color: AppColors.accent,
                  bgColor: AppColors.accentMuted,
                  onPressed: onCreateWorktree,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Line 2: metadata
          Row(
            children: [
              const SizedBox(width: 28),
              // Branch
              Icon(Icons.account_tree, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    pr.headBranch,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Age
              Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                _formatAge(pr.createdAt),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              // Author
              Icon(Icons.person_outline, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                pr.author,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (pr.requestedReviewers.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Icons.rate_review_outlined,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    pr.requestedReviewers.join(', '),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (pr.assignee != null) ...[
                const SizedBox(width: 16),
                Icon(Icons.assignment_ind_outlined,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  pr.assignee!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (pr.milestone != null) ...[
                const SizedBox(width: 16),
                Icon(Icons.flag_outlined,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  pr.milestone!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (pr.draft) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Draft',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Line 3: labels (all, with GitHub colors)
          if (pr.labels.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: pr.labels.map(_buildLabelChip).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabelChip(GithubLabel label) {
    final base = _hexToColor(label.color);
    final foreground = _readableForeground(base);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: base.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.name,
        style: TextStyle(
          fontSize: 12,
          color: foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatAge(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }
}

/// Quick-create (instant) worktree button that shows a spinner in place of the
/// button while creation is in progress. This gives the user visual feedback
/// and prevents firing the action multiple times with repeated clicks.
class _QuickCreateButton extends StatefulWidget {
  final String headBranch;
  final Future<void> Function() onPressed;

  const _QuickCreateButton({
    required this.headBranch,
    required this.onPressed,
  });

  @override
  State<_QuickCreateButton> createState() => _QuickCreateButtonState();
}

class _QuickCreateButtonState extends State<_QuickCreateButton> {
  bool _busy = false;

  Future<void> _handlePressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Match the compact ActionButton footprint (28x28) so the row doesn't
    // shift when swapping between the button and the spinner.
    if (_busy) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    return Tooltip(
      message: 'Quick-create worktree from ${widget.headBranch}',
      child: ActionButton(
        compact: true,
        icon: Icons.bolt_rounded,
        color: AppColors.accent,
        bgColor: AppColors.accentMuted,
        onPressed: _handlePressed,
      ),
    );
  }
}

/// Parses a GitHub 6-hex label color (e.g. "d73a4a") into a [Color],
/// falling back to the accent color when missing or malformed.
Color _hexToColor(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length != 6) return AppColors.accent;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return AppColors.accent;
  return Color(0xFF000000 | value);
}

/// Brightens a label color so its text stays legible on the dark surface.
Color _readableForeground(Color color) {
  final hsl = HSLColor.fromColor(color);
  if (hsl.lightness >= 0.65) return color;
  return hsl.withLightness(0.72).toColor();
}
