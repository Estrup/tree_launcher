
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';

/// First message for a Claude session on [issue]: what it is, where to read
/// it, and how.
String githubIssueContextPrompt(GithubIssue issue, GithubConfig config) {
  final repo = '${config.owner}/${config.repo}';
  return 'Context: Working on GitHub issue #${issue.number} "${issue.title}" '
      'in $repo (${issue.htmlUrl}). Run '
      '"gh issue view ${issue.number} -R $repo --comments" for its '
      'description and discussion.';
}

/// What a state change on [total] selected issues did, of which [attempted]
/// weren't in [target] yet, e.g. "Closed 3 of 5 issues as completed. #12:
/// Validation failed. 1 was already closed."
String bulkStateSummary(
  GithubIssueState target,
  int total,
  int attempted,
  Map<int, String> failures,
) {
  final changed = attempted - failures.length;
  final count = changed == total ? '$total' : '$changed of $total';
  final issues = total == 1 ? 'issue' : 'issues';
  final parts = [
    switch (target) {
      GithubIssueState.open => 'Reopened $count $issues.',
      GithubIssueState.closed => 'Closed $count $issues as completed.',
      GithubIssueState.notPlanned => 'Closed $count $issues as not planned.',
    },
    for (final MapEntry(key: number, value: reason) in failures.entries.take(2))
      '#$number: ${RegExp(r'[.!?]$').hasMatch(reason) ? reason : '$reason.'}',
    if (failures.length > 2) '${failures.length - 2} more failed.',
  ];
  final already = total - attempted;
  if (already > 0) {
    final state = target.label.toLowerCase();
    parts.add(
      already == 1 ? '1 was already $state.' : '$already were already $state.',
    );
  }
  return parts.join(' ');
}
