import 'dart:io';

import 'package:flutter/material.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/domain/jira_constants.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_status_menu.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_styles.dart';

/// Shows Jira issue info (summary, status, type, assignee, priority, last
/// update, description, comments) for [issueKey], pulled from the REST API and
/// cached locally. Cached data is shown instantly; on a cache miss it
/// auto-fetches. The status can be changed and the issue assigned to the
/// token's user from here.
///
/// Self-contained transient dialog (no provider) — mirrors `AddManualPostDialog`.
class JiraIssueDialog extends StatefulWidget {
  final String issueKey;
  final JiraApiService service;
  final JiraIssueCache cache;

  /// Called after the issue's status or assignee was changed here, so lists
  /// showing it can reload.
  final VoidCallback? onIssueChanged;

  const JiraIssueDialog({
    super.key,
    required this.issueKey,
    required this.service,
    required this.cache,
    this.onIssueChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String issueKey,
    JiraApiService? service,
    JiraIssueCache? cache,
    VoidCallback? onIssueChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => JiraIssueDialog(
        issueKey: issueKey,
        service: service ?? JiraApiService(),
        cache: cache ?? JiraIssueCache(),
        onIssueChanged: onIssueChanged,
      ),
    );
  }

  @override
  State<JiraIssueDialog> createState() => _JiraIssueDialogState();
}

class _JiraIssueDialogState extends State<JiraIssueDialog> {
  static const Color _jiraColor = Color(0xFF2684FF);

  JiraIssue? _issue;
  DateTime? _fetchedAt;
  bool _isLoading = false;
  String? _error;

  /// Whether a status change is being looked up or applied.
  bool _changingStatus = false;

  /// Anchors the status menu below the status pill.
  final _statusKey = GlobalKey();

  /// The token's user, once known; hides "Assign to me" on their issues.
  JiraUser? _me;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await widget.service.fetchMyself();
      if (mounted) setState(() => _me = me);
    } catch (e) {
      // "Assign to me" stays offered and reports the problem if used.
      debugPrint('Jira user lookup failed: $e');
    }
  }

  bool get _assignedToMe {
    final me = _me;
    return me != null && _issue?.assignee == me.displayName;
  }

  Future<void> _assignToMe() async {
    if (_assigning) return;
    setState(() {
      _assigning = true;
      _error = null;
    });
    try {
      final me = _me ?? await widget.service.fetchMyself();
      await widget.service.assignIssue(widget.issueKey, me.name);
      widget.onIssueChanged?.call();
      if (!mounted) return;
      setState(() => _me = me);
      await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _load() async {
    final cached = await widget.cache.read(widget.issueKey);
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _issue = cached.issue;
        _fetchedAt = cached.fetchedAt;
      });
      return;
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final issue = await widget.service.fetchIssue(widget.issueKey);
      await widget.cache.write(widget.issueKey, issue);
      if (!mounted) return;
      setState(() {
        _issue = issue;
        _fetchedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      // Keep any stale _issue visible alongside the error.
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Offers the workflow's status changes from the current status below the
  /// status pill, applies the one picked, and reloads the issue.
  Future<void> _changeStatus() async {
    if (_changingStatus || _issue == null) return;
    setState(() {
      _changingStatus = true;
      _error = null;
    });
    final List<JiraTransition> transitions;
    try {
      transitions = await widget.service.fetchTransitions(widget.issueKey);
    } catch (e) {
      _showError(e);
      return;
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
    if (!mounted) return;
    if (transitions.isEmpty) {
      setState(() => _error = 'No status changes are available.');
      return;
    }

    final picked = await showJiraStatusMenu(
      _statusKey.currentContext!,
      jiraStatusMoves({widget.issueKey: transitions}),
      issueCount: 1,
    );
    final transition = picked?.transitions[widget.issueKey];
    if (transition == null || !mounted) return;
    setState(() => _changingStatus = true);
    try {
      await widget.service.transitionIssue(widget.issueKey, transition.id);
      widget.onIssueChanged?.call();
      if (mounted) await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
  }

  void _openInBrowser() {
    Process.run('open', ['$jiraBaseUrl${widget.issueKey}']);
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

  /// Key, type and close button, then the summary as the title and the
  /// issue's facts below it.
  Widget _header() {
    final issue = _issue;
    final (typeIcon, typeColor) = jiraTypeIcon(issue?.issueType);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (issue?.issueType != null) ...[
                Tooltip(
                  message: issue!.issueType!,
                  child: Icon(typeIcon, size: 16, color: typeColor),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.issueKey,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _jiraColor,
                  fontFamily: 'monospace',
                ),
              ),
              if (issue?.issueType != null) ...[
                const SizedBox(width: 8),
                Text(
                  issue!.issueType!,
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
                issue.summary,
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
                if (issue.status != null)
                  _statusPill(issue.status!, issue.statusCategory),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _fact(
                      Icons.person_outline_rounded,
                      issue.assignee ?? 'Unassigned',
                      tooltip: 'Assignee',
                    ),
                    if (!_assignedToMe) ...[
                      const SizedBox(width: 8),
                      _assignToMeButton(),
                    ],
                  ],
                ),
                if (issue.priority != null)
                  _fact(
                    Icons.flag_outlined,
                    issue.priority!,
                    tooltip: 'Priority',
                  ),
                if (issue.updated != null)
                  _fact(
                    Icons.schedule_rounded,
                    'Updated ${_relative(issue.updated!)}',
                    tooltip: _absolute(issue.updated!),
                  ),
              ],
            ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            _errorBox(_error!),
            if (issue != null) const SizedBox(height: 20),
          ],
          // No cache and the fetch failed: only the error box shows.
          if (issue != null) ...[
            _sectionLabel('DESCRIPTION'),
            const SizedBox(height: 10),
            _description(issue.description),
            const SizedBox(height: 28),
            _sectionLabel('COMMENTS', count: issue.comments.length),
            const SizedBox(height: 12),
            _comments(issue.comments),
          ],
        ],
      ),
    );
  }

  /// When the data was fetched, a refresh, and the link to Jira.
  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 20, 12),
      child: Row(
        children: [
          if (_fetchedAt != null)
            Tooltip(
              message: _absolute(_fetchedAt!),
              child: Text(
                'Fetched ${_relative(_fetchedAt!)}',
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
              onTap: _openInBrowser,
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
                      'Open in Jira',
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

  /// The status, as a button that opens the status menu.
  Widget _statusPill(String status, String? category) {
    final color = jiraStatusColor(category);
    return Tooltip(
      message: 'Change status',
      child: Material(
        key: _statusKey,
        color: color.withValues(alpha: 0.12),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _changingStatus || _isLoading ? null : _changeStatus,
          hoverColor: color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: _changingStatus
                      ? Padding(
                          padding: const EdgeInsets.all(3),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: color,
                          ),
                        )
                      : Icon(Icons.expand_more_rounded, size: 16, color: color),
                ),
              ],
            ),
          ),
        ),
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
        onTap: _assigning || _isLoading ? null : _assignToMe,
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
          Text(
            text,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _description(String? description) {
    final empty = description == null || description.trim().isEmpty;
    return SelectableText(
      empty ? 'No description' : description.trim(),
      style: TextStyle(
        fontSize: 14,
        height: 1.55,
        color: empty ? AppColors.textMuted : AppColors.textPrimary,
      ),
    );
  }

  Widget _comments(List<JiraComment> comments) {
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

  Widget _comment(JiraComment c) {
    final author = c.author.isEmpty ? 'Unknown' : c.author;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(author),
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
                        message: _absolute(c.created!),
                        child: Text(
                          _relative(c.created!),
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

  /// A circle with the author's initials.
  Widget _avatar(String name) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _jiraColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _jiraColor,
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {int? count}) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 1.2,
    );
    if (count == null) return Text(text, style: style);
    return Row(
      children: [
        Text(text, style: style),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.isNegative) return 'just now';
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo ago';
    return '${(d.inDays / 365).floor()}y ago';
  }

  /// [t] as local date and time, e.g. `9 Oct 2026, 14:05`.
  String _absolute(DateTime t) {
    const months = [
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
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
