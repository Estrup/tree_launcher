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

  Pty? _pty;
  StreamSubscription<String>? _outputSub;
  bool _disposed = false;
  bool _ptyStarted = false;
  final Completer<int> _exitCodeCompleter = Completer<int>();

  TerminalSession({
    required this.title,
    required this.workingDirectory,
    required this.repoPath,
    this.command,
  }) : terminal = Terminal(maxLines: 10000);

  /// Start the PTY process. Must be called after the TerminalView has been
  /// laid out so that [terminal.viewWidth] and [terminal.viewHeight] reflect
  /// the actual view dimensions. Following the official xterm.dart example
  /// pattern, call this from `WidgetsBinding.instance.endOfFrame`.
  void startPty() {
    if (_ptyStarted || _disposed) return;
    _ptyStarted = true;

    final env = Map<String, String>.from(Platform.environment);

    final pty = Pty.start(
      '/bin/zsh',
      arguments: ['-l'],
      workingDirectory: workingDirectory,
      environment: env,
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
    );
    _pty = pty;

    // PTY output → terminal display (Utf8Decoder maintains state across chunks)
    _outputSub = pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(terminal.write);

    // Terminal user input → PTY stdin
    terminal.onOutput = (data) {
      pty.write(utf8.encode(data));
    };

    // Terminal resize (from TerminalView autoResize) → PTY resize
    terminal.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
      if (!_disposed) {
        pty.resize(height, width);
      }
    };

    pty.exitCode.then((code) {
      if (!_exitCodeCompleter.isCompleted) {
        _exitCodeCompleter.complete(code);
      }
    });
  }

  bool get isPtyStarted => _ptyStarted;

  /// Writes an initial command to the PTY (e.g., for custom commands).
  void sendCommand(String command) {
    if (_disposed || _pty == null) return;
    _pty!.write(utf8.encode('$command\n'));
  }

  /// Future that completes when the shell process exits.
  Future<int> get exitCode => _exitCodeCompleter.future;

  bool get isDisposed => _disposed;

  /// Gracefully closes the session by sending SIGINT first (like Ctrl+C),
  /// then escalating to SIGTERM and SIGKILL if the process doesn't exit.
  Future<void> gracefulClose() async {
    if (_disposed) return;
    _disposed = true;
    _outputSub?.cancel();

    final pty = _pty;
    if (pty == null) {
      if (!_exitCodeCompleter.isCompleted) {
        _exitCodeCompleter.complete(-1);
      }
      return;
    }

    // SIGINT (Ctrl+C)
    pty.kill(ProcessSignal.sigint);
    final exited = await pty.exitCode
        .timeout(const Duration(seconds: 2), onTimeout: () => -1);
    if (exited != -1) return;

    // SIGTERM
    pty.kill(ProcessSignal.sigterm);
    final exited2 = await pty.exitCode
        .timeout(const Duration(seconds: 1), onTimeout: () => -1);
    if (exited2 != -1) return;

    // SIGKILL as last resort
    pty.kill(ProcessSignal.sigkill);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _outputSub?.cancel();
    _pty?.kill();
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(-1);
    }
  }
}
