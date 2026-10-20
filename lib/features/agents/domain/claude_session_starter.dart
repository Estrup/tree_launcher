import 'package:tree_launcher/features/agents/domain/agent_run.dart';

/// Starts Claude in a new or an existing worktree in one go, as the Start
/// Claude Session dialog does, for the agent HTTP API.
///
/// Implemented by the `StartClaudeInWorktree` use case over the live
/// controllers, so the worktree, the terminal session and any agent run show
/// in the app at once.
abstract interface class ClaudeSessionStarter {
  /// Starts what [request] asks for. Throws [RepoNotFoundException],
  /// [WorktreeNotFoundException], [WorktreeConflictException],
  /// [ClaudePromptException] (before any worktree is created) or
  /// [ClaudeStartFailedException] (after one was).
  Future<StartedClaudeSession> start(ClaudeSessionRequest request);
}

/// What to start: in [existingWorktree] when given, else in [newWorktree].
class ClaudeSessionRequest {
  const ClaudeSessionRequest({
    required this.repoName,
    this.existingWorktree,
    this.newWorktree,
    this.issueKey,
    this.prompt,
    this.promptText,
    this.prNumber,
    this.title,
    this.model,
    this.effort,
    this.show = false,
  }) : assert((existingWorktree == null) != (newWorktree == null));

  final String repoName;

  /// An existing worktree of the repo: its folder name or absolute path.
  final String? existingWorktree;

  final NewWorktreeRequest? newWorktree;

  /// The Jira issue. A new worktree records it; in an existing worktree it
  /// defaults to the worktree's recorded issue.
  final String? issueKey;

  /// A saved prompt's name (any case), [issueContextPromptId] or
  /// [kickoffPromptId]; null for none.
  final String? prompt;

  /// A first message of the caller's own; not with [prompt].
  final String? promptText;

  final int? prNumber;

  /// An agent run's title.
  final String? title;

  /// The `--model` alias and `--effort` level; null leaves the flag out.
  final String? model;
  final String? effort;

  /// Whether to bring the new terminal tab to the front.
  final bool show;
}

/// A worktree to create, its names already normalised and validated.
class NewWorktreeRequest {
  const NewWorktreeRequest({
    required this.worktreeName,
    required this.baseBranch,
    required this.newBranch,
    this.kickoffPrompt,
  });

  final String worktreeName;
  final String baseBranch;

  /// The full branch name, prefix included.
  final String newBranch;

  final String? kickoffPrompt;
}

/// The worktree a session was started in.
class StartedWorktree {
  const StartedWorktree({
    required this.name,
    required this.path,
    required this.branch,
    required this.created,
    this.baseBranch,
    this.issueKey,
    this.kickoffPromptPath,
  });

  final String name;
  final String path;
  final String branch;
  final String? baseBranch;
  final String? issueKey;

  /// Whether the request created it.
  final bool created;

  final String? kickoffPromptPath;

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'branch': branch,
    'baseBranch': baseBranch,
    'issueKey': issueKey,
    'created': created,
    'kickoffPromptPath': kickoffPromptPath,
  };
}

/// What was started: the session in [worktree], and the agent run when the
/// prompt has a kind.
class StartedClaudeSession {
  const StartedClaudeSession({
    required this.repoName,
    required this.worktree,
    required this.title,
    this.promptId,
    this.prompt,
    this.model,
    this.effort,
    this.agent,
  });

  final String repoName;
  final StartedWorktree worktree;

  /// The terminal tab's title.
  final String title;

  /// What the session is recorded with: a saved prompt's name, a built-in
  /// prompt id, or null.
  final String? promptId;

  /// The first message as sent; null for none.
  final String? prompt;

  final String? model;
  final String? effort;
  final AgentRun? agent;
}

/// Thrown when the repo has no worktree with the requested name or path.
class WorktreeNotFoundException implements Exception {
  const WorktreeNotFoundException(this.repoName, this.worktree);

  final String repoName;
  final String worktree;

  @override
  String toString() => 'No worktree "$worktree" in repo "$repoName"';
}

/// Thrown when the prompt can't be used: unknown, or missing a value it
/// needs. [details] are extra keys for the response, e.g. `prompts`.
class ClaudePromptException implements Exception {
  const ClaudePromptException(this.message, {this.details = const {}});

  final String message;
  final Map<String, Object> details;

  @override
  String toString() => message;
}

/// Thrown when [worktree] was created but Claude didn't start in it.
class ClaudeStartFailedException implements Exception {
  const ClaudeStartFailedException(this.message, this.worktree);

  final String message;
  final StartedWorktree worktree;

  @override
  String toString() => message;
}
