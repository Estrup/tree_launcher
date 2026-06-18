import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/workspace/domain/copilot_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/custom_link.dart';
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

  Future<RepoConfig?> updateRepoCustomLinks(
    RepoConfig repo,
    List<CustomLink> links,
  ) async {
    final updated = repo.copyWith(customLinks: links);
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

  Future<RepoConfig?> updateDefaultRunCommands(
    RepoConfig repo,
    List<String> commandNames,
  ) async {
    final updated = repo.copyWith(defaultRunCommands: commandNames);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoCopilotSessions(
    RepoConfig repo,
    List<CopilotSession> sessions,
  ) async {
    final updated = repo.copyWith(copilotSessions: sessions);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoCopilotPrompts(
    RepoConfig repo,
    List<CopilotPrompt> prompts,
  ) async {
    final updated = repo.copyWith(copilotPrompts: prompts);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateSlotAssignments(
    RepoConfig repo,
    Map<String, String> slotAssignments,
  ) async {
    final updated = repo.copyWith(slotAssignments: slotAssignments);
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

  Future<RepoConfig?> updateAzureDevopsConfig(
    RepoConfig repo,
    AzureDevopsConfig? config,
  ) async {
    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: repo.customCommands,
      customLinks: repo.customLinks,
      lastBaseBranch: repo.lastBaseBranch,
      defaultRunCommands: repo.defaultRunCommands,
      copilotSessions: repo.copilotSessions,
      copilotPrompts: repo.copilotPrompts,
      slotAssignments: repo.slotAssignments,
      jiraIssues: repo.jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      kickoffPrompts: repo.kickoffPrompts,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: config,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
      predefinedIssues: repo.predefinedIssues,
      useNestedWorktrees: repo.useNestedWorktrees,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateLastAzureDevopsBranch(
    RepoConfig repo,
    String branch,
  ) async {
    final updated = repo.copyWith(lastAzureDevopsBranch: branch);
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateGithubConfig(
    RepoConfig repo,
    GithubConfig? config,
  ) async {
    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: repo.customCommands,
      customLinks: repo.customLinks,
      lastBaseBranch: repo.lastBaseBranch,
      defaultRunCommands: repo.defaultRunCommands,
      copilotSessions: repo.copilotSessions,
      copilotPrompts: repo.copilotPrompts,
      slotAssignments: repo.slotAssignments,
      jiraIssues: repo.jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      kickoffPrompts: repo.kickoffPrompts,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: config,
      predefinedIssues: repo.predefinedIssues,
      useNestedWorktrees: repo.useNestedWorktrees,
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
