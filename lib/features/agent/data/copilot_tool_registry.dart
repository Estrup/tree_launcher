import 'package:xterm/xterm.dart';

import 'package:tree_launcher/features/copilot/data/copilot_terminal_output.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';

class CopilotToolResult {
  const CopilotToolResult({required this.payload, required this.summary});

  final Map<String, dynamic> payload;
  final String summary;
}

class _CopilotToolDefinition {
  const _CopilotToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toOpenAiJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

class CopilotToolRegistry {
  CopilotToolRegistry({required CopilotController copilotController})
    : _copilotController = copilotController;

  final CopilotController _copilotController;

  List<Map<String, dynamic>> buildToolDefinitions() =>
      _toolDefinitions.map((tool) => tool.toOpenAiJson()).toList();

  Map<String, dynamic> describeContext() {
    final sessions = _copilotController.allSessions;
    return {
      'copilotSessions': sessions.map((s) {
        final status = _copilotController.statusForSession(s.id);
        return {
          'id': s.id,
          'name': s.name,
          'repoPath': s.repoPath,
          'status': status.name,
        };
      }).toList(),
      'activeSessionId': _copilotController.activeSession?.id,
    };
  }

  Future<CopilotToolResult> executeTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    switch (name) {
      case 'list_copilot_sessions':
        return _listCopilotSessions();
      case 'read_copilot_output':
        return _readCopilotOutput(arguments);
      case 'focus_copilot_session':
        return _focusCopilotSession(arguments);
      case 'send_to_copilot':
        return _sendToCopilot(arguments);
    }

    throw ArgumentError('Unsupported copilot tool: $name');
  }

  List<_CopilotToolDefinition> get _toolDefinitions => [
    const _CopilotToolDefinition(
      name: 'list_copilot_sessions',
      description:
          'List all active copilot sessions with their name, status (idle, working, needsAction), and repository path.',
      parameters: {
        'type': 'object',
        'properties': {},
        'required': [],
        'additionalProperties': false,
      },
    ),
    const _CopilotToolDefinition(
      name: 'read_copilot_output',
      description:
          'Read the last N lines of terminal output from a specific copilot session. '
          'Use this when the user asks what a copilot returned or wants to know what happened. '
          'Summaries should focus on the copilot\'s prose, user-facing outcome, next steps, and open questions rather than raw terminal mechanics.',
      parameters: {
        'type': 'object',
        'properties': {
          'sessionName': {
            'type': 'string',
            'description':
                'The name of the copilot session to read output from.',
          },
          'lineCount': {
            'type': 'integer',
            'description':
                'Number of lines to read from the end of the terminal buffer. Defaults to 50.',
          },
        },
        'required': ['sessionName'],
        'additionalProperties': false,
      },
    ),
    const _CopilotToolDefinition(
      name: 'focus_copilot_session',
      description:
          'Switch focus to a specific copilot session tab so the user can see it.',
      parameters: {
        'type': 'object',
        'properties': {
          'sessionName': {
            'type': 'string',
            'description': 'The name of the copilot session to focus.',
          },
        },
        'required': ['sessionName'],
        'additionalProperties': false,
      },
    ),
    const _CopilotToolDefinition(
      name: 'send_to_copilot',
      description:
          'Send the user\'s prose response to a copilot session. The copilot sessions are TUI apps. '
          'Use this ONLY to relay what the user said — answer prompts, make selections, or '
          'provide input the copilot is waiting for. NEVER send shell commands, code, or '
          'anything the user did not explicitly ask to send. A carriage return is appended automatically.',
      parameters: {
        'type': 'object',
        'properties': {
          'sessionName': {
            'type': 'string',
            'description': 'The name of the copilot session to send input to.',
          },
          'text': {
            'type': 'string',
            'description':
                'The exact user prose to send. Do not add shell commands or escape sequences.',
          },
        },
        'required': ['sessionName', 'text'],
        'additionalProperties': false,
      },
    ),
  ];

  CopilotToolResult _listCopilotSessions() {
    final sessions = _copilotController.allSessions;
    final sessionData = sessions.map((s) {
      final status = _copilotController.statusForSession(s.id);
      return {
        'id': s.id,
        'name': s.name,
        'repoPath': s.repoPath,
        'status': status.name,
        'isActive': _copilotController.activeSession?.id == s.id,
      };
    }).toList();

    return CopilotToolResult(
      payload: {'sessions': sessionData},
      summary: sessions.isEmpty
          ? 'No copilot sessions are currently running.'
          : 'Found ${sessions.length} copilot session(s).',
    );
  }

  CopilotToolResult _readCopilotOutput(Map<String, dynamic> arguments) {
    final sessionName = _requireString(arguments, 'sessionName');
    final lineCount = (arguments['lineCount'] as int?) ?? 50;
    final session = _findSessionByName(sessionName);
    final terminalSession = _copilotController.terminalForSession(session.id);

    if (terminalSession == null) {
      return CopilotToolResult(
        payload: {'ok': false, 'error': 'No terminal found for session.'},
        summary: 'No terminal found for copilot "${session.name}".',
      );
    }

    final output = readCopilotTerminalOutput(
      terminalSession,
      lineCount: lineCount,
    );
    return CopilotToolResult(
      payload: {
        'sessionName': session.name,
        'status': _copilotController.statusForSession(session.id).name,
        'output': output,
      },
      summary:
          'Read ${output.split('\n').length} lines from copilot "${session.name}".',
    );
  }

  CopilotToolResult _focusCopilotSession(Map<String, dynamic> arguments) {
    final sessionName = _requireString(arguments, 'sessionName');
    final session = _findSessionByName(sessionName);
    _copilotController.selectSession(session);

    return CopilotToolResult(
      payload: {'sessionName': session.name, 'focused': true},
      summary: 'Focused on copilot "${session.name}".',
    );
  }

  CopilotToolResult _sendToCopilot(Map<String, dynamic> arguments) {
    final sessionName = _requireString(arguments, 'sessionName');
    final text = _requireString(arguments, 'text');
    final session = _findSessionByName(sessionName);
    final terminalSession = _copilotController.terminalForSession(session.id);

    if (terminalSession == null) {
      return CopilotToolResult(
        payload: {'ok': false, 'error': 'No terminal found for session.'},
        summary: 'No terminal found for copilot "${session.name}".',
      );
    }

    // Send the text, then schedule Enter on a separate event loop turn so the
    // TUI processes them as distinct inputs (avoids being batched in one PTY read).
    terminalSession.terminal.textInput(text);
    Future.delayed(const Duration(milliseconds: 500), () {
      terminalSession.terminal.keyInput(TerminalKey.returnKey);
    });
    return CopilotToolResult(
      payload: {'sessionName': session.name, 'sent': true},
      summary: 'Sent input to copilot "${session.name}".',
    );
  }

  CopilotSession _findSessionByName(String name) {
    final normalizedTarget = name.trim().toLowerCase();
    final sessions = _copilotController.allSessions;
    for (final session in sessions) {
      if (session.name.trim().toLowerCase() == normalizedTarget) {
        return session;
      }
    }
    // Fallback: partial match
    for (final session in sessions) {
      if (session.name.trim().toLowerCase().contains(normalizedTarget)) {
        return session;
      }
    }
    throw ArgumentError(
      'Could not find a copilot session named "$name". '
      'Available: ${sessions.map((s) => s.name).join(", ")}',
    );
  }

  String _requireString(Map<String, dynamic> arguments, String key) {
    final value = arguments[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw ArgumentError('Expected a non-empty string argument for "$key".');
  }
}
