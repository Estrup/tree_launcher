import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag_editor.dart';
import 'package:tree_launcher/features/jira/domain/jira_version.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/models/jira_tag.dart';
import 'package:tree_launcher/models/predefined_issue.dart';
import 'package:tree_launcher/models/repo_config.dart';
import 'package:tree_launcher/services/config_service.dart';

/// A ConfigService that returns a fixed repo list and settings, so the stores
/// need no path_provider plugin in tests.
class _FakeConfigService extends ConfigService {
  _FakeConfigService(this.repos, {this.settings});
  final List<RepoConfig> repos;
  AppSettings? settings;
  @override
  Future<List<RepoConfig>> loadRepos() async => repos;
  @override
  Future<AppSettings> loadSettings() async => settings ?? AppSettings();
  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }
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
    if (rejectWith != null) throw Exception(rejectWith);
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

void main() {
  late Directory tempDir;
  late Directory tempHome;
  late AgentApiServer server;
  late _FakeWorktreeCreator creator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agent_api_events');
    tempHome = await Directory.systemTemp.createTemp('agent_api_home');
    creator = _FakeWorktreeCreator();
    server = AgentApiServer(
      repoConfigStore: RepoConfigStore(
        configService: _FakeConfigService(const []),
      ),
      gitService: GitService(),
      appSettingsStore: AppSettingsStore(
        configService: _FakeConfigService(
          const [],
          settings: AppSettings(defaultBranchPrefix: 'feature'),
        ),
      ),
      eventStore: WorktreeEventStore(directoryPath: tempDir.path),
      claudeActivity: ClaudeSessionActivity(homeDir: tempHome.path),
    );
    // Port 0 → OS picks a free loopback port.
    await server.start(port: 0);
  });

  tearDown(() async {
    await server.stop();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
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

  group('POST /v1/worktrees', () {
    Map<String, dynamic> validBody() => {
      'repo': 'demo',
      'baseBranch': 'main',
      'branch': 'my-feature',
      'worktreeName': 'my-feature',
      'issueKey': 'AU2-1234',
    };

    test('returns 503 before a creator is registered', () async {
      final (status, body) = await post('/v1/worktrees', validBody());
      expect(status, 503);
      expect(body['error'], 'app not ready');
    });

    test('rejects missing required fields with 400', () async {
      server.registerWorktreeCreator(creator);
      final (status, body) = await post('/v1/worktrees', {'repo': 'demo'});
      expect(status, 400);
      expect(body['error'], contains('missing required field'));
      expect(body['error'], contains('baseBranch'));
      expect(body['error'], contains('branch'));
      expect(body['error'], contains('worktreeName'));
    });

    test('rejects an invalid worktree name with 400', () async {
      server.registerWorktreeCreator(creator);
      final (status, body) = await post('/v1/worktrees', {
        ...validBody(),
        'worktreeName': 'has/slash',
      });
      expect(status, 400);
      expect(body['error'], startsWith('worktreeName:'));
    });

    test('rejects an invalid issue key with 400', () async {
      server.registerWorktreeCreator(creator);
      final (status, body) = await post('/v1/worktrees', {
        ...validBody(),
        'issueKey': 'not-a-key',
      });
      expect(status, 400);
      expect(body['error'], startsWith('issueKey:'));
    });

    test('returns 404 when the repo is unknown', () async {
      server.registerWorktreeCreator(creator);
      final (status, body) = await post('/v1/worktrees', {
        ...validBody(),
        'repo': 'missing',
      });
      expect(status, 404);
      expect(body['error'], contains('missing'));
    });

    test('creates a worktree, applying the branch prefix', () async {
      server.registerWorktreeCreator(creator);
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
      server.registerWorktreeCreator(creator);
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
      server.registerWorktreeCreator(creator);
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

    setUp(() async {
      manualStore = ManualPostStore(directoryPath: tempDir.path);
      s = AgentApiServer(
        repoConfigStore: RepoConfigStore(
          configService: _FakeConfigService([
            RepoConfig(
              name: 'demo',
              path: '/repos/demo',
              predefinedIssues: [
                PredefinedIssue(key: 'AU2-9', description: 'Code review'),
              ],
            ),
          ]),
        ),
        gitService: GitService(),
        appSettingsStore: AppSettingsStore(
          configService: _FakeConfigService(const []),
        ),
        eventStore: WorktreeEventStore(directoryPath: tempDir.path),
        claudeActivity: ClaudeSessionActivity(homeDir: tempHome.path),
        manualPostStore: manualStore,
      );
      await s.start(port: 0);
      addTearDown(() => s.stop());
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
      final config = _FakeConfigService(
        [
          RepoConfig(
            name: 'au2office',
            path: '/repos/au2',
            jiraProjectKey: 'AU2',
          ),
          RepoConfig(name: 'nojira', path: '/repos/nojira'),
        ],
        // What the app last saved, read before it registers its editor.
        settings: AppSettings(
          jiraTags: _tags,
          jiraTagsByIssue: const {
            'AU2-5928': ['b'],
          },
        ),
      );
      jiraServer = AgentApiServer(
        repoConfigStore: RepoConfigStore(configService: config),
        gitService: GitService(),
        appSettingsStore: AppSettingsStore(configService: config),
        eventStore: WorktreeEventStore(directoryPath: tempDir.path),
        claudeActivity: ClaudeSessionActivity(homeDir: tempHome.path),
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
        jiraServer.registerJiraTagEditor(editor);

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

      test('reads tags from the saved settings before the app is up', () async {
        final (_, body) = await getJira(
          '/v1/jira/issues?repo=au2office&status=Review',
        );

        expect((body['issues'] as List).first['tags'], ['Blocked']);
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
      test('returns 503 before the app is up', () async {
        final (status, _) = await putTags('AU2-5905', {'tags': []});
        expect(status, 503);
      });

      test('replaces the tags by name in the live app', () async {
        jiraServer.registerJiraTagEditor(editor);

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
        jiraServer.registerJiraTagEditor(editor);

        final (status, body) = await putTags('AU2-5905', {
          'tags': ['Blocked', 'Urgent'],
        });

        expect(status, 400);
        expect(body['error'], 'unknown tag(s): Urgent');
        expect(body['tags'], ['Blocked', 'Demo']);
        expect(editor.byIssue.containsKey('AU2-5905'), isFalse);
      });

      test('changes nothing but tags', () async {
        jiraServer.registerJiraTagEditor(editor);

        final (status, body) = await putTags('AU2-5905', {
          'tags': ['Blocked'],
          'status': 'Done',
        });

        expect(status, 400);
        expect(body['error'], contains('only local tags can be set'));
        expect(editor.byIssue.containsKey('AU2-5905'), isFalse);
      });

      test('rejects a bad key or body', () async {
        jiraServer.registerJiraTagEditor(editor);

        expect((await putTags('nope', {'tags': []})).$1, 400);
        expect((await putTags('AU2-1', {'tags': 'Blocked'})).$1, 400);
        expect((await putTags('AU2-1', {})).$1, 400);
      });
    });
  });
}
