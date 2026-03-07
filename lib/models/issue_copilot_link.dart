import 'package:uuid/uuid.dart';

class IssueCopilotLink {
  final String id;
  final String issueId;
  final String copilotSessionId;
  final String? worktreePath;
  final String? branch;
  final DateTime createdAt;

  const IssueCopilotLink({
    required this.id,
    required this.issueId,
    required this.copilotSessionId,
    this.worktreePath,
    this.branch,
    required this.createdAt,
  });

  factory IssueCopilotLink.create({
    required String issueId,
    required String copilotSessionId,
    String? worktreePath,
    String? branch,
  }) {
    return IssueCopilotLink(
      id: const Uuid().v4(),
      issueId: issueId,
      copilotSessionId: copilotSessionId,
      worktreePath: worktreePath,
      branch: branch,
      createdAt: DateTime.now(),
    );
  }

  factory IssueCopilotLink.fromMap(Map<String, dynamic> map) {
    return IssueCopilotLink(
      id: map['id'] as String,
      issueId: map['issue_id'] as String,
      copilotSessionId: map['copilot_session_id'] as String,
      worktreePath: map['worktree_path'] as String?,
      branch: map['branch'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'issue_id': issueId,
    'copilot_session_id': copilotSessionId,
    'worktree_path': worktreePath,
    'branch': branch,
    'created_at': createdAt.toIso8601String(),
  };

  IssueCopilotLink copyWith({String? worktreePath, String? branch}) {
    return IssueCopilotLink(
      id: id,
      issueId: issueId,
      copilotSessionId: copilotSessionId,
      worktreePath: worktreePath ?? this.worktreePath,
      branch: branch ?? this.branch,
      createdAt: createdAt,
    );
  }
}
