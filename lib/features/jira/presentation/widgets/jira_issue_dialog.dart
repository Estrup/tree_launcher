
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/widgets/issue_list.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_badges.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_comment_draft_store.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/domain/jira_attachment.dart';
import 'package:tree_launcher/features/jira/domain/jira_constants.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/domain/jira_wiki_markup.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_comment_composer.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_status_menu.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_styles.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_wiki_text.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/core/errors/user_message.dart';

/// Shows Jira issue info (summary, status, type, assignee, priority, last
/// update, description, attachments, comments) for [issueKey], pulled from
/// the REST API and cached locally. Cached data is shown instantly; on a
/// cache miss it auto-fetches. The status can be changed, the issue assigned
/// to the token's user, and a comment written (kept as a draft until sent)
/// from here.
///
/// Self-contained transient dialog (no provider) — mirrors `AddManualPostDialog`.
class JiraIssueDialog extends StatefulWidget {
  final String issueKey;
  final JiraApiService service;
  final JiraIssueCache cache;
  final JiraCommentDraftStore drafts;

  /// Opens a downloaded attachment or a link.
  final UrlOpener open;

  /// Called after the issue's status or assignee was changed here, so lists
  /// showing it can reload.
  final VoidCallback? onIssueChanged;

  const JiraIssueDialog({
    super.key,
    required this.issueKey,
    required this.service,
    required this.cache,
    required this.drafts,
    this.open = openExternal,
    this.onIssueChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String issueKey,
    JiraApiService? service,
    JiraIssueCache? cache,
    JiraCommentDraftStore? drafts,
    UrlOpener open = openExternal,
    VoidCallback? onIssueChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => JiraIssueDialog(
        issueKey: issueKey,
        service: service ?? context.read<JiraApiService>(),
        cache: cache ?? context.read<JiraIssueCache>(),
        drafts: drafts ?? context.read<JiraCommentDraftStore>(),
        open: open,
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

  /// Display names of the users the issue mentions, by username.
  final _mentionNames = <String, String>{};

  /// Attachment ids and image references being downloaded to open.
  final _opening = <String>{};

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
      _resolveMentions(cached.issue);
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
      _resolveMentions(issue);
    } catch (e) {
      if (!mounted) return;
      // Keep any stale _issue visible alongside the error.
      setState(() => _error = userMessage(e));
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

  /// Looks up the display names of the users [issue] mentions, so mentions
  /// show names instead of usernames. One that fails keeps its username.
  Future<void> _resolveMentions(JiraIssue issue) async {
    final users = jiraWikiMentions(
      [
        issue.description ?? '',
        for (final c in issue.comments) c.body,
      ].join('\n'),
    ).where((u) => !_mentionNames.containsKey(u));
    for (final user in users) {
      try {
        final found = await widget.service.fetchUser(user);
        if (!mounted) return;
        setState(() => _mentionNames[user] = found.displayName);
      } catch (e) {
        debugPrint('Jira user lookup failed for $user: $e');
      }
    }
  }

  /// Downloads [attachment] (tracked as [busyKey]) and opens it in its
  /// default app.
  Future<void> _openAttachment(
    JiraAttachment attachment, {
    String? busyKey,
  }) async {
    final key = busyKey ?? attachment.id;
    if (_opening.contains(key)) return;
    setState(() => _opening.add(key));
    try {
      widget.open(await widget.service.downloadAttachment(attachment));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _opening.remove(key));
    }
  }

  /// Opens an image reference (`!source!`): the issue's attachment with that
  /// name, or the URL.
  void _openImage(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      widget.open(source);
      return;
    }
    final attachment = _issue?.attachmentNamed(source);
    if (attachment == null) {
      _showError('$source is not attached to ${widget.issueKey}.');
      return;
    }
    _openAttachment(attachment, busyKey: source);
  }

  String? _mentionName(String user) => _mentionNames[user];

  void _showError(Object error) {
    if (!mounted) return;
    setState(() => _error = userMessage(error));
  }

  void _openInBrowser() {
    widget.open('$jiraBaseUrl${widget.issueKey}');
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
                    'Updated ${formatRelativeTime(issue.updated!)}',
                    tooltip: formatAbsoluteTime(issue.updated!),
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
            IssueErrorBanner(message: _error!, fontSize: 12),
            if (issue != null) const SizedBox(height: 20),
          ],
          // No cache and the fetch failed: only the error box shows.
          if (issue != null) ...[
            IssueDocumentsSection(
              issueKey: widget.issueKey,
              bottomSpacing: 28,
            ),
            const IssueSectionLabel('DESCRIPTION'),
            const SizedBox(height: 10),
            _description(issue.description),
            if (issue.attachments.isNotEmpty) ...[
              const SizedBox(height: 28),
              IssueSectionLabel('ATTACHMENTS', count: issue.attachments.length),
              const SizedBox(height: 10),
              _attachments(issue.attachments),
            ],
            const SizedBox(height: 28),
            IssueSectionLabel('COMMENTS', count: issue.comments.length),
            const SizedBox(height: 12),
            _comments(issue.comments),
            const SizedBox(height: 4),
            JiraCommentComposer(
              issueKey: widget.issueKey,
              service: widget.service,
              drafts: widget.drafts,
              onPosted: _refresh,
              mentionName: _mentionName,
              onOpenImage: _openImage,
            ),
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

  /// Marks a comment only [role] (e.g. Consultants) can see.
  Widget _visibilityBadge(String role) {
    final color = AppColors.claude;
    return Tooltip(
      message: 'Only $role can see this comment',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              role,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
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
    if (description == null || description.trim().isEmpty) {
      return Text(
        'No description',
        style: TextStyle(fontSize: 14, color: AppColors.textMuted),
      );
    }
    return _wikiText(description.trim(), fontSize: 14);
  }

  Widget _wikiText(String markup, {required double fontSize}) => JiraWikiText(
    markup,
    fontSize: fontSize,
    onOpenImage: _openImage,
    busyImages: _opening,
    mentionName: _mentionName,
    openUrl: widget.open,
  );

  /// The issue's files, newest last as Jira lists them; a click downloads
  /// and opens one.
  Widget _attachments(List<JiraAttachment> attachments) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in attachments)
          Tooltip(
            message: [
              if (a.author != null) a.author!,
              if (a.created != null) formatAbsoluteTime(a.created!),
            ].join(' · '),
            child: JiraFileChip(
              name: a.filename,
              icon: _fileIcon(a),
              detail: formatFileSize(a.size),
              busy: _opening.contains(a.id),
              onTap: () => _openAttachment(a),
            ),
          ),
      ],
    );
  }

  static IconData _fileIcon(JiraAttachment a) {
    if (a.isImage) return Icons.image_outlined;
    final name = a.filename.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (RegExp(r'\.(zip|gz|7z|rar)$').hasMatch(name)) {
      return Icons.folder_zip_outlined;
    }
    if (RegExp(r'\.(xlsx?|csv)$').hasMatch(name)) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
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
          InitialsAvatar(name: author, color: _jiraColor),
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
                    if (c.visibility != null) ...[
                      const SizedBox(width: 8),
                      _visibilityBadge(c.visibility!),
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
                    border: c.visibility == null
                        ? null
                        : Border.all(
                            color: AppColors.claude.withValues(alpha: 0.35),
                          ),
                  ),
                  child: _wikiText(c.body.trim(), fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
