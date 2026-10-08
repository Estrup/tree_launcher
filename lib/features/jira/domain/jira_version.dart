/// A Jira project version (what issues reference as their fixVersion).
class JiraVersion {
  final String id;
  final String name;
  final bool released;
  final bool archived;

  const JiraVersion({
    required this.id,
    required this.name,
    this.released = false,
    this.archived = false,
  });

  /// Parses one entry of `GET /rest/api/2/project/{key}/versions`.
  factory JiraVersion.fromApiJson(Map<String, dynamic> json) {
    return JiraVersion(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      released: json['released'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JiraVersion && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Orders [versions] for the fixVersion picker: archived versions are dropped,
/// unreleased versions come first in Jira's own project order, then released
/// versions newest-first (Jira lists them oldest-first).
List<JiraVersion> orderVersionsForPicker(List<JiraVersion> versions) {
  final live = versions.where((v) => !v.archived);
  return [
    ...live.where((v) => !v.released),
    ...live.where((v) => v.released).toList().reversed,
  ];
}

/// Picks the version to show: the remembered [rememberedId] when it is still in
/// [ordered], otherwise the first entry (the first unreleased version when there
/// is one). Null only when [ordered] is empty.
JiraVersion? pickVersion(List<JiraVersion> ordered, String? rememberedId) {
  if (ordered.isEmpty) return null;
  for (final v in ordered) {
    if (v.id == rememberedId) return v;
  }
  return ordered.first;
}

/// JQL for the issues in one fixVersion of [projectKey], in board (Rank) order.
/// Sub-tasks are left out: worktrees are made for their parent issues.
String fixVersionIssuesJql(String projectKey, String versionId) =>
    'project = "$projectKey" AND fixVersion = $versionId '
    'AND issuetype not in subTaskIssueTypes() ORDER BY Rank ASC';
