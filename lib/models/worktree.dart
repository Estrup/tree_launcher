class Worktree {
  final String path;
  final String branch;
  final String name;
  final bool isMain;
  final String commitHash;
  final String slot;

  Worktree({
    required this.path,
    required this.branch,
    required this.name,
    required this.isMain,
    required this.commitHash,
    this.slot = 'alpha',
  });

  Worktree copyWith({
    String? path,
    String? branch,
    String? name,
    bool? isMain,
    String? commitHash,
    String? slot,
  }) {
    return Worktree(
      path: path ?? this.path,
      branch: branch ?? this.branch,
      name: name ?? this.name,
      isMain: isMain ?? this.isMain,
      commitHash: commitHash ?? this.commitHash,
      slot: slot ?? this.slot,
    );
  }
}

class WorktreeListResult {
  final List<Worktree> worktrees;
  final bool isBareLayout;

  WorktreeListResult({required this.worktrees, required this.isBareLayout});
}
