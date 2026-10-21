import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';
import 'package:tree_launcher/features/activity/domain/predefined_issue.dart';
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

  Future<RepoConfig?> updateAgentWorkingDirectory(
    RepoConfig repo,
    String path,
  ) async {
    final updated = repo.copyWith(agentWorkingDirectory: path);
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

  /// Maps the fixVersion [versionId] to [branch], the default base branch of
  /// its issues' new worktrees; null or empty removes the mapping.
  Future<RepoConfig?> updateJiraVersionBranch(
    RepoConfig repo,
    String versionId,
    String? branch,
  ) async {
    final trimmed = branch?.trim();
    final branches = {...repo.jiraVersionBranches}..remove(versionId);
    if (trimmed != null && trimmed.isNotEmpty) branches[versionId] = trimmed;
    final updated = repo.copyWith(jiraVersionBranches: branches);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  /// Remembers the Issues tab's milestone pick; null for all open issues.
  Future<RepoConfig?> updateGithubMilestone(
    RepoConfig repo,
    int? milestoneNumber,
  ) async {
    final updated = repo.copyWith(
      githubMilestoneNumber: milestoneNumber,
      clearGithubMilestoneNumber: milestoneNumber == null,
    );
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
