import 'dart:io';

import 'package:flutter/material.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/domain/jira_constants.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';

/// Shows Jira issue info (summary, status, type, assignee, priority,
/// description, comments) for [issueKey], pulled from the REST API and cached
/// locally. Cached data is shown instantly; on a cache miss it auto-fetches.
///
/// Self-contained transient dialog (no provider) — mirrors `AddManualPostDialog`.
class JiraIssueDialog extends StatefulWidget {
  final String issueKey;
  final JiraApiService service;
  final JiraIssueCache cache;

  const JiraIssueDialog({
    super.key,
    required this.issueKey,
    required this.service,
    required this.cache,
  });

  static Future<void> show(
    BuildContext context, {
    required String issueKey,
    JiraApiService? service,
    JiraIssueCache? cache,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => JiraIssueDialog(
        issueKey: issueKey,
        service: service ?? JiraApiService(),
        cache: cache ?? JiraIssueCache(),
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

  @override
  void initState() {
    super.initState();
    _load();
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

  void _openInBrowser() {
    Process.run('open', ['$jiraBaseUrl${widget.issueKey}']);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      title: Row(
        children: [
          Text(
            widget.issueKey,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _jiraColor,
              fontFamily: 'monospace',
            ),
          ),
          if (_issue?.issueType != null) ...[
            const SizedBox(width: 10),
            _chip(_issue!.issueType!),
          ],
        ],
      ),
      content: SizedBox(width: 440, child: _content()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton.icon(
          onPressed: _isLoading ? null : _refresh,
          icon: _isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : Icon(Icons.refresh_rounded, size: 16, color: AppColors.accent),
          label: Text(
            'Refresh from Jira',
            style: TextStyle(color: AppColors.accent),
          ),
        ),
        GestureDetector(
          onTap: _openInBrowser,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      ],
    );
  }

  Widget _content() {
    if (_isLoading && _issue == null) {
      return SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    final issue = _issue;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            _errorBox(_error!),
            const SizedBox(height: 16),
          ],
          if (issue == null)
            // No cache and the fetch failed — only the error box above shows.
            const SizedBox.shrink()
          else ...[
            _field('SUMMARY', issue.summary),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field('STATUS', issue.status ?? '—')),
                const SizedBox(width: 16),
                Expanded(
                  child: _field('ASSIGNEE', issue.assignee ?? 'Unassigned'),
                ),
              ],
            ),
            _descriptionField(issue.description),
            _commentsField(issue.comments),
            if (_fetchedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Updated ${_relative(_fetchedAt!)}',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(label),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _descriptionField(String? description) {
    final text = (description == null || description.trim().isEmpty)
        ? 'No description'
        : description;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('DESCRIPTION'),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: (description == null || description.trim().isEmpty)
                      ? AppColors.textMuted
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentsField(List<JiraComment> comments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('COMMENTS (${comments.length})'),
        const SizedBox(height: 6),
        if (comments.isEmpty)
          Text(
            'No comments',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          )
        else
          for (final c in comments) _comment(c),
      ],
    );
  }

  Widget _comment(JiraComment c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.author.isEmpty ? 'Unknown' : c.author,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (c.created != null)
                Text(
                  _relative(c.created!),
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            c.body,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _jiraColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _jiraColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _jiraColor,
        ),
      ),
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
}
