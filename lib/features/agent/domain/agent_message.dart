import 'package:uuid/uuid.dart';

enum AgentMessageRole { user, assistant, system, tool }

class AgentMessage {
  final String id;
  final AgentMessageRole role;
  final String content;
  final DateTime timestamp;

  /// Tool call summaries attached to an assistant message.
  final List<String> toolSummaries;

  /// If true, this message is still being generated (streaming placeholder).
  final bool isStreaming;

  AgentMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.toolSummaries = const [],
    this.isStreaming = false,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  AgentMessage copyWith({
    String? content,
    List<String>? toolSummaries,
    bool? isStreaming,
  }) {
    return AgentMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      toolSummaries: toolSummaries ?? this.toolSummaries,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// Convert to OpenAI chat message format.
  Map<String, dynamic> toOpenAiMessage() => {
    'role': role == AgentMessageRole.assistant ? 'assistant' : 'user',
    'content': content,
  };
}
