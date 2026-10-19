import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/agent_api/data/api_http.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_constants.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag_editor.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

/// `/v1/jira/...`: Jira issues with the user's local tags, and the tags
/// themselves. Nothing here changes Jira.
class JiraRoutes {
  JiraRoutes({
    required RepoCatalog repos,
    required JiraTagEditor tags,
    required JiraApiService jira,
  }) : _repos = repos,
       _tags = tags,
       _jira = jira;

  final RepoCatalog _repos;
  final JiraTagEditor _tags;
  final JiraApiService _jira;

  void mount(Router router) => router
    ..get('/v1/jira/issues', _issues)
    ..get('/v1/jira/tags', _listTags)
    ..put('/v1/jira/issues/<key>/tags', _setIssueTags);

  /// `GET /v1/jira/issues?repo=<name>&fixVersion=<name|id>&status=<name>`
  ///
  /// Lists a Jira project's issues (no sub-tasks) in rank order, each with
  /// the user's local `tags`. Query:
  /// - `repo` — repo name whose Jira project key is used, or `project` — a
  ///   Jira project key. One is required.
  /// - `fixVersion` (optional) — version name (any case) or id.
  /// - `status` (optional, repeatable or comma-separated) — Jira status
  ///   names; issues in any of them match.
  ///
  /// At least one of `fixVersion` and `status` is required. Read-only.
  Future<Response> _issues(Request request) async {
    final query = request.url.queryParameters;
    final versionParam = query['fixVersion']?.trim();
    final statuses = <String>[
      for (final value in request.url.queryParametersAll['status'] ?? const [])
        for (final status in value.split(','))
          if (status.trim().isNotEmpty) status.trim(),
    ];
    if ((versionParam == null || versionParam.isEmpty) && statuses.isEmpty) {
      return jsonResponse({
        'error': 'give fixVersion, status, or both',
      }, status: 400);
    }

    final project = await _projectKeyFor(query);
    if (project.error != null) return project.error!;
    final projectKey = project.key!;

    try {
      String? versionId;
      Map<String, dynamic>? version;
      if (versionParam != null && versionParam.isNotEmpty) {
        final versions = await _jira.fetchVersions(projectKey);
        final lower = versionParam.toLowerCase();
        final match = versions
            .where((v) => v.id == versionParam || v.name.toLowerCase() == lower)
            .firstOrNull;
        if (match == null) {
          return jsonResponse({
            'error': 'fixVersion not found in $projectKey: $versionParam',
            'fixVersions': [
              for (final v in orderVersionsForPicker(versions)) v.name,
            ],
          }, status: 404);
        }
        versionId = match.id;
        version = {
          'id': match.id,
          'name': match.name,
          'released': match.released,
        };
      }

      final issues = await _jira.searchIssues(
        jiraIssuesJql(projectKey, versionId: versionId, statuses: statuses),
      );
      return jsonResponse({
        'project': projectKey,
        'fixVersion': version,
        'statuses': statuses,
        'count': issues.length,
        'issues': [
          for (final JiraIssue issue in issues)
            {
              'key': issue.key,
              'summary': issue.summary,
              'status': issue.status,
              'statusCategory': issue.statusCategory,
              'issueType': issue.issueType,
              'assignee': issue.assignee,
              'priority': issue.priority,
              'updated': issue.updated?.toIso8601String(),
              'url': '$jiraBaseUrl${issue.key}',
              'tags': [
                for (final tag in _tags.jiraTagsFor(issue.key)) tag.name,
              ],
            },
        ],
      });
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      debugPrint('AgentApiServer: /v1/jira/issues failed: $message');
      // Jira's own 400s (e.g. an unknown status) are the caller's to fix.
      final status = message.startsWith('Jira rejected the request')
          ? 400
          : 502;
      return jsonResponse({'error': message}, status: status);
    }
  }

  /// `GET /v1/jira/tags` — the user's local tags, in display order.
  Response _listTags(Request request) => jsonResponse({
    'tags': [
      for (final tag in _tags.jiraTags) {'name': tag.name, 'color': tag.color},
    ],
  });

  /// `PUT /v1/jira/issues/<key>/tags`
  ///
  /// Replaces the user's local tags on issue `<key>`. JSON body: `tags` — the
  /// tag names (any case), as listed by `GET /v1/jira/tags`; an empty list
  /// removes them all. Only local tags change: nothing is sent to Jira, and
  /// any other field is rejected.
  Future<Response> _setIssueTags(Request request, String key) async {
    final issueKey = key.trim().toUpperCase();
    final keyError = validateJiraKey(issueKey);
    if (keyError != null) {
      return jsonResponse({'error': 'issue key: $keyError'}, status: 400);
    }

    final parsed = await readJsonObject(request);
    if (parsed.error != null) return parsed.error!;
    final body = parsed.body!;

    final other = body.keys.where((k) => k != 'tags').toList();
    if (other.isNotEmpty) {
      return jsonResponse({
        'error':
            'only local tags can be set; unsupported field(s): '
            '${other.join(', ')}',
      }, status: 400);
    }
    final names = body['tags'];
    if (names is! List || names.any((n) => n is! String)) {
      return jsonResponse({
        'error': 'tags must be a list of tag names',
      }, status: 400);
    }

    final tags = _tags.jiraTags;
    final byName = {for (final tag in tags) tag.name.toLowerCase(): tag};
    final unknown = [
      for (final name in names.cast<String>())
        if (!byName.containsKey(name.trim().toLowerCase())) name,
    ];
    if (unknown.isNotEmpty) {
      return jsonResponse({
        'error': 'unknown tag(s): ${unknown.join(', ')}',
        'tags': [for (final tag in tags) tag.name],
      }, status: 400);
    }

    try {
      // A set drops repeated names, keeping the first.
      await _tags.setJiraTagsFor(issueKey, [
        ...{
          for (final name in names.cast<String>())
            byName[name.trim().toLowerCase()]!.id,
        },
      ]);
      return jsonResponse({
        'key': issueKey,
        'tags': [for (final tag in _tags.jiraTagsFor(issueKey)) tag.name],
      });
    } catch (e) {
      debugPrint(
        'AgentApiServer: PUT /v1/jira/issues/$issueKey/tags failed: $e',
      );
      return jsonResponse({'error': 'failed to save tags: $e'}, status: 500);
    }
  }

  /// The Jira project key from the `repo` or `project` query parameter, or
  /// the error response to send.
  Future<({String? key, Response? error})> _projectKeyFor(
    Map<String, String> query,
  ) async {
    final project = query['project']?.trim();
    if (project != null && project.isNotEmpty) {
      return (key: project.toUpperCase(), error: null);
    }
    final repoName = query['repo']?.trim();
    if (repoName == null || repoName.isEmpty) {
      return (
        key: null,
        error: jsonResponse({'error': 'give repo or project'}, status: 400),
      );
    }
    final repos = await _repos.loadedRepos();
    final repo = repos.where((r) => r.name == repoName).firstOrNull;
    if (repo == null) {
      return (
        key: null,
        error: jsonResponse({
          'error': 'repo not found: $repoName',
        }, status: 404),
      );
    }
    final key = repo.jiraProjectKey;
    if (key == null || key.isEmpty) {
      return (
        key: null,
        error: jsonResponse({
          'error': 'repo $repoName has no Jira project key',
        }, status: 400),
      );
    }
    return (key: key, error: null);
  }
}
