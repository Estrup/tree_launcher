import 'dart:convert';
import 'dart:io';

import 'package:tree_launcher/features/jira/domain/jira_constants.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_pat.dart';

/// Fetches Jira issues from the self-hosted Jira Server/Data Center REST API
/// (`/rest/api/2/issue/{KEY}`) using Bearer-token auth. Mirrors the dart:io
/// `HttpClient` pattern in `GithubApiService`.
class JiraApiService {
  /// Fields requested from the API. Trims the payload to what the dialog shows.
  static const _fields =
      'summary,status,issuetype,assignee,priority,description,updated,comment';

  /// Fetches [key] and returns the parsed issue. Throws with a clear message on
  /// missing token, auth failure, not-found, or other non-2xx responses.
  Future<JiraIssue> fetchIssue(String key) async {
    final pat = await readJiraPat();
    if (pat == null) {
      throw Exception('No Jira token found at ~/.config/jira-pat.txt');
    }

    final host = Uri.parse(jiraBaseUrl).host;
    final client = HttpClient();
    try {
      final uri = Uri.https(host, '/rest/api/2/issue/$key', {
        'fields': _fields,
      });

      final request = await client.getUrl(uri);
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
      if (response.statusCode == 403) {
        throw Exception('Jira access denied for $key.');
      }
      if (response.statusCode == 404) {
        throw Exception('Jira issue not found: $key');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Jira API error (${response.statusCode}): $body');
      }

      return JiraIssue.fromApiJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }
}
