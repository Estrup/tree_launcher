import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_attention_controller.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/domain/terminal_session.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

class CopilotSessionController extends ChangeNotifier {
  CopilotSessionController({
    required WorkspaceController workspaceController,
    required SettingsController settingsController,
    required CopilotAttentionController attentionController,
    required SoundService soundService,
  }) : _workspaceController = workspaceController,
       _settingsController = settingsController,
       _attentionController = attentionController,
       _soundService = soundService;

  static const _uuid = Uuid();

  WorkspaceController _workspaceController;
  SettingsController _settingsController;
  final CopilotAttentionController _attentionController;
  final SoundService _soundService;

  CopilotSession? _activeSession;
  final Map<String, TerminalSession> _terminals = {};
  final Map<String, int> _focusRequestVersions = {};
  int _focusRequestSerial = 0;

  CopilotSession? get activeSession => _activeSession;

  TerminalSession? get activeTerminal =>
      _activeSession != null ? _terminals[_activeSession!.id] : null;

  TerminalSession? terminalForSession(String sessionId) =>
      _terminals[sessionId];

  int focusRequestVersionForSession(String sessionId) =>
      _focusRequestVersions[sessionId] ?? 0;

  List<CopilotSession> get allSessions =>
      _workspaceController.allCopilotSessions;

  void updateDependencies({
    required WorkspaceController workspaceController,
    required SettingsController settingsController,
  }) {
    _workspaceController = workspaceController;
    _settingsController = settingsController;
  }

  Future<CopilotSession> createSession(
    String repoPath,
    String workingDirectory,
    String worktreeName, {
    String? prompt,
  }) async {
    final session = CopilotSession(
      id: _uuid.v4(),
      name: worktreeName,
      worktreeName: worktreeName,
      repoPath: repoPath,
      workingDirectory: workingDirectory,
    );

    final repo = _workspaceController.selectedRepo;
    if (repo != null) {
      final sessions = [...repo.copilotSessions, session];
      await _workspaceController.updateRepoCopilotSessions(repo, sessions);
    }

    _activateSession(session, initialPrompt: prompt);
    return session;
  }

  void selectSession(CopilotSession session) {
    final currentRepo = _workspaceController.selectedRepo;
    if (currentRepo == null || currentRepo.path != session.repoPath) {
      for (final repo in _workspaceController.repos) {
        if (repo.path == session.repoPath) {
          unawaited(_workspaceController.selectRepo(repo));
          break;
        }
      }
    }
    _activateSession(session);
  }

  void deselectSession() {
    _activeSession = null;
    notifyListeners();
  }

  Future<void> removeSession(CopilotSession session) async {
    final terminal = _terminals.remove(session.id);
    terminal?.dispose();
    _attentionController.removeStatus(session.id);
    _focusRequestVersions.remove(session.id);

    if (_activeSession == session) {
      _activeSession = null;
    }

    for (final repo in _workspaceController.repos) {
      if (repo.path == session.repoPath) {
        final sessions = repo.copilotSessions
            .where((item) => item.id != session.id)
            .toList();
        await _workspaceController.updateRepoCopilotSessions(repo, sessions);
        break;
      }
    }

    notifyListeners();
  }

  void _activateSession(CopilotSession session, {String? initialPrompt}) {
    _activeSession = session;
    _focusRequestVersions[session.id] = ++_focusRequestSerial;

    if (_attentionController.statusForSession(session.id) ==
        CopilotActivityStatus.needsAction) {
      _attentionController.setStatus(session.id, CopilotActivityStatus.idle);
    }

    if (!_terminals.containsKey(session.id) ||
        _terminals[session.id]!.isDisposed) {
      final cliSettings = _settingsController.settings;
      final parts = <String>['copilot'];

      if (cliSettings.copilotModel != null &&
          cliSettings.copilotModel!.isNotEmpty) {
        parts.add('--model "${cliSettings.copilotModel}"');
      }
      if (cliSettings.copilotAllowAll) {
        parts.add('--allow-all');
      } else {
        if (cliSettings.copilotAllowAllTools) parts.add('--allow-all-tools');
        if (cliSettings.copilotAllowAllUrls) parts.add('--allow-all-urls');
        if (cliSettings.copilotAllowAllPaths) parts.add('--allow-all-paths');
      }
      for (final dir in cliSettings.copilotAddDirs) {
        parts.add("--add-dir '${dir.replaceAll("'", "'\\''")}'");
      }
      if (cliSettings.copilotAutopilot) {
        parts.add('--autopilot');
      }

      if (initialPrompt != null && initialPrompt.isNotEmpty) {
        final escapedPrompt = initialPrompt.replaceAll("'", "'\\''");
        parts.add("-i '$escapedPrompt'");
      }
      parts.add('--resume ${session.id}');

      final command = parts.join(' ');

      final terminal = TerminalSession(
        title: session.name,
        workingDirectory: session.workingDirectory,
        repoPath: session.repoPath,
        command: command,
      );

      terminal.onTitleChange = (title) {
        _attentionController.setStatus(
          session.id,
          CopilotAttentionController.parseStatus(title),
        );
        unawaited(_handleTerminalTitleChange(session.id, title));
      };

      terminal.onBell = () {
        if (_attentionController.statusForSession(session.id) ==
            CopilotActivityStatus.needsAction) {
          return;
        }
        _attentionController.setStatus(
          session.id,
          CopilotActivityStatus.needsAction,
        );
        if (_settingsController.settings.copilotAttentionSoundEnabled) {
          unawaited(
            _playAttentionSound(
              _settingsController.settings.copilotAttentionSound,
            ),
          );
        }
      };

      _terminals[session.id] = terminal;
    }

    notifyListeners();
  }

  Future<void> _handleTerminalTitleChange(
    String sessionId,
    String title,
  ) async {
    final session = _sessionById(sessionId);
    if (session == null) {
      return;
    }

    final promotedTitle = _normalizePromotedTitle(session, title);
    if (promotedTitle == null || promotedTitle == session.name) {
      return;
    }

    final updatedSession = session.copyWith(name: promotedTitle);
    await _replaceSession(updatedSession);
  }

  String? _normalizePromotedTitle(CopilotSession session, String title) {
    final normalized = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains('\u{1F916}')) {
      return null;
    }

    final lower = normalized.toLowerCase();
    if (lower == 'zsh' || lower == 'bash' || lower == 'shell') {
      return null;
    }

    if (normalized == session.workingDirectory ||
        normalized == session.repoPath) {
      return null;
    }

    if (normalized == session.worktreeName) {
      return null;
    }

    return normalized;
  }

  CopilotSession? _sessionById(String sessionId) {
    for (final session in _workspaceController.allCopilotSessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  Future<void> _replaceSession(CopilotSession updatedSession) async {
    for (final repo in _workspaceController.repos) {
      if (repo.path != updatedSession.repoPath) {
        continue;
      }

      final index = repo.copilotSessions.indexWhere(
        (session) => session.id == updatedSession.id,
      );
      if (index == -1) {
        return;
      }

      final sessions = [...repo.copilotSessions];
      sessions[index] = updatedSession;
      await _workspaceController.updateRepoCopilotSessions(repo, sessions);
      if (_activeSession?.id == updatedSession.id) {
        _activeSession = updatedSession;
      }
      notifyListeners();
      return;
    }
  }

  void disposeAllTerminals() {
    for (final terminal in _terminals.values) {
      terminal.dispose();
    }
    _terminals.clear();
    _focusRequestVersions.clear();
    _attentionController.clearAll();
    _activeSession = null;
    notifyListeners();
  }

  Future<void> _playAttentionSound(CopilotAttentionSound sound) async {
    try {
      await _soundService.playSystemSound(sound);
    } on MissingPluginException catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tree_launcher.copilot',
          context: ErrorDescription(
            'while playing a Copilot attention sound without a registered platform handler',
          ),
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tree_launcher.copilot',
          context: ErrorDescription(
            'while playing the configured Copilot attention sound',
          ),
        ),
      );
    } on UnsupportedError catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tree_launcher.copilot',
          context: ErrorDescription(
            'while playing a Copilot attention sound on an unsupported platform',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final terminal in _terminals.values) {
      terminal.dispose();
    }
    _terminals.clear();
    _focusRequestVersions.clear();
    super.dispose();
  }
}
