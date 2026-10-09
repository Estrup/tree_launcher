import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// Terminal tab title for the Claude session in [worktreePath].
String claudeSessionTitle(String worktreePath) =>
    'Claude: ${p.basename(worktreePath)}';

/// Starts and resumes Claude CLI sessions in the built-in terminal, and keeps
/// their sidebar shortcuts. Holds the controllers it needs, so it can be
/// created before a dialog and used after it regardless of what rebuilt.
class ClaudeSessionLauncher {
  ClaudeSessionLauncher({
    required TerminalController terminal,
    required WorkspaceController workspace,
    required SettingsController settings,
    ClaudeSessionActivity? claudeActivity,
  }) : _terminal = terminal,
       _workspace = workspace,
       _settings = settings,
       _claudeActivity = claudeActivity ?? ClaudeSessionActivity();

  factory ClaudeSessionLauncher.of(BuildContext context) =>
      ClaudeSessionLauncher(
        terminal: context.read<TerminalController>(),
        workspace: context.read<WorkspaceController>(),
        settings: context.read<SettingsController>(),
      );

  final TerminalController _terminal;
  final WorkspaceController _workspace;
  final SettingsController _settings;
  final ClaudeSessionActivity _claudeActivity;

  /// Shows the Claude session running in [worktreePath]. Returns false when
  /// there is none.
  bool focus(String worktreePath) => _terminal.focusClaudeSession(worktreePath);

  /// Starts Claude in [worktreePath] with [prompt] as its first message, and
  /// remembers the session as a sidebar shortcut under the repo at
  /// [repoPath]. When Claude is already running there, that one is shown.
  Future<void> start({
    required String repoPath,
    required String worktreePath,
    String? prompt,
  }) async {
    _terminal.openClaudeSession(
      claudeSessionTitle(worktreePath),
      worktreePath,
      repoPath,
      buildClaudeCliCommand(
        extraArgs: _settings.settings.claudeCliArgs,
        prompt: prompt,
      ),
    );
    await _workspace.rememberClaudeSession(repoPath, worktreePath);
  }

  /// Opens a remembered session from its sidebar shortcut: shows the running
  /// one, or starts a terminal that continues the worktree's latest
  /// conversation (a fresh session when there is none). A shortcut whose
  /// worktree is gone is dropped.
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
    final canContinue = await _claudeActivity.hasSessions(worktreePath);
    _terminal.openClaudeSession(
      claudeSessionTitle(worktreePath),
      worktreePath,
      repoPath,
      buildClaudeCliCommand(
        extraArgs: _settings.settings.claudeCliArgs,
        resume: canContinue,
      ),
    );
  }
}
