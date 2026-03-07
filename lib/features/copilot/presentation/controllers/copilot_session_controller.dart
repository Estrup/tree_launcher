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

  CopilotSession? get activeSession => _activeSession;

  TerminalSession? get activeTerminal =>
      _activeSession != null ? _terminals[_activeSession!.id] : null;

  TerminalSession? terminalForSession(String sessionId) =>
      _terminals[sessionId];

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

    if (_attentionController.statusForSession(session.id) ==
        CopilotActivityStatus.needsAction) {
      _attentionController.setStatus(session.id, CopilotActivityStatus.idle);
    }

    if (!_terminals.containsKey(session.id) ||
        _terminals[session.id]!.isDisposed) {
      var command = 'copilot --resume ${session.id}';
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

      terminal.onTitleChange = (title) {
        _attentionController.setStatus(
          session.id,
          CopilotAttentionController.parseStatus(title),
        );
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

  void disposeAllTerminals() {
    for (final terminal in _terminals.values) {
      terminal.dispose();
    }
    _terminals.clear();
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
    super.dispose();
  }
}
