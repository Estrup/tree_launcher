import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_attention_controller.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_session_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/domain/terminal_session.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

class CopilotController extends ChangeNotifier {
  factory CopilotController.create({
    required WorkspaceController workspaceController,
    required SettingsController settingsController,
    required SoundService soundService,
  }) {
    final attention = CopilotAttentionController();
    return CopilotController._(
      attention: attention,
      session: CopilotSessionController(
        workspaceController: workspaceController,
        settingsController: settingsController,
        attentionController: attention,
        soundService: soundService,
      ),
    );
  }

  CopilotController._({required this.attention, required this.session}) {
    attention.addListener(_relay);
    session.addListener(_relay);
  }

  late final CopilotAttentionController attention;
  late final CopilotSessionController session;

  void _relay() => notifyListeners();

  void updateDependencies({
    required WorkspaceController workspaceController,
    required SettingsController settingsController,
  }) {
    session.updateDependencies(
      workspaceController: workspaceController,
      settingsController: settingsController,
    );
  }

  CopilotSession? get activeSession => session.activeSession;
  TerminalSession? get activeTerminal => session.activeTerminal;
  TerminalSession? terminalForSession(String sessionId) {
    return session.terminalForSession(sessionId);
  }

  int focusRequestVersionForSession(String sessionId) {
    return session.focusRequestVersionForSession(sessionId);
  }

  List<CopilotSession> get allSessions => session.allSessions;

  CopilotActivityStatus statusForSession(String id) =>
      attention.statusForSession(id);

  bool get hasAnyActivity => attention.hasAnyActivity;

  CopilotActivityStatus get aggregateStatus => attention.aggregateStatus;

  List<CopilotSession> get sessionsNeedingAction {
    return attention.sessionsNeedingAction(allSessions);
  }

  Future<CopilotSession> createSession(
    String repoPath,
    String workingDirectory,
    String worktreeName, {
    String? prompt,
  }) {
    return session.createSession(
      repoPath,
      workingDirectory,
      worktreeName,
      prompt: prompt,
    );
  }

  void selectSession(CopilotSession sessionValue) =>
      session.selectSession(sessionValue);

  void deselectSession() => session.deselectSession();

  Future<void> removeSession(CopilotSession sessionValue) {
    return session.removeSession(sessionValue);
  }

  void disposeAllTerminals() => session.disposeAllTerminals();

  @override
  void dispose() {
    attention.removeListener(_relay);
    session.removeListener(_relay);
    attention.dispose();
    session.dispose();
    super.dispose();
  }
}
