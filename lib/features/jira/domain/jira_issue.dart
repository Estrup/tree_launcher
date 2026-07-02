/// A single comment on a Jira issue. Bodies are plain wiki-markup strings on
/// Jira Server/Data Center (not Cloud ADF JSON), so [body] is just a String.
class JiraComment {
  final String author;
  final String body;
  final DateTime? created;

  const JiraComment({
    required this.author,
    required this.body,
    this.created,
  });

  /// Parses the comment shape from the raw Jira REST API
  /// (`fields.comment.comments[]`).
  factory JiraComment.fromApiJson(Map<String, dynamic> json) {
    final author = json['author'];
    return JiraComment(
      author: author is Map<String, dynamic>
          ? (author['displayName'] as String? ?? '')
          : '',
      body: json['body'] as String? ?? '',
      created: DateTime.tryParse(json['created'] as String? ?? ''),
    );
  }

  /// Parses the flat shape written by [toJson] (used by the on-disk cache).
  factory JiraComment.fromJson(Map<String, dynamic> json) {
    return JiraComment(
      author: json['author'] as String? ?? '',
      body: json['body'] as String? ?? '',
      created: DateTime.tryParse(json['created'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'author': author,
    'body': body,
    if (created != null) 'created': created!.toIso8601String(),
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
  final String? issueType;
  final String? assignee;
  final String? priority;
  final String? description;
  final DateTime? updated;
  final List<JiraComment> comments;

  const JiraIssue({
    required this.key,
    required this.summary,
    this.status,
    this.issueType,
    this.assignee,
    this.priority,
    this.description,
    this.updated,
    this.comments = const [],
  });

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
    final comment = fields['comment'];
    final rawComments = comment is Map<String, dynamic>
        ? (comment['comments'] as List<dynamic>? ?? const [])
        : const [];

    return JiraIssue(
      key: json['key'] as String? ?? '',
      summary: fields['summary'] as String? ?? '',
      status: _nestedName(fields, 'status'),
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
    );
  }

  /// Parses the flat shape written by [toJson] (used by the on-disk cache).
  factory JiraIssue.fromJson(Map<String, dynamic> json) {
    final rawComments = json['comments'] as List<dynamic>? ?? const [];
    return JiraIssue(
      key: json['key'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      status: json['status'] as String?,
      issueType: json['issueType'] as String?,
      assignee: json['assignee'] as String?,
      priority: json['priority'] as String?,
      description: json['description'] as String?,
      updated: DateTime.tryParse(json['updated'] as String? ?? ''),
      comments: rawComments
          .whereType<Map<String, dynamic>>()
          .map(JiraComment.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'summary': summary,
    if (status != null) 'status': status,
    if (issueType != null) 'issueType': issueType,
    if (assignee != null) 'assignee': assignee,
    if (priority != null) 'priority': priority,
    if (description != null) 'description': description,
    if (updated != null) 'updated': updated!.toIso8601String(),
    'comments': comments.map((c) => c.toJson()).toList(),
  };

  JiraIssue copyWith({
    String? key,
    String? summary,
    String? status,
    String? issueType,
    String? assignee,
    String? priority,
    String? description,
    DateTime? updated,
    List<JiraComment>? comments,
  }) {
    return JiraIssue(
      key: key ?? this.key,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      issueType: issueType ?? this.issueType,
      assignee: assignee ?? this.assignee,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      updated: updated ?? this.updated,
      comments: comments ?? this.comments,
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
