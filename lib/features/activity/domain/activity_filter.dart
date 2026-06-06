/// Predefined time windows for the activity timeline. All ranges are
/// half-open `[start, end)` in local time.
enum ActivityFilter { all, today, yesterday, thisWeek, thisMonth }

extension ActivityFilterX on ActivityFilter {
  String get label => switch (this) {
    ActivityFilter.all => 'All',
    ActivityFilter.today => 'Today',
    ActivityFilter.yesterday => 'Yesterday',
    ActivityFilter.thisWeek => 'This week',
    ActivityFilter.thisMonth => 'This month',
  };

  /// The `[start, end)` window for this filter relative to [now], or null for
  /// [ActivityFilter.all]. Day arithmetic goes through the `DateTime`
  /// constructor (which normalizes overflow) rather than `Duration`, so it
  /// stays correct across DST boundaries.
  ({DateTime start, DateTime end})? range(DateTime now) {
    final y = now.year, m = now.month, d = now.day;
    switch (this) {
      case ActivityFilter.all:
        return null;
      case ActivityFilter.today:
        return (start: DateTime(y, m, d), end: DateTime(y, m, d + 1));
      case ActivityFilter.yesterday:
        return (start: DateTime(y, m, d - 1), end: DateTime(y, m, d));
      case ActivityFilter.thisWeek:
        // weekday: 1 = Monday ... 7 = Sunday.
        final mondayOffset = now.weekday - 1;
        return (
          start: DateTime(y, m, d - mondayOffset),
          end: DateTime(y, m, d - mondayOffset + 7),
        );
      case ActivityFilter.thisMonth:
        return (start: DateTime(y, m, 1), end: DateTime(y, m + 1, 1));
    }
  }
}
