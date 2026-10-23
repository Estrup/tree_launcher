import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/agent_api/data/api_http.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_registry.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/settings/domain/app_settings_source.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

/// `/v1/agents/...`: agent runs register here and report their progress,
/// which the running app shows in its agent tabs.
class AgentRoutes {
  AgentRoutes({
    required RepoCatalog repos,
    required GitService gitService,
    required AgentRegistry registry,
    required AppSettingsSource settings,
  }) : _repos = repos,
       _gitService = gitService,
       _registry = registry,
       _settings = settings;

  final RepoCatalog _repos;
  final GitService _gitService;
  final AgentRegistry _registry;
  final AppSettingsSource _settings;

  void mount(Router router) => router
    ..get('/v1/agents', _list)
    ..post('/v1/agents', _register)
    ..get('/v1/agents/<id>', _get)
    ..post('/v1/agents/<id>/status', _reportStatus);

  /// `GET /v1/agents?repo=<name>&kind=<kind>&active=true|false&issue=<key>&archived=true`
  ///
  /// Lists agent runs, newest update first. Every filter is optional;
  /// archived runs are left out unless `archived=true`.
  Future<Response> _list(Request request) async {
    final registry = _registry;
    final query = request.url.queryParameters;

    final kindParam = query['kind']?.trim();
    AgentKind? kind;
    if (kindParam != null && kindParam.isNotEmpty) {
      kind = AgentKind.tryParse(kindParam);
      if (kind == null || !_isAgentType(kind)) return _unknownKind(kindParam);
    }
    final active = boolQuery(query, 'active');
    if (active.error != null) return active.error!;
    final archived = boolQuery(query, 'archived');
    if (archived.error != null) return archived.error!;
    final repo = query['repo']?.trim();
    final issue = query['issue']?.trim().toUpperCase();
    final includeArchived = archived.value ?? false;

    final runs = [
      for (final run in registry.runs)
        if ((repo == null || repo.isEmpty || run.repoName == repo) &&
            (kind == null || run.kind == kind) &&
            (active.value == null ||
                run.state.isFinished != active.value) &&
            (issue == null || issue.isEmpty || run.issueKeys.contains(issue)) &&
            (includeArchived || !run.archived))
          run,
    ];
    return jsonResponse({
      'count': runs.length,
      'agents': [for (final run in runs) run.toJson()],
    });
  }

  /// `GET /v1/agents/<id>` — one run with its latest timeline events.
  Response _get(Request request, String id) {
    final registry = _registry;
    final run = registry.runById(id);
    if (run == null) {
      return jsonResponse({'error': 'agent not found: $id'}, status: 404);
    }
    final events = registry.eventsFor(id);
    final recent = events.length > 50
        ? events.sublist(events.length - 50)
        : events;
    return jsonResponse({
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
  Future<Response> _register(Request request) async {
    final registry = _registry;
    final parsed = await readJsonObject(request);
    if (parsed.error != null) return parsed.error!;
    final body = parsed.body!;

    final unknown = body.keys.where((k) => !_registerFields.contains(k));
    if (unknown.isNotEmpty) return unsupportedFields(unknown, _registerFields);

    String? field(String key) => stringField(body, key);

    final id = field('id');
    final kindName = field('kind');
    final kind = AgentKind.tryParse(kindName);
    if (kindName != null && (kind == null || !_isAgentType(kind))) {
      return _unknownKind(kindName);
    }
    var repo = field('repo');
    final worktreePath = field('worktreePath');
    if (id == null && repo == null && worktreePath != null) {
      repo = await _repoOfWorktree(worktreePath);
    }
    if (id == null) {
      final missing = [if (kind == null) 'kind', if (repo == null) 'repo'];
      if (missing.isNotEmpty) {
        return jsonResponse({
          'error':
              'missing required field(s): ${missing.join(', ')}'
              '${repo == null && worktreePath != null ? ' ($worktreePath is not a worktree of any repo)' : ''}',
        }, status: 400);
      }
    }
    if (repo != null) {
      final repos = await _repos.loadedRepos();
      if (!repos.any((r) => r.name == repo)) {
        return jsonResponse({'error': 'repo not found: $repo'}, status: 404);
      }
    }
    if (kind != null) {
      final runRepo =
          repo ?? (id == null ? null : registry.runById(id)?.repoName);
      final repos = await _repos.loadedRepos();
      final config = repos.where((r) => r.name == runRepo).firstOrNull;
      if (config != null && !config.usesAgentType(kind)) {
        return jsonResponse({
          'error':
              'agent type "${kind.id}" is switched off for repo ${config.name} '
              '(repo settings → Agents)',
        }, status: 409);
      }
    }

    final List<String>? issueKeys;
    final List<String>? stages;
    try {
      final keys = <String>[
        ...?nameList(body['issueKeys'], 'issueKeys'),
        ...?nameList(body['issueKey'], 'issueKey'),
      ];
      issueKeys = body.containsKey('issueKeys') || body.containsKey('issueKey')
          ? [
              ...{for (final key in keys) key.toUpperCase()},
            ]
          : null;
      stages = nameList(body['stages'], 'stages')?.toSet().toList();
    } on FormatException catch (e) {
      return jsonResponse({'error': e.message}, status: 400);
    }
    for (final key in issueKeys ?? const <String>[]) {
      final error = validateJiraKey(key);
      if (error != null) {
        return jsonResponse({'error': 'issue key $key: $error'}, status: 400);
      }
    }

    final pr = intField(body, 'prNumber');
    if (pr.error != null) return pr.error!;
    final prNumber = pr.value;

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
      return jsonResponse(
        result.run.toJson(),
        status: result.created ? 201 : 200,
      );
    } on AgentNotFoundException catch (e) {
      return jsonResponse({'error': e.toString()}, status: 404);
    } on ArgumentError catch (e) {
      return jsonResponse({'error': '${e.message}'}, status: 400);
    } catch (e) {
      return serverError('register agent', e);
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
  Future<Response> _reportStatus(Request request, String id) async {
    final registry = _registry;
    if (registry.runById(id) == null) {
      return jsonResponse({'error': 'agent not found: $id'}, status: 404);
    }
    final parsed = await readJsonObject(request);
    if (parsed.error != null) return parsed.error!;
    final body = parsed.body!;

    final unknown = body.keys.where((k) => !_statusFields.contains(k));
    if (unknown.isNotEmpty) return unsupportedFields(unknown, _statusFields);
    if (body.isEmpty) {
      return jsonResponse({
        'error':
            'nothing to report; give at least one of: '
            '${_statusFields.join(', ')}',
      }, status: 400);
    }

    String? field(String key) => stringField(body, key);

    final stateName = field('state');
    final state = AgentState.tryParse(stateName);
    if (stateName != null && (state == null || state == AgentState.starting)) {
      return jsonResponse({
        'error':
            'unknown state "$stateName" — expected one of: '
            'running, waiting, done, failed, stopped',
      }, status: 400);
    }
    final stage = field('stage');
    final stageStateName = field('stageState');
    final stageState = AgentStageState.tryParse(stageStateName);
    if (stageStateName != null && stageState == null) {
      return jsonResponse({
        'error':
            'unknown stageState "$stageStateName" — expected one of: '
            '${AgentStageState.values.map((s) => s.name).join(', ')}',
      }, status: 400);
    }
    final levelName = field('level');
    final level = AgentEventLevel.tryParse(levelName);
    if (levelName != null && level == null) {
      return jsonResponse({
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
      return jsonResponse({
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
          return jsonResponse({
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
        return jsonResponse({
          'error': 'progress must be "4/7" or {"done": 4, "total": 7}',
        }, status: 400);
      }
    }
    if (stage == null && (stageState != null || progress != null)) {
      return jsonResponse({
        'error': 'stageState and progress need a stage',
      }, status: 400);
    }

    final links = <AgentLink>[];
    final linksRaw = body['links'];
    if (linksRaw != null) {
      if (linksRaw is! Map ||
          linksRaw.values.any((v) => v is! String || v.trim().isEmpty)) {
        return jsonResponse({
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
      stages = nameList(body['stages'], 'stages')?.toSet().toList();
    } on FormatException catch (e) {
      return jsonResponse({'error': e.message}, status: 400);
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
      return jsonResponse(run.toJson());
    } on AgentNotFoundException catch (e) {
      return jsonResponse({'error': e.toString()}, status: 404);
    } catch (e) {
      return serverError('report status', e);
    }
  }

  /// The name of the repo [worktreePath] is a worktree of (or the repo's own
  /// directory), or null. Asks git for every repo's worktrees at once.
  Future<String?> _repoOfWorktree(String worktreePath) async {
    final target = p.normalize(worktreePath);
    final repos = await _repos.loadedRepos();
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

  bool _isAgentType(AgentKind kind) =>
      _settings.settings.agentTypes.any((t) => t.kind == kind);

  Response _unknownKind(String kind) => jsonResponse({
    'error':
        'unknown kind "$kind" — expected one of: '
        '${_settings.settings.agentTypes.map((t) => t.kind.id).join(', ')}',
  }, status: 400);
}
