import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/activity/domain/activity_entry.dart';
import 'package:tree_launcher/features/activity/domain/activity_filter.dart';
import 'package:tree_launcher/features/activity/domain/activity_service.dart';
import 'package:tree_launcher/features/activity/domain/manual_post_writer.dart';
import 'package:tree_launcher/features/agent_api/data/api_http.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

/// `GET` and `POST /v1/activity`: the Activity timeline, and manual posts
/// logged into it.
class ActivityRoutes {
  ActivityRoutes({
    required RepoCatalog repos,
    required GitService gitService,
    required ActivityService activity,
    required ManualPostWriter manualPosts,
  }) : _repos = repos,
       _gitService = gitService,
       _activity = activity,
       _manualPosts = manualPosts;

  final RepoCatalog _repos;
  final GitService _gitService;
  final ActivityService _activity;
  final ManualPostWriter _manualPosts;

  void mount(Router router) => router
    ..get('/v1/activity', _list)
    ..post('/v1/activity', _createPost);

  /// `GET /v1/activity?repo=<name>&filter=all|today|yesterday|thisWeek|thisMonth`
  Future<Response> _list(Request request) async {
    final repoFilter = request.url.queryParameters['repo'];
    final filterParam = request.url.queryParameters['filter'];

    final filter = _parseFilter(filterParam);
    if (filter == null) {
      return jsonResponse({
        'error':
            'unknown filter "$filterParam" — expected one of: '
            '${ActivityFilter.values.map((f) => f.name).join(', ')}',
      }, status: 400);
    }

    try {
      final repos = await _repos.loadedRepos();
      final selected = repoFilter == null
          ? repos
          : repos.where((r) => r.name == repoFilter).toList();

      // Enumerate live worktrees across the selected repos, tagging each with
      // its repo name so event-less worktrees can still be filtered by repo.
      final listed = await Future.wait([
        for (final repo in selected)
          () async {
            try {
              return (await _gitService.getWorktrees(repo.path)).worktrees;
            } catch (e) {
              // One unreadable repo shouldn't fail the whole request.
              debugPrint(
                'AgentApiServer: getWorktrees(${repo.path}) failed: $e',
              );
              return const <Worktree>[];
            }
          }(),
      ]);
      final currentWorktrees = <Worktree>[];
      final repoNamesByPath = <String, String>{};
      for (final (i, worktrees) in listed.indexed) {
        for (final w in worktrees) {
          currentWorktrees.add(w);
          repoNamesByPath[w.path] = selected[i].name;
        }
      }

      // Apply the date-window filter against the current wall clock.
      final range = filter.range(DateTime.now());
      var entries = await _activity.loadEntries(
        currentWorktrees: currentWorktrees,
        repoNamesByWorktreePath: repoNamesByPath,
        since: range?.start,
      );

      // Narrow to the requested repo by name (covers event-sourced entries too).
      if (repoFilter != null) {
        entries = entries.where((e) => e.repoName == repoFilter).toList();
      }

      if (range != null) {
        entries = entries.where((e) => e.matchesRange(range)).toList();
      }

      return jsonResponse({
        'repo': repoFilter,
        'filter': filter.name,
        'count': entries.length,
        'entries': [for (final ActivityEntry e in entries) e.toJson()],
      });
    } catch (e) {
      debugPrint('AgentApiServer: /v1/activity failed: $e');
      return jsonResponse({
        'error': 'failed to load activity: $e',
      }, status: 500);
    }
  }

  /// `POST /v1/activity`
  ///
  /// Logs a manual activity post (work done outside any worktree), stamped at
  /// the current time. JSON body:
  /// - `repo` (required) — repo name, as in `GET /v1/activity?repo=`.
  /// - `issueKey` (required) — Jira key the work is logged against.
  /// - `description` (optional) — falls back to the matching predefined issue's
  ///   description for the repo, else empty.
  /// - `hours` (optional number) — time spent.
  Future<Response> _createPost(Request request) async {
    final parsed = await readJsonObject(request);
    if (parsed.error != null) return parsed.error!;
    final body = parsed.body!;

    final repo = stringField(body, 'repo');
    final issueKey = stringField(body, 'issueKey');
    final missing = [
      if (repo == null) 'repo',
      if (issueKey == null) 'issueKey',
    ];
    if (missing.isNotEmpty) return missingFields(missing);

    final jiraError = validateJiraKey(issueKey!);
    if (jiraError != null) {
      return jsonResponse({'error': 'issueKey: $jiraError'}, status: 400);
    }

    final hoursRaw = body['hours'];
    double? hours;
    if (hoursRaw != null) {
      hours = hoursRaw is num
          ? hoursRaw.toDouble()
          : double.tryParse(hoursRaw.toString());
      if (hours == null) {
        return jsonResponse({'error': 'hours must be a number'}, status: 400);
      }
    }

    try {
      final repos = await _repos.loadedRepos();
      final config = repos.where((r) => r.name == repo).firstOrNull;
      if (config == null) {
        return jsonResponse({'error': 'repo not found: $repo'}, status: 404);
      }

      var description = stringField(body, 'description') ?? '';
      if (description.isEmpty) {
        for (final preset in config.predefinedIssues) {
          if (preset.key == issueKey) {
            description = preset.description;
            break;
          }
        }
      }

      final post = await _manualPosts.addManualPost(
        repoName: config.name,
        issueKey: issueKey,
        description: description,
        hours: hours,
      );
      return jsonResponse(post.toJson(), status: 201);
    } catch (e) {
      debugPrint('AgentApiServer: /v1/activity POST failed: $e');
      return jsonResponse({'error': 'failed to log post: $e'}, status: 500);
    }
  }

  static ActivityFilter? _parseFilter(String? value) {
    if (value == null || value.isEmpty) return ActivityFilter.all;
    for (final f in ActivityFilter.values) {
      if (f.name == value) return f;
    }
    return null;
  }
}
