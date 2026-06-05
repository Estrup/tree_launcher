class GithubLabel {
  final String name;

  /// 6-hex color from the GitHub API (e.g. "d73a4a"), may be empty.
  final String color;

  GithubLabel({required this.name, required this.color});

  factory GithubLabel.fromJson(Map<String, dynamic> json) {
    return GithubLabel(
      name: json['name'] as String,
      color: (json['color'] as String?) ?? '',
    );
  }
}

class GithubPullRequest {
  final int number;
  final String title;
  final String htmlUrl;
  final DateTime createdAt;
  final String author;
  final String? authorAvatarUrl;
  final String? assignee;
  final String? milestone;
  final String headBranch;
  final String baseBranch;
  final bool draft;
  final List<GithubLabel> labels;
  final List<String> requestedReviewers;

  /// First Jira-style issue key found in the title (e.g. "AU2-5555"), or null.
  /// Jira keys are an uppercase project key + digits, so matching is
  /// case-sensitive and finds the key whether or not it is parenthesized
  /// (e.g. "Fejl fra driften (AU2-5555)" -> "AU2-5555").
  String? get jiraKey =>
      RegExp(r'[A-Z][A-Z0-9]*-\d+').firstMatch(title)?.group(0);

  GithubPullRequest({
    required this.number,
    required this.title,
    required this.htmlUrl,
    required this.createdAt,
    required this.author,
    this.authorAvatarUrl,
    this.assignee,
    this.milestone,
    required this.headBranch,
    required this.baseBranch,
    this.draft = false,
    this.labels = const [],
    this.requestedReviewers = const [],
  });

  factory GithubPullRequest.fromJson(Map<String, dynamic> json) {
    return GithubPullRequest(
      number: json['number'] as int,
      title: json['title'] as String,
      htmlUrl: json['html_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: (json['user'] as Map<String, dynamic>)['login'] as String,
      authorAvatarUrl:
          (json['user'] as Map<String, dynamic>)['avatar_url'] as String?,
      assignee: json['assignee'] != null
          ? (json['assignee'] as Map<String, dynamic>)['login'] as String?
          : null,
      milestone: json['milestone'] != null
          ? (json['milestone'] as Map<String, dynamic>)['title'] as String?
          : null,
      headBranch: (json['head'] as Map<String, dynamic>)['ref'] as String,
      baseBranch: (json['base'] as Map<String, dynamic>)['ref'] as String,
      draft: json['draft'] as bool? ?? false,
      labels: (json['labels'] as List<dynamic>?)
              ?.map((l) => GithubLabel.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      requestedReviewers: (json['requested_reviewers'] as List<dynamic>?)
              ?.map((r) => (r as Map<String, dynamic>)['login'] as String)
              .toList() ??
          [],
    );
  }
}
