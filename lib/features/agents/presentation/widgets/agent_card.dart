import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/presentation/agent_launcher.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';

/// One agent run in an agent tab: what it is working on, its stages, its
/// latest message and links, and actions to open, resume, stop or archive
/// it. Expands to show its timeline.
class AgentCard extends StatefulWidget {
  const AgentCard({super.key, required this.run});

  final AgentRun run;

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard> {
  bool _expanded = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final agents = context.watch<AgentsController>();
    final run = widget.run;
    final liveness = agents.livenessOf(run.id);
    final status = agentStatusStyle(run, liveness);
    final needsYou = agents.needsYou(run);
    final subtitle = [
      if (run.worktreePath != null) p.basename(run.worktreePath!),
      if (run.prNumber != null) 'PR #${run.prNumber}',
      if (run.issueKeys.length > 1) '+${run.issueKeys.length - 1} issues',
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surface1 : AppColors.surface0,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: needsYou
                ? agentWaitingColor.withValues(alpha: 0.6)
                : AppColors.borderSubtle,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusPill(
                    label: status.label,
                    icon: status.icon,
                    color: status.color,
                  ),
                  if (run.issueKey != null) ...[
                    const SizedBox(width: 10),
                    JiraBadge(issueKey: run.issueKey!, compact: true),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      run.title ?? run.promptName ?? run.kind.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Started ${_formatTime(run.startedAt)}',
                    child: Text(
                      _formatRelative(run.updatedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (run.promptName != null) ...[
                    Icon(run.kind.icon, size: 12, color: run.kind.color),
                    const SizedBox(width: 4),
                    Text(
                      run.promptName!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: run.kind.color,
                      ),
                    ),
                    if (subtitle.isNotEmpty) const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      subtitle.join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (run.stages.isNotEmpty) ...[
                const SizedBox(height: 10),
                _StageStrip(stages: run.stages, current: run.currentStage),
              ],
              if (run.summary != null) ...[
                const SizedBox(height: 10),
                Text(
                  run.summary!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (run.result != null && run.state.isFinished) ...[
                const SizedBox(height: 6),
                Text(
                  'Result: ${run.result}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: status.color,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final link in run.links)
                          _LinkChip(link: link, worktreePath: run.worktreePath),
                      ],
                    ),
                  ),
                  _Actions(
                    run: run,
                    liveness: liveness,
                    expanded: _expanded,
                    onToggleTimeline: () =>
                        setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                _Timeline(events: agents.eventsFor(run.id)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The run's stages in order: `✓ spec · ✓ plan · ◔ implement 4/7 · ○ review`.
class _StageStrip extends StatelessWidget {
  const _StageStrip({required this.stages, required this.current});

  final List<AgentStage> stages;
  final String? current;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final stage in stages)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                agentStageStyle(stage.state).icon,
                size: 14,
                color: agentStageStyle(stage.state).color,
              ),
              const SizedBox(width: 4),
              Text(
                [
                  stage.name,
                  if (stage.progressDone != null && stage.progressTotal != null)
                    '${stage.progressDone}/${stage.progressTotal}'
                  else if (stage.progressDone != null)
                    '${stage.progressDone}',
                ].join(' '),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: stage.name == current
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: stage.state == AgentStageState.pending
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.link, required this.worktreePath});

  final AgentLink link;
  final String? worktreePath;

  String get _target => link.isUrl || p.isAbsolute(link.target)
      ? link.target
      : p.join(worktreePath ?? '', link.target);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _target,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => link.isUrl
              ? Process.run('open', [_target])
              : LauncherService().openVSCode(_target),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  link.isUrl ? Icons.link_rounded : Icons.description_outlined,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  link.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _Actions extends StatelessWidget {
  const _Actions({
    required this.run,
    required this.liveness,
    required this.expanded,
    required this.onToggleTimeline,
  });

  final AgentRun run;
  final AgentLiveness liveness;
  final bool expanded;
  final VoidCallback onToggleTimeline;

  @override
  Widget build(BuildContext context) {
    final open = liveness != AgentLiveness.none;
    final canResume = !open && run.worktreePath != null && !run.archived;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (open)
          _ActionChip(
            label: 'Open',
            icon: Icons.terminal_rounded,
            color: AppColors.terminal,
            onTap: () => AgentLauncher.of(context).focus(run),
          )
        else if (canResume)
          _ActionChip(
            label: run.state.isFinished ? 'Reopen' : 'Resume',
            icon: Icons.play_arrow_rounded,
            color: AppColors.terminal,
            onTap: () => AgentLauncher.of(context).resume(run),
          ),
        const SizedBox(width: 4),
        _IconAction(
          tooltip: expanded ? 'Hide timeline' : 'Show timeline',
          icon: expanded
              ? Icons.expand_less_rounded
              : Icons.format_list_bulleted_rounded,
          onTap: onToggleTimeline,
        ),
        _MoreMenu(run: run, open: open),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.run, required this.open});

  final AgentRun run;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final agents = context.read<AgentsController>();
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: AppColors.textMuted,
      ),
      color: AppColors.surface1,
      onSelected: (value) async {
        switch (value) {
          case 'stop':
            await AgentLauncher.of(context).stop(run);
          case 'archive':
            await agents.setArchived(run.id, true);
          case 'unarchive':
            await agents.setArchived(run.id, false);
          case 'delete':
            await agents.delete(run.id);
        }
      },
      itemBuilder: (context) => [
        if (open || !run.state.isFinished)
          _menuItem('stop', Icons.stop_rounded, 'Stop agent'),
        if (run.archived) ...[
          _menuItem('unarchive', Icons.unarchive_outlined, 'Unarchive'),
          _menuItem('delete', Icons.delete_outline_rounded, 'Delete'),
        ] else
          _menuItem('archive', Icons.archive_outlined, 'Archive'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text) =>
      PopupMenuItem(
        value: value,
        height: 36,
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
      );
}

class _ActionChip extends StatefulWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _hovered ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.textMuted),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<AgentEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        'Nothing reported yet.',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        reverse: true,
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[events.length - 1 - index];
          final style = _levelStyle(event.level);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    _formatClock(event.at),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 6),
                  child: Icon(style.icon, size: 12, color: style.color),
                ),
                if (event.stage != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      event.stage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Expanded(
                  child: SelectableText(
                    event.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static ({IconData icon, Color color}) _levelStyle(AgentEventLevel level) =>
      switch (level) {
        AgentEventLevel.info => (
          icon: Icons.circle,
          color: AppColors.textMuted,
        ),
        AgentEventLevel.success => (
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        ),
        AgentEventLevel.warning => (
          icon: Icons.warning_amber_rounded,
          color: agentWaitingColor,
        ),
        AgentEventLevel.error => (
          icon: Icons.cancel_rounded,
          color: AppColors.error,
        ),
        AgentEventLevel.action => (
          icon: Icons.pause_circle_filled_rounded,
          color: agentWaitingColor,
        ),
      };
}

String _two(int n) => n.toString().padLeft(2, '0');

String _formatClock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

String _formatTime(DateTime time) =>
    '${time.year}-${_two(time.month)}-${_two(time.day)} ${_formatClock(time)}';

String _formatRelative(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.day}/${time.month}';
}
