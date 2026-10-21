/// When the app checks Jira for the repos' triggers: whether at all, how
/// often, and between which times of day. Outside the hours nothing is
/// checked; a change made then fires at the first check after.
class JiraTriggerSchedule {
  const JiraTriggerSchedule({
    this.enabled = true,
    this.intervalMinutes = defaultIntervalMinutes,
    this.from,
    this.until,
  });

  static const defaultIntervalMinutes = 10;

  final bool enabled;
  final int intervalMinutes;

  /// The checking hours, as minutes after midnight; both null for all day.
  /// [until] before [from] spans midnight.
  final int? from;
  final int? until;

  bool get hasHours => from != null && until != null;

  Duration get interval => Duration(minutes: intervalMinutes.clamp(1, 1440));

  /// Whether Jira is checked at [time].
  bool isActiveAt(DateTime time) {
    if (!enabled) return false;
    final (start, end) = (from, until);
    if (start == null || end == null || start == end) return true;
    final minute = time.hour * 60 + time.minute;
    return start < end
        ? minute >= start && minute < end
        : minute >= start || minute < end;
  }

  factory JiraTriggerSchedule.fromJson(Map<String, dynamic> json) =>
      JiraTriggerSchedule(
        enabled: json['enabled'] as bool? ?? true,
        intervalMinutes:
            json['intervalMinutes'] as int? ?? defaultIntervalMinutes,
        from: parseTimeOfDay(json['from'] as String?),
        until: parseTimeOfDay(json['until'] as String?),
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'intervalMinutes': intervalMinutes,
    if (from != null) 'from': formatTimeOfDay(from!),
    if (until != null) 'until': formatTimeOfDay(until!),
  };

  JiraTriggerSchedule copyWith({
    bool? enabled,
    int? intervalMinutes,
    int? from,
    int? until,
    bool clearHours = false,
  }) => JiraTriggerSchedule(
    enabled: enabled ?? this.enabled,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    from: clearHours ? null : (from ?? this.from),
    until: clearHours ? null : (until ?? this.until),
  );

  @override
  bool operator ==(Object other) =>
      other is JiraTriggerSchedule &&
      other.enabled == enabled &&
      other.intervalMinutes == intervalMinutes &&
      other.from == from &&
      other.until == until;

  @override
  int get hashCode => Object.hash(enabled, intervalMinutes, from, until);
}

/// Minutes after midnight for `H:mm` or `HH:mm` (00:00–23:59); null for
/// anything else.
int? parseTimeOfDay(String? text) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text?.trim() ?? '');
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

/// [minutes] after midnight as `HH:mm`.
String formatTimeOfDay(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';
