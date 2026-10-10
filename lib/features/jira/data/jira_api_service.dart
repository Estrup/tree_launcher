import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:tree_launcher/features/jira/domain/jira_constants.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_pat.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
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
    final json = await _requestJson(
      '/rest/api/2/issue/$key',
      {'fields': _issueFields},
      notFound: 'Jira issue not found: $key',
      forbidden: 'Jira access denied for $key.',
    );
    return JiraIssue.fromApiJson(json as Map<String, dynamic>);
  }

  /// The status changes the workflow allows on [key] from its current status.
  Future<List<JiraTransition>> fetchTransitions(String key) async {
    final json = await _requestJson(
      '/rest/api/2/issue/$key/transitions',
      const {},
      notFound: 'Jira issue not found: $key',
      forbidden: 'Jira access denied for $key.',
    );
    return ((json as Map<String, dynamic>)['transitions'] as List<dynamic>? ??
            const [])
        .whereType<Map<String, dynamic>>()
        .map(JiraTransition.fromApiJson)
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  /// Moves [key] through the transition [transitionId], changing its status.
  /// Throws with Jira's reasons when the transition needs more input (such
  /// as a resolution) or isn't allowed.
  Future<void> transitionIssue(String key, String transitionId) async {
    await _requestJson(
      '/rest/api/2/issue/$key/transitions',
      const {},
      method: 'POST',
      body: {
        'transition': {'id': transitionId},
      },
      notFound: 'Jira issue not found: $key',
      forbidden: 'Not allowed to change the status of $key.',
    );
  }

  /// The user the token belongs to. Looked up once per app session.
  Future<JiraUser> fetchMyself() => _myself ??= _lookUpMyself();

  static Future<JiraUser>? _myself;

  Future<JiraUser> _lookUpMyself() async {
    try {
      final json = await _requestJson('/rest/api/2/myself', const {});
      return JiraUser.fromApiJson(json as Map<String, dynamic>);
    } catch (_) {
      // Don't remember a failure; the next call tries again.
      _myself = null;
      rethrow;
    }
  }

  /// Assigns [key] to the user with the username [userName].
  Future<void> assignIssue(String key, String userName) async {
    await _requestJson(
      '/rest/api/2/issue/$key/assignee',
      const {},
      method: 'PUT',
      body: {'name': userName},
      notFound: 'Jira issue not found: $key',
      forbidden: 'Not allowed to assign $key.',
    );
  }

  /// Fetches every version of [projectKey], in Jira's project order.
  Future<List<JiraVersion>> fetchVersions(String projectKey) async {
    final json = await _requestJson(
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
  Future<List<JiraIssue>> searchIssues(String jql) =>
      _search(jql, limit: _maxSearchResults);

  /// Runs a search the user typed: the first [limit] issues matching [jql]
  /// (list fields only). An issue key that doesn't exist matches nothing
  /// instead of failing the search, as Jira's validation would have it.
  Future<List<JiraIssue>> findIssues(String jql, {required int limit}) =>
      _search(jql, limit: limit, validate: false);

  Future<List<JiraIssue>> _search(
    String jql, {
    required int limit,
    bool validate = true,
  }) async {
    final issues = <JiraIssue>[];
    while (issues.length < limit) {
      final json =
          await _requestJson('/rest/api/2/search', {
                'jql': jql,
                'fields': _listFields,
                'startAt': '${issues.length}',
                'maxResults': '${min(_pageSize, limit - issues.length)}',
                if (!validate) 'validateQuery': 'false',
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

  /// Sends [method] (GET unless given) to [path] with [query] and an
  /// optional JSON [body], and returns the decoded JSON response (null when
  /// empty). Throws a readable exception for a missing token and for non-2xx
  /// responses.
  Future<Object?> _requestJson(
    String path,
    Map<String, String> query, {
    String method = 'GET',
    Object? body,
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
      final request = await client.openUrl(
        method,
        Uri.https(host, path, query.isEmpty ? null : query),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $pat');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);

      if (response.statusCode == 401) {
        throw Exception(
          'Jira authentication failed. Check your token at '
          '~/.config/jira-pat.txt.',
        );
      }
      if (response.statusCode == 403) throw Exception(forbidden);
      if (response.statusCode == 404) throw Exception(notFound);
      if (response.statusCode == 400) {
        throw Exception(
          'Jira rejected the request: ${_errorMessages(responseBody)}',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Jira API error (${response.statusCode}): $responseBody',
        );
      }

      return responseBody.trim().isEmpty ? null : jsonDecode(responseBody);
    } finally {
      client.close(force: true);
    }
  }

  /// Pulls Jira's `errorMessages` and per-field `errors` (e.g. a required
  /// resolution) out of an error body, falling back to the raw body when it
  /// isn't the usual shape.
  static String _errorMessages(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final fieldErrors = json['errors'];
        final messages = [
          ...(json['errorMessages'] as List<dynamic>? ?? const [])
              .whereType<String>(),
          if (fieldErrors is Map<String, dynamic>)
            ...fieldErrors.values.whereType<String>(),
        ];
        if (messages.isNotEmpty) return messages.join(' ');
      }
    } catch (_) {
      // Not JSON; fall through to the raw body.
    }
    return body;
  }
}
