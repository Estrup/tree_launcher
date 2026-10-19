import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late WorktreeEventStore store;

  setUp(() async {
    db = testDatabase();
    store = WorktreeEventStore(db);
  });

  tearDown(() async {
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

  test('loadAll returns empty when nothing is stored', () async {
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

  test('keeps optional fields null and the timestamp exact', () async {
    final at = DateTime.utc(2026, 6, 6, 12, 30, 1, 2, 3);
    await store.append(
      WorktreeEvent(
        timestamp: at,
        type: WorktreeEventType.closed,
        repoPath: '/repo',
        repoName: 'repo',
        worktreePath: '/repo/wt',
        worktreeName: 'wt',
      ),
    );

    final loaded = (await store.loadAll()).single;
    expect(loaded.timestamp, at);
    expect(loaded.branch, isNull);
    expect(loaded.jiraIssue, isNull);
  });
}
