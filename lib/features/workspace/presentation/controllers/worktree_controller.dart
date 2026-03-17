import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';

class WorktreeController extends ChangeNotifier {
  WorktreeController({required GitService gitService})
    : _gitService = gitService;

  final GitService _gitService;

  List<Worktree> _worktrees = [];
  bool _loading = false;
  String? _error;
  bool _isBareLayout = false;

  List<Worktree> get worktrees => List.unmodifiable(_worktrees);
  bool get loading => _loading;
  String? get error => _error;
  bool get isBareLayout => _isBareLayout;

  /// Slot assignments from config, keyed by worktree path.
  Map<String, String> _slotAssignments = {};
  Map<String, String> get slotAssignments =>
      Map.unmodifiable(_slotAssignments);

  void setSlotAssignments(Map<String, String> assignments) {
    _slotAssignments = Map.of(assignments);
    _hydrateSlots();
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
      _hydrateSlots();
      _error = null;
    } catch (error) {
      _worktrees = [];
      _error = error.toString();
    }

    _loading = false;
    notifyListeners();
  }

  /// Assigns slots from [_slotAssignments] to worktrees.
  /// Unassigned worktrees get 'alpha' as default.
  void _hydrateSlots() {
    _worktrees = _worktrees.map((wt) {
      final slot = _slotAssignments[wt.path] ?? 'alpha';
      return wt.copyWith(slot: slot);
    }).toList();
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
  }) async {
    if (repoPath == null) return null;
    final path = await _gitService.addWorktree(
      repoPath,
      name,
      baseBranch: baseBranch,
      newBranch: newBranch,
    );
    await refreshForRepo(repoPath);
    return path;
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
}
