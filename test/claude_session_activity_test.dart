import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';

import 'test_database.dart';

void main() {
  group('ClaudeSessionActivity.encodeProjectDir', () {
    test('encodes a worktree path the way Claude names its project dir', () {
      expect(
        ClaudeSessionActivity.encodeProjectDir(
          '/Users/me/Projects/tree_launcher/main',
        ),
        '-Users-me-Projects-tree-launcher-main',
      );
    });

    test('encodes a leading slash + dot segment (.bare) as a double dash', () {
      expect(
        ClaudeSessionActivity.encodeProjectDir(
          '/Users/me/Projects/au2-project/.bare',
        ),
        '-Users-me-Projects-au2-project--bare',
      );
    });

    test('preserves existing hyphens and digit/letter case', () {
      expect(
        ClaudeSessionActivity.encodeProjectDir(
          '/Users/me/Projects/au2-project/klp-AU2-5407',
        ),
        '-Users-me-Projects-au2-project-klp-AU2-5407',
      );
    });
  });

  group('ClaudeSessionActivity.sessionTimestampsFor / activeDaysFor', () {
    late Directory tempHome;

    setUp(() async {
      tempHome = await Directory.systemTemp.createTemp('claude_activity_test');
    });

    tearDown(() async {
      if (await tempHome.exists()) await tempHome.delete(recursive: true);
    });

    test('returns empty when the worktree has no Claude history', () async {
      final activity = ClaudeSessionActivity(homeDir: tempHome.path);
      expect(
        await activity.sessionTimestampsFor('/some/missing/worktree'),
        isEmpty,
      );
      expect(await activity.activeDaysFor('/some/missing/worktree'), isEmpty);
    });

    test('reads .jsonl mtimes and collapses them to distinct days', () async {
      const worktreePath = '/Users/me/Projects/demo/main';
      final encoded = ClaudeSessionActivity.encodeProjectDir(worktreePath);
      final projectDir = Directory(
        p.join(tempHome.path, '.claude', 'projects', encoded),
      );
      await projectDir.create(recursive: true);

      final day1a = File(p.join(projectDir.path, 'a.jsonl'));
      final day1b = File(p.join(projectDir.path, 'b.jsonl'));
      final day2 = File(p.join(projectDir.path, 'c.jsonl'));
      // A non-session file should be ignored.
      final ignored = File(p.join(projectDir.path, 'notes.txt'));
      for (final f in [day1a, day1b, day2, ignored]) {
        await f.writeAsString('{}');
      }
      await day1a.setLastModified(DateTime(2026, 6, 3, 9));
      await day1b.setLastModified(DateTime(2026, 6, 3, 17));
      await day2.setLastModified(DateTime(2026, 6, 5, 11));

      final activity = ClaudeSessionActivity(homeDir: tempHome.path);

      final stamps = await activity.sessionTimestampsFor(worktreePath);
      expect(stamps.length, 3); // notes.txt excluded

      final days = await activity.activeDaysFor(worktreePath);
      expect(days, [DateTime(2026, 6, 3), DateTime(2026, 6, 5)]);

      final last = await activity.lastActiveFor(worktreePath);
      expect(last, DateTime(2026, 6, 5, 11));
    });

    test('captures every day a single session spans, not just its mtime '
        'day', () async {
      const worktreePath = '/Users/me/Projects/demo/main';
      final encoded = ClaudeSessionActivity.encodeProjectDir(worktreePath);
      final projectDir = Directory(
        p.join(tempHome.path, '.claude', 'projects', encoded),
      );
      await projectDir.create(recursive: true);

      // One session whose transcript carries events on two different days.
      final ts1 = DateTime(2026, 6, 4, 16);
      final ts2 = DateTime(2026, 6, 5, 9);
      final session = File(p.join(projectDir.path, 'session.jsonl'));
      await session.writeAsString(
        '{"type":"user","timestamp":"${ts1.toUtc().toIso8601String()}"}\n'
        '{"type":"assistant","timestamp":"${ts2.toUtc().toIso8601String()}"}\n',
      );
      // Move the file mtime to "now" so it can't accidentally explain the days.
      await session.setLastModified(DateTime(2026, 6, 6, 12));

      final activity = ClaudeSessionActivity(homeDir: tempHome.path);
      final days = await activity.activeDaysFor(worktreePath);

      // Both days are present — the earlier one would be lost if we used mtime.
      expect(days, [DateTime(2026, 6, 4), DateTime(2026, 6, 5)]);
      expect(await activity.lastActiveFor(worktreePath), ts2);
    });

    test(
      'falls back to file mtime when a transcript has no timestamps',
      () async {
        const worktreePath = '/Users/me/Projects/demo/main';
        final encoded = ClaudeSessionActivity.encodeProjectDir(worktreePath);
        final projectDir = Directory(
          p.join(tempHome.path, '.claude', 'projects', encoded),
        );
        await projectDir.create(recursive: true);
        final f = File(p.join(projectDir.path, 'empty.jsonl'));
        await f.writeAsString('{"type":"user"}\n');
        await f.setLastModified(DateTime(2026, 6, 2, 8));

        final activity = ClaudeSessionActivity(homeDir: tempHome.path);
        expect(await activity.activeDaysFor(worktreePath), [
          DateTime(2026, 6, 2),
        ]);
      },
    );
  });

  group('ClaudeSessionActivity.activeDaysFor with the transcript index', () {
    const worktreePath = '/Users/me/Projects/demo/main';
    late Directory tempHome;
    late Directory projectDir;
    late AppDatabase db;
    late ClaudeSessionActivity activity;

    setUp(() async {
      tempHome = await Directory.systemTemp.createTemp('claude_index_test');
      projectDir = Directory(
        p.join(
          tempHome.path,
          '.claude',
          'projects',
          ClaudeSessionActivity.encodeProjectDir(worktreePath),
        ),
      );
      await projectDir.create(recursive: true);
      db = testDatabase();
      activity = ClaudeSessionActivity(homeDir: tempHome.path, database: db);
    });

    tearDown(() async {
      if (await tempHome.exists()) await tempHome.delete(recursive: true);
    });

    /// A transcript line stamped at noon (local) on June [day].
    String line(int day) =>
        '{"type":"user","timestamp":"${DateTime(2026, 6, day, 12).toUtc().toIso8601String()}"}\n';

    Future<File> transcript(String content, {required DateTime mtime}) async {
      final file = File(p.join(projectDir.path, 'session.jsonl'));
      await file.writeAsString(content);
      await file.setLastModified(mtime);
      return file;
    }

    Future<List<int>> days({DateTime? since}) async => [
      for (final d in await activity.activeDaysFor(worktreePath, since: since))
        d.day,
    ];

    test('reads a grown transcript only from where it stopped', () async {
      await transcript(line(4), mtime: DateTime(2026, 6, 4, 13));
      expect(await days(), [4]);

      // The first line changes too, but only the appended one is read.
      await transcript(line(7) + line(5), mtime: DateTime(2026, 6, 5, 13));
      expect(await days(), [4, 5]);

      // Without the index the whole file is read.
      final unindexed = ClaudeSessionActivity(homeDir: tempHome.path);
      final all = await unindexed.activeDaysFor(worktreePath);
      expect(all.map((d) => d.day), [5, 7]);
    });

    test('does not read an unchanged transcript again', () async {
      final mtime = DateTime(2026, 6, 4, 13);
      await transcript(line(4), mtime: mtime);
      expect(await days(), [4]);

      // Same size and mtime: taken from the index.
      await transcript(line(8), mtime: mtime);
      expect(await days(), [4]);
    });

    test('reads a shrunk transcript again from the start', () async {
      await transcript(line(4) + line(5), mtime: DateTime(2026, 6, 5, 13));
      expect(await days(), [4, 5]);

      await transcript(line(8), mtime: DateTime(2026, 6, 8, 13));
      expect(await days(), [8]);
    });

    test('reads a line that was still being written once it ends', () async {
      final partial = line(5);
      await transcript(
        line(4) + partial.substring(0, 20),
        mtime: DateTime(2026, 6, 5, 13),
      );
      expect(await days(), [4]);

      await transcript(line(4) + partial, mtime: DateTime(2026, 6, 5, 14));
      expect(await days(), [4, 5]);
    });

    test('forgets a deleted transcript', () async {
      final file = await transcript(line(4), mtime: DateTime(2026, 6, 4, 13));
      expect(await days(), [4]);

      await file.delete();
      expect(await days(), isEmpty);
      expect(await db.select(db.claudeTranscripts).get(), isEmpty);
    });

    test(
      'falls back to the mtime of a transcript without timestamps',
      () async {
        await transcript('{"type":"user"}\n', mtime: DateTime(2026, 6, 2, 8));
        expect(await days(), [2]);
      },
    );

    test(
      'with since, skips re-reading transcripts modified before it',
      () async {
        await transcript(line(4), mtime: DateTime(2026, 6, 4, 13));
        expect(await days(), [4]);
        await transcript(line(4) + line(5), mtime: DateTime(2026, 6, 5, 13));

        // Modified before the window: the indexed days are used as they are.
        expect(await days(since: DateTime(2026, 6, 10)), [4]);
        // Inside the window it is read.
        expect(await days(since: DateTime(2026, 6, 5)), [4, 5]);
      },
    );
  });
}
