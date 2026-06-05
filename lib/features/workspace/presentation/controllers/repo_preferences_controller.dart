import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/workspace/domain/copilot_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/custom_link.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_registry_controller.dart';

class RepoPreferencesController extends ChangeNotifier {
  RepoPreferencesController({required RepoRegistryController registry})
    : _registry = registry;

  final RepoRegistryController _registry;

  Future<RepoConfig?> renameRepo(RepoConfig repo, String newName) async {
    final updated = RepoConfig(
      name: newName,
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
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoVscodeConfigs(
    RepoConfig repo,
    List<VscodeConfig> configs,
  ) async {
    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: configs,
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
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoCustomCommands(
    RepoConfig repo,
    List<CustomCommand> commands,
  ) async {
    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: commands,
      customLinks: repo.customLinks,
      lastBaseBranch: repo.lastBaseBranch,
      defaultRunCommands: repo.defaultRunCommands,
      copilotSessions: repo.copilotSessions,
      copilotPrompts: repo.copilotPrompts,
      slotAssignments: repo.slotAssignments,
      jiraIssues: repo.jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoCustomLinks(
    RepoConfig repo,
    List<CustomLink> links,
  ) async {
    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: repo.customCommands,
      customLinks: links,
      lastBaseBranch: repo.lastBaseBranch,
      defaultRunCommands: repo.defaultRunCommands,
      copilotSessions: repo.copilotSessions,
      copilotPrompts: repo.copilotPrompts,
      slotAssignments: repo.slotAssignments,
      jiraIssues: repo.jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateLastBaseBranch(
    RepoConfig repo,
    String branch,
  ) async {
    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: repo.customCommands,
      customLinks: repo.customLinks,
      lastBaseBranch: branch,
      defaultRunCommands: repo.defaultRunCommands,
      copilotSessions: repo.copilotSessions,
      copilotPrompts: repo.copilotPrompts,
      slotAssignments: repo.slotAssignments,
      jiraIssues: repo.jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateDefaultRunCommands(
    RepoConfig repo,
    List<String> commandNames,
  ) async {
    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: repo.customCommands,
      customLinks: repo.customLinks,
      lastBaseBranch: repo.lastBaseBranch,
      defaultRunCommands: commandNames,
      copilotSessions: repo.copilotSessions,
      copilotPrompts: repo.copilotPrompts,
      slotAssignments: repo.slotAssignments,
      jiraIssues: repo.jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoCopilotSessions(
    RepoConfig repo,
    List<CopilotSession> sessions,
  ) async {
    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: repo.customCommands,
      customLinks: repo.customLinks,
      lastBaseBranch: repo.lastBaseBranch,
      defaultRunCommands: repo.defaultRunCommands,
      copilotSessions: sessions,
      copilotPrompts: repo.copilotPrompts,
      slotAssignments: repo.slotAssignments,
      jiraIssues: repo.jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateRepoCopilotPrompts(
    RepoConfig repo,
    List<CopilotPrompt> prompts,
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
      copilotPrompts: prompts,
      slotAssignments: repo.slotAssignments,
      jiraIssues: repo.jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateSlotAssignments(
    RepoConfig repo,
    Map<String, String> slotAssignments,
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
      slotAssignments: slotAssignments,
      jiraIssues: repo.jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateJiraIssues(
    RepoConfig repo,
    Map<String, String> jiraIssues,
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
      jiraIssues: jiraIssues,
      baseBranches: repo.baseBranches,
      prAuthors: repo.prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateBaseBranches(
    RepoConfig repo,
    Map<String, String> baseBranches,
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
      baseBranches: baseBranches,
      prAuthors: repo.prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updatePrAuthors(
    RepoConfig repo,
    Map<String, String> prAuthors,
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
      prAuthors: prAuthors,
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateHiddenWorktrees(
    RepoConfig repo,
    List<String> hiddenWorktrees,
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
      hiddenWorktrees: hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateSnoozedWorktrees(
    RepoConfig repo,
    List<String> snoozedWorktrees,
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
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
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
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: config,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: repo.githubConfig,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }

  Future<RepoConfig?> updateLastAzureDevopsBranch(
    RepoConfig repo,
    String branch,
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
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: branch,
      githubConfig: repo.githubConfig,
    );
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
      hiddenWorktrees: repo.hiddenWorktrees,
      snoozedWorktrees: repo.snoozedWorktrees,
      azureDevopsConfig: repo.azureDevopsConfig,
      lastAzureDevopsBranch: repo.lastAzureDevopsBranch,
      githubConfig: config,
    );
    await _registry.replaceRepo(repo, updated);
    notifyListeners();
    return updated;
  }
}
