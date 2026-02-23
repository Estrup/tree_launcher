class Worktree {
  final String path;
  final String branch;
  final String name;
  final bool isMain;
  final String commitHash;

  Worktree({
    required this.path,
    required this.branch,
    required this.name,
    required this.isMain,
    required this.commitHash,
  });
}
