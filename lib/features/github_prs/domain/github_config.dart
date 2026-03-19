class GithubConfig {
  final String owner;
  final String repo;
  final String token;

  GithubConfig({
    required this.owner,
    required this.repo,
    required this.token,
  });

  factory GithubConfig.fromJson(Map<String, dynamic> json) {
    return GithubConfig(
      owner: json['owner'] as String,
      repo: json['repo'] as String,
      token: json['token'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner': owner,
    'repo': repo,
    'token': token,
  };

  GithubConfig copyWith({
    String? owner,
    String? repo,
    String? token,
  }) {
    return GithubConfig(
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      token: token ?? this.token,
    );
  }

  bool get isConfigured =>
      owner.isNotEmpty && repo.isNotEmpty && token.isNotEmpty;
}
