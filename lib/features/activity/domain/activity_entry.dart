/// Distinguishes a worktree-derived timeline entry from a manually logged post.
enum ActivityEntryKind { worktree, manual }

/// One row of the Activity timeline. For [ActivityEntryKind.worktree] entries
/// this is a worktree's worth of history — when it was created/closed and which
/// days Claude was active in it, merging the durable event log with Claude
/// Code's session history. For [ActivityEntryKind.manual] entries it's a single
/// manually logged post: [worktreeName] holds the description, [createdAt] the
/// log time, and [hours] the time spent.
class ActivityEntry {
  final String worktreePath;
  final String worktreeName;
  final String? repoName;
  final String? branch;
  final String? jiraIssue;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final List<DateTime> activeDays;
  final ActivityEntryKind kind;

  /// Hours logged, for [ActivityEntryKind.manual] entries. Null otherwise.
  final double? hours;

  ActivityEntry({
    required this.worktreePath,
    required this.worktreeName,
    this.repoName,
    this.branch,
    this.jiraIssue,
    this.createdAt,
    this.closedAt,
    this.activeDays = const [],
    this.kind = ActivityEntryKind.worktree,
    this.hours,
  });

  bool get isManual => kind == ActivityEntryKind.manual;

  bool get isOpen => closedAt == null;

  DateTime? get lastActiveDay => activeDays.isEmpty ? null : activeDays.last;

  /// Most recent moment we know about for this worktree, used for sorting.
  DateTime? get sortKey {
    DateTime? latest;
    for (final t in [createdAt, closedAt, lastActiveDay]) {
      if (t == null) continue;
      if (latest == null || t.isAfter(latest)) latest = t;
    }
    return latest;
  }

  /// Whether this entry has any signal — created, closed, or a Claude active
  /// day — falling within the half-open `[start, end)` window.
  bool matchesRange(({DateTime start, DateTime end}) r) {
    bool inRange(DateTime? t) =>
        t != null && !t.isBefore(r.start) && t.isBefore(r.end);
    if (inRange(createdAt) || inRange(closedAt)) return true;
    return activeDays.any(inRange);
  }

  /// JSON shape exposed over the agent HTTP API. Dates are ISO-8601;
  /// [activeDays] are date-only (midnight local) ISO strings.
  Map<String, dynamic> toJson() => {
    'worktreePath': worktreePath,
    'worktreeName': worktreeName,
    'repoName': repoName,
    'branch': branch,
    'jiraIssue': jiraIssue,
    'createdAt': createdAt?.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'isOpen': isOpen,
    'activeDays': [for (final d in activeDays) d.toIso8601String()],
    'lastActiveDay': lastActiveDay?.toIso8601String(),
    'kind': kind.name,
    if (hours != null) 'hours': hours,
  };
}
