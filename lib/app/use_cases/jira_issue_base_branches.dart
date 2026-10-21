import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/workspace/domain/issue_base_branches.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';

/// Looks the issue up in Jira for its fixVersions, and the repo's mapping for
/// their branch. Jira is only asked when the repo maps any version.
class JiraIssueBaseBranches implements IssueBaseBranches {
  JiraIssueBaseBranches({
    required RepoCatalog repos,
    required JiraApiService jira,
  }) : _repos = repos,
       _jira = jira;

  final RepoCatalog _repos;
  final JiraApiService _jira;

  @override
  Future<String?> baseBranchFor(String repoName, String issueKey) async {
    final repo = (await _repos.loadedRepos())
        .where((r) => r.name == repoName)
        .firstOrNull;
    if (repo == null || repo.jiraVersionBranches.isEmpty) return null;
    try {
      final issue = await _jira.fetchIssue(issueKey);
      return repo.baseBranchForFixVersions(issue.fixVersionIds);
    } catch (e) {
      debugPrint('Reading the fixVersions of $issueKey failed: $e');
      return null;
    }
  }
}
