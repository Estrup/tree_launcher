import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';

class GithubPrsTab extends StatefulWidget {
  const GithubPrsTab({super.key});

  @override
  State<GithubPrsTab> createState() => _GithubPrsTabState();
}

class _GithubPrsTabState extends State<GithubPrsTab> {
  String? _lastLoadedRepoPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  void _loadIfNeeded() {
    final workspace = context.read<WorkspaceController>();
    final repo = workspace.selectedRepo;
    if (repo == null) return;

    final config = repo.githubConfig;
    if (config == null || !config.isConfigured) return;

    if (_lastLoadedRepoPath != repo.path) {
      _lastLoadedRepoPath = repo.path;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<GithubPrsController>().loadPrs(config);
        }
      });
    }
  }

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
                fontSize: 14,
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
                  fontSize: 14,
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
                      fontSize: 11,
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
                      fontSize: 11,
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
                _HeaderAction(
                  icon: Icons.refresh,
                  tooltip: 'Refresh pull requests',
                  onTap: () => prs.refresh(),
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
                      style: TextStyle(color: AppColors.error, fontSize: 12),
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
                      fontSize: 14,
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

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _PullRequestRow extends StatelessWidget {
  final GithubPullRequest pr;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onCreateWorktree;

  const _PullRequestRow({
    required this.pr,
    required this.onOpenInBrowser,
    required this.onCreateWorktree,
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
                  fontSize: 12,
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
                        fontSize: 13,
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
              Tooltip(
                message: 'Create worktree from ${pr.headBranch}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: onCreateWorktree,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.add_circle_outline,
                        size: 16, color: AppColors.accent),
                  ),
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
                      fontSize: 11,
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
                  fontSize: 11,
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
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              if (pr.assignee != null) ...[
                const SizedBox(width: 16),
                Icon(Icons.assignment_ind_outlined,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  pr.assignee!,
                  style: TextStyle(
                    fontSize: 11,
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
                    fontSize: 11,
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
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              if (pr.labels.isNotEmpty) ...[
                const SizedBox(width: 12),
                ...pr.labels.take(3).map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accentMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ],
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
