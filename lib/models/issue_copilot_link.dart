import 'package:uuid/uuid.dart';

class IssueCopilotLink {
  final String id;
  final String issueId;
  final String copilotSessionId;
  final DateTime createdAt;

  const IssueCopilotLink({
    required this.id,
    required this.issueId,
    required this.copilotSessionId,
    required this.createdAt,
  });

  factory IssueCopilotLink.create({
    required String issueId,
    required String copilotSessionId,
  }) {
    return IssueCopilotLink(
      id: const Uuid().v4(),
      issueId: issueId,
      copilotSessionId: copilotSessionId,
      createdAt: DateTime.now(),
    );
  }

  factory IssueCopilotLink.fromMap(Map<String, dynamic> map) {
    return IssueCopilotLink(
      id: map['id'] as String,
      issueId: map['issue_id'] as String,
      copilotSessionId: map['copilot_session_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'issue_id': issueId,
    'copilot_session_id': copilotSessionId,
    'created_at': createdAt.toIso8601String(),
  };
}
