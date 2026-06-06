import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/models/repo_config.dart';
import 'package:tree_launcher/services/config_service.dart';

/// A ConfigService that returns a fixed repo list, so RepoConfigStore needs no
/// path_provider plugin in tests.
class _FakeConfigService extends ConfigService {
  _FakeConfigService(this.repos);
  final List<RepoConfig> repos;
  @override
  Future<List<RepoConfig>> loadRepos() async => repos;
}

void main() {
  late Directory tempDir;
  late Directory tempHome;
  late AgentApiServer server;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agent_api_events');
    tempHome = await Directory.systemTemp.createTemp('agent_api_home');
    server = AgentApiServer(
      repoConfigStore: RepoConfigStore(
        configService: _FakeConfigService(const []),
      ),
      gitService: GitService(),
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
}
