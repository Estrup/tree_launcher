class Worktree {
  final String path;
  final String branch;
  final String name;
  final bool isMain;
  final String commitHash;
  final String slot;

  /// JIRA issue key attached to this worktree (e.g. AU2-4859), or null.
  final String? jiraIssue;

  /// Base branch this worktree was created from (e.g. develop), or null.
  final String? baseBranch;

  /// GitHub login of the PR author this worktree was created from, or null.
  /// Persisted so worktrees can later be grouped by PR creator.
  final String? prAuthor;

  /// Whether this worktree is hidden from the list (unless "Show hidden
  /// worktrees" is enabled). Hydrated from RepoConfig.hiddenWorktrees.
  final bool isHidden;

  /// Whether this worktree is snoozed. PR worktrees auto-unsnooze when the PR
  /// is again assigned to me; others stay snoozed until cleared manually.
  /// Hydrated from RepoConfig.snoozedWorktrees.
  final bool isSnoozed;

  Worktree({
    required this.path,
    required this.branch,
    required this.name,
    required this.isMain,
    required this.commitHash,
    this.slot = 'alpha',
    this.jiraIssue,
    this.baseBranch,
    this.prAuthor,
    this.isHidden = false,
    this.isSnoozed = false,
  });

  Worktree copyWith({
    String? path,
    String? branch,
    String? name,
    bool? isMain,
    String? commitHash,
    String? slot,
    String? jiraIssue,
    String? baseBranch,
    String? prAuthor,
    bool? isHidden,
    bool? isSnoozed,
  }) {
    return Worktree(
      path: path ?? this.path,
      branch: branch ?? this.branch,
      name: name ?? this.name,
      isMain: isMain ?? this.isMain,
      commitHash: commitHash ?? this.commitHash,
      slot: slot ?? this.slot,
      jiraIssue: jiraIssue ?? this.jiraIssue,
      baseBranch: baseBranch ?? this.baseBranch,
      prAuthor: prAuthor ?? this.prAuthor,
      isHidden: isHidden ?? this.isHidden,
      isSnoozed: isSnoozed ?? this.isSnoozed,
    );
  }
}

class WorktreeListResult {
  final List<Worktree> worktrees;
  final bool isBareLayout;

  WorktreeListResult({required this.worktrees, required this.isBareLayout});
}
