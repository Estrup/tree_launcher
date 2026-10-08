class GithubConfig {
  final String owner;
  final String repo;
  final String token;

  /// How often the PR list auto-refreshes, in minutes.
  final int prRefreshIntervalMinutes;

  GithubConfig({
    required this.owner,
    required this.repo,
    required this.token,
    this.prRefreshIntervalMinutes = 5,
  });

  factory GithubConfig.fromJson(Map<String, dynamic> json) {
    return GithubConfig(
      owner: json['owner'] as String,
      repo: json['repo'] as String,
      token: json['token'] as String,
      prRefreshIntervalMinutes: json['prRefreshIntervalMinutes'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner': owner,
    'repo': repo,
    'token': token,
    'prRefreshIntervalMinutes': prRefreshIntervalMinutes,
  };

  GithubConfig copyWith({
    String? owner,
    String? repo,
    String? token,
    int? prRefreshIntervalMinutes,
  }) {
    return GithubConfig(
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      token: token ?? this.token,
      prRefreshIntervalMinutes:
          prRefreshIntervalMinutes ?? this.prRefreshIntervalMinutes,
    );
  }

  bool get isConfigured =>
      owner.isNotEmpty && repo.isNotEmpty && token.isNotEmpty;
}
