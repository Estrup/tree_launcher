/// A GitHub milestone, the GitHub counterpart of a Jira fixVersion.
class GithubMilestone {
  /// GitHub's per-repo milestone number (1 and up), used to filter issues.
  final int number;
  final String title;
  final bool open;
  final DateTime? dueOn;
  final DateTime? closedAt;

  const GithubMilestone({
    required this.number,
    required this.title,
    this.open = true,
    this.dueOn,
    this.closedAt,
  });

  /// Parses an item of `GET /repos/{o}/{r}/milestones`.
  factory GithubMilestone.fromApiJson(Map<String, dynamic> json) {
    return GithubMilestone(
      number: json['number'] as int,
      title: json['title'] as String? ?? '',
      open: json['state'] != 'closed',
      dueOn: DateTime.tryParse(json['due_on'] as String? ?? ''),
      closedAt: DateTime.tryParse(json['closed_at'] as String? ?? ''),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GithubMilestone &&
      other.number == number &&
      other.title == title &&
      other.open == open;

  @override
  int get hashCode => Object.hash(number, title, open);
}

/// Milestones in picker order: open ones by due date (soonest first, those
/// without one last, then by title), then closed ones, most recently closed
/// first.
List<GithubMilestone> orderMilestonesForPicker(
  List<GithubMilestone> milestones,
) {
  int byDue(GithubMilestone a, GithubMilestone b) {
    final da = a.dueOn, db = b.dueOn;
    if (da != null && db != null && da != db) return da.compareTo(db);
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  int byClosed(GithubMilestone a, GithubMilestone b) {
    final ca = a.closedAt, cb = b.closedAt;
    if (ca != null && cb != null) return cb.compareTo(ca);
    if (ca != null) return -1;
    if (cb != null) return 1;
    return b.number.compareTo(a.number);
  }

  return [
    ...milestones.where((m) => m.open).toList()..sort(byDue),
    ...milestones.where((m) => !m.open).toList()..sort(byClosed),
  ];
}
