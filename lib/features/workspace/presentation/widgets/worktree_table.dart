import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/design_system/selection_controls.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_titles_controller.dart';
import 'package:tree_launcher/features/workspace/data/launcher_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/providers/repo_provider.dart';

/// Shared column layout so the header and every row line up.
const double _kCheckboxWidth = 24;
const double _kJiraWidth = 120;
const double _kPrWidth = 80;
const double _kActionsWidth = 296;
const double _kColumnGap = 16;
const int _kNameFlex = 3;
const int _kBranchFlex = 3;
const int _kJiraTitleFlex = 4;

/// Width breakpoints for responsive column hiding. PR is dropped first (it is
/// the least essential), then the Jira title. PR threshold sits above the
/// title's so the two columns disappear one at a time as the table narrows.
const double _kHideJiraTitleBelow = 760;
const double _kHidePrBelow = 920;

/// Compact list/table view of worktrees.
///
/// Rows are grouped into "My worktrees" and "To review" (worktrees created from
/// another user's PR, identified by [Worktree.prAuthor]). PR and Jira title
/// columns hide on narrow widths.
class WorktreeTable extends StatefulWidget {
  final List<Worktree> worktrees;

  const WorktreeTable({super.key, required this.worktrees});

  @override
  State<WorktreeTable> createState() => _WorktreeTableState();
}

class _WorktreeTableState extends State<WorktreeTable> {
  /// Paths of the selected worktrees. Paths are the canonical worktree
  /// identity throughout the app (all per-worktree config is keyed by path).
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _requestJiraTitles();
  }

  /// Asks for the titles of the rows' Jira issues; already-known keys are
  /// skipped by the controller.
  void _requestJiraTitles() {
    final keys = widget.worktrees
        .map((w) => w.jiraIssue)
        .whereType<String>()
        .where((k) => k.isNotEmpty);
    context.read<JiraTitlesController>().ensureTitles(keys);
  }

  @override
  void didUpdateWidget(WorktreeTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _requestJiraTitles();
    // Drop selections whose rows left the table — covers deletions, hides
    // (when "Show hidden" is off), repo switches, and background refreshes.
    final paths = widget.worktrees.map((w) => w.path).toSet();
    _selected.removeWhere((p) => !paths.contains(p));
  }

  List<Worktree> get _selectedWorktrees =>
      widget.worktrees.where((w) => _selected.contains(w.path)).toList();

  void _toggle(String path, bool selected) {
    setState(() {
      selected ? _selected.add(path) : _selected.remove(path);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == widget.worktrees.length) {
        _selected.clear();
      } else {
        _selected.addAll(widget.worktrees.map((w) => w.path));
      }
    });
  }

  Future<void> _hideSelected() async {
    final paths = _selected.toList();
    // Clear eagerly: with "Show hidden worktrees" on, the rows stay visible
    // and didUpdateWidget would never prune them.
    setState(_selected.clear);
    await context.read<RepoProvider>().setWorktreesHidden(paths, true);
  }

  Future<void> _deleteSelected() async {
    final deletable = _selectedWorktrees.where((w) => !w.isMain).toList();
    // No manual clear afterwards: deleted rows leave the list and are pruned
    // by didUpdateWidget, while failed ones stay selected for a retry.
    await confirmBulkDeleteWorktrees(context, deletable);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<GithubPrsController>().currentUserLogin;
    // A worktree is a review worktree when it was created from someone else's
    // PR. When the current login is unknown, any attached prAuthor counts —
    // prAuthor is only ever set for worktrees created from another user's PR.
    bool isReview(Worktree w) => w.prAuthor != null && w.prAuthor != me;

    final mine = widget.worktrees.where((w) => !isReview(w)).toList();
    final toReview = widget.worktrees.where(isReview).toList();

    final selectionActive = _selected.isNotEmpty;
    final bool? selectAllState = _selected.isEmpty
        ? false
        : (_selected.length == widget.worktrees.length ? true : null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showPr = constraints.maxWidth >= _kHidePrBelow;
        final showJiraTitle = constraints.maxWidth >= _kHideJiraTitleBelow;

        Widget buildRow(Worktree wt) => _WorktreeRow(
          worktree: wt,
          showPr: showPr,
          showJiraTitle: showJiraTitle,
          selected: _selected.contains(wt.path),
          selectionActive: selectionActive,
          onSelectedChanged: (value) => _toggle(wt.path, value),
        );

        // Flatten the groups into a single item list so one ListView scrolls
        // both sections. Section headers are only shown when the review group
        // is non-empty, so a repo with nothing to review looks unchanged.
        final items = <Widget>[];
        if (toReview.isEmpty) {
          for (final wt in mine) {
            items.add(buildRow(wt));
          }
        } else {
          void addGroup(String title, List<Worktree> group) {
            if (group.isEmpty) return;
            items.add(_SectionHeader(title: title, count: group.length));
            for (final wt in group) {
              items.add(buildRow(wt));
            }
          }

          addGroup('My worktrees', mine);
          addGroup('To review', toReview);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selectionActive)
              _BulkActionBar(
                count: _selected.length,
                deletableCount: _selectedWorktrees
                    .where((w) => !w.isMain)
                    .length,
                onHide: _hideSelected,
                onDelete: _deleteSelected,
                onClear: () => setState(_selected.clear),
              ),
            _HeaderRow(
              showPr: showPr,
              showJiraTitle: showJiraTitle,
              selectAllState: selectAllState,
              selectionActive: selectionActive,
              onToggleSelectAll: _toggleAll,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: items.length,
                itemBuilder: (context, index) => items[index],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Toolbar shown above the header while rows are selected, offering bulk
/// actions on the selection. Delete is disabled when only the primary
/// worktree is selected — git cannot remove the main worktree.
class _BulkActionBar extends StatelessWidget {
  final int count;
  final int deletableCount;
  final VoidCallback onHide;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const _BulkActionBar({
    required this.count,
    required this.deletableCount,
    required this.onHide,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
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
          BulkBarButton(
            icon: Icons.visibility_off_rounded,
            label: 'Hide',
            onTap: onHide,
          ),
          const SizedBox(width: 8),
          BulkBarButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppColors.error,
            onTap: deletableCount > 0 ? onDelete : null,
            disabledTooltip: "The primary worktree can't be deleted",
          ),
          const SizedBox(width: 8),
          BulkBarButton(
            icon: Icons.close_rounded,
            label: 'Clear',
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

/// Group divider shown above each worktree section, styled like the muted
/// uppercase column labels.
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatefulWidget {
  final bool showPr;
  final bool showJiraTitle;

  /// Select-all checkbox state: true = all, null = some, false = none.
  final bool? selectAllState;
  final bool selectionActive;
  final VoidCallback onToggleSelectAll;

  const _HeaderRow({
    required this.showPr,
    required this.showJiraTitle,
    required this.selectAllState,
    required this.selectionActive,
    required this.onToggleSelectAll,
  });

  @override
  State<_HeaderRow> createState() => _HeaderRowState();
}

class _HeaderRowState extends State<_HeaderRow> {
  bool _hovered = false;

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 0.6,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final showPr = widget.showPr;
    final showJiraTitle = widget.showJiraTitle;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: _kCheckboxWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectCheckbox(
                  value: widget.selectAllState,
                  visible: _hovered || widget.selectionActive,
                  onTap: widget.onToggleSelectAll,
                ),
              ),
            ),
            const SizedBox(width: _kColumnGap),
            Expanded(flex: _kNameFlex, child: _label('Worktree')),
            const SizedBox(width: _kColumnGap),
            Expanded(flex: _kBranchFlex, child: _label('Branch')),
            const SizedBox(width: _kColumnGap),
            SizedBox(width: _kJiraWidth, child: _label('Jira')),
            if (showJiraTitle) ...[
              const SizedBox(width: _kColumnGap),
              Expanded(flex: _kJiraTitleFlex, child: _label('Jira title')),
            ],
            if (showPr) ...[
              const SizedBox(width: _kColumnGap),
              SizedBox(width: _kPrWidth, child: _label('PR')),
            ],
            const SizedBox(width: _kColumnGap),
            SizedBox(
              width: _kActionsWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: _label('Actions'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorktreeRow extends StatefulWidget {
  final Worktree worktree;
  final bool showPr;
  final bool showJiraTitle;
  final bool selected;
  final bool selectionActive;
  final ValueChanged<bool> onSelectedChanged;

  const _WorktreeRow({
    required this.worktree,
    required this.showPr,
    required this.showJiraTitle,
    required this.selected,
    required this.selectionActive,
    required this.onSelectedChanged,
  });

  @override
  State<_WorktreeRow> createState() => _WorktreeRowState();
}

class _WorktreeRowState extends State<_WorktreeRow> {
  final LauncherService _launcherService = LauncherService();
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<RepoProvider>().selectedRepo;
    final customCommands = repo?.customCommands ?? [];
    final wt = widget.worktree;

    // Match this worktree to an open PR by branch. Both own worktrees and
    // review worktrees check out the PR's head branch, so this finds either.
    GithubPullRequest? matchPr;
    if (widget.showPr) {
      final prs = context.watch<GithubPrsController>().pullRequests;
      for (final pr in prs) {
        if (pr.headBranch == wt.branch) {
          matchPr = pr;
          break;
        }
      }
    }

    final jiraKey = wt.jiraIssue;
    final jiraTitle = widget.showJiraTitle && jiraKey != null
        ? context.watch<JiraTitlesController>().titleFor(jiraKey)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: widget.selected
              ? AppColors.accentMuted
              : _hovered
              ? AppColors.surface2
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Row(
          children: [
            // Selection checkbox (space always reserved to keep columns fixed)
            SizedBox(
              width: _kCheckboxWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectCheckbox(
                  value: widget.selected,
                  visible:
                      _hovered || widget.selected || widget.selectionActive,
                  onTap: () => widget.onSelectedChanged(!widget.selected),
                ),
              ),
            ),
            const SizedBox(width: _kColumnGap),

            // Name (+ PRIMARY badge)
            Expanded(
              flex: _kNameFlex,
              child: Row(
                children: [
                  Flexible(
                    child: Tooltip(
                      message: wt.name,
                      waitDuration: const Duration(milliseconds: 300),
                      child: Text(
                        wt.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (wt.isMain) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PRIMARY',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: _kColumnGap),

            // Branch (click to copy)
            Expanded(
              flex: _kBranchFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => copyToClipboard(context, wt.branch, 'Branch'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.branchBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.branch.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.call_split_rounded,
                            size: 11,
                            color: AppColors.branch,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              wt.branch,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.branch,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: _kColumnGap),

            // Jira
            SizedBox(
              width: _kJiraWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: wt.jiraIssue != null
                    ? JiraBadge(issueKey: wt.jiraIssue!, compact: true)
                    : Text(
                        '—',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ),
            if (widget.showJiraTitle) ...[
              const SizedBox(width: _kColumnGap),

              // Jira title (when known)
              Expanded(
                flex: _kJiraTitleFlex,
                child: jiraTitle != null
                    ? Tooltip(
                        message: jiraTitle,
                        waitDuration: const Duration(milliseconds: 300),
                        child: Text(
                          jiraTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
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
            if (widget.showPr) ...[
              const SizedBox(width: _kColumnGap),

              // PR (link to GitHub)
              SizedBox(
                width: _kPrWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: matchPr != null
                      ? PrBadge(
                          number: matchPr.number,
                          htmlUrl: matchPr.htmlUrl,
                          compact: true,
                        )
                      : Text(
                          '—',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
              ),
            ],

            const SizedBox(width: _kColumnGap),

            // Actions
            SizedBox(
              width: _kActionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TerminalButton(
                    worktreePath: wt.path,
                    worktreeName: wt.name,
                    launcherService: _launcherService,
                    compact: true,
                  ),
                  const SizedBox(width: 6),
                  VscodeButton(
                    worktreePath: wt.path,
                    launcherService: _launcherService,
                    compact: true,
                  ),
                  const SizedBox(width: 6),
                  ClaudeButton(
                    wt: wt,
                    launcherService: _launcherService,
                    compact: true,
                  ),
                  if (customCommands.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    CustomCommandsButton(
                      worktreePath: wt.path,
                      worktreeName: wt.name,
                      commands: customCommands,
                      compact: true,
                    ),
                  ],
                  const SizedBox(width: 6),
                  PullButton(worktree: wt, compact: true),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 24,
                    child: WorktreeOptionsButton(worktree: wt),
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
