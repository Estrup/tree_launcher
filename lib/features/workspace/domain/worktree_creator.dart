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
  /// When [kickoffPrompt] is non-empty its text is written to a file inside the
  /// new worktree and referenced from [CreatedWorktree.kickoffPromptPath].
  /// Throws [RepoNotFoundException] if no repo matches [repoName].
  Future<CreatedWorktree> createWorktree({
    required String repoName,
    required String worktreeName,
    required String baseBranch,
    required String newBranch,
    String? jiraIssue,
    String? kickoffPrompt,
  });
}

/// The outcome of a successful worktree creation.
class CreatedWorktree {
  const CreatedWorktree({
    required this.worktreePath,
    required this.branch,
    required this.slot,
    this.kickoffPromptPath,
  });

  final String worktreePath;
  final String branch;
  final String slot;

  /// Absolute path to the written kickoff-prompt file, or null when no prompt
  /// was supplied (or the write failed).
  final String? kickoffPromptPath;
}

/// Thrown when no repo matches the requested name.
class RepoNotFoundException implements Exception {
  const RepoNotFoundException(this.repoName);

  final String repoName;

  @override
  String toString() => 'No repo found with name "$repoName"';
}
