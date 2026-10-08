import 'dart:convert';
import 'dart:io';

import 'package:tree_launcher/features/jira/domain/jira_constants.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_pat.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';

/// Talks to the self-hosted Jira Server/Data Center REST API (v2) using
/// Bearer-token auth. Mirrors the dart:io `HttpClient` pattern in
/// `GithubApiService`.
class JiraApiService {
  /// Fields requested for a single issue. Trims the payload to what the issue
  /// dialog shows.
  static const _issueFields =
      'summary,status,issuetype,assignee,priority,description,updated,comment';

  /// Fields requested for issue lists (no description or comments).
  static const _listFields =
      'summary,status,issuetype,assignee,priority,updated';

  /// Page size for searches, and the most issues a single search returns.
  static const _pageSize = 100;
  static const _maxSearchResults = 1000;

  /// Fetches [key] and returns the parsed issue. Throws with a clear message on
  /// missing token, auth failure, not-found, or other non-2xx responses.
  Future<JiraIssue> fetchIssue(String key) async {
    final json = await _getJson(
      '/rest/api/2/issue/$key',
      {'fields': _issueFields},
      notFound: 'Jira issue not found: $key',
      forbidden: 'Jira access denied for $key.',
    );
    return JiraIssue.fromApiJson(json as Map<String, dynamic>);
  }

  /// Fetches every version of [projectKey], in Jira's project order.
  Future<List<JiraVersion>> fetchVersions(String projectKey) async {
    final json = await _getJson(
      '/rest/api/2/project/$projectKey/versions',
      const {},
      notFound: 'Jira project not found: $projectKey',
      forbidden: 'Jira access denied for project $projectKey.',
    );
    return (json as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(JiraVersion.fromApiJson)
        .toList();
  }

  /// Runs [jql] and returns the matching issues (list fields only), following
  /// pagination up to [_maxSearchResults].
  Future<List<JiraIssue>> searchIssues(String jql) async {
    final issues = <JiraIssue>[];
    while (issues.length < _maxSearchResults) {
      final json =
          await _getJson('/rest/api/2/search', {
                'jql': jql,
                'fields': _listFields,
                'startAt': '${issues.length}',
                'maxResults': '$_pageSize',
              })
              as Map<String, dynamic>;
      final page = (json['issues'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(JiraIssue.fromApiJson)
          .toList();
      issues.addAll(page);
      final total = json['total'] as int? ?? issues.length;
      if (page.isEmpty || issues.length >= total) break;
    }
    return issues;
  }

  /// GETs [path] with [query] and returns the decoded JSON body. Throws a
  /// readable exception for a missing token and for non-2xx responses.
  Future<Object?> _getJson(
    String path,
    Map<String, String> query, {
    String notFound = 'Jira resource not found.',
    String forbidden = 'Jira access denied.',
  }) async {
    final pat = await readJiraPat();
    if (pat == null) {
      throw Exception('No Jira token found at ~/.config/jira-pat.txt');
    }

    final host = Uri.parse(jiraBaseUrl).host;
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.https(host, path, query.isEmpty ? null : query),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $pat');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      final body = await utf8.decodeStream(response);

      if (response.statusCode == 401) {
        throw Exception(
          'Jira authentication failed. Check your token at '
          '~/.config/jira-pat.txt.',
        );
      }
      if (response.statusCode == 403) throw Exception(forbidden);
      if (response.statusCode == 404) throw Exception(notFound);
      if (response.statusCode == 400) {
        throw Exception('Jira rejected the request: ${_errorMessages(body)}');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Jira API error (${response.statusCode}): $body');
      }

      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  /// Pulls Jira's `errorMessages` out of an error body, falling back to the raw
  /// body when it isn't the usual shape.
  static String _errorMessages(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final messages = (json['errorMessages'] as List<dynamic>? ?? const [])
            .whereType<String>();
        if (messages.isNotEmpty) return messages.join(' ');
      }
    } catch (_) {
      // Not JSON; fall through to the raw body.
    }
    return body;
  }
}
