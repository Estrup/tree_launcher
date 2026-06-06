import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/activity_service.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';

void main() {
  late Directory tempDir; // event-store storage
  late Directory tempHome; // fake $HOME for Claude transcripts

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('activity_service_events');
    tempHome = await Directory.systemTemp.createTemp('activity_service_home');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
    if (await tempHome.exists()) await tempHome.delete(recursive: true);
  });

  ActivityService service() => ActivityService(
    eventStore: WorktreeEventStore(directoryPath: tempDir.path),
    claudeActivity: ClaudeSessionActivity(homeDir: tempHome.path),
  );

  Worktree worktree(String path, {String name = 'wt', String branch = 'b'}) =>
      Worktree(
        path: path,
        branch: branch,
        name: name,
        isMain: false,
        commitHash: 'abc',
      );

  Future<void> writeClaudeDays(String worktreePath, List<DateTime> days) async {
    final encoded = ClaudeSessionActivity.encodeProjectDir(worktreePath);
    final dir = Directory(
      p.join(tempHome.path, '.claude', 'projects', encoded),
    );
    await dir.create(recursive: true);
    final lines = days
        .map((d) => '{"timestamp":"${d.toUtc().toIso8601String()}"}')
        .join('\n');
    await File(p.join(dir.path, 'session.jsonl')).writeAsString('$lines\n');
  }

  test('assembles created/closed events into an entry', () async {
    final store = WorktreeEventStore(directoryPath: tempDir.path);
    await store.append(
      WorktreeEvent(
        timestamp: DateTime(2026, 6, 3, 9),
        type: WorktreeEventType.created,
        repoPath: '/repo',
        repoName: 'demo',
        worktreePath: '/repo/wt-a',
        worktreeName: 'wt-a',
        branch: 'feature/a',
        jiraIssue: 'AU2-1',
      ),
    );
    await store.append(
      WorktreeEvent(
        timestamp: DateTime(2026, 6, 4, 17),
        type: WorktreeEventType.closed,
        repoPath: '/repo',
        repoName: 'demo',
        worktreePath: '/repo/wt-a',
        worktreeName: 'wt-a',
      ),
    );

    final entries = await service().loadEntries();
    expect(entries, hasLength(1));
    final e = entries.single;
    expect(e.worktreeName, 'wt-a');
    expect(e.repoName, 'demo');
    expect(e.branch, 'feature/a');
    expect(e.jiraIssue, 'AU2-1');
    expect(e.createdAt, DateTime(2026, 6, 3, 9));
    expect(e.closedAt, DateTime(2026, 6, 4, 17));
    expect(e.isOpen, isFalse);
  });

  test('folds in live worktrees and tags them with repo name', () async {
    const path = '/repo/live-wt';
    final entries = await service().loadEntries(
      currentWorktrees: [worktree(path, name: 'live-wt')],
      repoNamesByWorktreePath: {path: 'demo'},
    );
    expect(entries, hasLength(1));
    expect(entries.single.repoName, 'demo');
    expect(entries.single.isOpen, isTrue);
    expect(entries.single.closedAt, isNull);
  });

  test('enriches entries with Claude active days and sorts newest-first',
      () async {
    final store = WorktreeEventStore(directoryPath: tempDir.path);
    // Older worktree created earlier...
    await store.append(
      WorktreeEvent(
        timestamp: DateTime(2026, 6, 1, 9),
        type: WorktreeEventType.created,
        repoPath: '/repo',
        repoName: 'demo',
        worktreePath: '/repo/old',
        worktreeName: 'old',
      ),
    );
    // ...but recent Claude activity in a different one.
    await store.append(
      WorktreeEvent(
        timestamp: DateTime(2026, 6, 2, 9),
        type: WorktreeEventType.created,
        repoPath: '/repo',
        repoName: 'demo',
        worktreePath: '/repo/recent',
        worktreeName: 'recent',
      ),
    );
    await writeClaudeDays('/repo/recent', [
      DateTime(2026, 6, 5),
      DateTime(2026, 6, 6),
    ]);

    final entries = await service().loadEntries();
    expect(entries.map((e) => e.worktreeName), ['recent', 'old']);
    final recent = entries.first;
    expect(recent.activeDays, [DateTime(2026, 6, 5), DateTime(2026, 6, 6)]);
    expect(recent.lastActiveDay, DateTime(2026, 6, 6));
  });

  test('skips phantom entries with no signal at all', () async {
    // A live worktree with no events and no Claude history still appears
    // (live is a signal), but a path with truly nothing does not.
    final entries = await service().loadEntries();
    expect(entries, isEmpty);
  });

  test('toJson round-trips the entry fields', () async {
    const path = '/repo/json-wt';
    await writeClaudeDays(path, [DateTime(2026, 6, 5)]);
    final entries = await service().loadEntries(
      currentWorktrees: [worktree(path, name: 'json-wt', branch: 'feature/j')],
      repoNamesByWorktreePath: {path: 'demo'},
    );
    final json = entries.single.toJson();
    expect(json['worktreePath'], path);
    expect(json['worktreeName'], 'json-wt');
    expect(json['repoName'], 'demo');
    expect(json['branch'], 'feature/j');
    expect(json['isOpen'], true);
    expect(json['closedAt'], isNull);
    expect(json['activeDays'], [DateTime(2026, 6, 5).toIso8601String()]);
    expect(json['lastActiveDay'], DateTime(2026, 6, 5).toIso8601String());
  });
}
