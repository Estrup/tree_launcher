import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:tree_launcher/core/database/database_backup.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/models/manual_post.dart';

import 'test_database.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('database_backup_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  List<String> names() =>
      dir.listSync().map((e) => p.basename(e.path)).toList()..sort();

  test('makes one copy per day and keeps the newest seven', () async {
    final db = testDatabase();
    await ManualPostStore(db).add(
      ManualPost(
        id: 'm1',
        timestamp: DateTime(2026, 10, 19),
        repoName: 'demo',
        issueKey: 'AU2-1',
      ),
    );
    var now = DateTime(2026, 10, 1, 9);
    final backup = DatabaseBackup(db, dir.path, clock: () => now);

    await backup.runIfDue();
    final first = File(p.join(dir.path, 'tree_launcher-2026-10-01.db'));
    final made = await first.lastModified();
    now = DateTime(2026, 10, 1, 18);
    await backup.runIfDue();
    expect(names(), ['tree_launcher-2026-10-01.db']);
    expect(await first.lastModified(), made);

    final copy = sqlite3.open(first.path);
    addTearDown(copy.close);
    expect(copy.select('SELECT id FROM manual_posts').single['id'], 'm1');

    for (var day = 2; day <= 9; day++) {
      now = DateTime(2026, 10, day, 9);
      await backup.runIfDue();
    }
    expect(names(), [
      for (var day = 3; day <= 9; day++) 'tree_launcher-2026-10-0$day.db',
    ]);
  });
}
