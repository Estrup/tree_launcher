import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/worktree_metadata_controller.dart';

class WorktreeController extends ChangeNotifier {
  WorktreeController({
    required GitService gitService,
    required WorktreeMetadataController metadata,
  }) : _gitService = gitService,
       _metadata = metadata {
    metadata.addListener(_onMetadataChanged);
  }

  final GitService _gitService;

  /// The worktrees' issue, base branch, hidden/snoozed state and so on,
  /// applied to the listed worktrees.
  final WorktreeMetadataController _metadata;

  List<Worktree> _worktrees = [];
  bool _loading = false;
  String? _error;
  bool _isBareLayout = false;

  /// Paths of the worktrees whose sessions are shown below their row.
  final Set<String> _sessionsExpanded = {};

  List<Worktree> get worktrees => List.unmodifiable(_worktrees);
  bool get loading => _loading;
  String? get error => _error;
  bool get isBareLayout => _isBareLayout;

  /// Whether the sessions of the worktree at [path] are shown below its row.
  bool isSessionsExpanded(String path) => _sessionsExpanded.contains(path);

  /// Shows or hides the sessions of the worktree at [path] below its row.
  void toggleSessionsExpanded(String path) {
    if (!_sessionsExpanded.remove(path)) _sessionsExpanded.add(path);
    notifyListeners();
  }

  void _onMetadataChanged() {
    if (_worktrees.isEmpty) return;
    _hydrateMetadata();
    notifyListeners();
  }

  Future<void> refreshForRepo(String? repoPath) async {
    if (repoPath == null) {
      _worktrees = [];
      _error = null;
      _loading = false;
      _isBareLayout = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _gitService.getWorktrees(repoPath);
      _worktrees = result.worktrees;
      _isBareLayout = result.isBareLayout;
      _hydrateMetadata();
      _error = null;
    } catch (error) {
      _worktrees = [];
      _error = error.toString();
    }

    _loading = false;
    notifyListeners();
  }

  /// Applies each worktree's metadata (Jira issue, base branch, ...).
  void _hydrateMetadata() {
    _worktrees = [for (final wt in _worktrees) wt.withMetadata(_metadata[wt.path])];
  }

  Future<List<String>> listBranches(String? repoPath) async {
    if (repoPath == null) return [];
    return _gitService.listBranches(repoPath);
  }

  Future<String?> addWorktree(
    String? repoPath,
    String name, {
    String? baseBranch,
    String? newBranch,
    bool useNestedWorktrees = false,
  }) async {
    if (repoPath == null) return null;
    final path = await _gitService.addWorktree(
      repoPath,
      name,
      baseBranch: baseBranch,
      newBranch: newBranch,
      useNestedWorktrees: useNestedWorktrees,
    );
    await refreshForRepo(repoPath);
    return path;
  }

  /// Fetches and fast-forwards [worktree]'s current branch, then refreshes the
  /// list so the row's commit hash reflects the new HEAD. Rethrows any
  /// [GitService] error so the caller can surface a message.
  Future<PullResult> pullWorktree(String? repoPath, Worktree worktree) async {
    final result = await _gitService.pullCurrentBranch(worktree.path);
    await refreshForRepo(repoPath);
    return result;
  }

  Future<void> deleteWorktree(String? repoPath, Worktree worktree) async {
    if (repoPath == null) return;
    await _gitService.removeWorktree(repoPath, worktree.path);
    _worktrees = _worktrees
        .where((item) => item.path != worktree.path)
        .toList();
    notifyListeners();
    await refreshForRepo(repoPath);
  }

  @override
  void dispose() {
    _metadata.removeListener(_onMetadataChanged);
    super.dispose();
  }
}
