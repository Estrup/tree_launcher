import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/copilot_session.dart';
import '../models/terminal_session.dart';
import '../providers/repo_provider.dart';

class CopilotProvider extends ChangeNotifier {
  final RepoProvider _repoProvider;
  static const _uuid = Uuid();

  CopilotSession? _activeSession;
  final Map<String, TerminalSession> _terminals = {};
  final Map<String, CopilotActivityStatus> _sessionStatuses = {};

  CopilotProvider({required RepoProvider repoProvider})
      : _repoProvider = repoProvider;

  CopilotSession? get activeSession => _activeSession;

  TerminalSession? get activeTerminal =>
      _activeSession != null ? _terminals[_activeSession!.id] : null;

  /// Returns the terminal session for a given copilot session ID, if running.
  TerminalSession? terminalForSession(String sessionId) => _terminals[sessionId];

  /// All copilot sessions across all repos.
  List<CopilotSession> get allSessions => _repoProvider.allCopilotSessions;

  /// Returns the activity status for a given copilot session.
  CopilotActivityStatus statusForSession(String id) =>
      _sessionStatuses[id] ?? CopilotActivityStatus.idle;

  /// True if any copilot session is working or needs action.
  bool get hasAnyActivity => _sessionStatuses.values.any(
      (s) => s == CopilotActivityStatus.working || s == CopilotActivityStatus.needsAction);

  /// Returns the most urgent status across all sessions (needsAction > working > idle).
  CopilotActivityStatus get aggregateStatus {
    if (_sessionStatuses.values.any((s) => s == CopilotActivityStatus.needsAction)) {
      return CopilotActivityStatus.needsAction;
    }
    if (_sessionStatuses.values.any((s) => s == CopilotActivityStatus.working)) {
      return CopilotActivityStatus.working;
    }
    return CopilotActivityStatus.idle;
  }

  /// Returns copilot sessions that currently need user action.
  List<CopilotSession> get sessionsNeedingAction {
    return allSessions
        .where((s) => _sessionStatuses[s.id] == CopilotActivityStatus.needsAction)
        .toList();
  }

  /// Parses a terminal title and returns the corresponding activity status.
  static CopilotActivityStatus _parseStatus(String title) {
    if (title.contains('\u{1F916}')) return CopilotActivityStatus.working; // 🤖
    return CopilotActivityStatus.idle;
  }

  /// Creates a new copilot session, persists it, and activates it.
  Future<CopilotSession> createSession(
    String repoPath,
    String workingDirectory,
    String worktreeName, {
    String? prompt,
  }) async {
    final id = _uuid.v4();
    final session = CopilotSession(
      id: id,
      name: worktreeName,
      repoPath: repoPath,
      workingDirectory: workingDirectory,
    );

    // Persist to repo config
    final repo = _repoProvider.selectedRepo;
    if (repo != null) {
      final sessions = [...repo.copilotSessions, session];
      await _repoProvider.updateRepoCopilotSessions(repo, sessions);
    }

    _activateSession(session, initialPrompt: prompt);
    return session;
  }

  /// Selects an existing session and opens its terminal.
  /// Auto-switches to the session's repo if it differs from the current selection.
  void selectSession(CopilotSession session) {
    final currentRepo = _repoProvider.selectedRepo;
    if (currentRepo == null || currentRepo.path != session.repoPath) {
      final repos = _repoProvider.repos;
      for (final repo in repos) {
        if (repo.path == session.repoPath) {
          _repoProvider.selectRepo(repo);
          break;
        }
      }
    }
    _activateSession(session);
  }

  /// Deselects the active session, returning to normal worktree view.
  void deselectSession() {
    _activeSession = null;
    notifyListeners();
  }

  /// Removes a session from config and cleans up its terminal.
  Future<void> removeSession(CopilotSession session) async {
    // Clean up terminal and status
    final terminal = _terminals.remove(session.id);
    terminal?.dispose();
    _sessionStatuses.remove(session.id);

    if (_activeSession == session) {
      _activeSession = null;
    }

    // Remove from the session's owning repo (found by repoPath)
    for (final repo in _repoProvider.repos) {
      if (repo.path == session.repoPath) {
        final sessions =
            repo.copilotSessions.where((s) => s.id != session.id).toList();
        await _repoProvider.updateRepoCopilotSessions(repo, sessions);
        break;
      }
    }

    notifyListeners();
  }

  void _activateSession(CopilotSession session, {String? initialPrompt}) {
    _activeSession = session;

    // Clear needsAction when user navigates to this session
    if (_sessionStatuses[session.id] == CopilotActivityStatus.needsAction) {
      _sessionStatuses[session.id] = CopilotActivityStatus.idle;
    }

    // Create terminal if not already running
    if (!_terminals.containsKey(session.id) ||
        _terminals[session.id]!.isDisposed) {
      String command = 'copilot --resume ${session.id}';
      if (initialPrompt != null && initialPrompt.isNotEmpty) {
        final escapedPrompt = initialPrompt.replaceAll("'", "'\\''");
        command = "copilot -i '$escapedPrompt' --resume ${session.id}";
      }
      final terminal = TerminalSession(
        title: session.name,
        workingDirectory: session.workingDirectory,
        repoPath: session.repoPath,
        command: command,
      );

      // Listen for title changes to detect copilot activity status
      terminal.onTitleChange = (title) {
        final newStatus = _parseStatus(title);
        final oldStatus = _sessionStatuses[session.id] ?? CopilotActivityStatus.idle;
        if (newStatus != oldStatus) {
          _sessionStatuses[session.id] = newStatus;
          notifyListeners();
        }
      };

      // Listen for BEL to detect when copilot needs user attention
      terminal.onBell = () {
        _sessionStatuses[session.id] = CopilotActivityStatus.needsAction;
        notifyListeners();
      };

      _terminals[session.id] = terminal;
    }

    notifyListeners();
  }

  /// Dispose all terminals when switching repos.
  void disposeAllTerminals() {
    for (final terminal in _terminals.values) {
      terminal.dispose();
    }
    _terminals.clear();
    _sessionStatuses.clear();
    _activeSession = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final terminal in _terminals.values) {
      terminal.dispose();
    }
    _terminals.clear();
    super.dispose();
  }
}
