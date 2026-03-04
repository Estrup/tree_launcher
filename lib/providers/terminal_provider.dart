import 'package:flutter/foundation.dart';
import '../models/terminal_session.dart';

class TerminalProvider extends ChangeNotifier {
  static const int maxSessions = 8;
  static const double defaultPanelHeight = 300.0;
  static const double minPanelHeight = 120.0;
  static const double maxPanelHeight = 800.0;

  final List<TerminalSession> _sessions = [];
  int _activeIndex = 0;
  bool _visible = false;
  double _panelHeight = defaultPanelHeight;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  int get activeIndex => _activeIndex;
  bool get isVisible => _visible;
  double get panelHeight => _panelHeight;
  TerminalSession? get activeSession =>
      _sessions.isNotEmpty && _activeIndex < _sessions.length
          ? _sessions[_activeIndex]
          : null;

  /// Opens a terminal for the given worktree. Reuses an existing session if one
  /// is already open for the same working directory. Makes the panel visible.
  void openTerminal(String title, String workingDirectory, String repoPath) {
    // Reuse existing session for same directory
    final existing = _sessions.indexWhere(
      (s) => s.workingDirectory == workingDirectory && !s.isDisposed,
    );
    if (existing != -1) {
      _activeIndex = existing;
      _visible = true;
      notifyListeners();
      return;
    }

    if (_sessions.length >= maxSessions) {
      // Close the oldest session to make room
      _closeSessionAt(0);
    }

    final TerminalSession session;
    try {
      session = TerminalSession(
        title: title,
        workingDirectory: workingDirectory,
        repoPath: repoPath,
      );
    } catch (e) {
      debugPrint('Failed to create terminal session: $e');
      return;
    }

    // Auto-close tab when shell exits
    session.exitCode.then((_) {
      if (!session.isDisposed) {
        final idx = _sessions.indexOf(session);
        if (idx != -1) {
          _closeSessionAt(idx);
          notifyListeners();
        }
      }
    });

    _sessions.add(session);
    _activeIndex = _sessions.length - 1;
    _visible = true;
    notifyListeners();
  }

  /// Opens a new terminal tab and immediately runs the given command.
  /// Always creates a new session (never reuses).
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
    } catch (e) {
      debugPrint('Failed to create terminal session: $e');
      return;
    }

    // Auto-close tab when shell exits
    session.exitCode.then((_) {
      if (!session.isDisposed) {
        final idx = _sessions.indexOf(session);
        if (idx != -1) {
          _closeSessionAt(idx);
          notifyListeners();
        }
      }
    });

    _sessions.add(session);
    _activeIndex = _sessions.length - 1;
    _visible = true;
    notifyListeners();
    // Command is sent by _TerminalBodyState after PTY starts
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

    // Graceful shutdown in background
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

  void setPanelHeight(double height) {
    _panelHeight = height.clamp(minPanelHeight, maxPanelHeight);
    notifyListeners();
  }

  /// Close all sessions whose working directory matches the given path.
  void closeSessionsForPath(String path) {
    _sessions
        .where((s) => s.workingDirectory == path)
        .toList()
        .forEach((s) {
      final idx = _sessions.indexOf(s);
      if (idx != -1) _closeSessionAt(idx);
    });
    notifyListeners();
  }

  /// Gracefully close all command sessions (those with a non-null command)
  /// belonging to a given repo. Removes them from the list immediately so the
  /// UI updates, then awaits graceful shutdown of each in parallel.
  Future<void> gracefulCloseCommandSessionsForRepo(String repoPath) async {
    final targets = _sessions
        .where((s) => s.repoPath == repoPath && s.command != null && !s.isDisposed)
        .toList();
    if (targets.isEmpty) return;

    for (final s in targets) {
      _sessions.remove(s);
    }
    if (_activeIndex >= _sessions.length) {
      _activeIndex = (_sessions.length - 1).clamp(0, maxSessions);
    }
    if (_sessions.isEmpty) {
      _visible = false;
    }
    notifyListeners();

    await Future.wait(targets.map((s) => s.gracefulClose()));
  }

  /// Close all sessions belonging to a given repo.
  void closeSessionsForRepo(String repoPath) {
    _sessions
        .where((s) => s.repoPath == repoPath)
        .toList()
        .forEach((s) {
      final idx = _sessions.indexOf(s);
      if (idx != -1) _closeSessionAt(idx);
    });
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
