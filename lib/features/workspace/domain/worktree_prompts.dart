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
String? kickoffPromptLaunchPrompt(Worktree wt) =>
    wt.kickoffPromptPath == null ? null : _kickoffInstruction;

const _kickoffInstruction =
    'Read and follow the implementation plan in $kickoffPromptRelativePath.';

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
}) => fillClaudePlaceholders(
  prompt.prompt,
  issue: issue,
  baseBranch: baseBranch,
  worktreeName: worktreeName,
  worktreePath: worktreePath,
  repoName: repoName,
  prNumber: prNumber,
);

/// Fills the placeholders of a prompt [template] (see [ClaudePrompt]).
/// Returns null when the resolved text is empty.
String? fillClaudePlaceholders(
  String template, {
  String? issue,
  String? baseBranch,
  required String worktreeName,
  required String worktreePath,
  String? repoName,
  int? prNumber,
}) {
  var p = template;
  p = p.replaceAll('{issue}', issue ?? '');
  p = p.replaceAll('{pr}', prNumber == null ? '' : '$prNumber');
  p = p.replaceAll('{base_branch}', baseBranch ?? '');
  p = p.replaceAll('{worktree}', worktreeName);
  p = p.replaceAll('{path}', worktreePath);
  p = p.replaceAll('{repo}', repoName ?? '');
  p = p.replaceAll(RegExp(r'\s+'), ' ').trim();
  return p.isEmpty ? null : p;
}

/// Why [template] can't be filled in: it uses `{issue}` without an [issue],
/// or `{pr}` without a [prNumber]. Null when it can.
String? missingPlaceholderValue(
  String template, {
  String? issue,
  int? prNumber,
}) {
  if (issue == null && template.contains('{issue}')) {
    return 'the prompt uses {issue}, but there is no issue key';
  }
  if (prNumber == null && template.contains('{pr}')) {
    return 'the prompt uses {pr}, but there is no PR number';
  }
  return null;
}

/// What a Claude session's first message is made from: the options of the
/// Start Claude dialog's prompt panel, plus text of the caller's own.
sealed class ClaudePromptChoice {
  const ClaudePromptChoice();
}

/// No first message.
class NoClaudePrompt extends ClaudePromptChoice {
  const NoClaudePrompt();
}

/// The issue-context message ([claudeContextPromptFor]), or [text] when
/// given, e.g. a PR's context.
class ContextClaudePrompt extends ClaudePromptChoice {
  const ContextClaudePrompt([this.text]);

  final String? text;
}

/// Points Claude at the worktree's staged kickoff-prompt file.
class KickoffClaudePrompt extends ClaudePromptChoice {
  const KickoffClaudePrompt();
}

/// A saved prompt, its placeholders filled in.
class SavedClaudePrompt extends ClaudePromptChoice {
  const SavedClaudePrompt(this.prompt);

  final ClaudePrompt prompt;
}

/// A first message of the caller's own, its placeholders filled in.
class TextClaudePrompt extends ClaudePromptChoice {
  const TextClaudePrompt(this.text);

  final String text;
}

/// The first message [choice] makes for the worktree at [worktreePath].
/// [kickoffPromptPath] is the worktree's staged kickoff file, if any; a
/// [KickoffClaudePrompt] without one makes none.
String? firstClaudeMessage(
  ClaudePromptChoice choice, {
  String? issue,
  String? baseBranch,
  required String worktreeName,
  required String worktreePath,
  String? repoName,
  int? prNumber,
  String? kickoffPromptPath,
}) => switch (choice) {
  NoClaudePrompt() => null,
  ContextClaudePrompt(:final text) =>
    text ?? claudeContextPromptFor(issue: issue, base: baseBranch),
  KickoffClaudePrompt() =>
    kickoffPromptPath == null ? null : _kickoffInstruction,
  SavedClaudePrompt(:final prompt) => resolveClaudePrompt(
    prompt,
    issue: issue,
    baseBranch: baseBranch,
    worktreeName: worktreeName,
    worktreePath: worktreePath,
    repoName: repoName,
    prNumber: prNumber,
  ),
  TextClaudePrompt(:final text) => fillClaudePlaceholders(
    text,
    issue: issue,
    baseBranch: baseBranch,
    worktreeName: worktreeName,
    worktreePath: worktreePath,
    repoName: repoName,
    prNumber: prNumber,
  ),
};
