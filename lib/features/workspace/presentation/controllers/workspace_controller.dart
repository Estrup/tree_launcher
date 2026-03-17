import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/copilot/domain/copilot_session.dart';
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
      selection.selectRepo(repos.first);
      _syncSlotAssignments(repos.first);
      await worktreesController.refreshForRepo(repos.first.path);
    }
    notifyListeners();
  }

  Future<void> addRepo(String path) async {
    final repo = await registry.addRepo(path);
    if (selectedRepo == null) {
      selection.selectRepo(repo);
      await worktreesController.refreshForRepo(repo.path);
    }
    notifyListeners();
  }

  Future<void> removeRepo(RepoConfig repo) async {
    await registry.removeRepo(repo);
    if (selectedRepo == repo) {
      final fallback = repos.isNotEmpty ? repos.first : null;
      selection.selectRepo(fallback);
      await worktreesController.refreshForRepo(fallback?.path);
    }
    notifyListeners();
  }

  Future<void> selectRepo(RepoConfig repo) async {
    if (selectedRepo == repo) return;
    selection.selectRepo(repo);
    _syncSlotAssignments(repo);
    await worktreesController.refreshForRepo(repo.path);
  }

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

  Future<List<String>> listBranches() async {
    return worktreesController.listBranches(selectedRepo?.path);
  }

  Future<String?> addWorktree(
    String name, {
    String? baseBranch,
    String? newBranch,
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
      final newRepo = await preferences.updateSlotAssignments(repo, updated);
      _replaceSelection(repo, newRepo);
      worktreesController.setSlotAssignments(
        newRepo?.slotAssignments ?? updated,
      );
    }

    return worktreePath;
  }

  Future<void> deleteWorktree(Worktree worktree) async {
    await worktreesController.deleteWorktree(selectedRepo?.path, worktree);

    // Remove slot assignment for the deleted worktree
    if (selectedRepo != null) {
      final repo = selectedRepo!;
      final updated = Map<String, String>.from(repo.slotAssignments);
      updated.remove(worktree.path);
      final newRepo = await preferences.updateSlotAssignments(repo, updated);
      _replaceSelection(repo, newRepo);
      worktreesController.setSlotAssignments(
        newRepo?.slotAssignments ?? updated,
      );
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
    final newRepo = await preferences.updateSlotAssignments(repo, updated);
    _replaceSelection(repo, newRepo);
    worktreesController.setSlotAssignments(
      newRepo?.slotAssignments ?? updated,
    );
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
