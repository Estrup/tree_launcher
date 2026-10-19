import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/activity_entry.dart';
import 'package:tree_launcher/features/activity/domain/activity_filter.dart';
import 'package:tree_launcher/features/activity/domain/activity_service.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_registry.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_constants.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag_editor.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';
import 'package:tree_launcher/models/jira_tag.dart';
import 'package:tree_launcher/models/manual_post.dart';

/// A small HTTP server, bound to loopback only, that exposes app data to local
/// AI agents (for use in Claude Code skills).
///
/// v1 surfaces the Activity timeline, worktree creation, Jira issues with the
/// user's local tags (which it can set, but never anything in Jira), and agent
/// runs, which agents register and report their progress to. The router is
/// the extension point — adding a capability is a new `_router` line
/// plus a handler.
///
/// Requests a web page could send are refused: see [_localClientsOnly].
class AgentApiServer {
  AgentApiServer({
    required RepoConfigStore repoConfigStore,
    required GitService gitService,
    required AppSettingsStore appSettingsStore,
    WorktreeEventStore? eventStore,
    ClaudeSessionActivity? claudeActivity,
    ManualPostStore? manualPostStore,
    JiraApiService? jiraService,
  }) : _repoConfigStore = repoConfigStore,
       _gitService = gitService,
       _appSettingsStore = appSettingsStore,
       _jiraService = jiraService ?? JiraApiService(),
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
  final JiraApiService _jiraService;

  /// Set by the live app once its controllers exist, so write endpoints route
  /// through the in-memory → save → notify pipeline. Null until registered
  /// (the server starts before the provider tree is built).
  WorktreeCreator? _worktreeCreator;

  /// Registers the live worktree creator. Called from app wiring after the
  /// `WorkspaceController` is constructed.
  void registerWorktreeCreator(WorktreeCreator creator) {
    _worktreeCreator = creator;
  }

  /// Set by the live app once its settings controller exists, so tag writes
  /// go through it. Until then tags are read from disk and can't be set.
  JiraTagEditor? _jiraTagEditor;

  /// Registers the live Jira tag editor. Called from app wiring after the
  /// `SettingsController` is constructed.
  void registerJiraTagEditor(JiraTagEditor editor) {
    _jiraTagEditor = editor;
  }

  /// Set by the live app once its agents controller exists. Until then the
  /// agent routes answer 503.
  AgentRegistry? _agentRegistry;

  /// Registers the live agent runs. Called from app wiring after the
  /// `AgentsController` is constructed.
  void registerAgentRegistry(AgentRegistry registry) {
    _agentRegistry = registry;
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
        .addMiddleware(_localClientsOnly(port))
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

  /// Refuses what a web page open in a browser could send here:
  /// - a `Host` other than `127.0.0.1:<port>` or `localhost:<port>` (403),
  ///   which blocks DNS rebinding;
  /// - a POST or PUT that isn't `application/json` (415). Browsers send a
  ///   "simple" cross-site `text/plain` POST without asking, but must ask
  ///   first (a CORS preflight, which this server never answers) for JSON.
  Middleware _localClientsOnly(int requestedPort) =>
      (inner) => (request) {
        // The bound port: [requestedPort] is 0 when the OS picks one.
        final port = _server?.port ?? requestedPort;
        final host = request.headers['host']?.toLowerCase();
        if (host != '127.0.0.1:$port' && host != 'localhost:$port') {
          return _json({
            'error': 'Host must be 127.0.0.1:$port or localhost:$port',
          }, status: 403);
        }
        if ((request.method == 'POST' || request.method == 'PUT') &&
            _mimeType(request) != 'application/json') {
          return _json({
            'error': 'Content-Type must be application/json',
          }, status: 415);
        }
        return inner(request);
      };

  static String? _mimeType(Request request) {
    try {
      return request.mimeType;
    } on FormatException {
      return null;
    }
  }

  Router get _router => Router()
    ..get('/health', _health)
    ..get('/v1/activity', _activity)
    ..post('/v1/activity', _createPost)
    ..post('/v1/worktrees', _createWorktree)
    ..get('/v1/jira/issues', _jiraIssues)
    ..get('/v1/jira/tags', _jiraTags)
    ..put('/v1/jira/issues/<key>/tags', _setJiraIssueTags)
    ..get('/v1/agents', _listAgents)
    ..post('/v1/agents', _registerAgent)
    ..get('/v1/agents/<id>', _getAgent)
    ..post('/v1/agents/<id>/status', _reportAgentStatus);

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
  /// - `kickoffPrompt` (optional) — prompt text (e.g. a full implementation
  ///   plan) written to `<worktree>/.tree-launcher/kickoff-prompt.md`; the
  ///   response returns its `kickoffPromptPath`, and the worktree's Claude
  ///   dropdown gains a "Kickoff prompt" option that launches Claude pointed
  ///   at the file.
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
    final kickoffPrompt = field('kickoffPrompt');

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
        kickoffPrompt: kickoffPrompt,
      );

      return _json({
        'repo': repo,
        'worktreeName': worktreeName,
        'worktreePath': created.worktreePath,
        'branch': created.branch,
        'issueKey': issueKey,
        'kickoffPromptPath': created.kickoffPromptPath,
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
  Future<Response> _jiraIssues(Request request) async {
    final query = request.url.queryParameters;
    final versionParam = query['fixVersion']?.trim();
    final statuses = <String>[
      for (final value in request.url.queryParametersAll['status'] ?? const [])
        for (final status in value.split(','))
          if (status.trim().isNotEmpty) status.trim(),
    ];
    if ((versionParam == null || versionParam.isEmpty) && statuses.isEmpty) {
      return _json({'error': 'give fixVersion, status, or both'}, status: 400);
    }

    final project = await _projectKeyFor(query);
    if (project.error != null) return project.error!;
    final projectKey = project.key!;

    try {
      String? versionId;
      Map<String, dynamic>? version;
      if (versionParam != null && versionParam.isNotEmpty) {
        final versions = await _jiraService.fetchVersions(projectKey);
        final lower = versionParam.toLowerCase();
        final match = versions
            .where((v) => v.id == versionParam || v.name.toLowerCase() == lower)
            .firstOrNull;
        if (match == null) {
          return _json({
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

      final issues = await _jiraService.searchIssues(
        jiraIssuesJql(projectKey, versionId: versionId, statuses: statuses),
      );
      final tagsFor = await _tagLookup();
      return _json({
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
              'tags': [for (final tag in tagsFor(issue.key)) tag.name],
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
      return _json({'error': message}, status: status);
    }
  }

  /// `GET /v1/jira/tags` — the user's local tags, in display order.
  Future<Response> _jiraTags(Request request) async {
    final tags =
        _jiraTagEditor?.jiraTags ?? (await _appSettingsStore.load()).jiraTags;
    return _json({
      'tags': [
        for (final tag in tags) {'name': tag.name, 'color': tag.color},
      ],
    });
  }

  /// `PUT /v1/jira/issues/<key>/tags`
  ///
  /// Replaces the user's local tags on issue `<key>`. JSON body: `tags` — the
  /// tag names (any case), as listed by `GET /v1/jira/tags`; an empty list
  /// removes them all. Only local tags change: nothing is sent to Jira, and
  /// any other field is rejected.
  Future<Response> _setJiraIssueTags(Request request, String key) async {
    final editor = _jiraTagEditor;
    if (editor == null) {
      return _json({'error': 'app not ready'}, status: 503);
    }
    final issueKey = key.trim().toUpperCase();
    final keyError = validateJiraKey(issueKey);
    if (keyError != null) {
      return _json({'error': 'issue key: $keyError'}, status: 400);
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

    final other = body.keys.where((k) => k != 'tags').toList();
    if (other.isNotEmpty) {
      return _json({
        'error':
            'only local tags can be set; unsupported field(s): '
            '${other.join(', ')}',
      }, status: 400);
    }
    final names = body['tags'];
    if (names is! List || names.any((n) => n is! String)) {
      return _json({'error': 'tags must be a list of tag names'}, status: 400);
    }

    final tags = editor.jiraTags;
    final byName = {for (final tag in tags) tag.name.toLowerCase(): tag};
    final unknown = [
      for (final name in names.cast<String>())
        if (!byName.containsKey(name.trim().toLowerCase())) name,
    ];
    if (unknown.isNotEmpty) {
      return _json({
        'error': 'unknown tag(s): ${unknown.join(', ')}',
        'tags': [for (final tag in tags) tag.name],
      }, status: 400);
    }

    try {
      // A set drops repeated names, keeping the first.
      await editor.setJiraTagsFor(issueKey, [
        ...{
          for (final name in names.cast<String>())
            byName[name.trim().toLowerCase()]!.id,
        },
      ]);
      return _json({
        'key': issueKey,
        'tags': [for (final tag in editor.jiraTagsFor(issueKey)) tag.name],
      });
    } catch (e) {
      debugPrint(
        'AgentApiServer: PUT /v1/jira/issues/$issueKey/tags failed: $e',
      );
      return _json({'error': 'failed to save tags: $e'}, status: 500);
    }
  }

  /// `GET /v1/agents?repo=<name>&kind=<kind>&active=true|false&issue=<key>&archived=true`
  ///
  /// Lists agent runs, newest update first. Every filter is optional;
  /// archived runs are left out unless `archived=true`.
  Future<Response> _listAgents(Request request) async {
    final registry = _agentRegistry;
    if (registry == null) return _json({'error': 'app not ready'}, status: 503);
    final query = request.url.queryParameters;

    final kindParam = query['kind']?.trim();
    AgentKind? kind;
    if (kindParam != null && kindParam.isNotEmpty) {
      kind = AgentKind.tryParse(kindParam);
      if (kind == null) return _unknownKind(kindParam);
    }
    final activeParam = query['active']?.trim();
    if (activeParam != null &&
        activeParam != 'true' &&
        activeParam != 'false') {
      return _json({'error': 'active must be true or false'}, status: 400);
    }
    final repo = query['repo']?.trim();
    final issue = query['issue']?.trim().toUpperCase();
    final includeArchived = query['archived'] == 'true';

    final runs = [
      for (final run in registry.runs)
        if ((repo == null || repo.isEmpty || run.repoName == repo) &&
            (kind == null || run.kind == kind) &&
            (activeParam == null ||
                run.state.isFinished == (activeParam == 'false')) &&
            (issue == null || issue.isEmpty || run.issueKeys.contains(issue)) &&
            (includeArchived || !run.archived))
          run,
    ];
    return _json({
      'count': runs.length,
      'agents': [for (final run in runs) run.toJson()],
    });
  }

  /// `GET /v1/agents/<id>` — one run with its latest timeline events.
  Response _getAgent(Request request, String id) {
    final registry = _agentRegistry;
    if (registry == null) return _json({'error': 'app not ready'}, status: 503);
    final run = registry.runById(id);
    if (run == null) {
      return _json({'error': 'agent not found: $id'}, status: 404);
    }
    final events = registry.eventsFor(id);
    final recent = events.length > 50
        ? events.sublist(events.length - 50)
        : events;
    return _json({
      ...run.toJson(),
      'events': [for (final event in recent) event.toJson()],
    });
  }

  static const _registerFields = {
    'id',
    'kind',
    'repo',
    'prompt',
    'title',
    'issueKey',
    'issueKeys',
    'worktreePath',
    'branch',
    'prNumber',
    'stages',
    'model',
    'effort',
  };

  /// `POST /v1/agents`
  ///
  /// Registers an agent run. JSON body:
  /// - `id` (optional) — a run the app created when it launched the agent
  ///   (`$TREE_LAUNCHER_AGENT_ID`); the other fields update it. 404 if unknown.
  /// - `kind` and `repo` — required without `id`: `build`, `verify`,
  ///   `review` or `docs`, and a repo name. Without `repo`, the repo whose
  ///   worktree `worktreePath` is.
  /// - `prompt`, `title`, `worktreePath`, `branch`, `model`, `effort` —
  ///   optional strings; `prNumber` an optional number.
  /// - `issueKey` / `issueKeys` — one key, or a list (or comma-separated).
  /// - `stages` — the agent's stage names in order (list or comma-separated).
  ///
  /// Without `id`, an active run with the same kind, repo, worktree and
  /// issues is updated instead of creating another (200); a new run is 201.
  Future<Response> _registerAgent(Request request) async {
    final registry = _agentRegistry;
    if (registry == null) return _json({'error': 'app not ready'}, status: 503);
    final parsed = await _readJsonObject(request);
    if (parsed.error != null) return parsed.error!;
    final body = parsed.body!;

    final unknown = body.keys.where((k) => !_registerFields.contains(k));
    if (unknown.isNotEmpty) return _unsupportedFields(unknown, _registerFields);

    String? field(String key) {
      final value = body[key];
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    final id = field('id');
    final kindName = field('kind');
    final kind = AgentKind.tryParse(kindName);
    if (kindName != null && kind == null) return _unknownKind(kindName);
    var repo = field('repo');
    final worktreePath = field('worktreePath');
    if (id == null && repo == null && worktreePath != null) {
      repo = await _repoOfWorktree(worktreePath);
    }
    if (id == null) {
      final missing = [if (kind == null) 'kind', if (repo == null) 'repo'];
      if (missing.isNotEmpty) {
        return _json({
          'error':
              'missing required field(s): ${missing.join(', ')}'
              '${repo == null && worktreePath != null ? ' ($worktreePath is not a worktree of any repo)' : ''}',
        }, status: 400);
      }
    }
    if (repo != null) {
      final repos = await _repoConfigStore.load();
      if (!repos.any((r) => r.name == repo)) {
        return _json({'error': 'repo not found: $repo'}, status: 404);
      }
    }

    final List<String>? issueKeys;
    final List<String>? stages;
    try {
      final keys = <String>[
        ...?_names(body['issueKeys'], 'issueKeys'),
        ...?_names(body['issueKey'], 'issueKey'),
      ];
      issueKeys = body.containsKey('issueKeys') || body.containsKey('issueKey')
          ? [
              ...{for (final key in keys) key.toUpperCase()},
            ]
          : null;
      stages = _names(body['stages'], 'stages')?.toSet().toList();
    } on FormatException catch (e) {
      return _json({'error': e.message}, status: 400);
    }
    for (final key in issueKeys ?? const <String>[]) {
      final error = validateJiraKey(key);
      if (error != null) {
        return _json({'error': 'issue key $key: $error'}, status: 400);
      }
    }

    int? prNumber;
    final prRaw = body['prNumber'];
    if (prRaw != null) {
      prNumber = prRaw is int ? prRaw : int.tryParse(prRaw.toString().trim());
      if (prNumber == null) {
        return _json({'error': 'prNumber must be a number'}, status: 400);
      }
    }

    try {
      final result = await registry.register(
        AgentRegistration(
          kind: kind,
          repoName: repo,
          promptName: field('prompt'),
          title: field('title'),
          issueKeys: issueKeys,
          worktreePath: worktreePath,
          branch: field('branch'),
          prNumber: prNumber,
          stages: stages,
          model: field('model'),
          effort: field('effort'),
        ),
        id: id,
      );
      return _json(result.run.toJson(), status: result.created ? 201 : 200);
    } on AgentNotFoundException catch (e) {
      return _json({'error': e.toString()}, status: 404);
    } on ArgumentError catch (e) {
      return _json({'error': '${e.message}'}, status: 400);
    } catch (e) {
      debugPrint('AgentApiServer: POST /v1/agents failed: $e');
      return _json({'error': 'failed to register agent: $e'}, status: 500);
    }
  }

  static const _statusFields = {
    'state',
    'stage',
    'stageState',
    'progress',
    'stages',
    'message',
    'level',
    'links',
    'result',
  };

  /// Longest `message` kept; longer ones are cut.
  static const _maxMessageLength = 2000;

  /// `POST /v1/agents/<id>/status`
  ///
  /// Reports an agent's progress. Every field is optional, but at least one
  /// is needed:
  /// - `state` — `running`, `waiting` (needs a human; requires `message`),
  ///   `done`, `failed` or `stopped`.
  /// - `stage` — the stage this is about, with optional `stageState`
  ///   (`pending`, `running`, `waiting`, `done`, `failed`, `skipped`) and
  ///   `progress` (`"4/7"` or `{"done": 4, "total": 7}`).
  /// - `stages` — re-declares the stage names.
  /// - `message` — one line for the timeline and the card; `level` — `info`,
  ///   `success`, `warning`, `error` or `action`.
  /// - `links` — `{"label": "url or path"}`, added to the run's links.
  /// - `result` — the outcome in a few words.
  Future<Response> _reportAgentStatus(Request request, String id) async {
    final registry = _agentRegistry;
    if (registry == null) return _json({'error': 'app not ready'}, status: 503);
    if (registry.runById(id) == null) {
      return _json({'error': 'agent not found: $id'}, status: 404);
    }
    final parsed = await _readJsonObject(request);
    if (parsed.error != null) return parsed.error!;
    final body = parsed.body!;

    final unknown = body.keys.where((k) => !_statusFields.contains(k));
    if (unknown.isNotEmpty) return _unsupportedFields(unknown, _statusFields);
    if (body.isEmpty) {
      return _json({
        'error':
            'nothing to report; give at least one of: '
            '${_statusFields.join(', ')}',
      }, status: 400);
    }

    String? field(String key) {
      final value = body[key];
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    final stateName = field('state');
    final state = AgentState.tryParse(stateName);
    if (stateName != null && (state == null || state == AgentState.starting)) {
      return _json({
        'error':
            'unknown state "$stateName" — expected one of: '
            'running, waiting, done, failed, stopped',
      }, status: 400);
    }
    final stage = field('stage');
    final stageStateName = field('stageState');
    final stageState = AgentStageState.tryParse(stageStateName);
    if (stageStateName != null && stageState == null) {
      return _json({
        'error':
            'unknown stageState "$stageStateName" — expected one of: '
            '${AgentStageState.values.map((s) => s.name).join(', ')}',
      }, status: 400);
    }
    final levelName = field('level');
    final level = AgentEventLevel.tryParse(levelName);
    if (levelName != null && level == null) {
      return _json({
        'error':
            'unknown level "$levelName" — expected one of: '
            '${AgentEventLevel.values.map((l) => l.name).join(', ')}',
      }, status: 400);
    }

    var message = field('message');
    if (message != null && message.length > _maxMessageLength) {
      message = '${message.substring(0, _maxMessageLength)}…';
    }
    if (state == AgentState.waiting && message == null) {
      return _json({
        'error': 'state waiting needs a message saying what is needed',
      }, status: 400);
    }

    int? progressDone;
    int? progressTotal;
    final progress = body['progress'];
    if (progress != null) {
      if (progress is String) {
        final match = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s*$').firstMatch(progress);
        if (match == null) {
          return _json({
            'error': 'progress must be "done/total", e.g. "4/7"',
          }, status: 400);
        }
        progressDone = int.parse(match.group(1)!);
        progressTotal = int.parse(match.group(2)!);
      } else if (progress is Map &&
          (progress['done'] == null || progress['done'] is int) &&
          (progress['total'] == null || progress['total'] is int)) {
        progressDone = progress['done'] as int?;
        progressTotal = progress['total'] as int?;
      } else {
        return _json({
          'error': 'progress must be "4/7" or {"done": 4, "total": 7}',
        }, status: 400);
      }
    }
    if (stage == null && (stageState != null || progress != null)) {
      return _json({
        'error': 'stageState and progress need a stage',
      }, status: 400);
    }

    final links = <AgentLink>[];
    final linksRaw = body['links'];
    if (linksRaw != null) {
      if (linksRaw is! Map ||
          linksRaw.values.any((v) => v is! String || v.trim().isEmpty)) {
        return _json({
          'error': 'links must be an object of label → URL or path',
        }, status: 400);
      }
      for (final MapEntry(:key, :value) in linksRaw.entries) {
        final label = key.toString().trim();
        if (label.isEmpty) continue;
        links.add(AgentLink(label: label, target: (value as String).trim()));
      }
    }

    final List<String>? stages;
    try {
      stages = _names(body['stages'], 'stages')?.toSet().toList();
    } on FormatException catch (e) {
      return _json({'error': e.message}, status: 400);
    }

    var result = field('result');
    if (result != null && result.length > 200) {
      result = '${result.substring(0, 200)}…';
    }

    try {
      final run = await registry.report(
        id,
        AgentReport(
          state: state,
          stage: stage,
          stageState: stageState,
          progressDone: progressDone,
          progressTotal: progressTotal,
          stages: stages,
          message: message,
          level: level,
          links: links,
          result: result,
        ),
      );
      return _json(run.toJson());
    } on AgentNotFoundException catch (e) {
      return _json({'error': e.toString()}, status: 404);
    } catch (e) {
      debugPrint('AgentApiServer: POST /v1/agents/$id/status failed: $e');
      return _json({'error': 'failed to report status: $e'}, status: 500);
    }
  }

  /// The name of the repo [worktreePath] is a worktree of (or the repo's own
  /// directory), or null. Asks git for every repo's worktrees at once.
  Future<String?> _repoOfWorktree(String worktreePath) async {
    final target = p.normalize(worktreePath);
    final repos = await _repoConfigStore.load();
    final found = await Future.wait([
      for (final repo in repos)
        () async {
          if (p.equals(repo.path, target)) return repo.name;
          try {
            final result = await _gitService.getWorktrees(repo.path);
            if (result.worktrees.any((w) => p.equals(w.path, target))) {
              return repo.name;
            }
          } catch (_) {
            // An unreadable repo can't be the match.
          }
          return null;
        }(),
    ]);
    return found.nonNulls.firstOrNull;
  }

  /// Names from a JSON list of strings or a comma-separated string, trimmed
  /// and without blanks; null when [value] is null. Throws [FormatException]
  /// naming [field] for anything else.
  static List<String>? _names(Object? value, String field) {
    if (value == null) return null;
    final Iterable<String> raw;
    if (value is String) {
      raw = value.split(',');
    } else if (value is List && value.every((v) => v is String)) {
      raw = value.cast<String>();
    } else {
      throw FormatException('$field must be a list of strings');
    }
    return [
      for (final name in raw)
        if (name.trim().isNotEmpty) name.trim(),
    ];
  }

  static Response _unknownKind(String kind) => _json({
    'error':
        'unknown kind "$kind" — expected one of: '
        '${AgentKind.values.map((k) => k.name).join(', ')}',
  }, status: 400);

  static Response _unsupportedFields(
    Iterable<String> fields,
    Set<String> allowed,
  ) => _json({
    'error': 'unsupported field(s): ${fields.join(', ')}',
    'fields': allowed.toList(),
  }, status: 400);

  /// The request's JSON object body, or the 400 response to send.
  static Future<({Map<String, dynamic>? body, Response? error})>
  _readJsonObject(Request request) async {
    try {
      final raw = await request.readAsString();
      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return (
          body: null,
          error: _json({
            'error': 'request body must be a JSON object',
          }, status: 400),
        );
      }
      return (body: decoded, error: null);
    } catch (e) {
      return (
        body: null,
        error: _json({'error': 'invalid JSON body: $e'}, status: 400),
      );
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
        error: _json({'error': 'give repo or project'}, status: 400),
      );
    }
    final repos = await _repoConfigStore.load();
    final repo = repos.where((r) => r.name == repoName).firstOrNull;
    if (repo == null) {
      return (
        key: null,
        error: _json({'error': 'repo not found: $repoName'}, status: 404),
      );
    }
    final key = repo.jiraProjectKey;
    if (key == null || key.isEmpty) {
      return (
        key: null,
        error: _json({
          'error': 'repo $repoName has no Jira project key',
        }, status: 400),
      );
    }
    return (key: key, error: null);
  }

  /// Looks up an issue's local tags: live from the app when it has
  /// registered, otherwise from the saved settings.
  Future<List<JiraTag> Function(String issueKey)> _tagLookup() async {
    final editor = _jiraTagEditor;
    if (editor != null) return editor.jiraTagsFor;
    final settings = await _appSettingsStore.load();
    return settings.tagsFor;
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
