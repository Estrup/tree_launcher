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
  final List<String> labels;

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
              ?.map((l) => (l as Map<String, dynamic>)['name'] as String)
              .toList() ??
          [],
    );
  }
}
