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

  /// Called when the terminal title changes (e.g. Copilot CLI status icons).
  void Function(String title)? onTitleChange;

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

    // PTY output → terminal display (Utf8Decoder maintains state across chunks).
    // We intercept to handle Kitty keyboard protocol negotiation so that TUI
    // apps (e.g. GitHub Copilot CLI) use the CSI u parser for Shift+Enter.
    _outputSub = pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen((data) {
          data = _handleKittyProtocol(data, pty);
          if (data.isNotEmpty) terminal.write(data);
        });

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

    // Forward terminal title changes
    terminal.onTitleChange = (title) {
      onTitleChange?.call(title);
    };
  }

  /// Intercept Kitty keyboard protocol sequences from PTY output and respond
  /// so that TUI apps detect CSI u support. Strips the protocol control
  /// sequences from the data so the terminal emulator doesn't see them.
  static final _kittyQueryRe = RegExp(r'\x1b\[\?u');
  static final _kittyEnableRe = RegExp(r'\x1b\[>[0-9]*u');
  static final _kittyDisableRe = RegExp(r'\x1b\[<u');

  String _handleKittyProtocol(String data, Pty pty) {
    if (data.contains('\x1b[')) {
      if (_kittyQueryRe.hasMatch(data)) {
        pty.write(utf8.encode('\x1b[?0u'));
        data = data.replaceAll(_kittyQueryRe, '');
      }
      data = data.replaceAll(_kittyEnableRe, '');
      data = data.replaceAll(_kittyDisableRe, '');
    }
    return data;
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
