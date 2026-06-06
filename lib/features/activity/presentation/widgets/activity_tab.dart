import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/features/activity/domain/activity_filter.dart';
import 'package:tree_launcher/features/activity/presentation/controllers/activity_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart'
    show JiraBadge;
import 'package:tree_launcher/theme/app_theme.dart';

/// Timeline of worktree activity: when each worktree (issue) was created and
/// closed, plus which days Claude Code was active in it.
class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  String? _lastSignature;

  /// Identifies the current repo + its worktree set, so the timeline reloads
  /// when a worktree is created or closed while this tab is already open.
  String _signatureFor(WorkspaceController workspace) {
    final paths = workspace.worktrees.map((w) => w.path).toList()..sort();
    return '${workspace.selectedRepo?.path ?? ''}::${paths.join('|')}';
  }

  void _loadIfNeeded(WorkspaceController workspace) {
    final signature = _signatureFor(workspace);
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    final worktrees = workspace.worktrees;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ActivityController>().load(currentWorktrees: worktrees);
      }
    });
  }

  Future<void> _refresh() async {
    final workspace = context.read<WorkspaceController>();
    await context.read<ActivityController>().load(
      currentWorktrees: workspace.worktrees,
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    _loadIfNeeded(workspace);
    final controller = context.watch<ActivityController>();

    if (controller.loading && controller.entries.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (controller.entries.isEmpty) {
      return _EmptyState(onRefresh: _refresh);
    }

    final filtered = controller.filteredEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterBar(
          selected: controller.filter,
          onSelected: controller.setFilter,
        ),
        Expanded(
          child: filtered.isEmpty
              ? _NoMatchesState(filter: controller.filter)
              : _ActivityTable(entries: filtered, onRefresh: _refresh),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final ActivityFilter selected;
  final ValueChanged<ActivityFilter> onSelected;
  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in ActivityFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: filter.label,
                  selected: filter == selected,
                  onTap: () => onSelected(filter),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoMatchesState extends StatelessWidget {
  final ActivityFilter filter;
  const _NoMatchesState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_list_off_rounded,
            size: 32,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            'No activity for "${filter.label}"',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No activity yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 320,
            child: Text(
              'Worktrees you create and close will be logged here, along with '
              'the days you worked in them via Claude Code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRefresh,
            icon: Icon(Icons.refresh_rounded, size: 16, color: AppColors.accent),
            label: Text(
              'Refresh',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared column layout so the header and every row line up. Mirrors the house
/// style established in worktree_table.dart.
const double _kIssueWidth = 110;
const double _kStatusWidth = 76;
const double _kDateWidth = 116;
const double _kActiveWidth = 110;
const double _kColumnGap = 16;
const int _kNameFlex = 3;
const int _kBranchFlex = 3;

/// Width breakpoints for responsive column hiding. Branch is the least
/// essential, so it drops first; the Closed date drops next on very narrow
/// widths. Issue/Worktree/Status/Created/Active are always visible.
const double _kHideBranchBelow = 900;
const double _kHideClosedBelow = 720;

/// Compact table of activity entries — one row per worktree, newest first.
class _ActivityTable extends StatelessWidget {
  final List<ActivityEntry> entries;
  final Future<void> Function() onRefresh;

  const _ActivityTable({required this.entries, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showBranch = constraints.maxWidth >= _kHideBranchBelow;
        final showClosed = constraints.maxWidth >= _kHideClosedBelow;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderRow(showBranch: showBranch, showClosed: showClosed),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.surface1,
                onRefresh: onRefresh,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: entries.length,
                  itemBuilder: (context, index) => _ActivityRow(
                    entry: entries[index],
                    showBranch: showBranch,
                    showClosed: showClosed,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool showBranch;
  final bool showClosed;

  const _HeaderRow({required this.showBranch, required this.showClosed});

  Widget _label(String text, {Alignment align = Alignment.centerLeft}) => Align(
    alignment: align,
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.6,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(width: _kIssueWidth, child: _label('Issue')),
          const SizedBox(width: _kColumnGap),
          Expanded(flex: _kNameFlex, child: _label('Worktree')),
          if (showBranch) ...[
            const SizedBox(width: _kColumnGap),
            Expanded(flex: _kBranchFlex, child: _label('Branch')),
          ],
          const SizedBox(width: _kColumnGap),
          SizedBox(width: _kStatusWidth, child: _label('Status')),
          const SizedBox(width: _kColumnGap),
          SizedBox(width: _kDateWidth, child: _label('Created')),
          if (showClosed) ...[
            const SizedBox(width: _kColumnGap),
            SizedBox(width: _kDateWidth, child: _label('Closed')),
          ],
          const SizedBox(width: _kColumnGap),
          SizedBox(
            width: _kActiveWidth,
            child: _label('Active', align: Alignment.centerRight),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatefulWidget {
  final ActivityEntry entry;
  final bool showBranch;
  final bool showClosed;

  const _ActivityRow({
    required this.entry,
    required this.showBranch,
    required this.showClosed,
  });

  @override
  State<_ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<_ActivityRow> {
  bool _hovered = false;

  Widget _dateCell(DateTime? date) {
    if (date == null) {
      return Text(
        '—',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }
    return Tooltip(
      message: _formatDate(date),
      child: Text(
        _formatDateCol(date),
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surface2 : Colors.transparent,
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Row(
          children: [
            // Issue
            SizedBox(
              width: _kIssueWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: entry.jiraIssue != null
                    ? JiraBadge(issueKey: entry.jiraIssue!, compact: true)
                    : Text(
                        '—',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: _kColumnGap),

            // Worktree name
            Expanded(
              flex: _kNameFlex,
              child: Text(
                entry.worktreeName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Branch
            if (widget.showBranch) ...[
              const SizedBox(width: _kColumnGap),
              Expanded(
                flex: _kBranchFlex,
                child: entry.branch != null
                    ? Text(
                        entry.branch!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        '—',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ],
            const SizedBox(width: _kColumnGap),

            // Status
            SizedBox(
              width: _kStatusWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusPill(isOpen: entry.isOpen),
              ),
            ),
            const SizedBox(width: _kColumnGap),

            // Created
            SizedBox(width: _kDateWidth, child: _dateCell(entry.createdAt)),

            // Closed
            if (widget.showClosed) ...[
              const SizedBox(width: _kColumnGap),
              SizedBox(width: _kDateWidth, child: _dateCell(entry.closedAt)),
            ],
            const SizedBox(width: _kColumnGap),

            // Active days
            SizedBox(
              width: _kActiveWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: _ActiveDaysBadge(days: entry.activeDays),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isOpen;
  const _StatusPill({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Compact "N days" badge for the Active column. The full list of active days
/// (most recent first) is revealed on hover via a tooltip, keeping rows to a
/// uniform single-line height.
class _ActiveDaysBadge extends StatelessWidget {
  final List<DateTime> days;
  const _ActiveDaysBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Text(
        '—',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }
    final ordered = days.reversed.toList(); // most recent first
    final tooltip = ordered.map(_formatDayShort).join(', ');
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.claudeBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 12, color: AppColors.claude),
            const SizedBox(width: 4),
            Text(
              '${days.length} ${days.length == 1 ? 'day' : 'days'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.claude,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $h:$m';
}

String _formatDayShort(DateTime d) {
  return '${d.day} ${_months[d.month - 1]}';
}

String _formatDateCol(DateTime d) {
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}
