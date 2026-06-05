import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/copilot_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/custom_link.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_preferences_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_registry_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_selection_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/worktree_controller.dart';
import 'package:tree_launcher/models/worktree_slot.dart';
import 'package:tree_launcher/services/config_service.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required GitService gitService,
    RepoConfigStore? repoConfigStore,
    ConfigService? configService,
  }) : this._create(
         gitService: gitService,
         repoConfigStore:
             repoConfigStore ?? RepoConfigStore(configService: configService),
       );

  factory WorkspaceController.create({
    required GitService gitService,
    required RepoConfigStore repoConfigStore,
  }) {
    return WorkspaceController._create(
      gitService: gitService,
      repoConfigStore: repoConfigStore,
    );
  }

  WorkspaceController._create({
    required GitService gitService,
    required RepoConfigStore repoConfigStore,
  }) {
    _store = repoConfigStore;
    final registry = RepoRegistryController(
      store: repoConfigStore,
      gitService: gitService,
    );
    _initialize(
      registry: registry,
      selection: RepoSelectionController(),
      worktreesController: WorktreeController(gitService: gitService),
      preferences: RepoPreferencesController(registry: registry),
    );
  }

  late final RepoConfigStore _store;
  late final RepoRegistryController registry;
  late final RepoSelectionController selection;
  late final WorktreeController worktreesController;
  late final RepoPreferencesController preferences;

  void _initialize({
    required RepoRegistryController registry,
    required RepoSelectionController selection,
    required WorktreeController worktreesController,
    required RepoPreferencesController preferences,
  }) {
    this.registry = registry;
    this.selection = selection;
    this.worktreesController = worktreesController;
    this.preferences = preferences;
    registry.addListener(_relay);
    selection.addListener(_relay);
    worktreesController.addListener(_relay);
    preferences.addListener(_relay);
  }

  List<RepoConfig> get repos => registry.repos;
  RepoConfig? get selectedRepo => selection.selectedRepo;
  List<Worktree> get worktrees => worktreesController.worktrees;
  bool get loading => worktreesController.loading;
  String? get error => worktreesController.error;
  bool get showSettings => selection.showSettings;
  bool get isBareLayout => worktreesController.isBareLayout;
  List<CopilotSession> get allCopilotSessions =>
      repos.expand((repo) => repo.copilotSessions).toList();

  void _relay() => notifyListeners();

  void toggleSettings() => selection.toggleSettings();

  void closeSettings() => selection.closeSettings();

  Future<void> loadRepos() async {
    await registry.loadRepos();
    if (repos.isNotEmpty && selectedRepo == null) {
      final savedPath = await _store.loadLastSelectedRepoPath();
      final target = repos.firstWhere(
        (r) => r.path == savedPath,
        orElse: () => repos.first,
      );
      selection.selectRepo(target);
      _syncSlotAssignments(target);
      await worktreesController.refreshForRepo(target.path);
    }
    notifyListeners();
  }

  Future<void> addRepo(String path) async {
    final repo = await registry.addRepo(path);
    if (selectedRepo == null) {
      selection.selectRepo(repo);
      await _persistSelection(repo);
      await worktreesController.refreshForRepo(repo.path);
    }
    notifyListeners();
  }

  Future<void> removeRepo(RepoConfig repo) async {
    await registry.removeRepo(repo);
    if (selectedRepo == repo) {
      final fallback = repos.isNotEmpty ? repos.first : null;
      selection.selectRepo(fallback);
      await _persistSelection(fallback);
      await worktreesController.refreshForRepo(fallback?.path);
    }
    notifyListeners();
  }

  Future<void> selectRepo(RepoConfig repo) async {
    if (selectedRepo == repo) return;
    selection.selectRepo(repo);
    await _persistSelection(repo);
    _syncSlotAssignments(repo);
    await worktreesController.refreshForRepo(repo.path);
  }

  Future<void> _persistSelection(RepoConfig? repo) =>
      _store.saveLastSelectedRepoPath(repo?.path);

  Future<RepoConfig?> renameRepo(RepoConfig repo, String newName) async {
    final updated = await preferences.renameRepo(repo, newName);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateRepoVscodeConfigs(
    RepoConfig repo,
    List<VscodeConfig> configs,
  ) async {
    final updated = await preferences.updateRepoVscodeConfigs(repo, configs);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateRepoCustomCommands(
    RepoConfig repo,
    List<CustomCommand> commands,
  ) async {
    final updated = await preferences.updateRepoCustomCommands(repo, commands);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateRepoCustomLinks(
    RepoConfig repo,
    List<CustomLink> links,
  ) async {
    final updated = await preferences.updateRepoCustomLinks(repo, links);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateLastBaseBranch(
    RepoConfig repo,
    String branch,
  ) async {
    final updated = await preferences.updateLastBaseBranch(repo, branch);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateDefaultRunCommands(
    RepoConfig repo,
    List<String> commandNames,
  ) async {
    final updated = await preferences.updateDefaultRunCommands(
      repo,
      commandNames,
    );
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateRepoCopilotSessions(
    RepoConfig repo,
    List<CopilotSession> sessions,
  ) async {
    final updated = await preferences.updateRepoCopilotSessions(repo, sessions);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateRepoCopilotPrompts(
    RepoConfig repo,
    List<CopilotPrompt> prompts,
  ) async {
    final updated = await preferences.updateRepoCopilotPrompts(repo, prompts);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateAzureDevopsConfig(
    RepoConfig repo,
    AzureDevopsConfig? config,
  ) async {
    final updated = await preferences.updateAzureDevopsConfig(repo, config);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateLastAzureDevopsBranch(
    RepoConfig repo,
    String branch,
  ) async {
    final updated = await preferences.updateLastAzureDevopsBranch(repo, branch);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateGithubConfig(
    RepoConfig repo,
    GithubConfig? config,
  ) async {
    final updated = await preferences.updateGithubConfig(repo, config);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<List<String>> listBranches() async {
    return worktreesController.listBranches(selectedRepo?.path);
  }

  Future<String?> addWorktree(
    String name, {
    String? baseBranch,
    String? newBranch,
    String? jiraIssue,
    String? prAuthor,
  }) async {
    final worktreePath = await worktreesController.addWorktree(
      selectedRepo?.path,
      name,
      baseBranch: baseBranch,
      newBranch: newBranch,
    );

    // Auto-assign next available slot to the new worktree
    if (worktreePath != null && selectedRepo != null) {
      final repo = selectedRepo!;
      final usedSlots = repo.slotAssignments.values.toSet();
      final slot = nextAvailableSlot(usedSlots);
      final updated = Map<String, String>.from(repo.slotAssignments);
      updated[worktreePath] = slot;
      var newRepo = await preferences.updateSlotAssignments(repo, updated);
      _replaceSelection(repo, newRepo);
      worktreesController.setSlotAssignments(
        newRepo?.slotAssignments ?? updated,
      );

      // Attach JIRA issue to the new worktree, if provided.
      if (jiraIssue != null && jiraIssue.isNotEmpty) {
        final current = newRepo ?? selectedRepo!;
        final issues = Map<String, String>.from(current.jiraIssues);
        issues[worktreePath] = jiraIssue;
        final withJira = await preferences.updateJiraIssues(current, issues);
        _replaceSelection(current, withJira);
        worktreesController.setJiraIssues(withJira?.jiraIssues ?? issues);
      }

      // Record the base branch the worktree was created from, if known.
      if (baseBranch != null && baseBranch.isNotEmpty) {
        final current = selectedRepo!;
        final branches = Map<String, String>.from(current.baseBranches);
        branches[worktreePath] = baseBranch;
        final withBase = await preferences.updateBaseBranches(current, branches);
        _replaceSelection(current, withBase);
        worktreesController.setBaseBranches(withBase?.baseBranches ?? branches);
      }

      // Attach the PR author to the new worktree, if provided, so worktrees
      // can later be grouped by PR creator.
      if (prAuthor != null && prAuthor.isNotEmpty) {
        final current = selectedRepo!;
        final authors = Map<String, String>.from(current.prAuthors);
        authors[worktreePath] = prAuthor;
        final withAuthor = await preferences.updatePrAuthors(current, authors);
        _replaceSelection(current, withAuthor);
        worktreesController.setPrAuthors(withAuthor?.prAuthors ?? authors);
      }
    }

    return worktreePath;
  }

  Future<void> updateJiraIssue(String worktreePath, String? jiraIssue) async {
    if (selectedRepo == null) return;
    final repo = selectedRepo!;
    final updated = Map<String, String>.from(repo.jiraIssues);
    if (jiraIssue == null || jiraIssue.isEmpty) {
      updated.remove(worktreePath);
    } else {
      updated[worktreePath] = jiraIssue;
    }
    final newRepo = await preferences.updateJiraIssues(repo, updated);
    _replaceSelection(repo, newRepo);
    worktreesController.setJiraIssues(newRepo?.jiraIssues ?? updated);
  }

  Future<void> deleteWorktree(Worktree worktree) async {
    await worktreesController.deleteWorktree(selectedRepo?.path, worktree);

    // Remove slot assignment and JIRA issue for the deleted worktree
    if (selectedRepo != null) {
      final repo = selectedRepo!;
      final updated = Map<String, String>.from(repo.slotAssignments);
      updated.remove(worktree.path);
      var newRepo = await preferences.updateSlotAssignments(repo, updated);
      _replaceSelection(repo, newRepo);
      worktreesController.setSlotAssignments(
        newRepo?.slotAssignments ?? updated,
      );

      var current = newRepo ?? selectedRepo!;
      if (current.jiraIssues.containsKey(worktree.path)) {
        final issues = Map<String, String>.from(current.jiraIssues);
        issues.remove(worktree.path);
        final withJira = await preferences.updateJiraIssues(current, issues);
        _replaceSelection(current, withJira);
        current = withJira ?? current;
        worktreesController.setJiraIssues(current.jiraIssues);
      }

      if (current.prAuthors.containsKey(worktree.path)) {
        final authors = Map<String, String>.from(current.prAuthors);
        authors.remove(worktree.path);
        final withAuthor = await preferences.updatePrAuthors(current, authors);
        _replaceSelection(current, withAuthor);
        worktreesController.setPrAuthors(withAuthor?.prAuthors ?? authors);
      }
    }
  }

  Future<void> refreshWorktrees() async {
    _syncSlotAssignments(selectedRepo);
    await worktreesController.refreshForRepo(selectedRepo?.path);
    _pruneStaleSlotAssignments();
  }

  Future<void> updateSlotAssignment(String worktreePath, String slot) async {
    if (selectedRepo == null) return;
    final repo = selectedRepo!;
    final updated = Map<String, String>.from(repo.slotAssignments);
    updated[worktreePath] = slot;
    final newRepo = await preferences.updateSlotAssignments(repo, updated);
    _replaceSelection(repo, newRepo);
    worktreesController.setSlotAssignments(
      newRepo?.slotAssignments ?? updated,
    );
  }

  void _syncSlotAssignments(RepoConfig? repo) {
    worktreesController.setSlotAssignments(
      repo?.slotAssignments ?? {},
    );
    worktreesController.setJiraIssues(
      repo?.jiraIssues ?? {},
    );
    worktreesController.setBaseBranches(
      repo?.baseBranches ?? {},
    );
    worktreesController.setPrAuthors(
      repo?.prAuthors ?? {},
    );
  }

  /// Removes slot assignments for worktree paths that no longer exist.
  Future<void> _pruneStaleSlotAssignments() async {
    if (selectedRepo == null) return;
    final repo = selectedRepo!;
    final activePaths = worktreesController.worktrees.map((w) => w.path).toSet();
    final staleKeys = repo.slotAssignments.keys
        .where((path) => !activePaths.contains(path))
        .toList();
    if (staleKeys.isEmpty) return;

    final updated = Map<String, String>.from(repo.slotAssignments);
    for (final key in staleKeys) {
      updated.remove(key);
    }
    var newRepo = await preferences.updateSlotAssignments(repo, updated);
    _replaceSelection(repo, newRepo);
    worktreesController.setSlotAssignments(
      newRepo?.slotAssignments ?? updated,
    );

    // Prune stale JIRA issue assignments too.
    var current = newRepo ?? selectedRepo!;
    final staleJiraKeys = current.jiraIssues.keys
        .where((path) => !activePaths.contains(path))
        .toList();
    if (staleJiraKeys.isNotEmpty) {
      final issues = Map<String, String>.from(current.jiraIssues);
      for (final key in staleJiraKeys) {
        issues.remove(key);
      }
      final withJira = await preferences.updateJiraIssues(current, issues);
      _replaceSelection(current, withJira);
      current = withJira ?? current;
      worktreesController.setJiraIssues(current.jiraIssues);
    }

    // Prune stale PR author assignments too.
    final stalePrAuthorKeys = current.prAuthors.keys
        .where((path) => !activePaths.contains(path))
        .toList();
    if (stalePrAuthorKeys.isNotEmpty) {
      final authors = Map<String, String>.from(current.prAuthors);
      for (final key in stalePrAuthorKeys) {
        authors.remove(key);
      }
      final withAuthor = await preferences.updatePrAuthors(current, authors);
      _replaceSelection(current, withAuthor);
      worktreesController.setPrAuthors(withAuthor?.prAuthors ?? authors);
    }
  }

  void _replaceSelection(RepoConfig previous, RepoConfig? updated) {
    if (updated == null) return;
    selection.replaceSelectedRepo(previous, updated);
    notifyListeners();
  }

  @override
  void dispose() {
    registry.removeListener(_relay);
    selection.removeListener(_relay);
    worktreesController.removeListener(_relay);
    preferences.removeListener(_relay);
    registry.dispose();
    selection.dispose();
    worktreesController.dispose();
    preferences.dispose();
    super.dispose();
  }
}
