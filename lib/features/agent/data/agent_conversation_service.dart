import 'package:tree_launcher/features/agent/data/agent_tool_registry.dart';
import 'package:tree_launcher/features/agent/domain/agent_message.dart';
import 'package:tree_launcher/features/voice_commands/data/chatgpt_service.dart';

class AgentConversationService {
  AgentConversationService({
    required ChatGptService chatGptService,
  }) : _chatGptService = chatGptService;

  final ChatGptService _chatGptService;
  final List<AgentMessage> _messages = [];

  List<AgentMessage> get messages => List.unmodifiable(_messages);

  /// Send a text message and get an assistant response.
  Future<AgentMessage> sendMessage({
    required String text,
    required String apiKey,
    required String model,
    required AgentToolRegistry toolRegistry,
    String? lastAttentionSessionName,
  }) async {
    final userMessage = AgentMessage(
      role: AgentMessageRole.user,
      content: text,
    );
    _messages.add(userMessage);

    final openAiMessages = _messages
        .where((m) =>
            m.role == AgentMessageRole.user ||
            m.role == AgentMessageRole.assistant)
        .map((m) => m.toOpenAiMessage())
        .toList();

    final result = await _chatGptService.chatWithHistory(
      apiKey: apiKey,
      messages: openAiMessages,
      model: model,
      toolRegistry: toolRegistry,
      systemPrompt: toolRegistry.buildSystemPrompt(
        lastAttentionSessionName: lastAttentionSessionName,
      ),
    );

    final assistantMessage = AgentMessage(
      role: AgentMessageRole.assistant,
      content: result.responseText,
      toolSummaries: result.toolSummaries,
    );
    _messages.add(assistantMessage);

    return assistantMessage;
  }

  /// Add a user message from voice transcription then get a response.
  Future<AgentMessage> sendVoiceTranscript({
    required String transcript,
    required String apiKey,
    required String model,
    required AgentToolRegistry toolRegistry,
    String? lastAttentionSessionName,
  }) {
    return sendMessage(
      text: transcript,
      apiKey: apiKey,
      model: model,
      toolRegistry: toolRegistry,
      lastAttentionSessionName: lastAttentionSessionName,
    );
  }

  void clearHistory() {
    _messages.clear();
  }
}
