import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/activity/presentation/widgets/activity_tab.dart';
import 'package:tree_launcher/features/github_prs/presentation/widgets/github_prs_tab.dart';
import 'package:tree_launcher/features/github_prs/presentation/widgets/pr_review_toast.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_issues_tab.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/running_commands_bar.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/terminal_panel.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_repo_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings_view.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_sidebar.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_list.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/terminal_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const double _collapseBreakpoint = 800;
  bool _sidebarOpen = false;
  TabController? _tabController;
  int _lastTabCount = 0;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<RepoProvider>();
    final terminalProvider = context.watch<TerminalProvider>();
    final isTerminalActive =
        terminalProvider.isVisible && terminalProvider.sessions.isNotEmpty;

    final hasGithubPrsTab =
        repoProvider.selectedRepo?.githubConfig != null &&
        repoProvider.selectedRepo!.githubConfig!.isConfigured;
    final githubPrsTabCount = hasGithubPrsTab ? 1 : 0;
    final hasJiraTab = repoProvider.selectedRepo?.jiraProjectKey != null;
    final jiraTabIndex = 1 + githubPrsTabCount;
    // Worktrees + [PRs] + [Jira] + Activity
    final activityTabIndex = jiraTabIndex + (hasJiraTab ? 1 : 0);
    final tabCount = activityTabIndex + 1;

    if (_tabController == null || _lastTabCount != tabCount) {
      final oldIndex = _tabController?.index ?? 0;
      _tabController?.dispose();
      _tabController = TabController(
        length: tabCount,
        initialIndex: oldIndex >= tabCount
            ? (tabCount > 0 ? tabCount - 1 : 0)
            : oldIndex,
        vsync: this,
      );
      _lastTabCount = tabCount;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.backquote, meta: true): () {
          final tp = context.read<TerminalProvider>();
          if (tp.sessions.isNotEmpty) {
            tp.toggleVisibility();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.base,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isCollapsed = constraints.maxWidth < _collapseBreakpoint;

              // Auto-close overlay when window grows past breakpoint
              if (!isCollapsed && _sidebarOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _sidebarOpen = false);
                });
              }

              if (repoProvider.showSettings) {
                return const RepoSettingsView();
              }

              return Stack(
                children: [
                  Row(
                    children: [
                      if (!isCollapsed)
                        RepoSidebar(
                          onAddRepo: () => AddRepoDialog.show(context),
                          onOpenSettings: () => SettingsDialog.show(context),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            _buildHeader(
                              context,
                              repoProvider,
                              showMenuButton: isCollapsed,
                            ),
                            Expanded(
                              child: isTerminalActive
                                  ? const TerminalFullView()
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 24,
                                            right: 24,
                                            top: 16,
                                            bottom: 0,
                                          ),
                                          child: AnimatedBuilder(
                                            animation: _tabController!,
                                            builder: (context, _) {
                                              final currentIndex =
                                                  _tabController!.index;
                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: SingleChildScrollView(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: AppColors
                                                                  .surface0,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                _buildSegmentTab(
                                                                  text:
                                                                      "Worktrees",
                                                                  index: 0,
                                                                  currentIndex:
                                                                      currentIndex,
                                                                  onTap: () =>
                                                                      _tabController!
                                                                          .animateTo(
                                                                            0,
                                                                          ),
                                                                ),
                                                                if (hasGithubPrsTab)
                                                                  _buildSegmentTab(
                                                                    text: 'PRs',
                                                                    index: 1,
                                                                    currentIndex:
                                                                        currentIndex,
                                                                    icon: Icons
                                                                        .merge_type_rounded,
                                                                    onTap: () =>
                                                                        _tabController!
                                                                            .animateTo(
                                                                              1,
                                                                            ),
                                                                  ),
                                                                if (hasJiraTab)
                                                                  _buildSegmentTab(
                                                                    text:
                                                                        'Jira',
                                                                    index:
                                                                        jiraTabIndex,
                                                                    currentIndex:
                                                                        currentIndex,
                                                                    icon: Icons
                                                                        .confirmation_number_outlined,
                                                                    onTap: () =>
                                                                        _tabController!.animateTo(
                                                                          jiraTabIndex,
                                                                        ),
                                                                  ),
                                                                _buildSegmentTab(
                                                                  text:
                                                                      "Activity",
                                                                  index:
                                                                      activityTabIndex,
                                                                  currentIndex:
                                                                      currentIndex,
                                                                  icon: Icons
                                                                      .history_rounded,
                                                                  onTap: () =>
                                                                      _tabController!
                                                                          .animateTo(
                                                                            activityTabIndex,
                                                                          ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  if (currentIndex == 0) ...[
                                                    const SizedBox(width: 12),
                                                    const WorktreeListOptionsButton(),
                                                  ],
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Expanded(
                                          child: TabBarView(
                                            controller: _tabController,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            children: [
                                              const WorktreeList(),
                                              if (hasGithubPrsTab)
                                                const GithubPrsTab(),
                                              if (hasJiraTab)
                                                const JiraIssuesTab(),
                                              const ActivityTab(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const RunningCommandsBar(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Scrim
                  if (isCollapsed && _sidebarOpen)
                    GestureDetector(
                      onTap: () => setState(() => _sidebarOpen = false),
                      child: AnimatedOpacity(
                        opacity: _sidebarOpen ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(color: Colors.black54),
                      ),
                    ),
                  // Sliding sidebar overlay
                  if (isCollapsed)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      top: 0,
                      bottom: 0,
                      left: _sidebarOpen ? 0 : -240,
                      width: 240,
                      child: Material(
                        elevation: 8,
                        color: Colors.transparent,
                        child: RepoSidebar(
                          allowCollapse: false,
                          onAddRepo: () {
                            setState(() => _sidebarOpen = false);
                            AddRepoDialog.show(context);
                          },
                          onOpenSettings: () {
                            setState(() => _sidebarOpen = false);
                            SettingsDialog.show(context);
                          },
                        ),
                      ),
                    ),
                  // New PR review-request notification
                  const PrReviewToast(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTab({
    required String text,
    required int index,
    required int currentIndex,
    required VoidCallback onTap,
    GestureTapUpCallback? onSecondaryTapUp,
    IconData? icon,
    Color? activeColor,
  }) {
    final isSelected = index == currentIndex;
    final color = activeColor ?? AppColors.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onSecondaryTapUp: onSecondaryTapUp,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? color : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    RepoProvider repoProvider, {
    bool showMenuButton = false,
  }) {
    final selectedRepo = repoProvider.selectedRepo;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            _MenuButton(
              onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
            ),
            const SizedBox(width: 12),
          ],
          if (selectedRepo != null) ...[
            // Repo name + worktree count
            Text(
              selectedRepo.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${repoProvider.worktrees.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ] else
            Text(
              'TreeLauncher',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          const Spacer(),
          if (selectedRepo != null) ...[
            _AddWorktreeButton(
              onPressed: () => AddWorktreeDialog.show(context),
            ),
            const SizedBox(width: 8),
            _RefreshButton(
              loading: repoProvider.loading,
              onPressed: () => repoProvider.refreshWorktrees(),
            ),
          ],
        ],
      ),
    );
  }
}

class _RefreshButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _RefreshButton({required this.loading, required this.onPressed});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
                ),
        ),
      ),
    );
  }
}

class _AddWorktreeButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AddWorktreeButton({required this.onPressed});

  @override
  State<_AddWorktreeButton> createState() => _AddWorktreeButtonState();
}

class _AddWorktreeButtonState extends State<_AddWorktreeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.terminal.withValues(alpha: 0.15)
                : AppColors.terminalBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? AppColors.terminal.withValues(alpha: 0.4)
                  : AppColors.terminal.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 15, color: AppColors.terminal),
              SizedBox(width: 5),
              Text(
                'New Worktree',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.terminal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _MenuButton({required this.onPressed});

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.menu_rounded,
            size: 20,
            color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
