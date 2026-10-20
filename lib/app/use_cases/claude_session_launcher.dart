import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/agents/domain/agent_environment.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// Terminal tab title for the Claude session in [worktreePath], naming
/// [issueKey] too when the worktree's name doesn't, so sessions sharing a
/// checkout can be told apart.
String claudeSessionTitle(String worktreePath, {String? issueKey}) {
  final name = p.basename(worktreePath);
  if (issueKey == null || name.toUpperCase().contains(issueKey.toUpperCase())) {
    return 'Claude: $name';
  }
  return 'Claude: $name · $issueKey';
}

/// Starts and resumes Claude CLI sessions in the built-in terminal, and keeps
/// their sidebar shortcuts. Built once by the composition root and provided
/// to the widget tree, so a dialog can use it after it closes regardless of
/// what rebuilt.
class ClaudeSessionLauncher {
  ClaudeSessionLauncher({
    required TerminalController terminal,
    required WorkspaceController workspace,
    required SettingsController settings,
    required ClaudeSessionActivity claudeActivity,
    AgentLauncher? agents,
    int? Function()? apiPort,
  }) : _terminal = terminal,
       _workspace = workspace,
       _settings = settings,
       _claudeActivity = claudeActivity,
       _agents = agents,
       _apiPort = apiPort ?? (() => null);

  final TerminalController _terminal;
  final WorkspaceController _workspace;
  final SettingsController _settings;
  final ClaudeSessionActivity _claudeActivity;

  /// Resumes a worktree's unfinished agent as that agent (same run id).
  final AgentLauncher? _agents;

  /// The port the agent API is listening on now, or null when it isn't
  /// running.
  final int? Function() _apiPort;

  /// The API's address, so a session can save documents through it.
  Map<String, String> get _environment => {
    if (_apiPort() case final port?)
      agentUrlEnvironmentVariable: 'http://127.0.0.1:$port',
  };

  /// Shows the Claude session running in [worktreePath]. Returns false when
  /// there is none.
  bool focus(String worktreePath) => _terminal.focusClaudeSession(worktreePath);

  /// Starts Claude in [worktreePath] with [prompt] as its first message, on
  /// [model] at [effort] (null: the CLI's defaults), and remembers the session
  /// as a sidebar shortcut under the repo at [repoPath]. It starts next to any
  /// Claude session already running there, e.g. in a shared checkout used
  /// for several issues; [issueKey] goes in its tab title. [promptId] is
  /// the prompt it was started with, remembered with the shortcut. It starts
  /// in the background, a notice offering to show it, unless [show]. Returns
  /// its tab title.
  Future<String> start({
    required String repoPath,
    required String worktreePath,
    String? prompt,
    String? model,
    String? effort,
    String? issueKey,
    String? promptId,
    bool show = false,
  }) async {
    final title = claudeSessionTitle(worktreePath, issueKey: issueKey);
    final session = _terminal.openClaudeSession(
      title,
      worktreePath,
      repoPath,
      buildClaudeCliCommand(
        extraArgs: _settings.settings.claudeCliArgs,
        prompt: prompt,
        model: model,
        effort: effort,
      ),
      reuseRunning: false,
      environment: _environment,
      show: show,
    );
    if (session != null && !show) {
      showAppSnackBar(
        'Started $title',
        action: SnackBarAction(
          label: 'Show',
          onPressed: () => _terminal.showSession(session),
        ),
      );
    }
    await _workspace.rememberClaudeSession(
      repoPath,
      worktreePath,
      promptId: promptId,
    );
    return title;
  }

  /// Opens a remembered session from its sidebar shortcut: shows the running
  /// one, or starts a terminal that continues the worktree's latest
  /// conversation (a fresh session when there is none). A worktree with an
  /// unfinished agent resumes that agent. A shortcut whose worktree is gone
  /// is dropped.
  Future<void> resume({
    required String repoPath,
    required String worktreePath,
  }) async {
    if (focus(worktreePath)) return;
    if (!await Directory(worktreePath).exists()) {
      await _workspace.forgetClaudeSession(repoPath, worktreePath);
      showAppSnackBar('Worktree ${p.basename(worktreePath)} no longer exists');
      return;
    }
    final agentRun = _agents?.unfinishedRunIn(worktreePath);
    if (agentRun != null) {
      await _agents!.resume(agentRun);
      return;
    }
    final canContinue = await _claudeActivity.hasSessions(worktreePath);
    _terminal.openClaudeSession(
      claudeSessionTitle(worktreePath),
      worktreePath,
      repoPath,
      buildClaudeCliCommand(
        extraArgs: _settings.settings.claudeCliArgs,
        resume: canContinue,
      ),
      environment: _environment,
    );
  }
}
