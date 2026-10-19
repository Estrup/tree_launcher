import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/repo_pages.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_buttons/jira_badge.dart';

class RepoTile extends StatefulWidget {
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

  const RepoTile({
    super.key,
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
  State<RepoTile> createState() => _RepoTileState();
}

class _RepoTileState extends State<RepoTile> {
  bool _hovered = false;

  /// Under the repo: its pages (all of them for the selected repo, else only
  /// those with sessions), each with the Claude sessions that belong to it.
  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final agents = Provider.of<AgentsController?>(context);
    final tp = context.watch<TerminalController>();
    final active = tp.isVisible ? tp.activeSession : null;
    final pages = repoPagesFor(repo, agents);
    final pageKeys = {for (final page in pages) page.key};

    final metadata = context.read<WorkspaceController>().metadata;
    final sessions = sessionsByPage(
      repo,
      pageKeys: pageKeys,
      runs: agents?.runs ?? const [],
      isOpen: (run) => tp.claudeSessionForAgent(run.id) != null,
      remembered: metadata.sessionsFor(repo.path),
    );

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
          for (final session in sessions[page.key] ?? const <PageSession>[])
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
                  jiraIssue: metadata[path]?.jiraIssue,
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
    final terminal = context.read<TerminalController>();
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
    final launcher = context.read<AgentLauncher>();
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
