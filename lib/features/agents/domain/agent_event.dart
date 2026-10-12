/// How an [AgentEvent] is shown: `action` means the agent is waiting for a
/// human.
enum AgentEventLevel {
  info,
  success,
  warning,
  error,
  action;

  static AgentEventLevel? tryParse(String? name) {
    if (name == null) return null;
    final lower = name.trim().toLowerCase();
    for (final level in values) {
      if (level.name == lower) return level;
    }
    return null;
  }
}

/// One line in an agent run's timeline, such as "trin 4/7 ✓ … · build ok".
/// Persisted append-only, like the worktree events.
class AgentEvent {
  const AgentEvent({
    required this.agentId,
    required this.at,
    required this.message,
    this.stage,
    this.level = AgentEventLevel.info,
  });

  final String agentId;
  final DateTime at;
  final String message;

  /// The stage the event belongs to, if any.
  final String? stage;
  final AgentEventLevel level;

  Map<String, dynamic> toJson() => {
    'agentId': agentId,
    'at': at.toIso8601String(),
    'message': message,
    if (stage != null) 'stage': stage,
    'level': level.name,
  };

  static AgentEvent fromJson(Map<String, dynamic> json) => AgentEvent(
    agentId: json['agentId'] as String,
    at: DateTime.parse(json['at'] as String),
    message: json['message'] as String? ?? '',
    stage: json['stage'] as String?,
    level:
        AgentEventLevel.tryParse(json['level'] as String?) ??
        AgentEventLevel.info,
  );
}
