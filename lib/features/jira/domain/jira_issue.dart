import 'package:tree_launcher/features/jira/domain/jira_attachment.dart';

/// A single comment on a Jira issue. Bodies are plain wiki-markup strings on
/// Jira Server/Data Center (not Cloud ADF JSON), so [body] is just a String.
class JiraComment {
  final String author;
  final String body;
  final DateTime? created;

  /// The role or group the comment is restricted to (e.g. `Consultants`), or
  /// null when everyone can see it.
  final String? visibility;

  const JiraComment({
    required this.author,
    required this.body,
    this.created,
    this.visibility,
  });

  /// Parses the comment shape from the raw Jira REST API
  /// (`fields.comment.comments[]`).
  factory JiraComment.fromApiJson(Map<String, dynamic> json) {
    final author = json['author'];
    final visibility = json['visibility'];
    return JiraComment(
      author: author is Map<String, dynamic>
          ? (author['displayName'] as String? ?? '')
          : '',
      body: json['body'] as String? ?? '',
      created: DateTime.tryParse(json['created'] as String? ?? ''),
      visibility: visibility is Map<String, dynamic>
          ? visibility['value'] as String?
          : null,
    );
  }

  /// Parses the flat shape written by [toJson] (used by the on-disk cache).
  factory JiraComment.fromJson(Map<String, dynamic> json) {
    return JiraComment(
      author: json['author'] as String? ?? '',
      body: json['body'] as String? ?? '',
      created: DateTime.tryParse(json['created'] as String? ?? ''),
      visibility: json['visibility'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'author': author,
    'body': body,
    if (created != null) 'created': created!.toIso8601String(),
    if (visibility != null) 'visibility': visibility,
  };
}

/// A Jira issue's display-relevant fields, fetched from the REST API and cached
/// locally. Self-hosted Jira Server/Data Center, REST v2.
///
/// [JiraIssue.fromApiJson] parses the raw API response (reaching into
/// `fields`); [JiraIssue.fromJson]/[toJson] use a flat shape for cache storage.
class JiraIssue {
  final String key;
  final String summary;
  final String? status;

  /// Jira's status category key: `new`, `indeterminate` or `done`. Lets the UI
  /// colour statuses without knowing each workflow's status names.
  final String? statusCategory;
  final String? issueType;
  final String? assignee;
  final String? priority;
  final String? description;
  final DateTime? updated;
  final List<JiraComment> comments;
  final List<JiraAttachment> attachments;

  /// Ids of the issue's fixVersions (`JiraVersion.id`).
  final List<String> fixVersionIds;

  const JiraIssue({
    required this.key,
    required this.summary,
    this.status,
    this.statusCategory,
    this.issueType,
    this.assignee,
    this.priority,
    this.description,
    this.updated,
    this.comments = const [],
    this.attachments = const [],
    this.fixVersionIds = const [],
  });

  /// The attachment an image reference such as `!screenshot.png!` names: the
  /// newest one with that file name, as Jira picks it.
  JiraAttachment? attachmentNamed(String filename) =>
      attachments.where((a) => a.filename == filename).lastOrNull;

  /// Reads `fields.<key>.name` defensively (nested objects may be null).
  static String? _nestedName(Map<String, dynamic> fields, String key) {
    final obj = fields[key];
    return obj is Map<String, dynamic> ? obj['name'] as String? : null;
  }

  /// Parses the raw `GET /rest/api/2/issue/{KEY}` response.
  factory JiraIssue.fromApiJson(Map<String, dynamic> json) {
    final fields =
        (json['fields'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final assignee = fields['assignee'];
    final status = fields['status'];
    final category = status is Map<String, dynamic>
        ? status['statusCategory']
        : null;
    final comment = fields['comment'];
    final rawComments = comment is Map<String, dynamic>
        ? (comment['comments'] as List<dynamic>? ?? const [])
        : const [];
    final versions = fields['fixVersions'];
    final rawAttachments = fields['attachment'];

    return JiraIssue(
      key: json['key'] as String? ?? '',
      summary: fields['summary'] as String? ?? '',
      status: _nestedName(fields, 'status'),
      statusCategory: category is Map<String, dynamic>
          ? category['key'] as String?
          : null,
      issueType: _nestedName(fields, 'issuetype'),
      assignee: assignee is Map<String, dynamic>
          ? assignee['displayName'] as String?
          : null,
      priority: _nestedName(fields, 'priority'),
      description: fields['description'] as String?,
      updated: DateTime.tryParse(fields['updated'] as String? ?? ''),
      comments: rawComments
          .whereType<Map<String, dynamic>>()
          .map(JiraComment.fromApiJson)
          .toList(),
      attachments: [
        if (rawAttachments is List)
          for (final a in rawAttachments.whereType<Map<String, dynamic>>())
            JiraAttachment.fromApiJson(a),
      ],
      fixVersionIds: [
        if (versions is List)
          for (final v in versions.whereType<Map<String, dynamic>>())
            if (v['id'] != null) v['id'].toString(),
      ],
    );
  }

  /// Parses the flat shape written by [toJson] (used by the on-disk cache).
  factory JiraIssue.fromJson(Map<String, dynamic> json) {
    final rawComments = json['comments'] as List<dynamic>? ?? const [];
    return JiraIssue(
      key: json['key'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      status: json['status'] as String?,
      statusCategory: json['statusCategory'] as String?,
      issueType: json['issueType'] as String?,
      assignee: json['assignee'] as String?,
      priority: json['priority'] as String?,
      description: json['description'] as String?,
      updated: DateTime.tryParse(json['updated'] as String? ?? ''),
      comments: rawComments
          .whereType<Map<String, dynamic>>()
          .map(JiraComment.fromJson)
          .toList(),
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(JiraAttachment.fromJson)
          .toList(),
      fixVersionIds:
          (json['fixVersionIds'] as List<dynamic>?)?.cast<String>() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'summary': summary,
    if (status != null) 'status': status,
    if (statusCategory != null) 'statusCategory': statusCategory,
    if (issueType != null) 'issueType': issueType,
    if (assignee != null) 'assignee': assignee,
    if (priority != null) 'priority': priority,
    if (description != null) 'description': description,
    if (updated != null) 'updated': updated!.toIso8601String(),
    'comments': comments.map((c) => c.toJson()).toList(),
    if (attachments.isNotEmpty)
      'attachments': attachments.map((a) => a.toJson()).toList(),
    if (fixVersionIds.isNotEmpty) 'fixVersionIds': fixVersionIds,
  };

  JiraIssue copyWith({
    String? key,
    String? summary,
    String? status,
    String? statusCategory,
    String? issueType,
    String? assignee,
    String? priority,
    String? description,
    DateTime? updated,
    List<JiraComment>? comments,
    List<JiraAttachment>? attachments,
    List<String>? fixVersionIds,
  }) {
    return JiraIssue(
      key: key ?? this.key,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      statusCategory: statusCategory ?? this.statusCategory,
      issueType: issueType ?? this.issueType,
      assignee: assignee ?? this.assignee,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      updated: updated ?? this.updated,
      comments: comments ?? this.comments,
      attachments: attachments ?? this.attachments,
      fixVersionIds: fixVersionIds ?? this.fixVersionIds,
    );
  }
}

/// A [JiraIssue] together with the time it was fetched from Jira, so the dialog
/// can show how long ago it was last updated.
class CachedJiraIssue {
  final JiraIssue issue;
  final DateTime fetchedAt;

  const CachedJiraIssue({required this.issue, required this.fetchedAt});
}
