import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// A running interactive Claude CLI, as it registers itself in
/// `~/.claude/sessions/<pid>.json`.
class ClaudeCliProcess {
  const ClaudeCliProcess({
    required this.pid,
    required this.sessionId,
    required this.cwd,
    this.status,
  });

  final int pid;
  final String sessionId;
  final String cwd;

  /// `idle`, `shell` (idle with background shells running), `busy`, or
  /// `waiting` (a question or permission prompt is open). Null when unknown.
  final String? status;

  /// Whether the CLI sits at an empty-turn prompt, so typed input goes to the
  /// prompt rather than to a running turn or an open dialog.
  bool get atPrompt => status == 'idle' || status == 'shell';
}

/// Looks up the Claude CLI running inside a terminal from the CLI's own
/// session registry.
class ClaudeCliRegistry {
  ClaudeCliRegistry({
    String? sessionsDir,
    Future<Map<int, int>> Function()? parentPids,
  }) : _sessionsDir = sessionsDir ?? _defaultSessionsDir(),
       _parentPids = parentPids ?? _psParentPids;

  final String? _sessionsDir;
  final Future<Map<int, int>> Function() _parentPids;

  static String? _defaultSessionsDir() {
    final env = Platform.environment;
    final configDir =
        env['CLAUDE_CONFIG_DIR'] ??
        (env['HOME'] == null ? null : p.join(env['HOME']!, '.claude'));
    return configDir == null ? null : p.join(configDir, 'sessions');
  }

  /// Parent pid of every process (pid -> ppid).
  static Future<Map<int, int>> _psParentPids() async {
    final result = await Process.run('ps', ['-A', '-o', 'pid=,ppid=']);
    final parents = <int, int>{};
    if (result.exitCode != 0) return parents;
    for (final line in LineSplitter.split(result.stdout as String)) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length != 2) continue;
      final pid = int.tryParse(fields[0]);
      final ppid = int.tryParse(fields[1]);
      if (pid != null && ppid != null) parents[pid] = ppid;
    }
    return parents;
  }

  /// The interactive Claude CLI running in the process tree under
  /// [shellPid] (the terminal's shell), or null when there is none.
  Future<ClaudeCliProcess?> runningUnder(int shellPid) async {
    final dirPath = _sessionsDir;
    if (dirPath == null) return null;
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return null;
      final parents = await _parentPids();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final cli = _parse(await entity.readAsString());
        if (cli != null && _descendsFrom(cli.pid, shellPid, parents)) {
          return cli;
        }
      }
    } catch (e) {
      debugPrint('ClaudeCliRegistry.runningUnder failed: $e');
    }
    return null;
  }

  static ClaudeCliProcess? _parse(String source) {
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic>) return null;
      final pid = json['pid'];
      final sessionId = json['sessionId'];
      if (pid is! int || sessionId is! String) return null;
      if (json['kind'] != null && json['kind'] != 'interactive') return null;
      return ClaudeCliProcess(
        pid: pid,
        sessionId: sessionId,
        cwd: json['cwd'] as String? ?? '',
        status: json['status'] as String?,
      );
    } on FormatException {
      return null;
    }
  }

  /// Whether [pid] is a live process below [ancestor]. A registry file left
  /// behind by a dead CLI has no entry in [parents], so it never matches.
  static bool _descendsFrom(int pid, int ancestor, Map<int, int> parents) {
    var current = parents[pid];
    for (var depth = 0; current != null && depth < 16; depth++) {
      if (current == ancestor) return true;
      if (current <= 1) return false;
      current = parents[current];
    }
    return false;
  }
}

/// Continues a terminal's Claude session in Claude Desktop.
///
/// When the CLI runs in the terminal, it is handed `/desktop`, its own
/// command for this: it saves the session, opens it in Desktop and exits.
/// Otherwise `claude --desktop --continue` opens the worktree's latest
/// session there.
class ClaudeDesktopHandoff {
  ClaudeDesktopHandoff({
    ClaudeCliRegistry? registry,
    Future<ProcessResult> Function(String workingDirectory)? continueLatest,
    Duration keyDelay = const Duration(milliseconds: 120),
  }) : _registry = registry ?? ClaudeCliRegistry(),
       _continueLatest = continueLatest ?? _runContinueLatest,
       _keyDelay = keyDelay;

  final ClaudeCliRegistry _registry;
  final Future<ProcessResult> Function(String) _continueLatest;
  final Duration _keyDelay;

  static Future<ProcessResult> _runContinueLatest(String workingDirectory) {
    // A login shell, so `claude` resolves on the user's PATH as it does in
    // the terminal (an app started from Finder gets a minimal PATH).
    return Process.run('/bin/zsh', [
      '-lc',
      'claude --desktop --continue',
    ], workingDirectory: workingDirectory);
  }

  /// Hands the session over. [shellPid] is the terminal's shell, and [type]
  /// writes to its input. Returns a message to show when it can't be done,
  /// or null once started (the CLI reports its own progress in the terminal).
  Future<String?> continueInDesktop({
    required int? shellPid,
    required String workingDirectory,
    required void Function(String data) type,
  }) async {
    final cli = shellPid == null
        ? null
        : await _registry.runningUnder(shellPid);

    if (cli != null) {
      switch (cli.status) {
        case 'busy':
          return 'Claude is working. Try again when the turn is done.';
        case 'waiting':
          return 'Claude is waiting for an answer. Reply first, then try again.';
      }
      if (!cli.atPrompt) {
        return 'Claude is not at its prompt. Run /desktop in the terminal.';
      }
      // Clear any draft (Ctrl+L) so the command isn't appended to it, then
      // run /desktop. Keys are sent apart so the CLI reads them as typing,
      // not as one pasted chunk where Enter would be a newline.
      type('\x0c');
      await Future<void>.delayed(_keyDelay);
      type('/desktop');
      await Future<void>.delayed(_keyDelay);
      type('\r');
      return null;
    }

    try {
      final result = await _continueLatest(workingDirectory);
      if (result.exitCode == 0) return null;
      final output = '${result.stderr}'.trim().isNotEmpty
          ? '${result.stderr}'
          : '${result.stdout}';
      final message = output.trim();
      return message.isEmpty
          ? "Couldn't open the session in Claude Desktop."
          : message;
    } catch (e) {
      return "Couldn't open the session in Claude Desktop: $e";
    }
  }
}
