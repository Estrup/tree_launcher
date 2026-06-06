import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';

void main() {
  late Directory tempDir;
  late WorktreeEventStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('worktree_event_store_test');
    store = WorktreeEventStore(directoryPath: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  WorktreeEvent event(
    WorktreeEventType type, {
    String path = '/repo/wt',
    String? jira,
  }) {
    return WorktreeEvent(
      timestamp: DateTime(2026, 6, 6, 12),
      type: type,
      repoPath: '/repo',
      repoName: 'repo',
      worktreePath: path,
      worktreeName: 'wt',
      branch: 'feature/x',
      jiraIssue: jira,
    );
  }

  test('loadAll returns empty when no file exists', () async {
    expect(await store.loadAll(), isEmpty);
  });

  test('append then loadAll round-trips events in order', () async {
    await store.append(event(WorktreeEventType.created, jira: 'AU2-1'));
    await store.append(event(WorktreeEventType.closed, jira: 'AU2-1'));

    final events = await store.loadAll();
    expect(events.length, 2);
    expect(events[0].type, WorktreeEventType.created);
    expect(events[1].type, WorktreeEventType.closed);
    expect(events[0].jiraIssue, 'AU2-1');
    expect(events[1].worktreePath, '/repo/wt');
    expect(events[0].branch, 'feature/x');
  });

  test('malformed lines are skipped', () async {
    await store.append(event(WorktreeEventType.created));
    // Corrupt the file with a junk line between valid ones.
    final file = File(p.join(tempDir.path, 'worktree_events.jsonl'));
    await file.writeAsString('not-json\n', mode: FileMode.append);
    await store.append(event(WorktreeEventType.closed));

    final events = await store.loadAll();
    expect(events.length, 2);
    expect(events[0].type, WorktreeEventType.created);
    expect(events[1].type, WorktreeEventType.closed);
  });
}
