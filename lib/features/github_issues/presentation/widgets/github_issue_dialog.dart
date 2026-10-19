import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/app/dependencies.dart';
import 'package:tree_launcher/core/widgets/issue_list.dart';
import 'package:tree_launcher/features/github_issues/data/github_issue_cache.dart';
import 'package:tree_launcher/features/github_issues/data/github_issues_api_service.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_issues/presentation/github_issue_actions.dart';
import 'package:tree_launcher/features/github_issues/presentation/widgets/github_issue_styles.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/github_prs/presentation/widgets/github_styles.dart';
import 'package:tree_launcher/theme/app_theme.dart';

/// Shows a GitHub issue (title, state, assignees, milestone, labels,
/// description, comments), pulled from the REST API and cached locally. It is
/// fetched every time the dialog opens; [GithubIssueDialog.initialIssue] and
/// then the cached copy show until the fetch is done. The state can be
/// changed and the issue assigned to the token's user from here.
///
/// Self-contained transient dialog (no provider), like `JiraIssueDialog`.
class GithubIssueDialog extends StatefulWidget {
  final GithubConfig config;
  final int number;

  /// The issue as a list already has it (no comments), shown until the
  /// cached or fetched copy arrives.
  final GithubIssue? initialIssue;
  final GithubIssuesApiService service;
  final GithubIssueCache cache;

  /// Called after the issue's state or assignees were changed here, so lists
  /// showing it can reload.
  final VoidCallback? onIssueChanged;

  /// Opens the issue on github.com.
  final UrlOpener openUrl;

  const GithubIssueDialog({
    super.key,
    required this.config,
    required this.number,
    required this.service,
    required this.cache,
    this.initialIssue,
    this.onIssueChanged,
    this.openUrl = openInBrowser,
  });

  static Future<void> show(
    BuildContext context, {
    required GithubConfig config,
    required int number,
    GithubIssue? initialIssue,
    GithubIssuesApiService? service,
    GithubIssueCache? cache,
    VoidCallback? onIssueChanged,
    UrlOpener openUrl = openInBrowser,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => GithubIssueDialog(
        config: config,
        number: number,
        initialIssue: initialIssue,
        service: service ?? GithubIssuesApiService(),
        cache: cache ?? context.read<AppDependencies>().githubIssueCache,
        onIssueChanged: onIssueChanged,
        openUrl: openUrl,
      ),
    );
  }

  @override
  State<GithubIssueDialog> createState() => _GithubIssueDialogState();
}

class _GithubIssueDialogState extends State<GithubIssueDialog> {
  late GithubIssue? _issue = widget.initialIssue;
  DateTime? _fetchedAt;
  bool _isLoading = false;
  String? _error;

  /// Whether a state change is being applied.
  bool _changingState = false;

  /// Anchors the state menu below the state pill.
  final _stateKey = GlobalKey();

  /// The token's login, once known; hides "Assign to me" on their issues.
  String? _me;
  bool _assigning = false;

  String get _repo => '${widget.config.owner}/${widget.config.repo}';

  String get _ref =>
      githubIssueRef(widget.config.owner, widget.config.repo, widget.number);

  String get _url =>
      _issue?.htmlUrl ?? 'https://github.com/$_repo/issues/${widget.number}';

  @override
  void initState() {
    super.initState();
    _load();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final me = await widget.service.fetchMyLogin(widget.config);
    if (mounted && me != null) setState(() => _me = me);
  }

  bool get _assignedToMe {
    final me = _me;
    return me != null && (_issue?.assignees.contains(me) ?? false);
  }

  /// Whether a fetch has finished, so a late cache read doesn't replace it.
  bool _fetched = false;

  /// Fetches a fresh copy, showing the cached one while that loads.
  Future<void> _load() async {
    final refresh = _refresh();
    final cached = await widget.cache.read(_ref);
    if (mounted && cached != null && !_fetched) {
      setState(() {
        _issue = cached.issue;
        _fetchedAt = cached.fetchedAt;
      });
    }
    await refresh;
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final issue = await widget.service.fetchIssue(
        widget.config,
        widget.number,
      );
      _fetched = true;
      // Never throws, and the dialog needn't wait for it.
      widget.cache.write(_ref, issue);
      if (!mounted) return;
      setState(() {
        _issue = issue;
        _fetchedAt = DateTime.now();
      });
    } catch (e) {
      // Keep any stale _issue visible alongside the error.
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Offers the issue's other states below the state pill, applies the one
  /// picked, and reloads the issue.
  Future<void> _changeState() async {
    final issue = _issue;
    if (_changingState || issue == null) return;
    final target = await showGithubStateMenu(_stateKey.currentContext!, [
      for (final state in GithubIssueState.values)
        if (state != issue.state) state,
    ]);
    if (target == null || !mounted) return;
    setState(() {
      _changingState = true;
      _error = null;
    });
    try {
      await widget.service.setState(widget.config, widget.number, target);
      widget.onIssueChanged?.call();
      if (mounted) await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _changingState = false);
    }
  }

  Future<void> _assignToMe() async {
    if (_assigning) return;
    setState(() {
      _assigning = true;
      _error = null;
    });
    try {
      final me = _me ?? await widget.service.fetchMyLogin(widget.config);
      if (me == null) throw Exception("Couldn't look up your GitHub login.");
      final assignees = await widget.service.addAssignee(
        widget.config,
        widget.number,
        me,
      );
      widget.onIssueChanged?.call();
      if (!mounted) return;
      setState(() => _me = me);
      await _refresh();
      if (!assignees.contains(me)) {
        _showError(
          "GitHub didn't assign you to #${widget.number}. You may lack write "
          'access to $_repo.',
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // Wide enough for comfortable reading, never wider than the window.
    final width = (screen.width - 80).clamp(320.0, 860.0);
    return Dialog(
      backgroundColor: AppColors.surface1,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screen.height * 0.88),
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              Divider(height: 1, color: AppColors.borderSubtle),
              Flexible(child: _body()),
              Divider(height: 1, color: AppColors.borderSubtle),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  /// State icon, reference, type and close button, then the title and the
  /// issue's facts below it.
  Widget _header() {
    final issue = _issue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (issue != null) ...[
                Icon(
                  githubIssueStateIcon(issue.state),
                  size: 16,
                  color: githubIssueStateColor(issue.state),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  '$_repo#${widget.number}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (issue?.type != null) ...[
                const SizedBox(width: 8),
                Text(
                  issue!.type!,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (issue != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SelectableText(
                issue.title,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                KeyedSubtree(
                  key: _stateKey,
                  child: GithubStatePill(
                    state: issue.state,
                    busy: _changingState,
                    onTap: _isLoading && _fetchedAt == null
                        ? null
                        : _changeState,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _fact(
                      Icons.person_outline_rounded,
                      issue.assignees.isEmpty
                          ? 'Unassigned'
                          : issue.assignees.join(', '),
                      tooltip: 'Assignees',
                    ),
                    if (!_assignedToMe) ...[
                      const SizedBox(width: 8),
                      _assignToMeButton(),
                    ],
                  ],
                ),
                if (issue.milestone != null)
                  _fact(
                    Icons.flag_outlined,
                    issue.milestone!,
                    tooltip: 'Milestone',
                  ),
                if (issue.author != null)
                  _fact(
                    Icons.edit_note_rounded,
                    issue.createdAt == null
                        ? 'Opened by ${issue.author}'
                        : 'Opened by ${issue.author} '
                              '${formatRelativeTime(issue.createdAt!)}',
                    tooltip: issue.createdAt == null
                        ? 'Author'
                        : formatAbsoluteTime(issue.createdAt!),
                  ),
                if (issue.updatedAt != null)
                  _fact(
                    Icons.schedule_rounded,
                    'Updated ${formatRelativeTime(issue.updatedAt!)}',
                    tooltip: formatAbsoluteTime(issue.updatedAt!),
                  ),
              ],
            ),
            if (issue.labels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in issue.labels)
                    GithubLabelChip(label: label),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _body() {
    final issue = _issue;
    if (_isLoading && issue == null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    // Comments arrive with the first fetch (or the cache); the list's copy
    // has none.
    final commentsLoaded = _fetchedAt != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            IssueErrorBanner(message: _error!, fontSize: 12),
            if (issue != null) const SizedBox(height: 20),
          ],
          // No copy at all and the fetch failed: only the error box shows.
          if (issue != null) ...[
            const IssueSectionLabel('DESCRIPTION'),
            const SizedBox(height: 10),
            _description(issue.body),
            const SizedBox(height: 28),
            IssueSectionLabel(
              'COMMENTS',
              count: commentsLoaded
                  ? issue.comments.length
                  : issue.commentCount,
            ),
            const SizedBox(height: 12),
            if (commentsLoaded)
              _comments(issue.comments)
            else
              Text(
                'Loading comments…',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
          ],
        ],
      ),
    );
  }

  /// When the data was fetched, a refresh, and the link to GitHub.
  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 20, 12),
      child: Row(
        children: [
          if (_fetchedAt != null)
            Tooltip(
              message: formatAbsoluteTime(_fetchedAt!),
              child: Text(
                'Fetched ${formatRelativeTime(_fetchedAt!)}',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _isLoading ? null : _refresh,
            icon: _isLoading
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    size: 15,
                    color: AppColors.accent,
                  ),
            label: Text(
              'Refresh',
              style: TextStyle(fontSize: 12, color: AppColors.accent),
            ),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.openUrl(_url),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: AppColors.base,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Open in GitHub',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.base,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assignToMeButton() {
    final color = AppColors.accent;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _assigning || (_isLoading && _fetchedAt == null)
            ? null
            : _assignToMe,
        hoverColor: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: _assigning
                    ? Padding(
                        padding: const EdgeInsets.all(2),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: color,
                        ),
                      )
                    : Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 14,
                        color: color,
                      ),
              ),
              const SizedBox(width: 5),
              Text(
                'Assign to me',
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

  Widget _fact(IconData icon, String text, {required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _description(String? body) {
    final empty = body == null || body.trim().isEmpty;
    return SelectableText(
      empty ? 'No description' : body.trim(),
      style: TextStyle(
        fontSize: 14,
        height: 1.55,
        color: empty ? AppColors.textMuted : AppColors.textPrimary,
      ),
    );
  }

  Widget _comments(List<GithubIssueComment> comments) {
    if (comments.isEmpty) {
      return Text(
        'No comments',
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final c in comments) _comment(c)],
    );
  }

  Widget _comment(GithubIssueComment c) {
    final author = c.author.isEmpty ? 'Unknown' : c.author;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: author, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (c.created != null) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: formatAbsoluteTime(c.created!),
                        child: Text(
                          formatRelativeTime(c.created!),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    c.body.trim(),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
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
