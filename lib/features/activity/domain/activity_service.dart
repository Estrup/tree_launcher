import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/activity_entry.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';

/// Pure (Flutter-state-free) assembly of the Activity timeline. Merges the
/// durable [WorktreeEvent] log with Claude Code's session history and any live
/// worktrees into a sorted list of [ActivityEntry]s.
///
/// Extracted from `ActivityController` so the same logic can be served over the
/// agent HTTP API without going through a `ChangeNotifier`/Provider.
class ActivityService {
  ActivityService({
    WorktreeEventStore? eventStore,
    ClaudeSessionActivity? claudeActivity,
  }) : _eventStore = eventStore ?? WorktreeEventStore(),
       _claudeActivity = claudeActivity ?? ClaudeSessionActivity();

  final WorktreeEventStore _eventStore;
  final ClaudeSessionActivity _claudeActivity;

  /// Builds the timeline, newest-first by [ActivityEntry.sortKey].
  ///
  /// [currentWorktrees] are live worktrees folded in so ones that predate the
  /// event log (or were never created through this app) still appear, populated
  /// from their Claude session history.
  ///
  /// [repoNamesByWorktreePath] tags live (event-less) worktrees with the repo
  /// they belong to, so callers can filter results by repo. The UI passes
  /// nothing here, leaving behavior unchanged.
  Future<List<ActivityEntry>> loadEntries({
    List<Worktree> currentWorktrees = const [],
    Map<String, String>? repoNamesByWorktreePath,
  }) async {
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
          worktreeName: reference?.worktreeName ?? live?.name ?? _basename(path),
          repoName: reference?.repoName ?? repoNamesByWorktreePath?[path],
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

    return entries;
  }

  static String _basename(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? path : segments.last;
  }
}
