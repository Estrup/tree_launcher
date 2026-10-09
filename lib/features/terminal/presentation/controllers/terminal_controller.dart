import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'package:tree_launcher/features/terminal/domain/terminal_session.dart';

class TerminalController extends ChangeNotifier {
  static const int maxSessions = 8;

  final List<TerminalSession> _sessions = [];
  int _activeIndex = 0;
  bool _visible = false;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  int get activeIndex => _activeIndex;
  bool get isVisible => _visible;
  TerminalSession? get activeSession =>
      _sessions.isNotEmpty && _activeIndex < _sessions.length
      ? _sessions[_activeIndex]
      : null;

  void openTerminal(String title, String workingDirectory, String repoPath) {
    final existing = _sessions.indexWhere(
      (session) =>
          session.workingDirectory == workingDirectory &&
          !session.isClaude &&
          !session.isDisposed,
    );
    if (existing != -1) {
      _activeIndex = existing;
      _visible = true;
      notifyListeners();
      return;
    }

    _evictIfFull();

    final TerminalSession session;
    try {
      session = TerminalSession(
        title: title,
        workingDirectory: workingDirectory,
        repoPath: repoPath,
      );
    } catch (error) {
      debugPrint('Failed to create terminal session: $error');
      return;
    }

    session.exitCode.then((_) {
      if (!session.isDisposed) {
        final index = _sessions.indexOf(session);
        if (index != -1) {
          _closeSessionAt(index);
          notifyListeners();
        }
      }
    });

    _sessions.add(session);
    _activeIndex = _sessions.length - 1;
    _visible = true;
    notifyListeners();
  }

  void openTerminalWithCommand(
    String title,
    String workingDirectory,
    String repoPath,
    String command,
  ) => _openCommandSession(title, workingDirectory, repoPath, command);

  /// The live Claude session running in [workingDirectory], if any.
  TerminalSession? claudeSessionFor(String workingDirectory) {
    for (final session in _sessions) {
      if (session.isClaude &&
          session.workingDirectory == workingDirectory &&
          !session.isDisposed) {
        return session;
      }
    }
    return null;
  }

  /// Shows the live Claude session in [workingDirectory]. Returns false when
  /// there is none.
  bool focusClaudeSession(String workingDirectory) {
    final session = claudeSessionFor(workingDirectory);
    if (session == null) return false;
    _activeIndex = _sessions.indexOf(session);
    _visible = true;
    notifyListeners();
    return true;
  }

  /// Starts a Claude session running [command] in [workingDirectory], or just
  /// shows the one already running there.
  void openClaudeSession(
    String title,
    String workingDirectory,
    String repoPath,
    String command,
  ) {
    if (focusClaudeSession(workingDirectory)) return;
    _openCommandSession(
      title,
      workingDirectory,
      repoPath,
      command,
      isClaude: true,
    );
  }

  void _openCommandSession(
    String title,
    String workingDirectory,
    String repoPath,
    String command, {
    bool isClaude = false,
  }) {
    _evictIfFull();

    final TerminalSession session;
    try {
      session = TerminalSession(
        title: title,
        workingDirectory: workingDirectory,
        repoPath: repoPath,
        command: command,
        isClaude: isClaude,
      );
    } catch (error) {
      debugPrint('Failed to create terminal session: $error');
      return;
    }

    session.exitCode.then((_) {
      if (!session.isDisposed) {
        final index = _sessions.indexOf(session);
        if (index != -1) {
          _closeSessionAt(index);
          notifyListeners();
        }
      }
    });

    _sessions.add(session);
    _activeIndex = _sessions.length - 1;
    _visible = true;
    notifyListeners();

    // Start the PTY and run the command for every command session up front,
    // not just the focused one. Only the active session's _TerminalBody is
    // built, so without this the background sessions wouldn't start their PTY
    // (or run their command) until the user manually focused each tab.
    // Deferred to endOfFrame so the active session's TerminalView has been
    // laid out and reports correct dimensions before startPty(). The
    // !isPtyStarted guards here and in the view make the start idempotent.
    _scheduleCommandStart(session);
  }

  void _scheduleCommandStart(TerminalSession session) {
    SchedulerBinding.instance.endOfFrame.then((_) {
      if (session.isDisposed || session.isPtyStarted) return;
      session.startPty();
      final command = session.command;
      if (command != null) {
        // Match the view's delay so the shell has initialized before input.
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!session.isDisposed) {
            session.sendCommand(command);
          }
        });
      }
    });
  }

  /// Makes room for a new session by closing the oldest non-Claude one. A
  /// running Claude session is never closed silently, so when only Claude
  /// sessions are open the limit is exceeded instead.
  void _evictIfFull() {
    if (_sessions.length < maxSessions) return;
    final oldest = _sessions.indexWhere((session) => !session.isClaude);
    if (oldest != -1) _closeSessionAt(oldest);
  }

  void closeTerminal(int index) {
    if (index < 0 || index >= _sessions.length) return;
    final session = _sessions[index];
    _sessions.removeAt(index);
    if (_activeIndex >= _sessions.length) {
      _activeIndex = (_sessions.length - 1).clamp(0, maxSessions);
    }
    if (_sessions.isEmpty) {
      _visible = false;
    }
    notifyListeners();
    session.gracefulClose();
  }

  void _closeSessionAt(int index) {
    _sessions[index].dispose();
    _sessions.removeAt(index);
    if (_activeIndex >= _sessions.length) {
      _activeIndex = (_sessions.length - 1).clamp(0, maxSessions);
    }
    if (_sessions.isEmpty) {
      _visible = false;
    }
  }

  void setActive(int index) {
    if (index < 0 || index >= _sessions.length) return;
    _activeIndex = index;
    notifyListeners();
  }

  void toggleVisibility() {
    _visible = !_visible;
    notifyListeners();
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  void closeSessionsForPath(String path) {
    _sessions
        .where((session) => session.workingDirectory == path)
        .toList()
        .forEach((session) {
          final index = _sessions.indexOf(session);
          if (index != -1) _closeSessionAt(index);
        });
    notifyListeners();
  }

  void closeSessionsForRepo(String repoPath) {
    _sessions.where((session) => session.repoPath == repoPath).toList().forEach(
      (session) {
        final index = _sessions.indexOf(session);
        if (index != -1) _closeSessionAt(index);
      },
    );
    notifyListeners();
  }

  @override
  void dispose() {
    for (final session in _sessions) {
      session.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}
