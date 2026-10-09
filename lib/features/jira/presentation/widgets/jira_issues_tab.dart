import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_issues_controller.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';

/// Shared column widths so the header lines up with every row.
const double _kTypeWidth = 22;
const double _kKeyWidth = 120;
const double _kStatusWidth = 150;
const double _kAssigneeWidth = 160;
const double _kActionsWidth = 98;
const double _kColumnGap = 12;

/// Below this list width the assignee column is dropped so the summary keeps
/// room in a narrow window.
const double _kAssigneeMinListWidth = 760;

/// Lists the selected repo's Jira issues for one fixVersion, with a status
/// filter and per-issue buttons that open New Worktree prefilled or start a
/// Claude session for the issue.
class JiraIssuesTab extends StatelessWidget {
  const JiraIssuesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final jira = context.watch<JiraIssuesController>();
    final worktrees = context.watch<WorkspaceController>().worktrees;

    if (jira.projectKey == null) {
      return _CenteredMessage(
        icon: Icons.confirmation_number_outlined,
        text: 'Set a Jira project key in repo settings',
      );
    }

    final worktreesByIssue = <String, Worktree>{
      for (final wt in worktrees)
        if (wt.jiraIssue != null) wt.jiraIssue!: wt,
    };
    final visible = jira.visibleIssues;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: fixVersion picker, count, refresh
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _VersionPicker(
                versions: jira.versions,
                selected: jira.selectedVersion,
                onSelected: jira.selectVersion,
              ),
              if (jira.issues.isNotEmpty) ...[
                const SizedBox(width: 10),
                _CountBadge(
                  text: jira.statusFilter.isEmpty
                      ? '${jira.issues.length}'
                      : '${visible.length} / ${jira.issues.length}',
                ),
              ],
              const Spacer(),
              if (jira.lastRefreshed != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    _formatLastRefreshed(jira.lastRefreshed!),
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
              if (jira.isLoading)
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
                  message: 'Refresh issues',
                  child: ActionButton(
                    compact: true,
                    icon: Icons.refresh,
                    color: AppColors.accent,
                    bgColor: AppColors.accentMuted,
                    onPressed: jira.refresh,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Status filter
        if (jira.issues.isNotEmpty || jira.statusFilter.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusChip(
                  label: 'All',
                  count: jira.issues.length,
                  color: AppColors.textSecondary,
                  selected: jira.statusFilter.isEmpty,
                  onTap: jira.clearStatusFilter,
                ),
                for (final status in jira.statusCounts)
                  _StatusChip(
                    label: status.name,
                    count: status.count,
                    color: _statusColor(status.category),
                    selected: jira.statusFilter.contains(status.name),
                    onTap: () => jira.toggleStatus(status.name),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        if (jira.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: _ErrorBanner(message: jira.error!),
          ),

        Expanded(
          child: visible.isEmpty
              ? (jira.isLoading
                    ? const SizedBox.shrink()
                    : jira.error != null
                    ? const SizedBox.shrink()
                    : _CenteredMessage(
                        icon: Icons.inbox_outlined,
                        text: jira.selectedVersion == null
                            ? 'No fixVersions in ${jira.projectKey}'
                            : jira.issues.isEmpty
                            ? 'No issues in ${jira.selectedVersion!.name}'
                            : 'No issues match the status filter',
                      ))
              : LayoutBuilder(
                  builder: (context, constraints) => _buildList(
                    context,
                    visible,
                    worktreesByIssue,
                    showAssignee:
                        constraints.maxWidth >= _kAssigneeMinListWidth,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    List<JiraIssue> visible,
    Map<String, Worktree> worktreesByIssue, {
    required bool showAssignee,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _HeaderRow(showAssignee: showAssignee),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final issue = visible[index];
              return _IssueRow(
                issue: issue,
                worktree: worktreesByIssue[issue.key],
                showAssignee: showAssignee,
                onCreateWorktree: () => AddWorktreeDialog.show(
                  context,
                  initialName: worktreeNameForJiraIssue(
                    issue.key,
                    issue.summary,
                  ),
                  initialJiraKey: issue.key,
                  contextTitle: issue.summary,
                ),
                onStartClaude: () => AddWorktreeDialog.startClaudeSession(
                  context,
                  existingWorktree: worktreesByIssue[issue.key],
                  initialName: worktreeNameForJiraIssue(
                    issue.key,
                    issue.summary,
                  ),
                  initialJiraKey: issue.key,
                  contextTitle: issue.summary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _formatLastRefreshed(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

/// Colour for a Jira status category (`new`, `indeterminate`, `done`).
Color _statusColor(String? category) {
  switch (category) {
    case 'done':
      return AppColors.success;
    case 'indeterminate':
      return AppColors.vscode;
    default:
      return AppColors.textSecondary;
  }
}

/// Icon and colour for an issue type name.
(IconData, Color) _typeIcon(String? type) {
  switch (type?.trim().toLowerCase()) {
    case 'bug':
      return (Icons.bug_report_rounded, AppColors.error);
    case 'story':
      return (Icons.bookmark_rounded, AppColors.success);
    case 'task':
      return (Icons.check_box_rounded, AppColors.vscode);
    case 'epic':
      return (Icons.bolt_rounded, AppColors.branch);
    case 'new feature':
      return (Icons.add_box_rounded, AppColors.success);
    case 'improvement':
      return (Icons.arrow_circle_up_rounded, AppColors.success);
    default:
      return (Icons.circle_outlined, AppColors.textMuted);
  }
}

class _VersionPicker extends StatelessWidget {
  final List<JiraVersion> versions;
  final JiraVersion? selected;
  final ValueChanged<JiraVersion> onSelected;

  const _VersionPicker({
    required this.versions,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<JiraVersion>(
      // Rebuilt when the selection changes from outside (repo switch, refresh)
      // so the field shows the current version.
      key: ValueKey(selected?.id),
      initialSelection: selected,
      enabled: versions.isNotEmpty,
      width: 300,
      menuHeight: 380,
      enableFilter: true,
      requestFocusOnTap: true,
      hintText: 'Select fixVersion',
      leadingIcon: Icon(
        Icons.flag_outlined,
        size: 16,
        color: AppColors.textMuted,
      ),
      textStyle: appFormFieldTextStyle(context),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surface1),
      ),
      dropdownMenuEntries: [
        for (final version in versions)
          DropdownMenuEntry(
            value: version,
            label: version.name,
            trailingIcon: version.released
                ? Text(
                    'released',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  )
                : null,
          ),
      ],
      onSelected: (version) {
        if (version != null) onSelected(version);
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool showAssignee;

  const _HeaderRow({required this.showAssignee});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 1.2,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const SizedBox(width: _kTypeWidth + _kColumnGap),
          SizedBox(
            width: _kKeyWidth,
            child: Text('KEY', style: style),
          ),
          const SizedBox(width: _kColumnGap),
          Expanded(child: Text('SUMMARY', style: style)),
          const SizedBox(width: _kColumnGap),
          SizedBox(
            width: _kStatusWidth,
            child: Text('STATUS', style: style),
          ),
          if (showAssignee) ...[
            const SizedBox(width: _kColumnGap),
            SizedBox(
              width: _kAssigneeWidth,
              child: Text('ASSIGNEE', style: style),
            ),
          ],
          const SizedBox(width: _kColumnGap + _kActionsWidth),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final JiraIssue issue;
  final Worktree? worktree;
  final bool showAssignee;
  final VoidCallback onCreateWorktree;
  final VoidCallback onStartClaude;

  const _IssueRow({
    required this.issue,
    required this.worktree,
    required this.showAssignee,
    required this.onCreateWorktree,
    required this.onStartClaude,
  });

  @override
  Widget build(BuildContext context) {
    final (typeIcon, typeColor) = _typeIcon(issue.issueType);
    final statusColor = _statusColor(issue.statusCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kTypeWidth,
            child: Tooltip(
              message: issue.issueType?.trim() ?? 'Unknown type',
              child: Icon(typeIcon, size: 16, color: typeColor),
            ),
          ),
          const SizedBox(width: _kColumnGap),
          SizedBox(
            width: _kKeyWidth,
            // Scales a long key down rather than overflowing the column.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: JiraBadge(issueKey: issue.key, compact: true),
            ),
          ),
          const SizedBox(width: _kColumnGap),
          Expanded(
            child: Tooltip(
              message: issue.summary,
              waitDuration: const Duration(milliseconds: 500),
              child: Text(
                issue.summary,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: _kColumnGap),
          SizedBox(
            width: _kStatusWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  issue.status ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ),
          if (showAssignee) ...[
            const SizedBox(width: _kColumnGap),
            SizedBox(
              width: _kAssigneeWidth,
              child: Text(
                issue.assignee ?? 'Unassigned',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: issue.assignee == null
                      ? AppColors.textMuted
                      : AppColors.textSecondary,
                  fontStyle: issue.assignee == null
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
          ],
          const SizedBox(width: _kColumnGap),
          SizedBox(
            width: _kActionsWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (worktree != null) ...[
                  Tooltip(
                    message: 'Worktree: ${worktree!.name}',
                    child: Icon(
                      Icons.account_tree_rounded,
                      size: 15,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Tooltip(
                  message: 'Claude session for ${issue.key}…',
                  child: ActionButton(
                    compact: true,
                    svgAsset: 'assets/icons/claude.svg',
                    color: AppColors.claude,
                    bgColor: AppColors.claudeBg,
                    onPressed: onStartClaude,
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Create worktree for ${issue.key}…',
                  child: ActionButton(
                    compact: true,
                    icon: Icons.add_rounded,
                    color: AppColors.terminal,
                    bgColor: AppColors.terminalBg,
                    onPressed: onCreateWorktree,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatefulWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final selected = widget.selected;
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
            color: selected
                ? color.withValues(alpha: 0.18)
                : _hovered
                ? AppColors.surface2
                : AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.5)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.count}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? color.withValues(alpha: 0.8)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String text;

  const _CountBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CenteredMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(color: AppColors.textMuted, fontSize: 17),
          ),
        ],
      ),
    );
  }
}
