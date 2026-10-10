/// A full issue key, any case (e.g. `au2-5928`).
final _issueKeyPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*-\d+$');

/// Characters Jira's text search treats as operators; searched as spaces.
final _textOperators = RegExp(r'[+\-&|!(){}\[\]^~*?\\:"/]');

/// The issue key a search [query] names: a full key in any project, or a bare
/// number in [projectKey]. Null when it names none.
String? jiraKeyInQuery(String projectKey, String query) {
  final q = query.trim();
  if (_issueKeyPattern.hasMatch(q)) return q.toUpperCase();
  if (RegExp(r'^\d+$').hasMatch(q)) return '$projectKey-$q';
  return null;
}

/// JQL for the Jira tab's search: issues in [projectKey] (no sub-tasks) whose
/// text contains every word of [query], the last word as a prefix so results
/// come while typing, plus the issue [query] names (see [jiraKeyInQuery]).
/// Most recently updated first. Null when there is nothing to search for.
///
/// Run it with validation off: Jira otherwise rejects the whole search when
/// the named key doesn't exist.
String? jiraSearchJql(String projectKey, String query) {
  final key = jiraKeyInQuery(projectKey, query);
  final words = query
      .replaceAll(_textOperators, ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final conditions = [
    if (key != null) 'key = "$key"',
    if (words.isNotEmpty)
      '(project = "$projectKey" AND issuetype not in subTaskIssueTypes() '
          'AND text ~ "${words.join(' ')}*")',
  ];
  if (conditions.isEmpty) return null;
  return '${conditions.join(' OR ')} ORDER BY updated DESC';
}
