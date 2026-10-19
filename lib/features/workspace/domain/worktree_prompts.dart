import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

/// Builds the standard Claude launch context prompt from a worktree's recorded
/// JIRA issue and base branch. Returns null when neither is known.
String? claudeContextPrompt(Worktree wt) =>
    claudeContextPromptFor(issue: wt.jiraIssue, base: wt.baseBranch);

/// [claudeContextPrompt] from bare values, for a worktree that may not be in
/// the list yet.
String? claudeContextPromptFor({String? issue, String? base}) {
  if (issue != null && issue.isNotEmpty && base != null && base.isNotEmpty) {
    return 'Context: Working on issue $issue where the base branch is $base.';
  }
  if (issue != null && issue.isNotEmpty) {
    return 'Context: Working on issue $issue.';
  }
  if (base != null && base.isNotEmpty) {
    return 'Context: The base branch is $base.';
  }
  return null;
}

/// Short instruction that points Claude at the worktree's API-supplied
/// kickoff-prompt file. The (potentially large) plan stays in the file rather
/// than being inlined into the launch URL. Returns null when no kickoff prompt
/// is attached to [wt].
String? kickoffPromptLaunchPrompt(Worktree wt) => wt.kickoffPromptPath == null
    ? null
    : 'Read and follow the implementation plan in $kickoffPromptRelativePath.';
/// The shared checkout a session that only reads the code runs in by
/// default: the [remembered] one, else the worktree on the main line.
Worktree? defaultSharedWorktree(
  List<Worktree> worktrees, {
  String? remembered,
}) {
  return worktrees.where((w) => w.path == remembered).firstOrNull ??
      worktrees
          .where((w) => const ['develop', 'main', 'master'].contains(w.branch))
          .firstOrNull ??
      worktrees.where((w) => w.isMain).firstOrNull ??
      worktrees.firstOrNull;
}

/// Fills a saved [ClaudePrompt]'s placeholders from an existing worktree's
/// recorded fields. Returns null when the resolved text is empty.
String? resolveWorktreePrompt(
  ClaudePrompt prompt,
  Worktree wt, {
  String? repoName,
  int? prNumber,
}) => resolveClaudePrompt(
  prompt,
  issue: wt.jiraIssue,
  baseBranch: wt.baseBranch,
  worktreeName: wt.name,
  worktreePath: wt.path,
  repoName: repoName,
  prNumber: prNumber,
);

/// [resolveWorktreePrompt] from bare values, for a worktree that may not be in
/// the list yet.
String? resolveClaudePrompt(
  ClaudePrompt prompt, {
  String? issue,
  String? baseBranch,
  required String worktreeName,
  required String worktreePath,
  String? repoName,
  int? prNumber,
}) {
  var p = prompt.prompt;
  p = p.replaceAll('{issue}', issue ?? '');
  p = p.replaceAll('{pr}', prNumber == null ? '' : '$prNumber');
  p = p.replaceAll('{base_branch}', baseBranch ?? '');
  p = p.replaceAll('{worktree}', worktreeName);
  p = p.replaceAll('{path}', worktreePath);
  p = p.replaceAll('{repo}', repoName ?? '');
  p = p.replaceAll(RegExp(r'\s+'), ' ').trim();
  return p.isEmpty ? null : p;
}
