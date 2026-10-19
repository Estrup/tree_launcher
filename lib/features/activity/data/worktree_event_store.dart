import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';

/// Log of [WorktreeEvent]s in the app database's `worktree_events` table, in
/// write order. Keyed by path, so the history outlives the worktree.
class WorktreeEventStore {
  WorktreeEventStore(this._db);

  final AppDatabase _db;

  /// Appends a single event. Never throws — logging must not block the worktree
  /// create/delete it accompanies.
  Future<void> append(WorktreeEvent event) async {
    try {
      await _db.into(_db.worktreeEvents).insert(worktreeEventRow(event));
    } catch (e) {
      debugPrint('WorktreeEventStore.append failed: $e');
    }
  }

  /// Reads all events in write order. Never throws.
  Future<List<WorktreeEvent>> loadAll() async {
    try {
      final rows = await (_db.select(
        _db.worktreeEvents,
      )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
      return [
        for (final row in rows)
          WorktreeEvent(
            timestamp: row.at,
            type: WorktreeEventType.values.firstWhere(
              (t) => t.name == row.type,
              orElse: () => WorktreeEventType.created,
            ),
            repoPath: row.repoPath,
            repoName: row.repoName,
            worktreePath: row.worktreePath,
            worktreeName: row.worktreeName,
            branch: row.branch,
            jiraIssue: row.jiraIssue,
          ),
      ];
    } catch (e) {
      debugPrint('WorktreeEventStore.loadAll failed: $e');
      return [];
    }
  }
}

/// The `worktree_events` row for [event].
WorktreeEventsCompanion worktreeEventRow(WorktreeEvent event) =>
    WorktreeEventsCompanion.insert(
      at: event.timestamp,
      type: event.type.name,
      repoPath: event.repoPath,
      repoName: event.repoName,
      worktreePath: event.worktreePath,
      worktreeName: event.worktreeName,
      branch: Value(event.branch),
      jiraIssue: Value(event.jiraIssue),
    );
