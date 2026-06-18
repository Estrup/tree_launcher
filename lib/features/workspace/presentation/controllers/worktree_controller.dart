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

  /// JIRA issue keys from config, keyed by worktree path.
  Map<String, String> _jiraIssues = {};
  Map<String, String> get jiraIssues => Map.unmodifiable(_jiraIssues);

  void setJiraIssues(Map<String, String> issues) {
    _jiraIssues = Map.of(issues);
    _hydrateSlots();
    notifyListeners();
  }

  /// Base branches from config, keyed by worktree path.
  Map<String, String> _baseBranches = {};
  Map<String, String> get baseBranches => Map.unmodifiable(_baseBranches);

  void setBaseBranches(Map<String, String> branches) {
    _baseBranches = Map.of(branches);
    _hydrateSlots();
    notifyListeners();
  }

  /// PR author logins from config, keyed by worktree path.
  Map<String, String> _prAuthors = {};
  Map<String, String> get prAuthors => Map.unmodifiable(_prAuthors);

  void setPrAuthors(Map<String, String> authors) {
    _prAuthors = Map.of(authors);
    _hydrateSlots();
    notifyListeners();
  }

  /// Kickoff-prompt file paths from config, keyed by worktree path.
  Map<String, String> _kickoffPrompts = {};
  Map<String, String> get kickoffPrompts => Map.unmodifiable(_kickoffPrompts);

  void setKickoffPrompts(Map<String, String> prompts) {
    _kickoffPrompts = Map.of(prompts);
    _hydrateSlots();
    notifyListeners();
  }

  /// Hidden worktree paths from config.
  Set<String> _hiddenWorktrees = {};
  Set<String> get hiddenWorktrees => Set.unmodifiable(_hiddenWorktrees);

  void setHiddenWorktrees(Iterable<String> paths) {
    _hiddenWorktrees = paths.toSet();
    _hydrateSlots();
    notifyListeners();
  }

  /// Snoozed worktree paths from config.
  Set<String> _snoozedWorktrees = {};
  Set<String> get snoozedWorktrees => Set.unmodifiable(_snoozedWorktrees);

  void setSnoozedWorktrees(Iterable<String> paths) {
    _snoozedWorktrees = paths.toSet();
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

  /// Assigns slots and JIRA issues from config to worktrees.
  /// Unassigned worktrees get 'alpha' as default slot.
  void _hydrateSlots() {
    _worktrees = _worktrees.map((wt) {
      final slot = _slotAssignments[wt.path] ?? 'alpha';
      return wt.copyWith(
        slot: slot,
        jiraIssue: _jiraIssues[wt.path],
        baseBranch: _baseBranches[wt.path],
        prAuthor: _prAuthors[wt.path],
        kickoffPromptPath: _kickoffPrompts[wt.path],
        isHidden: _hiddenWorktrees.contains(wt.path),
        isSnoozed: _snoozedWorktrees.contains(wt.path),
      );
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
