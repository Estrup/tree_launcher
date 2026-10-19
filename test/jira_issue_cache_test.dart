import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late JiraIssueCache cache;

  setUp(() async {
    db = testDatabase();
    cache = JiraIssueCache(db);
  });

  tearDown(() async {
  });

  JiraIssue issue(String key) =>
      JiraIssue(key: key, summary: 'summary $key', status: 'Open');

  test('read returns null when nothing is cached', () async {
    expect(await cache.read('AU2-1'), isNull);
  });

  test('write then read round-trips the issue and fetchedAt', () async {
    final stamp = DateTime.parse('2026-06-10T12:00:00.000Z');
    await cache.write('AU2-1', issue('AU2-1'), fetchedAt: stamp);

    final cached = await cache.read('AU2-1');
    expect(cached, isNotNull);
    expect(cached!.issue.summary, 'summary AU2-1');
    expect(cached.fetchedAt, stamp);
  });

  test('write overwrites an existing entry', () async {
    await cache.write('AU2-1', issue('AU2-1'));
    await cache.write(
      'AU2-1',
      issue('AU2-1').copyWith(summary: 'updated'),
    );

    final cached = await cache.read('AU2-1');
    expect(cached!.issue.summary, 'updated');
  });

  test('prune drops orphan keys and keeps live ones', () async {
    await cache.write('AU2-1', issue('AU2-1'));
    await cache.write('AU2-2', issue('AU2-2'));
    await cache.write('OA-3', issue('OA-3'));

    await cache.prune({'AU2-1', 'OA-3'});

    expect(await cache.read('AU2-1'), isNotNull);
    expect(await cache.read('OA-3'), isNotNull);
    expect(await cache.read('AU2-2'), isNull);
  });

  test('prune with no live keys clears everything', () async {
    await cache.write('AU2-1', issue('AU2-1'));
    await cache.prune({});
    expect(await cache.read('AU2-1'), isNull);
  });

  test('prune is a no-op when nothing is orphaned', () async {
    await cache.write('AU2-1', issue('AU2-1'));
    await cache.prune({'AU2-1', 'AU2-2'});
    expect(await cache.read('AU2-1'), isNotNull);
  });
}
