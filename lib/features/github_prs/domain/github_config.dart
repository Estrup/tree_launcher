class GithubConfig {
  final String owner;
  final String repo;
  final String token;

  /// How often the PR list auto-refreshes, in minutes.
  final int prRefreshIntervalMinutes;

  /// When true, a worktree is automatically created for a PR's head branch
  /// whenever the current user is requested as a reviewer on it.
  final bool autoCreateWorktreeOnReviewRequest;

  GithubConfig({
    required this.owner,
    required this.repo,
    required this.token,
    this.prRefreshIntervalMinutes = 5,
    this.autoCreateWorktreeOnReviewRequest = true,
  });

  factory GithubConfig.fromJson(Map<String, dynamic> json) {
    return GithubConfig(
      owner: json['owner'] as String,
      repo: json['repo'] as String,
      token: json['token'] as String,
      prRefreshIntervalMinutes: json['prRefreshIntervalMinutes'] as int? ?? 5,
      autoCreateWorktreeOnReviewRequest:
          json['autoCreateWorktreeOnReviewRequest'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner': owner,
    'repo': repo,
    'token': token,
    'prRefreshIntervalMinutes': prRefreshIntervalMinutes,
    'autoCreateWorktreeOnReviewRequest': autoCreateWorktreeOnReviewRequest,
  };

  GithubConfig copyWith({
    String? owner,
    String? repo,
    String? token,
    int? prRefreshIntervalMinutes,
    bool? autoCreateWorktreeOnReviewRequest,
  }) {
    return GithubConfig(
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      token: token ?? this.token,
      prRefreshIntervalMinutes:
          prRefreshIntervalMinutes ?? this.prRefreshIntervalMinutes,
      autoCreateWorktreeOnReviewRequest: autoCreateWorktreeOnReviewRequest ??
          this.autoCreateWorktreeOnReviewRequest,
    );
  }

  bool get isConfigured =>
      owner.isNotEmpty && repo.isNotEmpty && token.isNotEmpty;
}
