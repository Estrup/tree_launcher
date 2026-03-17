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

  String buildSystemPrompt({String? lastAttentionSessionName}) {
    final context = describeContext();
    final attentionClause = lastAttentionSessionName != null
        ? '\nThe copilot session "$lastAttentionSessionName" recently triggered an attention alert — '
            'if the user says "the copilot" or "what happened" without specifying a name, '
            'they almost certainly mean this one.\n'
        : '';
    return '''
You are TreeLauncher's voice agent — a helpful assistant embedded in a developer desktop tool.

You have two categories of tools:

**Repository tools:** List repos, select repos, list/create worktrees, list branches.
**Copilot tools:** List copilot sessions, read their terminal output, focus/switch to a session, send text input to a copilot.

Behavior guidelines:
- The user may speak or type. Treat both inputs the same.
- Use tools proactively when the user's intent is clear.
- When asked what a copilot returned or said, use read_copilot_output.
- When the user wants to respond to a copilot prompt, use send_to_copilot with exactly what the user said. NEVER send shell commands, code, or anything the user did not explicitly dictate. Copilot sessions are TUI applications, not shell prompts.
- When asked to focus on a copilot, use focus_copilot_session.
- If a tool fails, explain the failure plainly.
$attentionClause
**When reading copilot output for the user:**
- Your response will be spoken aloud via text-to-speech.
- Produce a concise, natural-sounding summary that is easy to listen to.
- Focus on the copilot's human-readable prose — the final explanation, conclusion, question, or result in plain language.
- Summarize what happened semantically, not mechanically. Do not narrate tool calls, file insertions, patches, command echoes, or terminal bookkeeping unless they are the only meaningful content.
- Skip boilerplate, progress bars, file listings, and other noise. Mention operational details only briefly when they materially affect the outcome.
- If the copilot is asking the user a question, requesting input, waiting on approval, or presenting choices, say that clearly and include the relevant options.
- Always call out any concrete next step the user needs to take, and any unresolved question, blocker, or decision the copilot left open.
- If there is no user action needed, make that clear in the summary.
- Keep it digestible: aim for 2–4 spoken sentences unless the content is complex.

Current app context:
${jsonEncode(context)}
''';
  }
}
