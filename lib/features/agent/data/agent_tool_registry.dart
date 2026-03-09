import 'dart:convert';

import 'package:tree_launcher/features/agent/data/copilot_tool_registry.dart';
import 'package:tree_launcher/services/chatgpt_service.dart';
import 'package:tree_launcher/services/repo_action_tool_registry.dart';

/// Composes the repo action tools and copilot tools into a single registry
/// that implements [ToolRegistryInterface] for the ChatGptService.
class AgentToolRegistry implements ToolRegistryInterface {
  AgentToolRegistry({
    required RepoActionToolRegistry repoToolRegistry,
    required CopilotToolRegistry copilotToolRegistry,
  }) : _repoToolRegistry = repoToolRegistry,
       _copilotToolRegistry = copilotToolRegistry;

  final RepoActionToolRegistry _repoToolRegistry;
  final CopilotToolRegistry _copilotToolRegistry;

  static const _repoTools = {
    'list_repositories',
    'select_repository',
    'list_worktrees',
    'list_branches',
    'create_worktree',
  };

  static const _copilotTools = {
    'list_copilot_sessions',
    'read_copilot_output',
    'focus_copilot_session',
    'send_to_copilot',
  };

  @override
  List<Map<String, dynamic>> buildToolDefinitions() => [
    ..._repoToolRegistry.buildToolDefinitions(),
    ..._copilotToolRegistry.buildToolDefinitions(),
  ];

  @override
  Map<String, dynamic> describeContext() => {
    ..._repoToolRegistry.describeContext(),
    ..._copilotToolRegistry.describeContext(),
  };

  @override
  Future<RepoActionToolResult> executeTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    if (_repoTools.contains(name)) {
      return _repoToolRegistry.executeTool(name, arguments);
    }
    if (_copilotTools.contains(name)) {
      final result = await _copilotToolRegistry.executeTool(name, arguments);
      return RepoActionToolResult(
        payload: result.payload,
        summary: result.summary,
      );
    }
    throw ArgumentError('Unknown tool: $name');
  }

  String buildSystemPrompt() {
    final context = describeContext();
    return '''
You are TreeLauncher's voice agent — a helpful assistant embedded in a developer desktop tool.

You have two categories of tools:

**Repository tools:** List repos, select repos, list/create worktrees, list branches.
**Copilot tools:** List copilot sessions, read their terminal output, focus/switch to a session, send text input to a copilot.

Behavior guidelines:
- The user may speak or type. Treat both inputs the same.
- Use tools proactively when the user's intent is clear.
- When asked what a copilot returned or said, use read_copilot_output.
- When the user wants to respond to a copilot prompt, use send_to_copilot.
- When asked to focus on a copilot, use focus_copilot_session.
- Keep responses concise and action-oriented.
- If you read copilot output, summarize the key information rather than repeating everything verbatim.
- If a tool fails, explain the failure plainly.
- If the user asks you to read something aloud or speak, just provide the text response — TTS is handled by the app.

Current app context:
${jsonEncode(context)}
''';
  }
}
