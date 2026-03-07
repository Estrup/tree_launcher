enum CopilotActivityStatus { idle, working, needsAction }

class CopilotSession {
  final String id;
  final String name;
  final String repoPath;
  final String workingDirectory;
  final DateTime createdAt;

  CopilotSession({
    required this.id,
    required this.name,
    required this.repoPath,
    required this.workingDirectory,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CopilotSession.fromJson(Map<String, dynamic> json) {
    return CopilotSession(
      id: json['id'] as String,
      name: json['name'] as String,
      repoPath: json['repoPath'] as String,
      workingDirectory: json['workingDirectory'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'repoPath': repoPath,
    'workingDirectory': workingDirectory,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CopilotSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
