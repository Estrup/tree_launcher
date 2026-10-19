/// A Claude session remembered in a worktree: a shortcut under its repo in
/// the sidebar, kept across restarts so it can be resumed.
class RememberedSession {
  const RememberedSession({this.promptId, this.startedAt});

  /// The prompt it was started with: a saved prompt's name or a built-in
  /// prompt id (see `issueContextPromptId`). Decides where the sidebar
  /// groups it.
  final String? promptId;

  /// When it was first started; null for ones remembered before start times
  /// were kept, which sort as oldest.
  final DateTime? startedAt;

  @override
  bool operator ==(Object other) =>
      other is RememberedSession &&
      other.promptId == promptId &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(promptId, startedAt);
}

/// What the app knows about a worktree beyond what git says. Keyed by the
/// worktree's [path]; [repoPath] is the repo it belongs to.
class WorktreeMetadata {
  const WorktreeMetadata({
    required this.path,
    required this.repoPath,
    this.baseBranch,
    this.jiraIssue,
    this.githubIssue,
    this.prAuthor,
    this.kickoffPromptPath,
    this.hidden = false,
    this.snoozed = false,
    this.session,
  });

  final String path;
  final String repoPath;

  /// The branch it was created from.
  final String? baseBranch;

  /// The Jira issue it is for.
  final String? jiraIssue;

  /// The GitHub issue it was made for from the Issues tab.
  final int? githubIssue;

  /// The login of the author of the PR it was made to review.
  final String? prAuthor;

  /// The kickoff prompt file an agent API caller left in it.
  final String? kickoffPromptPath;

  /// Hidden from the worktree list (unless hidden ones are shown).
  final bool hidden;

  /// Snoozed: PR worktrees wake up when the PR asks for my review again.
  final bool snoozed;

  /// The Claude session remembered here, if any.
  final RememberedSession? session;

  /// Whether there is nothing to keep, so the row can go.
  bool get isEmpty =>
      baseBranch == null &&
      jiraIssue == null &&
      githubIssue == null &&
      prAuthor == null &&
      kickoffPromptPath == null &&
      !hidden &&
      !snoozed &&
      session == null;

  WorktreeMetadata copyWith({
    String? baseBranch,
    String? jiraIssue,
    bool clearJiraIssue = false,
    int? githubIssue,
    String? prAuthor,
    String? kickoffPromptPath,
    bool? hidden,
    bool? snoozed,
    RememberedSession? session,
    bool clearSession = false,
  }) => WorktreeMetadata(
    path: path,
    repoPath: repoPath,
    baseBranch: baseBranch ?? this.baseBranch,
    jiraIssue: clearJiraIssue ? null : (jiraIssue ?? this.jiraIssue),
    githubIssue: githubIssue ?? this.githubIssue,
    prAuthor: prAuthor ?? this.prAuthor,
    kickoffPromptPath: kickoffPromptPath ?? this.kickoffPromptPath,
    hidden: hidden ?? this.hidden,
    snoozed: snoozed ?? this.snoozed,
    session: clearSession ? null : (session ?? this.session),
  );

  @override
  bool operator ==(Object other) =>
      other is WorktreeMetadata &&
      other.path == path &&
      other.repoPath == repoPath &&
      other.baseBranch == baseBranch &&
      other.jiraIssue == jiraIssue &&
      other.githubIssue == githubIssue &&
      other.prAuthor == prAuthor &&
      other.kickoffPromptPath == kickoffPromptPath &&
      other.hidden == hidden &&
      other.snoozed == snoozed &&
      other.session == session;

  @override
  int get hashCode => Object.hash(
    path,
    repoPath,
    baseBranch,
    jiraIssue,
    githubIssue,
    prAuthor,
    kickoffPromptPath,
    hidden,
    snoozed,
    session,
  );
}
