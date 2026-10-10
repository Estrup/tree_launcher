/// A workflow transition available on a Jira issue: what changing its status
/// is called (e.g. "Start Progress") and the status it leads to.
class JiraTransition {
  final String id;
  final String name;

  /// Name of the status the issue moves to.
  final String toStatus;

  /// Status category key of [toStatus]: `new`, `indeterminate` or `done`.
  final String? toStatusCategory;

  const JiraTransition({
    required this.id,
    required this.name,
    required this.toStatus,
    this.toStatusCategory,
  });

  /// Parses one entry of `GET /rest/api/2/issue/{key}/transitions`.
  factory JiraTransition.fromApiJson(Map<String, dynamic> json) {
    final to = json['to'];
    final toMap = to is Map<String, dynamic> ? to : const <String, dynamic>{};
    final category = toMap['statusCategory'];
    final name = json['name'] as String? ?? '';
    return JiraTransition(
      id: '${json['id'] ?? ''}',
      name: name,
      toStatus: toMap['name'] as String? ?? name,
      toStatusCategory: category is Map<String, dynamic>
          ? category['key'] as String?
          : null,
    );
  }
}

/// Moving one or more issues to [toStatus], with the transition each of them
/// takes to get there (workflows differ, so the transitions can too).
class JiraStatusMove {
  final String toStatus;
  final String? toStatusCategory;

  /// Issue key -> the transition that moves that issue to [toStatus]. Only
  /// issues that can move there are included.
  final Map<String, JiraTransition> transitions;

  const JiraStatusMove({
    required this.toStatus,
    required this.toStatusCategory,
    required this.transitions,
  });
}

/// Groups each issue's available transitions (issue key -> transitions) by
/// the status they lead to, ordered to do → in progress → done, then by first
/// appearance. An issue with several transitions to one status takes the
/// first.
List<JiraStatusMove> jiraStatusMoves(
  Map<String, List<JiraTransition>> transitionsByIssue,
) {
  final byStatus = <String, Map<String, JiraTransition>>{};
  final categories = <String, String?>{};
  for (final MapEntry(key: issueKey, value: transitions)
      in transitionsByIssue.entries) {
    for (final t in transitions) {
      byStatus.putIfAbsent(t.toStatus, () => {}).putIfAbsent(issueKey, () => t);
      categories[t.toStatus] ??= t.toStatusCategory;
    }
  }
  const order = {'new': 0, 'indeterminate': 1, 'done': 2};
  final statuses = byStatus.keys.toList();
  final firstSeen = {for (var i = 0; i < statuses.length; i++) statuses[i]: i};
  statuses.sort((a, b) {
    final byCategory = (order[categories[a]] ?? 1).compareTo(
      order[categories[b]] ?? 1,
    );
    return byCategory != 0
        ? byCategory
        : firstSeen[a]!.compareTo(firstSeen[b]!);
  });
  return [
    for (final status in statuses)
      JiraStatusMove(
        toStatus: status,
        toStatusCategory: categories[status],
        transitions: byStatus[status]!,
      ),
  ];
}
