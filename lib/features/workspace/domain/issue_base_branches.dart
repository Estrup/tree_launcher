/// The default base branch of a new worktree for a Jira issue: the branch its
/// repo maps to the issue's fixVersion (Repo settings → Jira).
abstract interface class IssueBaseBranches {
  /// The branch the repo named [repoName] maps to one of [issueKey]'s
  /// fixVersions; null when none is mapped or the issue can't be read.
  Future<String?> baseBranchFor(String repoName, String issueKey);
}
