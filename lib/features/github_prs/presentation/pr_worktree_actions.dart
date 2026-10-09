import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// Creates a worktree that checks out [pr]'s existing head branch and shows a
/// toast on success or failure (including "already exists"). Used by the
/// per-PR quick-create button in the PRs tab.
Future<void> createWorktreeForPr(
  WorkspaceController workspace,
  GithubPullRequest pr,
) async {
  // The branch already exists on the remote, so we check it out directly
  // (baseBranch with no newBranch). Only the folder name puts the Jira key last.
  final name = worktreeNameForPrBranch(pr.headBranch, jiraKey: pr.jiraKey);
  try {
    // Attach the Jira ticket parsed from the PR title (e.g. "AU2-5555") and the
    // PR author, so the worktree carries its PR origin.
    final path = await workspace.addWorktree(
      name,
      baseBranch: pr.headBranch,
      jiraIssue: pr.jiraKey,
      prAuthor: pr.author,
    );
    showAppSnackBar(
      path != null
          ? 'Created worktree for ${pr.headBranch}'
          : 'Could not create worktree for ${pr.headBranch}',
    );
  } catch (e) {
    showAppSnackBar(e.toString().replaceFirst('Exception: ', ''));
  }
}

/// First message for a Claude session on [pr]: what it is, which branch it
/// merges where, and its Jira issue when the title names one.
String prClaudeContextPrompt(GithubPullRequest pr) {
  final issue = pr.jiraKey;
  return 'Context: Working on pull request #${pr.number} "${pr.title}" '
      '(${pr.headBranch} into ${pr.baseBranch})'
      '${issue != null ? ' for issue $issue' : ''}.';
}
