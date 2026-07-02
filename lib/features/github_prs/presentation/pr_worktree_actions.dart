import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/models/app_settings.dart';

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

/// Creates a worktree for [pr] (like [createWorktreeForPr]) and, on success,
/// launches the `claude` CLI in the built-in terminal seeded with the PR prompt
/// and model from [settings]. Used by both the per-PR "create & launch" button
/// and the auto-create-on-review-request path, so both behave identically.
Future<void> createWorktreeAndLaunchClaudeForPr(
  WorkspaceController workspace,
  TerminalController terminal,
  AppSettings settings,
  GithubPullRequest pr,
) async {
  final name = pr.headBranch.replaceAll('/', '-');
  try {
    final path = await workspace.addWorktree(
      name,
      baseBranch: pr.headBranch,
      jiraIssue: pr.jiraKey,
      prAuthor: pr.author,
    );
    if (path == null) {
      showAppSnackBar('Could not create worktree for ${pr.headBranch}');
      return;
    }
    // PRs always belong to the selected repo, so its path is the right repo
    // anchor for the terminal session; fall back to the worktree path.
    final repoPath = workspace.selectedRepo?.path ?? path;
    terminal.openTerminalWithCommand(
      'Claude: $name',
      path,
      repoPath,
      buildClaudePrCommand(settings, pr),
    );
    showAppSnackBar('Created worktree and launched Claude for ${pr.headBranch}');
  } catch (e) {
    showAppSnackBar(e.toString().replaceFirst('Exception: ', ''));
  }
}

/// Builds the `claude` CLI invocation for a PR launch, e.g.
/// `claude --model 'opus' 'Review #42 ...'`. The model (when set) and the
/// resolved prompt are single-quoted and shell-escaped so the embedded
/// `/bin/zsh -l` receives them intact.
String buildClaudePrCommand(AppSettings settings, GithubPullRequest pr) {
  final parts = <String>['claude'];
  final model = settings.prLaunchModel.trim();
  if (model.isNotEmpty) {
    parts.add('--model ${_shellSingleQuote(model)}');
  }
  final prompt = resolvePrPrompt(settings.prLaunchPrompt, pr);
  if (prompt.isNotEmpty) {
    parts.add(_shellSingleQuote(prompt));
  }
  return parts.join(' ');
}

/// Substitutes a PR's fields into a prompt [template]. Recognised placeholders:
/// `{number}`, `{title}`, `{url}`, `{branch}`, `{base}`, `{author}`, `{jira}`.
String resolvePrPrompt(String template, GithubPullRequest pr) {
  return template
      .replaceAll('{number}', pr.number.toString())
      .replaceAll('{title}', pr.title)
      .replaceAll('{url}', pr.htmlUrl)
      .replaceAll('{branch}', pr.headBranch)
      .replaceAll('{base}', pr.baseBranch)
      .replaceAll('{author}', pr.author)
      .replaceAll('{jira}', pr.jiraKey ?? '')
      .trim();
}

/// Wraps [s] in single quotes for POSIX shells, escaping embedded single quotes
/// via the standard `'\''` close-escape-reopen trick (same as the copilot CLI
/// command builder).
String _shellSingleQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";
