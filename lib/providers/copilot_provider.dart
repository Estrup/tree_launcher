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

  CopilotProvider({required RepoProvider repoProvider})
      : _repoProvider = repoProvider;

  CopilotSession? get activeSession => _activeSession;

  TerminalSession? get activeTerminal =>
      _activeSession != null ? _terminals[_activeSession!.id] : null;

  /// Creates a new copilot session, persists it, and activates it.
  Future<CopilotSession> createSession(
    String repoPath,
    String workingDirectory,
    String worktreeName,
  ) async {
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

    _activateSession(session);
    return session;
  }

  /// Selects an existing session and opens its terminal.
  void selectSession(CopilotSession session) {
    _activateSession(session);
  }

  /// Deselects the active session, returning to normal worktree view.
  void deselectSession() {
    _activeSession = null;
    notifyListeners();
  }

  /// Removes a session from config and cleans up its terminal.
  Future<void> removeSession(CopilotSession session) async {
    // Clean up terminal
    final terminal = _terminals.remove(session.id);
    terminal?.dispose();

    if (_activeSession == session) {
      _activeSession = null;
    }

    // Remove from repo config
    final repo = _repoProvider.selectedRepo;
    if (repo != null) {
      final sessions =
          repo.copilotSessions.where((s) => s.id != session.id).toList();
      await _repoProvider.updateRepoCopilotSessions(repo, sessions);
    }

    notifyListeners();
  }

  void _activateSession(CopilotSession session) {
    _activeSession = session;

    // Create terminal if not already running
    if (!_terminals.containsKey(session.id) ||
        _terminals[session.id]!.isDisposed) {
      final terminal = TerminalSession(
        title: session.name,
        workingDirectory: session.workingDirectory,
        repoPath: session.repoPath,
        command: 'copilot --resume ${session.id}',
      );
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
