import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';
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
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_preferences_controller.dart';
import 'package:tree_launcher/models/predefined_issue.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_registry_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_selection_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/worktree_controller.dart';
import 'package:tree_launcher/models/worktree_slot.dart';
import 'package:tree_launcher/services/config_service.dart';

class WorkspaceController extends ChangeNotifier implements WorktreeCreator {
  WorkspaceController({
    required GitService gitService,
    RepoConfigStore? repoConfigStore,
    ConfigService? configService,
    WorktreeEventStore? eventStore,
  }) : this._create(
         gitService: gitService,
         repoConfigStore:
             repoConfigStore ?? RepoConfigStore(configService: configService),
         eventStore: eventStore,
       );

  factory WorkspaceController.create({
    required GitService gitService,
    required RepoConfigStore repoConfigStore,
    WorktreeEventStore? eventStore,
  }) {
    return WorkspaceController._create(
      gitService: gitService,
      repoConfigStore: repoConfigStore,
      eventStore: eventStore,
    );
  }

  WorkspaceController._create({
    required GitService gitService,
    required RepoConfigStore repoConfigStore,
    WorktreeEventStore? eventStore,
  }) {
    _store = repoConfigStore;
    _eventStore = eventStore ?? WorktreeEventStore();
    _gitService = gitService;
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
  late final WorktreeEventStore _eventStore;
  late final GitService _gitService;
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

  Future<RepoConfig?> updateUseNestedWorktrees(
    RepoConfig repo,
    bool value,
  ) async {
    final updated = await preferences.updateUseNestedWorktrees(repo, value);
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

  Future<RepoConfig?> updateRepoPredefinedIssues(
    RepoConfig repo,
    List<PredefinedIssue> issues,
  ) async {
    final updated = await preferences.updateRepoPredefinedIssues(repo, issues);
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
  }) {
    final repo = selectedRepo;
    if (repo == null) return Future.value(null);
    return _addWorktreeForRepo(
      repo,
      name,
      baseBranch: baseBranch,
      newBranch: newBranch,
      jiraIssue: jiraIssue,
      prAuthor: prAuthor,
    );
  }

  /// Creates a worktree in an explicit [repo] (not necessarily the selected
  /// one) and records its slot / JIRA / base-branch / PR-author metadata.
  ///
  /// All persistence flows through [preferences] (registry → save → notify), so
  /// it stays correct for any repo. The selected-repo view sync and the live
  /// worktree-list refresh only run when [repo] is the selected one — otherwise
  /// they would corrupt the currently-displayed list.
  Future<String?> _addWorktreeForRepo(
    RepoConfig repo,
    String name, {
    String? baseBranch,
    String? newBranch,
    String? jiraIssue,
    String? prAuthor,
  }) async {
    final isSelected = repo.path == selectedRepo?.path;

    final String? worktreePath;
    if (isSelected) {
      // Goes through the worktrees controller so the displayed list refreshes.
      worktreePath = await worktreesController.addWorktree(
        repo.path,
        name,
        baseBranch: baseBranch,
        newBranch: newBranch,
        useNestedWorktrees: repo.useNestedWorktrees,
      );
    } else {
      // Create directly so we don't replace the selected repo's worktree list.
      worktreePath = await _gitService.addWorktree(
        repo.path,
        name,
        baseBranch: baseBranch,
        newBranch: newBranch,
        useNestedWorktrees: repo.useNestedWorktrees,
      );
    }

    if (worktreePath == null) return null;

    // Persistence matches the in-memory RepoConfig by identity, so resolve the
    // live registry instance and thread it through each update.
    var current = _registryRepoFor(repo);

    // Auto-assign next available slot to the new worktree.
    final usedSlots = current.slotAssignments.values.toSet();
    final slot = nextAvailableSlot(usedSlots);
    final slots = Map<String, String>.from(current.slotAssignments);
    slots[worktreePath] = slot;
    final withSlot = await preferences.updateSlotAssignments(current, slots);
    if (isSelected) {
      _replaceSelection(current, withSlot);
      worktreesController.setSlotAssignments(
        withSlot?.slotAssignments ?? slots,
      );
    }
    current = withSlot ?? current;

    // Attach JIRA issue to the new worktree, if provided.
    if (jiraIssue != null && jiraIssue.isNotEmpty) {
      final issues = Map<String, String>.from(current.jiraIssues);
      issues[worktreePath] = jiraIssue;
      final withJira = await preferences.updateJiraIssues(current, issues);
      if (isSelected) {
        _replaceSelection(current, withJira);
        worktreesController.setJiraIssues(withJira?.jiraIssues ?? issues);
      }
      current = withJira ?? current;
    }

    // Record the base branch the worktree was created from, if known.
    if (baseBranch != null && baseBranch.isNotEmpty) {
      final branches = Map<String, String>.from(current.baseBranches);
      branches[worktreePath] = baseBranch;
      final withBase = await preferences.updateBaseBranches(current, branches);
      if (isSelected) {
        _replaceSelection(current, withBase);
        worktreesController.setBaseBranches(withBase?.baseBranches ?? branches);
      }
      current = withBase ?? current;
    }

    // Attach the PR author to the new worktree, if provided, so worktrees can
    // later be grouped by PR creator.
    if (prAuthor != null && prAuthor.isNotEmpty) {
      final authors = Map<String, String>.from(current.prAuthors);
      authors[worktreePath] = prAuthor;
      final withAuthor = await preferences.updatePrAuthors(current, authors);
      if (isSelected) {
        _replaceSelection(current, withAuthor);
        worktreesController.setPrAuthors(withAuthor?.prAuthors ?? authors);
      }
      current = withAuthor ?? current;
    }

    // Record the creation in the activity log.
    _logWorktreeEvent(
      type: WorktreeEventType.created,
      repo: current,
      worktreePath: worktreePath,
      branch: newBranch ?? baseBranch,
      jiraIssue: jiraIssue,
    );

    return worktreePath;
  }

  /// Returns the live registry instance matching [repo] by path (so updates
  /// match by identity), falling back to [repo] if it isn't registered.
  RepoConfig _registryRepoFor(RepoConfig repo) {
    for (final r in registry.repos) {
      if (r.path == repo.path) return r;
    }
    return repo;
  }

  /// [WorktreeCreator] entry point for the agent HTTP API. Resolves the repo by
  /// name from the live registry and delegates to [_addWorktreeForRepo].
  @override
  Future<CreatedWorktree> createWorktree({
    required String repoName,
    required String worktreeName,
    required String baseBranch,
    required String newBranch,
    String? jiraIssue,
  }) async {
    RepoConfig? repo;
    for (final r in registry.repos) {
      if (r.name == repoName) {
        repo = r;
        break;
      }
    }
    if (repo == null) throw RepoNotFoundException(repoName);

    final worktreePath = await _addWorktreeForRepo(
      repo,
      worktreeName,
      baseBranch: baseBranch,
      newBranch: newBranch,
      jiraIssue: jiraIssue,
    );
    if (worktreePath == null) {
      throw Exception('Failed to create worktree "$worktreeName"');
    }

    final updated = _registryRepoFor(repo);
    return CreatedWorktree(
      worktreePath: worktreePath,
      branch: newBranch,
      slot: updated.slotAssignments[worktreePath] ?? '',
    );
  }

  /// Appends a worktree lifecycle event. Best-effort: a logging failure must
  /// never block the create/delete it accompanies.
  void _logWorktreeEvent({
    required WorktreeEventType type,
    required RepoConfig repo,
    required String worktreePath,
    String? branch,
    String? jiraIssue,
  }) {
    final segments = worktreePath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    final name = segments.isEmpty ? worktreePath : segments.last;
    _eventStore.append(
      WorktreeEvent(
        timestamp: DateTime.now(),
        type: type,
        repoPath: repo.path,
        repoName: repo.name,
        worktreePath: worktreePath,
        worktreeName: name,
        branch: (branch != null && branch.isNotEmpty) ? branch : null,
        jiraIssue: (jiraIssue != null && jiraIssue.isNotEmpty)
            ? jiraIssue
            : null,
      ),
    );
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

  /// Hides or unhides a worktree. Hidden worktrees are filtered from the list
  /// unless "Show hidden worktrees" is enabled.
  Future<void> setWorktreeHidden(String worktreePath, bool hidden) async {
    if (selectedRepo == null) return;
    final repo = selectedRepo!;
    final updated = List<String>.from(repo.hiddenWorktrees);
    if (hidden) {
      if (!updated.contains(worktreePath)) updated.add(worktreePath);
    } else {
      updated.remove(worktreePath);
    }
    final newRepo = await preferences.updateHiddenWorktrees(repo, updated);
    _replaceSelection(repo, newRepo);
    worktreesController.setHiddenWorktrees(newRepo?.hiddenWorktrees ?? updated);
  }

  /// Hides or unhides several worktrees in a single config write.
  Future<void> setWorktreesHidden(
    List<String> worktreePaths,
    bool hidden,
  ) async {
    if (selectedRepo == null || worktreePaths.isEmpty) return;
    final repo = selectedRepo!;
    final updated = List<String>.from(repo.hiddenWorktrees);
    if (hidden) {
      for (final path in worktreePaths) {
        if (!updated.contains(path)) updated.add(path);
      }
    } else {
      updated.removeWhere(worktreePaths.contains);
    }
    final newRepo = await preferences.updateHiddenWorktrees(repo, updated);
    _replaceSelection(repo, newRepo);
    worktreesController.setHiddenWorktrees(newRepo?.hiddenWorktrees ?? updated);
  }

  /// Snoozes or unsnoozes a worktree. PR worktrees auto-unsnooze when the PR is
  /// again assigned to me (see [clearSnoozeForBranch]); others stay snoozed
  /// until cleared manually.
  Future<void> setWorktreeSnoozed(String worktreePath, bool snoozed) async {
    if (selectedRepo == null) return;
    final repo = selectedRepo!;
    final updated = List<String>.from(repo.snoozedWorktrees);
    if (snoozed) {
      if (!updated.contains(worktreePath)) updated.add(worktreePath);
    } else {
      updated.remove(worktreePath);
    }
    final newRepo = await preferences.updateSnoozedWorktrees(repo, updated);
    _replaceSelection(repo, newRepo);
    worktreesController.setSnoozedWorktrees(
      newRepo?.snoozedWorktrees ?? updated,
    );
  }

  /// Clears the snooze on any worktree of the selected repo whose branch
  /// matches [headBranch]. Called when a PR transitions to requesting my review
  /// again, implementing "hide until the PR is again assigned to me".
  Future<void> clearSnoozeForBranch(String headBranch) async {
    if (selectedRepo == null) return;
    final repo = selectedRepo!;
    if (repo.snoozedWorktrees.isEmpty) return;
    final matching = worktreesController.worktrees
        .where((w) => w.branch == headBranch)
        .map((w) => w.path)
        .where(repo.snoozedWorktrees.contains)
        .toList();
    if (matching.isEmpty) return;
    final updated = List<String>.from(repo.snoozedWorktrees)
      ..removeWhere(matching.contains);
    final newRepo = await preferences.updateSnoozedWorktrees(repo, updated);
    _replaceSelection(repo, newRepo);
    worktreesController.setSnoozedWorktrees(
      newRepo?.snoozedWorktrees ?? updated,
    );
  }

  Future<void> deleteWorktree(Worktree worktree) async {
    // Capture the close event before any per-worktree metadata is stripped
    // below — the JIRA issue and branch only live on the passed [worktree] and
    // in config, both of which we clear during deletion.
    final repoForLog = selectedRepo;
    if (repoForLog != null) {
      _logWorktreeEvent(
        type: WorktreeEventType.closed,
        repo: repoForLog,
        worktreePath: worktree.path,
        branch: worktree.branch,
        jiraIssue: worktree.jiraIssue,
      );
    }

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
        current = withAuthor ?? current;
        worktreesController.setPrAuthors(current.prAuthors);
      }

      if (current.hiddenWorktrees.contains(worktree.path)) {
        final hidden = List<String>.from(current.hiddenWorktrees)
          ..remove(worktree.path);
        final withHidden = await preferences.updateHiddenWorktrees(
          current,
          hidden,
        );
        _replaceSelection(current, withHidden);
        current = withHidden ?? current;
        worktreesController.setHiddenWorktrees(current.hiddenWorktrees);
      }

      if (current.snoozedWorktrees.contains(worktree.path)) {
        final snoozed = List<String>.from(current.snoozedWorktrees)
          ..remove(worktree.path);
        final withSnoozed = await preferences.updateSnoozedWorktrees(
          current,
          snoozed,
        );
        _replaceSelection(current, withSnoozed);
        current = withSnoozed ?? current;
        worktreesController.setSnoozedWorktrees(current.snoozedWorktrees);
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
    worktreesController.setSlotAssignments(newRepo?.slotAssignments ?? updated);
  }

  void _syncSlotAssignments(RepoConfig? repo) {
    worktreesController.setSlotAssignments(repo?.slotAssignments ?? {});
    worktreesController.setJiraIssues(repo?.jiraIssues ?? {});
    worktreesController.setBaseBranches(repo?.baseBranches ?? {});
    worktreesController.setPrAuthors(repo?.prAuthors ?? {});
    worktreesController.setHiddenWorktrees(repo?.hiddenWorktrees ?? const []);
    worktreesController.setSnoozedWorktrees(repo?.snoozedWorktrees ?? const []);
  }

  /// Removes slot assignments for worktree paths that no longer exist.
  Future<void> _pruneStaleSlotAssignments() async {
    if (selectedRepo == null) return;
    final repo = selectedRepo!;
    final activePaths = worktreesController.worktrees
        .map((w) => w.path)
        .toSet();
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
    worktreesController.setSlotAssignments(newRepo?.slotAssignments ?? updated);

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
