import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/activity_entry.dart';
import 'package:tree_launcher/features/activity/domain/activity_filter.dart';
import 'package:tree_launcher/features/activity/domain/activity_service.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';

/// A small read-only HTTP server, bound to loopback only, that exposes app data
/// to local AI agents (for use in Claude Code skills).
///
/// v1 surfaces the Activity timeline. The router is the extension point — adding
/// a capability is a new `_router.get(...)` line plus a handler.
class AgentApiServer {
  AgentApiServer({
    required RepoConfigStore repoConfigStore,
    required GitService gitService,
    WorktreeEventStore? eventStore,
    ClaudeSessionActivity? claudeActivity,
  }) : _repoConfigStore = repoConfigStore,
       _gitService = gitService,
       _activityService = ActivityService(
         eventStore: eventStore,
         claudeActivity: claudeActivity,
       );

  /// Default loopback port the agent API listens on.
  static const int defaultPort = 8765;

  final RepoConfigStore _repoConfigStore;
  final GitService _gitService;
  final ActivityService _activityService;

  HttpServer? _server;
  bool get isRunning => _server != null;
  int? get port => _server?.port;

  /// Starts the server on `127.0.0.1:[port]`. Never throws — if the bind fails
  /// (e.g. the port is already in use) it logs and leaves the server stopped so
  /// the app keeps launching normally.
  Future<void> start({int port = defaultPort}) async {
    if (_server != null) return;
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_router.call);
    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        port,
      );
      debugPrint(
        'AgentApiServer listening on http://127.0.0.1:${_server!.port}',
      );
    } catch (e) {
      debugPrint('AgentApiServer failed to start on port $port: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Router get _router => Router()
    ..get('/health', _health)
    ..get('/v1/activity', _activity);

  Response _health(Request request) => _json({
    'status': 'ok',
    'service': 'tree_launcher',
    'version': 1,
  });

  /// `GET /v1/activity?repo=<name>&filter=all|today|yesterday|thisWeek|thisMonth`
  Future<Response> _activity(Request request) async {
    final repoFilter = request.url.queryParameters['repo'];
    final filterParam = request.url.queryParameters['filter'];

    final filter = _parseFilter(filterParam);
    if (filter == null) {
      return _json({
        'error':
            'unknown filter "$filterParam" — expected one of: '
            '${ActivityFilter.values.map((f) => f.name).join(', ')}',
      }, status: 400);
    }

    try {
      final repos = await _repoConfigStore.load();
      final selected = repoFilter == null
          ? repos
          : repos.where((r) => r.name == repoFilter).toList();

      // Enumerate live worktrees across the selected repos, tagging each with
      // its repo name so event-less worktrees can still be filtered by repo.
      final currentWorktrees = <Worktree>[];
      final repoNamesByPath = <String, String>{};
      for (final RepoConfig repo in selected) {
        try {
          final result = await _gitService.getWorktrees(repo.path);
          for (final w in result.worktrees) {
            currentWorktrees.add(w);
            repoNamesByPath[w.path] = repo.name;
          }
        } catch (e) {
          // One unreadable repo shouldn't fail the whole request.
          debugPrint('AgentApiServer: getWorktrees(${repo.path}) failed: $e');
        }
      }

      var entries = await _activityService.loadEntries(
        currentWorktrees: currentWorktrees,
        repoNamesByWorktreePath: repoNamesByPath,
      );

      // Narrow to the requested repo by name (covers event-sourced entries too).
      if (repoFilter != null) {
        entries = entries.where((e) => e.repoName == repoFilter).toList();
      }

      // Apply the date-window filter against the current wall clock.
      final range = filter.range(DateTime.now());
      if (range != null) {
        entries = entries.where((e) => e.matchesRange(range)).toList();
      }

      return _json({
        'repo': repoFilter,
        'filter': filter.name,
        'count': entries.length,
        'entries': [for (final ActivityEntry e in entries) e.toJson()],
      });
    } catch (e) {
      debugPrint('AgentApiServer: /v1/activity failed: $e');
      return _json({'error': 'failed to load activity: $e'}, status: 500);
    }
  }

  static ActivityFilter? _parseFilter(String? value) {
    if (value == null || value.isEmpty) return ActivityFilter.all;
    for (final f in ActivityFilter.values) {
      if (f.name == value) return f;
    }
    return null;
  }

  static Response _json(Object data, {int status = 200}) => Response(
    status,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
