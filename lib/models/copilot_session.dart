enum CopilotActivityStatus { idle, working, needsAction }

class CopilotSession {
  final String id;
  final String name;
  final String worktreeName;
  final String repoPath;
  final String workingDirectory;
  final DateTime createdAt;

  CopilotSession({
    required this.id,
    required this.name,
    String? worktreeName,
    required this.repoPath,
    required this.workingDirectory,
    DateTime? createdAt,
  }) : worktreeName = worktreeName != null && worktreeName.trim().isNotEmpty
           ? worktreeName
           : name,
       createdAt = createdAt ?? DateTime.now();

  factory CopilotSession.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    return CopilotSession(
      id: json['id'] as String,
      name: name,
      worktreeName: json['worktreeName'] as String? ?? name,
      repoPath: json['repoPath'] as String,
      workingDirectory: json['workingDirectory'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'worktreeName': worktreeName,
    'repoPath': repoPath,
    'workingDirectory': workingDirectory,
    'createdAt': createdAt.toIso8601String(),
  };

  CopilotSession copyWith({
    String? name,
    String? worktreeName,
    String? repoPath,
    String? workingDirectory,
    DateTime? createdAt,
  }) {
    return CopilotSession(
      id: id,
      name: name ?? this.name,
      worktreeName: worktreeName ?? this.worktreeName,
      repoPath: repoPath ?? this.repoPath,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CopilotSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
