import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_card.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/start_agent_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

enum _AgentFilter { active, finished, archived }

/// A repo tab listing its agents of one [kind]: those waiting for a human
/// first, then the running ones; finished and archived runs behind filters.
/// Starts new agents from the repo's prompts of that kind.
class AgentsTab extends StatefulWidget {
  const AgentsTab({super.key, required this.kind});

  final AgentKind kind;

  @override
  State<AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<AgentsTab> {
  _AgentFilter _filter = _AgentFilter.active;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<WorkspaceController>().selectedRepo;
    final agents = context.watch<AgentsController>();
    if (repo == null) return const SizedBox.shrink();
    final kind = widget.kind;
    final prompts = [
      for (final prompt in repo.claudePrompts)
        if (prompt.kind == kind) prompt,
    ];

    final all = agents.runsFor(repo.name, kind, includeArchived: true);
    final active = [
      for (final run in all)
        if (!run.archived && !run.state.isFinished) run,
    ];
    // Agents that need a human first; otherwise newest update first.
    active.sort((a, b) {
      final needs = (agents.needsYou(b) ? 1 : 0) - (agents.needsYou(a) ? 1 : 0);
      return needs != 0 ? needs : b.updatedAt.compareTo(a.updatedAt);
    });
    final finished = [
      for (final run in all)
        if (!run.archived && run.state.isFinished) run,
    ];
    final archived = [
      for (final run in all)
        if (run.archived) run,
    ];
    final visible = switch (_filter) {
      _AgentFilter.active => active,
      _AgentFilter.finished => finished,
      _AgentFilter.archived => archived,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _FilterChip(
                label: 'Active',
                count: active.length,
                selected: _filter == _AgentFilter.active,
                onTap: () => setState(() => _filter = _AgentFilter.active),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Finished',
                count: finished.length,
                selected: _filter == _AgentFilter.finished,
                onTap: () => setState(() => _filter = _AgentFilter.finished),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Archived',
                count: archived.length,
                selected: _filter == _AgentFilter.archived,
                onTap: () => setState(() => _filter = _AgentFilter.archived),
              ),
              const Spacer(),
              if (_filter == _AgentFilter.finished && finished.isNotEmpty) ...[
                TextButton(
                  onPressed: () async {
                    for (final run in finished) {
                      await agents.setArchived(run.id, true);
                    }
                  },
                  child: const Text('Archive all'),
                ),
                const SizedBox(width: 8),
              ],
              _NewAgentButton(kind: kind, prompts: prompts),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(
                  kind: kind,
                  filter: _filter,
                  hasPrompts: prompts.isNotEmpty,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final run = visible[index];
                    return AgentCard(key: ValueKey(run.id), run: run);
                  },
                ),
        ),
      ],
    );
  }
}

/// The "New … agent" button: starts one from a prompt of the tab's kind; with
/// several, a menu picks which.
class _NewAgentButton extends StatelessWidget {
  const _NewAgentButton({required this.kind, required this.prompts});

  final AgentKind kind;
  final List<ClaudePrompt> prompts;

  @override
  Widget build(BuildContext context) {
    final color = kind.color;
    final label = 'New ${kind.label.toLowerCase()} agent';
    final enabled = prompts.isNotEmpty;
    final button = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: enabled ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: enabled ? 0.35 : 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_rounded,
            size: 15,
            color: enabled ? color : AppColors.textMuted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled ? color : AppColors.textMuted,
            ),
          ),
          if (prompts.length > 1) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
          ],
        ],
      ),
    );

    if (!enabled) {
      return Tooltip(
        message:
            'Give a prompt the ${kind.label} kind in repo settings → Claude Prompts',
        child: button,
      );
    }
    if (prompts.length == 1) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () =>
              StartAgentDialog.show(context, kind: kind, prompt: prompts.first),
          child: button,
        ),
      );
    }
    return PopupMenuButton<ClaudePrompt>(
      tooltip: label,
      color: AppColors.surface1,
      position: PopupMenuPosition.under,
      onSelected: (prompt) =>
          StartAgentDialog.show(context, kind: kind, prompt: prompt),
      itemBuilder: (context) => [
        for (final prompt in prompts)
          PopupMenuItem(
            value: prompt,
            height: 36,
            child: Row(
              children: [
                Icon(kind.icon, size: 15, color: color),
                const SizedBox(width: 10),
                Text(
                  prompt.name,
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
      ],
      child: button,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.textPrimary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface2 : AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.border : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.kind,
    required this.filter,
    required this.hasPrompts,
  });

  final AgentKind kind;
  final _AgentFilter filter;
  final bool hasPrompts;

  @override
  Widget build(BuildContext context) {
    final noun = '${kind.label.toLowerCase()} agents';
    final (title, hint) = switch (filter) {
      _AgentFilter.active => (
        'No active $noun',
        hasPrompts
            ? 'Start one with "New ${kind.label.toLowerCase()} agent". Agents '
                  'started elsewhere show up here when they report in.'
            : 'Give a prompt the ${kind.label} kind in repo settings → '
                  'Claude Prompts to start agents from here.',
      ),
      _AgentFilter.finished => ('No finished $noun', null),
      _AgentFilter.archived => ('No archived $noun', null),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind.icon,
              size: 44,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Whether the selected repo shows [kind]'s tab: it has prompts of that kind,
/// or runs of it (agents that registered themselves).
bool showsAgentTab(
  String repoName,
  List<ClaudePrompt> prompts,
  AgentsController agents,
  AgentKind kind,
) => prompts.any((p) => p.kind == kind) || agents.hasRunsFor(repoName, kind);
