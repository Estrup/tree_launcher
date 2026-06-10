import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/activity_entry.dart';
import 'package:tree_launcher/features/activity/domain/activity_filter.dart';
import 'package:tree_launcher/features/activity/domain/activity_service.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/models/manual_post.dart';

/// A small read-only HTTP server, bound to loopback only, that exposes app data
/// to local AI agents (for use in Claude Code skills).
///
/// v1 surfaces the Activity timeline and worktree creation. The router is the
/// extension point — adding a capability is a new `_router` line plus a handler.
class AgentApiServer {
  AgentApiServer({
    required RepoConfigStore repoConfigStore,
    required GitService gitService,
    required AppSettingsStore appSettingsStore,
    WorktreeEventStore? eventStore,
    ClaudeSessionActivity? claudeActivity,
    ManualPostStore? manualPostStore,
  }) : _repoConfigStore = repoConfigStore,
       _gitService = gitService,
       _appSettingsStore = appSettingsStore,
       _manualPostStore = manualPostStore ?? ManualPostStore(),
       _activityService = ActivityService(
         eventStore: eventStore,
         claudeActivity: claudeActivity,
         manualPostStore: manualPostStore,
       );

  /// Default loopback port the agent API listens on.
  static const int defaultPort = 8765;

  final RepoConfigStore _repoConfigStore;
  final GitService _gitService;
  final AppSettingsStore _appSettingsStore;
  final ManualPostStore _manualPostStore;
  final ActivityService _activityService;

  /// Set by the live app once its controllers exist, so write endpoints route
  /// through the in-memory → save → notify pipeline. Null until registered
  /// (the server starts before the provider tree is built).
  WorktreeCreator? _worktreeCreator;

  /// Registers the live worktree creator. Called from app wiring after the
  /// `WorkspaceController` is constructed.
  void registerWorktreeCreator(WorktreeCreator creator) {
    _worktreeCreator = creator;
  }

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

  /// Stops the server (if running) and starts it again on [port]. Like [start],
  /// never throws — a failed rebind leaves the server stopped.
  Future<void> restart({int port = defaultPort}) async {
    await stop();
    await start(port: port);
  }

  Router get _router => Router()
    ..get('/health', _health)
    ..get('/v1/activity', _activity)
    ..post('/v1/activity', _createPost)
    ..post('/v1/worktrees', _createWorktree);

  Response _health(Request request) =>
      _json({'status': 'ok', 'service': 'tree_launcher', 'version': 1});

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
    final Map<String, dynamic> body;
    try {
      final raw = await request.readAsString();
      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _json({
          'error': 'request body must be a JSON object',
        }, status: 400);
      }
      body = decoded;
    } catch (e) {
      return _json({'error': 'invalid JSON body: $e'}, status: 400);
    }

    String? field(String key) {
      final value = body[key];
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    final repo = field('repo');
    final issueKey = field('issueKey');
    final missing = <String>[
      if (repo == null) 'repo',
      if (issueKey == null) 'issueKey',
    ];
    if (missing.isNotEmpty) {
      return _json({
        'error': 'missing required field(s): ${missing.join(', ')}',
      }, status: 400);
    }

    final jiraError = validateJiraKey(issueKey!);
    if (jiraError != null) {
      return _json({'error': 'issueKey: $jiraError'}, status: 400);
    }

    final hoursRaw = body['hours'];
    double? hours;
    if (hoursRaw != null) {
      hours = hoursRaw is num
          ? hoursRaw.toDouble()
          : double.tryParse(hoursRaw.toString());
      if (hours == null) {
        return _json({'error': 'hours must be a number'}, status: 400);
      }
    }

    try {
      final repos = await _repoConfigStore.load();
      final match = repos.where((r) => r.name == repo).toList();
      if (match.isEmpty) {
        return _json({'error': 'repo not found: $repo'}, status: 404);
      }
      final config = match.first;

      var description = field('description') ?? '';
      if (description.isEmpty) {
        for (final preset in config.predefinedIssues) {
          if (preset.key == issueKey) {
            description = preset.description;
            break;
          }
        }
      }

      final post = ManualPost(
        id: ManualPost.newId(),
        timestamp: DateTime.now(),
        repoName: config.name,
        issueKey: issueKey,
        description: description,
        hours: hours,
      );
      await _manualPostStore.add(post);
      return _json(post.toJson(), status: 201);
    } catch (e) {
      debugPrint('AgentApiServer: /v1/activity POST failed: $e');
      return _json({'error': 'failed to log post: $e'}, status: 500);
    }
  }

  /// `POST /v1/worktrees`
  ///
  /// JSON body:
  /// - `repo` (required) — repo name, as in `GET /v1/activity?repo=`.
  /// - `baseBranch` (required) — branch the worktree is created from.
  /// - `branch` (required) — the new-branch suffix; the full branch becomes
  ///   `<defaultBranchPrefix>/<branch>` when a prefix is configured.
  /// - `worktreeName` (required) — the worktree directory name.
  /// - `issueKey` (optional) — Jira key stored as worktree metadata.
  ///
  /// `worktreeName` and `branch` are normalized (lowercased, spaces→dashes) and
  /// validated against the app's naming rules.
  Future<Response> _createWorktree(Request request) async {
    final creator = _worktreeCreator;
    if (creator == null) {
      return _json({'error': 'app not ready'}, status: 503);
    }

    final Map<String, dynamic> body;
    try {
      final raw = await request.readAsString();
      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _json({
          'error': 'request body must be a JSON object',
        }, status: 400);
      }
      body = decoded;
    } catch (e) {
      return _json({'error': 'invalid JSON body: $e'}, status: 400);
    }

    String? field(String key) {
      final value = body[key];
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    final repo = field('repo');
    final baseBranch = field('baseBranch');
    final branchInput = field('branch');
    final worktreeInput = field('worktreeName');
    final issueKey = field('issueKey');

    final missing = <String>[
      if (repo == null) 'repo',
      if (baseBranch == null) 'baseBranch',
      if (branchInput == null) 'branch',
      if (worktreeInput == null) 'worktreeName',
    ];
    if (missing.isNotEmpty) {
      return _json({
        'error': 'missing required field(s): ${missing.join(', ')}',
      }, status: 400);
    }

    final worktreeName = normalizeWorktreeName(worktreeInput!);
    final branchSuffix = normalizeWorktreeName(branchInput!);

    final worktreeError = validateWorktreeName(worktreeName);
    if (worktreeError != null) {
      return _json({'error': 'worktreeName: $worktreeError'}, status: 400);
    }
    final branchError = validateWorktreeName(branchSuffix);
    if (branchError != null) {
      return _json({'error': 'branch: $branchError'}, status: 400);
    }
    if (issueKey != null) {
      final jiraError = validateJiraKey(issueKey);
      if (jiraError != null) {
        return _json({'error': 'issueKey: $jiraError'}, status: 400);
      }
    }

    try {
      final settings = await _appSettingsStore.load();
      final newBranch = buildBranchName(
        branchSuffix,
        settings.defaultBranchPrefix,
      );

      final created = await creator.createWorktree(
        repoName: repo!,
        worktreeName: worktreeName,
        baseBranch: baseBranch!,
        newBranch: newBranch,
        jiraIssue: issueKey,
      );

      return _json({
        'repo': repo,
        'worktreeName': worktreeName,
        'worktreePath': created.worktreePath,
        'branch': created.branch,
        'slot': created.slot,
        'issueKey': issueKey,
      }, status: 201);
    } on RepoNotFoundException catch (e) {
      return _json({'error': e.toString()}, status: 404);
    } catch (e) {
      debugPrint('AgentApiServer: /v1/worktrees failed: $e');
      final message = e.toString().replaceFirst('Exception: ', '');
      final status = message.contains('already exists') ? 409 : 500;
      return _json({'error': message}, status: status);
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
