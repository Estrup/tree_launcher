import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/activity_service.dart';
import 'package:tree_launcher/features/activity/presentation/controllers/activity_controller.dart';
import 'package:tree_launcher/features/activity/domain/predefined_issue.dart';
import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_registry.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag_editor.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/domain/app_settings_source.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';

import 'test_database.dart';

/// The live app's repos, in memory. Loaded at once unless [loaded] is
/// given, which the repos wait for.
class _FakeRepos implements RepoCatalog {
  _FakeRepos(this._repos, {Future<void>? loaded})
    : whenLoaded = loaded ?? Future.value();

  List<RepoConfig> _repos;

  @override
  List<RepoConfig> get repos => _repos;

  set repos(List<RepoConfig> repos) => _repos = repos;

  @override
  final Future<void> whenLoaded;
}

/// The live app's settings, in memory.
class _FakeSettings implements AppSettingsSource {
  _FakeSettings([AppSettings? settings]) : settings = settings ?? AppSettings();

  @override
  final AppSettings settings;
}

/// An app without agent runs, for the tests that don't use them.
class _NoAgents implements AgentRegistry {
  @override
  List<AgentRun> get runs => const [];

  @override
  AgentRun? runById(String id) => null;

  @override
  List<AgentEvent> eventsFor(String id) => const [];

  @override
  Future<({AgentRun run, bool created})> register(
    AgentRegistration registration, {
    String? id,
  }) => throw UnimplementedError();

  @override
  Future<AgentRun> report(String id, AgentReport report) =>
      throw UnimplementedError();
}

const _tags = [
  JiraTag(id: 'b', name: 'Blocked', color: 'red'),
  JiraTag(id: 'd', name: 'Demo', color: 'blue'),
];

/// The live app's tags, in memory.
class _FakeTagEditor implements JiraTagEditor {
  final byIssue = <String, List<String>>{
    'AU2-5928': ['b'],
  };

  @override
  List<JiraTag> get jiraTags => _tags;

  @override
  List<JiraTag> jiraTagsFor(String issueKey) =>
      AppSettings(jiraTags: _tags, jiraTagsByIssue: byIssue).tagsFor(issueKey);

  @override
  Future<void> setJiraTagsFor(String issueKey, List<String> tagIds) async {
    if (tagIds.isEmpty) {
      byIssue.remove(issueKey);
    } else {
      byIssue[issueKey] = tagIds;
    }
  }
}

/// Jira with two versions and two issues; records searches, and fails the
/// test if anything tries to change Jira.
class _FakeJiraService extends JiraApiService {
  final searchedJql = <String>[];
  String? rejectWith;

  @override
  Future<List<JiraVersion>> fetchVersions(String projectKey) async => const [
    JiraVersion(id: '29207', name: 'au2office 2.41.2', released: true),
    JiraVersion(id: '29501', name: 'au2office 2.41.3'),
  ];

  @override
  Future<List<JiraIssue>> searchIssues(String jql) async {
    searchedJql.add(jql);
    if (rejectWith != null) throw JiraApiException(400, rejectWith!);
    return [
      JiraIssue(
        key: 'AU2-5928',
        summary: 'Værksted kontakt',
        status: 'Review',
        statusCategory: 'indeterminate',
        issueType: 'Story',
        assignee: 'Jane Doe',
        priority: 'Medium',
        updated: DateTime.utc(2026, 10, 1, 12),
      ),
      const JiraIssue(key: 'AU2-5905', summary: 'Konto', status: 'Open'),
    ];
  }

  @override
  Future<void> transitionIssue(String key, String transitionId) async =>
      fail('changed the status of $key in Jira');

  @override
  Future<void> assignIssue(String key, String userName) async =>
      fail('assigned $key in Jira');
}

/// Records the most recent call and synthesizes a result. Throws
/// [RepoNotFoundException] for any repo not in [knownRepos].
class _FakeWorktreeCreator implements WorktreeCreator {
  Map<String, dynamic>? lastCall;
  Set<String> knownRepos = {'demo'};

  @override
  Future<CreatedWorktree> createWorktree({
    required String repoName,
    required String worktreeName,
    required String baseBranch,
    required String newBranch,
    String? jiraIssue,
    String? kickoffPrompt,
  }) async {
    lastCall = {
      'repoName': repoName,
      'worktreeName': worktreeName,
      'baseBranch': baseBranch,
      'newBranch': newBranch,
      'jiraIssue': jiraIssue,
      'kickoffPrompt': kickoffPrompt,
    };
    if (!knownRepos.contains(repoName)) {
      throw RepoNotFoundException(repoName);
    }
    return CreatedWorktree(
      worktreePath: '/repos/$worktreeName',
      branch: newBranch,
      kickoffPromptPath: kickoffPrompt == null
          ? null
          : '/repos/$worktreeName/.tree-launcher/kickoff-prompt.md',
    );
  }
}

/// Lists one worktree for the repo at `/repos/au2`; fails for any other.
class _FakeWorktreeGit extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async {
    if (repoPath != '/repos/au2') throw Exception('not a repo: $repoPath');
    return WorktreeListResult(
      worktrees: [
        Worktree(
          path: '/repos/au2-5953',
          branch: 'sen/au2-5953',
          name: 'au2-5953',
          isMain: false,
          commitHash: 'abc1234',
        ),
      ],
      isBareLayout: true,
    );
  }
}

/// The Activity timeline over real stores in [db] and Claude transcripts
/// under [home].
ActivityService _activityService(
  AppDatabase db,
  Directory home,
  ManualPostStore posts,
) => ActivityService(
  eventStore: WorktreeEventStore(db),
  claudeActivity: ClaudeSessionActivity(homeDir: home.path),
  manualPostStore: posts,
);

/// A server on the live app's state in memory: [repos] (or [catalog]),
/// [settings] and the given fakes, and real stores in [db]. Manual posts go
/// through [activity] when given, else an Activity controller of its own.
AgentApiServer _server(
  AppDatabase db,
  Directory home, {
  List<RepoConfig> repos = const [],
  RepoCatalog? catalog,
  AppSettings? settings,
  WorktreeCreator? worktreeCreator,
  JiraTagEditor? jiraTagEditor,
  AgentRegistry? agentRegistry,
  GitService? gitService,
  ManualPostStore? manualPostStore,
  ActivityController? activity,
  JiraApiService? jiraService,
}) {
  final posts = manualPostStore ?? ManualPostStore(db);
  final service = _activityService(db, home, posts);
  final writer =
      activity ??
      ActivityController(
        eventStore: WorktreeEventStore(db),
        manualPostStore: posts,
        service: service,
      );
  if (activity == null) addTearDown(writer.dispose);
  return AgentApiServer(
    repos: catalog ?? _FakeRepos(repos),
    settings: _FakeSettings(settings),
    worktreeCreator: worktreeCreator ?? _FakeWorktreeCreator(),
    jiraTagEditor: jiraTagEditor ?? _FakeTagEditor(),
    agentRegistry: agentRegistry ?? _NoAgents(),
    activity: service,
    manualPosts: writer,
    gitService: gitService ?? GitService(),
    jiraService: jiraService,
  );
}

void main() {
  late AppDatabase db;
  late Directory tempHome;
  late AgentApiServer server;
  late _FakeWorktreeCreator creator;

  setUp(() async {
    db = testDatabase();
    tempHome = await Directory.systemTemp.createTemp('agent_api_home');
    creator = _FakeWorktreeCreator();
    server = _server(
      db,
      tempHome,
      settings: AppSettings(defaultBranchPrefix: 'feature'),
      worktreeCreator: creator,
    );
    // Port 0 → OS picks a free loopback port.
    await server.start(port: 0);
  });

  tearDown(() async {
    await server.stop();
    if (await tempHome.exists()) await tempHome.delete(recursive: true);
  });

  Future<(int, Map<String, dynamic>)> get(String path, {int? port}) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:${port ?? server.port}$path'),
      );
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return (res.statusCode, jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  Future<(int, Map<String, dynamic>)> post(
    String path,
    Object body, {
    int? port,
    String method = 'POST',
  }) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:${port ?? server.port}$path'),
      );
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close();
      final respBody = await res.transform(utf8.decoder).join();
      return (res.statusCode, jsonDecode(respBody) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  test('binds to a loopback port and reports running', () {
    expect(server.isRunning, isTrue);
    expect(server.port, isNotNull);
  });

  test('GET /health returns ok', () async {
    final (status, body) = await get('/health');
    expect(status, 200);
    expect(body['status'], 'ok');
    expect(body['service'], 'tree_launcher');
    expect(body['version'], 1);
  });

  test('GET /v1/activity with no repos returns an empty list', () async {
    final (status, body) = await get('/v1/activity');
    expect(status, 200);
    expect(body['filter'], 'all');
    expect(body['count'], 0);
    expect(body['entries'], isEmpty);
  });

  test('GET /v1/activity rejects an unknown filter with 400', () async {
    final (status, body) = await get('/v1/activity?filter=lastDecade');
    expect(status, 400);
    expect(body['error'], contains('unknown filter'));
  });

  group('requests a web page could send', () {
    const worktree = {
      'repo': 'demo',
      'baseBranch': 'main',
      'branch': 'my-feature',
      'worktreeName': 'my-feature',
    };

    /// Sends [method] [path] with [host] and [contentType] in place of what
    /// HttpClient would send (no Content-Type when null), and returns the
    /// status.
    Future<int> send(
      String method,
      String path, {
      String? host,
      String? contentType,
      Object? body,
    }) async {
      final client = HttpClient();
      try {
        final req = await client.openUrl(
          method,
          Uri.parse('http://127.0.0.1:${server.port}$path'),
        );
        if (host != null) req.headers.set(HttpHeaders.hostHeader, host);
        if (contentType != null) {
          req.headers.set(HttpHeaders.contentTypeHeader, contentType);
        }
        if (body != null) req.add(utf8.encode(jsonEncode(body)));
        final res = await req.close();
        await res.drain<void>();
        return res.statusCode;
      } finally {
        client.close(force: true);
      }
    }

    test('accepts localhost as the Host', () async {
      expect(
        await send('GET', '/health', host: 'localhost:${server.port}'),
        200,
      );
    });

    test('refuses any other Host with 403', () async {
      // DNS rebinding: the page's own name, resolving to 127.0.0.1.
      expect(
        await send('GET', '/health', host: 'evil.example:${server.port}'),
        403,
      );
      expect(await send('GET', '/v1/activity', host: '127.0.0.1:1'), 403);
      expect(
        await send(
          'POST',
          '/v1/worktrees',
          host: 'evil.example:${server.port}',
          contentType: 'application/json',
          body: worktree,
        ),
        403,
      );
      expect(creator.lastCall, isNull);
    });

    test('refuses a request without a Host with 403', () async {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port!,
      );
      socket.write('GET /health HTTP/1.0\r\n\r\n');
      final response = await utf8.decoder.bind(socket).join();
      socket.destroy();
      expect(response.split('\r\n').first, contains(' 403 '));
    });

    test('refuses a POST that is not JSON with 415', () async {
      // What a cross-site form or fetch() can send without a preflight.
      expect(
        await send(
          'POST',
          '/v1/worktrees',
          contentType: 'text/plain',
          body: worktree,
        ),
        415,
      );
      expect(await send('POST', '/v1/worktrees', body: worktree), 415);
      expect(
        await send(
          'POST',
          '/v1/worktrees',
          contentType: 'application/x-www-form-urlencoded',
          body: worktree,
        ),
        415,
      );
      expect(creator.lastCall, isNull);
    });

    test('refuses a PUT that is not JSON with 415', () async {
      expect(
        await send(
          'PUT',
          '/v1/jira/issues/AU2-1/tags',
          contentType: 'text/plain',
          body: {'tags': <String>[]},
        ),
        415,
      );
    });

    test('accepts JSON with a charset', () async {
      expect(
        await send(
          'POST',
          '/v1/worktrees',
          contentType: 'Application/JSON; charset=utf-8',
          body: worktree,
        ),
        201,
      );
      expect(creator.lastCall, isNotNull);
    });
  });

  group('POST /v1/worktrees', () {
    Map<String, dynamic> validBody() => {
      'repo': 'demo',
      'baseBranch': 'main',
      'branch': 'my-feature',
      'worktreeName': 'my-feature',
      'issueKey': 'AU2-1234',
    };

    test('rejects missing required fields with 400', () async {
      final (status, body) = await post('/v1/worktrees', {'repo': 'demo'});
      expect(status, 400);
      expect(body['error'], contains('missing required field'));
      expect(body['error'], contains('baseBranch'));
      expect(body['error'], contains('branch'));
      expect(body['error'], contains('worktreeName'));
    });

    test('rejects an invalid worktree name with 400', () async {
      final (status, body) = await post('/v1/worktrees', {
        ...validBody(),
        'worktreeName': 'has/slash',
      });
      expect(status, 400);
      expect(body['error'], startsWith('worktreeName:'));
    });

    test('rejects an invalid issue key with 400', () async {
      final (status, body) = await post('/v1/worktrees', {
        ...validBody(),
        'issueKey': 'not-a-key',
      });
      expect(status, 400);
      expect(body['error'], startsWith('issueKey:'));
    });

    test('returns 404 when the repo is unknown', () async {
      final (status, body) = await post('/v1/worktrees', {
        ...validBody(),
        'repo': 'missing',
      });
      expect(status, 404);
      expect(body['error'], contains('missing'));
    });

    test('creates a worktree, applying the branch prefix', () async {
      final (status, body) = await post('/v1/worktrees', validBody());
      expect(status, 201);
      expect(body['repo'], 'demo');
      expect(body['worktreeName'], 'my-feature');
      expect(body['worktreePath'], '/repos/my-feature');
      // defaultBranchPrefix 'feature' is applied to the supplied suffix.
      expect(body['branch'], 'feature/my-feature');
      expect(body.containsKey('slot'), isFalse);
      expect(body['issueKey'], 'AU2-1234');
      expect(creator.lastCall!['newBranch'], 'feature/my-feature');
      expect(creator.lastCall!['jiraIssue'], 'AU2-1234');
      // No kickoff prompt supplied → the creator sees null and the response
      // carries a null path.
      expect(creator.lastCall!['kickoffPrompt'], isNull);
      expect(body['kickoffPromptPath'], isNull);
    });

    test('forwards a kickoff prompt and returns its file path', () async {
      final (status, body) = await post('/v1/worktrees', {
        ...validBody(),
        'kickoffPrompt': '# Plan\n\nStep 1\nStep 2',
      });
      expect(status, 201);
      expect(creator.lastCall!['kickoffPrompt'], '# Plan\n\nStep 1\nStep 2');
      expect(
        body['kickoffPromptPath'],
        '/repos/my-feature/.tree-launcher/kickoff-prompt.md',
      );
    });

    test('normalizes worktree name and branch suffix', () async {
      final (status, body) = await post('/v1/worktrees', {
        'repo': 'demo',
        'baseBranch': 'main',
        'branch': 'My Feature',
        'worktreeName': 'My Feature',
      });
      expect(status, 201);
      expect(body['worktreeName'], 'my-feature');
      expect(body['branch'], 'feature/my-feature');
    });
  });

  group('POST /v1/activity', () {
    late ManualPostStore manualStore;
    late AgentApiServer s;
    final demo = RepoConfig(
      name: 'demo',
      path: '/repos/demo',
      predefinedIssues: [
        PredefinedIssue(key: 'AU2-9', description: 'Code review'),
      ],
    );

    setUp(() async {
      manualStore = ManualPostStore(db);
      s = _server(db, tempHome, repos: [demo], manualPostStore: manualStore);
      await s.start(port: 0);
      addTearDown(() => s.stop());
    });

    test('waits for the app to load its repos', () async {
      final loaded = Completer<void>();
      final catalog = _FakeRepos(const [], loaded: loaded.future);
      final early = _server(db, tempHome, catalog: catalog);
      await early.start(port: 0);
      addTearDown(early.stop);

      final response = post('/v1/activity', {
        'repo': 'demo',
        'issueKey': 'AU2-9',
      }, port: early.port);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      catalog.repos = [demo];
      loaded.complete();

      expect((await response).$1, 201);
    });

    test('rejects missing required fields with 400', () async {
      final (status, body) = await post('/v1/activity', {
        'hours': 2,
      }, port: s.port);
      expect(status, 400);
      expect(body['error'], contains('missing required field'));
      expect(body['error'], contains('repo'));
      expect(body['error'], contains('issueKey'));
    });

    test('rejects an invalid issue key with 400', () async {
      final (status, body) = await post('/v1/activity', {
        'repo': 'demo',
        'issueKey': 'not-a-key',
      }, port: s.port);
      expect(status, 400);
      expect(body['error'], startsWith('issueKey:'));
    });

    test('rejects a non-numeric hours with 400', () async {
      final (status, body) = await post('/v1/activity', {
        'repo': 'demo',
        'issueKey': 'AU2-9',
        'hours': 'lots',
      }, port: s.port);
      expect(status, 400);
      expect(body['error'], contains('hours'));
    });

    test('returns 404 when the repo is unknown', () async {
      final (status, body) = await post('/v1/activity', {
        'repo': 'missing',
        'issueKey': 'AU2-9',
      }, port: s.port);
      expect(status, 404);
      expect(body['error'], contains('missing'));
    });

    test('logs a post, filling description from a predefined issue', () async {
      final (status, body) = await post('/v1/activity', {
        'repo': 'demo',
        'issueKey': 'AU2-9',
        'hours': 2.5,
      }, port: s.port);
      expect(status, 201);
      expect(body['repoName'], 'demo');
      expect(body['issueKey'], 'AU2-9');
      expect(body['description'], 'Code review');
      expect(body['hours'], 2.5);
      expect(body['id'], isNotEmpty);

      // The post is persisted and surfaces in the timeline as a manual entry.
      expect((await manualStore.loadAll()).single.issueKey, 'AU2-9');
      final (gStatus, gBody) = await get(
        '/v1/activity?repo=demo',
        port: s.port,
      );
      expect(gStatus, 200);
      final entries = gBody['entries'] as List;
      expect(entries, hasLength(1));
      expect(entries.single['kind'], 'manual');
      expect(entries.single['hours'], 2.5);
      expect(entries.single['jiraIssue'], 'AU2-9');
    });

    test('shows a logged post in the open Activity tab at once', () async {
      final activity = ActivityController(
        eventStore: WorktreeEventStore(db),
        manualPostStore: manualStore,
        service: _activityService(db, tempHome, manualStore),
      );
      addTearDown(activity.dispose);
      // The tab was opened: its timeline is loaded, and empty.
      await activity.load();
      expect(activity.entries, isEmpty);
      final live = _server(
        db,
        tempHome,
        repos: [demo],
        manualPostStore: manualStore,
        activity: activity,
      );
      await live.start(port: 0);
      addTearDown(live.stop);

      final (status, _) = await post('/v1/activity', {
        'repo': 'demo',
        'issueKey': 'AU2-9',
      }, port: live.port);

      expect(status, 201);
      expect(activity.entries.single.jiraIssue, 'AU2-9');
    });

    test('keeps an explicit description over the predefined one', () async {
      final (status, body) = await post('/v1/activity', {
        'repo': 'demo',
        'issueKey': 'AU2-9',
        'description': 'Pairing session',
      }, port: s.port);
      expect(status, 201);
      expect(body['description'], 'Pairing session');
    });
  });

  group('Jira', () {
    late AgentApiServer jiraServer;
    late _FakeJiraService jira;
    late _FakeTagEditor editor;

    setUp(() async {
      jira = _FakeJiraService();
      editor = _FakeTagEditor();
      jiraServer = _server(
        db,
        tempHome,
        repos: [
          RepoConfig(
            name: 'au2office',
            path: '/repos/au2',
            jiraProjectKey: 'AU2',
          ),
          RepoConfig(name: 'nojira', path: '/repos/nojira'),
        ],
        jiraTagEditor: editor,
        jiraService: jira,
      );
      await jiraServer.start(port: 0);
    });

    tearDown(() async {
      await jiraServer.stop();
    });

    Future<(int, Map<String, dynamic>)> getJira(String path) =>
        get(path, port: jiraServer.port);

    Future<(int, Map<String, dynamic>)> putTags(String key, Object body) =>
        post(
          '/v1/jira/issues/$key/tags',
          body,
          port: jiraServer.port,
          method: 'PUT',
        );

    group('GET /v1/jira/issues', () {
      test('lists a fixVersion by name with each issue\'s tags', () async {
        final (status, body) = await getJira(
          '/v1/jira/issues?repo=au2office&fixVersion=AU2OFFICE%202.41.3',
        );

        expect(status, 200);
        expect(body['project'], 'AU2');
        expect(body['fixVersion'], {
          'id': '29501',
          'name': 'au2office 2.41.3',
          'released': false,
        });
        expect(jira.searchedJql.single, contains('fixVersion = 29501'));
        expect(body['count'], 2);
        final issues = (body['issues'] as List).cast<Map<String, dynamic>>();
        expect(issues.first, {
          'key': 'AU2-5928',
          'summary': 'Værksted kontakt',
          'status': 'Review',
          'statusCategory': 'indeterminate',
          'issueType': 'Story',
          'assignee': 'Jane Doe',
          'priority': 'Medium',
          'updated': '2026-10-01T12:00:00.000Z',
          'url': 'https://jira.elbek-vejrup.dk/browse/AU2-5928',
          'tags': ['Blocked'],
        });
        expect(issues.last['tags'], isEmpty);
      });

      test('filters by statuses, repeated or comma-separated', () async {
        final (status, body) = await getJira(
          '/v1/jira/issues?project=au2&status=Review,In%20Progress&status=Open',
        );

        expect(status, 200);
        expect(body['fixVersion'], isNull);
        expect(body['statuses'], ['Review', 'In Progress', 'Open']);
        expect(
          jira.searchedJql.single,
          'project = "AU2" AND status in ("Review", "In Progress", "Open") '
          'AND issuetype not in subTaskIssueTypes() ORDER BY Rank ASC',
        );
      });

      test('rejects a request without fixVersion or status', () async {
        final (status, _) = await getJira('/v1/jira/issues?repo=au2office');
        expect(status, 400);
      });

      test('needs a repo with a Jira project, or a project', () async {
        expect((await getJira('/v1/jira/issues?status=Open')).$1, 400);
        expect(
          (await getJira('/v1/jira/issues?repo=nope&status=Open')).$1,
          404,
        );
        expect(
          (await getJira('/v1/jira/issues?repo=nojira&status=Open')).$1,
          400,
        );
      });

      test('lists the fixVersions when the one asked for is unknown', () async {
        final (status, body) = await getJira(
          '/v1/jira/issues?repo=au2office&fixVersion=2.99',
        );

        expect(status, 404);
        expect(body['fixVersions'], ['au2office 2.41.3', 'au2office 2.41.2']);
        expect(jira.searchedJql, isEmpty);
      });

      test("passes on Jira's reason for a rejected search", () async {
        jira.rejectWith =
            "Jira rejected the request: The value 'Nope' does not exist for "
            "the field 'status'.";

        final (status, body) = await getJira(
          '/v1/jira/issues?repo=au2office&status=Nope',
        );

        expect(status, 400);
        expect(body['error'], contains("The value 'Nope' does not exist"));
      });
    });

    test('GET /v1/jira/tags lists the tags', () async {
      final (status, body) = await getJira('/v1/jira/tags');

      expect(status, 200);
      expect(body['tags'], [
        {'name': 'Blocked', 'color': 'red'},
        {'name': 'Demo', 'color': 'blue'},
      ]);
    });

    group('PUT /v1/jira/issues/<key>/tags', () {
      test('replaces the tags by name in the live app', () async {
        final (status, body) = await putTags('au2-5905', {
          'tags': ['demo', 'BLOCKED', 'Demo'],
        });

        expect(status, 200);
        expect(body, {
          'key': 'AU2-5905',
          'tags': ['Blocked', 'Demo'],
        });
        expect(editor.byIssue['AU2-5905'], ['d', 'b']);

        final (_, cleared) = await putTags('AU2-5928', {'tags': []});
        expect(cleared['tags'], isEmpty);
        expect(editor.byIssue.containsKey('AU2-5928'), isFalse);
      });

      test('rejects unknown tags, listing the known ones', () async {
        final (status, body) = await putTags('AU2-5905', {
          'tags': ['Blocked', 'Urgent'],
        });

        expect(status, 400);
        expect(body['error'], 'unknown tag(s): Urgent');
        expect(body['tags'], ['Blocked', 'Demo']);
        expect(editor.byIssue.containsKey('AU2-5905'), isFalse);
      });

      test('changes nothing but tags', () async {
        final (status, body) = await putTags('AU2-5905', {
          'tags': ['Blocked'],
          'status': 'Done',
        });

        expect(status, 400);
        expect(body['error'], contains('only local tags can be set'));
        expect(editor.byIssue.containsKey('AU2-5905'), isFalse);
      });

      test('rejects a bad key or body', () async {
        expect((await putTags('nope', {'tags': []})).$1, 400);
        expect((await putTags('AU2-1', {'tags': 'Blocked'})).$1, 400);
        expect((await putTags('AU2-1', {})).$1, 400);
      });
    });
  });

  group('Agents', () {
    late AgentApiServer agentServer;
    late AgentsController agents;

    setUp(() async {
      agents = AgentsController(store: AgentRunStore(db));
      agentServer = _server(
        db,
        tempHome,
        repos: [
          RepoConfig(name: 'other', path: '/repos/other'),
          RepoConfig(name: 'au2office', path: '/repos/au2'),
        ],
        gitService: _FakeWorktreeGit(),
        agentRegistry: agents,
      );
      await agentServer.start(port: 0);
    });

    tearDown(() async {
      await agentServer.stop();
      await agents.flush();
      agents.dispose();
    });

    Future<(int, Map<String, dynamic>)> getAgents(String path) =>
        get(path, port: agentServer.port);
    Future<(int, Map<String, dynamic>)> postAgents(String path, Object body) =>
        post(path, body, port: agentServer.port);

    Map<String, dynamic> registration() => {
      'kind': 'build',
      'repo': 'au2office',
      'issueKey': 'au2-5953',
      'prompt': 'Factory track: feature',
      'worktreePath': '/repos/au2-5953',
      'branch': 'sen/au2-5953',
      'stages': ['spec', 'plan', 'implement'],
    };

    group('POST /v1/agents', () {
      test('registers a run', () async {
        final (status, body) = await postAgents('/v1/agents', registration());

        expect(status, 201);
        expect(body['id'], startsWith('ag_'));
        expect(body['kind'], 'build');
        expect(body['repo'], 'au2office');
        expect(body['issueKeys'], ['AU2-5953']);
        expect(body['state'], 'starting');
        expect(
          [for (final s in body['stages'] as List) s['name']],
          ['spec', 'plan', 'implement'],
        );
        expect(agents.runById(body['id'] as String), isNotNull);
      });

      test('finds the repo from the worktree', () async {
        final (status, body) = await postAgents('/v1/agents', {
          'kind': 'build',
          'worktreePath': '/repos/au2-5953/',
        });
        expect(status, 201);
        expect(body['repo'], 'au2office');

        final (missing, error) = await postAgents('/v1/agents', {
          'kind': 'build',
          'worktreePath': '/elsewhere',
        });
        expect(missing, 400);
        expect(error['error'], contains('not a worktree of any repo'));
      });

      test('returns the active run it describes again', () async {
        final (_, first) = await postAgents('/v1/agents', registration());
        final (status, again) = await postAgents('/v1/agents', {
          ...registration(),
          'title': 'Oprydning',
        });

        expect(status, 200);
        expect(again['id'], first['id']);
        expect(again['title'], 'Oprydning');
        expect(agents.runs, hasLength(1));
      });

      test('updates the run the app launched, by id', () async {
        final launched = await agents.createForLaunch(
          kind: AgentKind.build,
          repoName: 'au2office',
          promptName: 'Factory track: feature',
        );
        final (status, body) = await postAgents('/v1/agents', {
          'id': launched.id,
          'stages': 'spec, plan',
          'issueKeys': ['AU2-1'],
        });

        expect(status, 200);
        expect(body['id'], launched.id);
        expect(body['prompt'], 'Factory track: feature');
        expect(body['issueKeys'], ['AU2-1']);
        expect(body['stages'], hasLength(2));
      });

      test('rejects bad registrations', () async {
        expect(
          (await postAgents('/v1/agents', {'repo': 'au2office'})).$2['error'],
          contains('kind'),
        );
        expect(
          (await postAgents('/v1/agents', {
            'kind': 'deploy',
            'repo': 'au2office',
          })).$1,
          400,
        );
        expect(
          (await postAgents('/v1/agents', {
            ...registration(),
            'colour': 'red',
          })).$2['error'],
          contains('colour'),
        );
        expect(
          (await postAgents('/v1/agents', {
            ...registration(),
            'issueKey': 'nope',
          })).$1,
          400,
        );
        expect(
          (await postAgents('/v1/agents', {
            ...registration(),
            'repo': 'nope',
          })).$1,
          404,
        );
        expect((await postAgents('/v1/agents', {'id': 'ag_missing'})).$1, 404);
      });
    });

    group('POST /v1/agents/<id>/status', () {
      late String id;

      setUp(() async {
        id =
            (await postAgents('/v1/agents', registration())).$2['id'] as String;
      });

      Future<(int, Map<String, dynamic>)> status(Object body) =>
          postAgents('/v1/agents/$id/status', body);

      test('moves through the stages', () async {
        await status({'stage': 'spec', 'message': 'spec: henter issue'});
        await status({
          'state': 'waiting',
          'message': 'Gate 1: spec klar · 5 AC',
        });
        var run = agents.runById(id)!;
        expect(run.state.name, 'waiting');
        expect(run.stages.first.state.name, 'waiting');
        expect(agents.needsYou(run), isTrue);

        final (code, body) = await status({
          'stage': 'implement',
          'progress': '4/7',
          'message': 'trin 4/7 ✓',
        });
        expect(code, 200);
        expect(body['state'], 'running');
        expect(body['currentStage'], 'implement');
        final stages = body['stages'] as List;
        expect(stages[0]['state'], 'done');
        expect(stages[1]['state'], 'pending');
        expect(stages[2]['state'], 'running');
        expect(stages[2]['progress'], {'done': 4, 'total': 7});

        await status({
          'state': 'done',
          'result': 'PR #7123',
          'links': {'PR': 'https://github.com/x/y/pull/7123'},
        });
        run = agents.runById(id)!;
        expect(run.state.name, 'done');
        expect(run.finishedAt, isNotNull);
        expect(run.stages[2].state.name, 'done');
        expect(run.result, 'PR #7123');
        expect(run.links.single.label, 'PR');

        final (_, detail) = await getAgents('/v1/agents/$id');
        final messages = [
          for (final e in detail['events'] as List) e['message'],
        ];
        expect(messages, containsAll(['spec: henter issue', 'trin 4/7 ✓']));
      });

      test('rejects bad reports', () async {
        expect((await status({})).$1, 400);
        expect(
          (await status({'state': 'waiting'})).$2['error'],
          contains('message'),
        );
        expect((await status({'state': 'starting'})).$1, 400);
        expect(
          (await status({'progress': '1/2'})).$2['error'],
          contains('stage'),
        );
        expect((await status({'stage': 'spec', 'progress': 'half'})).$1, 400);
        expect(
          (await status({
            'links': ['x'],
          })).$1,
          400,
        );
        expect((await status({'mood': 'great'})).$1, 400);
        expect(
          (await postAgents('/v1/agents/ag_missing/status', {
            'state': 'done',
          })).$1,
          404,
        );
      });
    });

    test('GET /v1/agents filters the runs', () async {
      final (_, build) = await postAgents('/v1/agents', registration());
      await postAgents('/v1/agents', {
        'kind': 'verify',
        'repo': 'au2office',
        'issueKey': 'AU2-1',
        'worktreePath': '/repos/develop',
      });
      await postAgents('/v1/agents/${build['id']}/status', {'state': 'done'});

      Future<int> count(String query) async =>
          (await getAgents('/v1/agents$query')).$2['count'] as int;

      expect(await count(''), 2);
      expect(await count('?kind=verify'), 1);
      expect(await count('?active=true'), 1);
      expect(await count('?active=false'), 1);
      expect(await count('?issue=au2-5953'), 1);
      expect(await count('?repo=other'), 0);
      expect((await getAgents('/v1/agents?kind=deploy')).$1, 400);
      expect((await getAgents('/v1/agents/ag_missing')).$1, 404);
    });
  });
}
