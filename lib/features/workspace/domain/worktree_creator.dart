/// A repo-targeted worktree-creation seam.
///
/// Implemented by the live `WorkspaceController` and consumed by the agent HTTP
/// API. Routing API-driven creation through the controller (rather than writing
/// config directly) keeps the in-memory repo state authoritative: the running
/// app never reloads config from disk, so a direct write would be silently
/// clobbered by the next UI save.
abstract class WorktreeCreator {
  /// Creates a worktree in the repo named [repoName].
  ///
  /// [newBranch] is the fully-resolved branch name (prefix already applied).
  /// Throws [RepoNotFoundException] if no repo matches [repoName].
  Future<CreatedWorktree> createWorktree({
    required String repoName,
    required String worktreeName,
    required String baseBranch,
    required String newBranch,
    String? jiraIssue,
  });
}

/// The outcome of a successful worktree creation.
class CreatedWorktree {
  const CreatedWorktree({
    required this.worktreePath,
    required this.branch,
    required this.slot,
  });

  final String worktreePath;
  final String branch;
  final String slot;
}

/// Thrown when no repo matches the requested name.
class RepoNotFoundException implements Exception {
  const RepoNotFoundException(this.repoName);

  final String repoName;

  @override
  String toString() => 'No repo found with name "$repoName"';
}
