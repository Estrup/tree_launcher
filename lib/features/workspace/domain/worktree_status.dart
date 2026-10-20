/// Where a worktree's checkout stands, from `git status --porcelain=v2
/// --branch` and a count against its base branch.
class WorktreeStatus {
  const WorktreeStatus({
    this.branch,
    this.commit,
    this.subject,
    this.upstream,
    this.aheadOfUpstream = 0,
    this.behindUpstream = 0,
    this.staged = 0,
    this.modified = 0,
    this.untracked = 0,
    this.conflicted = 0,
    this.base,
    this.aheadOfBase,
    this.behindBase,
  });

  /// The checked-out branch; null when HEAD is detached.
  final String? branch;

  /// The full HEAD commit hash; null before the first commit.
  final String? commit;

  /// The HEAD commit's subject line.
  final String? subject;

  /// The remote-tracking branch, e.g. `origin/feature/x`; null when none.
  final String? upstream;
  final int aheadOfUpstream;
  final int behindUpstream;

  /// Files with staged changes.
  final int staged;

  /// Tracked files with unstaged changes.
  final int modified;
  final int untracked;

  /// Files with merge conflicts.
  final int conflicted;

  /// The ref the base comparison used (e.g. `origin/develop`); null when
  /// there was no base branch or it couldn't be found.
  final String? base;
  final int? aheadOfBase;
  final int? behindBase;

  /// The short HEAD hash.
  String? get shortCommit => commit?.substring(0, commit!.length.clamp(0, 8));

  /// Files with any change.
  int get changedFiles => staged + modified + untracked + conflicted;

  /// Parses `git status --porcelain=v2 --branch` output. Lines it doesn't
  /// know are skipped. A file both staged and modified counts in both.
  static WorktreeStatus parse(String output) {
    String? branch;
    String? commit;
    String? upstream;
    var ahead = 0;
    var behind = 0;
    var staged = 0;
    var modified = 0;
    var untracked = 0;
    var conflicted = 0;

    for (final line in output.split('\n')) {
      if (line.startsWith('# branch.oid ')) {
        final oid = line.substring('# branch.oid '.length).trim();
        if (oid != '(initial)') commit = oid;
      } else if (line.startsWith('# branch.head ')) {
        final head = line.substring('# branch.head '.length).trim();
        if (head != '(detached)') branch = head;
      } else if (line.startsWith('# branch.upstream ')) {
        upstream = line.substring('# branch.upstream '.length).trim();
      } else if (line.startsWith('# branch.ab ')) {
        final parts = line.substring('# branch.ab '.length).trim().split(' ');
        for (final part in parts) {
          if (part.length < 2) continue;
          final count = int.tryParse(part.substring(1)) ?? 0;
          if (part.startsWith('+')) ahead = count;
          if (part.startsWith('-')) behind = count;
        }
      } else if (line.startsWith('1 ') || line.startsWith('2 ')) {
        // "1 XY ..." / "2 XY ...": X is the staged state, Y the unstaged.
        if (line.length < 4) continue;
        if (line[2] != '.') staged++;
        if (line[3] != '.') modified++;
      } else if (line.startsWith('u ')) {
        conflicted++;
      } else if (line.startsWith('? ')) {
        untracked++;
      }
    }

    return WorktreeStatus(
      branch: branch,
      commit: commit,
      upstream: upstream,
      aheadOfUpstream: ahead,
      behindUpstream: behind,
      staged: staged,
      modified: modified,
      untracked: untracked,
      conflicted: conflicted,
    );
  }

  WorktreeStatus withDetails({
    String? subject,
    String? base,
    int? aheadOfBase,
    int? behindBase,
  }) => WorktreeStatus(
    branch: branch,
    commit: commit,
    subject: subject ?? this.subject,
    upstream: upstream,
    aheadOfUpstream: aheadOfUpstream,
    behindUpstream: behindUpstream,
    staged: staged,
    modified: modified,
    untracked: untracked,
    conflicted: conflicted,
    base: base ?? this.base,
    aheadOfBase: aheadOfBase ?? this.aheadOfBase,
    behindBase: behindBase ?? this.behindBase,
  );
}
