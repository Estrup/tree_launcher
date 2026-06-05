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
    );
  }
}

class WorktreeListResult {
  final List<Worktree> worktrees;
  final bool isBareLayout;

  WorktreeListResult({required this.worktrees, required this.isBareLayout});
}
