/// Shared naming rules for worktrees and branches.
///
/// These live here (UI-free) so the Add-Worktree dialog and the agent HTTP API
/// validate and build names identically — one source of truth for the app's
/// naming convention.
library;

final RegExp _worktreeNamePattern = RegExp(r'^[a-z0-9._\-]+$');
final RegExp _jiraKeyPattern = RegExp(r'^[A-Z][A-Z0-9]+-\d+$');

/// Normalizes a raw worktree/branch name the way the Add-Worktree dialog does
/// as the user types: trims surrounding whitespace, lowercases, and turns
/// spaces into dashes.
String normalizeWorktreeName(String raw) =>
    raw.trim().toLowerCase().replaceAll(' ', '-');

/// Returns an error message if [value] is not a valid worktree name, or null if
/// it is acceptable. An empty string is treated as "no value yet" (null), to
/// match the dialog's field validation.
String? validateWorktreeName(String value) {
  if (value.isEmpty) return null;
  if (value != value.toLowerCase()) return 'Must be lowercase';
  if (!_worktreeNamePattern.hasMatch(value)) {
    return 'Only a-z, 0-9, ., -, _ allowed';
  }
  return null;
}

/// Returns an error message if [value] is not a valid Jira issue key, or null
/// if it is acceptable (empty is treated as null).
String? validateJiraKey(String value) {
  if (value.isEmpty) return null;
  if (!_jiraKeyPattern.hasMatch(value)) {
    return 'Format: AU2-0001';
  }
  return null;
}

/// Builds a branch name from a [suffix] and the configured [prefix], mirroring
/// the dialog's auto-fill: `<prefix>/<suffix>` when a prefix is set, otherwise
/// just `<suffix>`.
String buildBranchName(String suffix, String? prefix) {
  if (prefix != null && prefix.isNotEmpty) return '$prefix/$suffix';
  return suffix;
}

/// Letters folded to ASCII before slugging, so Danish (and a few other) words
/// stay readable in names: "Værksted på" -> "vaerksted-paa".
const Map<String, String> _asciiFolds = {
  'æ': 'ae',
  'ø': 'oe',
  'å': 'aa',
  'ä': 'ae',
  'ö': 'oe',
  'ü': 'ue',
  'é': 'e',
  'è': 'e',
  'ß': 'ss',
};

/// Builds a worktree name for a Jira issue: a slug of the first words of
/// [summary] followed by the lowercased [key], e.g. `AU2-5928` + "Værksted
/// kontakt" -> `vaerksted-kontakt-au2-5928`. Whole words are added while the
/// name stays within [maxLength] and [maxWords]; the result always passes
/// [validateWorktreeName].
String worktreeNameForJiraIssue(
  String key,
  String summary, {
  int maxLength = 48,
  int maxWords = 5,
}) {
  var text = summary.toLowerCase();
  _asciiFolds.forEach((from, to) => text = text.replaceAll(from, to));
  final words = text
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .take(maxWords);

  final suffix = key.toLowerCase();
  var slug = '';
  for (final word in words) {
    final next = slug.isEmpty ? word : '$slug-$word';
    if (next.length + 1 + suffix.length > maxLength) break;
    slug = next;
  }
  return slug.isEmpty ? suffix : '$slug-$suffix';
}

/// Builds a worktree name for a PR's [headBranch]. With a Jira [jiraKey] it
/// follows [worktreeNameForJiraIssue]: the branch's last segment without the
/// key, then the key, e.g. `klp/AU2-5928-vaerksted-kontakt` ->
/// `vaerksted-kontakt-au2-5928`. Without a key the branch is used as-is, with
/// slashes turned into dashes.
String worktreeNameForPrBranch(String headBranch, {String? jiraKey}) {
  if (jiraKey == null) return headBranch.replaceAll('/', '-');
  final keyPattern = RegExp(
    '(?<![a-z0-9])${RegExp.escape(jiraKey)}(?![0-9])',
    caseSensitive: false,
  );
  final lastSegment = headBranch.split('/').last;
  return worktreeNameForJiraIssue(
    jiraKey,
    lastSegment.replaceAll(keyPattern, ''),
  );
}

/// Relative path (within a worktree) of the API-supplied kickoff-prompt file.
///
/// The agent API writes a worktree's kickoff prompt here; the Claude launcher
/// references this path rather than inlining the (potentially large) text.
const String kickoffPromptRelativePath = '.tree-launcher/kickoff-prompt.md';
