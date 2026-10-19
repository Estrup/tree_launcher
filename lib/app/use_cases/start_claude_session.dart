import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/app/use_cases/claude_session_launcher.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

/// Starts Claude in the worktree picked in the Start Claude dialog (the
/// flow behind the Jira, PR and issue buttons): remembers the choices for
/// next time, then starts an agent when the picked prompt has an agent kind,
/// or else a plain Claude session.
class StartClaudeSession {
  StartClaudeSession({
    required SettingsController settings,
    required ClaudeSessionLauncher sessions,
    required AgentLauncher agents,
  }) : _settings = settings,
       _sessions = sessions,
       _agents = agents;

  final SettingsController _settings;
  final ClaudeSessionLauncher _sessions;
  final AgentLauncher _agents;

  /// Starts Claude in [worktreePath] of [repo] with [prompt] (the picked
  /// prompt, placeholders filled in) as its first message, on [model] at
  /// [effort].
  ///
  /// [promptId] is the prompt picked (a saved prompt's name or a built-in
  /// id; null for none) and [savedPrompt] the saved prompt, if one was.
  /// [useExistingWorktree] is whether "Existing worktree" was picked, null
  /// when it wasn't a choice. [title] and [prNumber] describe an agent run.
  Future<void> call({
    required RepoConfig repo,
    required String worktreePath,
    String? branch,
    String? prompt,
    String? promptId,
    ClaudePrompt? savedPrompt,
    String? model,
    String? effort,
    bool? useExistingWorktree,
    String? issueKey,
    String? title,
    int? prNumber,
  }) async {
    await _settings.updateClaudeModelAndEffort(model, effort);
    await _settings.updateClaudeStartChoices(
      prompt: promptId ?? noClaudePromptId,
      useExistingWorktree: useExistingWorktree,
    );
    if (savedPrompt != null && savedPrompt.kind != null) {
      await _agents.start(
        repoPath: repo.path,
        repoName: repo.name,
        prompt: savedPrompt,
        worktreePath: worktreePath,
        resolvedPrompt: prompt,
        branch: branch,
        issueKey: issueKey,
        title: title,
        prNumber: prNumber,
        model: model,
        effort: effort,
      );
      return;
    }
    await _sessions.start(
      repoPath: repo.path,
      worktreePath: worktreePath,
      prompt: prompt,
      model: model,
      effort: effort,
      issueKey: issueKey,
      promptId: promptId,
    );
  }
}
