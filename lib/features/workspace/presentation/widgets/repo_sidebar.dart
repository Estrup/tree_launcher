import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/app/use_cases/claude_session_launcher.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/repo_pages.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_context_menu.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/sidebar/repo_rail_tile.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/sidebar/repo_tile.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/sidebar/sidebar_buttons.dart';

class RepoSidebar extends StatefulWidget {
  final VoidCallback onAddRepo;
  final VoidCallback onOpenSettings;
  final bool allowCollapse;

  const RepoSidebar({
    super.key,
    required this.onAddRepo,
    required this.onOpenSettings,
    this.allowCollapse = true,
  });

  @override
  State<RepoSidebar> createState() => _RepoSidebarState();
}

class _RepoSidebarState extends State<RepoSidebar> {
  bool _collapsed = false;

  void _toggleCollapsed() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<WorkspaceController>();
    final collapsed = widget.allowCollapse && _collapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: collapsed ? 64 : 240,
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: collapsed
          ? _buildRail(context, repoProvider)
          : _buildExpanded(context, repoProvider),
    );
  }

  Widget _buildExpanded(BuildContext context, WorkspaceController repoProvider) {
    final hidden = context.watch<SettingsController>().settings.hiddenRepos.toSet();
    final repos = repoProvider.repos
        .where((r) => !hidden.contains(r.path))
        .toList();
    return Column(
      children: [
        // Logo / brand
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.account_tree_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TreeLauncher',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (widget.allowCollapse) ...[
                const SizedBox(width: 8),
                SidebarCollapseToggle(
                  collapsed: false,
                  onTap: _toggleCollapsed,
                ),
              ],
            ],
          ),
        ),

          // Section label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Text(
                  'REPOSITORIES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Repo list (with nested Claude session shortcuts)
          Expanded(
            child: repos.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),
                        Icon(
                          Icons.folder_open_rounded,
                          size: 36,
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No repos yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: repos.length,
                    itemBuilder: (context, index) {
                      final repo = repos[index];
                      final isSelected = repo == repoProvider.selectedRepo;
                      return RepoTile(
                        repo: repo,
                        isSelected: isSelected,
                        pageKey: repoProvider.repoPageKey,
                        onTap: () {
                          context.read<TerminalController>().hide();
                          repoProvider.selectRepo(repo);
                        },
                        onOpenPage: (key) {
                          context.read<TerminalController>().hide();
                          repoProvider.selectRepo(repo);
                          repoProvider.showRepoPage(key);
                        },
                        onSettings: () {
                          repoProvider.selectRepo(repo);
                          if (!repoProvider.showSettings) {
                            repoProvider.toggleSettings();
                          }
                        },
                        onContextMenu: (pos) =>
                            _showRepoMenu(context, repoProvider, repo, pos),
                        onOpenClaudeSession: (path, pageKey) =>
                            _openClaudeSession(
                              context,
                              repoProvider,
                              repo,
                              path,
                              pageKey,
                            ),
                        onOpenAgent: (run) =>
                            _openAgent(context, repoProvider, repo, run),
                        onForgetClaudeSession: (path) =>
                            repoProvider.forgetClaudeSession(repo.path, path),
                      );
                    },
                  ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: SidebarAddRepoButton(onPressed: widget.onAddRepo)),
                const SizedBox(width: 8),
                SidebarTerminalToggle(),
                const SizedBox(width: 8),
                SidebarSettingsButton(onPressed: widget.onOpenSettings),
              ],
            ),
          ),
        ],
    );
  }

  // --- Collapsed navigation rail ---

  Widget _buildRail(BuildContext context, WorkspaceController repoProvider) {
    final hidden = context.watch<SettingsController>().settings.hiddenRepos.toSet();
    final repos = repoProvider.repos
        .where((r) => !hidden.contains(r.path))
        .toList();
    return Column(
      children: [
        // Compact brand + expand toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.account_tree_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 12),
              SidebarCollapseToggle(collapsed: true, onTap: _toggleCollapsed),
            ],
          ),
        ),
        // Repo avatar list
        Expanded(
          child: repos.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  itemCount: repos.length,
                  itemBuilder: (context, index) {
                    final repo = repos[index];
                    final isSelected = repo == repoProvider.selectedRepo;
                    return RepoRailTile(
                      repo: repo,
                      isSelected: isSelected,
                      onTap: () {
                        context.read<TerminalController>().hide();
                        repoProvider.selectRepo(repo);
                      },
                      onContextMenu: (pos) =>
                          _showRepoMenu(context, repoProvider, repo, pos),
                    );
                  },
                ),
        ),
        // Compact vertical action bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          child: Column(
            children: [
              SidebarRailIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Add Repo',
                accent: true,
                onTap: widget.onAddRepo,
              ),
              const SizedBox(height: 8),
              SidebarTerminalToggle(),
              const SizedBox(height: 8),
              SidebarRailIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Settings',
                onTap: widget.onOpenSettings,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Selects [repo] and the page the session is under, and shows (or
  /// resumes) its Claude session in [worktreePath].
  Future<void> _openClaudeSession(
    BuildContext context,
    WorkspaceController provider,
    RepoConfig repo,
    String worktreePath,
    String pageKey,
  ) async {
    final launcher = context.read<ClaudeSessionLauncher>();
    await provider.selectRepo(repo);
    provider.showRepoPage(pageKey);
    await launcher.resume(repoPath: repo.path, worktreePath: worktreePath);
  }

  /// Selects [repo] and [run]'s agent page, and shows (or resumes) the run's
  /// Claude session.
  Future<void> _openAgent(
    BuildContext context,
    WorkspaceController provider,
    RepoConfig repo,
    AgentRun run,
  ) async {
    final launcher = context.read<AgentLauncher>();
    await provider.selectRepo(repo);
    provider.showRepoPage(agentPageKey(run.kind));
    await launcher.resume(run);
  }

  Future<void> _showRepoMenu(
    BuildContext context,
    WorkspaceController provider,
    RepoConfig repo,
    Offset position,
  ) async {
    final action = await showRepoContextMenu(
      context: context,
      position: position,
    );
    switch (action) {
      case RepoContextMenuAction.openSettings:
        provider.selectRepo(repo);
        if (!provider.showSettings) {
          provider.toggleSettings();
        }
      case RepoContextMenuAction.hide:
        if (context.mounted) {
          context.read<SettingsController>().hideRepo(repo.path);
        }
      case RepoContextMenuAction.remove:
        if (context.mounted) {
          _confirmRemove(context, provider, repo);
        }
      case null:
        break;
    }
  }

  void _confirmRemove(
    BuildContext context,
    WorkspaceController provider,
    RepoConfig repo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Repository'),
        content: Text('Remove "${repo.name}" from TreeLauncher?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.removeRepo(repo);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// --- Collapse / expand toggle button ---
