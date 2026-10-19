import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';

/// The three states a GitHub issue can be in, as GitHub shows them.
enum GithubIssueState {
  open('Open'),
  closed('Closed'),
  notPlanned('Not planned');

  const GithubIssueState(this.label);

  final String label;

  /// Reads the REST API's `state` and `state_reason`: a closed issue is not
  /// planned when closed as not planned or as a duplicate.
  static GithubIssueState fromApi(String? state, String? stateReason) {
    if (state != 'closed') return GithubIssueState.open;
    return stateReason == 'not_planned' || stateReason == 'duplicate'
        ? GithubIssueState.notPlanned
        : GithubIssueState.closed;
  }

  static GithubIssueState? tryParse(String? name) =>
      values.where((s) => s.name == name).firstOrNull;
}

/// A comment on a GitHub issue. Bodies are GitHub markdown.
class GithubIssueComment {
  final String author;
  final String body;
  final DateTime? created;

  const GithubIssueComment({
    required this.author,
    required this.body,
    this.created,
  });

  /// Parses an item of `GET /repos/{o}/{r}/issues/{n}/comments`.
  factory GithubIssueComment.fromApiJson(Map<String, dynamic> json) {
    final user = json['user'];
    return GithubIssueComment(
      author: user is Map<String, dynamic>
          ? (user['login'] as String? ?? '')
          : '',
      body: json['body'] as String? ?? '',
      created: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  /// Parses the flat shape written by [toJson] (used by the on-disk cache).
  factory GithubIssueComment.fromJson(Map<String, dynamic> json) {
    return GithubIssueComment(
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

/// A GitHub issue's display-relevant fields, from the REST API.
///
/// [GithubIssue.fromApiJson] parses the raw API shape; [GithubIssue.fromJson]
/// and [toJson] use a flat shape for the on-disk cache.
class GithubIssue {
  final int number;
  final String title;
  final GithubIssueState state;
  final String htmlUrl;

  /// Login of whoever opened it.
  final String? author;

  /// Logins of its assignees, in GitHub's order.
  final List<String> assignees;
  final List<GithubLabel> labels;

  /// Title of its milestone.
  final String? milestone;

  /// Its issue type's name, for repos whose organization uses issue types.
  final String? type;
  final String? body;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// How many comments GitHub says it has.
  final int commentCount;

  /// Its comments, oldest first; empty unless fetched for the issue dialog.
  final List<GithubIssueComment> comments;

  const GithubIssue({
    required this.number,
    required this.title,
    required this.state,
    required this.htmlUrl,
    this.author,
    this.assignees = const [],
    this.labels = const [],
    this.milestone,
    this.type,
    this.body,
    this.createdAt,
    this.updatedAt,
    this.commentCount = 0,
    this.comments = const [],
  });

  /// Whether a raw item from the REST issues endpoints is a pull request
  /// (`GET /repos/{o}/{r}/issues` lists those too).
  static bool isPullRequestJson(Map<String, dynamic> json) =>
      json['pull_request'] != null;

  /// Parses a raw issue from the REST API (`GET /repos/{o}/{r}/issues[/{n}]`
  /// or a search result).
  factory GithubIssue.fromApiJson(Map<String, dynamic> json) {
    String? login(Object? user) =>
        user is Map<String, dynamic> ? user['login'] as String? : null;
    final milestone = json['milestone'];
    final type = json['type'];
    return GithubIssue(
      number: json['number'] as int,
      title: json['title'] as String? ?? '',
      state: GithubIssueState.fromApi(
        json['state'] as String?,
        json['state_reason'] as String?,
      ),
      htmlUrl: json['html_url'] as String? ?? '',
      author: login(json['user']),
      assignees: [
        for (final user in json['assignees'] as List<dynamic>? ?? const [])
          ?login(user),
      ],
      labels: [
        for (final label in json['labels'] as List<dynamic>? ?? const [])
          if (label is Map<String, dynamic>) GithubLabel.fromJson(label),
      ],
      milestone: milestone is Map<String, dynamic>
          ? milestone['title'] as String?
          : null,
      type: type is Map<String, dynamic> ? type['name'] as String? : null,
      body: json['body'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      commentCount: json['comments'] as int? ?? 0,
    );
  }

  /// Parses the flat shape written by [toJson] (used by the on-disk cache).
  factory GithubIssue.fromJson(Map<String, dynamic> json) {
    return GithubIssue(
      number: json['number'] as int,
      title: json['title'] as String? ?? '',
      state:
          GithubIssueState.tryParse(json['state'] as String?) ??
          GithubIssueState.open,
      htmlUrl: json['htmlUrl'] as String? ?? '',
      author: json['author'] as String?,
      assignees: (json['assignees'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      labels: (json['labels'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GithubLabel.fromJson)
          .toList(),
      milestone: json['milestone'] as String?,
      type: json['type'] as String?,
      body: json['body'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      commentCount: json['commentCount'] as int? ?? 0,
      comments: (json['comments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GithubIssueComment.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'state': state.name,
    'htmlUrl': htmlUrl,
    if (author != null) 'author': author,
    'assignees': assignees,
    'labels': [for (final label in labels) label.toJson()],
    if (milestone != null) 'milestone': milestone,
    if (type != null) 'type': type,
    if (body != null) 'body': body,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'commentCount': commentCount,
    'comments': [for (final c in comments) c.toJson()],
  };

  GithubIssue copyWith({List<GithubIssueComment>? comments}) {
    return GithubIssue(
      number: number,
      title: title,
      state: state,
      htmlUrl: htmlUrl,
      author: author,
      assignees: assignees,
      labels: labels,
      milestone: milestone,
      type: type,
      body: body,
      createdAt: createdAt,
      updatedAt: updatedAt,
      commentCount: commentCount,
      comments: comments ?? this.comments,
    );
  }
}

/// A [GithubIssue] together with the time it was fetched, so the dialog can
/// show how fresh it is.
class CachedGithubIssue {
  final GithubIssue issue;
  final DateTime fetchedAt;

  const CachedGithubIssue({required this.issue, required this.fetchedAt});
}

/// The key a GitHub issue is known by outside its repo (the issue cache, the
/// local tags), e.g. `owner/repo#482`. Never looks like a Jira key.
String githubIssueRef(String owner, String repo, int number) =>
    '$owner/$repo#$number';
