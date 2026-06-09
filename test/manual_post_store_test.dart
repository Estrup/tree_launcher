import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/models/manual_post.dart';

void main() {
  late Directory tempDir;
  late ManualPostStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('manual_post_store_test');
    store = ManualPostStore(directoryPath: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
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

  test('loadAll returns empty when no file exists', () async {
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

  test('delete tombstones a post so it no longer loads', () async {
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

  test('malformed lines are skipped', () async {
    await store.add(post('a'));
    final file = File(p.join(tempDir.path, 'manual_posts.jsonl'));
    await file.writeAsString('not-json\n', mode: FileMode.append);
    await store.add(post('b'));

    final posts = await store.loadAll();
    expect(posts.map((p) => p.id).toList()..sort(), ['a', 'b']);
  });

  test('newId yields distinct ids', () {
    final ids = {for (var i = 0; i < 50; i++) ManualPost.newId()};
    expect(ids.length, 50);
  });
}
