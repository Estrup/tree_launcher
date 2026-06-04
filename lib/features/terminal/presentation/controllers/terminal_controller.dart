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
          session.workingDirectory == workingDirectory && !session.isDisposed,
    );
    if (existing != -1) {
      _activeIndex = existing;
      _visible = true;
      notifyListeners();
      return;
    }

    if (_sessions.length >= maxSessions) {
      _closeSessionAt(0);
    }

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
  ) {
    if (_sessions.length >= maxSessions) {
      _closeSessionAt(0);
    }

    final TerminalSession session;
    try {
      session = TerminalSession(
        title: title,
        workingDirectory: workingDirectory,
        repoPath: repoPath,
        command: command,
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

  Future<void> gracefulCloseCommandSessionsForRepo(String repoPath) async {
    final targets = _sessions
        .where(
          (session) =>
              session.repoPath == repoPath &&
              session.command != null &&
              !session.isDisposed,
        )
        .toList();
    if (targets.isEmpty) return;

    for (final session in targets) {
      _sessions.remove(session);
    }
    if (_activeIndex >= _sessions.length) {
      _activeIndex = (_sessions.length - 1).clamp(0, maxSessions);
    }
    if (_sessions.isEmpty) {
      _visible = false;
    }
    notifyListeners();

    await Future.wait(targets.map((session) => session.gracefulClose()));
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
