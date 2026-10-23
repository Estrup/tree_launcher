import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/app/use_cases/claude_session_launcher.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/widgets/issue_list.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/repo_pages.dart';

/// The sessions in [repo] a list row stands for (see [sessionsWhere]), from
/// the agents and worktrees in the widget tree, which rebuild [context] when
/// they change.
List<PageSession> watchSessions(
  BuildContext context,
  RepoConfig repo, {
  required bool Function(WorktreeMetadata worktree) inWorktree,
  bool Function(AgentRun run)? runMatches,
}) => sessionsWhere(
  repo,
  inWorktree: inWorktree,
  runMatches: runMatches,
  agentTypes: agentTypesOf(context),
  runs: Provider.of<AgentsController?>(context)?.runs ?? const [],
  worktrees: context.watch<WorkspaceController>().metadata.forRepo(repo.path),
);

/// Whether [session]'s Claude session is open in the built-in terminal.
bool sessionIsOpen(TerminalController? terminal, PageSession session) {
  if (terminal == null) return false;
  if (session.run case final run?) {
    return terminal.claudeSessionForAgent(run.id) != null;
  }
  return terminal.claudeSessionFor(session.path!) != null;
}

/// On a list row (an issue, worktree or pull request): how many [sessions]
/// it has, a dot when one is open, and a chevron that shows or hides them
/// below the row.
class SessionsToggle extends StatelessWidget {
  const SessionsToggle({
    super.key,
    required this.sessions,
    required this.expanded,
    required this.onTap,
  });

  final List<PageSession> sessions;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final terminal = Provider.of<TerminalController?>(context);
    final anyOpen = sessions.any((s) => sessionIsOpen(terminal, s));
    final count = sessions.length;
    final label = count == 1 ? '1 session' : '$count sessions';
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: expanded ? 'Hide $label' : 'Show $label',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 2, 2, 2),
              decoration: BoxDecoration(
                color: AppColors.claudeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/claude.svg',
                    width: 10,
                    height: 10,
                    colorFilter: ColorFilter.mode(
                      AppColors.claude,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.claude,
                    ),
                  ),
                  if (anyOpen) ...[
                    const SizedBox(width: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 13,
                    color: AppColors.claude,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A list row's [sessions] in [repo], one line each below the row. Clicking
/// an open one shows it; a closed one offers to reopen or archive it.
class SessionList extends StatelessWidget {
  const SessionList({super.key, required this.repo, required this.sessions});

  final RepoConfig repo;
  final List<PageSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final session in sessions)
          _SessionLine(repo: repo, session: session),
      ],
    );
  }
}

class _SessionLine extends StatefulWidget {
  const _SessionLine({required this.repo, required this.session});

  final RepoConfig repo;
  final PageSession session;

  @override
  State<_SessionLine> createState() => _SessionLineState();
}

class _SessionLineState extends State<_SessionLine> {
  bool _hovered = false;

  PageSession get _session => widget.session;

  bool get _isOpen => sessionIsOpen(
    Provider.of<TerminalController?>(context, listen: false),
    _session,
  );

  /// Shows the open session; offers the menu for a closed one.
  void _onTap(Offset position) {
    if (_isOpen) {
      _show();
    } else {
      _showMenu(position);
    }
  }

  /// Shows the session, or starts a terminal that resumes it.
  Future<void> _show() async {
    if (_session.run case final run?) {
      await context.read<AgentLauncher>().resume(run);
    } else {
      await context.read<ClaudeSessionLauncher>().resume(
        repoPath: widget.repo.path,
        worktreePath: _session.path!,
      );
    }
  }

  /// Archives an agent run, or drops a plain session's shortcut. An agent
  /// that owns its worktree takes the worktree's shortcut with it, or the
  /// shortcut would take its place in the list.
  Future<void> _archive() async {
    final workspace = context.read<WorkspaceController>();
    final run = _session.run;
    if (run == null) {
      await workspace.forgetClaudeSession(widget.repo.path, _session.path!);
      return;
    }
    final ownsWorktree = agentTypeOf(
      context,
      run.kind,
      listen: false,
    ).ownsWorktree;
    await context.read<AgentsController>().setArchived(run.id, true);
    final path = run.worktreePath;
    if (ownsWorktree &&
        path != null &&
        workspace.metadata[path]?.session != null) {
      await workspace.forgetClaudeSession(widget.repo.path, path);
    }
  }

  Future<void> _showMenu(Offset position) async {
    final open = _isOpen;
    final action = await showMenu<String>(
      context: context,
      color: AppColors.surface1,
      constraints: const BoxConstraints(minWidth: 160),
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
        open
            ? _menuItem('show', Icons.open_in_new_rounded, 'Show')
            : _menuItem('reopen', Icons.replay_rounded, 'Reopen'),
        _menuItem('archive', Icons.archive_outlined, 'Archive'),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'show' || 'reopen':
        await _show();
      case 'archive':
        await _archive();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final terminal = Provider.of<TerminalController?>(context);
    final agents = Provider.of<AgentsController?>(context);
    final open = sessionIsOpen(terminal, _session);
    final run = _session.run;
    final path = run?.worktreePath ?? _session.path;
    final type = run == null ? null : agentTypeOf(context, run.kind);

    final String label;
    final ({String label, Color color}) status;
    if (run != null) {
      label = run.title ?? run.promptName ?? type!.label;
      final style = agentStatusStyle(
        run,
        agents?.livenessOf(run.id) ?? AgentLiveness.none,
      );
      status = (label: style.label, color: style.color);
    } else {
      label = p.basename(_session.path!);
      status = open
          ? (label: 'Open', color: AppColors.success)
          : (label: 'Closed', color: AppColors.textMuted);
    }
    final started = _session.startedAt.millisecondsSinceEpoch == 0
        ? null
        : _session.startedAt;
    final iconColor = open ? AppColors.claude : AppColors.textMuted;

    return Tooltip(
      message: [
        ?path,
        open ? 'Open — click to show' : 'Closed — click to reopen or archive',
      ].join('\n'),
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapUp: (d) => _onTap(d.globalPosition),
          onSecondaryTapDown: (d) => _showMenu(d.globalPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: type != null
                      ? Icon(type.iconData, size: 13, color: iconColor)
                      : SvgPicture.asset(
                          'assets/icons/claude.svg',
                          width: 12,
                          height: 12,
                          colorFilter: ColorFilter.mode(
                            iconColor,
                            BlendMode.srcIn,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (type != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: type.colorValue,
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: status.color,
                        ),
                      ),
                      if (open) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (started != null)
                  Tooltip(
                    message: 'Started ${formatAbsoluteTime(started)}',
                    child: Text(
                      formatRelativeTime(started),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
