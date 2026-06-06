import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';

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

    test('falls back to file mtime when a transcript has no timestamps',
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
      expect(await activity.activeDaysFor(worktreePath), [DateTime(2026, 6, 2)]);
    });
  });
}
