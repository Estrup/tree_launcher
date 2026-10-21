import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/data/worktree_metadata_store.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_preferences_controller.dart';
import 'package:tree_launcher/features/activity/domain/predefined_issue.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_registry_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/repo_selection_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/worktree_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/worktree_metadata_controller.dart';

class WorkspaceController extends ChangeNotifier
    implements WorktreeCreator, RepoCatalog {
  WorkspaceController({
    required GitService gitService,
    required RepoConfigStore repoConfigStore,
    required WorktreeEventStore eventStore,
    required WorktreeMetadataStore metadataStore,
  }) : _store = repoConfigStore,
       _eventStore = eventStore,
       _gitService = gitService {
    registry = RepoRegistryController(
      store: repoConfigStore,
      gitService: gitService,
    );
    selection = RepoSelectionController();
    metadata = WorktreeMetadataController(store: metadataStore);
    worktreesController = WorktreeController(
      gitService: gitService,
      metadata: metadata,
    );
    preferences = RepoPreferencesController(registry: registry);
    registry.addListener(_relay);
    selection.addListener(_relay);
    metadata.addListener(_relay);
    worktreesController.addListener(_relay);
    preferences.addListener(_relay);
  }

  final RepoConfigStore _store;
  final WorktreeEventStore _eventStore;
  final GitService _gitService;
  late final RepoRegistryController registry;
  late final RepoSelectionController selection;

  /// Every worktree's metadata (issue, base branch, hidden, snoozed,
  /// remembered Claude session), for all repos.
  late final WorktreeMetadataController metadata;
  late final WorktreeController worktreesController;
  late final RepoPreferencesController preferences;

  @override
  List<RepoConfig> get repos => registry.repos;

  final _reposLoaded = Completer<void>();

  @override
  Future<void> get whenLoaded => _reposLoaded.future;

  RepoConfig? get selectedRepo => selection.selectedRepo;
  List<Worktree> get worktrees => worktreesController.worktrees;
  bool get loading => worktreesController.loading;
  String? get error => worktreesController.error;
  bool get showSettings => selection.showSettings;
  bool get isBareLayout => worktreesController.isBareLayout;

  void _relay() => notifyListeners();

  void toggleSettings() => selection.toggleSettings();

  void closeSettings() => selection.closeSettings();

  /// Key of the selected repo's page that is shown (a tab, and an entry under
  /// the repo in the sidebar).
  String get repoPageKey => selection.pageKey;

  void showRepoPage(String key) => selection.showPage(key);

  Future<void> loadRepos() async {
    try {
      await Future.wait([registry.loadRepos(), metadata.load()]);
    } finally {
      if (!_reposLoaded.isCompleted) _reposLoaded.complete();
    }
    if (repos.isNotEmpty && selectedRepo == null) {
      final savedPath = await _store.loadLastSelectedRepoPath();
      final target = repos.firstWhere(
        (r) => r.path == savedPath,
        orElse: () => repos.first,
      );
      selection.selectRepo(target);
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

  Future<RepoConfig?> updateLastBaseBranch(
    RepoConfig repo,
    String branch,
  ) async {
    final updated = await preferences.updateLastBaseBranch(repo, branch);
    _replaceSelection(repo, updated);
    return updated;
  }

  /// Remembers [path] as the working directory for [repo]'s agents that run
  /// outside an issue's worktree.
  Future<RepoConfig?> updateAgentWorkingDirectory(
    RepoConfig repo,
    String path,
  ) async {
    final updated = await preferences.updateAgentWorkingDirectory(repo, path);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateRepoClaudePrompts(
    RepoConfig repo,
    List<ClaudePrompt> prompts,
  ) async {
    final updated = await preferences.updateRepoClaudePrompts(repo, prompts);
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

  Future<RepoConfig?> updateGithubConfig(
    RepoConfig repo,
    GithubConfig? config,
  ) async {
    final updated = await preferences.updateGithubConfig(repo, config);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateJiraProjectKey(
    RepoConfig repo,
    String? projectKey,
  ) async {
    final updated = await preferences.updateJiraProjectKey(repo, projectKey);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateJiraFixVersion(
    RepoConfig repo,
    String versionId,
  ) async {
    final updated = await preferences.updateJiraFixVersion(repo, versionId);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateJiraVersionBranch(
    RepoConfig repo,
    String versionId,
    String? branch,
  ) async {
    final updated = await preferences.updateJiraVersionBranch(
      repo,
      versionId,
      branch,
    );
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateJiraTriggers(
    RepoConfig repo,
    List<JiraTrigger> triggers,
  ) async {
    final updated = await preferences.updateJiraTriggers(repo, triggers);
    _replaceSelection(repo, updated);
    return updated;
  }

  Future<RepoConfig?> updateGithubMilestone(
    RepoConfig repo,
    int? milestoneNumber,
  ) async {
    final updated = await preferences.updateGithubMilestone(
      repo,
      milestoneNumber,
    );
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
    int? githubIssue,
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
      githubIssue: githubIssue,
      prAuthor: prAuthor,
    );
  }

  /// Creates a worktree in an explicit [repo] (not necessarily the selected
  /// one) and records its JIRA / base-branch / PR-author metadata.
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
    int? githubIssue,
    String? prAuthor,
    String? kickoffPrompt,
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

    // Write the API-supplied kickoff prompt into the worktree; only its path
    // is kept. Best-effort: a write failure must never block worktree
    // creation.
    String? kickoffPath;
    if (kickoffPrompt != null && kickoffPrompt.isNotEmpty) {
      try {
        kickoffPath = await _gitService.writeKickoffPrompt(
          repoPath: repo.path,
          worktreePath: worktreePath,
          content: kickoffPrompt,
        );
      } catch (e) {
        debugPrint('WorkspaceController: writeKickoffPrompt failed: $e');
      }
    }

    // Record what the worktree was made for and from.
    await metadata.update(
      repo.path,
      worktreePath,
      (m) => m.copyWith(
        jiraIssue: jiraIssue != null && jiraIssue.isNotEmpty ? jiraIssue : null,
        githubIssue: githubIssue,
        baseBranch: baseBranch != null && baseBranch.isNotEmpty
            ? baseBranch
            : null,
        prAuthor: prAuthor != null && prAuthor.isNotEmpty ? prAuthor : null,
        kickoffPromptPath: kickoffPath,
      ),
    );

    // Record the creation in the activity log.
    _logWorktreeEvent(
      type: WorktreeEventType.created,
      repo: repo,
      worktreePath: worktreePath,
      branch: newBranch ?? baseBranch,
      jiraIssue: jiraIssue,
    );

    return worktreePath;
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
    String? kickoffPrompt,
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
      kickoffPrompt: kickoffPrompt,
    );
    if (worktreePath == null) {
      throw Exception('Failed to create worktree "$worktreeName"');
    }

    return CreatedWorktree(
      worktreePath: worktreePath,
      branch: newBranch,
      kickoffPromptPath: metadata[worktreePath]?.kickoffPromptPath,
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

  /// Remembers a Claude CLI session for [worktreePath] in the repo at
  /// [repoPath], so the sidebar shows a shortcut to it, along with the
  /// [promptId] it was started with (see [RememberedSession.promptId]) and,
  /// the first time, when. No-op when the repo isn't registered.
  Future<void> rememberClaudeSession(
    String repoPath,
    String worktreePath, {
    String? promptId,
  }) async {
    if (_registryRepoForPath(repoPath) == null) return;
    await metadata.update(repoPath, worktreePath, (m) {
      final session = m.session;
      if (session != null && session.promptId == promptId) return m;
      return m.copyWith(
        session: RememberedSession(
          promptId: promptId,
          startedAt: session == null ? DateTime.now() : session.startedAt,
        ),
      );
    });
  }

  /// Drops the Claude session shortcut for [worktreePath] in the repo at
  /// [repoPath]. Any running terminal is left alone.
  Future<void> forgetClaudeSession(String repoPath, String worktreePath) async {
    if (_registryRepoForPath(repoPath) == null) return;
    await metadata.update(
      repoPath,
      worktreePath,
      (m) => m.copyWith(clearSession: true),
    );
  }

  RepoConfig? _registryRepoForPath(String repoPath) {
    for (final r in registry.repos) {
      if (r.path == repoPath) return r;
    }
    return null;
  }

  /// [worktreePath]'s metadata (it may be another repo's worktree), or null.
  WorktreeMetadata? metadataFor(String worktreePath) => metadata[worktreePath];

  Future<void> updateJiraIssue(String worktreePath, String? jiraIssue) async {
    final repo = selectedRepo;
    if (repo == null) return;
    await metadata.update(
      repo.path,
      worktreePath,
      (m) => jiraIssue == null || jiraIssue.isEmpty
          ? m.copyWith(clearJiraIssue: true)
          : m.copyWith(jiraIssue: jiraIssue),
    );
  }

  /// Hides or unhides a worktree. Hidden worktrees are filtered from the list
  /// unless "Show hidden worktrees" is enabled.
  Future<void> setWorktreeHidden(String worktreePath, bool hidden) =>
      setWorktreesHidden([worktreePath], hidden);

  /// Hides or unhides several worktrees in a single write.
  Future<void> setWorktreesHidden(
    List<String> worktreePaths,
    bool hidden,
  ) async {
    final repo = selectedRepo;
    if (repo == null || worktreePaths.isEmpty) return;
    await metadata.updateAll(
      repo.path,
      worktreePaths,
      (m) => m.copyWith(hidden: hidden),
    );
  }

  /// Snoozes or unsnoozes a worktree. PR worktrees auto-unsnooze when the PR is
  /// again assigned to me (see [clearSnoozeForBranch]); others stay snoozed
  /// until cleared manually.
  Future<void> setWorktreeSnoozed(String worktreePath, bool snoozed) async {
    final repo = selectedRepo;
    if (repo == null) return;
    await metadata.update(
      repo.path,
      worktreePath,
      (m) => m.copyWith(snoozed: snoozed),
    );
  }

  /// Clears the snooze on any worktree of the selected repo whose branch
  /// matches [headBranch]. Called when a PR transitions to requesting my review
  /// again, implementing "hide until the PR is again assigned to me".
  Future<void> clearSnoozeForBranch(String headBranch) async {
    final repo = selectedRepo;
    if (repo == null) return;
    final matching = [
      for (final w in worktreesController.worktrees)
        if (w.branch == headBranch && w.isSnoozed) w.path,
    ];
    if (matching.isEmpty) return;
    await metadata.updateAll(
      repo.path,
      matching,
      (m) => m.copyWith(snoozed: false),
    );
  }

  /// Fetches and fast-forwards [worktree]'s current branch to its upstream.
  /// Throws with a user-facing message when a clean fast-forward isn't possible.
  Future<PullResult> pullWorktree(Worktree worktree) =>
      worktreesController.pullWorktree(selectedRepo?.path, worktree);

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
    await metadata.forget([worktree.path]);
  }

  /// Lists the selected repo's worktrees again, and forgets the metadata of
  /// its worktrees that are gone.
  Future<void> refreshWorktrees() async {
    final repo = selectedRepo;
    await worktreesController.refreshForRepo(repo?.path);
    // A failed refresh leaves the list empty; don't mistake that for every
    // worktree having been removed.
    if (repo == null || worktreesController.error != null) return;
    await metadata.reconcile(repo.path, {
      for (final w in worktreesController.worktrees) w.path,
    });
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
    metadata.removeListener(_relay);
    worktreesController.removeListener(_relay);
    preferences.removeListener(_relay);
    registry.dispose();
    selection.dispose();
    worktreesController.dispose();
    metadata.dispose();
    preferences.dispose();
    super.dispose();
  }
}
