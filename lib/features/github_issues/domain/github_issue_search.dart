/// The issue number a search [query] names: `123` or `#123`. Null when it
/// names none.
int? githubIssueNumberInQuery(String query) {
  final match = RegExp(r'^#?(\d+)$').firstMatch(query.trim());
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// The GitHub search `q` for the Issues tab's search: issues in
/// [owner]/[repo] matching [query]. The query is passed on as typed, so
/// GitHub's qualifiers (`label:bug`, `is:open`, `no:milestone` …) work; a
/// leading `#` on a number is dropped. Null when there is nothing to search
/// for.
String? githubIssueSearchQuery(String owner, String repo, String query) {
  final number = githubIssueNumberInQuery(query);
  final text = number != null ? '$number' : query.trim();
  if (text.isEmpty) return null;
  return 'repo:$owner/$repo is:issue $text';
}
