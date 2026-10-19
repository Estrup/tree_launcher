import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/design_system/selection_controls.dart';
import 'package:tree_launcher/core/widgets/issue_list.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_issues/domain/github_milestone.dart';
import 'package:tree_launcher/features/github_issues/presentation/controllers/github_issues_controller.dart';
import 'package:tree_launcher/features/github_issues/presentation/github_issue_actions.dart';
import 'package:tree_launcher/features/github_issues/presentation/widgets/github_issue_dialog.dart';
import 'package:tree_launcher/features/github_issues/presentation/widgets/github_issue_styles.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/github_prs/presentation/widgets/github_styles.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_tags.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/models/jira_tag.dart';

/// Shared column widths so the header lines up with every row.
const double _kStateIconWidth = 22;
const double _kNumberWidth = 72;
const double _kStateWidth = 130;
const double _kAssigneeWidth = 160;
const double _kActionsWidth = 166;
const double _kColumnGap = 12;

/// Room the title keeps before the assignee column is dropped in a narrow
/// window.
const double _kTitleMinWidth = 180;

/// Width of the list's padding and of every column but the title and the
/// assignees.
const double _kFixedListWidth =
    2 * 24 + // list padding
    2 * 14 + // row padding
    selectCheckboxSize +
    _kColumnGap +
    _kStateIconWidth +
    _kColumnGap +
    _kNumberWidth +
    _kColumnGap +
    _kColumnGap +
    _kStateWidth +
    _kColumnGap +
    _kActionsWidth;

/// Lists the selected repo's GitHub issues for one milestone (or every open
/// issue), or the issues a search finds, with state and label filters and
/// per-issue buttons that open the issue in a dialog or on github.com, open
/// New Worktree prefilled, start a Claude session for it, change its state or
/// assign it to me. Selected issues can have their state changed together,
/// and issues can get the user's own tags (shared with Jira issues).
class GithubIssuesTab extends StatelessWidget {
  const GithubIssuesTab({super.key, this.openUrl = openInBrowser});

  /// Opens an issue on github.com.
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final issues = context.watch<GithubIssuesController>();
    final worktrees = context.watch<WorkspaceController>().worktrees;
    final config = issues.config;

    if (config == null) {
      return const IssueCenteredMessage(
        icon: Icons.adjust_rounded,
        text: 'Turn on GitHub issues in repo settings',
      );
    }

    final worktreesByIssue = <int, Worktree>{
      for (final wt in worktrees)
        if (wt.githubIssue != null) wt.githubIssue!: wt,
    };
    final visible = issues.visibleIssues;
    final milestone = issues.selectedMilestone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: milestone picker, search, count, refresh
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _MilestonePicker(
                // Rebuilt when the selection changes from outside (repo
                // switch, refresh, a rename on GitHub) so the field shows the
                // current milestone's title.
                key: ValueKey((
                  issues.selectedMilestoneNumber,
                  milestone?.title,
                )),
                milestones: issues.milestones,
                selectedNumber: issues.selectedMilestoneNumber,
                onSelected: issues.selectMilestone,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: IssueSearchField(
                    query: issues.searchQuery,
                    onSearch: issues.search,
                    hintText: 'Search number or text',
                  ),
                ),
              ),
              if (issues.issues.isNotEmpty) ...[
                const SizedBox(width: 10),
                IssueCountBadge(
                  text: [
                    if (issues.hasFilter) '${visible.length}',
                    '${issues.issues.length}${issues.truncated ? '+' : ''}',
                  ].join(' / '),
                  tooltip: !issues.truncated
                      ? null
                      : issues.isSearching
                      ? 'Showing the ${GithubIssuesController.searchLimit} '
                            'most recently updated matches'
                      : 'Showing the ${issues.issues.length} most recently '
                            'updated issues',
                ),
              ],
              const Spacer(),
              if (issues.lastRefreshed != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    formatLastRefreshed(issues.lastRefreshed!),
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
              if (issues.isLoading)
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
                    onPressed: issues.refresh,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // State and label filters
        if (issues.issues.isNotEmpty || issues.hasFilter)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _FilterChips(controller: issues),
          ),
        const SizedBox(height: 12),

        if (issues.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: IssueErrorBanner(message: issues.error!),
          ),

        Expanded(
          child: visible.isEmpty
              ? (issues.isLoading || issues.error != null
                    ? const SizedBox.shrink()
                    : IssueCenteredMessage(
                        icon: Icons.inbox_outlined,
                        text: issues.isSearching && issues.issues.isEmpty
                            ? 'No issues match "${issues.searchQuery}"'
                            : issues.issues.isEmpty && milestone == null
                            ? 'No open issues in ${config.owner}/${config.repo}'
                            : issues.issues.isEmpty
                            ? 'No issues in ${milestone!.title}'
                            : 'No issues match the filter',
                      ))
              : LayoutBuilder(
                  builder: (context, constraints) => _buildList(
                    context,
                    visible,
                    worktreesByIssue,
                    showAssignees:
                        constraints.maxWidth >=
                        _kFixedListWidth +
                            _kTitleMinWidth +
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
    List<GithubIssue> visible,
    Map<int, Worktree> worktreesByIssue, {
    required bool showAssignees,
  }) {
    final issues = context.watch<GithubIssuesController>();
    final settings = context.watch<SettingsController>();
    final config = issues.config!;
    final selected = issues.selectedNumbers;
    final selectionActive = selected.isNotEmpty;
    final allSelected = visible.every((i) => selected.contains(i.number));
    return Column(
      children: [
        if (selectionActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: _BulkBar(issues: issues.selectedIssues),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _HeaderRow(
            showAssignees: showAssignees,
            selectAllState: !selectionActive
                ? false
                : (allSelected ? true : null),
            onToggleSelectAll: issues.toggleSelectAll,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final issue = visible[index];
              final ref = issues.issueRef(issue.number);
              final name = worktreeNameForGithubIssue(
                issue.number,
                issue.title,
              );
              return _IssueRow(
                issue: issue,
                worktree: worktreesByIssue[issue.number],
                showAssignees: showAssignees,
                tags: settings.settings.tagsFor(ref),
                allTags: settings.settings.jiraTags,
                onTagChanged: (tagId, tagged) =>
                    settings.setJiraTag(ref, tagId, tagged),
                selected: selected.contains(issue.number),
                selectionActive: selectionActive,
                assignedToMe:
                    issues.myLogin != null &&
                    issue.assignees.contains(issues.myLogin),
                onSelectedChanged: (value) =>
                    issues.setSelected(issue.number, value),
                onOpen: () => _open(context, issue),
                onOpenInBrowser: () => openUrl(issue.htmlUrl),
                onCreateWorktree: () => AddWorktreeDialog.show(
                  context,
                  initialName: name,
                  githubIssue: issue.number,
                  contextTitle: issue.title,
                ),
                onStartClaude: () => AddWorktreeDialog.startClaudeSession(
                  context,
                  existingWorktree: worktreesByIssue[issue.number],
                  initialName: name,
                  githubIssue: issue.number,
                  contextPrompt: githubIssueContextPrompt(issue, config),
                  contextPromptLabel: 'Issue context',
                  contextPromptId: githubIssueContextPromptId,
                  contextTitle: issue.title,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Opens [issue] in the issue dialog, or on github.com while ⌘ is held.
  void _open(BuildContext context, GithubIssue issue) {
    if (HardwareKeyboard.instance.isMetaPressed) {
      openUrl(issue.htmlUrl);
      return;
    }
    final issues = context.read<GithubIssuesController>();
    final config = issues.config;
    if (config == null) return;
    GithubIssueDialog.show(
      context,
      config: config,
      number: issue.number,
      initialIssue: issue,
      service: issues.service,
      onIssueChanged: issues.refresh,
      openUrl: openUrl,
    );
  }
}

/// The milestone picker: All open issues, then the open milestones; typing
/// searches the closed ones too.
class _MilestonePicker extends StatefulWidget {
  final List<GithubMilestone> milestones;

  /// Null for all open issues.
  final int? selectedNumber;
  final ValueChanged<int?> onSelected;

  const _MilestonePicker({
    super.key,
    required this.milestones,
    required this.selectedNumber,
    required this.onSelected,
  });

  @override
  State<_MilestonePicker> createState() => _MilestonePickerState();
}

class _MilestonePickerState extends State<_MilestonePicker> {
  /// The entry value for all open issues; milestone numbers start at 1.
  static const _allOpen = 0;
  static const _allOpenLabel = 'All open issues';

  final _controller = TextEditingController();

  /// Whether the field holds something typed rather than the selection's
  /// title, so closed milestones are searched too.
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _selectedTitle {
    final number = widget.selectedNumber;
    if (number == null) return _allOpenLabel;
    return widget.milestones
            .where((m) => m.number == number)
            .firstOrNull
            ?.title ??
        '';
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    final searching = text.isNotEmpty && text != _selectedTitle;
    if (searching != _searching) setState(() => _searching = searching);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedNumber;
    return DropdownMenu<int>(
      controller: _controller,
      initialSelection: selected ?? _allOpen,
      width: 300,
      menuHeight: 380,
      enableFilter: true,
      requestFocusOnTap: true,
      hintText: 'Select milestone',
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
        const DropdownMenuEntry(value: _allOpen, label: _allOpenLabel),
        for (final milestone in widget.milestones)
          if (_searching || milestone.open || milestone.number == selected)
            DropdownMenuEntry(
              value: milestone.number,
              label: milestone.title,
              trailingIcon: milestone.open
                  ? null
                  : Text(
                      'closed',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
      ],
      onSelected: (value) {
        if (value != null) widget.onSelected(value == _allOpen ? null : value);
      },
    );
  }
}

/// All, the states present, then the labels present.
class _FilterChips extends StatelessWidget {
  final GithubIssuesController controller;

  const _FilterChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    final labels = controller.labelCounts;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IssueFilterChip(
          label: 'All',
          count: controller.issues.length,
          color: AppColors.textSecondary,
          selected: !controller.hasFilter,
          onTap: controller.clearFilters,
        ),
        for (final (state, count) in controller.stateCounts)
          IssueFilterChip(
            label: state.label,
            count: count,
            color: githubIssueStateColor(state),
            selected: controller.stateFilter.contains(state),
            onTap: () => controller.toggleState(state),
          ),
        if (labels.isNotEmpty)
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppColors.border,
          ),
        for (final entry in labels)
          IssueFilterChip(
            label: entry.label.name,
            count: entry.count,
            color: readableLabelForeground(githubLabelColor(entry.label.color)),
            selected: controller.labelFilter.contains(entry.label.name),
            onTap: () => controller.toggleLabel(entry.label.name),
          ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool showAssignees;

  /// The select-all checkbox: all, none, or (null) some selected.
  final bool? selectAllState;
  final VoidCallback onToggleSelectAll;

  const _HeaderRow({
    required this.showAssignees,
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
          const SizedBox(width: _kStateIconWidth + _kColumnGap),
          SizedBox(
            width: _kNumberWidth,
            child: Text('#', style: style),
          ),
          const SizedBox(width: _kColumnGap),
          Expanded(child: Text('TITLE', style: style)),
          const SizedBox(width: _kColumnGap),
          SizedBox(
            width: _kStateWidth,
            child: Text('STATE', style: style),
          ),
          if (showAssignees) ...[
            const SizedBox(width: _kColumnGap),
            SizedBox(
              width: _kAssigneeWidth,
              child: Text('ASSIGNEES', style: style),
            ),
          ],
          const SizedBox(width: _kColumnGap + _kActionsWidth),
        ],
      ),
    );
  }
}

class _IssueRow extends StatefulWidget {
  final GithubIssue issue;
  final Worktree? worktree;
  final bool showAssignees;

  /// The issue's tags, and every tag (none hides tagging).
  final List<JiraTag> tags;
  final List<JiraTag> allTags;
  final void Function(String tagId, bool tagged) onTagChanged;
  final bool selected;

  /// Whether any issue is selected, which keeps every checkbox shown.
  final bool selectionActive;
  final bool assignedToMe;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onOpen;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onCreateWorktree;
  final VoidCallback onStartClaude;

  const _IssueRow({
    required this.issue,
    required this.worktree,
    required this.showAssignees,
    required this.tags,
    required this.allTags,
    required this.onTagChanged,
    required this.selected,
    required this.selectionActive,
    required this.assignedToMe,
    required this.onSelectedChanged,
    required this.onOpen,
    required this.onOpenInBrowser,
    required this.onCreateWorktree,
    required this.onStartClaude,
  });

  @override
  State<_IssueRow> createState() => _IssueRowState();
}

class _IssueRowState extends State<_IssueRow> {
  bool _hovered = false;
  bool _changingState = false;
  bool _assigning = false;

  /// Offers the issue's other states below its state pill ([pillContext])
  /// and applies the one picked.
  Future<void> _changeState(BuildContext pillContext) async {
    if (_changingState) return;
    final controller = context.read<GithubIssuesController>();
    final issue = widget.issue;
    final target = await showGithubStateMenu(pillContext, [
      for (final state in GithubIssueState.values)
        if (state != issue.state) state,
    ]);
    if (target == null || !mounted) return;
    setState(() => _changingState = true);
    try {
      final failures = await controller.applyState([issue.number], target);
      final reason = failures[issue.number];
      if (reason != null) showAppSnackBar('#${issue.number}: $reason');
    } finally {
      if (mounted) setState(() => _changingState = false);
    }
  }

  Future<void> _assignToMe() async {
    if (_assigning) return;
    final controller = context.read<GithubIssuesController>();
    setState(() => _assigning = true);
    try {
      await controller.assignToMe(widget.issue.number);
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
    final stateColor = githubIssueStateColor(issue.state);

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
              width: _kStateIconWidth,
              child: Tooltip(
                message: [?issue.type, issue.state.label].join(' · '),
                child: Icon(
                  githubIssueStateIcon(issue.state),
                  size: 16,
                  color: stateColor,
                ),
              ),
            ),
            const SizedBox(width: _kColumnGap),
            SizedBox(
              width: _kNumberWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GithubIssueNumberBadge(
                    number: issue.number,
                    onTap: widget.onOpen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: _kColumnGap),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Flexible(
                      child: Tooltip(
                        message: issue.title,
                        waitDuration: const Duration(milliseconds: 500),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onOpen,
                            child: Text(
                              issue.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (issue.labels.isNotEmpty || widget.allTags.isNotEmpty)
                      // The title keeps at least 40% of the cell.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (issue.labels.isNotEmpty)
                              Flexible(child: _RowLabels(labels: issue.labels)),
                            if (widget.allTags.isNotEmpty)
                              Flexible(
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
                  ],
                ),
              ),
            ),
            const SizedBox(width: _kColumnGap),
            SizedBox(
              width: _kStateWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Builder(
                  builder: (pillContext) => GithubStatePill(
                    state: issue.state,
                    busy: _changingState,
                    onTap: () => _changeState(pillContext),
                  ),
                ),
              ),
            ),
            if (widget.showAssignees) ...[
              const SizedBox(width: _kColumnGap),
              SizedBox(
                width: _kAssigneeWidth,
                child: _Assignees(assignees: issue.assignees),
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
                    message: 'Open #${issue.number} in GitHub',
                    child: ActionButton(
                      compact: true,
                      icon: Icons.open_in_new_rounded,
                      color: AppColors.accent,
                      bgColor: AppColors.accentMuted,
                      onPressed: widget.onOpenInBrowser,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Claude session for #${issue.number}…',
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
                    message: 'Create worktree for #${issue.number}…',
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

/// A row's first two labels, then "+N" for the rest.
class _RowLabels extends StatelessWidget {
  static const maxShown = 2;

  final List<GithubLabel> labels;

  const _RowLabels({required this.labels});

  @override
  Widget build(BuildContext context) {
    final hidden = labels.skip(maxShown).toList();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, label) in labels.take(maxShown).indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Flexible(child: GithubLabelChip(label: label, compact: true)),
          ],
          if (hidden.isNotEmpty) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: hidden.map((l) => l.name).join(', '),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  '+${hidden.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The first assignee and "+N" for the others, all in the tooltip.
class _Assignees extends StatelessWidget {
  final List<String> assignees;

  const _Assignees({required this.assignees});

  @override
  Widget build(BuildContext context) {
    if (assignees.isEmpty) {
      return Text(
        'Unassigned',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textMuted,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final text = Text(
      assignees.length == 1
          ? assignees.first
          : '${assignees.first} +${assignees.length - 1}',
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );
    return assignees.length == 1
        ? text
        : Tooltip(message: assignees.join(', '), child: text);
  }
}

/// Shown above the list while issues are selected: how many, changing their
/// state together, and clearing the selection.
class _BulkBar extends StatefulWidget {
  final List<GithubIssue> issues;

  const _BulkBar({required this.issues});

  @override
  State<_BulkBar> createState() => _BulkBarState();
}

class _BulkBarState extends State<_BulkBar> {
  bool _busy = false;

  Future<void> _changeState(BuildContext buttonContext) async {
    if (_busy) return;
    final controller = context.read<GithubIssuesController>();
    final issues = widget.issues;
    final counts = {
      for (final state in GithubIssueState.values)
        state: issues.where((i) => i.state != state).length,
    };
    final target = await showGithubStateMenu(
      buttonContext,
      [
        for (final state in GithubIssueState.values)
          if (counts[state]! > 0) state,
      ],
      counts: counts,
      issueCount: issues.length,
    );
    if (target == null || !mounted) return;
    final numbers = [
      for (final issue in issues)
        if (issue.state != target) issue.number,
    ];
    setState(() => _busy = true);
    try {
      final failures = await controller.applyState(numbers, target);
      showAppSnackBar(
        bulkStateSummary(target, issues.length, numbers.length, failures),
      );
      // Leave the issues that didn't change selected, to retry or handle.
      controller.clearSelection();
      for (final number in failures.keys) {
        controller.setSelected(number, true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<GithubIssuesController>();
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
              label: 'Change state',
              busy: _busy,
              onTap: _busy || count == 0
                  ? null
                  : () => _changeState(buttonContext),
            ),
          ),
          const SizedBox(width: 8),
          BulkBarButton(
            icon: Icons.close_rounded,
            label: 'Clear',
            onTap: controller.clearSelection,
          ),
        ],
      ),
    );
  }
}
