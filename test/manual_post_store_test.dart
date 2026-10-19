import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/domain/manual_post.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late ManualPostStore store;

  setUp(() async {
    db = testDatabase();
    store = ManualPostStore(db);
  });

  tearDown(() async {
  });

  ManualPost post(String id, {String issue = 'AU2-1', double? hours}) {
    return ManualPost(
      id: id,
      timestamp: DateTime(2026, 6, 9, 10),
      repoName: 'demo',
      issueKey: issue,
      description: 'desc $id',
      hours: hours,
    );
  }

  test('loadAll returns empty when nothing is stored', () async {
    expect(await store.loadAll(), isEmpty);
  });

  test('add then loadAll round-trips posts', () async {
    await store.add(post('a', hours: 2));
    await store.add(post('b', issue: 'AU2-2'));

    final posts = await store.loadAll();
    expect(posts.length, 2);
    final byId = {for (final p in posts) p.id: p};
    expect(byId['a']!.issueKey, 'AU2-1');
    expect(byId['a']!.hours, 2);
    expect(byId['a']!.description, 'desc a');
    expect(byId['b']!.issueKey, 'AU2-2');
    expect(byId['b']!.hours, isNull);
  });

  test('delete removes a post so it no longer loads', () async {
    await store.add(post('a'));
    await store.add(post('b'));
    await store.delete('a');

    final posts = await store.loadAll();
    expect(posts.map((p) => p.id), ['b']);
  });

  test('re-adding after delete brings the post back', () async {
    await store.add(post('a'));
    await store.delete('a');
    await store.add(post('a', hours: 5));

    final posts = await store.loadAll();
    expect(posts.single.id, 'a');
    expect(posts.single.hours, 5);
  });

  test('add with an existing id replaces the post in place', () async {
    await store.add(post('a'));
    await store.add(post('b'));
    await store.add(post('a', hours: 3));

    final posts = await store.loadAll();
    expect(posts.map((p) => p.id), ['a', 'b']);
    expect(posts.first.hours, 3);
  });

  test('round-trips the timestamp exactly', () async {
    final at = DateTime(2026, 6, 9, 10, 11, 12, 13, 14);
    await store.add(post('a').copyWith(timestamp: at));
    final loaded = (await store.loadAll()).single.timestamp;
    expect(loaded, at);
    expect(loaded.isUtc, isFalse);
  });

  test('newId yields distinct ids', () {
    final ids = {for (var i = 0; i < 50; i++) ManualPost.newId()};
    expect(ids.length, 50);
  });
}
