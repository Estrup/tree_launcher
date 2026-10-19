class GithubConfig {
  final String owner;
  final String repo;
  final String token;

  /// How often the PR list auto-refreshes, in minutes.
  final int prRefreshIntervalMinutes;

  /// Whether the repo shows the Issues tab for this repo's GitHub issues.
  /// Off by default: many repos track their issues elsewhere (e.g. Jira).
  final bool issuesEnabled;

  GithubConfig({
    required this.owner,
    required this.repo,
    required this.token,
    this.prRefreshIntervalMinutes = 5,
    this.issuesEnabled = false,
  });

  factory GithubConfig.fromJson(Map<String, dynamic> json) {
    return GithubConfig(
      owner: json['owner'] as String,
      repo: json['repo'] as String,
      token: json['token'] as String,
      prRefreshIntervalMinutes: json['prRefreshIntervalMinutes'] as int? ?? 5,
      issuesEnabled: json['issuesEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner': owner,
    'repo': repo,
    'token': token,
    'prRefreshIntervalMinutes': prRefreshIntervalMinutes,
    'issuesEnabled': issuesEnabled,
  };

  GithubConfig copyWith({
    String? owner,
    String? repo,
    String? token,
    int? prRefreshIntervalMinutes,
    bool? issuesEnabled,
  }) {
    return GithubConfig(
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      token: token ?? this.token,
      prRefreshIntervalMinutes:
          prRefreshIntervalMinutes ?? this.prRefreshIntervalMinutes,
      issuesEnabled: issuesEnabled ?? this.issuesEnabled,
    );
  }

  bool get isConfigured =>
      owner.isNotEmpty && repo.isNotEmpty && token.isNotEmpty;

  /// Whether the Issues tab is shown: configured, with issues turned on.
  bool get showsIssues => isConfigured && issuesEnabled;
}
