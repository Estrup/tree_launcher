import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/workspace/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';
import 'package:tree_launcher/models/predefined_issue.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_registry_controller.dart';

class RepoPreferencesController extends ChangeNotifier {
  RepoPreferencesController({required RepoRegistryController registry})
    : _registry = registry;

  final RepoRegistryController _registry;

  Future<RepoConfig?> renameRepo(RepoConfig repo, String newName) async {
    final updated = repo.copyWith(name: newName);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoVscodeConfigs(
    RepoConfig repo,
    List<VscodeConfig> configs,
  ) async {
    final updated = repo.copyWith(vscodeConfigs: configs);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoCustomCommands(
    RepoConfig repo,
    List<CustomCommand> commands,
  ) async {
    final updated = repo.copyWith(customCommands: commands);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateLastBaseBranch(
    RepoConfig repo,
    String branch,
  ) async {
    final updated = repo.copyWith(lastBaseBranch: branch);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoClaudePrompts(
    RepoConfig repo,
    List<ClaudePrompt> prompts,
  ) async {
    final updated = repo.copyWith(claudePrompts: prompts);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateJiraIssues(
    RepoConfig repo,
    Map<String, String> jiraIssues,
  ) async {
    final updated = repo.copyWith(jiraIssues: jiraIssues);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateBaseBranches(
    RepoConfig repo,
    Map<String, String> baseBranches,
  ) async {
    final updated = repo.copyWith(baseBranches: baseBranches);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updatePrAuthors(
    RepoConfig repo,
    Map<String, String> prAuthors,
  ) async {
    final updated = repo.copyWith(prAuthors: prAuthors);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateKickoffPrompts(
    RepoConfig repo,
    Map<String, String> kickoffPrompts,
  ) async {
    final updated = repo.copyWith(kickoffPrompts: kickoffPrompts);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateHiddenWorktrees(
    RepoConfig repo,
    List<String> hiddenWorktrees,
  ) async {
    final updated = repo.copyWith(hiddenWorktrees: hiddenWorktrees);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateSnoozedWorktrees(
    RepoConfig repo,
    List<String> snoozedWorktrees,
  ) async {
    final updated = repo.copyWith(snoozedWorktrees: snoozedWorktrees);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateClaudeSessions(
    RepoConfig repo,
    List<String> claudeSessions,
  ) async {
    final updated = repo.copyWith(claudeSessions: claudeSessions);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateGithubConfig(
    RepoConfig repo,
    GithubConfig? config,
  ) async {
    final updated = repo.copyWith(
      githubConfig: config,
      clearGithubConfig: config == null,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  /// Sets (or clears, for null/empty) the Jira project key. A different project
  /// has different fixVersions, so the remembered fixVersion is reset too.
  Future<RepoConfig?> updateJiraProjectKey(
    RepoConfig repo,
    String? projectKey,
  ) async {
    final trimmed = projectKey?.trim().toUpperCase();
    final key = trimmed == null || trimmed.isEmpty ? null : trimmed;
    final updated = repo.copyWith(
      jiraProjectKey: key,
      clearJiraProjectKey: key == null,
      clearJiraFixVersionId: key != repo.jiraProjectKey,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateJiraFixVersion(
    RepoConfig repo,
    String versionId,
  ) async {
    final updated = repo.copyWith(jiraFixVersionId: versionId);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoPredefinedIssues(
    RepoConfig repo,
    List<PredefinedIssue> issues,
  ) async {
    final updated = repo.copyWith(predefinedIssues: issues);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateUseNestedWorktrees(
    RepoConfig repo,
    bool value,
  ) async {
    final updated = repo.copyWith(useNestedWorktrees: value);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }
}
