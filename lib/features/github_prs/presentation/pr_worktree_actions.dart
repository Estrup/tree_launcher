import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// Creates a worktree that checks out [pr]'s existing head branch and shows a
/// toast on success or failure (including "already exists"). Used by both the
/// per-PR quick-create button and the auto-create-on-review-request path, so
/// both behave identically.
Future<void> createWorktreeForPr(
  WorkspaceController workspace,
  GithubPullRequest pr,
) async {
  // The branch already exists on the remote, so we check it out directly
  // (baseBranch with no newBranch). The folder name can't contain slashes.
  final name = pr.headBranch.replaceAll('/', '-');
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
