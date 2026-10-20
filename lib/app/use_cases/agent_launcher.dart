import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/agents/domain/agent_environment.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// Starts, shows, resumes and stops agents in the built-in terminal. Built
/// once by the composition root and provided to the widget tree, so a dialog
/// can use it after it closes regardless of what rebuilt.
class AgentLauncher {
  AgentLauncher({
    required TerminalController terminal,
    required AgentsController agents,
    required WorkspaceController workspace,
    required SettingsController settings,
    required ClaudeSessionActivity claudeActivity,
    int? Function()? apiPort,
  }) : _terminal = terminal,
       _agents = agents,
       _workspace = workspace,
       _settings = settings,
       _claudeActivity = claudeActivity,
       _apiPort = apiPort ?? (() => null);

  final TerminalController _terminal;
  final AgentsController _agents;
  final WorkspaceController _workspace;
  final SettingsController _settings;
  final ClaudeSessionActivity _claudeActivity;

  /// The port the agent API is listening on now (it can be restarted on
  /// another), or null when it isn't running.
  final int? Function() _apiPort;

  /// Terminal tab title for [run].
  static String titleFor(AgentRun run) =>
      '${run.kind.label}: ${run.issueKey ?? p.basename(run.worktreePath ?? run.repoName)}';

  Map<String, String> _environment(AgentRun run) => {
    agentIdEnvironmentVariable: run.id,
    if (_apiPort() case final port?)
      agentUrlEnvironmentVariable: 'http://127.0.0.1:$port',
  };

  /// Creates a run for [prompt] (which must have a kind) and starts its
  /// Claude session in [worktreePath] with [resolvedPrompt] as the first
  /// message, in the background (a notice offers to show it) unless [show].
  /// A build agent's worktree is remembered as a sidebar session.
  Future<AgentRun> start({
    required String repoPath,
    required String repoName,
    required ClaudePrompt prompt,
    required String worktreePath,
    String? resolvedPrompt,
    String? branch,
    String? issueKey,
    String? title,
    int? prNumber,
    String? model,
    String? effort,
    bool show = false,
  }) async {
    final kind = prompt.kind;
    if (kind == null) {
      throw ArgumentError('prompt "${prompt.name}" has no agent kind');
    }
    final run = await _agents.createForLaunch(
      kind: kind,
      repoName: repoName,
      promptName: prompt.name,
      title: title,
      issueKeys: [?issueKey],
      worktreePath: worktreePath,
      branch: branch,
      prNumber: prNumber,
      model: model,
      effort: effort,
    );
    final session = _terminal.openAgentSession(
      titleFor(run),
      worktreePath,
      repoPath,
      buildClaudeCliCommand(
        extraArgs: _settings.settings.claudeCliArgs,
        prompt: resolvedPrompt,
        model: model,
        effort: effort,
      ),
      agentId: run.id,
      environment: _environment(run),
      show: show,
    );
    if (session != null && !show) {
      showAppSnackBar(
        'Started ${titleFor(run)}',
        action: SnackBarAction(
          label: 'Show',
          onPressed: () => _terminal.showSession(session),
        ),
      );
    }
    if (kind == AgentKind.build) {
      await _workspace.rememberClaudeSession(
        repoPath,
        worktreePath,
        promptId: prompt.name,
      );
    }
    return run;
  }

  /// The newest unfinished, unarchived run working in [worktreePath], if any.
  AgentRun? unfinishedRunIn(String worktreePath) => _agents.runs
      .where(
        (r) =>
            r.worktreePath == worktreePath &&
            !r.state.isFinished &&
            !r.archived,
      )
      .firstOrNull;

  /// Whether [run]'s Claude session is open in the terminal.
  bool isOpen(AgentRun run) => _terminal.claudeSessionForAgent(run.id) != null;

  /// Shows [run]'s session. Returns false when it isn't open.
  bool focus(AgentRun run) => _terminal.focusAgentSession(run.id);

  /// Shows [run]'s session, or starts a terminal that resumes its Claude
  /// conversation (the exact one when its session id is known, else the
  /// worktree's latest) with the agent's id in the environment again.
  Future<void> resume(AgentRun run) async {
    if (focus(run)) return;
    final path = run.worktreePath;
    if (path == null) {
      showAppSnackBar("This agent didn't say where it runs");
      return;
    }
    if (!await Directory(path).exists()) {
      showAppSnackBar('${p.basename(path)} no longer exists');
      return;
    }
    final repoPath =
        _workspace.repos
            .where((r) => r.name == run.repoName)
            .firstOrNull
            ?.path ??
        path;
    final sessionId = run.claudeSessionId;
    final canContinue =
        sessionId == null && await _claudeActivity.hasSessions(path);
    _terminal.openAgentSession(
      titleFor(run),
      path,
      repoPath,
      buildClaudeCliCommand(
        extraArgs: _settings.settings.claudeCliArgs,
        model: run.model,
        effort: run.effort,
        resumeSessionId: sessionId,
        resume: canContinue,
      ),
      agentId: run.id,
      environment: _environment(run),
    );
  }

  /// Closes [run]'s session (interrupting Claude) and marks it stopped.
  Future<void> stop(AgentRun run) async {
    _terminal.closeAgentSession(run.id);
    if (!run.state.isFinished) await _agents.markStopped(run.id);
  }
}
