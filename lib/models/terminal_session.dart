import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

class TerminalSession {
  final String title;
  final String workingDirectory;
  final String repoPath;
  final String? command;
  final Terminal terminal;
  final Pty _pty;
  late final StreamSubscription<List<int>> _outputSub;
  bool _disposed = false;

  TerminalSession._({
    required this.title,
    required this.workingDirectory,
    required this.repoPath,
    this.command,
    required this.terminal,
    required Pty pty,
  }) : _pty = pty {
    // PTY output → terminal display
    _outputSub = _pty.output.listen((data) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    });

    // Terminal user input → PTY stdin
    terminal.onOutput = (data) {
      _pty.write(utf8.encode(data));
    };

    // Terminal resize (from TerminalView autoResize) → PTY resize
    terminal.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
      if (!_disposed) {
        _pty.resize(height, width);
      }
    };
  }

  /// Factory that creates a session and starts the PTY process.
  /// Inherits the current process environment with TERM override.
  factory TerminalSession({
    required String title,
    required String workingDirectory,
    required String repoPath,
    String? command,
  }) {
    final env = Map<String, String>.from(Platform.environment)
      ..['TERM'] = 'xterm-256color';

    final terminal = Terminal(maxLines: 10000);
    final pty = Pty.start(
      '/bin/zsh',
      arguments: ['-l'],
      workingDirectory: workingDirectory,
      environment: env,
    );

    return TerminalSession._(
      title: title,
      workingDirectory: workingDirectory,
      repoPath: repoPath,
      command: command,
      terminal: terminal,
      pty: pty,
    );
  }

  /// Writes an initial command to the PTY (e.g., for custom commands).
  void sendCommand(String command) {
    if (_disposed) return;
    _pty.write(utf8.encode('$command\n'));
  }

  /// Future that completes when the shell process exits.
  Future<int> get exitCode => _pty.exitCode;

  bool get isDisposed => _disposed;

  /// Gracefully closes the session by sending SIGINT first (like Ctrl+C),
  /// then escalating to SIGTERM and SIGKILL if the process doesn't exit.
  Future<void> gracefulClose() async {
    if (_disposed) return;
    _disposed = true;
    _outputSub.cancel();

    // SIGINT (Ctrl+C)
    _pty.kill(ProcessSignal.sigint);
    final exited = await _pty.exitCode
        .timeout(const Duration(seconds: 2), onTimeout: () => -1);
    if (exited != -1) return;

    // SIGTERM
    _pty.kill(ProcessSignal.sigterm);
    final exited2 = await _pty.exitCode
        .timeout(const Duration(seconds: 1), onTimeout: () => -1);
    if (exited2 != -1) return;

    // SIGKILL as last resort
    _pty.kill(ProcessSignal.sigkill);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _outputSub.cancel();
    _pty.kill();
  }
}
