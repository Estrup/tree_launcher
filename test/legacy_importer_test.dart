import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/legacy_importer.dart';
import 'package:tree_launcher/features/activity/data/activity_legacy_import.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';
import 'package:tree_launcher/features/agents/data/agent_run_legacy_import.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/github_issues/data/github_issue_cache.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/models/manual_post.dart';

import 'test_database.dart';

void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('legacy_importer_test');
    db = testDatabase();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> importAll() => LegacyImporter(db, dir.path, [
    AgentRunsLegacyImport(db),
    AgentEventsLegacyImport(db),
    WorktreeEventsLegacyImport(db),
    ManualPostsLegacyImport(db),
    JiraIssueCache.legacyImport(db),
    GithubIssueCache.legacyImport(db),
  ]).run();

  File file(String name) => File(p.join(dir.path, name));

  Future<void> write(String name, String content) =>
      file(name).writeAsString(content);

  String lines(List<Object> records) =>
      records.map((r) => r is String ? r : jsonEncode(r)).join('\n');

  AgentRun run(String id, {DateTime? updatedAt, String title = 'Build'}) =>
      AgentRun(
        id: id,
        kind: AgentKind.build,
        repoName: 'au2office',
        title: title,
        issueKeys: const ['AU2-2', 'AU2-1'],
        stages: const [
          AgentStage(name: 'plan', state: AgentStageState.done),
          AgentStage(
            name: 'implement',
            state: AgentStageState.running,
            progressDone: 4,
            progressTotal: 7,
          ),
        ],
        currentStage: 'implement',
        state: AgentState.running,
        summary: 'step 4',
        links: const [AgentLink(label: 'PR', target: 'https://x/pr/1')],
        model: 'opus',
        startedAt: DateTime(2026, 10, 1, 9, 0, 0, 123, 456),
        updatedAt: updatedAt ?? DateTime(2026, 10, 1, 10),
      );

  AgentEvent event(String runId, String message, {int minute = 0}) =>
      AgentEvent(
        agentId: runId,
        at: DateTime(2026, 10, 1, 10, minute),
        message: message,
        stage: 'implement',
        level: AgentEventLevel.success,
      );

  WorktreeEvent worktreeEvent(WorktreeEventType type, {int hour = 9}) =>
      WorktreeEvent(
        timestamp: DateTime(2026, 6, 3, hour),
        type: type,
        repoPath: '/repo',
        repoName: 'repo',
        worktreePath: '/repo/wt',
        worktreeName: 'wt',
        branch: 'feature/x',
        jiraIssue: 'AU2-1',
      );

  ManualPost post(String id, {double? hours}) => ManualPost(
    id: id,
    timestamp: DateTime(2026, 6, 9, 10),
    repoName: 'demo',
    issueKey: 'AU2-9',
    description: 'desc $id',
    hours: hours,
  );

  Map<String, dynamic> cacheEntry(Map<String, dynamic> issue, String at) => {
    'issue': issue,
    'fetchedAt': at,
  };

  group('imports each file once and keeps it as *.migrated', () {
    setUp(() async {
      await write(
        'agent_runs.json',
        jsonEncode({
          'runs': [
            run('ag_one').toJson(),
            {'id': 'broken'},
            run('ag_two', title: 'Verify').toJson(),
          ],
        }),
      );
      await write(
        'agent_events.jsonl',
        lines([
          event('ag_one', 'started').toJson(),
          'not-json',
          event('ag_gone', 'of a run that no longer exists').toJson(),
          event('ag_two', 'done', minute: 5).toJson(),
        ]),
      );
      await write(
        'worktree_events.jsonl',
        lines([
          worktreeEvent(WorktreeEventType.created).toJson(),
          '{"timestamp": "2026-06-03T1',
          worktreeEvent(WorktreeEventType.closed, hour: 17).toJson(),
        ]),
      );
      await write(
        'manual_posts.jsonl',
        lines([
          post('a').toJson(),
          post('b', hours: 2).toJson(),
          {'kind': 'delete', 'id': 'a'},
          post('c').toJson(),
        ]),
      );
      await write(
        'jira_issue_cache.json',
        jsonEncode({
          'AU2-1': cacheEntry(
            const JiraIssue(key: 'AU2-1', summary: 'One').toJson(),
            '2026-10-19T12:00:00.000Z',
          ),
          'AU2-2': {
            'issue': const JiraIssue(key: 'AU2-2', summary: 'Two').toJson(),
          },
        }),
      );
      await write(
        'github_issue_cache.json',
        jsonEncode({
          'acme/app#482': cacheEntry(
            const GithubIssue(
              number: 482,
              title: 'Login redirect loops',
              state: GithubIssueState.open,
              htmlUrl: 'https://github.com/acme/app/issues/482',
            ).toJson(),
            '2026-10-19T12:00:00.000Z',
          ),
        }),
      );
      await importAll();
    });

    test('agent runs, with their details and issue order', () async {
      final runs = await AgentRunStore(db).loadRuns();
      expect(runs.map((r) => r.id), ['ag_one', 'ag_two']);
      expect(
        jsonEncode(runs.first.toJson()),
        jsonEncode(run('ag_one').toJson()),
      );
      expect(runs.first.issueKeys, ['AU2-2', 'AU2-1']);
      expect(runs.first.activeStage?.progressDone, 4);
      expect(runs.first.links.single.target, 'https://x/pr/1');
      expect(runs.first.startedAt, DateTime(2026, 10, 1, 9, 0, 0, 123, 456));
    });

    test('agent events of known runs, skipping malformed lines', () async {
      final events = await AgentRunStore(db).loadEvents();
      expect(events.map((e) => (e.agentId, e.message)), [
        ('ag_one', 'started'),
        ('ag_two', 'done'),
      ]);
      expect(events.first.level, AgentEventLevel.success);
      expect(events.first.stage, 'implement');
    });

    test('worktree events in order, skipping a torn line', () async {
      final events = await WorktreeEventStore(db).loadAll();
      expect(events.map((e) => e.type), [
        WorktreeEventType.created,
        WorktreeEventType.closed,
      ]);
      expect(events.first.jiraIssue, 'AU2-1');
      expect(events.first.timestamp, DateTime(2026, 6, 3, 9));
    });

    test('manual posts with the tombstones applied', () async {
      final posts = await ManualPostStore(db).loadAll();
      expect(posts.map((p) => p.id), ['b', 'c']);
      expect(posts.first.hours, 2);
    });

    test('cached issues that have a fetch time', () async {
      final jira = JiraIssueCache(db);
      final cached = await jira.read('AU2-1');
      expect(cached!.issue.summary, 'One');
      expect(cached.fetchedAt, DateTime.utc(2026, 10, 19, 12));
      expect(await jira.read('AU2-2'), isNull);

      final github = await GithubIssueCache(db).read('acme/app#482');
      expect(github!.issue.title, 'Login redirect loops');
    });

    test('renames every file to *.migrated', () async {
      for (final name in [
        'agent_runs.json',
        'agent_events.jsonl',
        'worktree_events.jsonl',
        'manual_posts.jsonl',
        'jira_issue_cache.json',
        'github_issue_cache.json',
      ]) {
        expect(await file(name).exists(), isFalse, reason: name);
        expect(await file('$name.migrated').exists(), isTrue, reason: name);
      }
    });
  });

  group('merges a file that reappears (written by an older build)', () {
    test('adds only new log lines and keeps the first *.migrated', () async {
      final first = worktreeEvent(WorktreeEventType.created).toJson();
      final second = worktreeEvent(WorktreeEventType.closed, hour: 17);
      await write('worktree_events.jsonl', lines([first]));
      await importAll();
      await write('worktree_events.jsonl', lines([first, second.toJson()]));
      await importAll();

      final events = await WorktreeEventStore(db).loadAll();
      expect(events, hasLength(2));
      expect(events.last.type, WorktreeEventType.closed);
      expect(
        await file('worktree_events.jsonl.migrated').readAsString(),
        lines([first]),
      );
      final kept = dir
          .listSync()
          .map((e) => p.basename(e.path))
          .where((n) => n.startsWith('worktree_events.jsonl.migrated-'));
      expect(kept, hasLength(1));
    });

    test('adds only new agent events', () async {
      await write(
        'agent_runs.json',
        jsonEncode({
          'runs': [run('ag_one').toJson()],
        }),
      );
      await write(
        'agent_events.jsonl',
        lines([event('ag_one', 'started').toJson()]),
      );
      await importAll();
      await write(
        'agent_events.jsonl',
        lines([
          event('ag_one', 'started').toJson(),
          event('ag_one', 'built', minute: 3).toJson(),
        ]),
      );
      await importAll();

      final events = await AgentRunStore(db).loadEvents();
      expect(events.map((e) => e.message), ['started', 'built']);
    });

    test('keeps the more recently updated copy of a run', () async {
      final store = AgentRunStore(db);
      await store.saveRuns([
        run('ag_one', updatedAt: DateTime(2026, 10, 2), title: 'newer'),
        run('ag_two', updatedAt: DateTime(2026, 10, 2), title: 'older'),
      ]);
      await write(
        'agent_runs.json',
        jsonEncode({
          'runs': [
            run('ag_one', updatedAt: DateTime(2026, 10, 1), title: 'stale'),
            run('ag_two', updatedAt: DateTime(2026, 10, 3), title: 'fresh'),
            run('ag_three'),
          ].map((r) => r.toJson()).toList(),
        }),
      );
      await importAll();

      final runs = {
        for (final r in await AgentRunStore(db).loadRuns()) r.id: r.title,
      };
      expect(runs, {'ag_one': 'newer', 'ag_two': 'fresh', 'ag_three': 'Build'});
    });

    test('replays posts and tombstones onto what is there', () async {
      final store = ManualPostStore(db);
      await store.add(post('a'));
      await store.add(post('b'));
      await write(
        'manual_posts.jsonl',
        lines([
          {'kind': 'delete', 'id': 'a'},
          post('b', hours: 4).toJson(),
          post('c').toJson(),
        ]),
      );
      await importAll();

      final posts = await store.loadAll();
      expect(posts.map((p) => p.id), ['b', 'c']);
      expect(posts.first.hours, 4);
    });

    test('keeps the more recently fetched cached issue', () async {
      final cache = JiraIssueCache(db);
      await cache.write(
        'AU2-1',
        const JiraIssue(key: 'AU2-1', summary: 'cached later'),
        fetchedAt: DateTime.utc(2026, 10, 19, 13),
      );
      await write(
        'jira_issue_cache.json',
        jsonEncode({
          'AU2-1': cacheEntry(
            const JiraIssue(key: 'AU2-1', summary: 'from file').toJson(),
            '2026-10-19T12:00:00.000Z',
          ),
          'AU2-3': cacheEntry(
            const JiraIssue(key: 'AU2-3', summary: 'new').toJson(),
            '2026-10-19T12:00:00.000Z',
          ),
        }),
      );
      await importAll();

      expect((await cache.read('AU2-1'))!.issue.summary, 'cached later');
      expect((await cache.read('AU2-3'))!.issue.summary, 'new');
    });
  });

  test('keeps the complete record when two appends interleaved', () async {
    final cut = jsonEncode(worktreeEvent(WorktreeEventType.created).toJson());
    final whole = worktreeEvent(WorktreeEventType.closed, hour: 17).toJson();
    await write(
      'worktree_events.jsonl',
      lines([cut.substring(0, cut.length - 30) + jsonEncode(whole)]),
    );
    await importAll();

    final events = await WorktreeEventStore(db).loadAll();
    expect(events.single.type, WorktreeEventType.closed);
    expect(events.single.timestamp, DateTime(2026, 6, 3, 17));
  });

  test('leaves an unreadable file in place and imports the rest', () async {
    await write('agent_runs.json', '{"runs": [');
    await write(
      'worktree_events.jsonl',
      lines([worktreeEvent(WorktreeEventType.created).toJson()]),
    );
    await importAll();

    expect(await file('agent_runs.json').exists(), isTrue);
    expect(await AgentRunStore(db).loadRuns(), isEmpty);
    expect(await WorktreeEventStore(db).loadAll(), hasLength(1));
  });

  test('does nothing when there are no files', () async {
    await importAll();
    expect(dir.listSync(), isEmpty);
    expect(await AgentRunStore(db).loadRuns(), isEmpty);
  });
}
