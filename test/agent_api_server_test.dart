import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/models/repo_config.dart';
import 'package:tree_launcher/services/config_service.dart';

/// A ConfigService that returns a fixed repo list and settings, so the stores
/// need no path_provider plugin in tests.
class _FakeConfigService extends ConfigService {
  _FakeConfigService(this.repos, {this.settings});
  final List<RepoConfig> repos;
  final AppSettings? settings;
  @override
  Future<List<RepoConfig>> loadRepos() async => repos;
  @override
  Future<AppSettings> loadSettings() async => settings ?? AppSettings();
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
  }) async {
    lastCall = {
      'repoName': repoName,
      'worktreeName': worktreeName,
      'baseBranch': baseBranch,
      'newBranch': newBranch,
      'jiraIssue': jiraIssue,
    };
    if (!knownRepos.contains(repoName)) {
      throw RepoNotFoundException(repoName);
    }
    return CreatedWorktree(
      worktreePath: '/repos/$worktreeName',
      branch: newBranch,
      slot: 'alpha',
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

  Future<(int, Map<String, dynamic>)> get(String path) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}$path'),
      );
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return (res.statusCode, jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  Future<(int, Map<String, dynamic>)> post(String path, Object body) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}$path'),
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
      expect(body['slot'], 'alpha');
      expect(body['issueKey'], 'AU2-1234');
      expect(creator.lastCall!['newBranch'], 'feature/my-feature');
      expect(creator.lastCall!['jiraIssue'], 'AU2-1234');
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
}
