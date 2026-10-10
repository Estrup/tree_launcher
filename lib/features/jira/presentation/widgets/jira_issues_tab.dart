import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/design_system/selection_controls.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_issues_controller.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_status_menu.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_styles.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_tags.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/models/jira_tag.dart';

/// Shared column widths so the header lines up with every row.
const double _kTypeWidth = 22;
const double _kKeyWidth = 120;
const double _kStatusWidth = 150;
const double _kAssigneeWidth = 160;
const double _kActionsWidth = 132;
const double _kColumnGap = 12;

/// Room the summary keeps before the assignee column is dropped in a narrow
/// window.
const double _kSummaryMinWidth = 180;

/// Width of the list's padding and of every column but the summary and the
/// assignee.
const double _kFixedListWidth =
    2 * 24 + // list padding
    2 * 14 + // row padding
    selectCheckboxSize +
    _kColumnGap +
    _kTypeWidth +
    _kColumnGap +
    _kKeyWidth +
    _kColumnGap +
    _kColumnGap +
    _kStatusWidth +
    _kColumnGap +
    _kActionsWidth;

/// Lists the selected repo's Jira issues for one fixVersion, or the issues a
/// search by key or text finds, with a status filter and per-issue buttons that open New Worktree prefilled, start a
/// Claude session for the issue, change its status or assign it to me.
/// Selected issues can have their status changed together. Issues can also
/// get the user's own tags (from Settings), kept only on this Mac.
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
        // Header: fixVersion picker, search, count, refresh
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _VersionPicker(
                versions: jira.versions,
                selected: jira.selectedVersion,
                onSelected: jira.selectVersion,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: _SearchField(
                    query: jira.searchQuery,
                    onSearch: jira.search,
                  ),
                ),
              ),
              if (jira.issues.isNotEmpty) ...[
                const SizedBox(width: 10),
                _CountBadge(
                  text: [
                    if (jira.statusFilter.isNotEmpty) '${visible.length}',
                    '${jira.issues.length}${jira.searchTruncated ? '+' : ''}',
                  ].join(' / '),
                  tooltip: jira.searchTruncated
                      ? 'Showing the ${JiraIssuesController.searchLimit} most '
                            'recently updated matches'
                      : null,
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
                    color: jiraStatusColor(status.category),
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
                        text: jira.isSearching && jira.issues.isEmpty
                            ? 'No issues match "${jira.searchQuery}"'
                            : jira.selectedVersion == null && !jira.isSearching
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
                        constraints.maxWidth >=
                        _kFixedListWidth +
                            _kSummaryMinWidth +
                            _kColumnGap +
                            _kAssigneeWidth,
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
    final jira = context.watch<JiraIssuesController>();
    final settings = context.watch<SettingsController>();
    final selected = jira.selectedKeys;
    final selectionActive = selected.isNotEmpty;
    final allSelected = visible.every((i) => selected.contains(i.key));
    return Column(
      children: [
        if (selectionActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: _BulkBar(issues: jira.selectedIssues),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _HeaderRow(
            showAssignee: showAssignee,
            selectAllState: !selectionActive
                ? false
                : (allSelected ? true : null),
            onToggleSelectAll: jira.toggleSelectAll,
          ),
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
                tags: settings.settings.tagsFor(issue.key),
                allTags: settings.settings.jiraTags,
                onTagChanged: (tagId, tagged) =>
                    settings.setJiraTag(issue.key, tagId, tagged),
                selected: selected.contains(issue.key),
                selectionActive: selectionActive,
                assignedToMe:
                    issue.assignee != null &&
                    issue.assignee == jira.myDisplayName,
                onSelectedChanged: (value) =>
                    jira.setSelected(issue.key, value),
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

/// Searches for an issue key or text: as you type (after a pause), or at once
/// on Enter. Clearing it, or Escape, goes back to the fixVersion's issues.
class _SearchField extends StatefulWidget {
  /// The controller's query; the field follows it when it's cleared from
  /// outside (a fixVersion picked, another repo selected).
  final String query;
  final ValueChanged<String> onSearch;

  const _SearchField({required this.query, required this.onSearch});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  static const _pause = Duration(milliseconds: 400);

  late final _text = TextEditingController(text: widget.query);
  Timer? _timer;

  @override
  void didUpdateWidget(_SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query &&
        widget.query != _text.text.trim() &&
        !(_timer?.isActive ?? false)) {
      _text.text = widget.query;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {}); // Shows or hides the clear button.
    _timer?.cancel();
    _timer = Timer(_pause, () => widget.onSearch(value));
  }

  void _submit(String value) {
    _timer?.cancel();
    widget.onSearch(value);
  }

  void _clear() {
    _text.clear();
    _submit('');
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clear},
      child: TextField(
        controller: _text,
        onChanged: _changed,
        onSubmitted: _submit,
        style: appFormFieldTextStyle(context),
        decoration: InputDecoration(
          hintText: 'Search key or text',
          prefixIcon: Icon(Icons.search, size: 16, color: AppColors.textMuted),
          suffixIcon: _text.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: _clear,
                ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool showAssignee;

  /// The select-all checkbox: all, none, or (null) some selected.
  final bool? selectAllState;
  final VoidCallback onToggleSelectAll;

  const _HeaderRow({
    required this.showAssignee,
    required this.selectAllState,
    required this.onToggleSelectAll,
  });

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
          Tooltip(
            message: 'Select all',
            child: SelectCheckbox(
              value: selectAllState,
              // Always shown, so all issues can be selected at once.
              visible: true,
              onTap: onToggleSelectAll,
            ),
          ),
          const SizedBox(width: _kColumnGap),
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

class _IssueRow extends StatefulWidget {
  final JiraIssue issue;
  final Worktree? worktree;
  final bool showAssignee;

  /// The issue's tags, and every tag (none hides tagging).
  final List<JiraTag> tags;
  final List<JiraTag> allTags;
  final void Function(String tagId, bool tagged) onTagChanged;
  final bool selected;

  /// Whether any issue is selected, which keeps every checkbox shown.
  final bool selectionActive;
  final bool assignedToMe;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onCreateWorktree;
  final VoidCallback onStartClaude;

  const _IssueRow({
    required this.issue,
    required this.worktree,
    required this.showAssignee,
    required this.tags,
    required this.allTags,
    required this.onTagChanged,
    required this.selected,
    required this.selectionActive,
    required this.assignedToMe,
    required this.onSelectedChanged,
    required this.onCreateWorktree,
    required this.onStartClaude,
  });

  @override
  State<_IssueRow> createState() => _IssueRowState();
}

class _IssueRowState extends State<_IssueRow> {
  bool _hovered = false;
  bool _changingStatus = false;
  bool _assigning = false;

  /// Offers the issue's status changes below its status pill
  /// ([pillContext]) and applies the one picked.
  Future<void> _changeStatus(BuildContext pillContext) async {
    if (_changingStatus) return;
    final jira = context.read<JiraIssuesController>();
    final key = widget.issue.key;
    setState(() => _changingStatus = true);
    try {
      final moves = await jira.statusMovesFor([key]);
      if (!mounted || !pillContext.mounted) return;
      if (moves.isEmpty) {
        showAppSnackBar('No status changes are available for $key.');
        return;
      }
      setState(() => _changingStatus = false);
      final move = await showJiraStatusMenu(pillContext, moves, issueCount: 1);
      if (move == null || !mounted) return;
      setState(() => _changingStatus = true);
      final failures = await jira.applyStatusMove(move);
      final reason = failures[key];
      if (reason != null) showAppSnackBar('$key: $reason');
    } catch (e) {
      showAppSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
  }

  Future<void> _assignToMe() async {
    if (_assigning) return;
    final jira = context.read<JiraIssuesController>();
    setState(() => _assigning = true);
    try {
      await jira.assignToMe(widget.issue.key);
    } catch (e) {
      showAppSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final worktree = widget.worktree;
    final (typeIcon, typeColor) = jiraTypeIcon(issue.issueType);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: widget.selected ? AppColors.accentMuted : AppColors.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.selected
                ? AppColors.accent.withValues(alpha: 0.35)
                : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            SelectCheckbox(
              value: widget.selected,
              visible: _hovered || widget.selected || widget.selectionActive,
              onTap: () => widget.onSelectedChanged(!widget.selected),
            ),
            const SizedBox(width: _kColumnGap),
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
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Flexible(
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
                    if (widget.allTags.isNotEmpty)
                      // The summary keeps at least 40% of the cell.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.6,
                        ),
                        child: IssueTags(
                          tags: widget.tags,
                          allTags: widget.allTags,
                          showHint: _hovered,
                          onChanged: widget.onTagChanged,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: _kColumnGap),
            SizedBox(
              width: _kStatusWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Builder(
                  builder: (pillContext) => _StatusPill(
                    status: issue.status ?? '—',
                    category: issue.statusCategory,
                    busy: _changingStatus,
                    onTap: () => _changeStatus(pillContext),
                  ),
                ),
              ),
            ),
            if (widget.showAssignee) ...[
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
                      message: 'Worktree: ${worktree.name}',
                      child: Icon(
                        Icons.account_tree_rounded,
                        size: 15,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!widget.assignedToMe) ...[
                    Tooltip(
                      message: 'Assign to me',
                      child: _assigning
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              ),
                            )
                          : ActionButton(
                              compact: true,
                              icon: Icons.person_add_alt_1_rounded,
                              color: AppColors.accent,
                              bgColor: AppColors.accentMuted,
                              onPressed: _assignToMe,
                            ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Tooltip(
                    message: 'Claude session for ${issue.key}…',
                    child: ActionButton(
                      compact: true,
                      svgAsset: 'assets/icons/claude.svg',
                      color: AppColors.claude,
                      bgColor: AppColors.claudeBg,
                      onPressed: widget.onStartClaude,
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
                      onPressed: widget.onCreateWorktree,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An issue's status, as a button that opens its status menu.
class _StatusPill extends StatefulWidget {
  final String status;
  final String? category;
  final bool busy;
  final VoidCallback onTap;

  const _StatusPill({
    required this.status,
    required this.category,
    required this.busy,
    required this.onTap,
  });

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = jiraStatusColor(widget.category);
    return Tooltip(
      message: 'Change status',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.busy ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: _hovered ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: _hovered ? 0.5 : 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.status,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: widget.busy
                      ? Padding(
                          padding: const EdgeInsets.all(2),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: color,
                          ),
                        )
                      : Icon(Icons.expand_more_rounded, size: 14, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown above the list while issues are selected: how many, changing their
/// status together, and clearing the selection.
class _BulkBar extends StatefulWidget {
  final List<JiraIssue> issues;

  const _BulkBar({required this.issues});

  @override
  State<_BulkBar> createState() => _BulkBarState();
}

class _BulkBarState extends State<_BulkBar> {
  bool _busy = false;

  Future<void> _changeStatus(BuildContext buttonContext) async {
    if (_busy) return;
    final jira = context.read<JiraIssuesController>();
    final keys = widget.issues.map((i) => i.key).toList();
    setState(() => _busy = true);
    try {
      final moves = await jira.statusMovesFor(keys);
      if (!mounted || !buttonContext.mounted) return;
      if (moves.isEmpty) {
        showAppSnackBar('No status changes are available for these issues.');
        return;
      }
      setState(() => _busy = false);
      final move = await showJiraStatusMenu(
        buttonContext,
        moves,
        issueCount: keys.length,
      );
      if (move == null || !mounted) return;
      setState(() => _busy = true);
      final failures = await jira.applyStatusMove(move);
      showAppSnackBar(bulkMoveSummary(move, keys.length, failures));
      // Leave the issues that didn't move selected, to retry or handle.
      jira.clearSelection();
      for (final key in keys) {
        if (failures.containsKey(key) || !move.transitions.containsKey(key)) {
          jira.setSelected(key, true);
        }
      }
    } catch (e) {
      showAppSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jira = context.read<JiraIssuesController>();
    final count = widget.issues.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Text(
            '$count selected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Builder(
            builder: (buttonContext) => BulkBarButton(
              icon: Icons.swap_horiz_rounded,
              label: 'Change status',
              busy: _busy,
              onTap: _busy || count == 0
                  ? null
                  : () => _changeStatus(buttonContext),
            ),
          ),
          const SizedBox(width: 8),
          BulkBarButton(
            icon: Icons.close_rounded,
            label: 'Clear',
            onTap: jira.clearSelection,
          ),
        ],
      ),
    );
  }
}

/// What a status change on [total] selected issues did, e.g. "Moved 3 of 5
/// issues to Done. AU2-4: Resolution is required. 1 can't move to Done."
@visibleForTesting
String bulkMoveSummary(
  JiraStatusMove move,
  int total,
  Map<String, String> failures,
) {
  final moved = move.transitions.length - failures.length;
  final issues = total == 1 ? 'issue' : 'issues';
  final parts = [
    moved == total
        ? 'Moved $total $issues to ${move.toStatus}.'
        : 'Moved $moved of $total $issues to ${move.toStatus}.',
    for (final MapEntry(key: key, value: reason) in failures.entries.take(2))
      '$key: $reason',
    if (failures.length > 2) '${failures.length - 2} more failed.',
  ];
  final unavailable = total - move.transitions.length;
  if (unavailable > 0) {
    parts.add("$unavailable can't move to ${move.toStatus}.");
  }
  return parts.join(' ');
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
  final String? tooltip;

  const _CountBadge({required this.text, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
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
    return tooltip == null ? badge : Tooltip(message: tooltip, child: badge);
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
