import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/activity_filter.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';

/// One worktree's worth of timeline: when it was created/closed and which days
/// Claude was active in it. Merges the durable event log with Claude Code's
/// session history.
class ActivityEntry {
  final String worktreePath;
  final String worktreeName;
  final String? repoName;
  final String? branch;
  final String? jiraIssue;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final List<DateTime> activeDays;

  ActivityEntry({
    required this.worktreePath,
    required this.worktreeName,
    this.repoName,
    this.branch,
    this.jiraIssue,
    this.createdAt,
    this.closedAt,
    this.activeDays = const [],
  });

  bool get isOpen => closedAt == null;

  DateTime? get lastActiveDay =>
      activeDays.isEmpty ? null : activeDays.last;

  /// Most recent moment we know about for this worktree, used for sorting.
  DateTime? get sortKey {
    DateTime? latest;
    for (final t in [createdAt, closedAt, lastActiveDay]) {
      if (t == null) continue;
      if (latest == null || t.isAfter(latest)) latest = t;
    }
    return latest;
  }

  /// Whether this entry has any signal — created, closed, or a Claude active
  /// day — falling within the half-open `[start, end)` window.
  bool matchesRange(({DateTime start, DateTime end}) r) {
    bool inRange(DateTime? t) =>
        t != null && !t.isBefore(r.start) && t.isBefore(r.end);
    if (inRange(createdAt) || inRange(closedAt)) return true;
    return activeDays.any(inRange);
  }
}

class ActivityController extends ChangeNotifier {
  ActivityController({
    WorktreeEventStore? eventStore,
    ClaudeSessionActivity? claudeActivity,
  }) : _eventStore = eventStore ?? WorktreeEventStore(),
       _claudeActivity = claudeActivity ?? ClaudeSessionActivity();

  final WorktreeEventStore _eventStore;
  final ClaudeSessionActivity _claudeActivity;

  bool _loading = false;
  bool get loading => _loading;

  List<ActivityEntry> _entries = [];
  List<ActivityEntry> get entries => List.unmodifiable(_entries);

  ActivityFilter _filter = ActivityFilter.all;
  ActivityFilter get filter => _filter;

  void setFilter(ActivityFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  /// Entries narrowed to the active [filter]. Evaluated against the current
  /// wall clock so "Today"/"This week" stay correct without a reload.
  List<ActivityEntry> get filteredEntries {
    final range = _filter.range(DateTime.now());
    if (range == null) return List.unmodifiable(_entries);
    return _entries.where((e) => e.matchesRange(range)).toList();
  }

  /// Loads the timeline. [currentWorktrees] are the live worktrees of the
  /// selected repo — they're folded in so worktrees that predate the event log
  /// (or were never created through this app) still appear, populated from
  /// their Claude session history.
  Future<void> load({List<Worktree> currentWorktrees = const []}) async {
    _loading = true;
    notifyListeners();

    try {
      final events = await _eventStore.loadAll();

      // Group events by worktree path.
      final created = <String, WorktreeEvent>{};
      final closed = <String, WorktreeEvent>{};
      final order = <String>[];
      void track(String path) {
        if (!order.contains(path)) order.add(path);
      }

      for (final e in events) {
        track(e.worktreePath);
        if (e.type == WorktreeEventType.created) {
          // Keep the earliest creation.
          final existing = created[e.worktreePath];
          if (existing == null || e.timestamp.isBefore(existing.timestamp)) {
            created[e.worktreePath] = e;
          }
        } else {
          // Keep the latest close.
          final existing = closed[e.worktreePath];
          if (existing == null || e.timestamp.isAfter(existing.timestamp)) {
            closed[e.worktreePath] = e;
          }
        }
      }

      // Fold in currently-existing worktrees that have no event yet.
      final liveByPath = {for (final w in currentWorktrees) w.path: w};
      for (final w in currentWorktrees) {
        track(w.path);
      }

      final entries = <ActivityEntry>[];
      for (final path in order) {
        final createdEvent = created[path];
        final closedEvent = closed[path];
        final live = liveByPath[path];
        final activeDays = await _claudeActivity.activeDaysFor(path);

        // Skip phantom entries with no signal at all.
        if (createdEvent == null &&
            closedEvent == null &&
            live == null &&
            activeDays.isEmpty) {
          continue;
        }

        final reference = createdEvent ?? closedEvent;
        entries.add(
          ActivityEntry(
            worktreePath: path,
            worktreeName:
                reference?.worktreeName ?? live?.name ?? _basename(path),
            repoName: reference?.repoName,
            branch: createdEvent?.branch ?? live?.branch ?? closedEvent?.branch,
            jiraIssue:
                createdEvent?.jiraIssue ??
                live?.jiraIssue ??
                closedEvent?.jiraIssue,
            createdAt: createdEvent?.timestamp,
            // A live worktree is, by definition, not closed — guard against a
            // stale close event for a since-recreated path.
            closedAt: live != null ? null : closedEvent?.timestamp,
            activeDays: activeDays,
          ),
        );
      }

      entries.sort((a, b) {
        final ak = a.sortKey;
        final bk = b.sortKey;
        if (ak == null && bk == null) return 0;
        if (ak == null) return 1;
        if (bk == null) return -1;
        return bk.compareTo(ak);
      });

      _entries = entries;
    } catch (e) {
      debugPrint('ActivityController.load failed: $e');
      _entries = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  static String _basename(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? path : segments.last;
  }
}
