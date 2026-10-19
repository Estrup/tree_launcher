import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';

class Worktree {
  final String path;
  final String branch;
  final String name;
  final bool isMain;
  final String commitHash;

  /// JIRA issue key attached to this worktree (e.g. AU2-4859), or null.
  final String? jiraIssue;

  /// Number of the GitHub issue attached to this worktree, or null.
  final int? githubIssue;

  /// Base branch this worktree was created from (e.g. develop), or null.
  final String? baseBranch;

  /// GitHub login of the PR author this worktree was created from, or null.
  /// Persisted so worktrees can later be grouped by PR creator.
  final String? prAuthor;

  /// Absolute path to the API-supplied kickoff-prompt file inside this worktree
  /// (see [kickoffPromptRelativePath]), or null.
  final String? kickoffPromptPath;

  /// Whether this worktree is hidden from the list (unless "Show hidden
  /// worktrees" is enabled).
  final bool isHidden;

  /// Whether this worktree is snoozed. PR worktrees auto-unsnooze when the PR
  /// is again assigned to me; others stay snoozed until cleared manually.
  final bool isSnoozed;

  Worktree({
    required this.path,
    required this.branch,
    required this.name,
    required this.isMain,
    required this.commitHash,
    this.jiraIssue,
    this.githubIssue,
    this.baseBranch,
    this.prAuthor,
    this.kickoffPromptPath,
    this.isHidden = false,
    this.isSnoozed = false,
  });

  Worktree copyWith({
    String? path,
    String? branch,
    String? name,
    bool? isMain,
    String? commitHash,
    String? jiraIssue,
    int? githubIssue,
    String? baseBranch,
    String? prAuthor,
    String? kickoffPromptPath,
    bool? isHidden,
    bool? isSnoozed,
  }) {
    return Worktree(
      path: path ?? this.path,
      branch: branch ?? this.branch,
      name: name ?? this.name,
      isMain: isMain ?? this.isMain,
      commitHash: commitHash ?? this.commitHash,
      jiraIssue: jiraIssue ?? this.jiraIssue,
      githubIssue: githubIssue ?? this.githubIssue,
      baseBranch: baseBranch ?? this.baseBranch,
      prAuthor: prAuthor ?? this.prAuthor,
      kickoffPromptPath: kickoffPromptPath ?? this.kickoffPromptPath,
      isHidden: isHidden ?? this.isHidden,
      isSnoozed: isSnoozed ?? this.isSnoozed,
    );
  }
}

extension WorktreeWithMetadata on Worktree {
  /// This worktree as git lists it, with [metadata]'s fields (or none, when
  /// null) in place of any it had.
  Worktree withMetadata(WorktreeMetadata? metadata) => Worktree(
    path: path,
    branch: branch,
    name: name,
    isMain: isMain,
    commitHash: commitHash,
    jiraIssue: metadata?.jiraIssue,
    githubIssue: metadata?.githubIssue,
    baseBranch: metadata?.baseBranch,
    prAuthor: metadata?.prAuthor,
    kickoffPromptPath: metadata?.kickoffPromptPath,
    isHidden: metadata?.hidden ?? false,
    isSnoozed: metadata?.snoozed ?? false,
  );
}

class WorktreeListResult {
  final List<Worktree> worktrees;
  final bool isBareLayout;

  WorktreeListResult({required this.worktrees, required this.isBareLayout});
}
