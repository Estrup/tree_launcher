import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/presentation/agent_launcher.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/terminal/presentation/claude_session_actions.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/presentation/repo_pages.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_context_menu.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'package:tree_launcher/providers/terminal_provider.dart';

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
    final repoProvider = context.watch<RepoProvider>();
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

  Widget _buildExpanded(BuildContext context, RepoProvider repoProvider) {
    final hidden = context.watch<SettingsProvider>().settings.hiddenRepos.toSet();
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
                _CollapseToggleButton(
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
                      return _RepoTile(
                        repo: repo,
                        isSelected: isSelected,
                        pageKey: repoProvider.repoPageKey,
                        onTap: () {
                          context.read<TerminalProvider>().hide();
                          repoProvider.selectRepo(repo);
                        },
                        onOpenPage: (key) {
                          context.read<TerminalProvider>().hide();
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
                Expanded(child: _AddRepoButton(onPressed: widget.onAddRepo)),
                const SizedBox(width: 8),
                _TerminalToggleButton(),
                const SizedBox(width: 8),
                _SettingsButton(onPressed: widget.onOpenSettings),
              ],
            ),
          ),
        ],
    );
  }

  // --- Collapsed navigation rail ---

  Widget _buildRail(BuildContext context, RepoProvider repoProvider) {
    final hidden = context.watch<SettingsProvider>().settings.hiddenRepos.toSet();
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
              _CollapseToggleButton(collapsed: true, onTap: _toggleCollapsed),
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
                    return _RepoRailTile(
                      repo: repo,
                      isSelected: isSelected,
                      onTap: () {
                        context.read<TerminalProvider>().hide();
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
              _RailIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Add Repo',
                accent: true,
                onTap: widget.onAddRepo,
              ),
              const SizedBox(height: 8),
              _TerminalToggleButton(),
              const SizedBox(height: 8),
              _RailIconButton(
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
    RepoProvider provider,
    RepoConfig repo,
    String worktreePath,
    String pageKey,
  ) async {
    final launcher = ClaudeSessionLauncher.of(context);
    await provider.selectRepo(repo);
    provider.showRepoPage(pageKey);
    await launcher.resume(repoPath: repo.path, worktreePath: worktreePath);
  }

  /// Selects [repo] and [run]'s agent page, and shows (or resumes) the run's
  /// Claude session.
  Future<void> _openAgent(
    BuildContext context,
    RepoProvider provider,
    RepoConfig repo,
    AgentRun run,
  ) async {
    final launcher = AgentLauncher.of(context);
    await provider.selectRepo(repo);
    provider.showRepoPage(agentPageKey(run.kind));
    await launcher.resume(run);
  }

  Future<void> _showRepoMenu(
    BuildContext context,
    RepoProvider provider,
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
          context.read<SettingsProvider>().hideRepo(repo.path);
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
    RepoProvider provider,
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

class _CollapseToggleButton extends StatefulWidget {
  final bool collapsed;
  final VoidCallback onTap;

  const _CollapseToggleButton({required this.collapsed, required this.onTap});

  @override
  State<_CollapseToggleButton> createState() => _CollapseToggleButtonState();
}

class _CollapseToggleButtonState extends State<_CollapseToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              widget.collapsed
                  ? Icons.menu_open_rounded
                  : Icons.keyboard_double_arrow_left_rounded,
              size: 16,
              color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Collapsed rail repo avatar tile ---

class _RepoRailTile extends StatefulWidget {
  final RepoConfig repo;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(Offset position) onContextMenu;

  const _RepoRailTile({
    required this.repo,
    required this.isSelected,
    required this.onTap,
    required this.onContextMenu,
  });

  @override
  State<_RepoRailTile> createState() => _RepoRailTileState();
}

class _RepoRailTileState extends State<_RepoRailTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final letter = widget.repo.name.isNotEmpty
        ? widget.repo.name[0].toUpperCase()
        : '?';

    return Tooltip(
      message: widget.repo.name,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapDown: (d) => widget.onContextMenu(d.globalPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(vertical: 3),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.accentMuted
                  : _hovered
                  ? AppColors.surface1
                  : AppColors.surface0,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isSelected
                    ? AppColors.accent
                    : AppColors.border,
                width: widget.isSelected ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: widget.isSelected
                    ? AppColors.accent
                    : _hovered
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Collapsed rail icon button ---

class _RailIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool accent;
  final VoidCallback onTap;

  const _RailIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  @override
  State<_RailIconButton> createState() => _RailIconButtonState();
}

class _RailIconButtonState extends State<_RailIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (widget.accent) {
      bg = _hovered ? AppColors.accent : AppColors.accentMuted;
      fg = _hovered ? AppColors.base : AppColors.accent;
    } else {
      bg = _hovered ? AppColors.surface2 : Colors.transparent;
      fg = _hovered ? AppColors.textPrimary : AppColors.textMuted;
    }

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.accent
                    ? (_hovered
                          ? AppColors.accent
                          : AppColors.accent.withValues(alpha: 0.3))
                    : AppColors.border,
              ),
            ),
            child: Icon(widget.icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}

// --- Repo tile with left accent bar ---

class _RepoTile extends StatefulWidget {
  final RepoConfig repo;
  final bool isSelected;

  /// Key of the page shown for the selected repo.
  final String pageKey;
  final VoidCallback onTap;
  final ValueChanged<String> onOpenPage;
  final VoidCallback onSettings;
  final void Function(Offset position) onContextMenu;

  /// Opens the session in a worktree, given the page it is under.
  final void Function(String worktreePath, String pageKey) onOpenClaudeSession;
  final ValueChanged<String> onForgetClaudeSession;
  final ValueChanged<AgentRun> onOpenAgent;

  const _RepoTile({
    required this.repo,
    required this.isSelected,
    required this.pageKey,
    required this.onTap,
    required this.onOpenPage,
    required this.onSettings,
    required this.onContextMenu,
    required this.onOpenClaudeSession,
    required this.onForgetClaudeSession,
    required this.onOpenAgent,
  });

  @override
  State<_RepoTile> createState() => _RepoTileState();
}

class _RepoTileState extends State<_RepoTile> {
  bool _hovered = false;

  /// Under the repo: its pages (all of them for the selected repo, else only
  /// those with sessions), each with the Claude sessions that belong to it.
  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final agents = Provider.of<AgentsController?>(context);
    final tp = context.watch<TerminalProvider>();
    final active = tp.isVisible ? tp.activeSession : null;
    final pages = repoPagesFor(repo, agents);
    final pageKeys = {for (final page in pages) page.key};

    // Each page's sessions: agent runs and remembered shortcuts.
    final sessions = <String, List<_PageSession>>{};
    // A build agent's worktree is also a shortcut; the agent stands for it.
    final buildAgentPaths = <String>{};
    for (final run in agents?.runs ?? const <AgentRun>[]) {
      if (run.repoName != repo.name) continue;
      final isOpen = tp.claudeSessionForAgent(run.id) != null;
      if (!showsAgentSession(run, isOpen: isOpen)) continue;
      sessions
          .putIfAbsent(agentPageKey(run.kind), () => [])
          .add((startedAt: run.startedAt, order: 0, path: null, run: run));
      final path = run.worktreePath;
      if (run.kind == AgentKind.build && !run.state.isFinished && path != null) {
        buildAgentPaths.add(path);
      }
    }
    for (final (index, path) in repo.claudeSessions.indexed) {
      if (buildAgentPaths.contains(path)) continue;
      final pageKey = sessionPageKey(
        repo,
        path,
        pageKeys,
        runs: agents?.runs ?? const [],
      );
      final started = DateTime.tryParse(repo.claudeSessionStarts[path] ?? '');
      sessions.putIfAbsent(pageKey, () => []).add((
        // Shortcuts from before start times were kept count as oldest, in
        // the order they were remembered.
        startedAt: started ?? DateTime.fromMillisecondsSinceEpoch(0),
        order: index,
        path: path,
        run: null,
      ));
    }
    // Newest first, in a fixed order: not moved by status or updates.
    for (final list in sessions.values) {
      list.sort((a, b) {
        final byStart = b.startedAt.compareTo(a.startedAt);
        return byStart != 0 ? byStart : b.order.compareTo(a.order);
      });
    }

    final shown = [
      for (final page in pages)
        if (widget.isSelected || sessions.containsKey(page.key)) page,
    ];
    if (shown.isEmpty) return _buildRepoRow();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRepoRow(),
        for (final page in shown) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _PageTile(
              page: page,
              isActive:
                  widget.isSelected &&
                  active == null &&
                  widget.pageKey == page.key,
              onTap: () => widget.onOpenPage(page.key),
            ),
          ),
          for (final session in sessions[page.key] ?? const <_PageSession>[])
            if (session.run case final run?)
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: _ClaudeSessionTile(
                  worktreePath: run.worktreePath ?? '',
                  label: run.title ?? run.promptName ?? run.kind.label,
                  icon: run.kind.icon,
                  jiraIssue: run.issueKeys.firstOrNull,
                  isRunning: tp.claudeSessionForAgent(run.id) != null,
                  needsYou: agents!.needsYou(run),
                  isActive: active?.agentId == run.id,
                  onTap: () => widget.onOpenAgent(run),
                  onContextMenu: (position) => _showAgentMenu(position, run),
                ),
              )
            else if (session.path case final path?)
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: _ClaudeSessionTile(
                  worktreePath: path,
                  jiraIssue: repo.jiraIssues[path],
                  isRunning: tp.claudeSessionFor(path) != null,
                  onContextMenu: (position) =>
                      _showSessionMenu(position, path, page.key),
                  isActive:
                      active != null &&
                      active.isClaude &&
                      active.agentId == null &&
                      active.workingDirectory == path,
                  onTap: () => widget.onOpenClaudeSession(path, page.key),
                  onRemove: () => widget.onForgetClaudeSession(path),
                ),
              ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  /// Right-click menu of a remembered session in [path] under [pageKey].
  Future<void> _showSessionMenu(
    Offset position,
    String path,
    String pageKey,
  ) async {
    final terminal = context.read<TerminalProvider>();
    final running = terminal.claudeSessionFor(path) != null;
    final action = await _showMenuAt(position, [
      _menuItem('show', Icons.open_in_new_rounded, 'Show'),
      if (running) _menuItem('stop', Icons.stop_rounded, 'Stop session'),
      _menuItem('remove', Icons.close_rounded, 'Remove shortcut'),
    ]);
    switch (action) {
      case 'show':
        widget.onOpenClaudeSession(path, pageKey);
      case 'stop':
        terminal.closeClaudeSessions(path);
      case 'remove':
        widget.onForgetClaudeSession(path);
    }
  }

  /// Right-click menu of an agent's session.
  Future<void> _showAgentMenu(Offset position, AgentRun run) async {
    final launcher = AgentLauncher.of(context);
    final agents = context.read<AgentsController>();
    final action = await _showMenuAt(position, [
      _menuItem('show', Icons.open_in_new_rounded, 'Show'),
      if (launcher.isOpen(run) || !run.state.isFinished)
        _menuItem('stop', Icons.stop_rounded, 'Stop agent'),
      _menuItem('archive', Icons.archive_outlined, 'Archive'),
    ]);
    switch (action) {
      case 'show':
        widget.onOpenAgent(run);
      case 'stop':
        await launcher.stop(run);
      case 'archive':
        await agents.setArchived(run.id, true);
    }
  }

  Future<String?> _showMenuAt(
    Offset position,
    List<PopupMenuEntry<String>> items,
  ) => showMenu<String>(
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
    items: items,
  );

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text) =>
      PopupMenuItem(
        value: value,
        height: 36,
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
      );

  Widget _buildRepoRow() {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (d) => widget.onContextMenu(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.surface2
                : _hovered
                ? AppColors.surface1
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left accent bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppColors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.repo.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: widget.isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.repo.path.replaceFirst(
                            RegExp(r'^/Users/[^/]+'),
                            '~',
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Action icons (only on hover)
                if (_hovered || widget.isSelected)
                  _TinyIconButton(
                    icon: Icons.edit_rounded,
                    onTap: widget.onSettings,
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TinyIconButton({required this.icon, required this.onTap});

  @override
  State<_TinyIconButton> createState() => _TinyIconButtonState();
}

class _TinyIconButtonState extends State<_TinyIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// --- Bottom bar buttons ---

class _AddRepoButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AddRepoButton({required this.onPressed});

  @override
  State<_AddRepoButton> createState() => _AddRepoButtonState();
}

class _AddRepoButtonState extends State<_AddRepoButton> {
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
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accent : AppColors.accentMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 16,
                color: _hovered ? AppColors.base : AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Add Repo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? AppColors.base : AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _SettingsButton({required this.onPressed});

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 16,
            color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TerminalToggleButton extends StatefulWidget {
  const _TerminalToggleButton();

  @override
  State<_TerminalToggleButton> createState() => _TerminalToggleButtonState();
}

class _TerminalToggleButtonState extends State<_TerminalToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerminalProvider>();
    final count = tp.sessions.length;
    final hasSessions = count > 0;
    final isActive = tp.isVisible && hasSessions;

    final Color fg;
    if (!hasSessions) {
      fg = AppColors.textMuted.withValues(alpha: 0.4);
    } else if (isActive) {
      fg = AppColors.terminal;
    } else {
      fg = _hovered ? AppColors.textPrimary : AppColors.textMuted;
    }

    final Color bg;
    if (isActive) {
      bg = AppColors.terminal.withValues(alpha: 0.15);
    } else {
      bg = _hovered && hasSessions ? AppColors.surface2 : Colors.transparent;
    }

    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: hasSessions
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: hasSessions ? tp.toggleVisibility : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.terminal.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(Icons.terminal_rounded, size: 16, color: fg),
              ),
              if (hasSessions)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: AppColors.terminal,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.base, width: 1.5),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.base,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Tooltip(
      message: hasSessions
          ? (isActive ? 'Hide terminals' : 'Show terminals ($count)')
          : 'No active terminals',
      child: button,
    );
  }
}

// --- Claude session shortcut ---

class _ClaudeSessionTile extends StatefulWidget {
  final String worktreePath;

  /// Name shown; the worktree's folder name by default.
  final String? label;

  /// Icon instead of Claude's (an agent's kind).
  final IconData? icon;

  /// Jira issue key of the session, shown below its name.
  final String? jiraIssue;
  final bool isRunning;
  final bool isActive;

  /// Whether the session waits for a human (an agent at a gate).
  final bool needsYou;
  final VoidCallback onTap;

  /// Removes the shortcut; null when it can't be removed here.
  final VoidCallback? onRemove;

  /// Opens the right-click menu at a global position.
  final void Function(Offset position)? onContextMenu;

  const _ClaudeSessionTile({
    required this.worktreePath,
    this.label,
    this.icon,
    this.jiraIssue,
    required this.isRunning,
    required this.isActive,
    this.needsYou = false,
    required this.onTap,
    this.onRemove,
    this.onContextMenu,
  });

  @override
  State<_ClaudeSessionTile> createState() => _ClaudeSessionTileState();
}

class _ClaudeSessionTileState extends State<_ClaudeSessionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? AppColors.claude : AppColors.textMuted;
    final jiraIssue = widget.jiraIssue?.isEmpty ?? true
        ? null
        : widget.jiraIssue;
    return Tooltip(
      message:
          '${widget.worktreePath}\n'
          '${widget.needsYou ? 'Waiting for you — click to show' : widget.isRunning ? 'Running — click to show' : 'Click to resume'}',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapDown: widget.onContextMenu == null
              ? null
              : (d) => widget.onContextMenu!(d.globalPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.claude.withValues(alpha: 0.12)
                  : _hovered
                  ? AppColors.surface1
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IntrinsicHeight(
              // Top-aligned, so the icon, dot and remove button stay level
              // with the name's first line however many lines follow.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isActive
                          ? AppColors.claude
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: widget.icon != null
                        ? Icon(
                            widget.icon,
                            size: 13,
                            color: widget.isRunning ? AppColors.claude : color,
                          )
                        : SvgPicture.asset(
                            'assets/icons/claude.svg',
                            width: 12,
                            height: 12,
                            colorFilter: ColorFilter.mode(
                              widget.isRunning ? AppColors.claude : color,
                              BlendMode.srcIn,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label ?? p.basename(widget.worktreePath),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: widget.isActive
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: widget.isActive
                                  ? AppColors.claude
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (jiraIssue != null) ...[
                            const SizedBox(height: 5),
                            JiraBadge(issueKey: jiraIssue, compact: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (widget.isRunning || widget.needsYou) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 13),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: widget.needsYou
                              ? agentWaitingColor
                              : AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (_hovered && widget.onRemove != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Tooltip(
                        message: 'Remove shortcut',
                        child: _TinyIconButton(
                          icon: Icons.close_rounded,
                          onTap: widget.onRemove!,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A session under a page in the sidebar: an agent [run], or a remembered
/// shortcut to the session in [path]. [order] breaks ties in [startedAt].
typedef _PageSession = ({
  DateTime startedAt,
  int order,
  String? path,
  AgentRun? run,
});

// --- Repo page entry ---

/// One of a repo's pages in the sidebar; tapping shows it.
class _PageTile extends StatefulWidget {
  final RepoPage page;
  final bool isActive;
  final VoidCallback onTap;

  const _PageTile({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_PageTile> createState() => _PageTileState();
}

class _PageTileState extends State<_PageTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final isActive = widget.isActive;
    final color = page.agentKind?.color ?? AppColors.accent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.12)
                : _hovered
                ? AppColors.surface1
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                page.icon,
                size: 14,
                color: isActive ? color : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  page.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (page.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: agentWaitingColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${page.badge}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.base,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
