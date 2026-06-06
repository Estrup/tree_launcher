/// A single lifecycle event for a worktree — recorded when a worktree is
/// created or closed. Persisted append-only so the history survives even after
/// the worktree (and its per-worktree config metadata) is deleted.
enum WorktreeEventType { created, closed }

class WorktreeEvent {
  final DateTime timestamp;
  final WorktreeEventType type;
  final String repoPath;
  final String repoName;
  final String worktreePath;
  final String worktreeName;
  final String? branch;
  final String? jiraIssue;

  WorktreeEvent({
    required this.timestamp,
    required this.type,
    required this.repoPath,
    required this.repoName,
    required this.worktreePath,
    required this.worktreeName,
    this.branch,
    this.jiraIssue,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'repoPath': repoPath,
    'repoName': repoName,
    'worktreePath': worktreePath,
    'worktreeName': worktreeName,
    if (branch != null) 'branch': branch,
    if (jiraIssue != null) 'jiraIssue': jiraIssue,
  };

  static WorktreeEvent fromJson(Map<String, dynamic> json) {
    return WorktreeEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: WorktreeEventType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => WorktreeEventType.created,
      ),
      repoPath: json['repoPath'] as String? ?? '',
      repoName: json['repoName'] as String? ?? '',
      worktreePath: json['worktreePath'] as String? ?? '',
      worktreeName: json['worktreeName'] as String? ?? '',
      branch: json['branch'] as String?,
      jiraIssue: json['jiraIssue'] as String?,
    );
  }
}
