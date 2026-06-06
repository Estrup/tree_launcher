import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/activity/domain/activity_filter.dart';
import 'package:tree_launcher/features/activity/presentation/controllers/activity_controller.dart';

void main() {
  // Reference "now": Saturday 6 June 2026, 14:30 local.
  final now = DateTime(2026, 6, 6, 14, 30);

  group('ActivityFilter.range', () {
    test('all has no range', () {
      expect(ActivityFilter.all.range(now), isNull);
    });

    test('today is [midnight today, midnight tomorrow)', () {
      final r = ActivityFilter.today.range(now)!;
      expect(r.start, DateTime(2026, 6, 6));
      expect(r.end, DateTime(2026, 6, 7));
    });

    test('yesterday is [midnight yesterday, midnight today)', () {
      final r = ActivityFilter.yesterday.range(now)!;
      expect(r.start, DateTime(2026, 6, 5));
      expect(r.end, DateTime(2026, 6, 6));
    });

    test('this week runs Monday..Sunday and contains now', () {
      final r = ActivityFilter.thisWeek.range(now)!;
      expect(r.start.weekday, DateTime.monday);
      expect(r.end.difference(r.start).inDays, 7);
      // 6 June 2026 is a Saturday → week starts Mon 1 June.
      expect(r.start, DateTime(2026, 6, 1));
      expect(r.end, DateTime(2026, 6, 8));
      expect(now.isBefore(r.start), isFalse);
      expect(now.isBefore(r.end), isTrue);
    });

    test('a Sunday belongs to the week that started the prior Monday', () {
      final sunday = DateTime(2026, 6, 7, 9); // Sunday
      final r = ActivityFilter.thisWeek.range(sunday)!;
      expect(r.start, DateTime(2026, 6, 1)); // Monday
      expect(r.end, DateTime(2026, 6, 8));
    });

    test('this month is [1st, 1st of next month)', () {
      final r = ActivityFilter.thisMonth.range(now)!;
      expect(r.start, DateTime(2026, 6, 1));
      expect(r.end, DateTime(2026, 7, 1));
    });

    test('this month rolls over December correctly', () {
      final dec = DateTime(2026, 12, 20);
      final r = ActivityFilter.thisMonth.range(dec)!;
      expect(r.start, DateTime(2026, 12, 1));
      expect(r.end, DateTime(2027, 1, 1));
    });
  });

  group('ActivityEntry.matchesRange', () {
    ActivityEntry entry({
      DateTime? created,
      DateTime? closed,
      List<DateTime> activeDays = const [],
    }) {
      return ActivityEntry(
        worktreePath: '/repo/wt',
        worktreeName: 'wt',
        createdAt: created,
        closedAt: closed,
        activeDays: activeDays,
      );
    }

    test('matches when created within the window', () {
      final r = ActivityFilter.today.range(now)!;
      expect(entry(created: DateTime(2026, 6, 6, 8)).matchesRange(r), isTrue);
    });

    test('matches when closed within the window', () {
      final r = ActivityFilter.today.range(now)!;
      expect(entry(closed: DateTime(2026, 6, 6, 23)).matchesRange(r), isTrue);
    });

    test('matches on a Claude active day inside the window', () {
      final r = ActivityFilter.thisWeek.range(now)!;
      expect(
        entry(activeDays: [DateTime(2026, 6, 3)]).matchesRange(r),
        isTrue,
      );
    });

    test('does not match when all signals fall outside the window', () {
      final r = ActivityFilter.today.range(now)!;
      final e = entry(
        created: DateTime(2026, 6, 1, 10),
        activeDays: [DateTime(2026, 6, 5)],
      );
      expect(e.matchesRange(r), isFalse);
    });

    test('end of window is exclusive', () {
      final r = ActivityFilter.yesterday.range(now)!; // [6-05, 6-06)
      // Exactly midnight 6 June is the start of "today", not "yesterday".
      expect(entry(created: DateTime(2026, 6, 6)).matchesRange(r), isFalse);
      expect(entry(created: DateTime(2026, 6, 5)).matchesRange(r), isTrue);
    });
  });
}
